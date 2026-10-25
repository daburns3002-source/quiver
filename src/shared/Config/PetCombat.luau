--!strict
--[[
	What each pet does in a run (docs/PETS-FOREST.md, Attacks), keyed by its
	`Config/PetModels` name. `Combat/PetCombat` runs it on the server; the
	look (the Attack clip and its pieces, `Config/PetAttacks`) plays on the
	clients in step with it.

	PLACEHOLDER NUMBERS (2026-10-24): the owner balances them. For scale, the
	player's arrow does 100 and the area 1 enemies have 150 to 1,200 health;
	the player has 225.

	Which pet a player has is their `Pet` attribute. Until Phase 6 brings
	eggs and equipping, only the Studio sandbox sets it.

	A pet looks for enemies within `range` studs of its owner (60 covers a
	room; the Fern Frog's tongue is short), nearest first, every `every` seconds; with none in range it waits (a support
	pet's heal, guard or pull goes off regardless).
]]

export type Spec = {
	--[[ Seconds between attacks, and studs from the owner it reaches. ]]
	every: number,
	range: number,
	--[[ Damage a hit, how many hits land on each target, and how many
	     enemies it hits, nearest first. ]]
	damage: number?,
	hits: number?,
	targets: number?,
	--[[ Instead of `targets`: every enemy in a line this many studs wide
	     from the owner toward the nearest one, out to `range`. ]]
	beam: number?,
	--[[ Extra damage against a boss (the Slime Prince's crown shockwave). ]]
	bossDamage: number?,
	--[[ A hit enemy moves at `scale` of its speed for `duration` seconds;
	     `root` holds it still that many seconds. ]]
	slow: { scale: number, duration: number }?,
	root: number?,
	--[[ A hit enemy burns at `rate` damage a second for `duration` (stacks
	     with Blaze the way two burns do: the stronger rate wins). ]]
	burn: { rate: number, duration: number }?,
	--[[ The nearest enemy takes `scale` times the damage for `duration`. ]]
	mark: { scale: number, duration: number }?,
	--[[ Health back to the owner per enemy hit. ]]
	healPerHit: number?,
	--[[ A patch under the owner healing `perSecond` while they stand within
	     `radius` of it, for `duration` seconds. ]]
	heal: { perSecond: number, duration: number, radius: number }?,
	--[[ The shell is up again: it blocks the owner's next hit. ]]
	guard: boolean?,
	--[[ Pulls every XP crystal in the room to the owner. ]]
	magnet: boolean?,
	--[[ Every `every`th attack, the owner attacks `bonus` faster for
	     `duration` seconds (the Ember Wilf's howl). ]]
	haste: { bonus: number, duration: number, every: number }?,
	--[[ Once a run, a killing blow leaves the owner at this share of their
	     max health instead (the Glimmerhorn). ]]
	revive: number?,
}

local PetCombat: { pets: { [string]: Spec } } = {
	pets = {
		-- Slime Glob: a blob that slows
		Mosslet = { every = 2, range = 60, damage = 30, slow = { scale = 0.5, duration = 1.5 } },
		-- Acorn Flick: a burst of three pellets
		Babacorn = { every = 2.5, range = 60, damage = 20, hits = 3 },
		-- Tongue Snap: short and hard
		FernFrog = { every = 3, range = 14, damage = 70 },
		-- Spore Patch: a healing ring
		ToadstoolTot = { every = 20, range = 0, heal = { perSecond = 6, duration = 3, radius = 6 } },
		-- Shell Guard: blocks one hit
		MossbackSnail = { every = 20, range = 0, guard = true },
		-- Lantern Lure: pulls the crystals in, marks one enemy
		FireflyBun = { every = 6, range = 60, magnet = true, mark = { scale = 1.25, duration = 4 } },
		-- Root Snare: holds one enemy still
		Stumpy = { every = 4, range = 60, damage = 25, root = 1 },
		-- Leaf Dash: slashes up to three
		GladeFox = { every = 3, range = 60, damage = 45, targets = 3 },
		-- Feather Volley: homing feathers over walls and cover
		Hootmoss = { every = 3, range = 80, damage = 25, targets = 4 },
		-- Royal Court: two mini slimes, a crown shockwave against bosses
		SlimePrince = { every = 4, range = 60, damage = 40, targets = 2, bossDamage = 80 },
		-- Ember Bite: fire bolts that burn, and a howl that speeds attacks
		EmberWilfPet = {
			every = 3,
			range = 60,
			damage = 35,
			burn = { rate = 15, duration = 3 },
			haste = { bonus = 0.25, duration = 3, every = 3 },
		},
		-- Prism Beam: pierces a line, heals per hit, revives once a run
		Glimmerhorn = { every = 4, range = 60, damage = 60, beam = 3, healPerHit = 3, revive = 0.5 },
	},
}

return table.freeze(PetCombat)
