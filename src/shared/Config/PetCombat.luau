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

local Bleed = require(script.Parent.Parent.Combat.Bleed)
local DeepAccord = require(script.Parent.Parent.Util.DeepAccord)
local PetDash = require(script.Parent.Parent.Util.PetDash)
local PetWake = require(script.Parent.Parent.Util.PetWake)
local RootHold = require(script.Parent.Parent.Util.RootHold)
local Shelter = require(script.Parent.Parent.Util.Shelter)

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
	--[[ A hit enemy carries another thorn, and bleeds the harder for every
	     one it holds (the Bramble Wilf's Thorn Bite; `Shared/Combat/Bleed`).
	     Unlike `burn` these do sum, so the pet pays for staying on one
	     target. ]]
	bleed: Bleed.Bleed?,
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
	--[[ A guard that answers: as the shell blocks, thorns burst from the
	     owner for `damage` to every enemy within `radius` studs (the Thistle
	     Mole's Thorn Shell, owner 2026-10-31). Needs `guard`; it is the only
	     damage such a pet does, and it does it on the hit it blocks rather
	     than on a clock. ]]
	reflect: { damage: number, radius: number }?,
	--[[ Enemies beside the first target that take everything the attack
	     does except its damage — the hold, the slow, the bleed (the Briar
	     Beetle's Chain Snare). Counted on top of `targets`. ]]
	chain: number?,
	--[[ A ring that turns round the owner for `duration` seconds, hurting
	     every enemy within `radius` of them for `damage` every `every`
	     seconds (Thornwake's Wake). Raised afresh on the pet's own clock, so
	     it still plays an Attack; `damage` on the spec itself is not used. ]]
	aura: { damage: number, radius: number, every: number, duration: number }?,
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
	--[[ Drowned Village (docs/PETS-DROWNED.md). Five behaviours that are
	     each a first for the game, which is why each one's rule is its own
	     pure module rather than a number read in the damage path. ]]
	--[[ The owner takes less from everything for a while (the Slate
	     Turtle's Roof Huddle; `Shared/Util/Shelter`). A cut, not a wall:
	     hits still land, nothing is blocked and nobody is untouchable. ]]
	shelter: Shelter.Shelter?,
	--[[ A pet that answers the owner being hurt rather than a clock (the
	     Buoy Puffer's Payback Puff): it arms when its owner takes damage
	     and its next attack, at most one every `every`, hits for `scale`
	     times what it otherwise would. With no damage taken it does
	     nothing at all. ]]
	payback: { scale: number }?,
	--[[ A hit enemy cannot pick a target further than `range` studs away
	     for `duration` seconds (the Inkpot's Ink Blink): it still walks,
	     and still attacks whatever comes close. No slow and no damage. ]]
	blind: { duration: number, range: number }?,
	--[[ Foam on one enemy that bites it for walking (the Tide Wilf's Wake
	     Chase; `Shared/Util/PetWake`). An enemy that stands still takes
	     nothing from it. ]]
	wake: PetWake.Wake?,
	--[[ A canopy joining a few enemies, which share out what any of them
	     takes (the Abyss Jelly's Deep Accord; `Shared/Util/DeepAccord`).
	     It never multiplies damage: the total is what the player dealt. ]]
	accord: DeepAccord.Accord?,
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

		     The six Commons and the two Epics keep the forest's shapes on
		     purpose — a ram, a volley, a slow, a patch, a swipe, a dart
		     flight — so a player who learned one area knows the other.

		     The other six do not. The owner read them back as reskins
		     (2026-10-31) and each was given something the Mossy Glade has
		     no answer to: a guard that hits back, a hold that jumps, a bite
		     that feeds, thorns that stack, a cage that holds a boss, and a
		     ring instead of a beam. Those are the Thornwood egg's reason to
		     exist once a player owns the forest's eight. ]]

		-- Bark Charge: a short, hard ram
		BarkHoglet = { every = 3, range = 16, damage = 79 },
		-- Burr Toss: three burrs off its back
		Burrball = { every = 2.5, range = 60, damage = 22, hits = 3 },
		-- Spore Puff: a cloud that slows
		Budbulb = { every = 2, range = 60, damage = 34, slow = { scale = 0.5, duration = 1.5 } },
		-- Berry Cache: a patch that feeds whoever stands in it
		BerryMouse = { every = 18, range = 0, heal = { perSecond = 7, duration = 3, radius = 6 } },
		--[[ Thorn Shell: blocks one hit a room, and the block answers --
		     thorns burst off the shell into everything close. The Snail's
		     shell only ever absorbed (owner, 2026-10-31). ]]
		ThistleMole = {
			every = 0,
			range = 0,
			guard = true,
			reflect = { damage = 45, radius = 10 },
		},
		--[[ Chain Snare: the hold jumps from the enemy it hits to the one
		     beside it, so a pair is pinned instead of Stumpy's one (owner,
		     2026-10-31). Only the first takes the damage. ]]
		BriarBeetle = {
			every = 4,
			range = 60,
			damage = 28,
			root = { duration = 1.75, boss = 0 },
			chain = 1,
		},
		--[[ Blood Berry: it drinks. Nothing else in the Thornwood egg feeds
		     its owner on a hit, where the mark it used to carry was the
		     Firefly Bun's (owner, 2026-10-31). Bites far more often than the
		     mark did, since a mark lasts and a bite does not.

		     A Common since the owner moved it there, so the drain is a
		     trickle rather than a sustain: 1 a bite, 0.4 a second, against
		     the 2 it drank as a Rare. The damage stands — 10 a second is
		     already the softest of the egg's Commons, and feeding its owner
		     at all is the whole reason to take it. ]]
		BerryBat = { every = 2.5, range = 70, damage = 26, healPerHit = 1 },
		-- Bramble Swipe: one blow across three
		BrambleBear = { every = 3, range = 60, damage = 51, targets = 3 },
		-- Thorn Darts: four that follow
		BriarLynx = { every = 3, range = 80, damage = 28, targets = 4 },
		--[[ Thorn Bite: thorns that stack, so the damage grows the longer
		     its owner stays on one enemy, and a howl that speeds attacks.
		     The Ember Wilf's burn paid the same on every hit; this one has
		     to be earned (owner, 2026-10-31). Nine seconds on one target for
		     a full stack, which only a boss or a brute lives to see.

		     Direct damage is down from 39 because the bleed carries it: 10
		     a second from the bites, up to 36 more from the thorns. ]]
		BrambleWilf = {
			every = 3,
			range = 60,
			damage = 30,
			bleed = { rate = 12, stacks = 3, duration = 7 },
			haste = { bonus = 0.25, duration = 3, every = 3 },
		},
		--[[ Briar Cage: two spirits, and a cage that holds even a boss --
		     the one thing no other pet, weapon or card in the game can do
		     (owner, 2026-10-31). The Slime Prince's extra boss damage is
		     gone: she answers a boss by stopping it, not by hitting it
		     harder.

		     A caged boss stands between its moves rather than mid-move
		     (`Enemies/EnemyManager`), so the cage is a window, not a stun
		     lock: 1.25 of every 5 seconds. ]]
		ThornPrincess = {
			every = 5,
			range = 60,
			damage = 56,
			targets = 2,
			root = { duration = 1.5, boss = 1.25 },
		},
		--[[ The Wake: a ring of thorns turning round its owner that shreds
		     whatever comes near, raised afresh every few seconds so the pet
		     still plays its Attack. The Glimmerhorn's beam, its heal on hit
		     and the whole shape of it are gone (owner, 2026-10-31); the
		     revive stays, because that is a Mythic's promise.

		     `range` is the ring, so the pet only raises it with something
		     near enough to catch. It asks its owner to stand in the fight to
		     earn 18 a second an enemy, where the beam was safe at 60 studs.
		     No heal on hit: a ring over four enemies would never stop
		     healing. ]]
		Thornwake = {
			every = 3,
			range = 12,
			aura = { damage = 14, radius = 12, every = 0.75, duration = 3 },
			revive = 0.5,
		},

		--[[ Drowned Village (docs/PETS-DROWNED.md). PLACEHOLDER NUMBERS, as
		     everything here is, until the owner plays them. Area 3's enemies
		     are not built, so these are aimed at Thornwood's: the Bramble
		     Boar at 900 health hitting for 70.

		     Three of the five do no damage of their own at all. That is on
		     purpose and it is what makes this egg read differently from the
		     first two -- the glade is a pool of little damage dealers, and
		     the village answers with a pet that makes you harder to kill,
		     one that makes an archer useless up close, and one that makes
		     the whole room fall together. ]]
		--[[ Roof Huddle: it tucks in beside you and everything hurts less
		     for a moment. 3 s in every 14 is a fifth off for 21% of a
		     fight, which is worth about a tenth of the player's health
		     against area 2's rooms -- a real defensive pick without being
		     the Snail's flat "one hit did not happen". ]]
		SlateTurtle = {
			every = 14,
			range = 0,
			shelter = { reduction = 0.2, duration = 3 },
		},
		--[[ Payback Puff: nothing at all until its owner is hurt, then one
		     blunt spine at triple weight. Three times a Rare's ordinary 55
		     is 165, about a fifth of a Bramble Boar, and only ever once
		     every 8 s however often the player is hit -- a pet that
		     rewards taking a hit must not reward standing in a fire. ]]
		BuoyPuffer = {
			every = 8,
			range = 60,
			damage = 55,
			payback = { scale = 3 },
		},
		--[[ Ink Blink: ink in one enemy's face. For 3 s it cannot pick a
		     target more than 6 studs off, so a Spitter or a Burr Thistle
		     holding its distance simply stops firing; a melee enemy on top
		     of you is unaffected, which is the trade. No slow, no damage,
		     and a boss ignores it (`Combat/PetCombat`). ]]
		Inkpot = {
			every = 11,
			range = 60,
			blind = { duration = 3, range = 6 },
		},
		--[[ Wake Chase: foam that bites whatever wears it for moving. Four
		     splashes of 45 is 180 against something that runs the whole 3 s
		     and nothing against something that stands -- so it is worth
		     most against exactly the enemies a Legendary should answer,
		     the chargers and the lungers. ]]
		TideWilf = {
			every = 10,
			range = 60,
			wake = { damage = 45, perStud = 3, hits = 4, duration = 3 },
		},
		--[[ Deep Accord: a canopy over three. It adds no damage of its own
		     -- a blow on a linked enemy is split, never copied
		     (`Shared/Util/DeepAccord`) -- and it is a Mythic because of
		     what that does to a room: every shot spends itself on three
		     enemies at once, so a room falls together instead of one at a
		     time, and nothing is left on a sliver of health. ]]
		AbyssJelly = {
			every = 16,
			range = 60,
			accord = { targets = 3, duration = 4 },
		},
	},
}

return table.freeze(PetCombat)
