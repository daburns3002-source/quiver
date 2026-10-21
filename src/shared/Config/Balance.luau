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
export type EnemyTell = "Flash" | "Line"

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
}

local meleeCharger: EnemyConfig = {
	displayName = "Charger",
	health = 30,
	moveSpeed = 9,
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
	moveSpeed = 6,
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
		speed = 16,
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
	moveSpeed = 5,
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
		speed = 80,
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
	moveSpeed = 4,
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
}

local Balance = {
	Player = {
		maxHealth = 100,
		-- Studs per second. Archero's archer is slow enough that committing to a
		-- direction costs something.
		moveSpeed = 16,
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
		speed = 70,
		lifetime = 2.5,
		radius = 0.35,
		-- Hard cap on live server projectiles. Phase 3 abilities multiply volley
		-- size aggressively; this is the backstop.
		maxActive = 400,
	},

	Enemies = {
		MeleeCharger = meleeCharger,
		SpreadShooter = spreadShooter,
		LineSniper = lineSniper,
		Tank = tank,
	},

	--[[ Drawn tell for a `Line` shot: how thick the line is, and how far past
	     the target it reaches so the player can see it is a line rather than a
	     distance. ]]
	Telegraph = {
		lineThickness = 0.35,
		lineOvershoot = 12,
		lineColor = Color3.fromRGB(236, 92, 84),
	},

	--[[ Colour an enemy flashes to while winding up a telegraphed shot. The
	     tell has to be visible before the projectile exists, or the telegraph
	     is decoration. ]]
	TelegraphColor = Color3.fromRGB(255, 226, 150),

	Arena = {
		size = Vector3.new(90, 1, 90),
		wallHeight = 14,
		wallThickness = 2,
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

	Spawning = {
		-- Phase 1 is one room with a fixed wave. Room flow arrives in Phase 2.
		enemyCount = 6,
		-- Minimum studs between a spawn point and the player.
		minSpawnDistance = 28,
		-- Seconds after the wave clears before it respawns, so the slice can be
		-- played for longer than one fight.
		respawnDelay = 3,
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
