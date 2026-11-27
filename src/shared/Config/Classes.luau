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
--[[ Where a blow lands (`Shared/Combat/SwingBox`): the side-to-side blows
     hit an arc, `reach` studs out and `arc` degrees wide; the combo's last
     blow, the slam, a circle `slamRadius` across, `slamAhead` in front. ]]
export type Swing = {
	reach: number,
	arc: number,
	slamRadius: number,
	slamAhead: number,
	damage: { number },
	--[[ Untouchable for the whole swing, from its start until its clip
	     ends (owner, 2026-10-23: "if the warden is mid swing of his sword
	     he should be invulnerable", then "keep it to the whole swing"). ]]
	guard: boolean?,
	--[[ The share of an enemy's own knockback each blow of the combo gives,
	     when not all of it. Every hit still shoves (owner, 2026-10-25), but
	     a class that strikes twice a second at arm's length would shove
	     everything out of its own reach. ]]
	knock: { number }?,
}

--[[ A dash of the class's own (`Shared/Combat/DashCut`, `Combat/MeleeSystem`;
     the Assassin's Shadow Dash): it comes back in `cooldown` seconds in
     place of `Balance.Player.dash.cooldown`, strikes every enemy within a
     cut `width` studs across along the ground it covered for `damage`
     times a strike, and nothing can hurt the dasher from its start until
     `guard` seconds after it ends: it goes through enemies, so it must get
     out the other side. ]]
export type Dash = {
	cooldown: number,
	damage: number,
	width: number,
	guard: number,
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
	--[[ Present for a class whose dash cuts. ]]
	dash: Dash?,
}

local Classes: { [string]: Class } = {
	--[[ Fast, fragile, long range: the base numbers as tuned. ]]
	Ranger = {
		weapon = "TwigBow",
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
		weapon = "BranchStaff",
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
		weapon = "TimberBlade",
		damageScale = 1.6,
		cooldownScale = 1.2,
		--[[ It has to stand among the enemies, so it can take more of them
		     (owner, 2026-10-23: "the warden needs to be tankier", twice: 1.6,
		     then this). ]]
		healthScale = 2.2,
		speedScale = 1,
		innate = {},
		look = "Arrow",
		--[[ Was 7, then 8 deep and 9 wide: "that is too close" (owner,
		     2026-10-23). ]]
		reach = 10,
		--[[ About the old 10 × 11 box's ground: an arc 11 out and 100°
		     wide, and a slam circle 5 across, 5.5 in front, reaching 10.5,
		     past `reach`. ]]
		swing = {
			reach = 11,
			arc = 100,
			slamRadius = 5,
			slamAhead = 5.5,
			damage = { 1, 1, 1.5 },
			guard = true,
		},
	},
	--[[ Twin daggers (owner, 2026-11-15: "we need to create the assassin
	     class now", and yes to option A, "twin daggers up close"): about two
	     strikes a second, each lighter than an arrow, on what is right in
	     front of it: a slash from each hand, a narrow arc, then both daggers
	     driven in together, 1.5x in a small circle.

	     What keeps it alive (Studio, 2026-11-16, a bot through Mossy Glade
	     1-1's ten rooms): with the Ranger's 225 health and no guard it died
	     in room 4, 5 and 5; with half as much health again (338; owner,
	     2026-11-16, "Yes, 1.5x health") it still died in room 5, and in
	     room 7 dashing every time the dash was back, about a hit for every
	     two kills: a class that stands 8 studs from what it hits is in
	     reach of all of it. So its strikes guard it as the Warden's do
	     (`swing.guard`: nothing lands mid-strike; owner, 2026-11-16, "Keep
	     the guard"), and it keeps the 1.5x:
	     the same bot then won twice, on 34% and 93% health, the second
	     time never dashing. Still well under the Warden's 495, with a
	     shorter, narrower swing. ]]
	Assassin = {
		weapon = "SplinterDaggers",
		damageScale = 0.75,
		cooldownScale = 0.7,
		healthScale = 1.5,
		speedScale = 1,
		innate = {},
		look = "Arrow",
		--[[ Closer than the Warden's 10: a dagger is short. ]]
		reach = 8,
		--[[ An arc 8.5 out and 70 degrees wide for the slashes; the stab a
		     circle 7 across, from just in front of the feet out to `reach`. ]]
		swing = {
			reach = 8.5,
			arc = 70,
			slamRadius = 3.5,
			slamAhead = 4.5,
			damage = { 1, 1, 1.5 },
			--[[ A slash shoves a third as far as a hit usually does, the
			     stab all the way: seen in Studio (2026-11-16), full shoves
			     put a 3 stud gap between every strike and the next, and
			     four strikes cleared the dummies out of reach. ]]
			knock = { 0.35, 0.35, 1 },
			guard = true,
		},
		--[[ Shadow Dash, the class's skill (owner, 2026-11-15): the dash
		     cuts what it passes through, 1.5x a strike, and is back in 2.5 s
		     where every other class waits 4.

		     Its guard after landing was 0.2 s: in the release check's bot
		     the Assassin took the most damage of the four, 9 to 17 would-be
		     deaths a level from 1-4 on against the Warden's 0 to 7 (owner,
		     2026-11-27: "Longer dash guard", not more health). ]]
		dash = {
			cooldown = 2.5,
			damage = 1.5,
			width = 5,
			guard = 0.75,
		},
	},
}

return table.freeze(Classes)
