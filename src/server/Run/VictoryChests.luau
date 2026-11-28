--!strict
--[[
	Victory's three chests, the server's side (`Util/VictoryChestRules`,
	`Config/Rewards.victory`; owner, 2026-11-14: "there should be more
	rewards for players").

	`offer` rolls a winner's three chests as the level is won
	(`RoomController`) and keeps them here, in memory, telling the client
	only that a pick is owed. `Remotes.VictoryChest` from the client carries
	which chest, 1 to 3, and nothing else: the offer is taken away before
	anything is given, so a pick sent twice opens one chest, and a pick with
	no offer opens none. Then the picked chest is given and the client is
	told what was in all three, to draw.

	An offer not picked is dropped by the next win or by leaving: nothing is
	owed for a chest nobody opened. Nothing here is saved.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local VictoryChestRules = require(ReplicatedStorage.Shared.Util.VictoryChestRules)

local EndlessPrizes = require(script.Parent.Parent.Data.EndlessPrizes)
local Hatchery = require(script.Parent.Parent.Data.Hatchery)
local Inbound = require(script.Parent.Parent.Net.Inbound)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local RunSession = require(script.Parent.RunSession)
local Wallet = require(script.Parent.Parent.Data.Wallet)

local log = Log.forTag("VictoryChests")
local opened = Remotes.event(Remotes.VictoryChest)
local random = Random.new()

local VictoryChests = {}

type Offer = {
	prizes: { VictoryChestRules.Prize },
	--[[ The level's area, for its crate; its egg (`Config/Economy`'s
	     `firstClearEgg`); and its clear bonus, which sizes the coins. ]]
	area: string?,
	egg: string?,
	clearCoins: number,
}

local offers: { [Player]: Offer } = {}

--[[ Rolls `player`'s three chests for a level just won. ]]
function VictoryChests.offer(player: Player, area: string?, egg: string?, clearCoins: number)
	offers[player] = {
		prizes = VictoryChestRules.three(clearCoins, function()
			return random:NextNumber()
		end),
		area = area,
		egg = egg,
		clearCoins = clearCoins,
	}
end

--[[ Gives `prize`. Returns what was really given (coins instead of an egg
     or crate there is none of) and, for an egg or a crate, what came out. ]]
local function give(
	player: Player,
	offer: Offer,
	prize: VictoryChestRules.Prize
): (VictoryChestRules.Prize, any)
	if prize.kind == "egg" then
		local key = offer.egg
		local result = if key then Hatchery.grantFree(player, key) else nil
		if key and result then
			return prize,
				{ kind = "Egg", key = key, results = { { pet = result.pet, new = result.new } } }
		end
		prize = VictoryChestRules.instead(offer.clearCoins)
	elseif prize.kind == "crate" then
		local session = RunSession.get(player)
		local class = if session then session.loadout.class else nil
		local index = VictoryChestRules.crate(offer.area, class)
		local weapons = if index then EndlessPrizes.crates(player, index, 1) else {}
		if index and #weapons > 0 then
			return prize, { kind = "Crate", key = index, results = weapons }
		end
		prize = VictoryChestRules.instead(offer.clearCoins)
	end
	if prize.kind == "coins" then
		Wallet.addCoins(player, prize.amount, "Chest", offer.area)
	elseif prize.kind == "gems" then
		Wallet.addGems(player, prize.amount, "Chest", offer.area)
	end
	return prize, nil
end

local function pick(player: Player, index: unknown)
	local chosen = VictoryChestRules.pick(index)
	local offer = offers[player]
	if not chosen or not offer or not PlayerData.get(player) then
		return
	end
	-- taken away first: a second pick finds no offer
	offers[player] = nil
	local prizes = table.clone(offer.prizes)
	local given, reveal = give(player, offer, prizes[chosen])
	prizes[chosen] = given
	log.info("%s opens chest %d: %d %s", player.Name, chosen, given.amount, given.kind)
	PlayerData.touch(player)
	Wallet.send(player)
	opened:FireClient(player, chosen, prizes, reveal)
end

--[[ The run is moving on with chests still shut: in co-op a teammate
     pressed NEXT LEVEL or BACK TO LOBBY before this player had picked, their
     screen went with the run, and the chest was never opened (found
     2026-11-28, the little-kid pass). Each is opened for them, one of the
     three at random. No reveal is sent: there is no screen left to show it
     on. ]]
function VictoryChests.settle()
	-- taken away first: a pick that lands meanwhile finds no offer
	local owed = table.clone(offers)
	table.clear(offers)
	for player, offer in owed do
		if player.Parent and PlayerData.get(player) and #offer.prizes > 0 then
			local chosen = random:NextInteger(1, #offer.prizes)
			local given = give(player, offer, offer.prizes[chosen])
			log.info(
				"%s's chest %d opened for them: %d %s",
				player.Name,
				chosen,
				given.amount,
				given.kind
			)
			PlayerData.touch(player)
			Wallet.send(player)
		end
	end
end

function VictoryChests.start()
	Inbound.on(Remotes.VictoryChest, pick)
	Players.PlayerRemoving:Connect(function(player)
		offers[player] = nil
	end)
end

return VictoryChests
