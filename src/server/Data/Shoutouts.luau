--!strict
--[[
	Hatch shout-outs on the server (`Config/Shoutouts`, `Util/ShoutoutRules`):
	every roll that makes a pet or a crate weapon calls `Shoutouts.rolled`
	(`Data/Hatchery`, `Data/Shop`, `Data/EndlessPrizes`), after the server
	has rolled and granted it, and a Legendary or Mythic is told to every
	client here (`Remotes.Shoutout`, drawn by `UI/Shoutout`). Nothing a
	client sends can make one.

	A Mythic also goes to the game's other servers through MessagingService,
	a chat line there and no banner, one sent per `far.sendGap` seconds and
	one shown per `far.showGap`; a message that is not a shout we would send
	is dropped (`ShoutoutRules.read`). Studio never publishes, so a test
	Mythic cannot reach live servers.
]]

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Shoutouts)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local ShoutoutRules = require(ReplicatedStorage.Shared.Util.ShoutoutRules)

local log = Log.forTag("Shoutouts")

local Shoutouts = {}

local shout = Remotes.event(Remotes.Shoutout)
local lastSent: number? = nil
local lastShown: number? = nil

local function rarityOf(kind: ShoutoutRules.Kind, item: string): string?
	if kind == "Pet" then
		local pet = Pets[item]
		return if pet then pet.rarity else nil
	end
	local entry = ShopRules.find(item)
	return if entry then entry.rarity else nil
end

--[[ `player` has just been given `item` (a `Config/Pets` key for a pet, a
     weapon key for a weapon) by a roll. Shouted if its rarity is loud. ]]
function Shoutouts.rolled(player: Player, kind: ShoutoutRules.Kind, item: string)
	local rarity = rarityOf(kind, item)
	if not ShoutoutRules.loud(rarity) then
		return
	end
	local who = player.DisplayName
	shout:FireAllClients(who, kind, item, rarity, false)
	log.info("%s rolled a %s %s", player.Name, rarity :: string, item)
	if not ShoutoutRules.far(rarity) or RunService:IsStudio() then
		return
	end
	local ok, at = ShoutoutRules.spaced(lastSent, os.clock(), Config.far.sendGap)
	if not ok then
		return
	end
	lastSent = at
	task.spawn(function()
		local sent, err = pcall(function()
			MessagingService:PublishAsync(Config.far.topic, {
				who = who,
				kind = kind,
				item = item,
				rarity = rarity,
				from = game.JobId,
			})
		end)
		if not sent then
			log.warn("could not send a shout to other servers: %s", tostring(err))
		end
	end)
end

--[[ A message from the topic: shown here as a far shout if it is one, from
     another server, outside the gap. Returns whether it was shown. ]]
function Shoutouts.heard(data: unknown, now: number): boolean
	if type(data) == "table" and (data :: any).from == game.JobId then
		return false
	end
	local heard = ShoutoutRules.read(data)
	if not heard then
		return false
	end
	local ok, at = ShoutoutRules.spaced(lastShown, now, Config.far.showGap)
	if not ok then
		return false
	end
	lastShown = at
	shout:FireAllClients(heard.who, heard.kind, heard.item, heard.rarity, true)
	return true
end

function Shoutouts.start()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(Config.far.topic, function(packet)
				Shoutouts.heard(if type(packet) == "table" then packet.Data else nil, os.clock())
			end)
		end)
		if not ok then
			log.warn("not listening for other servers' shouts: %s", tostring(err))
		end
	end)
end

return Shoutouts
