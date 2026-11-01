--!strict
--[[
	A pet's accord (`Config/PetCombat` `accord`, the Abyss Jelly's Deep
	Accord): a canopy over a few enemies that shares out what one of them
	takes. Pure, so the server's split (`Enemies/EnemyManager.damage`) and
	what the hatchery says the pet does (`Util/PetBlurb`) read one rule, and
	`tests/DeepAccord.spec` pins it.

	**It never multiplies damage.** A blow of 300 on a canopy of three is
	three blows of 100, not three of 300 -- the total is exactly what the
	player dealt, every time, and that invariant is the reason this is its
	own module rather than three lines in the damage path. A Mythic that
	quietly trebled every hit would be the strongest thing in the game by a
	distance and nobody would be able to see why.

	What it is worth is reach, not force: one shot that spends itself on a
	nearly-dead enemy instead chips three, and a room with a canopy up falls
	together rather than one at a time.
]]

export type Accord = {
	--[[ The most enemies one canopy joins, the struck one included. ]]
	targets: number,
	--[[ Seconds the canopy holds them. ]]
	duration: number,
}

local DeepAccord = {}

--[[ What each of `living` linked enemies takes of a blow of `amount`.
     `living` counts the struck enemy, so one alone takes the lot. ]]
function DeepAccord.share(amount: number, living: number): number
	if living <= 1 then
		return amount
	end
	return amount / living
end

--[[ What a canopy of `living` enemies takes in total from a blow of
     `amount`: `amount`, always. Here so `tests/DeepAccord.spec` can say so
     in the one place the rule lives. ]]
function DeepAccord.total(amount: number, living: number): number
	return DeepAccord.share(amount, living) * math.max(living, 1)
end

return DeepAccord
