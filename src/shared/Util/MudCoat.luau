--!strict
--[[
	A pet's mud coat (`Config/PetCombat` `coat`, the Bog Beaver's Mud
	Plaster): it plasters its owner in mud that soaks up a set amount of
	damage in all, then crumbles. Pure, so the server's soak
	(`Run/RunSession.applyDamage`) and the hatchery's words
	(`Util/PetBlurb`) read one rule, and `tests/MudCoat.spec` pins it.

	The third kind of defensive pet, and kept apart from the other two on
	purpose: the Mossback Snail's shell eats one whole hit however big, the
	Slate Turtle's shelter takes a share off every hit for a moment, and
	the coat is a pool -- small hits vanish into it, a big one breaks
	through with whatever the mud could not hold.
]]

export type Coat = {
	--[[ Damage it soaks in all before it crumbles. ]]
	amount: number,
	--[[ Seconds it lasts if nothing breaks it first. ]]
	duration: number,
}

local MudCoat = {}

--[[ A hit of `amount` against a coat with `left` still in it: what gets
     through, and what the coat has left after. Neither goes below 0. ]]
function MudCoat.soak(left: number, amount: number): (number, number)
	local held = math.clamp(left, 0, math.max(amount, 0))
	return math.max(amount, 0) - held, math.max(left, 0) - held
end

--[[ Most damage a coat can save its owner a second, over a long fight. ]]
function MudCoat.perSecond(coat: Coat, every: number): number
	return if every > 0 then coat.amount / every else 0
end

return table.freeze(MudCoat)
