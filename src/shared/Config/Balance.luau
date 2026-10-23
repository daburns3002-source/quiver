--!strict
--[[
	Every tunable number in the game. Pure data — no logic, no requires.

	If a gameplay constant is written inline anywhere else, it is a bug.

	**Scaled to Archero 2's proportions.** Measured from 1080x1920 footage: a
	room there is about thirteen player-widths across and taller than it is
	wide, and the camera always shows its full width. Ours was a 90x90 square
	— forty-five player-widths — which no portrait camera could fit. It was
	rebuilt at 28 x 46 with every *room-sized* number scaled to match, then
	enlarged after playtest to 35 x 58 — about seventeen player-widths, a
	little roomier than the footage by choice. Pace in room-widths per second
	still matches theirs: 6.5 studs/s across 35 is 0.19, the footage's 0.19.

	*Body-sized* numbers were deliberately not scaled — hitboxes, melee reach,
	the arrow's width, the orb's size, enemy separation. Those are measured
	against the characters, and the characters did not change size. Where a
	number sits between the two, its comment says which way it went and why.
]]

--[[
	How a wind-up is shown to the player.

	`Flash` recolours the enemy: enough for a fan you dodge by moving at all.
	`Line` draws the actual path the shot will take, which only means anything
	if that path is honest — see `locksAim`.
]]
export type EnemyTell = "Flash" | "Line" | "Ground"

--[[
	What the telegraph channel is allowed to carry.

	Wider than `EnemyTell`, and deliberately a separate type: a shot's tell is
	a warning about something that has not happened yet, while a dive has
	already happened by the time it is drawn. They share a channel because
	they are the same thing to render — a mark at a point, for a moment — but
	`EnemyShot.tell` must not be allowed to name one.
]]
export type TelegraphTell = EnemyTell | "Dive" | "Spawn" | "Split"

--[[
	What an enemy becomes when it dies, if anything: `count` of `into`,
	thrown clear of where it fell (`Balance.Split` has how far and how fast).
	The pieces are ordinary enemies of their own archetype, spawned by the
	server, so they count towards the room and drop their own XP.
]]
export type EnemySplit = {
	into: EnemyConfig,
	count: number,
	--[[ The pieces' health as a share of their archetype's. ]]
	health: number,
}

--[[
	A ranged enemy's attack. Melee archetypes leave `shot` unset and swing at
	`attackRange` instead.
]]
export type EnemyShot = {
	count: number,
	spread: number,
	speed: number,
	lifetime: number,
	telegraph: number,
	tell: EnemyTell,
	--[[
		Whether the aim is fixed when the wind-up starts rather than when the
		shot leaves.

		This is the difference between the two ranged counterplays. An unlocked
		shot re-aims at the last moment, so the answer is to never stop moving.
		A locked shot commits, so the answer is to read where it is pointed and
		step out of that line. A `Line` tell must lock, or the line it draws is
		a lie and the player learns to ignore it.
	]]
	locksAim: boolean,
	--[[
		Studs from the player it may open fire at, when that is not the
		distance it holds (`attackRange`). A ranged enemy that may only shoot
		from where it wants to stand has to walk there first — the Spitter
		spawned 21+ studs out, fired from 13 and its seeds died at 16, so it
		walked in silence and its shots never reached a player who kept back.
		Nil is `attackRange`.
	]]
	range: number?,
}

--[[
	Declared as a type so every archetype is checked against the same shape,
	the way DeviceTiers does. Phase 2 adds five of these and a typo in one
	should be a type error, not a nil at runtime.
]]
--[[
	Going underground to close distance untouched.

	The counterplay the teardown asks for is "pre-move before they land", so
	the marker that shows where it will surface has to appear far enough ahead
	for a player to walk out of it. `surfaceTell` is that window, and it is the
	only defence against something that cannot be shot while it travels.
]]
export type EnemyBurrow = {
	duration: number,
	surfaceTell: number,
	--[[
		How close it tries to get before coming up.

		Deliberately *not* `attackRange`. A ranged enemy parks itself at
		attackRange, so gating the dive on being further than that would let it
		dive exactly once and then sit on the boundary for ever. Underground it
		is closing to knife range, which is a different number and a different
		intent.
	]]
	surfaceDistance: number,
	--[[ Movement multiplier while under. Faster than walking, or burrowing
	     would be a worse way to cross the room than walking. ]]
	speedScale: number,
	--[[ Seconds above ground before it may dive again, so it cannot chain
	     dives and spend the whole fight untargetable. ]]
	cooldown: number,
}

export type EnemyConfig = {
	displayName: string,
	health: number,
	moveSpeed: number,
	attackRange: number,
	attackDamage: number,
	attackCooldown: number,
	knockback: number,
	hitboxSize: Vector3,
	color: Color3,
	xpReward: number,
	--[[
		Degrees per second the enemy can turn to face its target.

		Without a limit every enemy snapped to face the player every frame,
		which on a three-stud Charger is invisible and on a Bulwark with a
		shield wider than its body looks like the whole slab is copying the
		player's movements — it swung 315 degrees in three seconds while the
		player strafed past it. A turn rate is also what makes weight read:
		big things should come round slowly.

		Facing is presentation only. Every shot is aimed separately at the
		target, so this never makes an enemy easier or harder to dodge.
	]]
	turnRate: number,
	shot: EnemyShot?,
	burrow: EnemyBurrow?,
	split: EnemySplit?,
}

local meleeCharger: EnemyConfig = {
	displayName = "Charger",
	--[[ Quick: it commits to a direction and turns hard to keep it. ]]
	turnRate = 540,
	health = 300,
	moveSpeed = 6.9,
	-- Studs from the player at which it lands a hit.
	attackRange = 4,
	attackDamage = 56,
	attackCooldown = 1,
	-- Studs the enemy is shoved back per hit taken.
	knockback = 3,
	--[[ The Moss Slime's own shape: 3 wide and deep, 2.2 tall — a squat
	     jelly, not the 5-stud box every archetype used to share. Arrows fly
	     low enough to meet it (`Projectile.height`). ]]
	hitboxSize = Vector3.new(3, 2.2, 3),
	color = Color3.fromRGB(226, 52, 56),
	xpReward = 10,
	--[[ Melee: closes to attackRange and swings. A ranged archetype sets
	     `shot` instead and keeps its distance. ]]
	shot = nil,
}

--[[
	Elite melee: the Brood Slime (docs/ENEMIES-AND-ARENAS.md's Act 1 elite).
	A big, slow Moss Slime with four babies riding in its moss, and when it
	dies it splits like Zac's Cell Division — into Moss Slimes, thrown clear
	in arcs (`Balance.Split`). A slow body that becomes four quick threats:
	the lesson is finishing what you start.
]]
local broodSlime: EnemyConfig = {
	displayName = "BroodSlime",
	--[[ Heavier than a Moss Slime, lighter than a Bulwark. ]]
	turnRate = 240,
	--[[ Six arrows, then the four slimes it becomes, one per baby. ]]
	health = 600,
	moveSpeed = 4.5,
	attackRange = 4.6,
	attackDamage = 56,
	attackCooldown = 1.3,
	knockback = 1.5,
	--[[ Its model's own shape, 4.1 × 3.4 × 4.1. ]]
	hitboxSize = Vector3.new(4.1, 3.4, 4.1),
	color = Color3.fromRGB(226, 52, 56),
	xpReward = 20,
	shot = nil,
	--[[ Four, one per baby, like Zac; at half a Moss Slime's health each
	     (owner, 2026-10-22: Level 1 was too hard). ]]
	split = { into = meleeCharger, count = 4, health = 0.5 },
}

--[[
	Spread ranged. Stands off and fires a fan of slow projectiles, which the
	player walks through the gaps of. The counterplay it teaches is "find the
	gap, move through it" — so the arc stays wide enough to read and the
	projectiles slow enough to dodge on a phone.
	See docs/RESEARCH-archero.md §4.
]]
local spreadShooter: EnemyConfig = {
	displayName = "Spitter",
	--[[ Moderate: it stands off and tracks. ]]
	turnRate = 360,
	health = 240,
	moveSpeed = 4.8,
	--[[ Ranged enemies treat attackRange as the distance they want to hold,
	     not the distance they close to. ]]
	attackRange = 13.3,
	attackDamage = 45,
	--[[ 2.2, then 3 (owner, 2026-10-22: "make the spitter fire every 3
	     seconds"). ]]
	attackCooldown = 3,
	knockback = 3,
	--[[ The Sprout Spitter's own shape (its model, 3 × 3.6 × 3), not the
	     shared 5-stud box; arrows at `Projectile.height` meet it. ]]
	hitboxSize = Vector3.new(3, 3.6, 3),
	color = Color3.fromRGB(70, 206, 236),
	xpReward = 14,
	shot = {
		--[[ Two, either side of the aim (owner, 2026-10-22: "only fire two
		     projectiles"). Was three, one down the centre; standing still
		     in its line is now safe for a moment, moving through the gap is
		     the answer. ]]
		count = 2,
		-- Radians between neighbouring projectiles in the fan.
		spread = math.rad(18),
		--[[
			Measured: Archero 2's slow purple orbs, tracked across 1.5 s of
			footage with the camera's drift taken out, travel 0.27–0.40
			room-widths a second — about 12 studs/s here, inside the 8–20
			band the teardown asks for. Rescaling with the room had pushed
			this down to 4, where an orb crawled.

			Lifetime keeps the reach it had (16 studs), so the speed is the
			only thing that changed. Then ×1.5 with everything else on the
			owner's ask (2026-10-22), reach still 16.
		]]
		--[[ 18 after the ×1.5, then three quarters of that at playtest
		     (owner, 2026-10-22: "the spitter's projectiles are a bit too
		     fast"). ]]
		speed = 13.5,
		--[[ Reach: the whole room, corner to corner (35 × 58, about 68
		     studs), so a seed reaches the player wherever they stand
		     (owner, 2026-10-22: "make sure the spitter projectiles can
		     reach the player"). Was 16. ]]
		lifetime = 70 / 13.5,
		--[[ Seconds of wind-up before the volley leaves, so the player reacts
		     to the tell rather than to the projectile. ]]
		telegraph = 0.45,
		tell = "Flash",
		--[[ Re-aims as it fires. Against a fan the counterplay is to keep
		     moving, so letting it track rewards exactly that. ]]
		locksAim = false,
		--[[ Fires from anywhere in the room, so it opens up as soon as it
		     has landed (owner: "it fires from when it spawns") rather than
		     after walking in to `attackRange`, which is still where it
		     holds. ]]
		range = 70,
	},
}

--[[
	Line ranged. Telegraphs with a drawn line, then fires one fast shot down
	it. The counterplay is not "move" but "read the line and step off it" —
	which only works because the aim locks when the wind-up begins.

	Low health and slow movement on purpose: it is a threat you answer by
	repositioning, and it should die quickly once you have closed on it.
]]
local lineSniper: EnemyConfig = {
	displayName = "Lancer",
	--[[ Deliberate: it swings round to line the lance up. ]]
	turnRate = 240,
	health = 200,
	moveSpeed = 3.9,
	attackRange = 18.8,
	attackDamage = 90,
	attackCooldown = 3,
	knockback = 3,
	hitboxSize = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(140, 82, 210),
	xpReward = 16,
	shot = {
		count = 1,
		spread = 0,
		--[[ Fast, unlike the Spitter. The telegraph is the counterplay here,
		     not the flight time — once it fires, it has already hit.
		     Measured against the footage's fast red shot, ~0.8 room-widths
		     a second; one sample, so the least certain number here. ×1.5
		     with everything else (2026-10-22); reach held at 28 studs. ]]
		speed = 42,
		lifetime = 28 / 42,
		--[[ Long, because the whole fight is the player reading this window
		     and moving out of the line inside it. ]]
		telegraph = 0.9,
		tell = "Line",
		locksAim = true,
	},
}

--[[
	Tank. Large, slow and placed to deny space rather than to chase. The
	teardown's note is to treat it as terrain and kill it last, so its job is
	to make a region of the room expensive to stand in — which is a direct tax
	on move-or-shoot.
]]
local tank: EnemyConfig = {
	displayName = "Bulwark",
	--[[ Ponderous. A quarter-turn takes a full second, which is what makes it read as heavy rather than as copying the player. ]]
	turnRate = 90,
	health = 1200,
	moveSpeed = 3.3,
	attackRange = 5,
	attackDamage = 100,
	attackCooldown = 1.6,
	--[[ Barely flinches. Knockback on something this heavy would let a player
	     stall it indefinitely with chip damage. ]]
	knockback = 0.6,
	hitboxSize = Vector3.new(6, 8, 6),
	color = Color3.fromRGB(124, 134, 160),
	xpReward = 30,
	shot = nil,
	burrow = nil,
}

--[[
	Hidden. Dives, crosses the room untargetable, and comes up next to the
	player with a wide fan.

	The pressure it applies is specific: every other archetype can be answered
	by shooting it, and this one cannot while it is moving. It forces the
	player to give up their firing position pre-emptively, on a marker, which
	is the most expensive thing move-or-shoot can ask of them.

	Low health, because it earns its damage by arriving rather than by
	surviving — once it is above ground it should die fast.
]]
local burrower: EnemyConfig = {
	displayName = "Lurker",
	--[[ Moderate, and only ever seen turning above ground. ]]
	turnRate = 360,
	health = 260,
	moveSpeed = 5.7,
	attackRange = 10.1,
	attackDamage = 56,
	attackCooldown = 2.4,
	knockback = 3,
	hitboxSize = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(124, 62, 178),
	xpReward = 20,
	shot = {
		--[[ Wider and denser than the Spitter's: it surfaces at close range,
		     so the fan has to threaten the space around the player rather than
		     a lane across the room. ]]
		count = 5,
		spread = math.rad(24),
		--[[ The same slow-orb family as the Spitter's, measured the same
		     way. Reach held at 13.2 studs. ]]
		speed = 18,
		lifetime = 13.2 / 18,
		--[[ Short. Surfacing *is* the telegraph, and the player has already
		     been given the ground marker to act on. ]]
		telegraph = 0.25,
		tell = "Flash",
		locksAim = false,
	},
	burrow = {
		duration = 2.2,
		--[[ Long enough to walk out of at base move speed, which is what makes
		     the marker a decision rather than a notification. ]]
		surfaceTell = 0.75,
		--[[ Close, but not inside them. It comes up beside the player so the
		     fan covers the space they are standing in. ]]
		surfaceDistance = 3.5,
		speedScale = 2.2,
		cooldown = 3.5,
	},
}

--[[ An obstacle footprint, as an XZ offset from the arena centre. ]]
export type Obstacle = {
	offset: Vector2,
	size: Vector3,
}

--[[
	One room: what it is shaped like and what is in it.

	Layout is listed first on purpose. Where the pillars are changes
	move-or-shoot more than any enemy stat does, because it decides where the
	player can afford to stand still — which is the only decision the game
	asks. A room with no cover and a room that is mostly corridor are
	different fights with identical enemies.
]]
--[[
	A stage: one run, from its first fight to the end.

	Archero 2 has two kinds, and which one a stage is belongs to the place in
	the game it sits, so it is data here rather than a branch in the run code:

	- **Rooms** — fight, clear, the door opens, walk through to the next room.
	  `rooms` lists which `Rooms` entries, in order.
	- **Waves** — one arena for the whole stage. Waves arrive in place; every
	  `Waves.valkyrieAt` a Valkyrie offers one of two skills, every
	  `Waves.angelAt` an Angel offers a stat or a heal, and every
	  `Waves.bossAt` is a boss wave. `arena` names the `Rooms` entry whose
	  layout is the arena; `waves` is how many there are.

	Wave content is read off the same `Rooms` list a Rooms stage walks: wave
	`w` of `n` fights the roster and count of room ⌈w / n · #Rooms⌉. The
	tutorial order those rooms encode carries over unchanged.
]]
export type StageMode = "Rooms" | "Waves"

export type StageConfig = {
	name: string,
	mode: StageMode,
	rooms: { number }?,
	arena: number?,
	waves: number?,
	--[[ How hard this stage's enemies are, as multipliers on every
	     archetype's `attackDamage` and `health`: the per-area scaling
	     non-negotiable 8 calls for, set by where the stage sits in the game.
	     Nil is 1. ]]
	enemyDamage: number?,
	enemyHealth: number?,
}

export type RoomConfig = {
	name: string,
	obstacles: { Obstacle },
	enemyCount: number,
	--[[
		Which archetypes this room draws from, cycled to fill `enemyCount`.

		Per-room rather than one global order, because the order *is* the
		tutorial. A single cycle shared by every room put a charger, a spitter
		and a burrower in the opening fight — three mechanics at once, one of
		them the hardest of the five to read — which is a teaching failure
		dressed up as difficulty.
	]]
	roster: { EnemyConfig },
	--[[ The `ArenaModels` entry that dresses this room, in place of the
	     grey-box look. Presentation only: what collides is still the room's
	     walls and `obstacles`. Nil is the grey box. ]]
	arena: string?,
}

--[[
	Ten grey-box rooms. Deliberately hand-authored rather than generated: the
	Phase 2 question is whether a room-to-room loop holds up, and a generator
	would be answering a different question with more variables.

	They alternate deliberately — open, broken, tight, open — so the player
	keeps having to re-learn where standing still is safe rather than settling
	into one position that always works.
]]
local rooms: { RoomConfig } = {
	{
		name = "Open Ground",
		--[[
			Deliberately empty, and this one cost a playtest to learn.

			The opener used to be a screen across the spawn's sight-line, put
			there so the room could not be won standing still. It worked far
			too well: the player spawns behind it every time, auto-aim picks
			targets through it, and 41 of 45 shots went into the wall. The
			first thing a new player experienced was firing continuously at
			nothing, with no feedback explaining why.

			A tutorial room's job is to prove the verb works. Stand still, the
			archer fires, the thing dies. Cover arrives in room two, where the
			player already trusts that shooting does something — and where
			being blocked reads as a wall rather than as a broken game.
		]]
		obstacles = {},
		--[[ Two chargers, which walk straight at you and die. Nothing here is
		     trying to be interesting. ]]
		enemyCount = 2,
		roster = { meleeCharger },
	},
	{
		name = "Two Pillars",
		obstacles = {
			{ offset = Vector2.new(-5.5, 0), size = Vector3.new(3.1, 10, 5.2) },
			{ offset = Vector2.new(5.5, 0), size = Vector3.new(3.1, 10, 5.2) },
		},
		--[[ Adds the spitter. A fan you walk through the gaps of. ]]
		enemyCount = 3,
		roster = { meleeCharger, meleeCharger, spreadShooter },
	},
	{
		name = "The Spine",
		-- One long wall across the middle: every fight is decided by which
		-- side of it you choose.
		obstacles = {
			{ offset = Vector2.new(0, 0), size = Vector3.new(2.5, 10, 29.6) },
		},
		--[[ Adds the Brood Slime: room two's fight, and one body that has to
		     be killed twice. ]]
		enemyCount = 3,
		roster = { meleeCharger, spreadShooter, broodSlime },
	},
	{
		name = "Scatter",
		obstacles = {
			{ offset = Vector2.new(-7.8, -9.1), size = Vector3.new(3.1, 10, 5.2) },
			{ offset = Vector2.new(8.5, -11.6), size = Vector3.new(2.5, 10, 9.1) },
			{ offset = Vector2.new(-9.4, 12.9), size = Vector3.new(4.6, 10, 3.9) },
			{ offset = Vector2.new(6.2, 11.6), size = Vector3.new(3.1, 10, 5.2) },
			{ offset = Vector2.new(0, 0), size = Vector3.new(2.5, 10, 3.9) },
		},
		--[[ Adds the bulwark, which is really a piece of terrain that hits back. ]]
		enemyCount = 4,
		roster = { meleeCharger, spreadShooter, meleeCharger, tank },
	},
	{
		name = "The Gauntlet",
		-- Two corridors. Ranged enemies at the far end own the lanes.
		obstacles = {
			{ offset = Vector2.new(-4.6, 0), size = Vector3.new(2.5, 10, 38.7) },
			{ offset = Vector2.new(4.6, 0), size = Vector3.new(2.5, 10, 38.7) },
		},
		--[[ Adds the lancer. A drawn line to step out of, in the room with lanes. ]]
		enemyCount = 4,
		roster = { meleeCharger, spreadShooter, lineSniper },
	},
	{
		name = "Quarters",
		obstacles = {
			{ offset = Vector2.new(0, -12.9), size = Vector3.new(15.5, 10, 3.9) },
			{ offset = Vector2.new(0, 12.9), size = Vector3.new(15.5, 10, 3.9) },
		},
		--[[ No new archetype. Four of them at once instead, and a brood. ]]
		enemyCount = 5,
		roster = { meleeCharger, spreadShooter, lineSniper, broodSlime },
	},
	{
		name = "The Pit",
		-- A ring of cover around a bare centre. Standing in the middle is the
		-- worst possible place to stop, which is where the fight pulls you.
		obstacles = {
			{ offset = Vector2.new(-9.4, -15.5), size = Vector3.new(3.9, 10, 6.4) },
			{ offset = Vector2.new(9.4, -15.5), size = Vector3.new(3.9, 10, 6.4) },
			{ offset = Vector2.new(-9.4, 15.5), size = Vector3.new(3.9, 10, 6.4) },
			{ offset = Vector2.new(9.4, 15.5), size = Vector3.new(3.9, 10, 6.4) },
		},
		--[[ Adds the lurker, last because it is the only one that stops being a target. ]]
		enemyCount = 5,
		roster = { meleeCharger, spreadShooter, burrower, tank },
	},
	{
		name = "Teeth",
		obstacles = {
			{ offset = Vector2.new(-10.9, 0), size = Vector3.new(2.5, 10, 19.3) },
			{ offset = Vector2.new(0, -11.6), size = Vector3.new(2.5, 10, 19.3) },
			{ offset = Vector2.new(10.9, 0), size = Vector3.new(2.5, 10, 19.3) },
			{ offset = Vector2.new(0, 11.6), size = Vector3.new(2.5, 10, 19.3) },
		},
		--[[ All five, and from here the count is the only thing still rising. ]]
		enemyCount = 6,
		roster = { meleeCharger, spreadShooter, lineSniper, burrower, tank },
	},
	{
		name = "Last Cover",
		obstacles = {
			{ offset = Vector2.new(0, 0), size = Vector3.new(5.5, 10, 9.1) },
		},
		--[[ All five. ]]
		enemyCount = 6,
		roster = { meleeCharger, lineSniper, spreadShooter, burrower, tank },
	},
	{
		name = "Nowhere To Stand",
		-- Ends where it began, open, but with the most enemies. If the loop
		-- works, this is the room the player wants a rematch with.
		obstacles = {},
		--[[ All five, at the most this run ever throws at once. ]]
		enemyCount = 7,
		roster = { meleeCharger, spreadShooter, lineSniper, burrower, tank },
	},

	--[[
		Level 1 (owner, 2026-10-22): ten rooms, all Mossy Glade, in the
		owner's order — logs, pond, boulders, thorns, then a boss arena, and
		the same again. Each is drawn by its own model (`ArenaModels`); a
		room whose model is not imported yet is the grey box until it is.

		Cover comes in two kinds. The log, stumps, boulders and pillars are
		tall: they stop the player's arrows as well as bodies. The pond and
		the thorns are low: nobody walks through them, but arrows fly over
		(a box under `Projectile.height` blocks movement, not shots).
		Positions are the models' own, ×2.7 (the boss arena ×2.11 across
		and ×2.38 deep: `ArenaModels`).

		Counts are one fewer than first set (owner, 2026-10-22, after a
		playtest: "one less enemy per room").
	]]
	{
		name = "Mossy Glade",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(-2.43, -11.56), size = Vector3.new(12, 2.8, 3.5) },
			{ offset = Vector2.new(-8.91, 5.13), size = Vector3.new(3.75, 1.5, 3.75) },
			{ offset = Vector2.new(8.64, 13.23), size = Vector3.new(3.3, 1.5, 3.3) },
			{ offset = Vector2.new(-6.21, 19.71), size = Vector3.new(2.7, 1.2, 2.7) },
		},
		--[[ Moss Slimes, which walk straight at you and die. ]]
		enemyCount = 2,
		roster = { meleeCharger },
	},
	{
		name = "Mossy Pond",
		arena = "GladePond",
		obstacles = {
			{ offset = Vector2.new(-4.05, -4.32), size = Vector3.new(14, 0.4, 10) },
			{ offset = Vector2.new(9.18, -16.2), size = Vector3.new(3.3, 1.4, 3.3) },
			{ offset = Vector2.new(8.1, 14.31), size = Vector3.new(3.6, 1.6, 3.6) },
		},
		--[[ Adds the Sprout Spitter, across the water. ]]
		enemyCount = 3,
		roster = { meleeCharger, meleeCharger, spreadShooter },
	},
	{
		name = "Mossy Boulders",
		arena = "GladeBoulders",
		obstacles = {
			{ offset = Vector2.new(-8.13, -10.31), size = Vector3.new(5.3, 4.2, 5.6) },
			{ offset = Vector2.new(-5.35, -8.45), size = Vector3.new(3.6, 2.7, 3.6) },
			{ offset = Vector2.new(8.37, 7.32), size = Vector3.new(5, 4, 5.4) },
			{ offset = Vector2.new(10.96, 9.02), size = Vector3.new(3.5, 2.6, 3) },
			{ offset = Vector2.new(-7.29, 18.12), size = Vector3.new(2.9, 2.3, 3) },
			{ offset = Vector2.new(9.18, -19.44), size = Vector3.new(3, 1.3, 3) },
			-- The small boulders beside the big ones.
			{ offset = Vector2.new(-10.34, -8.15), size = Vector3.new(2.7, 2, 2.5) },
			{ offset = Vector2.new(-7.13, -13.2), size = Vector3.new(2.2, 1.8, 2.35) },
			{ offset = Vector2.new(6.18, 9.29), size = Vector3.new(2.5, 2, 2.5) },
			{ offset = Vector2.new(9.32, 4.54), size = Vector3.new(1.9, 1.7, 2.1) },
			{ offset = Vector2.new(-5.8, 19.06), size = Vector3.new(2, 1.5, 2) },
		},
		--[[ Adds the Brood Slime. ]]
		enemyCount = 3,
		roster = { meleeCharger, spreadShooter, broodSlime },
	},
	{
		name = "Mossy Thorns",
		arena = "GladeThorns",
		obstacles = {
			{ offset = Vector2.new(-7.16, -11.6), size = Vector3.new(7.8, 0.4, 7) },
			{ offset = Vector2.new(7.83, 6.48), size = Vector3.new(9.4, 0.4, 7) },
			{ offset = Vector2.new(-8.64, 15.93), size = Vector3.new(3.3, 1.4, 3.3) },
		},
		--[[ Adds the Lancer, whose line crosses the brambles. ]]
		enemyCount = 4,
		roster = { meleeCharger, spreadShooter, broodSlime, lineSniper },
	},
	{
		name = "Glade Heart",
		arena = "GladeBoss",
		obstacles = {
			{ offset = Vector2.new(-11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(-11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
		},
		--[[ A boss room, until Act 1's bosses are built (docs/BOSSES.md): the
		     heaviest body with an escort, as a Waves boss wave is. ]]
		enemyCount = 3,
		roster = { tank, meleeCharger, spreadShooter, meleeCharger },
	},
	{
		name = "Mossy Glade II",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(-2.43, -11.56), size = Vector3.new(12, 2.8, 3.5) },
			{ offset = Vector2.new(-8.91, 5.13), size = Vector3.new(3.75, 1.5, 3.75) },
			{ offset = Vector2.new(8.64, 13.23), size = Vector3.new(3.3, 1.5, 3.3) },
			{ offset = Vector2.new(-6.21, 19.71), size = Vector3.new(2.7, 1.2, 2.7) },
		},
		enemyCount = 4,
		roster = { meleeCharger, spreadShooter, broodSlime, lineSniper },
	},
	{
		name = "Mossy Pond II",
		arena = "GladePond",
		obstacles = {
			{ offset = Vector2.new(-4.05, -4.32), size = Vector3.new(14, 0.4, 10) },
			{ offset = Vector2.new(9.18, -16.2), size = Vector3.new(3.3, 1.4, 3.3) },
			{ offset = Vector2.new(8.1, 14.31), size = Vector3.new(3.6, 1.6, 3.6) },
		},
		--[[ Adds the Lurker, last because it stops being a target. ]]
		enemyCount = 4,
		roster = { meleeCharger, spreadShooter, burrower, broodSlime },
	},
	{
		name = "Mossy Boulders II",
		arena = "GladeBoulders",
		obstacles = {
			{ offset = Vector2.new(-8.13, -10.31), size = Vector3.new(5.3, 4.2, 5.6) },
			{ offset = Vector2.new(-5.35, -8.45), size = Vector3.new(3.6, 2.7, 3.6) },
			{ offset = Vector2.new(8.37, 7.32), size = Vector3.new(5, 4, 5.4) },
			{ offset = Vector2.new(10.96, 9.02), size = Vector3.new(3.5, 2.6, 3) },
			{ offset = Vector2.new(-7.29, 18.12), size = Vector3.new(2.9, 2.3, 3) },
			{ offset = Vector2.new(9.18, -19.44), size = Vector3.new(3, 1.3, 3) },
			-- The small boulders beside the big ones.
			{ offset = Vector2.new(-10.34, -8.15), size = Vector3.new(2.7, 2, 2.5) },
			{ offset = Vector2.new(-7.13, -13.2), size = Vector3.new(2.2, 1.8, 2.35) },
			{ offset = Vector2.new(6.18, 9.29), size = Vector3.new(2.5, 2, 2.5) },
			{ offset = Vector2.new(9.32, 4.54), size = Vector3.new(1.9, 1.7, 2.1) },
			{ offset = Vector2.new(-5.8, 19.06), size = Vector3.new(2, 1.5, 2) },
		},
		enemyCount = 5,
		roster = { meleeCharger, spreadShooter, lineSniper, burrower, broodSlime },
	},
	{
		name = "Mossy Thorns II",
		arena = "GladeThorns",
		obstacles = {
			{ offset = Vector2.new(-7.16, -11.6), size = Vector3.new(7.8, 0.4, 7) },
			{ offset = Vector2.new(7.83, 6.48), size = Vector3.new(9.4, 0.4, 7) },
			{ offset = Vector2.new(-8.64, 15.93), size = Vector3.new(3.3, 1.4, 3.3) },
		},
		enemyCount = 5,
		roster = { meleeCharger, spreadShooter, lineSniper, burrower, broodSlime },
	},
	{
		name = "Glade Heart II",
		arena = "GladeBoss",
		obstacles = {
			{ offset = Vector2.new(-11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(-11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
		},
		enemyCount = 4,
		roster = { tank, broodSlime, spreadShooter, meleeCharger, lineSniper },
	},
}

local Balance = {
	Player = {
		maxHealth = 225,
		--[[ Studs per second. Raised in steps over several playtests:
		     repositioning has to be affordable, or the answer to every threat
		     is to stand still and hope. Was 9 — 0.26 room-widths a second,
		     brisker than the footage's 0.19 by choice — then every speed in
		     the game went up by half on the owner's ask (2026-10-22). ]]
		moveSpeed = 13.5,
		baseDamage = 100,
		--[[ Seconds between volleys while stationary. Slowed from 0.45 over
		     playtests: at that pace standing still paid so well that moving
		     stopped being worth it, which hollows out move-or-shoot from the
		     other side. Precision shortens it from here. ]]
		attackCooldown = 0.7,
		--[[ Studs. Past this the archer holds fire rather than shooting at
		     nothing. Must stay inside how far an arrow actually flies, or the
		     archer locks onto enemies its arrows fade before reaching —
		     `tests/Balance.spec.luau` holds that. ]]
		attackRange = 42,
		-- MoveDirection magnitude below which the archer counts as stationary.
		-- Not zero: thumbsticks idle noisy, and a dead archer is an unfair one.
		stationaryThreshold = 0.05,
		-- Seconds the archer must be still before firing resumes. Small, but
		-- non-zero stops a player machine-gunning by tapping the stick.
		stationaryDelay = 0.1,

		--[[
			The dash.

			Move-or-shoot gives the player exactly one answer to a volley
			already in the air: walk out of it, which against a Lancer's shot
			— two and a half times walking speed — is no answer at all. The
			dash is the escape that makes a bad position recoverable instead
			of fatal.

			It costs what it is worth. Dashing is moving, so the stationary
			timer resets and the archer stops firing — the way out of a fan is
			paid for in the shots not taken while leaving. Nothing about
			firing needed changing for that; it falls out of driving the
			Humanoid rather than teleporting.

			Four studs — two player-widths, about a ninth of the room's
			width. Scaled down with the room from the original sixteen, then
			shortened a step further after playtest: it still clears a fan,
			but it is an escape now rather than a way across the room. The duration is the shortest that still reads as travel
			rather than as a blink, which matters because a player who cannot
			see where they went cannot aim the next one.
		]]
		--[[ Seconds of standing still before Overdraw reaches its full bonus.
		     Long enough that it is a commitment, short enough that it pays
		     inside a single volley exchange. ]]
		overdrawRamp = 2.5,

		--[[ Every archer crits sometimes, so Deadly Strike (crit damage) is
		     worth something before Precision (crit chance) is drafted. ]]
		critChance = 0.05,
		critMultiplier = 2,

		--[[
			Momentum: "attack speed rises while moving". Nothing fires on the
			move here, so the speed is banked by moving and spent after:
			having moved for at least `windup` seconds, the first `duration`
			seconds of shooting after you stop fire faster. Rewards stepping
			out of a shot and answering straight back.
		]]
		momentum = {
			windup = 0.5,
			duration = 2,
		},

		dash = {
			distance = 4,
			duration = 0.12,
			--[[
				Long enough that it is a decision rather than a second
				movement speed.

				Raised from 1.2 after playtest. At just over a second the dash
				was close enough to always-available that it stopped being a
				resource and started being how you walked. At four it is the
				thing you save for the fan you did not see coming — which only
				works because `DashBar` shows the player where it is.
			]]
			cooldown = 4,
		},
	},

	Projectile = {
		--[[
			Measured, not tuned: Archero 2's arrows cross about 5.5 room-widths
			a second (1080p footage at 60 fps, ~1,840 px/s against a 336 px
			floor — see docs/RESEARCH-archero.md §7). Across our 35-stud room
			that is about 190.

			This was 17.4 for a long stretch, a number that came from scaling
			an older, slower value down with the room. It made a volley
			something you watched travel; in the reference it is all but
			instant, and the cost of standing still is the enemy fire you are
			not dodging, not the wait for your own arrow.

			Then slowed to 110 at playtest — about 58% of the footage — because
			at full footage speed the arrows read as flying too fast. Still
			fast enough to land before most targets can step aside. Then
			×1.5 with every other speed (2026-10-22), to 165: still under
			the footage's 190.
		]]
		speed = 165,
		--[[ 45 studs of flight, the reach playtesting settled on: a little
		     over `Player.attackRange`, so a shot at the edge of range
		     arrives, and not so far that arrows sail on after the fight.
		     Held as a distance by `Balance.spec`, so this follows `speed`. ]]
		lifetime = 45 / 165,
		--[[
			The longest a projectile moves before its hit tests run again.

			At footage speed an arrow covers about three studs a frame — more
			than its own length — and the overlap pass only sees what the
			arrow is touching on the moment it runs. So flight is cut into
			sub-steps no longer than this, each with its own overlap pass and
			sweep. Under half the arrow's length keeps the dead-zone argument
			in `tests/HitDetection.spec.luau` true however fast arrows go.
		]]
		maxStepTravel = 1.2,
		--[[ Diagonal Arrows' two extra arrows, either side of the aim. The
		     footage's fan measures about ±30°, not the ±45° of the original
		     Archero. ]]
		diagonalAngle = math.rad(30),
		--[[
			Ricochet, as Archero 2's card has it: "Bullets can bounce between
			monsters". After a hit the arrow leaves for the nearest *other*
			enemy within `ricochetRange`, at `ricochetDamageScale` of the
			damage it arrived with. The scale is the original game's roughly
			-30% per bounce, from the teardown; the footage shows no number.
		]]
		ricochetRange = 14,
		ricochetDamageScale = 0.7,
		--[[ How far ahead a Tracking Eye arrow looks for something to curve
		     towards. Under the archer's targeting range, so it bends shots
		     at the fight rather than hunting across the room. ]]
		homingRange = 20,
		--[[ Seconds between Multishot's volleys. Short enough that they read
		     as one attack; long enough that the next arrow is a second chance
		     at a target that moved. Held under the fastest fire rate by
		     `Balance.spec`. ]]
		multishotInterval = 0.12,
		--[[ Radians between the arrows of Double Shot's narrow spread. ]]
		doubleShotSpread = math.rad(9),
		--[[ Radians between the arrows of a second Rear or Side arrow. ]]
		extraArrowSpread = math.rad(12),
		--[[ Where Diagonal Arrows' second pair flies, from the aim. ]]
		wideDiagonalAngle = math.rad(45),
		--[[ Studs an arrow must travel for Long Shot's full bonus. About half
		     the room's length: point-blank shots get nothing extra. ]]
		farRange = 30,
		--[[ Soul Chain: the share of a hit each linked enemy takes, and how
		     far from the one hit a link reaches. ]]
		linkShare = 0.5,
		linkRange = 10,
		--[[
			Half the width of the drawn arrow, and half the width of the box
			the server sweeps. These two numbers are the hitbox *and* the
			visual, which is the point: a projectile that is shown as a long
			dart but simulated as a tiny sphere only counts from its nose, so
			shots that plainly connected along the shaft did nothing.
		]]
		radius = 0.35,
		--[[ Studs above the floor every player arrow flies at, wherever the
		     archer's body is. Low, so it passes through every enemy's hitbox:
		     the shortest is the Moss Slime's 2.2 (owner, 2026-10-22: "make the
		     Charger's hitbox fit the slime ... and lower the arrow height to
		     match"). `Balance.spec` holds it inside every hitbox. ]]
		height = 1.1,
		--[[
			Length of that arrow, along its direction of travel. Shared rather
			than a client constant, because the server has to sweep the same
			shape the player is looking at.

			Long, because Archero reads its shots as beams rather than as
			pellets and a short dart is almost invisible at phone size.

			Three studs, about one and a half player-widths, matching the
			arrow-to-body proportion in the footage. Body-sized, so it did not
			scale with the room the way speed did.

			This number is not free. A shape cast ignores anything it already
			intersects when it starts, so the arrow's forward half is a dead
			zone the sweep cannot see into — 1.5 studs here, against
			`maxStepTravel` of travel per sub-step. ProjectileFlight pays for
			that with a per-step overlap pass; without it, a target that walks
			into the arrow's front half is never hit.
		]]
		length = 3,
		--[[
			Studs between neighbouring arrows in a multi-arrow volley.

			Tight on purpose. Extra arrows fly in a lane beside each other,
			not in a fan, so that a volley aimed at one enemy puts *all* of
			it into that enemy — which is the thing a fan stops doing the
			moment the target is more than a few studs away.

			`tests/AbilityEffects.spec.luau` holds this to the width of the
			narrowest enemy: widen it far enough and the outer arrows of a
			full-stack volley start sailing past the thing they were aimed
			at, which is the bug this replaced.
		]]
		parallelSpacing = 0.85,
		--[[
			Diameter of an enemy shot, which is a round orb rather than an
			arrow — that is what the reference footage shows, and it means a
			player can tell incoming fire from their own by shape alone.

			Swept as a cube of this size on the server, so the hitbox is the
			orb on screen. Larger than an arrow is wide on purpose: enemy fire
			is slow, and the thing that has to be readable at a glance on a
			phone is what is coming at you.
		]]
		enemyOrbDiameter = 1.2,
		-- Hard cap on live server projectiles. Phase 3 abilities multiply volley
		-- size aggressively; this is the backstop.
		maxActive = 400,
	},

	--[[
		What Blaze sets alight. A hit burns for `duration` seconds, ticking
		every `tick`, and a fresh hit *refreshes* the burn at the stronger of
		the two rates rather than adding to it — so Front Arrow and Double
		Shot cannot stack it into a second weapon. `Balance.spec` holds a
		whole burn under the hit that lit it.
	]]
	--[[ How a hit shoves an enemy. Each archetype's `knockback` is how far;
	     this is how long the slide takes to come to rest. Short enough to
	     read as an impact, long enough to be seen at all. ]]
	Knockback = {
		slideTime = 0.25,
	},

	--[[ Blaze. How long a burn lasts is the card's level; `rate` is the
	     share of the arrow's damage it burns for each second. ]]
	Burn = {
		rate = 0.2,
		tick = 0.5,
	},

	--[[ The draft (docs/RESEARCH-archero2.md; the upgrade card design).
	     Cards are dealt weighted by rarity (`Config/Rarities`), and a run
	     may redeal a hand this many times. ]]
	Draft = {
		rerollsPerRun = 2,
	},

	--[[
		Damage scale, from Archero 2 (docs/RESEARCH-archero2.md §3). A fresh
		hero there has 225 HP and hits for 100; a first-wave grunt dies in
		three hits; about four enemy hits kill the hero. So: player numbers
		are set to exactly those, enemy health keeps the ratios playtesting
		gave the archetypes with the Charger at three hits, and enemy damage
		is a quarter of the player for the common hit, more for the
		archetypes whose whole threat is one heavy blow.

		`Balance.spec` holds these as relationships, so a retune that keeps
		the shape passes and one that loses it fails.
	]]
	Enemies = {
		MeleeCharger = meleeCharger,
		SpreadShooter = spreadShooter,
		LineSniper = lineSniper,
		Tank = tank,
		Burrower = burrower,
		BroodSlime = broodSlime,
	},

	--[[
		How a splitting enemy's pieces leave it, after Zac's Cell Division
		in League of Legends: the body bursts and its pieces are flung out in
		arcs, land with a squash, and only then are enemies. Until they land
		they are untargetable and harmless — a piece in the air is a warning,
		not a threat.
	]]
	Split = {
		--[[ Studs from where it fell to where a piece lands. ]]
		reach = 5,
		--[[ Seconds in the air, and how high the arc peaks. ]]
		flight = 0.5,
		arcHeight = 3.5,
		--[[ Seconds a landed piece wobbles before it becomes an enemy. ]]
		settle = 0.25,
	},

	--[[ Drawn tell for a `Line` shot: how thick the line is, and how far past
	     the target it reaches so the player can see it is a line rather than a
	     distance. ]]
	Telegraph = {
		lineThickness = 0.35,
		lineOvershoot = 5,
		lineColor = Color3.fromRGB(236, 92, 84),
		--[[ Radius of the marker showing where something is about to surface.
		     Wider than the enemy so stepping to its edge is not enough. ]]
		groundRadius = 3,
		groundColor = Color3.fromRGB(255, 150, 60),
		--[[
			The footprint, drawn instantly at full size and left there.

			The growing disc is a countdown and has to stay one, but on its own
			it spends the first third of a 0.75s warning as almost nothing —
			which is most of the time the player had. This says *where* at
			once, and the fill still says *when*.
		]]
		groundOutlineTransparency = 0.76,

		--[[
			The dive, which is the opposite event and is drawn as the opposite
			shape: a disc that collapses inward rather than growing outward.

			Growing means something is coming up here. Shrinking means
			something went down here. Two events that used to be one silent
			pop now read as a pair without the player being taught anything.
		]]
		diveDuration = 0.45,
		diveRadius = 3,
		diveColor = Color3.fromRGB(150, 230, 180),

		--[[ Where an enemy is about to appear. Red, and drawn at the arriving
		     body's own size times this, so a Bulwark's warning is visibly
		     bigger than a Charger's before either exists. ]]
		spawnColor = Color3.fromRGB(226, 70, 70),
		spawnMarkerScale = 1.35,
	},

	--[[ Colour an enemy flashes to while winding up a telegraphed shot. The
	     tell has to be visible before the projectile exists, or the telegraph
	     is decoration. ]]
	TelegraphColor = Color3.fromRGB(255, 226, 150),

	Arena = {
		size = Vector3.new(35, 1, 58),
		wallHeight = 8,
		wallThickness = 2,
		--[[ Where a player stands at the start of a room. Near the south wall,
		     the full length of the arena from the exit pad, so clearing a room
		     always means crossing it. Raised clear of the floor because
		     characters are placed here by CFrame, not dropped. ]]
		spawnPosition = Vector3.new(0, 4, 23),
		--[[ The arena's dressing, after Archero 2's first chapter
		     (docs/ART-archero2.md §2): blue-violet flagstones over darker
		     grout, purple bevelled stone, pink orb lamps, a grass edge, and
		     the world going on past the walls. All decoration — none of it
		     collides, blocks a shot or moves the floor plane. ]]
		floorColor = Color3.fromRGB(52, 56, 104),
		tileColor = Color3.fromRGB(98, 108, 182),
		wallColor = Color3.fromRGB(88, 80, 140),
		wallCapColor = Color3.fromRGB(132, 124, 190),
		obstacleColor = Color3.fromRGB(104, 98, 160),
		obstacleCapColor = Color3.fromRGB(146, 140, 204),
		lampColor = Color3.fromRGB(255, 120, 200),
		grassColor = Color3.fromRGB(70, 160, 104),
		outsideColor = Color3.fromRGB(30, 70, 92),
		--[[ Studs between orb lamps along each side wall. ]]
		lampSpacing = 11,
		-- Grey-box pillars. Positions are XZ offsets from arena centre.
		-- These block the player's arrows but NOT enemy attacks, which is the
		-- asymmetry the whole game rests on. See docs/RESEARCH-archero.md.
		obstacles = {
			{ offset = Vector2.new(-7.8, -9.1), size = Vector3.new(3.1, 10, 5.2) },
			{ offset = Vector2.new(8.5, -11.6), size = Vector3.new(2.5, 10, 9.1) },
			{ offset = Vector2.new(-9.4, 12.9), size = Vector3.new(4.6, 10, 3.9) },
			{ offset = Vector2.new(6.2, 11.6), size = Vector3.new(3.1, 10, 5.2) },
			{ offset = Vector2.new(0, 0), size = Vector3.new(2.5, 10, 3.9) },
		},
	},

	Rooms = rooms,

	--[[ Global light, after the footage: bright and even, nothing important
	     ever in shadow, and a soft bloom so glowing things glow. The bloom is
	     switched off on the lowest device tier. ]]
	Lighting = {
		ambient = Color3.fromRGB(124, 122, 156),
		outdoorAmbient = Color3.fromRGB(150, 150, 184),
		brightness = 2.2,
		clockTime = 14,
		bloomIntensity = 0.55,
		bloomSize = 26,
		bloomThreshold = 1.15,
		saturation = 0.15,
		contrast = 0.05,
		--[[ The distance haze. The place's default is grey, which read as
		     grey space at the edges of the screen (owner, 2026-10-22); a
		     forest green reads as the glade going on into mist. ]]
		hazeDensity = 0.3,
		hazeColor = Color3.fromRGB(70, 110, 60),
		hazeDecay = Color3.fromRGB(30, 60, 30),
	},

	Stages = {
		{
			name = "The Courtyards",
			mode = "Rooms",
			rooms = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
		},
		{
			name = "Moonlit Arena",
			mode = "Waves",
			--[[ Two Pillars: a little cover, open enough that a wave arriving
			     anywhere can be fought. ]]
			arena = 2,
			waves = 30,
		},
		{
			--[[ Ten Mossy Glade rooms: logs, pond, boulders, thorns, boss, twice. ]]
			name = "Level 1",
			mode = "Rooms",
			rooms = { 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
			--[[ The game's first level, eased after playtests (owner,
			     2026-10-22: "the difficulty is still too high"): enemies hit
			     at 0.7 and have 0.8 of their health, so the player takes
			     about six hits rather than four. ]]
			enemyDamage = 0.7,
			enemyHealth = 0.8,
		},
	} :: { StageConfig },

	--[[ Which stage a run plays. Set per point in the game; one index here
	     until there is a stage select. ]]
	stage = 3,

	--[[ The Waves-mode schedule, as Archero 2 numbers it within each block
	     of ten: a Valkyrie on the 5th, an Angel on the 9th, a boss on the
	     10th. Positions, not frequencies — wave 15 is a Valkyrie because
	     15 is 5 into its block. ]]
	Waves = {
		blockSize = 10,
		valkyrieAt = 5,
		angelAt = 9,
		bossAt = 10,
		--[[ Cards a Valkyrie offers. ]]
		valkyrieOffer = 2,
		--[[ Seconds between a wave clearing and the next arriving: long
		     enough that a clear is its own moment, short enough that the
		     stage keeps its rhythm. ]]
		pause = 1.2,
		--[[ A boss wave, until Phase 4 brings bosses: the stage's heaviest
		     body with an escort. ]]
		bossRoster = { tank, meleeCharger, spreadShooter, meleeCharger },
		--[[ Hearts a Valkyrie wave leaves on the floor, as Archero 2's does. ]]
		valkyrieHearts = 1,
		--[[ How many of the first `Rooms` a Waves stage's fights are drawn
		     from: the Courtyards' ten, whose tutorial order carries into
		     waves. Later rooms belong to their own levels. ]]
		rooms = 10,
	},

	--[[
		What kills leave on the floor (docs/RESEARCH-archero2.md, "XP" and
		"Healing").

		**XP crystals.** A kill's XP is not credited when it dies. It drops as
		crystals, which lie where the enemy fell. Walk over your own to take
		them early; whatever is left is drawn in to its owner when the wave or
		room clears, so no XP is ever lost to where an enemy happened to die.

		**Hearts.** A rare drop that waits on the floor until a player walks
		over it, full health or not, and heals a share of max health.
	]]
	Pickups = {
		--[[ XP one crystal stands for, and the most a single kill drops: a
		     Charger's 10 is two crystals, a Bulwark's 30 is four. ]]
		xpPerCrystal = 8,
		maxCrystalsPerKill = 4,
		--[[ Studs from a crystal to the player at which it is taken and
		     flies to them — the magnet. Raised from 3 on the owner's ask
		     (2026-10-22, "the magnet range ... to be bigger"): passing near
		     is enough. ]]
		crystalRadius = 7,
		--[[ How far from the body crystals scatter, in studs. ]]
		crystalScatter = 2.2,
		--[[ Seconds after a clear before the crystals are drawn in, so the
		     last kill's crystals are seen landing first. ]]
		collectDelay = 0.3,
		--[[ Seconds a crystal takes to fly to its owner. Presentation; the XP
		     is credited when the flight starts. ]]
		collectFlight = 0.45,

		--[[ Chance a kill drops a heart. ]]
		heartChance = 0.05,
		--[[ Share of max health one heart restores. ]]
		heartHeal = 0.2,
		--[[ Studs from a heart's centre to the player's at which it is taken
		     — the magnet. Raised from 2.5 with the crystals' (2026-10-22). ]]
		heartRadius = 6,

		crystalColor = Color3.fromRGB(70, 210, 255),
		heartColor = Color3.fromRGB(255, 60, 90),
	},

	--[[
		Archero 2's revive (docs/RESEARCH-archero2.md, "Healing"): once per
		stage, a death is undone — full health and a moment untouchable, so
		the hit that killed you cannot simply happen again. Automatic for
		now; Archero 2 asks first and charges for it, and that belongs with
		currency in a later phase.
	]]
	Revive = {
		perStage = 1,
		--[[ Seconds nothing can hurt the player after reviving. ]]
		invulnerable = 2.5,
		--[[ Studs around the player swept clear of enemy shots on revive,
		     so the volley that killed them does not kill them twice. ]]
		clearRadius = 12,
	},

	Run = {
		--[[ Where the exit is: just inside the gate in the north wall
		     (`Arena/ExitGate`). Walking into its light is the only way
		     forward, and it is the full length of the room from the spawn,
		     so clearing a room still means crossing it. ]]
		doorOffset = Vector2.new(0, -26.5),
		--[[ Studs from that point that count as reaching the exit. ]]
		doorRadius = 3.5,
		--[[
			The exit gate, after Archero 2's (owner, 2026-10-22, from
			footage): a gatehouse in the gap of the north wall whose doorway
			is a dark purple haze until the room is cleared, then blazes
			white-gold with light, sparkles and a GO arrow on the floor.
			Mossy stone, for the glade.
		]]
		gate = {
			width = 6,
			height = 6.5,
			depth = 3,
			pillarWidth = 2.2,
			stoneColor = Color3.fromRGB(150, 156, 168),
			mossColor = Color3.fromRGB(104, 168, 64),
			roofColor = Color3.fromRGB(86, 140, 58),
			plaqueColor = Color3.fromRGB(196, 200, 210),
			plaqueTextColor = Color3.fromRGB(70, 74, 86),
			closedColor = Color3.fromRGB(58, 28, 86),
			openColor = Color3.fromRGB(255, 238, 186),
			lightRange = 18,
			lightBrightness = 3,
			sparkleRate = 14,
			--[[ Studs of light spilled onto the floor in front of it. ]]
			spillLength = 5,
		},
		--[[ Seconds between a room clearing and the door opening, so a kill
		     gets its own beat instead of being swallowed by the next room. ]]
		clearPause = 0.8,
		--[[ Seconds the run-over message holds before the run restarts. ]]
		deathPause = 2.5,
	},

	Spawning = {
		--[[
			Minimum studs between a spawn point and the player.

			Scaled with the room from the original fifty-six, which was set
			after Playtest 2 because enemies arriving close enough felt like
			they appeared on top of the player. Twenty-one keeps that same
			share of the room. Archero 2 also marks where each enemy will
			appear before it does, so a wave reads as something arriving
			rather than something already there. See the spawn-placement note
			in EnemyManager.
		]]
		minSpawnDistance = 21,

		--[[
			Seconds an enemy's spawn marker shows before the enemy appears.

			Measured from the footage: markers start appearing about 0.8 to
			1.0 seconds before the wave, and the wave lands all together. The
			marker is the player's chance to decide where to stand before a
			room that is about to fill — without it, a wave reads as having
			been there all along.
		]]
		arrivalTell = 0.9,
		--[[ Extra seconds per enemy after the first, so markers come up a few
		     at a time, as they do in the footage, rather than on one frame. ]]
		arrivalStagger = 0.08,
		--[[ Enemies arrive in triangles of this many, as in the footage: the
		     first at a spawn point found the usual way, pointing at the
		     player, the rest in a row behind it. ]]
		clusterSize = 3,
		--[[ Studs of floor between neighbours in a cluster, edge to edge. ]]
		clusterGap = 1.4,
	},

	Feedback = {
		hitFlashDuration = 0.08,
		--[[ An enemy hit squashes onto its feet and springs back
		     (`Fx/HitSquash`): flattened by this share at the hit, settled
		     by `hitSquashDuration` seconds. Not on burn ticks. ]]
		--[[ 0.2 at first; the owner asked for it "a little more
		     noticeable" (2026-10-22). ]]
		hitSquash = 0.3,
		hitSquashDuration = 0.36,
		--[[ Studs a hit flattens a body by, so small enemies squash as
		     visibly as the Brood Slime (3.4 tall at 0.3): a share of
		     `hitSquashStuds / height`, from `hitSquash` up to `hitSquashMax`. ]]
		hitSquashStuds = 1,
		hitSquashMax = 0.45,
		--[[ The squash an enemy lands with as it appears, like the Brood
		     Slime's pieces landing. ]]
		landSquash = 0.5,
		landSquashDuration = 0.45,
		hitFlashColor = Color3.fromRGB(255, 255, 255),
		damageNumberRise = 4,
		damageNumberDuration = 0.7,
		--[[ How each kind of hit is drawn, after Archero 2: a plain hit in
		     white with a dark outline, a crit larger and red, fire smaller
		     and orange. `scale` multiplies the number's size. ]]
		damageNumberStyles = {
			Hit = { color = Color3.fromRGB(255, 255, 255), scale = 1 },
			Crit = { color = Color3.fromRGB(255, 64, 40), scale = 1.6 },
			Burn = { color = Color3.fromRGB(255, 150, 40), scale = 0.75 },
		},
		shakeOnDamageMagnitude = 1.6,
		shakeOnDamageDuration = 0.25,

		--[[
			What happens to the player's own character when something lands on
			it. Deliberately separate numbers from the enemy flash above, and
			deliberately louder.

			An enemy flash confirms something the player chose to do. This one
			reports something done *to* them, while they were busy reading the
			room — so it has to survive not being looked at directly. It runs
			twice as long, in a colour nothing else in the game uses.
		]]
		playerHitColor = Color3.fromRGB(255, 86, 74),
		playerHitDuration = 0.18,
		--[[ A ring thrown off the character, so a hit is legible from the
		     silhouette alone when the character itself is behind a projectile
		     or under a damage number. ]]
		playerHitBurstRadius = 5.5,
		playerHitBurstDuration = 0.28,
		--[[
			Screen-edge flare: how far in from each edge the glow reaches, as a
			fraction of that axis, and how long it takes to clear.

			Kept shallow on purpose. The player is being asked to find a gap in
			a fan of projectiles at the moment this fires, and a vignette deep
			enough to be dramatic is a blindfold on a phone.
		]]
		vignetteReach = 0.16,
		vignetteDuration = 0.34,
		vignetteColor = Color3.fromRGB(216, 40, 36),

		--[[
			The blast from Blast Arrows.

			Loud on purpose. An explosion the player cannot see is an upgrade
			they cannot tell is working — three enemies die and two of them
			for no visible reason. It is drawn at the real radius so the
			player learns the shape of the thing they bought, and the ground
			ring snaps to full size immediately because the area is the
			information; only the fade is animated.
		]]
		explosionDuration = 0.32,
		explosionColor = Color3.fromRGB(255, 170, 70),
		explosionCoreColor = Color3.fromRGB(255, 244, 214),
	},

	--[[
		The camera, matched to Archero 2.

		Measured from 1080x1920 footage: their camera never moves sideways and
		always shows the room's full width — the floor fills about 85% of the
		screen across, and ours sits a little wider than that by choice —
		while following the player up and down a room that is
		taller than the screen. Ours used to sit at a fixed offset with a wide
		lens, which on a phone showed about 38% of the room's width and a long
		stretched-out depth behind it.

		So instead of an offset, the distance is *solved* each frame from the
		screen's shape, so the room's width fits on any phone. A steep pitch and
		a narrow lens keep it close to flat, which is how theirs reads.
	]]
	Camera = {
		-- Degrees below the horizon. Steep, so it reads as nearly top-down.
		pitch = 68,
		--[[ Narrow, so distance does the zooming and perspective stays mild.
		     A wide lens close in is what made far enemies tiny before. ]]
		fieldOfView = 40,
		--[[ Studs of ground the screen spans side to side at the focus. The
		     35-stud floor fills about 67% of it — zoomed out past the
		     footage's 85% over two playtests, so more of the room and what is
		     coming in from its edges is in view. ]]
		fitWidth = 52,
		--[[ On a landscape screen, fitting the width alone would zoom right in
		     and show almost no depth; this is the least depth it may show.
		     54 puts about the whole 58-stud room on a landscape screen at
		     once — "I want to see most of the arena at once". A portrait
		     phone, fitted by width, already shows all of it. ]]
		minVisibleDepth = 54,
		--[[ Studs of ground past each end of the room the view may show, so the
		     end walls are in frame. The camera works out how far its view
		     reaches from the focus and keeps that inside the room plus this;
		     a view longer than the room centres it instead of following. ]]
		wallMargin = 3,
		--[[ The same past the north wall, where the exit gate stands: enough
		     to show the whole gatehouse as the player nears it. At 3 the
		     camera stopped at the wall and the gate never came into view. ]]
		gateMargin = 12,
		-- How fast the camera catches up, as a per-second lerp factor.
		followSharpness = 12,
		--[[ A phone's framing, closer: "everything needs to be zoomed in on
		     the phone" (owner, 2026-10-22). The desktop's numbers put the
		     whole room on a six-inch screen. Held sideways, a phone shows 34
		     studs of depth rather than 54 — 1.6× closer — and follows the
		     player up and down the room for the rest; held upright, the
		     floor fills about 87% of its width, the Archero 2 footage's
		     framing, rather than 67%. ]]
		phone = {
			--[[ 40 and 34 until "the camera view also needs to be zoomed in
			     a little more on the phone" (owner, 2026-10-22): the floor
			     now fills about 97% of an upright phone's width, still all
			     of it (CameraFit.spec), and sideways shows 30 studs of
			     depth. ]]
			fitWidth = 36,
			minVisibleDepth = 30,
		},
	},
}

return table.freeze(Balance)
