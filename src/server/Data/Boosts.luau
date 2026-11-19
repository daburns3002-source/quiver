--!strict
--[[
	The boosts that are not on the clock, on the server (`Config/LiveEvents`,
	`docs/LIVE-EVENTS.md`): the owner's live event and the Server Luck. Each
	is published as workspace attributes for every screen and for this
	server's own rolls and payments (`Util/LiveState`); the weekend's boost
	and the set rotation need nothing kept, being the clock's.

	- **The live event** (`Remotes.LiveEventStart(kind)`): only a user id in
	  `LiveEvents.ownerIds`, or the place's creator, may fire one. It runs
	  here at once, goes to every other server through MessagingService, and
	  is written to a MemoryStore map so a server that starts during it picks
	  it up. "End" stops it everywhere. A message from elsewhere is checked
	  and never runs longer than one event from now.
	- **The Server Luck** (`Config/RobuxStore`, `Data/Purchases`): a bought
	  one adds its time to this server's luck and names its buyer for the
	  banner's thanks. It lasts as long as the server; nothing is saved.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Inbound = require(script.Parent.Parent.Net.Inbound)
local LiveBoosts = require(ReplicatedStorage.Shared.Util.LiveBoosts)
local LiveEvents = require(ReplicatedStorage.Shared.Config.LiveEvents)
local LiveState = require(ReplicatedStorage.Shared.Util.LiveState)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local log = Log.forTag("Boosts")

local Boosts = {}

local ATTRIBUTES = LiveEvents.attributes
local KEY = "current"
--[[ Seconds between sweeps that clear a boost that has run out. ]]
local SWEEP = 5
--[[ The furthest the Studio test clock may be moved, either way. ]]
local SHIFT_MOST = 400 * 86400

--[[ Whether `player` may fire a live event: by user id, never by name. ]]
function Boosts.isOwner(player: Player): boolean
	if table.find(LiveEvents.ownerIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User
		and game.CreatorId > 0
		and player.UserId == game.CreatorId
end

local function setLive(kind: string?, endsAt: number?)
	Workspace:SetAttribute(ATTRIBUTES.liveKind, kind)
	Workspace:SetAttribute(ATTRIBUTES.liveEnds, endsAt)
end

--[[ A live event as a message carries it, from here or another server:
     `{ kind, endsAt }`, or `{ kind = "End" }`. Anything else is dropped. ]]
local function receive(data: unknown)
	if type(data) ~= "table" then
		return
	end
	local message = data :: { [string]: unknown }
	local kind, endsAt = message.kind, message.endsAt
	if kind == "End" then
		setLive(nil, nil)
		return
	end
	if type(kind) ~= "string" or not table.find(LiveEvents.liveKinds, kind) then
		return
	end
	if type(endsAt) ~= "number" or endsAt ~= endsAt then
		return
	end
	local now = LiveState.now()
	local ends = math.min(endsAt, now + LiveEvents.liveSeconds)
	if ends > now then
		setLive(kind, ends)
	end
end

local map: MemoryStoreSortedMap? = nil
local function memory(): MemoryStoreSortedMap?
	if not map then
		local ok, got = pcall(function()
			return MemoryStoreService:GetSortedMap(LiveEvents.memoryMap)
		end)
		map = if ok then got else nil
	end
	return map
end

--[[ Sends a live event to every server, and keeps it for those starting. ]]
local function broadcast(data: { [string]: any })
	local ok, problem = pcall(function()
		MessagingService:PublishAsync(LiveEvents.topic, data)
	end)
	if not ok then
		log.warn("live event not sent to the other servers: %s", tostring(problem))
	end
	local store = memory()
	if store then
		local kept, why = pcall(function()
			if data.kind == "End" then
				store:RemoveAsync(KEY)
			else
				store:SetAsync(KEY, data, LiveEvents.liveSeconds + 60)
			end
		end)
		if not kept then
			log.warn("live event not kept for new servers: %s", tostring(why))
		end
	end
end

--[[ `Remotes.LiveEventStart`: the owner fires a live event of `kind`
     ("Luck", "Coins") for `LiveEvents.liveSeconds`, or "End" to stop one.
     Anyone else is turned away and logged. ]]
local function fire(player: Player, kind: unknown)
	if not Boosts.isOwner(player) then
		log.warn("%s (%d) is not an owner: no live event", player.Name, player.UserId)
		return
	end
	local data: { [string]: any }
	if kind == "End" then
		data = { kind = "End" }
	elseif type(kind) == "string" and table.find(LiveEvents.liveKinds, kind) then
		data = { kind = kind, endsAt = LiveState.now() + LiveEvents.liveSeconds }
	else
		return
	end
	receive(data)
	log.info("%s fired a live event: %s", player.Name, tostring(kind))
	task.spawn(broadcast, data)
end

--[[ A Server Luck bought by `player`: `seconds` more of 2x luck for the
     whole server, thanking them on the banner. Called once a receipt, by
     `Data/Purchases`. ]]
function Boosts.addServerLuck(player: Player, seconds: number)
	local now = LiveState.now()
	local endsAt = Workspace:GetAttribute(ATTRIBUTES.luckEnds)
	local ends = LiveBoosts.extend(if type(endsAt) == "number" then endsAt else nil, now, seconds)
	Workspace:SetAttribute(ATTRIBUTES.luckEnds, ends)
	Workspace:SetAttribute(ATTRIBUTES.luckBy, player.DisplayName)
	log.info("%s bought %ds of server luck; it ends in %ds", player.Name, seconds, ends - now)
end

--[[ The egg luck running in this server now (`Data/Hatchery`). ]]
function Boosts.luck(): number
	return LiveState.luck()
end

--[[ What the events add to a run's coin scale now (`Run/RunSession`). ]]
function Boosts.coinShare(): number
	return LiveState.coinShare()
end

--[[ Studio only (`Remotes.DebugClock`): moves this server's clock by
     `seconds` (0 puts it back), for seeing a weekend or a new week. ]]
local function debugClock(_player: Player, seconds: unknown)
	if type(seconds) ~= "number" or seconds ~= seconds then
		return
	end
	local shift = math.clamp(seconds, -SHIFT_MOST, SHIFT_MOST)
	Workspace:SetAttribute(ATTRIBUTES.shift, if shift == 0 then nil else shift)
	log.info("the live clock is moved %ds", shift)
end

local function sweep()
	local now = LiveState.now()
	local liveEnds = Workspace:GetAttribute(ATTRIBUTES.liveEnds)
	if type(liveEnds) == "number" and liveEnds <= now then
		setLive(nil, nil)
	end
	local luckEnds = Workspace:GetAttribute(ATTRIBUTES.luckEnds)
	if type(luckEnds) == "number" and luckEnds <= now then
		Workspace:SetAttribute(ATTRIBUTES.luckEnds, nil)
		Workspace:SetAttribute(ATTRIBUTES.luckBy, nil)
	end
end

function Boosts.start()
	Inbound.on(Remotes.LiveEventStart, fire)
	Inbound.debug(Remotes.DebugClock, debugClock)
	local function mark(player: Player)
		if Boosts.isOwner(player) then
			player:SetAttribute(LiveEvents.ownerAttribute, true)
		end
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
	task.spawn(function()
		local ok, problem = pcall(function()
			MessagingService:SubscribeAsync(LiveEvents.topic, function(message)
				receive(message.Data)
			end)
		end)
		if not ok then
			log.warn("not listening for live events: %s", tostring(problem))
		end
		-- one already running when this server started
		local store = memory()
		if store then
			local read, data = pcall(function()
				return store:GetAsync(KEY)
			end)
			if read and data ~= nil and Workspace:GetAttribute(ATTRIBUTES.liveKind) == nil then
				receive(data)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SWEEP)
			sweep()
		end
	end)
end

return Boosts
