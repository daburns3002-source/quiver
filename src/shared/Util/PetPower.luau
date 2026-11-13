--!strict
--[[
	What a pet does to a room, as one number (owner, 2026-11-02: fix the pet
	rarity ladder).

	`Config/PetCombat` describes every pet in its own terms — bolts, burns,
	thorns, rings, foam — so two pets' specs cannot be read side by side,
	and the ladder had quietly inverted: in both eggs the Epic was the
	hardest hitter, the Mythic did less than the Common, and the Rare did
	about a third of the Common (`docs/BALANCE-REPORT.md`, 2026-11-01).

	This puts them on one scale so `tests/PetPower.spec` can hold the ladder
	up, and so retuning one pet shows what it did to its neighbours.

	**It is damage a second against a full room**, not against one enemy:
	everything the pet's own clock puts out, counting each target it names.
	A pet that hits three for 40 is worth three times one that hits one for
	40, because that is what it does to a room's health, and hitting more
	than one is what several of these pets are *for*. It is not a quality
	score: a hold, a heal, a guard, a revive, a haste, a mark, a blind, a
	shelter and a canopy are all worth having and none of them is counted
	here. So a pet that reads a little low for its rarity is normal, where
	a pet below a rarer one is not.
]]

local Bleed = require(script.Parent.Parent.Combat.Bleed)
local PetCombat = require(script.Parent.Parent.Config.PetCombat)
local PetCrowd = require(script.Parent.Parent.Util.PetCrowd)
local PetWake = require(script.Parent.Parent.Util.PetWake)
local WeaponStats = require(script.Parent.Parent.Config.WeaponStats)

local PetPower = {}

--[[ What each rarity is aimed at in area 1, as `Config/PetCombat` sets out.
     Uncommon is absent on purpose: every Uncommon so far trades its damage
     for a guard or a shelter, so it is off this scale rather than at the
     bottom of it. ]]
local BAND = {
	Common = 16,
	Rare = 24,
	Epic = 34,
	Legendary = 44,
	Mythic = 56,
} :: { [string]: number }

--[[ The `dps` a pet of this rarity in this area is aimed at, or nil for a
     rarity with no band. An area's pets are scaled like its weapons
     (`Config/WeaponStats.areaScale`), since they face the same health. ]]
function PetPower.band(rarity: string, area: number): number?
	local aimed = BAND[rarity]
	local scale = WeaponStats.areaScale[area]
	if aimed == nil or scale == nil then
		return nil
	end
	-- every pet's `damageScale` raises the bands with them (1.5 since 2026-11-13)
	return aimed * scale * PetCombat.damageScale
end

--[[ How many enemies a beam or a ring is credited with. Both reach as far
     as the room lets them, so unlike `targets` there is no number in the
     spec to read; two is what a room of area 1 or 2 tends to put in front
     of a player at once. ]]
local LINE = 2
local RING = 2

--[[ The Bogheart pets' crowds (`Shared/Util/PetCrowd`) are credited the
     same way: a sneeze, a flop or a burst catches two, a crowd bite has two
     beside its target, and a prism's shards find two others. ]]
local CROWD = 2

--[[ Damage a second against a full room, as the comment above defines it.
     Zero for a pet that does no damage of its own, which three of the
     Drowned Village's five do on purpose. ]]
function PetPower.dps(spec: PetCombat.Spec): number
	local every = spec.every
	--[[ A guard has no clock (`Config/PetCombat`, `guard`): its shell comes
	     back each room and its thorns, if it has any, burst on the hit it
	     blocks. There is no seconds-per-attack to divide by, so it is not
	     on this scale at all. ]]
	if spec.guard or every == nil or every <= 0 then
		return 0
	end

	local targets = spec.targets or 1
	if spec.beam then
		targets = LINE
	end
	if spec.cone or spec.flop or spec.burst then
		targets = CROWD
	end

	local out = 0

	local damage = spec.damage
	if damage then
		local hit = damage * (spec.hits or 1) * targets
		--[[ A payback pet does nothing until its owner is hurt and then
		     swings for `scale` times as much, at most once a cycle. Taking
		     a hit is not optional over a run, so it is credited in full. ]]
		local payback = spec.payback
		if payback then
			hit *= payback.scale
		end
		--[[ One lick in `every` is `scale` times as hard. ]]
		local combo = spec.combo
		if combo then
			hit *= PetCrowd.comboAverage(combo)
		end
		local crowd = spec.crowd
		if crowd then
			hit *= PetCrowd.crowdScale(crowd, CROWD)
		end
		local split = spec.split
		if split then
			hit *= 1 + split.share * math.min(split.shards, CROWD)
		end
		out += hit / every
	end

	--[[ A ring does its own damage on its own clock and `spec.damage` is
	     not used (`Config/PetCombat`, `aura`). ]]
	local aura = spec.aura
	if aura then
		local ticks = aura.duration / aura.every
		out += (aura.damage * ticks * RING) / every
	end

	--[[ Two burns do not sum — the stronger rate wins — so one burn runs
	     per target, and it is only worth the part of the cycle it covers. ]]
	local burn = spec.burn
	if burn then
		out += (burn.rate * math.min(burn.duration, every) * targets) / every
	end

	--[[ Thorns do sum, and build on one target over several attacks, so
	     this is the average rate across the stack rather than its peak. ]]
	local bleed = spec.bleed
	if bleed then
		out += Bleed.rate(bleed, (bleed.stacks + 1) / 2)
	end

	--[[ Foam that only bites an enemy for moving. Credited as though it
	     runs the whole time, which is what it is aimed at. ]]
	local wake = spec.wake
	if wake then
		out += PetWake.total(wake) / every
	end

	return out * PetCombat.damageScale
end

return table.freeze(PetPower)
