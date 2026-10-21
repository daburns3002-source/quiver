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
export type TelegraphTell = EnemyTell | "Dive" | "Spawn"

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
}

local meleeCharger: EnemyConfig = {
	displayName = "Charger",
	--[[ Quick: it commits to a direction and turns hard to keep it. ]]
	turnRate = 540,
	health = 30,
	moveSpeed = 2.3,
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
	--[[ Moderate: it stands off and tracks. ]]
	turnRate = 360,
	health = 24,
	moveSpeed = 1.6,
	--[[ Ranged enemies treat attackRange as the distance they want to hold,
	     not the distance they close to. ]]
	attackRange = 13.3,
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
		speed = 4,
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
	--[[ Deliberate: it swings round to line the lance up. ]]
	turnRate = 240,
	health = 20,
	moveSpeed = 1.3,
	attackRange = 18.8,
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
		speed = 14,
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
	--[[ Ponderous. A quarter-turn takes a full second, which is what makes it read as heavy rather than as copying the player. ]]
	turnRate = 90,
	health = 120,
	moveSpeed = 1.1,
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
	--[[ Moderate, and only ever seen turning above ground. ]]
	turnRate = 360,
	health = 26,
	moveSpeed = 1.9,
	attackRange = 10.1,
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
		speed = 4.4,
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
		--[[ No new archetype. Room three is for practising room two in a worse shape. ]]
		enemyCount = 3,
		roster = { meleeCharger, spreadShooter },
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
		--[[ No new archetype. Four of them at once instead. ]]
		enemyCount = 5,
		roster = { meleeCharger, spreadShooter, lineSniper, tank },
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
}

local Balance = {
	Player = {
		maxHealth = 100,
		--[[ Studs per second. Still slow enough that committing to a direction
		     costs something, but raised after Playtest 2: repositioning out of
		     cover has to be affordable, or the answer to every threat is to
		     stand still and hope. ]]
		moveSpeed = 6.5,
		baseDamage = 10,
		-- Seconds between volleys while stationary.
		attackCooldown = 0.45,
		-- Studs. Past this the archer holds fire rather than shooting at nothing.
		attackRange = 50,
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
		--[[ Seconds of standing still before Momentum reaches its full bonus.
		     Long enough that it is a commitment, short enough that it pays
		     inside a single volley exchange. ]]
		momentumRamp = 2.5,

		dash = {
			distance = 4,
			duration = 0.18,
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
		--[[ Dropped a fifth after Playtest 2, along with every enemy shot, so
		     the ratio between them is unchanged. Slower arrows make a volley
		     something the player watches land rather than an instant line,
		     which is what gives standing still a visible cost. ]]
		speed = 17.4,
		lifetime = 3.2,
		--[[
			Half the width of the drawn arrow, and half the width of the box
			the server sweeps. These two numbers are the hitbox *and* the
			visual, which is the point: a projectile that is shown as a long
			dart but simulated as a tiny sphere only counts from its nose, so
			shots that plainly connected along the shaft did nothing.
		]]
		radius = 0.35,
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
			zone the sweep cannot see into — 1.5 studs here, against about a
			third of a stud of travel per frame. ProjectileSystem pays for
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
		floorColor = Color3.fromRGB(96, 104, 120),
		wallColor = Color3.fromRGB(62, 68, 82),
		obstacleColor = Color3.fromRGB(78, 86, 102),
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

	Run = {
		--[[ The pad that appears when a room is cleared. Walking onto it is
		     the only way forward, so it has to be unmissable and far enough
		     from the spawn that clearing a room still means crossing it. ]]
		doorOffset = Vector2.new(0, -23),
		doorSize = Vector3.new(6, 0.4, 6),
		doorColor = Color3.fromRGB(120, 220, 160),
		--[[ Studs from the pad's centre that count as stepping on it. ]]
		doorRadius = 3.5,
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
	},

	Feedback = {
		hitFlashDuration = 0.08,
		hitFlashColor = Color3.fromRGB(255, 255, 255),
		damageNumberRise = 4,
		damageNumberDuration = 0.7,
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
		     35-stud floor fills about 78% of it — zoomed out a little past the
		     footage's 85% after playtest, so more of the room's edges and
		     what is coming in from them is in view. ]]
		fitWidth = 45,
		--[[ On a landscape screen, fitting the width alone would zoom right in
		     and show almost no depth; this is the least depth it may show. ]]
		minVisibleDepth = 36,
		--[[ Studs the focus is kept inside the room's back and front walls, so
		     the view stops at the room's edge instead of scrolling past it. ]]
		edgeMargin = 11,
		-- How fast the camera catches up, as a per-second lerp factor.
		followSharpness = 12,
	},
}

return table.freeze(Balance)
