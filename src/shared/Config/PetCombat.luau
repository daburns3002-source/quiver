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
	pet's heal or pull goes off regardless). A guard is not on the clock:
	see `guard`.
]]

local PetDash = require(script.Parent.Parent.Util.PetDash)
local RootHold = require(script.Parent.Parent.Util.RootHold)

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
	--[[ A hit enemy moves at `scale` of its speed for `duration` seconds. ]]
	slow: { scale: number, duration: number }?,
	--[[ A hit enemy is held where it stands for `duration` seconds (a boss
	     for `boss`): no walking, lunging, diving or sliding with a shove,
	     though it still attacks from there (`Shared/Util/RootHold`). ]]
	root: RootHold.Root?,
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
	--[[ Once a room: as each room or wave begins (and as the pet joins) its
	     shell is up, and it blocks the owner's next hit. The pet plays its
	     Attack, flying in front of the owner, when it blocks, not on a clock:
	     `every` is not used. ]]
	guard: boolean?,
	--[[ Pulls every XP crystal in the room to the owner. ]]
	magnet: boolean?,
	--[[ Every `every`th attack, the owner attacks `bonus` faster for
	     `duration` seconds (the Ember Wilf's howl). ]]
	haste: { bonus: number, duration: number, every: number }?,
	--[[ Once a run, a killing blow leaves the owner at this share of their
	     max health instead (the Glimmerhorn). ]]
	revive: number?,
	--[[ The pet runs to each target and strikes as it lands, then runs back
	     (the Glade Fox's Leaf Dash; `Shared/Util/PetDash`). ]]
	dash: PetDash.Dash?,
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
		-- Shell Guard: blocks one hit a room
		MossbackSnail = { every = 0, range = 0, guard = true },
		-- Lantern Lure: pulls the crystals in, marks one enemy
		FireflyBun = { every = 6, range = 60, magnet = true, mark = { scale = 1.25, duration = 4 } },
		-- Root Snare: holds one enemy still (owner, 2026-10-26: "stumpy needs to
		-- hold enemies in place"). Held under half the time, so a room still
		-- has to be fought; bosses are not held: their moves are timelines
		Stumpy = { every = 4, range = 60, damage = 25, root = { duration = 1.75, boss = 0 } },
		-- Leaf Dash: slashes up to three
		GladeFox = {
			every = 3,
			range = 60,
			damage = 45,
			targets = 3,
			-- runs to each one (owner, 2026-10-25), timed to its Attack clip's
			-- own lunge: out at 0.17 s, landed at 0.37, back from 0.57 to 0.8
			dash = {
				speed = 70,
				windup = 0.17,
				slash = 0.2,
				shortest = 0.2,
				longest = 0.55,
				radius = 0.8,
				gap = 0.3,
				reach = 2,
				clip = {
					name = "Attack",
					root = "Rig",
					out = 0.167,
					hit = 0.367,
					back = 0.567,
					home = 0.8,
				},
			},
		},
		-- Feather Volley: homing feathers over walls and cover
		Hootmoss = { every = 3, range = 80, damage = 25, targets = 4 },
		-- Royal Court: two mini slimes, a crown shockwave against bosses
		SlimePrince = { every = 4, range = 60, damage = 50, targets = 2, bossDamage = 80 },
		-- Ember Bite: fire bolts that burn, and a howl that speeds attacks
		EmberWilfPet = {
			every = 3,
			range = 60,
			damage = 35,
			burn = { rate = 15, duration = 3 },
			haste = { bonus = 0.25, duration = 3, every = 3 },
		},
		-- Prism Beam: pierces a line, heals per hit, revives once a run
		Glimmerhorn = { every = 4, range = 60, damage = 80, beam = 3, healPerHit = 3, revive = 0.5 },

		--[[ Thornwood (area 2). Each one is its Mossy Glade counterpart's
		     trick at this area's strength: damage is the forest pet's times
		     `WeaponStats.areaScale[2]` (1.125), rounded, because area 2's
		     enemies carry 0.9 health against area 1's 0.8 and a pet has to
		     keep up the same way a weapon does.

		     The shapes are deliberately the forest's -- a slow, a guard, a
		     root, a mark, a volley, a burn-and-haste, a court, a beam -- so
		     every kind of pet exists in both areas and a player who learned
		     one knows the other. What changes is the flavour and the
		     numbers. ]]

		-- Bark Charge: a short, hard ram
		BarkHoglet = { every = 3, range = 16, damage = 79 },
		-- Burr Toss: three burrs off its back
		Burrball = { every = 2.5, range = 60, damage = 22, hits = 3 },
		-- Spore Puff: a cloud that slows
		Budbulb = { every = 2, range = 60, damage = 34, slow = { scale = 0.5, duration = 1.5 } },
		-- Berry Cache: a patch that feeds whoever stands in it
		BerryMouse = { every = 18, range = 0, heal = { perSecond = 7, duration = 3, radius = 6 } },
		-- Thistle Shell: blocks one hit a room
		ThistleMole = { every = 0, range = 0, guard = true },
		-- Briar Snare: holds one enemy still; bosses are not held
		BriarBeetle = { every = 4, range = 60, damage = 28, root = { duration = 1.75, boss = 0 } },
		-- Berry Mark: paints one target softer
		BerryBat = { every = 6, range = 70, damage = 26, mark = { scale = 1.3, duration = 4 } },
		-- Bramble Swipe: one blow across three
		BrambleBear = { every = 3, range = 60, damage = 51, targets = 3 },
		-- Thorn Darts: four that follow
		BriarLynx = { every = 3, range = 80, damage = 28, targets = 4 },
		-- Thorn Bite: bolts that burn, and a howl that speeds attacks
		BrambleWilf = {
			every = 3,
			range = 60,
			damage = 39,
			burn = { rate = 17, duration = 3 },
			haste = { bonus = 0.25, duration = 3, every = 3 },
		},
		-- Court of Thorns: two spirits, a shockwave against bosses
		ThornPrincess = { every = 4, range = 60, damage = 56, targets = 2, bossDamage = 90 },
		-- Briar Beam: pierces a line, heals per hit, revives once a run
		Thornwake = { every = 4, range = 60, damage = 90, beam = 3, healPerHit = 3, revive = 0.5 },
	},
}

return table.freeze(PetCombat)
