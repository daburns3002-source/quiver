--!strict
--[[
	Roblox's experience notifications on the server (`Config/Notifications`,
	rules in `Util/NotifyRules`, `docs/NOTIFICATIONS.md`).

	**Asking.** Each session that loads counts one (`NotifyRules.joined`).
	Just after a daily reward is claimed (`Rewards.dailyClaimed`) the rules
	say whether to ask; if so the player is sent `Remotes.NotifyAsk` and
	`Client/UI/NotifyPrompt` asks at the next quiet moment, Roblox's own
	opt-in behind YES. The answer comes back on `Remotes.NotifyAnswer` and
	is taken only while this server is waiting for one, so a client cannot
	write answers it was never asked for. A YES is the only thing a client
	says that matters here, and all it can do is have Roblox ping itself.

	**Sending** (only with the owner's `send` switch on): as an opted-in
	player leaves, their plan (`NotifyRules.plan`) goes into the shared
	queue (`Data/NotifyQueue`), and as they join it is taken out. Every
	server sends what is due through `Data/NotifySender`.

	**Hooks for the other systems.** The weekend event, the season and the
	set rotation each tell this module when their next start is, and when
	it ends, with `Notify.upcoming(kind, provider)`: `provider(now)`
	returns `(startsAt, endsAt?)` in Unix seconds, or nil when nothing is
	coming. It is asked as each player leaves. Kinds are
	`Config/Notifications.kinds` ("event", "season", "rotation"). The
	weekend event and the set rotation run on the clock (`Util/LiveBoosts`,
	`Util/SetRotation`), so they are hooked here; the season hooks itself.

	Studio only: `Remotes.DebugNotifyAsk:FireServer()` asks this player at
	once, and the question shows even where Roblox says it cannot ask, so
	it can be looked at.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GiftRules = require(ReplicatedStorage.Shared.Util.GiftRules)
local LiveBoosts = require(ReplicatedStorage.Shared.Util.LiveBoosts)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Notifications = require(ReplicatedStorage.Shared.Config.Notifications)
local NotifyRules = require(ReplicatedStorage.Shared.Util.NotifyRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)
local SetRotation = require(ReplicatedStorage.Shared.Util.SetRotation)

local Inbound = require(script.Parent.Parent.Net.Inbound)
local NotifyQueue = require(script.Parent.NotifyQueue)
local NotifySender = require(script.Parent.NotifySender)
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

local log = Log.forTag("Notify")

local Notify = {}

type Provider = (now: number) -> (number?, number?)

local providers: { [string]: Provider } = {}
--[[ Players this server has asked and not yet heard back from. ]]
local waiting: { [Player]: boolean } = {}
local queue: NotifyQueue.Queue? = nil

--[[ `kind`'s next start (and end), for the plans made as players leave. ]]
function Notify.upcoming(kind: string, provider: Provider)
	assert(Notifications.kinds[kind], `no notification kind {kind}`)
	providers[kind] = provider
end

local function ask(player: Player, preview: boolean)
	waiting[player] = true
	Remotes.event(Remotes.NotifyAsk):FireClient(player, preview)
end

local function answered(player: Player, answer: unknown, zone: unknown)
	if not waiting[player] then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if NotifyRules.answer(profile.notify, answer, Rewards.today(player), zone) then
		waiting[player] = nil
		PlayerData.touch(player)
		log.info("%s answered %s", player.Name, profile.notify.answer)
	end
end

--[[ What is known to begin while the player is away, by kind. ]]
local function upcoming(now: number): { [string]: { at: number, untilAt: number? } }
	local out = {}
	for kind, provider in providers do
		local ok, at, untilAt = pcall(provider, now)
		if ok and type(at) == "number" then
			out[kind] = { at = at, untilAt = if type(untilAt) == "number" then untilAt else nil }
		elseif not ok then
			log.warn("the %s hook failed: %s", kind, tostring(at))
		end
	end
	return out
end

--[[ The plan for this player as they leave now, nil when there is none
     (not opted in, or nothing to say). The queue's own spec builds the
     same from a made-up profile. ]]
function Notify.planFor(user: number, profile: any, today: number, now: number): NotifyRules.Entry?
	local state = profile.notify :: NotifyRules.State
	if not NotifyRules.optedIn(state) then
		return nil
	end
	return NotifyRules.plan({
		user = user,
		now = now,
		zone = state.zone,
		dailyAt = NotifyRules.dailyAt(profile.rewards.loginDay, today, now),
		giftFull = GiftRules.full(profile.gift),
		upcoming = upcoming(now),
	})
end

local function left(player: Player, profile: any)
	waiting[player] = nil
	local q = queue
	if not q then
		return
	end
	local now = os.time()
	local entry = Notify.planFor(player.UserId, profile, RewardRules.day(now), now)
	if entry then
		local ok, err = (pcall :: any)(q.leave, q, entry)
		if not ok then
			log.warn("could not queue %s: %s", player.Name, tostring(err))
		end
	end
end

local function joined(player: Player)
	local profile = PlayerData.get(player)
	if profile then
		NotifyRules.joined(profile.notify)
		PlayerData.touch(player)
	end
	local q = queue
	if q then
		local ok, err = (pcall :: any)(q.back, q, player.UserId)
		if not ok then
			log.warn("could not unqueue %s: %s", player.Name, tostring(err))
		end
	end
end

--[[ The next weekend that begins after `now`, and when it ends. ]]
local function nextWeekend(now: number): (number?, number?)
	local _, start = LiveBoosts.nextWeekend(now)
	if start <= now then
		_, start = LiveBoosts.nextWeekend(now + SetRotation.WEEK)
	end
	return start, SetRotation.weekStart(SetRotation.week(start) + 1)
end

--[[ The next Monday the sets change, and the Monday after. ]]
local function nextRotation(now: number): (number?, number?)
	local at = now + SetRotation.left(now)
	return at, at + SetRotation.WEEK
end

function Notify.start()
	Notify.upcoming("event", nextWeekend)
	Notify.upcoming("rotation", nextRotation)
	--[[ The owner's switch, a message to send, and a live server: Studio's
	     MemoryStore is its own, and its playtests have no secrets. ]]
	if Notifications.send and not RunService:IsStudio() then
		queue = NotifyQueue.new(NotifyQueue.memoryStore(), NotifySender.send)
	end
	PlayerData.onLoaded(joined)
	PlayerData.onLeaving(left)
	Rewards.dailyClaimed = function(player: Player)
		local profile = PlayerData.get(player)
		if profile and NotifyRules.shouldAsk(profile.notify, Rewards.today(player)) then
			ask(player, false)
		end
	end
	Inbound.on(Remotes.NotifyAnswer, answered)
	Players.PlayerRemoving:Connect(function(player)
		waiting[player] = nil
	end)
	if RunService:IsStudio() then
		Inbound.debug(Remotes.DebugNotifyAsk, function(player)
			ask(player, true)
		end)
	end
	local q = queue
	if q then
		task.spawn(function()
			while true do
				task.wait(Notifications.poll)
				local ok, result = pcall(q.poll, q, os.time())
				if not ok then
					log.warn("poll failed: %s", tostring(result))
				elseif result > 0 then
					log.info("sent %d", result)
				end
			end
		end)
	end
end

return Notify
