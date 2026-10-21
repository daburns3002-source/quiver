--!strict
--[[
	Every tunable number in Phase 1. Pure data — no logic, no requires.

	If a gameplay constant is written inline anywhere else, it is a bug.
]]

--[[
	How a wind-up is shown to the player.

	`Flash` recolours the enemy: enough for a fan you dodge by moving at all.
	`Line` draws the actual path the shot will take, which only means anything
	if that path is honest — see `locksAim`.
]]
export type EnemyTell = "Flash" | "Line" | "Ground"

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
	shot: EnemyShot?,
	burrow: EnemyBurrow?,
}

local meleeCharger: EnemyConfig = {
	displayName = "Charger",
	health = 30,
	moveSpeed = 7.5,
	-- Studs from the player at which it lands a hit.
	attackRange = 4,
	attackDamage = 10,
	attackCooldown = 1,
	-- Studs the enemy is shoved back per hit taken.
	knockback = 2,
	hitboxSize = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(214, 96, 86),
	xpReward = 10,
	--[[ Melee: closes to attackRange and swings. A ranged archetype sets
	     `shot` instead and keeps its distance. ]]
	shot = nil,
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
	health = 24,
	moveSpeed = 5,
	--[[ Ranged enemies treat attackRange as the distance they want to hold,
	     not the distance they close to. ]]
	attackRange = 34,
	attackDamage = 8,
	attackCooldown = 2.2,
	knockback = 2,
	hitboxSize = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(150, 110, 200),
	xpReward = 14,
	shot = {
		-- Odd count so one projectile always runs down the centre.
		count = 3,
		-- Radians between neighbouring projectiles in the fan.
		spread = math.rad(18),
		--[[ Slow on purpose. Enemy projectiles have to be readable and
		     dodgeable on a small screen; 8–20 studs/s is the band the teardown
		     calls for. ]]
		speed = 13,
		lifetime = 4,
		--[[ Seconds of wind-up before the volley leaves, so the player reacts
		     to the tell rather than to the projectile. ]]
		telegraph = 0.45,
		tell = "Flash",
		--[[ Re-aims as it fires. Against a fan the counterplay is to keep
		     moving, so letting it track rewards exactly that. ]]
		locksAim = false,
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
	health = 20,
	moveSpeed = 4.25,
	attackRange = 48,
	attackDamage = 16,
	attackCooldown = 3,
	knockback = 2,
	hitboxSize = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(96, 150, 214),
	xpReward = 16,
	shot = {
		count = 1,
		spread = 0,
		--[[ Fast, unlike the Spitter. The telegraph is the counterplay here,
		     not the flight time — once it fires, it has already hit. ]]
		speed = 45,
		lifetime = 2,
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
	health = 120,
	moveSpeed = 3.5,
	attackRange = 5,
	attackDamage = 18,
	attackCooldown = 1.6,
	--[[ Barely flinches. Knockback on something this heavy would let a player
	     stall it indefinitely with chip damage. ]]
	knockback = 0.4,
	hitboxSize = Vector3.new(6, 8, 6),
	color = Color3.fromRGB(120, 124, 138),
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
	health = 26,
	moveSpeed = 6,
	attackRange = 26,
	attackDamage = 10,
	attackCooldown = 2.4,
	knockback = 2,
	hitboxSize = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(110, 190, 140),
	xpReward = 20,
	shot = {
		--[[ Wider and denser than the Spitter's: it surfaces at close range,
		     so the fan has to threaten the space around the player rather than
		     a lane across the room. ]]
		count = 5,
		spread = math.rad(24),
		speed = 14,
		lifetime = 3,
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
		surfaceDistance = 8,
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
		name = "First Cover",
		--[[
			A screen straight across the spawn's sight-line.

			The opener used to be bare ground, and bare ground is the one shape
			that teaches nothing: the archer out-ranges the room from where it
			arrives, so four enemies died in about five seconds without the
			player taking a step. A room that never asks you to move is a poor
			way to introduce a game about deciding when to stand still.

			This screen is wide enough that shooting past it means walking
			clear of it — but enemy shots fly over it, so standing behind it
			costs damage and buys no safety. That is the asymmetry the whole
			game rests on, stated in the first room rather than discovered in
			the fourth.
		]]
		obstacles = {
			{ offset = Vector2.new(0, 18), size = Vector3.new(34, 10, 6) },
		},
		--[[ Three, not four. Playtest 2 found the opener too hard: it is the
		     room where a player is still learning that stopping is a choice,
		     and it should not also be the room that punishes them hardest for
		     getting it wrong. ]]
		--[[ Chargers only. The first room teaches one thing: stopping is a choice. ]]
		enemyCount = 2,
		roster = { meleeCharger },
	},
	{
		name = "Two Pillars",
		obstacles = {
			{ offset = Vector2.new(-14, 0), size = Vector3.new(8, 10, 8) },
			{ offset = Vector2.new(14, 0), size = Vector3.new(8, 10, 8) },
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
			{ offset = Vector2.new(0, 0), size = Vector3.new(6, 10, 46) },
		},
		--[[ No new archetype. Room three is for practising room two in a worse shape. ]]
		enemyCount = 3,
		roster = { meleeCharger, spreadShooter },
	},
	{
		name = "Scatter",
		obstacles = {
			{ offset = Vector2.new(-20, -14), size = Vector3.new(8, 10, 8) },
			{ offset = Vector2.new(22, -18), size = Vector3.new(6, 10, 14) },
			{ offset = Vector2.new(-24, 20), size = Vector3.new(12, 10, 6) },
			{ offset = Vector2.new(16, 18), size = Vector3.new(8, 10, 8) },
			{ offset = Vector2.new(0, 0), size = Vector3.new(6, 10, 6) },
		},
		--[[ Adds the bulwark, which is really a piece of terrain that hits back. ]]
		enemyCount = 4,
		roster = { meleeCharger, spreadShooter, meleeCharger, tank },
	},
	{
		name = "The Gauntlet",
		-- Two corridors. Ranged enemies at the far end own the lanes.
		obstacles = {
			{ offset = Vector2.new(-12, 0), size = Vector3.new(6, 10, 60) },
			{ offset = Vector2.new(12, 0), size = Vector3.new(6, 10, 60) },
		},
		--[[ Adds the lancer. A drawn line to step out of, in the room with lanes. ]]
		enemyCount = 4,
		roster = { meleeCharger, spreadShooter, lineSniper },
	},
	{
		name = "Quarters",
		obstacles = {
			{ offset = Vector2.new(0, -20), size = Vector3.new(40, 10, 6) },
			{ offset = Vector2.new(0, 20), size = Vector3.new(40, 10, 6) },
		},
		--[[ No new archetype. Four of them at once instead. ]]
		enemyCount = 5,
		roster = { meleeCharger, spreadShooter, lineSniper, tank },
	},
	{
		name = "The Pit",
		-- A ring of cover around a bare centre. Standing in the middle is the
		-- worst possible place to stop, which is where the fight pulls you.
		obstacles = {
			{ offset = Vector2.new(-24, -24), size = Vector3.new(10, 10, 10) },
			{ offset = Vector2.new(24, -24), size = Vector3.new(10, 10, 10) },
			{ offset = Vector2.new(-24, 24), size = Vector3.new(10, 10, 10) },
			{ offset = Vector2.new(24, 24), size = Vector3.new(10, 10, 10) },
		},
		--[[ Adds the lurker, last because it is the only one that stops being a target. ]]
		enemyCount = 5,
		roster = { meleeCharger, spreadShooter, burrower, tank },
	},
	{
		name = "Teeth",
		obstacles = {
			{ offset = Vector2.new(-28, 0), size = Vector3.new(6, 10, 30) },
			{ offset = Vector2.new(0, -18), size = Vector3.new(6, 10, 30) },
			{ offset = Vector2.new(28, 0), size = Vector3.new(6, 10, 30) },
			{ offset = Vector2.new(0, 18), size = Vector3.new(6, 10, 30) },
		},
		--[[ All five, and from here the count is the only thing still rising. ]]
		enemyCount = 6,
		roster = { meleeCharger, spreadShooter, lineSniper, burrower, tank },
	},
	{
		name = "Last Cover",
		obstacles = {
			{ offset = Vector2.new(0, 0), size = Vector3.new(14, 10, 14) },
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
}

local Balance = {
	Player = {
		maxHealth = 100,
		--[[ Studs per second. Still slow enough that committing to a direction
		     costs something, but raised after Playtest 2: repositioning out of
		     cover has to be affordable, or the answer to every threat is to
		     stand still and hope. ]]
		moveSpeed = 18,
		baseDamage = 10,
		-- Seconds between volleys while stationary.
		attackCooldown = 0.45,
		-- Studs. Past this the archer holds fire rather than shooting at nothing.
		attackRange = 60,
		-- MoveDirection magnitude below which the archer counts as stationary.
		-- Not zero: thumbsticks idle noisy, and a dead archer is an unfair one.
		stationaryThreshold = 0.05,
		-- Seconds the archer must be still before firing resumes. Small, but
		-- non-zero stops a player machine-gunning by tapping the stick.
		stationaryDelay = 0.1,
	},

	Projectile = {
		--[[ Dropped a fifth after Playtest 2, along with every enemy shot, so
		     the ratio between them is unchanged. Slower arrows make a volley
		     something the player watches land rather than an instant line,
		     which is what gives standing still a visible cost. ]]
		speed = 56,
		lifetime = 2.5,
		--[[
			Half the width of the drawn arrow, and half the width of the box
			the server sweeps. These two numbers are the hitbox *and* the
			visual, which is the point: a projectile that is shown as a long
			dart but simulated as a tiny sphere only counts from its nose, so
			shots that plainly connected along the shaft did nothing.
		]]
		radius = 0.35,
		--[[ Length of that arrow, along its direction of travel. Shared rather
		     than a client constant, because the server has to sweep the same
		     shape the player is looking at. ]]
		length = 2.2,
		-- Hard cap on live server projectiles. Phase 3 abilities multiply volley
		-- size aggressively; this is the backstop.
		maxActive = 400,
	},

	Enemies = {
		MeleeCharger = meleeCharger,
		SpreadShooter = spreadShooter,
		LineSniper = lineSniper,
		Tank = tank,
		Burrower = burrower,
	},

	--[[ Drawn tell for a `Line` shot: how thick the line is, and how far past
	     the target it reaches so the player can see it is a line rather than a
	     distance. ]]
	Telegraph = {
		lineThickness = 0.35,
		lineOvershoot = 12,
		lineColor = Color3.fromRGB(236, 92, 84),
		--[[ Radius of the marker showing where something is about to surface.
		     Wider than the enemy so stepping to its edge is not enough. ]]
		groundRadius = 5,
		groundColor = Color3.fromRGB(236, 140, 84),
	},

	--[[ Colour an enemy flashes to while winding up a telegraphed shot. The
	     tell has to be visible before the projectile exists, or the telegraph
	     is decoration. ]]
	TelegraphColor = Color3.fromRGB(255, 226, 150),

	Arena = {
		size = Vector3.new(90, 1, 90),
		wallHeight = 14,
		wallThickness = 2,
		--[[ Where a player stands at the start of a room. Near the south wall,
		     the full length of the arena from the exit pad, so clearing a room
		     always means crossing it. Raised clear of the floor because
		     characters are placed here by CFrame, not dropped. ]]
		spawnPosition = Vector3.new(0, 4, 34),
		floorColor = Color3.fromRGB(96, 104, 120),
		wallColor = Color3.fromRGB(62, 68, 82),
		obstacleColor = Color3.fromRGB(78, 86, 102),
		-- Grey-box pillars. Positions are XZ offsets from arena centre.
		-- These block the player's arrows but NOT enemy attacks, which is the
		-- asymmetry the whole game rests on. See docs/RESEARCH-archero.md.
		obstacles = {
			{ offset = Vector2.new(-20, -14), size = Vector3.new(8, 10, 8) },
			{ offset = Vector2.new(22, -18), size = Vector3.new(6, 10, 14) },
			{ offset = Vector2.new(-24, 20), size = Vector3.new(12, 10, 6) },
			{ offset = Vector2.new(16, 18), size = Vector3.new(8, 10, 8) },
			{ offset = Vector2.new(0, 0), size = Vector3.new(6, 10, 6) },
		},
	},

	Rooms = rooms,

	Run = {
		--[[ The pad that appears when a room is cleared. Walking onto it is
		     the only way forward, so it has to be unmissable and far enough
		     from the spawn that clearing a room still means crossing it. ]]
		doorOffset = Vector2.new(0, -38),
		doorSize = Vector3.new(14, 0.4, 14),
		doorColor = Color3.fromRGB(120, 220, 160),
		--[[ Studs from the pad's centre that count as stepping on it. ]]
		doorRadius = 8,
		--[[ Seconds between a room clearing and the door opening, so a kill
		     gets its own beat instead of being swallowed by the next room. ]]
		clearPause = 0.8,
		--[[ Seconds the run-over message holds before the run restarts. ]]
		deathPause = 2.5,
	},

	Spawning = {
		--[[
			Minimum studs between a spawn point and the player.

			Doubled after Playtest 2. Enemies were still arriving close enough
			to feel like they appeared on top of the player, so the exclusion
			is now most of the arena's width — far enough that a wave reads as
			something approaching rather than something that was already
			there. See the spawn-placement note in EnemyManager.
		]]
		minSpawnDistance = 56,
	},

	Feedback = {
		hitFlashDuration = 0.08,
		hitFlashColor = Color3.fromRGB(255, 255, 255),
		damageNumberRise = 4,
		damageNumberDuration = 0.7,
		shakeOnDamageMagnitude = 1.6,
		shakeOnDamageDuration = 0.25,
	},

	Camera = {
		-- Offset from the character, in studs. A high, slightly-behind angle so
		-- the player can read incoming projectiles early.
		offset = Vector3.new(0, 58, 34),
		-- How fast the camera catches up, as a per-second lerp factor.
		followSharpness = 12,
		fieldOfView = 55,
	},
}

return table.freeze(Balance)
