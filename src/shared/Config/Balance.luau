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
	health = 300,
	moveSpeed = 4.6,
	-- Studs from the player at which it lands a hit.
	attackRange = 4,
	attackDamage = 56,
	attackCooldown = 1,
	-- Studs the enemy is shoved back per hit taken.
	knockback = 3,
	hitboxSize = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(226, 52, 56),
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
	health = 240,
	moveSpeed = 3.2,
	--[[ Ranged enemies treat attackRange as the distance they want to hold,
	     not the distance they close to. ]]
	attackRange = 13.3,
	attackDamage = 45,
	attackCooldown = 2.2,
	knockback = 3,
	hitboxSize = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(70, 206, 236),
	xpReward = 14,
	shot = {
		-- Odd count so one projectile always runs down the centre.
		count = 3,
		-- Radians between neighbouring projectiles in the fan.
		spread = math.rad(18),
		--[[
			Measured: Archero 2's slow purple orbs, tracked across 1.5 s of
			footage with the camera's drift taken out, travel 0.27–0.40
			room-widths a second — about 12 studs/s here, inside the 8–20
			band the teardown asks for. Rescaling with the room had pushed
			this down to 4, where an orb crawled.

			Lifetime keeps the reach it had (16 studs), so the speed is the
			only thing that changed.
		]]
		speed = 12,
		lifetime = 16 / 12,
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
	health = 200,
	moveSpeed = 2.6,
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
		     a second; one sample, so the least certain number here. Reach
		     held at 28 studs. ]]
		speed = 28,
		lifetime = 1,
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
	moveSpeed = 2.2,
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
	moveSpeed = 3.8,
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
		speed = 12,
		lifetime = 13.2 / 12,
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
		maxHealth = 225,
		--[[ Studs per second. Raised in steps over several playtests:
		     repositioning has to be affordable, or the answer to every threat
		     is to stand still and hope. 9 across a 35-stud room is 0.26
		     room-widths a second, brisker than the footage's 0.19 by choice. ]]
		moveSpeed = 9,
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
			fast enough to land before most targets can step aside.
		]]
		speed = 110,
		--[[ 45 studs of flight, the reach playtesting settled on: a little
		     over `Player.attackRange`, so a shot at the edge of range
		     arrives, and not so far that arrows sail on after the fight.
		     Held as a distance by `Balance.spec`, so this follows `speed`. ]]
		lifetime = 45 / 110,
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
		--[[ Seconds between Double Shot's volleys. Our number, not the
		     footage's — Double Shot is never drafted in the reference video.
		     Short enough that the pair reads as one attack; long enough
		     that the second arrow is a second chance at a target that
		     moved. Held under the fastest fire rate by `Balance.spec`. ]]
		doubleShotInterval = 0.12,
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

	Burn = {
		duration = 2,
		tick = 0.5,
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
	} :: { StageConfig },

	--[[ Which stage a run plays. Set per point in the game; one index here
	     until there is a stage select. ]]
	stage = 2,

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
		--[[ Studs from a crystal to the player that count as walking over
		     it. Generous: crystals are small and the fight is busy. ]]
		crystalRadius = 3,
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
		--[[ Studs from a heart's centre to the player's that count as
		     walking over it. ]]
		heartRadius = 2.5,

		crystalColor = Color3.fromRGB(70, 210, 255),
		heartColor = Color3.fromRGB(255, 60, 90),
	},

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
		-- How fast the camera catches up, as a per-second lerp factor.
		followSharpness = 12,
	},
}

return table.freeze(Balance)
