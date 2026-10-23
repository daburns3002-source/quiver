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

export type Class = {
	--[[ The `Config/Weapons` entry held in hand. ]]
	weapon: string,
	--[[ Multipliers on `Balance.Player.baseDamage` and `attackCooldown`. ]]
	damageScale: number,
	cooldownScale: number,
	--[[ Multiplier on `Balance.Projectile.speed`. The shot lives longer to
	     match, so its reach is the same however fast it flies. ]]
	speedScale: number,
	--[[ Skills held from the start of a run, as ability id → level. They
	     stack with the same skill drafted: drafting it raises the level. ]]
	innate: { [string]: number },
	look: ProjectileLook,
}

local Classes: { [string]: Class } = {
	--[[ Fast, fragile, long range: the base numbers as tuned. ]]
	Ranger = {
		weapon = "LeafBow",
		damageScale = 1,
		cooldownScale = 1,
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
		speedScale = 0.6,
		innate = { BlastArrows = 1 },
		look = "Orb",
	},
}

return table.freeze(Classes)
