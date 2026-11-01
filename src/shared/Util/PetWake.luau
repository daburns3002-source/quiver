--!strict
--[[
	A pet's wake (`Config/PetCombat` `wake`, the Tide Wilf's Wake Chase):
	foam splashed onto one enemy that bites it for moving. Pure, so the
	server's count (`Enemies/EnemyManager`) and what the hatchery says the
	pet does (`Util/PetBlurb`) read one rule, and `tests/PetWake.spec` pins
	it.

	It is the opposite of a root. A hold punishes an enemy for being where
	it is; a wake punishes it for leaving, and an enemy that stands still
	takes nothing at all beyond the splash that marked it. Against a charger
	it is most of its damage, against a turret it is none -- which is the
	whole design, and why its damage is counted in hits owed rather than in
	a tick on a clock.

	Only the enemy's own walking counts. A shove from a hit, a lunge's
	slide and anything that moves it without it choosing to are the
	player's doing, not the enemy's, so they must not feed the wake: the
	server measures travel while it walks.
]]

export type Wake = {
	--[[ Damage a splash. ]]
	damage: number,
	--[[ Studs the enemy must cover to owe one splash. ]]
	perStud: number,
	--[[ The most splashes one wake can land before it ends. ]]
	hits: number,
	--[[ Seconds the foam stays on it, however far it runs. ]]
	duration: number,
}

local PetWake = {}

--[[ How many splashes an enemy that has walked `travelled` studs under this
     wake owes, having already taken `landed` of them. Never more than the
     wake has left to give. ]]
function PetWake.owed(wake: Wake, travelled: number, landed: number): number
	if wake.perStud <= 0 then
		return 0
	end
	local earned = math.floor(travelled / wake.perStud)
	return math.max(0, math.min(earned, wake.hits) - landed)
end

--[[ The most one wake can do, if its target runs the whole time. ]]
function PetWake.total(wake: Wake): number
	return wake.damage * wake.hits
end

--[[ The studs an enemy has to cover to take everything a wake has. ]]
function PetWake.reach(wake: Wake): number
	return wake.perStud * wake.hits
end

return PetWake
