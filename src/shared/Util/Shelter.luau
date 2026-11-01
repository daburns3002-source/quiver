--!strict
--[[
	A pet's shelter (`Config/PetCombat` `shelter`, the Slate Turtle's Roof
	Huddle): for a while, its owner takes less from everything. Pure, so the
	server's cut (`Run/RunSession.applyDamage`) and what the hatchery says
	the pet does (`Util/PetBlurb`) read one rule, and `tests/Shelter.spec`
	pins it.

	A cut, not a wall: hits still land, they are simply smaller. It neither
	blocks shots nor grants a moment of invulnerability, and it is not a
	shell -- the Mossback Snail's guard eats one hit whole and this one eats
	a fifth of every hit for three seconds. Keeping them different is the
	point: a player picking a defensive pet is choosing between "one hit
	does not happen" and "every hit for a moment hurts less".
]]

export type Shelter = {
	--[[ The share of a hit taken off, 0 to 1 (0.2 is a fifth less). ]]
	reduction: number,
	--[[ Seconds it lasts, from the moment the pet tucks in. ]]
	duration: number,
}

local Shelter = {}

--[[ What `amount` becomes under a shelter of `reduction`. Clamped at both
     ends: a reduction over 1 would heal the player rather than spare them,
     and one below 0 would make the turtle a liability. ]]
function Shelter.reduce(amount: number, reduction: number): number
	return amount * (1 - math.clamp(reduction, 0, 1))
end

--[[ The share of the time a shelter is up, at most: raised every `every`
     seconds and lasting `duration`. Never above 1 -- a shelter that
     outlasts its own cooldown is simply always on, which is a different
     (and much stronger) thing than a pet that tucks in now and then. ]]
function Shelter.uptime(shelter: Shelter, every: number): number
	return if every > 0 then math.min(1, shelter.duration / every) else 1
end

--[[ The share of incoming damage a shelter stops over a whole fight: its
     cut, for as long as it is up. What the blurb quotes. ]]
function Shelter.averageCut(shelter: Shelter, every: number): number
	return math.clamp(shelter.reduction, 0, 1) * Shelter.uptime(shelter, every)
end

return Shelter
