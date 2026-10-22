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
	--[[ Share of max health restored per enemy killed. Bloodthirst. ]]
	healPerKill: number,
	--[[ Share of max health restored each second. Mending. ]]
	regenPerSecond: number,
	--[[ Chance, 0 to 1, that a hit on the player misses. Agility. ]]
	dodgeChance: number,
	--[[ Share of max health Second Wind revives with, or 0 without it. ]]
	secondWind: number,
	--[[ Extra damage at full Overdraw charge, as a fraction. ]]
	overdrawBonus: number,
	--[[ Extra attack speed, as a fraction, while Momentum is paying out. ]]
	momentumBonus: number,
}

--[[
	What the client needs in order to predict correctly.

	Still not "the player's stats" — nothing that decides an outcome is here.
	But prediction is not only movement: the client draws its own volley and
	skips the server's copy to avoid double-drawing, so if it does not know
	the loadout it draws one unbuffed arrow for ever while the server fires
	the real ones somewhere else.

	`abilities` is the stack counts, not a stage list. Stages are functions
	and do not replicate; counts do, and `AbilityEffects.stages` rebuilds the
	identical pipeline from them on either side. `momentumBonus` is here
	because Momentum changes *when* the archer fires, which the client
	predicts.
]]
export type ClientStats = {
	moveSpeed: number,
	dashCooldown: number,
	attackCooldown: number,
	momentumBonus: number,
	abilities: Counts,
}

--[[ The ability's total at the level held, or 0 when it is not held. The
     cards say what each level is worth, so a level is looked up rather
     than multiplied. ]]
local function at(counts: Counts, id: string): number
	local level = counts[id] or 0
	if level <= 0 then
		return 0
	end

	local levels = Abilities.byId[id].levels
	return levels[math.min(level, #levels)]
end

--[[ `count` offsets `step` apart, centred on `base` — how a second Rear or
     Side arrow joins the first. ]]
local function around(base: number, count: number, step: number): { number }
	local out: { number } = {}
	local first = -(count - 1) / 2 * step
	for index = 0, count - 1 do
		table.insert(out, base + first + index * step)
	end
	return out
end

--[[
	The stages this loadout contributes, in no particular order — the pipeline
	sorts them into buckets itself; within a bucket they run in the order
	they are added here.
]]
function AbilityEffects.stages(counts: Counts): { ShotStage }
	local out: { ShotStage } = {}
	local projectile = Balance.Projectile
	local player = Balance.Player

	--[[ Front Arrow puts extra arrows *beside* the first rather than fanning
	     them, so the whole volley lands in the enemy the player aimed at. ]]
	local front = at(counts, "FrontArrow")
	if front > 0 then
		table.insert(out, Stages.parallel(1 + front, projectile.parallelSpacing))
	end

	--[[ After Front Arrow, so a lane is repeated as a lane; and Count, so
	     every Pattern stage copies the repeats too. ]]
	local multishot = at(counts, "Multishot")
	if multishot > 0 then
		table.insert(out, Stages.repeatVolley(multishot, projectile.multishotInterval))
	end

	--[[ The narrow fan goes first in Pattern, so the rear, side and
	     diagonal copies are fans as well. ]]
	local double = at(counts, "DoubleShot")
	if double > 0 then
		table.insert(out, Stages.spread(double, projectile.doubleShotSpread))
	end

	local rear = at(counts, "RearArrow")
	if rear > 0 then
		table.insert(
			out,
			Stages.mirror("RearArrow", around(math.pi, rear, projectile.extraArrowSpread))
		)
	end

	local side = at(counts, "SideArrows")
	if side > 0 then
		local offsets = around(math.pi / 2, side, projectile.extraArrowSpread)
		for _, offset in around(-math.pi / 2, side, projectile.extraArrowSpread) do
			table.insert(offsets, offset)
		end
		table.insert(out, Stages.mirror("SideArrows", offsets))
	end

	local diagonal = at(counts, "DiagonalArrows")
	if diagonal > 0 then
		local angle = projectile.diagonalAngle
		local offsets = { angle, -angle }
		if diagonal >= 4 then
			table.insert(offsets, projectile.wideDiagonalAngle)
			table.insert(offsets, -projectile.wideDiagonalAngle)
		end
		table.insert(out, Stages.mirror("DiagonalArrows", offsets))
	end

	local pierce = at(counts, "PiercingShot")
	if pierce > 0 then
		table.insert(out, Stages.pierce(pierce))
	end

	local swift = at(counts, "SwiftArrows")
	if swift > 0 then
		table.insert(out, Stages.scale("SwiftArrows", "speed", 1 + swift))
	end

	local far = at(counts, "LongShot")
	if far > 0 then
		table.insert(out, Stages.farDamage(far))
	end

	--[[ Radius grows with the level; the share does not. A splash that also
	     scaled its damage would overtake the arrow that delivered it. ]]
	local blast = at(counts, "BlastArrows")
	if blast > 0 then
		table.insert(out, Stages.splash(blast, 0.5))
	end

	local ricochet = at(counts, "Ricochet")
	if ricochet > 0 then
		table.insert(out, Stages.ricochet(ricochet))
	end

	local homing = at(counts, "TrackingEye")
	if homing > 0 then
		table.insert(out, Stages.homing(math.rad(homing)))
	end

	local bouncyWall = at(counts, "BouncyWall")
	if bouncyWall > 0 then
		table.insert(out, Stages.bounce(bouncyWall))
	end

	local blaze = at(counts, "Blaze")
	if blaze > 0 then
		table.insert(out, Stages.burn(Balance.Burn.rate, blaze))
	end

	--[[ The link counts the enemy hit; the stage wants the others. ]]
	local link = at(counts, "SoulChain")
	if link > 0 then
		table.insert(out, Stages.link(link - 1))
	end

	--[[ Every archer crits a little; Precision raises the chance and Deadly
	     Strike the payoff. One stage carrying both, because chance and
	     multiplier are resolved together on contact. ]]
	local chance = player.critChance + at(counts, "Precision")
	if chance > 0 then
		local multiplier = player.critMultiplier + at(counts, "DeadlyStrike")
		table.insert(out, Stages.crit(chance, multiplier))
	end

	return out
end

function AbilityEffects.serverStats(counts: Counts): ServerStats
	local player = Balance.Player

	return {
		--[[ Additive across levels, as the cards read: "+30% ATK" is thirty
		     percent of the base, not of the last level. ]]
		damage = player.baseDamage * (1 + at(counts, "Strength")),
		maxHealth = player.maxHealth * (1 + at(counts, "Vitality")),
		attackCooldown = player.attackCooldown,
		healPerKill = at(counts, "Bloodthirst"),
		regenPerSecond = at(counts, "Mending"),
		dodgeChance = at(counts, "Agility"),
		secondWind = at(counts, "SecondWind"),
		overdrawBonus = at(counts, "Overdraw"),
		momentumBonus = at(counts, "Momentum"),
	}
end

--[[
	The gap between volleys right now, with Momentum: shorter for a while
	after the player stops, if they had moved for long enough first.

	One function for both sides. The server decides when the archer fires;
	the client predicts it, and the two only agree if they ask the same
	question of the same numbers.
]]
function AbilityEffects.cooldownAt(
	cooldown: number,
	momentumBonus: number,
	movedFor: number,
	stoppedFor: number
): number
	local momentum = Balance.Player.momentum
	if momentumBonus <= 0 or movedFor < momentum.windup or stoppedFor > momentum.duration then
		return cooldown
	end

	return cooldown / (1 + momentumBonus)
end

function AbilityEffects.clientStats(counts: Counts): ClientStats
	local player = Balance.Player

	--[[ Copied rather than passed by reference: the server goes on mutating
	     its own counts, and a client-side pipeline rebuilt from a table that
	     changes underneath it would be a very hard bug to see. ]]
	local copy: Counts = table.clone(counts)

	return {
		moveSpeed = player.moveSpeed * (1 + at(counts, "Lightfoot")),
		dashCooldown = player.dash.cooldown,
		attackCooldown = player.attackCooldown,
		momentumBonus = at(counts, "Momentum"),
		abilities = copy,
	}
end

--[[
	How much an instant ability heals, or 0 if it does not heal.

	Instant abilities are resolved once at the moment they are drafted and
	never stored, so they cannot be expressed as a level like everything
	else here. Keeping them in the same module anyway means there is still
	exactly one place that knows what an id does.
]]
function AbilityEffects.instantHeal(id: string, maxHealth: number): number
	if id ~= "Heal" then
		return 0
	end

	return maxHealth * Abilities.byId.Heal.levels[1]
end

--[[ Exposed for the tests, which assert the bucket ordering holds for the
     stages above rather than trusting that they were given the right one. ]]
AbilityEffects.Stage = ShotPipeline.Stage

return AbilityEffects
