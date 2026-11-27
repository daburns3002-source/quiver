--!strict
--[[
	Victory's three chests (`Config/Rewards.victory`; owner, 2026-11-14:
	"there should be more rewards for players"): every level won offers
	three shut chests and the player opens one. Pure, so the server rolls
	with it (`Run/VictoryChests`) and `tests/VictoryChests.spec` pins it.

	**The server rolls all three before the screen shows any**, and tells
	the client nothing about them until one is picked: the client sends
	which chest (1 to 3) and nothing else, and only then learns what was in
	each. A changed client can pick a chest, as anyone can; it cannot see
	inside first, pick twice, or pick a fourth.

	Each chest is rolled by itself from the same table, so the pick is a
	real one and the three are worth, on average, what one roll is. Mostly
	coins (a share of the area's clear bonus), sometimes a few gems, and
	rarely the area's own egg or weapon crate, free. Never more than that:
	the store's gems keep their price (`Config/Rewards`), and an egg or a
	crate gives what buying one would.
]]

local Rewards = require(script.Parent.Parent.Config.Rewards)
local Shop = require(script.Parent.Parent.Config.Shop)
local ShopRules = require(script.Parent.ShopRules)

local VictoryChestRules = {}

--[[ What a chest holds: "coins" or "gems" and how many, or one "egg" or
     "crate". ]]
export type Prize = { kind: string, amount: number }

VictoryChestRules.COUNT = Rewards.victory.chests

--[[ Coins are paid in fives, and never none. ]]
local function coins(clearCoins: number, share: number): number
	return math.max(5, math.floor(math.max(0, clearCoins) * share / 5 + 0.5) * 5)
end

--[[ One chest. `roll` gives a number from 0 up to 1 each time it is
     called (the server's `Random`; a spec's own). ]]
function VictoryChestRules.one(clearCoins: number, roll: () -> number): Prize
	local total = 0
	for _, entry in Rewards.victory.prizes do
		total += entry.weight
	end
	local at = math.clamp(roll(), 0, 1) * total
	local chosen = Rewards.victory.prizes[1]
	for _, entry in Rewards.victory.prizes do
		chosen = entry
		at -= entry.weight
		if at < 0 then
			break
		end
	end
	local size = chosen.low + (chosen.high - chosen.low) * math.clamp(roll(), 0, 1)
	if chosen.kind == "coins" then
		return { kind = "coins", amount = coins(clearCoins, size) }
	elseif chosen.kind == "gems" then
		return { kind = "gems", amount = math.floor(size + 0.5) }
	end
	return { kind = chosen.kind, amount = 1 }
end

--[[ The three chests of a win, in the order they stand. ]]
function VictoryChestRules.three(clearCoins: number, roll: () -> number): { Prize }
	local out = {}
	for _ = 1, VictoryChestRules.COUNT do
		table.insert(out, VictoryChestRules.one(clearCoins, roll))
	end
	return out
end

--[[ Which chest a client asked for: 1 to 3, or nil for anything else. ]]
function VictoryChestRules.pick(index: unknown): number?
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 then
		return nil
	end
	return if index >= 1 and index <= VictoryChestRules.COUNT then index else nil
end

--[[ What an egg or a crate that cannot be given is paid as (an area with
     no egg yet, no crate with a weapon for the class): the biggest coins a
     chest can hold. ]]
function VictoryChestRules.instead(clearCoins: number): Prize
	local most = 0
	for _, entry in Rewards.victory.prizes do
		if entry.kind == "coins" then
			most = math.max(most, entry.high)
		end
	end
	return { kind = "coins", amount = coins(clearCoins, most) }
end

--[[ The crate `area`'s chest opens for a player of `class`: that area's
     own (`Config/Shop.crates`), if it has a weapon for them. ]]
function VictoryChestRules.crate(area: string?, class: string?): number?
	for index, crate in Shop.crates do
		if crate.area == area and #ShopRules.cratePool(index, class) > 0 then
			return index
		end
	end
	return nil
end

return VictoryChestRules
