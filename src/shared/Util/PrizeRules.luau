--!strict
--[[
	What a prize of free eggs and crates gives (an Endless milestone,
	`Balance.Endless.milestones`; owner, 2026-11-11: "MAKE IT MORE LIKE 5
	EGGS AND 5 CRATES ... I WANT IT TO FEEL NECESSARY TO BEAT THESE ROOMS").

	The rules only: which egg, which crate, and what a guaranteed rarity may
	be. `Server/Data/EndlessPrizes` rolls and grants with them; the server
	alone decides what a player gets.

	**A prize follows the player's progress, whichever way the launch switch
	is** (the every-class run-through, 2026-11-16: a Ranger who had beaten
	nothing got Bogheart's crate at class level 3 and held an Epic bow at
	damage x1.99 after ten wins). A shop may sell everything while the game
	is in playtest (`Config/Launch.locks` off); a gift may not, or the first
	hour of a playtest is nothing like the first hour of the launch. So both
	rules below read the launch gates as if the switch were on.
]]

local EggRules = require(script.Parent.EggRules)
local Eggs = require(script.Parent.Parent.Config.Eggs)
local LaunchLocks = require(script.Parent.LaunchLocks)
local Shop = require(script.Parent.Parent.Config.Shop)
local ShopRules = require(script.Parent.ShopRules)

local PrizeRules = {}

local ORDER = EggRules.ORDER

--[[ The egg a prize hatches: the last one in `Config/Eggs` that has pets
     in it and that a player who has beaten these bosses has reached, by
     the launch's gates (`LaunchLocks.eggUnlock`). Nil if there is none. ]]
function PrizeRules.eggKey(bossesBeaten: { [string]: boolean }?): string?
	local best: string? = nil
	for _, egg in Eggs.list do
		local unlock = LaunchLocks.eggUnlock(egg, true)
		local reached = unlock == nil or (bossesBeaten ~= nil and bossesBeaten[unlock] == true)
		if reached and #EggRules.pool(egg.key) > 0 then
			best = egg.key
		end
	end
	return best
end

--[[ The crate a prize opens for a player of `class` who has beaten these
     bosses: the furthest area's that has weapons for them (`Config/Shop`'s
     `stocked`) and that they have reached, by the launch's gates
     (`ShopRules.crateOpen`). Nil if no such crate has any. ]]
function PrizeRules.crateIndex(class: string?, bossesBeaten: { [string]: boolean }?): number?
	local best: number? = nil
	for index in Shop.crates do
		if
			ShopRules.crateOpen(index, bossesBeaten, true)
			and #ShopRules.cratePool(index, class) > 0
			and (best == nil or index > best)
		then
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
