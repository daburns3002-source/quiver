--!strict
--[[
	What an ability actually does.

	The only place in the project that knows what an ability id means. Config
	owns *how much*, this owns *what*, and the firing code owns neither — so
	adding an ability is a row in `Config/Abilities` plus a case here, and
	never a branch in `FiringSystem`. See CLAUDE.md, non-negotiable 1.

	**Everything is derived from the stack counts, every time.** There is no
	incremental state: `Loadout` hands over "you have two Front Arrow and one
	Piercing Shot" and gets back the whole pipeline and the whole stat block.
	That costs a rebuild per level-up, which is nothing, and it buys the thing
	that matters — a loadout cannot drift out of step with the abilities that
	produced it, however many times it is changed, removed or replayed.

	Stats are split by who needs them. Damage and health are outcomes, so the
	server owns them outright. Move speed and dash cooldown are *inputs to
	client prediction* — the client pins `WalkSpeed` every frame and runs the
	dash timer locally — so those are replicated to the client rather than
	being applied server-side where the client would immediately overwrite
	them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Stages = require(ReplicatedStorage.Shared.Combat.Stages)
local Types = require(ReplicatedStorage.Shared.Types)

type ShotStage = Types.ShotStage

local AbilityEffects = {}

export type Counts = { [string]: number }

--[[ What the server applies. ]]
export type ServerStats = {
	damage: number,
	maxHealth: number,
	attackCooldown: number,
	--[[ Health restored per enemy killed. ]]
	healPerKill: number,
	--[[ Whether this run may survive one killing blow. ]]
	secondWind: boolean,
	--[[ Extra damage at full Momentum charge, as a fraction. Zero without it. ]]
	momentumBonus: number,
}

--[[
	What the client needs in order to predict correctly.

	Still not "the player's stats" — nothing that decides an outcome is here.
	But prediction is not only movement: the client draws its own volley and
	skips the server's copy to avoid double-drawing, so if it does not know
	the loadout it draws one unbuffed arrow for ever while the server fires
	the real ones somewhere else. The player then watches an arrow that does
	not exist sail through an enemy that a different, invisible arrow is busy
	killing.

	`abilities` is the stack counts, not a stage list. Stages are functions
	and do not replicate; counts do, and `AbilityEffects.stages` rebuilds the
	identical pipeline from them on either side.
]]
export type ClientStats = {
	moveSpeed: number,
	dashCooldown: number,
	attackCooldown: number,
	abilities: Counts,
}

local function stacks(counts: Counts, id: string): number
	return counts[id] or 0
end

--[[ `base * (1 + per)^n`, so each copy of an ability is worth the same
     fraction of what you already had rather than the same flat amount. Flat
     stacking makes the first copy enormous and the fifth pointless. ]]
local function compounded(base: number, per: number, count: number): number
	return base * (1 + per) ^ count
end

--[[
	The stages this loadout contributes, in no particular order — the pipeline
	sorts them into buckets itself.

	Front Arrow puts extra arrows *beside* the first rather than fanning them
	outwards. They share a heading and start a fraction of a stud apart, so
	the whole volley arrives in the enemy the player aimed at — which is the
	thing a fan stops doing as soon as the target is any distance away.
]]
function AbilityEffects.stages(counts: Counts): { ShotStage }
	local out: { ShotStage } = {}

	local front = stacks(counts, "FrontArrow")
	if front > 0 then
		--[[ One base arrow plus one per stack, side by side rather than
		     fanned. A fan separates with distance and lands one arrow on a
		     target the player aimed every arrow at; a lane does not. ]]
		table.insert(out, Stages.parallel(1 + front, Balance.Projectile.parallelSpacing))
	end

	if stacks(counts, "RearArrow") > 0 then
		table.insert(out, Stages.mirror("RearArrow", { math.pi }))
	end

	if stacks(counts, "SideArrows") > 0 then
		table.insert(out, Stages.mirror("SideArrows", { math.pi / 2, -math.pi / 2 }))
	end

	if stacks(counts, "DiagonalArrows") > 0 then
		local angle = Balance.Projectile.diagonalAngle
		table.insert(out, Stages.mirror("DiagonalArrows", { angle, -angle }))
	end

	local pierce = stacks(counts, "PiercingShot")
	if pierce > 0 then
		table.insert(out, Stages.pierce(Abilities.byId.PiercingShot.value * pierce))
	end

	local swift = stacks(counts, "SwiftArrows")
	if swift > 0 then
		table.insert(
			out,
			Stages.scale("SwiftArrows", "speed", (1 + Abilities.byId.SwiftArrows.value) ^ swift)
		)
	end

	local long = stacks(counts, "LongShot")
	if long > 0 then
		table.insert(
			out,
			Stages.scale("LongShot", "lifetime", (1 + Abilities.byId.LongShot.value) ^ long)
		)
	end

	local blast = stacks(counts, "BlastArrows")
	if blast > 0 then
		--[[ Radius grows per stack; the fraction does not. A splash that also
		     scaled its damage would overtake the arrow that delivered it. ]]
		table.insert(out, Stages.splash(Abilities.byId.BlastArrows.value * blast, 0.5))
	end

	local ricochet = stacks(counts, "Ricochet")
	if ricochet > 0 then
		table.insert(out, Stages.ricochet(Abilities.byId.Ricochet.value * ricochet))
	end

	local bouncyWall = stacks(counts, "BouncyWall")
	if bouncyWall > 0 then
		table.insert(out, Stages.bounce(Abilities.byId.BouncyWall.value * bouncyWall))
	end

	local chain = stacks(counts, "SoulChain")
	if chain > 0 then
		table.insert(out, Stages.chainOnKill(Abilities.byId.SoulChain.value * chain))
	end

	--[[ Crit is one stage carrying the whole loadout's totals rather than one
	     per stack, because chance and multiplier have to be resolved together
	     before the spec leaves the pipeline. ]]
	local deadly = stacks(counts, "DeadlyStrike")
	local overdraw = stacks(counts, "Overdraw")

	if deadly > 0 then
		local chance = Abilities.byId.DeadlyStrike.value * deadly
		--[[ Base payoff is double. Overdraw adds to that, so it is worth
		     nothing without a chance to use it — which is the intended trap,
		     and why it is a separate card rather than part of the first. ]]
		local multiplier = 2 + Abilities.byId.Overdraw.value * overdraw
		table.insert(out, Stages.crit(chance, multiplier))
	end

	return out
end

function AbilityEffects.serverStats(counts: Counts): ServerStats
	local player = Balance.Player

	return {
		damage = compounded(
			player.baseDamage,
			Abilities.byId.Strength.value,
			stacks(counts, "Strength")
		),
		maxHealth = player.maxHealth + Abilities.byId.Vitality.value * stacks(counts, "Vitality"),
		--[[ Divided, not multiplied: the ability reads as "you fire faster",
		     and the number it acts on is the gap between volleys. ]]
		attackCooldown = player.attackCooldown
			/ (1 + Abilities.byId.Precision.value) ^ stacks(counts, "Precision"),
		healPerKill = Abilities.byId.Bloodthirst.value * stacks(counts, "Bloodthirst"),
		secondWind = stacks(counts, "SecondWind") > 0,
		--[[ Additive across stacks rather than compounding. Momentum is
		     already multiplied by the ramp, and compounding a multiplier that
		     is itself scaled by time gets unreadable fast. ]]
		momentumBonus = Abilities.byId.Momentum.value * stacks(counts, "Momentum"),
	}
end

function AbilityEffects.clientStats(counts: Counts): ClientStats
	local player = Balance.Player

	--[[ Copied rather than passed by reference: the server goes on mutating
	     its own counts, and a client-side pipeline rebuilt from a table that
	     changes underneath it would be a very hard bug to see. ]]
	local copy: Counts = table.clone(counts)

	return {
		moveSpeed = compounded(
			player.moveSpeed,
			Abilities.byId.Agility.value,
			stacks(counts, "Agility")
		),
		dashCooldown = player.dash.cooldown
			/ (1 + Abilities.byId.Lightfoot.value) ^ stacks(counts, "Lightfoot"),
		--[[ The same number `serverStats` computes. The client predicts *when*
		     it fires as well as what, so Precision has to reach both or the
		     prediction drifts a little further apart with every volley. ]]
		attackCooldown = AbilityEffects.serverStats(counts).attackCooldown,
		abilities = copy,
	}
end

--[[
	How much an instant ability heals, or 0 if it does not heal.

	Instant abilities are resolved once at the moment they are drafted and
	never stored, so they cannot be expressed as a stack count like everything
	else here. Keeping them in the same module anyway means there is still
	exactly one place that knows what an id does.
]]
function AbilityEffects.instantHeal(id: string, maxHealth: number): number
	if id ~= "Mending" then
		return 0
	end

	return maxHealth * Abilities.byId.Mending.value
end

--[[ Exposed for the tests, which assert the bucket ordering holds for the
     stages above rather than trusting that they were given the right one. ]]
AbilityEffects.Stage = ShotPipeline.Stage

return AbilityEffects
