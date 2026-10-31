--!strict
--[[
	Thorns that stack on one enemy (`Config/PetCombat` `bleed`, the Bramble
	Wilf's Thorn Bite; owner, 2026-10-31): every attack that lands drives
	another thorn in, up to `stacks`, and the enemy bleeds at `rate` a second
	for each one it carries.

	The clock is the newest thorn's: a fresh one refreshes the whole bleed,
	so a pet that keeps hitting one enemy keeps the stack it has built up and
	one that looks away loses all of it at once. That is the point of the
	pet — it rewards staying on a target, where the Ember Wilf's burn paid
	the same on every hit.

	Deliberately the opposite of a burn, which keeps the stronger rate and
	never sums (`Combat/Burning`): a burn is a bonus on a weapon, a bleed is
	a Legendary's whole trick.

	Pure, so `Combat/Burning` ticks it and `tests/Bleed.spec` pins it.
]]

export type Bleed = {
	--[[ Damage a second each thorn adds, and how many an enemy may carry. ]]
	rate: number,
	stacks: number,
	--[[ Seconds from the newest thorn until the whole bleed lapses. ]]
	duration: number,
}

local Bleed = {}

--[[ How many thorns an enemy already carrying `held` of them has after
     another lands: never past the cap, never less than the one that just
     went in. ]]
function Bleed.stack(bleed: Bleed, held: number): number
	return math.clamp(held + 1, 1, math.max(bleed.stacks, 1))
end

--[[ Damage a second an enemy carrying `held` thorns takes. ]]
function Bleed.rate(bleed: Bleed, held: number): number
	return bleed.rate * math.clamp(held, 0, math.max(bleed.stacks, 1))
end

--[[ The most it can ever do to one enemy: a full stack for its duration.
     What `tests/Bleed.spec` weighs a pet's bleed against. ]]
function Bleed.most(bleed: Bleed): number
	return Bleed.rate(bleed, bleed.stacks) * bleed.duration
end

--[[ Seconds of hitting one enemy every `every` before it carries a full
     stack: the first thorn lands at once, so the last one waits out the
     gaps between them. ]]
function Bleed.ramp(bleed: Bleed, every: number): number
	return math.max(bleed.stacks - 1, 0) * every
end

return Bleed
