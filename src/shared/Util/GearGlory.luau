--!strict
--[[
	How grand an owned weapon or pet is drawn (owner, 2026-11-14: "it should
	feel more grand to own a mythic, legendary or high merge tier"). One
	number, so the Gear screen's tiles, slots and cards all agree
	(`UI/Chunky.grand`):

	- 0: nothing extra.
	- 1: a Legendary, or anything merged to tier A: turning rays behind it,
	  a breathing glow, sparkles on its corners.
	- 2: a Mythic, or anything merged to tier S: brighter and faster, stars
	  rising off it, and the picture itself breathing.

	Rarity and tier each give a rank and the greater counts: a Common merged
	all the way to S is as grand as a Mythic, which is the point of merging.
	Pure, so `tests/GearGlory.spec` pins it.
]]

local GearGlory = {}

local BY_RARITY: { [string]: number } = { Legendary = 1, Mythic = 2 }
local BY_TIER: { [string]: number } = { A = 1, S = 2 }

--[[ The rank of an item of `rarity` whose best merge tier is `tier` (nil
     for one with no tier). ]]
function GearGlory.rank(rarity: string?, tier: string?): number
	local byRarity = if rarity then BY_RARITY[rarity] or 0 else 0
	local byTier = if tier then BY_TIER[tier] or 0 else 0
	return math.max(byRarity, byTier)
end

--[[ The word over a grand item's card, nil for a plain one: what makes it
     grand, the tier when that is what counts for more. ]]
function GearGlory.banner(rarity: string?, tier: string?): string?
	local byRarity = if rarity then BY_RARITY[rarity] or 0 else 0
	local byTier = if tier then BY_TIER[tier] or 0 else 0
	if byRarity == 0 and byTier == 0 then
		return nil
	end
	if byTier > byRarity then
		return "TIER " .. (tier :: string) .. "!"
	end
	return string.upper(rarity :: string) .. "!"
end

return GearGlory
