--!strict
--[[
	The playable classes (docs/WORLD.md). A class is a weapon, a scale on the
	shared base stats, the skills it starts a run already holding, and how its
	shots look. Pure data: `AbilityEffects` reads it alongside the ability
	counts, so a class never needs a branch in the firing code.

	Chosen per player (`Loadout.State.class`). Until a lobby exists the choice
	is a Studio key, C (owner, 2026-10-23).
]]

export type ProjectileLook = "Arrow" | "Orb"

--[[ A melee class's swing (`Combat/MeleeSystem`): every enemy in a box
     `width` studs across and `depth` deep in front of the swinger, facing
     its target, is struck. `damage` multiplies each blow of the weapon's
     combo in turn (`Config/Weapons.clips.fire`), so a slam can land
     harder than a sweep. ]]
export type Swing = {
	width: number,
	depth: number,
	damage: { number },
	--[[ Untouchable while the blade is moving: from each slash's
	     `TrailOn` marker to its `TrailOff` (owner, 2026-10-23: "if the
	     warden is mid swing of his sword he should be invulnerable"). ]]
	guard: boolean?,
}

export type Class = {
	--[[ The `Config/Weapons` entry held in hand. ]]
	weapon: string,
	--[[ Multipliers on `Balance.Player.baseDamage`, `attackCooldown` and
	     `maxHealth`. ]]
	damageScale: number,
	cooldownScale: number,
	healthScale: number,
	--[[ Multiplier on `Balance.Projectile.speed`. The shot lives longer to
	     match, so its reach is the same however fast it flies. ]]
	speedScale: number,
	--[[ Skills held from the start of a run, as ability id → level. They
	     stack with the same skill drafted: drafting it raises the level. ]]
	innate: { [string]: number },
	look: ProjectileLook,
	--[[ Studs within which the class picks a target, when not
	     `Balance.Player.attackRange`: how close a melee class must get. ]]
	reach: number?,
	--[[ Present for a melee class: it swings instead of shooting. ]]
	swing: Swing?,
}

local Classes: { [string]: Class } = {
	--[[ Fast, fragile, long range: the base numbers as tuned. ]]
	Ranger = {
		weapon = "LeafBow",
		damageScale = 1,
		cooldownScale = 1,
		healthScale = 1,
		speedScale = 1,
		innate = {},
		look = "Arrow",
	},
	--[[ Slow attacks that hit hard, and burst (owner, 2026-10-23: "slow,
	     heavy orbs with splash"): half the fire rate, twice the damage, a
	     slower glowing orb, and Blast Arrows' small blast on every shot.
	     Its Mythic is homing (Tracking Eye, to be Homing Orbs). ]]
	Arcanist = {
		weapon = "ArcaneStaff",
		damageScale = 2,
		cooldownScale = 2,
		healthScale = 1,
		speedScale = 0.6,
		innate = { BlastArrows = 1 },
		look = "Orb",
	},
	--[[ The unlockable melee class (docs/WORLD.md; owner, 2026-10-23: the
	     Ruby Greatsword kit). It has to walk into reach, so each swing hits
	     harder than an arrow and strikes everything in front of it; the
	     third blow of the combo is an overhead slam. Its swing takes crit
	     and Blaze from the draft; abilities that shape a volley (more
	     arrows, spread, bounces) have nothing to shape. Numbers to tune. ]]
	Warden = {
		weapon = "RubyGreatsword",
		damageScale = 1.6,
		cooldownScale = 1.2,
		--[[ It has to stand among the enemies, so it can take more of them
		     (owner, 2026-10-23: "the warden needs to be tankier"). ]]
		healthScale = 1.6,
		speedScale = 1,
		innate = {},
		look = "Arrow",
		--[[ Was 7, then 8 deep and 9 wide: "that is too close" (owner,
		     2026-10-23). ]]
		reach = 10,
		swing = { width = 10, depth = 11, damage = { 1, 1, 1.5 }, guard = true },
	},
}

return table.freeze(Classes)
