--!strict
--[[
	What a prize of free eggs and crates gives (an Endless milestone,
	`Balance.Endless.milestones`; owner, 2026-11-11: "MAKE IT MORE LIKE 5
	EGGS AND 5 CRATES ... I WANT IT TO FEEL NECESSARY TO BEAT THESE ROOMS").

	The rules only: which egg, which crate, and what a guaranteed rarity may
	be. `Server/Data/EndlessPrizes` rolls and grants with them; the server
	alone decides what a player gets.
]]

local EggRules = require(script.Parent.EggRules)
local Eggs = require(script.Parent.Parent.Config.Eggs)
local Shop = require(script.Parent.Parent.Config.Shop)
local ShopRules = require(script.Parent.ShopRules)

local PrizeRules = {}

local ORDER = EggRules.ORDER

--[[ The egg a prize hatches: the last one in `Config/Eggs` that is open to
     a player who has beaten these bosses and has pets in it. Nil if there
     is none. ]]
function PrizeRules.eggKey(bossesBeaten: { [string]: boolean }): string?
	local best: string? = nil
	for _, egg in Eggs.list do
		if EggRules.open(egg, bossesBeaten) and #EggRules.pool(egg.key) > 0 then
			best = egg.key
		end
	end
	return best
end

--[[ The crate a prize opens for a player of `class`: the furthest area's
     that has weapons for them (`Config/Shop`'s `stocked`). Nil if no crate
     has any. ]]
function PrizeRules.crateIndex(class: string?): number?
	local best: number? = nil
	for index in Shop.crates do
		if #ShopRules.cratePool(index, class) > 0 and (best == nil or index > best) then
			best = index
		end
	end
	return best
end

--[[ The entries of `pool` a guarantee of at least `least` may give: those
     of the lowest rarity at or above it, so a Legendary guarantee gives a
     Legendary and not always the Mythic; the pool's best if nothing in it
     is that rare. Never empty for a pool that is not. ]]
function PrizeRules.guaranteed<T>(pool: { T }, least: string): { T }
	local floor = ORDER[least] or 1
	local lowest: number? = nil
	local highest = 0
	for _, entry in pool do
		local tier = ORDER[(entry :: any).rarity] or 1
		highest = math.max(highest, tier)
		if tier >= floor and (lowest == nil or tier < lowest) then
			lowest = tier
		end
	end
	local want = lowest or highest
	local out: { T } = {}
	for _, entry in pool do
		if (ORDER[(entry :: any).rarity] or 1) == want then
			table.insert(out, entry)
		end
	end
	return out
end

return PrizeRules
