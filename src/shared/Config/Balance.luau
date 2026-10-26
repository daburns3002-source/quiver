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
	`Eyes` turns only the eyes red, pulsing, and draws nothing on the floor:
	the Ember Wilf's charge (owner, 2026-10-23: "no line and the eyes just
	flash red before he charges").
]]
export type EnemyTell = "Flash" | "Line" | "Ground" | "Eyes"

--[[
	What the telegraph channel is allowed to carry.

	Wider than `EnemyTell`, and deliberately a separate type: a shot's tell is
	a warning about something that has not happened yet, while a dive has
	already happened by the time it is drawn. They share a channel because
	they are the same thing to render — a mark at a point, for a moment — but
	`EnemyShot.tell` must not be allowed to name one.
]]
export type TelegraphTell =
	EnemyTell
	| "Dive"
	| "Spawn"
	| "Split"
	| "Slam"
	| "Shockwave"
	| "LaneAim"
	| "Lane"
	| "Shake"
	| "Meteor"
	| "MeteorImpact"
	| "GroundSlam"
	| "Cracks"
	| "Erupt"

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
	--[[ For a body that plays its own clips: the clip it falls with as it
	     splits, in place of its Death. ]]
	clip: string?,
	--[[ For pieces that play their own clips: each is thrown as itself,
	     playing this clip over `Balance.Split.flight + settle`, instead of
	     as a blob of jelly (`Fx/SplitFx`). ]]
	pieceClip: string?,
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
	--[[ Seconds between the fan's projectiles leaving, one after another
	     across the fan, when they should not all leave at once: set to the
	     beats of the enemy's shot sound, so each one is heard as it leaves.
	     Nil fires the whole fan together. ]]
	every: number?,
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

--[[
	A boss's moves (docs/BOSSES.md; the Slime King's from the owner's
	design_handoff_slime_king, 2026-10-23). A boss does not walk and swing:
	it plays its moves in a loop, `Enemies/BossMoves` running each one as a
	timeline and `EnemyManager` resolving what lands. Times are seconds,
	distances studs; `shove` is how far a hit pushes the player.
]]
--[[ Royal Bounce: a telegraphed hop, slam and shockwave, `bounces` times,
     each landing where the target stood at takeoff (no homing), then a
     winded pause that is the punish window. ]]
export type BossBounce = {
	bounces: number,
	windup: number,
	launch: number,
	air: number,
	recover: number,
	winded: number,
	height: number,
	maxRange: number,
	radius: number,
	damage: number,
	shove: number,
	shockRadius: number,
}

--[[ Slime Lash: an arm thrown down a lane that tracks the target for
     `track`, then locks; a hit grabs the first player in it, pulls the boss
     to them and ends in a chest bump. One lash per arm in `arms`. ]]
export type BossLash = {
	arms: { string },
	wind: number,
	track: number,
	strike: number,
	hold: number,
	retract: number,
	reach: number,
	minReach: number,
	width: number,
	damage: number,
	shove: number,
	pull: number,
	bump: number,
	bumpDamage: number,
	bumpShove: number,
	recover: number,
	stopDistance: number,
	--[[ For a body that plays clips (`BossClips`): studs from the feet to
	     the chain's root (the shoulder it is thrown from), and to its fist
	     when the lane is `reach` long, as the clips draw them. A shorter
	     lane shortens the chain from its root (`BossMoves.chainScale`), so
	     the fist always lands as near the lane's end as at full reach. ]]
	chainRoot: number?,
	chainReach: number?,
}

--[[ The clip a boss's body plays in each phase of a move, for a body that
     carries its own clips (an imported Claude Design rig, `Config/
     ModelClips`): `idle` between moves, `Bounce` by phase, `Lash` by arm
     then phase. Phases that share a clip play it once across both. ]]
export type BossClips = {
	idle: string,
	Bounce: { [string]: string },
	Lash: { [string]: { [string]: string } },
	Spin: { [string]: string }?,
}

--[[ Web Walker (the Broodmother; owner, 2026-10-25, concept sheet
     `assets/concepts/blocky/broodmother_web_walker_concept.png`): she
     raises a web `radius` studs round her, warned for `windup`, that spins
     clockwise once every `period` seconds for `spin`, then snaps and leaves
     her slumped for `broken`. Under the web hurts; outside it `spokes` arms
     `width` wide reach on to `reach` and sweep the floor, so the player
     walks round with them, like a horse in a horse walker. A player is hit
     at most every `hitEvery`, for `damage`, and pushed `shove` (out from
     under the web, or on round with an arm). `holdSpan` is the length of
     the clip she holds while it spins, so that loop keeps its own pace;
     `height` is where the web hangs over the floor (drawn only). First she
     scuttles to the middle of the room at `travelSpeed` (owner, 2026-10-25:
     "go the middle of the arena every time"), taking at least `travelMin`. ]]
export type BossSpin = {
	travelSpeed: number,
	travelMin: number,
	windup: number,
	spin: number,
	broken: number,
	recover: number,
	spokes: number,
	radius: number,
	reach: number,
	width: number,
	period: number,
	damage: number,
	hitEvery: number,
	shove: number,
	holdSpan: number,
	height: number,
}

export type BossChase = {
	speed: number,
	stopDistance: number,
	clip: string,
}

export type EnemyBoss = {
	--[[ What the boss bar calls it. ]]
	title: string,
	bounce: BossBounce,
	lash: BossLash,
	--[[ Seconds it rests after each move; the moves loop Bounce, Lash
	     unless `loop` names its own order. ]]
	restAfterBounce: number,
	restAfterLash: number,
	restAfterSpin: number?,
	loop: { string }?,
	--[[ Web Walker, for a boss whose `loop` has "Spin". ]]
	spin: BossSpin?,
	--[[ Set for a boss that runs at the player between moves (her rests
	     and her opening) instead of standing still: `speed` studs a
	     second, stopping `stopDistance` from the player, playing `clip`. ]]
	chase: BossChase?,
	--[[ Seconds before its first move, once it has arrived. ]]
	opening: number,
	--[[ Set when the body plays its own clips; nil for a body the server
	     poses (`Enemies/BossBody`). ]]
	clips: BossClips?,
	--[[ Her lash is a web (the Broodmother): the client draws a silk strand
	     and a web splat (`Fx/BroodWebFx`) in place of the Slime King's
	     slime, and no goo. ]]
	web: boolean?,
	--[[ After every `every`th move she plays `clip` for `windup` seconds,
	     then `count` of `into` drop round her. ]]
	summon: BossSummon?,
}

export type BossSummon = {
	into: EnemyConfig,
	count: number,
	every: number,
	clip: string,
	windup: number,
}

--[[
	A lunge: the enemy winds up where it stands, locks the direction to its
	target, then bolts down that line at `speed` for `distance` studs,
	striking the player once if it touches them on the way. Stopped short
	by cover. The counterplay is the same as a locked shot's: read the tell
	and step out of the line before it goes.

	An archetype can have several, chosen by how far away the player is
	(`minRange`..`maxRange`); they share its `attackCooldown`, which starts
	when the wind-up does.
]]
export type EnemyLunge = {
	minRange: number,
	maxRange: number,
	--[[ Seconds of wind-up, standing still, before it goes. ]]
	telegraph: number,
	tell: EnemyTell,
	distance: number,
	--[[ Studs a second while lunging. ]]
	speed: number,
	--[[ Multiplier on `attackDamage` for a hit during this lunge. ]]
	damageScale: number,
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
	boss: EnemyBoss?,
	--[[ Lunging attacks, in place of the plain melee hit. ]]
	lunges: { EnemyLunge }?,
	--[[ A training dummy (the Studio sandbox, `Config/Sandbox`): it stands
	     still, never attacks, and every hit refills its health, so it is
	     struck for as long as anyone likes and never dies. ]]
	dummy: boolean?,
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
	hitboxSize = Vector3.new(3, 2.7, 2.6),
	color = Color3.fromRGB(226, 52, 56),
	xpReward = 10,
	--[[ Melee: closes to attackRange and swings. A ranged archetype sets
	     `shot` instead and keeps its distance. ]]
	shot = nil,
}

--[[
	The Baby Slime (the owner's updated slimes, 2026-10-23): one of the four
	babies that ride in a Brood Slime's moss, on its own. Small, quick and
	frail; it only ever arrives by a Brood Slime splitting.
]]
local babySlime: EnemyConfig = {
	displayName = "BabySlime",
	--[[ Small, so it turns quickest of all. ]]
	turnRate = 600,
	--[[ Half a Moss Slime's: two arrows. ]]
	health = 150,
	moveSpeed = 7.8,
	attackRange = 3.4,
	attackDamage = 40,
	attackCooldown = 1,
	knockback = 3.5,
	--[[ Its model ×2 is 2.5 across and 1.24 tall; the box is 1.5 tall so
	     arrows at `Projectile.height` meet it. ]]
	hitboxSize = Vector3.new(2.5, 1.5, 2.5),
	color = Color3.fromRGB(127, 203, 36),
	xpReward = 5,
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
	hitboxSize = Vector3.new(4.0, 4.6, 3.5),
	color = Color3.fromRGB(226, 52, 56),
	xpReward = 20,
	shot = nil,
	--[[ Four, one per baby, like Zac; at half a Moss Slime's health each
	     (owner, 2026-10-22: Level 1 was too hard). ]]
	--[[ Four Baby Slimes, one per baby in its moss (owner's updated model,
	     2026-10-23); they were Moss Slimes at half health. ]]
	split = { into = babySlime, count = 4, health = 1 },
}

--[[
	The Ember Wilf (owner, 2026-10-23: "a wilf enemy that has a charge and
	dash attack ... modeled after this dog"): a fluffy ginger wilf, quick
	and low, that never just walks up and bites. From across the room it
	charges, its eyes flashing red first; up close it dashes,
	a short pounce on a quick flash. Both are lunges (`EnemyLunge`), so the
	answer to both is the same — see where it is pointed and get out of the
	line. Its body is primitives in the dog's colours until its model exists
	(`assets/concepts/models/ember_wilf_sheet.png`).
]]
local wilf: EnemyConfig = {
	displayName = "Wilf",
	--[[ As slow to turn as anything its size (it is the longest of the
	     grunts); its lunges snap it onto their line regardless, so this only
	     shapes how it walks. ]]
	turnRate = 240,
	health = 260,
	moveSpeed = 6.3,
	--[[ It closes to here, inside the dash, then lunges; it has no plain
	     bite. ]]
	attackRange = 5,
	attackDamage = 60,
	attackCooldown = 1.8,
	knockback = 2.5,
	--[[ The owner's model's own shape, ×2.6 (`assets/models/enemies/
	     ember_wilf_roblox.glb`, a round pup): 2.2 across, 3 tall, 3.3 nose
	     to tail. Arrows at `Projectile.height` meet it. ]]
	hitboxSize = Vector3.new(2.2, 3, 3.3),
	color = Color3.fromRGB(214, 116, 48),
	xpReward = 16,
	shot = nil,
	lunges = {
		--[[ Dash: close, quick, and lighter. ]]
		{
			minRange = 0,
			maxRange = 8,
			telegraph = 0.4,
			tell = "Flash" :: EnemyTell,
			distance = 7,
			speed = 32,
			damageScale = 0.8,
		},
		--[[ Charge: from across the room, on a long line, and it hurts. Its
		     eyes flash red as it winds up, with no line drawn (owner,
		     2026-10-23). ]]
		{
			minRange = 8,
			maxRange = 20,
			telegraph = 0.75,
			tell = "Eyes" :: EnemyTell,
			distance = 18,
			speed = 26,
			damageScale = 1.3,
		},
	},
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
	--[[ The Splitter Spitter's own shape (its model, 3 × 3.6 × 3), not the
	     shared 5-stud box; arrows at `Projectile.height` meet it. ]]
	hitboxSize = Vector3.new(3, 3.2, 3),
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
local _lineSniper: EnemyConfig = {
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

--[[
	The Slime King, Mossy Glade's boss (docs/BOSSES.md §1, the owner's
	design_handoff_slime_king, 2026-10-23). Alone in Level 1's last room.
	His moves are the handoff's, timings as given; damage is rescaled from
	its 100-health Roblox character to this game's 225 (×2.25, then the
	stage's 0.7), and its knockback speeds become `shove` distances.

	About 9.8 studs tall, as the handoff asks: its model ×2, and the
	hitbox fits it (`EnemyDesigns.SlimeKing`). He takes no knockback and
	does not walk; every move he makes is a move.
]]
local slimeKing: EnemyConfig = {
	displayName = "SlimeKing",
	--[[ Turned by his moves, not by walking; as slow as the Bulwark, as
	     big things are. ]]
	turnRate = 90,
	--[[ Twenty Moss Slimes' worth (4,800 at Level 1's 0.8). ]]
	health = 6000,
	moveSpeed = 0,
	attackRange = 0,
	attackDamage = 0,
	attackCooldown = 0,
	knockback = 0,
	hitboxSize = Vector3.new(9.6, 9.6, 8.0),
	color = Color3.fromRGB(127, 203, 36),
	xpReward = 100,
	boss = {
		title = "Slime King",
		bounce = {
			bounces = 3,
			--[[ The red circle shows from the start of the wind-up: 2.45 s
			     of warning before each slam. ]]
			windup = 0.9,
			launch = 0.15,
			air = 1.4,
			recover = 0.55,
			winded = 1.4,
			height = 14,
			maxRange = 22,
			radius = 7,
			damage = 56,
			shove = 7,
			shockRadius = 12,
		},
		lash = {
			arms = { "Arm_R", "Arm_L" },
			wind = 0.8,
			track = 0.4,
			strike = 0.2,
			hold = 0.35,
			retract = 0.45,
			reach = 18,
			minReach = 6,
			width = 3.5,
			damage = 45,
			--[[ Anyone else in the lane is knocked sideways out of it. ]]
			shove = 4,
			pull = 0.38,
			bump = 0.22,
			bumpDamage = 34,
			bumpShove = 9,
			recover = 0.6,
			--[[ The handoff's 5.5, plus the extra half-depth of a king twice
			     its size. ]]
			stopDistance = 7,
			--[[ King Bloblin's chain (`KingBloblin_Fight.glb`'s Lash_Hold), at
			     his 9.6 studs: thrown from about 3.2 studs ahead of his feet,
			     its fist lands 17.1 out down an 18-stud lane. `BossClips.spec`
			     measures both off the clip data. ]]
			chainRoot = 3.2,
			chainReach = 17.1,
		},
		restAfterBounce = 1.5,
		restAfterLash = 1,
		opening = 1,
		--[[ King Bloblin's 22 clips (the owner's King Bloblin Fight,
		     2026-10-24), on the beats of the moves above. The wind-up plays
		     across tracking and the lock; the chest bump across the lean and
		     the release. ]]
		clips = {
			idle = "Idle",
			Bounce = {
				windup = "Bounce_Windup",
				launch = "Bounce_Launch",
				air = "Bounce_Air",
				recover = "Bounce_Land",
				winded = "Winded",
			},
			Lash = {
				Arm_R = {
					track = "Lash_Wind_R",
					aimed = "Lash_Wind_R",
					strike = "Lash_Strike",
					slap = "Lash_Hold",
					retract = "Lash_Retract",
					pull = "Lash_Pull",
					lean = "Lash_ChestBump",
					release = "Lash_ChestBump",
					settle = "Lash_Recover",
				},
				Arm_L = {
					track = "Lash_Wind_L",
					aimed = "Lash_Wind_L",
					strike = "Lash_Strike_L",
					slap = "Lash_Hold_L",
					retract = "Lash_Retract_L",
					pull = "Lash_Pull_L",
					lean = "Lash_ChestBump_L",
					release = "Lash_ChestBump_L",
					settle = "Lash_Recover_L",
				},
			},
		},
	},
}

--[[
	Act 1, area 2: Thornwood (the owner's blocky models, Claude Design,
	2026-10-23 to 25). Each plays its own clips (`Config/ModelClips`):
	Idle and Move as it walks, `Attack wind-up` on its tell, `Death` as it
	falls. Each takes the nearest Mossy Glade enemy's behaviour, so Level 2
	adds bodies before it adds rules.

	The Bramble Boar: a charger that never just walks up and gores. From
	across the room it charges down a locked line; up close it dashes.
]]
local brambleBoar: EnemyConfig = {
	displayName = "BrambleBoar",
	--[[ Longer than the Wilf, so no quicker to turn; its charges snap it
	     onto their line regardless. ]]
	turnRate = 240,
	health = 320,
	moveSpeed = 5.7,
	attackRange = 5,
	attackDamage = 58,
	attackCooldown = 2,
	knockback = 2.5,
	--[[ Its model ×3.4: 3 across, 2.7 tall, 3.8 snout to tail. ]]
	hitboxSize = Vector3.new(3, 2.7, 3.8),
	color = Color3.fromRGB(150, 98, 60),
	xpReward = 16,
	shot = nil,
	lunges = {
		{
			minRange = 0,
			maxRange = 7,
			telegraph = 0.45,
			tell = "Flash" :: EnemyTell,
			distance = 6,
			speed = 28,
			damageScale = 0.8,
		},
		--[[ The charge: it flashes as it paws the ground (its wind-up
		     clip), then goes most of the room's length. ]]
		{
			minRange = 7,
			maxRange = 20,
			telegraph = 0.8,
			tell = "Flash" :: EnemyTell,
			distance = 17,
			speed = 24,
			damageScale = 1.25,
		},
	},
}

--[[ The Burr Thistle: Thornwood's Spitter, three burrs in a fan from
     anywhere in the room. Its burrs are the Spitter's seeds until the burr
     is modelled. ]]
local burrThistle: EnemyConfig = {
	displayName = "BurrThistle",
	turnRate = 360,
	health = 260,
	moveSpeed = 4.5,
	attackRange = 13.3,
	attackDamage = 45,
	attackCooldown = 3,
	knockback = 3,
	--[[ Its model ×2: 3.2 across, 3.8 tall, 2.4 deep. ]]
	hitboxSize = Vector3.new(3.2, 3.8, 2.4),
	color = Color3.fromRGB(150, 70, 170),
	xpReward = 14,
	shot = {
		count = 3,
		spread = math.rad(20),
		--[[ One burr per "ptoo" of its spit (`enemy_thistle_spit`, round
		     18 take A: three, 0.06 s apart), so they leave in time with it
		     (owner, 2026-10-25: "there should be a small delay consistent
		     with the delay in the sounds for each shot"). ]]
		every = 0.06,
		speed = 13.5,
		lifetime = 70 / 13.5,
		telegraph = 0.5,
		tell = "Flash",
		locksAim = false,
		range = 70,
	},
}

--[[ A Boarlet: one of the piglets a Bramble Sow drops as it dies. The
     Sow's own model at about half its size; quick and frail. ]]
local boarlet: EnemyConfig = {
	displayName = "Boarlet",
	turnRate = 600,
	health = 150,
	moveSpeed = 7.5,
	attackRange = 3.4,
	attackDamage = 40,
	attackCooldown = 1,
	knockback = 3.5,
	--[[ The Sow's box ×0.55. ]]
	hitboxSize = Vector3.new(2.15, 2.25, 3),
	color = Color3.fromRGB(150, 98, 60),
	xpReward = 5,
	shot = nil,
}

--[[ The Bramble Sow: Thornwood's Brood Slime. Big and slow, and when it
     dies three Boarlets tumble out of its brambles: its brambles burst as
     it falls (DropBoarlets) and each Boarlet somersaults out curled up
     (Tumble), both its own clips (owner, 2026-10-25: the slime split did
     not fit her). ]]
local brambleSow: EnemyConfig = {
	displayName = "BrambleSow",
	turnRate = 220,
	health = 650,
	moveSpeed = 4.2,
	attackRange = 5,
	attackDamage = 60,
	attackCooldown = 1.3,
	knockback = 1.5,
	--[[ Its model ×3.6: 3.9 across, 4.1 tall, 5.4 long. ]]
	hitboxSize = Vector3.new(3.9, 4.1, 5.4),
	color = Color3.fromRGB(150, 98, 60),
	xpReward = 22,
	shot = nil,
	split = {
		into = boarlet,
		count = 3,
		health = 1,
		clip = "DropBoarlets",
		pieceClip = "Tumble",
	},
}

--[[ The Bramble Lurker: Thornwood's burrower. It dives, travels under the
     floor, comes up beside the player on a marked spot (`Emerge`) and
     sprays thorns. ]]
local brambleLurker: EnemyConfig = {
	displayName = "BrambleLurker",
	--[[ Bigger than the Wilf, so no quicker to turn. ]]
	turnRate = 240,
	health = 280,
	moveSpeed = 5.7,
	attackRange = 10.1,
	attackDamage = 56,
	attackCooldown = 2.4,
	knockback = 3,
	--[[ Its model ×1.6, its dirt mound and all: 4.5 across, 3.3 tall. ]]
	hitboxSize = Vector3.new(4.5, 3.3, 4.5),
	color = Color3.fromRGB(110, 140, 60),
	xpReward = 20,
	shot = {
		count = 5,
		spread = math.rad(24),
		speed = 18,
		lifetime = 13.2 / 18,
		telegraph = 0.3,
		tell = "Flash",
		locksAim = false,
	},
	burrow = {
		duration = 2.2,
		surfaceTell = 0.75,
		surfaceDistance = 3.5,
		speedScale = 2.2,
		cooldown = 3.5,
	},
}

--[[
	A Thornling: one of the spiderlings the Broodmother drops round her
	(`EnemyBoss.summon`; the owner's Claude Design "Thornling 3D model",
	2026-10-25). Small, quick and frail, a Boarlet's health: it scuttles in
	and bites. Its model ×2.4: 2.4 across, 1.8 tall, 1.85 deep.
]]
local thornling: EnemyConfig = {
	displayName = "Thornling",
	turnRate = 600,
	health = 130,
	moveSpeed = 8.1,
	attackRange = 3.2,
	attackDamage = 34,
	attackCooldown = 1,
	knockback = 3.5,
	hitboxSize = Vector3.new(2.4, 1.8, 1.85),
	color = Color3.fromRGB(110, 70, 160),
	xpReward = 4,
	shot = nil,
}

--[[
	The Broodmother, Thornwood's boss (docs/BOSSES.md §2, the owner's
	Claude Design "Thornweaver", 2026-10-25). Alone in Level 2's last
	room. Her fight loops two moves, drawn with her own clips: Web Walker
	(owner, 2026-10-25, in place of the Slime King's climb and drop: a web
	nearly as wide as the room spins round her and the player walks the
	edge with it, `spin`, `WebSpin_*`) and the Slime King's lash as a web
	(a strand shot down a lane that drags whoever it catches to her:
	`ShootWeb`). After every second move a Thornling clutch (`Summon`).
	`bounce` is kept for the type and is not in her loop.
]]
local broodmother: EnemyConfig = {
	displayName = "Broodmother",
	turnRate = 90,
	health = 6600,
	moveSpeed = 0,
	attackRange = 0,
	attackDamage = 0,
	attackCooldown = 0,
	knockback = 0,
	--[[ Her model ×3.4, legs spread: 10.3 across, 6.2 tall and deep. ]]
	hitboxSize = Vector3.new(10.3, 6.2, 6.2),
	color = Color3.fromRGB(70, 60, 90),
	xpReward = 110,
	boss = {
		title = "The Broodmother",
		bounce = {
			bounces = 3,
			windup = 0.9,
			launch = 0.2,
			air = 1.4,
			recover = 0.55,
			winded = 1.4,
			height = 16,
			maxRange = 22,
			radius = 7,
			damage = 60,
			shove = 7,
			shockRadius = 12,
		},
		lash = {
			arms = { "Web" },
			wind = 0.8,
			track = 0.4,
			strike = 0.2,
			hold = 0.35,
			retract = 0.45,
			reach = 18,
			minReach = 6,
			width = 3.5,
			damage = 45,
			shove = 4,
			pull = 0.38,
			bump = 0.22,
			bumpDamage = 34,
			bumpShove = 9,
			recover = 0.6,
			stopDistance = 6,
			--[[ Her web has no chain to stretch; these only matter to a body
			     that draws one. ]]
			chainRoot = 3,
			chainReach = 18,
		},
		restAfterBounce = 1.5,
		--[[ Rests long enough to see her chase (owner, 2026-10-25: "she
		     should run at the player as well not just sit in the middle"),
		     and her fight opens with the lash, the spin after it. ]]
		restAfterLash = 2.5,
		restAfterSpin = 2.5,
		loop = { "Lash", "Spin" },
		--[[ About half the player's 13.5: she closes in, they can still
		     out-walk her; she stops short of them by her own reach. ]]
		chase = { speed = 7, stopDistance = 7, clip = "Move" },
		--[[ She spins mid-room, where the web covers all but a 4-stud track
		     either side of a room 35 wide; its arms reach the far corners
		     (the room is 58 long). The arms cross the track at about 8
		     studs a second, well under the player's 13.5, so walking with
		     them is the answer and stopping is not. ]]
		spin = {
			travelSpeed = 12,
			travelMin = 0.4,
			windup = 1.6,
			spin = 6,
			broken = 1.6,
			recover = 0.8,
			spokes = 8,
			radius = 13.5,
			reach = 34,
			width = 2.4,
			period = 12,
			damage = 45,
			hitEvery = 0.8,
			shove = 6,
			holdSpan = 2,
			height = 7,
		},
		opening = 2.5,
		web = true,
		--[[ Her clutch (owner, 2026-10-25): after every second move, three
		     Thornlings drop round her as she plays Summon. ]]
		summon = { into = thornling, count = 3, every = 2, clip = "Summon", windup = 1.1 },
		clips = {
			idle = "Idle",
			Bounce = {
				windup = "Attack wind-up",
				launch = "ClimbUp",
				air = "ClimbUp",
				recover = "DropSlam",
				winded = "Idle",
			},
			Lash = {
				Web = {
					track = "Attack wind-up",
					aimed = "Attack wind-up",
					strike = "ShootWeb",
					slap = "ShootWeb",
					retract = "Idle",
					pull = "Move",
					lean = "Attack wind-up",
					release = "Idle",
					settle = "Idle",
				},
			},
			Spin = {
				travel = "Move",
				windup = "WebSpin_Windup",
				spin = "WebSpin_Hold",
				broken = "WebSpin_End",
				recover = "WebSpin_Recover",
			},
		},
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
	--[[ Which area of the world the stage is in (`docs/WORLD.md`), as
	     `EndScreenAssets.chests` keys it: the chest Victory shows. Nil is
	     the Mossy Glade. ]]
	area: string?,
	--[[ The tutorial (`Config/Tutorial`): fixed upgrade hands, the tutorial's
	     class, no Legendary or Mythic, no boss pay, and on to the lobby when
	     it is won. ]]
	tutorial: boolean?,
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
--[[
	The tutorial's five rooms (owner, 2026-10-25: "a 5 room level. it should
	only have the lowest moss enemy and the spitter"), after `rooms` as 81-85
	so the room generators, which rewrite their own runs of `rooms`, never
	touch them. Mossy Glade layouts from the run's first rooms. Sized so the
	level-ups land in rooms 1, 2 and 3 (`Config/Tutorial`): 30, 34 and 44 XP
	against level costs of 28, 35 and 44.
]]
local tutorialRooms: { RoomConfig } = {
	{
		-- three Moss Slimes: learn to move and to stand still to shoot
		name = "Tutorial 1",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(8.75, -11.49), size = Vector3.new(9, 2.8, 3.5) },
			{ offset = Vector2.new(-8.75, -11.49), size = Vector3.new(9, 2.8, 3.5) },
		},
		enemyCount = 3,
		roster = { meleeCharger },
	},
	{
		-- the Sprout Spitter's debut, beside two slimes
		name = "Tutorial 2",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(0, 3.84), size = Vector3.new(11, 2.8, 3.5) },
			{ offset = Vector2.new(8.13, -12.58), size = Vector3.new(3.75, 1.5, 3.75) },
			{ offset = Vector2.new(-8.13, -12.58), size = Vector3.new(3.75, 1.5, 3.75) },
		},
		enemyCount = 3,
		roster = { meleeCharger, meleeCharger, spreadShooter },
	},
	{
		-- the Legendary room: Multishot comes on its level-up
		name = "Tutorial 3",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(9.06, -14.16), size = Vector3.new(3.3, 1.5, 3.3) },
			{ offset = Vector2.new(-9.06, -14.16), size = Vector3.new(3.3, 1.5, 3.3) },
		},
		enemyCount = 4,
		roster = { meleeCharger, meleeCharger, meleeCharger, spreadShooter },
	},
	{
		name = "Tutorial 4",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(-10, 0.21), size = Vector3.new(3.4, 0.4, 3.4) },
			{ offset = Vector2.new(0, 0.21), size = Vector3.new(3.4, 0.4, 3.4) },
			{ offset = Vector2.new(10, 0.21), size = Vector3.new(6.8, 0.4, 3.4) },
		},
		enemyCount = 4,
		roster = { meleeCharger, spreadShooter },
	},
	{
		name = "Tutorial 5",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(5.54, 10.57), size = Vector3.new(7, 2.8, 3.5) },
			{ offset = Vector2.new(-5.54, 10.57), size = Vector3.new(7, 2.8, 3.5) },
			{ offset = Vector2.new(5.13, -3.51), size = Vector3.new(3.2, 3.2, 3.2) },
			{ offset = Vector2.new(-5.13, -3.51), size = Vector3.new(3.2, 3.2, 3.2) },
		},
		enemyCount = 5,
		roster = { meleeCharger, meleeCharger, spreadShooter },
	},
}

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
		--[[ Adds the lancer: a drawn line to step out of, in the room with
		     lanes. The Ember Wilf stands in for the Lancer everywhere for now
		     (owner, 2026-10-23); its charge is a drawn line too. ]]
		enemyCount = 4,
		roster = { meleeCharger, spreadShooter, wilf },
	},
	{
		name = "Quarters",
		obstacles = {
			{ offset = Vector2.new(0, -12.9), size = Vector3.new(15.5, 10, 3.9) },
			{ offset = Vector2.new(0, 12.9), size = Vector3.new(15.5, 10, 3.9) },
		},
		--[[ No new archetype. Four of them at once instead, and a brood. ]]
		enemyCount = 5,
		roster = { meleeCharger, spreadShooter, wilf, broodSlime },
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
		roster = { meleeCharger, spreadShooter, wilf, burrower, tank },
	},
	{
		name = "Last Cover",
		obstacles = {
			{ offset = Vector2.new(0, 0), size = Vector3.new(5.5, 10, 9.1) },
		},
		--[[ All five. ]]
		enemyCount = 6,
		roster = { meleeCharger, wilf, spreadShooter, burrower, tank },
	},
	{
		name = "Nowhere To Stand",
		-- Ends where it began, open, but with the most enemies. If the loop
		-- works, this is the room the player wants a rematch with.
		obstacles = {},
		--[[ All five, at the most this run ever throws at once. ]]
		enemyCount = 7,
		roster = { meleeCharger, spreadShooter, wilf, burrower, tank },
	},

	--[[
		Level 1 (owner, 2026-10-22): ten rooms, all Mossy Glade, in the
		owner's order — logs, hollow, boulders, thorns, then a boss arena, and
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
		name = "Mossy Hollow",
		arena = "GladeHollow",
		obstacles = {
			{ offset = Vector2.new(-4.05, -4.32), size = Vector3.new(14, 0.4, 10) },
			{ offset = Vector2.new(9.18, -16.2), size = Vector3.new(3.3, 1.4, 3.3) },
			{ offset = Vector2.new(8.1, 14.31), size = Vector3.new(3.6, 1.6, 3.6) },
		},
		--[[ More Moss Slimes, round the hollow. Level 1 is slimes only
		     (owner, 2026-10-23: "take out any enemies that are not slime
		     enemies"). ]]
		enemyCount = 3,
		roster = { meleeCharger },
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
		roster = { meleeCharger, meleeCharger, broodSlime },
	},
	{
		name = "Mossy Thorns",
		arena = "GladeThorns",
		obstacles = {
			{ offset = Vector2.new(-7.16, -11.6), size = Vector3.new(7.8, 0.4, 7) },
			{ offset = Vector2.new(7.83, 6.48), size = Vector3.new(9.4, 0.4, 7) },
			{ offset = Vector2.new(-8.64, 15.93), size = Vector3.new(3.3, 1.4, 3.3) },
		},
		enemyCount = 4,
		roster = { meleeCharger, broodSlime },
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
		--[[ The boss arena, halfway: two Brood Slimes and their escort, a
		     taste of the room the level ends in. The Slime King waits for
		     the second visit. ]]
		enemyCount = 4,
		roster = { broodSlime, meleeCharger },
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
		--[[ The Splitter Spitter's debut, from room 6, so the first five stay
		     the slime tutorial: the one new thing to learn here. It took the
		     Ember Wilf's place (owner, 2026-10-24: "take out the non blocky
		     wilf enemy"), and fires across the whole room from anywhere in
		     it (`spreadShooter.shot`). ]]
		roster = { meleeCharger, meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Hollow II",
		arena = "GladeHollow",
		obstacles = {
			{ offset = Vector2.new(-4.05, -4.32), size = Vector3.new(14, 0.4, 10) },
			{ offset = Vector2.new(9.18, -16.2), size = Vector3.new(3.3, 1.4, 3.3) },
			{ offset = Vector2.new(8.1, 14.31), size = Vector3.new(3.6, 1.6, 3.6) },
		},
		enemyCount = 4,
		roster = { meleeCharger, broodSlime, spreadShooter },
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
		roster = { meleeCharger, meleeCharger, broodSlime, spreadShooter },
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
		roster = { meleeCharger, broodSlime, spreadShooter },
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
		--[[ The Slime King, by himself (owner, 2026-10-23: "this is going
		     to be room 10 and the boss will be by itself"). ]]
		enemyCount = 1,
		roster = { slimeKing },
	},

	--[[
		Level 2 (2026-10-25): forty Thornwood rooms, generated by
		`tools/thornwood_rooms.py` after Archero 2's (owner: "create me 40
		rooms of this area with randomly placed objects but make sure there
		is a clear path to the exit every time"): mostly open floor, a few
		pieces of cover, a body's width round each. Rooms 10, 20 and 30 are
		the boss arena with an elite fight; 40 is the Broodmother. Edit the
		script, not these rows.
	]]
	{
		name = "Thornwood 1",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(6.55, -2.92), size = Vector3.new(2.6, 1.6, 2.6) },
			{ offset = Vector2.new(-6.55, -2.92), size = Vector3.new(2.6, 1.6, 2.6) },
		},
		enemyCount = 2,
		roster = { brambleBoar },
	},
	{
		name = "Thornwood 2",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(4.44, -10.71), size = Vector3.new(3.4, 1.6, 3.4) },
			{ offset = Vector2.new(-5.45, -7.63), size = Vector3.new(3.4, 0.4, 3.4) },
		},
		enemyCount = 3,
		roster = { brambleBoar },
	},
	{
		name = "Thornwood 3",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(0, -3.2), size = Vector3.new(9, 2.6, 3) },
			{ offset = Vector2.new(10.46, -16.82), size = Vector3.new(3.4, 1.6, 3.4) },
			{ offset = Vector2.new(-10.46, -16.82), size = Vector3.new(3.4, 1.6, 3.4) },
		},
		enemyCount = 3,
		roster = { brambleBoar },
	},
	{
		name = "Thornwood 4",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(5.91, 1.63), size = Vector3.new(3.4, 1.6, 3.4) },
			{ offset = Vector2.new(-5.91, 1.63), size = Vector3.new(3.4, 1.6, 3.4) },
		},
		enemyCount = 3,
		roster = { brambleBoar, burrThistle },
	},
	{
		name = "Thornwood 5",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(0, -1.83), size = Vector3.new(10.5, 2.6, 3) },
			{ offset = Vector2.new(10.93, -18.54), size = Vector3.new(3, 1.6, 3) },
			{ offset = Vector2.new(-10.93, -18.54), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 3,
		roster = { brambleBoar, burrThistle },
	},
	{
		name = "Thornwood 6",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(9.62, -9.89), size = Vector3.new(3, 2.6, 9) },
			{ offset = Vector2.new(-9.62, -9.89), size = Vector3.new(3, 2.6, 9) },
		},
		enemyCount = 3,
		roster = { brambleBoar, burrThistle },
	},
	{
		name = "Thornwood 7",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(11.5, -6), size = Vector3.new(3, 2.6, 6) },
			{ offset = Vector2.new(-11.5, -6), size = Vector3.new(3, 2.6, 6) },
			{ offset = Vector2.new(11.5, -16), size = Vector3.new(3, 2.6, 6) },
			{ offset = Vector2.new(-11.5, -16), size = Vector3.new(3, 2.6, 6) },
		},
		enemyCount = 4,
		roster = { brambleBoar, burrThistle, brambleSow },
	},
	{
		name = "Thornwood 8",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(8.41, -6.53), size = Vector3.new(10.5, 2.6, 3) },
			{ offset = Vector2.new(-8.41, -6.53), size = Vector3.new(10.5, 2.6, 3) },
			{ offset = Vector2.new(0, 2.47), size = Vector3.new(3.4, 0.4, 3.4) },
		},
		enemyCount = 4,
		roster = { brambleBoar, burrThistle, brambleSow },
	},
	{
		name = "Thornwood 9",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(5.87, 5.23), size = Vector3.new(3.4, 0.4, 3.4) },
			{ offset = Vector2.new(-5.87, 5.23), size = Vector3.new(3.4, 0.4, 3.4) },
		},
		enemyCount = 4,
		roster = { brambleBoar, burrThistle, brambleSow },
	},
	{
		name = "Brood Clearing 1",
		arena = "ThornBoss",
		obstacles = {
			{ offset = Vector2.new(-11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(-11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
		},
		enemyCount = 5,
		roster = { brambleSow, brambleBoar, burrThistle },
	},
	{
		name = "Thornwood 11",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(0, -5.7), size = Vector3.new(7.5, 2.6, 3) },
			{ offset = Vector2.new(9.33, -15.99), size = Vector3.new(3, 1.6, 3) },
			{ offset = Vector2.new(-9.33, -15.99), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 4,
		roster = { brambleBoar, brambleLurker },
	},
	{
		name = "Thornwood 12",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(0, 3.99), size = Vector3.new(9, 2.6, 3) },
			{ offset = Vector2.new(9.68, -16.62), size = Vector3.new(3, 1.6, 3) },
			{ offset = Vector2.new(-9.68, -16.62), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 4,
		roster = { brambleBoar, brambleLurker },
	},
	{
		name = "Thornwood 13",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(-10, -3.68), size = Vector3.new(6.8, 0.4, 3.4) },
			{ offset = Vector2.new(0, -3.68), size = Vector3.new(3.4, 0.4, 3.4) },
			{ offset = Vector2.new(10, -3.68), size = Vector3.new(3.4, 0.4, 6.8) },
		},
		enemyCount = 4,
		roster = { brambleBoar, brambleLurker },
	},
	{
		name = "Thornwood 14",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(8.35, -5.14), size = Vector3.new(3.4, 1.6, 3.4) },
			{ offset = Vector2.new(-8.35, -5.14), size = Vector3.new(3.4, 1.6, 3.4) },
		},
		enemyCount = 4,
		roster = { brambleSow, brambleLurker, brambleBoar },
	},
	{
		name = "Thornwood 15",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(0, -2.49), size = Vector3.new(10.5, 2.6, 3) },
			{ offset = Vector2.new(8.7, -13.78), size = Vector3.new(3, 1.6, 3) },
			{ offset = Vector2.new(-8.7, -13.78), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 4,
		roster = { burrThistle, brambleLurker, brambleBoar, brambleSow },
	},
	{
		name = "Thornwood 16",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(0, 0.61), size = Vector3.new(9, 2.6, 3) },
			{ offset = Vector2.new(8.9, -14.05), size = Vector3.new(3, 1.6, 3) },
			{ offset = Vector2.new(-8.9, -14.05), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 4,
		roster = { brambleBoar, burrThistle, brambleLurker },
	},
	{
		name = "Thornwood 17",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(11.5, -16), size = Vector3.new(3, 2.6, 10.5) },
			{ offset = Vector2.new(-11.5, -16), size = Vector3.new(3, 2.6, 10.5) },
			{ offset = Vector2.new(11.5, 4), size = Vector3.new(3, 2.6, 9) },
			{ offset = Vector2.new(-11.5, 4), size = Vector3.new(3, 2.6, 9) },
		},
		enemyCount = 4,
		roster = { brambleBoar, brambleSow, burrThistle },
	},
	{
		name = "Thornwood 18",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(9.56, 5.74), size = Vector3.new(7.5, 2.6, 3) },
			{ offset = Vector2.new(-9.56, 5.74), size = Vector3.new(7.5, 2.6, 3) },
		},
		enemyCount = 4,
		roster = { brambleSow, brambleLurker, brambleBoar },
	},
	{
		name = "Thornwood 19",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(7.6, 12.23), size = Vector3.new(6.8, 0.4, 3.4) },
			{ offset = Vector2.new(-7.6, 12.23), size = Vector3.new(6.8, 0.4, 3.4) },
		},
		enemyCount = 4,
		roster = { burrThistle, brambleLurker, brambleBoar, brambleSow },
	},
	{
		name = "Brood Clearing 2",
		arena = "ThornBoss",
		obstacles = {
			{ offset = Vector2.new(-11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(-11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
		},
		enemyCount = 6,
		roster = { brambleSow, brambleBoar, burrThistle, brambleLurker },
	},
	{
		name = "Thornwood 21",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(9.74, -8.05), size = Vector3.new(3, 2.6, 9) },
			{ offset = Vector2.new(-9.74, -8.05), size = Vector3.new(3, 2.6, 9) },
			{ offset = Vector2.new(0, 0.95), size = Vector3.new(6.8, 0.4, 3.4) },
		},
		enemyCount = 5,
		roster = { brambleBoar, brambleSow, burrThistle },
	},
	{
		name = "Thornwood 22",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(8.53, 10.16), size = Vector3.new(3.4, 0.4, 3.4) },
			{ offset = Vector2.new(-8.53, 10.16), size = Vector3.new(3.4, 0.4, 3.4) },
			{ offset = Vector2.new(7.98, -0.3), size = Vector3.new(3.4, 1.6, 3.4) },
			{ offset = Vector2.new(-7.98, -0.3), size = Vector3.new(3.4, 1.6, 3.4) },
		},
		enemyCount = 5,
		roster = { brambleSow, brambleLurker, brambleBoar },
	},
	{
		name = "Thornwood 23",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(0, 1.36), size = Vector3.new(6, 2.6, 3) },
			{ offset = Vector2.new(7.56, -13.21), size = Vector3.new(2.6, 1.6, 2.6) },
			{ offset = Vector2.new(-7.56, -13.21), size = Vector3.new(2.6, 1.6, 2.6) },
		},
		enemyCount = 5,
		roster = { burrThistle, brambleLurker, brambleBoar, brambleSow },
	},
	{
		name = "Thornwood 24",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(9.94, 8.88), size = Vector3.new(2.6, 1.6, 2.6) },
			{ offset = Vector2.new(-9.94, 8.88), size = Vector3.new(2.6, 1.6, 2.6) },
		},
		enemyCount = 5,
		roster = { brambleBoar, burrThistle, brambleLurker },
	},
	{
		name = "Thornwood 25",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(0, -2.32), size = Vector3.new(9, 2.6, 3) },
			{ offset = Vector2.new(7.4, -12.33), size = Vector3.new(3, 1.6, 3) },
			{ offset = Vector2.new(-7.4, -12.33), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 5,
		roster = { brambleBoar, brambleSow, burrThistle },
	},
	{
		name = "Thornwood 26",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(8.11, 0.57), size = Vector3.new(9, 2.6, 3) },
			{ offset = Vector2.new(-8.11, 0.57), size = Vector3.new(9, 2.6, 3) },
		},
		enemyCount = 6,
		roster = { brambleSow, brambleLurker, brambleBoar },
	},
	{
		name = "Thornwood 27",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(8.61, 1.45), size = Vector3.new(3, 2.6, 9) },
			{ offset = Vector2.new(-8.61, 1.45), size = Vector3.new(3, 2.6, 9) },
		},
		enemyCount = 6,
		roster = { burrThistle, brambleLurker, brambleBoar, brambleSow },
	},
	{
		name = "Thornwood 28",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(6.63, 6.07), size = Vector3.new(3.4, 1.6, 3.4) },
			{ offset = Vector2.new(-6.63, 6.07), size = Vector3.new(3.4, 1.6, 3.4) },
		},
		enemyCount = 6,
		roster = { brambleBoar, burrThistle, brambleLurker },
	},
	{
		name = "Thornwood 29",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(7.39, -3.67), size = Vector3.new(7.5, 2.6, 3) },
			{ offset = Vector2.new(-7.39, -3.67), size = Vector3.new(7.5, 2.6, 3) },
		},
		enemyCount = 6,
		roster = { brambleBoar, brambleSow, burrThistle },
	},
	{
		name = "Brood Clearing 3",
		arena = "ThornBoss",
		obstacles = {
			{ offset = Vector2.new(-11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(-11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
		},
		enemyCount = 7,
		roster = { brambleSow, brambleBoar, burrThistle, brambleLurker },
	},
	{
		name = "Thornwood 31",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(9.4, -1.55), size = Vector3.new(2.6, 1.6, 2.6) },
			{ offset = Vector2.new(-0.47, -1.89), size = Vector3.new(6, 2.6, 3) },
			{ offset = Vector2.new(-9.4, -9.94), size = Vector3.new(3.4, 0.4, 6.8) },
		},
		enemyCount = 6,
		roster = { burrThistle, brambleLurker, brambleBoar, brambleSow },
	},
	{
		name = "Thornwood 32",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(8.36, 1.88), size = Vector3.new(9, 2.6, 3) },
			{ offset = Vector2.new(-8.36, 1.88), size = Vector3.new(9, 2.6, 3) },
		},
		enemyCount = 7,
		roster = { brambleBoar, burrThistle, brambleLurker },
	},
	{
		name = "Thornwood 33",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(-7, -14.44), size = Vector3.new(2.6, 1.6, 2.6) },
			{ offset = Vector2.new(7, -14.44), size = Vector3.new(3.4, 1.6, 3.4) },
		},
		enemyCount = 7,
		roster = { brambleBoar, brambleSow, burrThistle },
	},
	{
		name = "Thornwood 34",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(-7, -15.78), size = Vector3.new(3, 1.6, 3) },
			{ offset = Vector2.new(7, -15.78), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 7,
		roster = { brambleSow, brambleLurker, brambleBoar },
	},
	{
		name = "Thornwood 35",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(6.46, -14.33), size = Vector3.new(6.8, 0.4, 3.4) },
			{ offset = Vector2.new(-6.46, -14.33), size = Vector3.new(6.8, 0.4, 3.4) },
			{ offset = Vector2.new(6.88, 7.98), size = Vector3.new(3, 1.6, 3) },
			{ offset = Vector2.new(-6.88, 7.98), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 7,
		roster = { burrThistle, brambleLurker, brambleBoar, brambleSow },
	},
	{
		name = "Thornwood 36",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(-10, -11.25), size = Vector3.new(3.4, 1.6, 3.4) },
			{ offset = Vector2.new(0, -11.25), size = Vector3.new(3.4, 1.6, 3.4) },
			{ offset = Vector2.new(10, -11.25), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 7,
		roster = { brambleBoar, burrThistle, brambleLurker },
	},
	{
		name = "Thornwood 37",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(-10, 2.28), size = Vector3.new(3.4, 0.4, 3.4) },
			{ offset = Vector2.new(0, 2.28), size = Vector3.new(6.8, 0.4, 3.4) },
			{ offset = Vector2.new(10, 2.28), size = Vector3.new(3.4, 0.4, 6.8) },
		},
		enemyCount = 7,
		roster = { brambleBoar, brambleSow, burrThistle },
	},
	{
		name = "Thornwood 38",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(0, -6.88), size = Vector3.new(10.5, 2.6, 3) },
			{ offset = Vector2.new(10.15, -15.21), size = Vector3.new(3, 1.6, 3) },
			{ offset = Vector2.new(-10.15, -15.21), size = Vector3.new(3, 1.6, 3) },
		},
		enemyCount = 7,
		roster = { brambleSow, brambleLurker, brambleBoar },
	},
	{
		name = "Thornwood 39",
		arena = "ThornHedges",
		obstacles = {
			{ offset = Vector2.new(8.14, -7.35), size = Vector3.new(9, 2.6, 3) },
			{ offset = Vector2.new(-8.14, -7.35), size = Vector3.new(9, 2.6, 3) },
			{ offset = Vector2.new(0, -16.35), size = Vector3.new(3.4, 0.4, 3.4) },
		},
		enemyCount = 7,
		roster = { burrThistle, brambleLurker, brambleBoar, brambleSow },
	},
	{
		name = "Brood Heart",
		arena = "ThornBoss",
		obstacles = {
			{ offset = Vector2.new(-11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, -16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(-11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
			{ offset = Vector2.new(11.42, 16.18), size = Vector3.new(3.9, 3.8, 4.4) },
		},
		enemyCount = 1,
		roster = { broodmother },
	},

	--[[
		The Mossy Glade run (2026-10-25): twenty Mossy Glade rooms for a run-through,
		generated by `tools/glade_rooms.py` in Archero 2's layout style
		from the glade's kit (owner: "give me 20 rooms of mossy glade
		ending in king bloblin"). Every room is random but the 20th: King
		Bloblin alone in Level 1's boss room, the Glade Heart. Edit the
		script, not these rows.
	]]
	{
		name = "Mossy Glade 1",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(8.75, -11.49), size = Vector3.new(9, 2.8, 3.5) },
			{ offset = Vector2.new(-8.75, -11.49), size = Vector3.new(9, 2.8, 3.5) },
		},
		enemyCount = 2,
		roster = { meleeCharger },
	},
	{
		name = "Mossy Glade 2",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(0, 3.84), size = Vector3.new(11, 2.8, 3.5) },
			{ offset = Vector2.new(8.13, -12.58), size = Vector3.new(3.75, 1.5, 3.75) },
			{ offset = Vector2.new(-8.13, -12.58), size = Vector3.new(3.75, 1.5, 3.75) },
		},
		enemyCount = 3,
		roster = { meleeCharger },
	},
	{
		name = "Mossy Glade 3",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(9.06, -14.16), size = Vector3.new(3.3, 1.5, 3.3) },
			{ offset = Vector2.new(-9.06, -14.16), size = Vector3.new(3.3, 1.5, 3.3) },
		},
		enemyCount = 3,
		roster = { meleeCharger },
	},
	{
		name = "Mossy Glade 4",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(5.54, 10.57), size = Vector3.new(7, 2.8, 3.5) },
			{ offset = Vector2.new(-5.54, 10.57), size = Vector3.new(7, 2.8, 3.5) },
			{ offset = Vector2.new(5.13, -3.51), size = Vector3.new(3.2, 3.2, 3.2) },
			{ offset = Vector2.new(-5.13, -3.51), size = Vector3.new(3.2, 3.2, 3.2) },
		},
		enemyCount = 3,
		roster = { meleeCharger, meleeCharger, broodSlime },
	},
	{
		name = "Mossy Glade 5",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(8.36, -0.02), size = Vector3.new(9, 2.8, 3.5) },
			{ offset = Vector2.new(-8.36, -0.02), size = Vector3.new(9, 2.8, 3.5) },
			{ offset = Vector2.new(0, 8.98), size = Vector3.new(3.4, 0.4, 5.1) },
		},
		enemyCount = 3,
		roster = { meleeCharger, meleeCharger, broodSlime },
	},
	{
		name = "Mossy Glade 6",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(-10, 0.21), size = Vector3.new(3.4, 0.4, 3.4) },
			{ offset = Vector2.new(0, 0.21), size = Vector3.new(3.4, 0.4, 3.4) },
			{ offset = Vector2.new(10, 0.21), size = Vector3.new(6.8, 0.4, 3.4) },
		},
		enemyCount = 4,
		roster = { meleeCharger, meleeCharger, broodSlime },
	},
	{
		name = "Mossy Glade 7",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(-10, -13.05), size = Vector3.new(3.2, 3.2, 3.2) },
			{ offset = Vector2.new(0, -13.05), size = Vector3.new(2.8, 3.2, 2.8) },
			{ offset = Vector2.new(10, -13.05), size = Vector3.new(2.8, 3.2, 2.8) },
		},
		enemyCount = 4,
		roster = { meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Glade 8",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(10.33, 7.49), size = Vector3.new(2.8, 3.2, 2.8) },
			{ offset = Vector2.new(-10.33, 7.49), size = Vector3.new(2.8, 3.2, 2.8) },
			{ offset = Vector2.new(7.15, -4.79), size = Vector3.new(3, 1.5, 3) },
			{ offset = Vector2.new(-7.15, -4.79), size = Vector3.new(3, 1.5, 3) },
		},
		enemyCount = 4,
		roster = { meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Glade 9",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(8.68, -11.71), size = Vector3.new(3.5, 2.8, 11) },
			{ offset = Vector2.new(-8.68, -11.71), size = Vector3.new(3.5, 2.8, 11) },
		},
		enemyCount = 4,
		roster = { meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Glade 10",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(-1.52, -12.64), size = Vector3.new(2.8, 3.2, 2.8) },
			{ offset = Vector2.new(-5.35, -5.24), size = Vector3.new(7, 2.8, 3.5) },
		},
		enemyCount = 4,
		roster = { meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Glade 11",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(10.24, 9.14), size = Vector3.new(3, 1.5, 3) },
			{ offset = Vector2.new(-10.24, 9.14), size = Vector3.new(3, 1.5, 3) },
			{ offset = Vector2.new(9.92, -3.9), size = Vector3.new(3, 1.5, 3) },
			{ offset = Vector2.new(-9.92, -3.9), size = Vector3.new(3, 1.5, 3) },
		},
		enemyCount = 4,
		roster = { broodSlime, spreadShooter, meleeCharger },
	},
	{
		name = "Mossy Glade 12",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(11.5, 4), size = Vector3.new(3.5, 2.8, 9) },
			{ offset = Vector2.new(-11.5, 4), size = Vector3.new(3.5, 2.8, 9) },
			{ offset = Vector2.new(11.5, -16), size = Vector3.new(3.5, 2.8, 7) },
			{ offset = Vector2.new(-11.5, -16), size = Vector3.new(3.5, 2.8, 7) },
		},
		enemyCount = 4,
		roster = { meleeCharger, meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Glade 13",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(8.17, -11.37), size = Vector3.new(11, 2.8, 3.5) },
			{ offset = Vector2.new(-8.17, -11.37), size = Vector3.new(11, 2.8, 3.5) },
		},
		enemyCount = 5,
		roster = { meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Glade 14",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(-7, -12.31), size = Vector3.new(3.2, 3.2, 3.2) },
			{ offset = Vector2.new(7, -12.31), size = Vector3.new(3.2, 3.2, 3.2) },
		},
		enemyCount = 5,
		roster = { broodSlime, spreadShooter, meleeCharger },
	},
	{
		name = "Mossy Glade 15",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(4.39, -14.82), size = Vector3.new(3.75, 1.5, 3.75) },
			{ offset = Vector2.new(8.69, 5.82), size = Vector3.new(3.75, 1.5, 3.75) },
			{ offset = Vector2.new(-9.01, -15.36), size = Vector3.new(3.75, 1.5, 3.75) },
		},
		enemyCount = 5,
		roster = { meleeCharger, meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Glade 16",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(0, -4.45), size = Vector3.new(11, 2.8, 3.5) },
			{ offset = Vector2.new(10.74, -16.31), size = Vector3.new(3, 1.5, 3) },
			{ offset = Vector2.new(-10.74, -16.31), size = Vector3.new(3, 1.5, 3) },
		},
		enemyCount = 6,
		roster = { meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Glade 17",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(-7, -11.16), size = Vector3.new(3.75, 1.5, 3.75) },
			{ offset = Vector2.new(7, -11.16), size = Vector3.new(3.75, 1.5, 3.75) },
		},
		enemyCount = 6,
		roster = { broodSlime, spreadShooter, meleeCharger },
	},
	{
		name = "Mossy Glade 18",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(-7, -8.3), size = Vector3.new(3.75, 1.5, 3.75) },
			{ offset = Vector2.new(7, -8.3), size = Vector3.new(3, 1.5, 3) },
		},
		enemyCount = 6,
		roster = { meleeCharger, meleeCharger, broodSlime, spreadShooter },
	},
	{
		name = "Mossy Glade 19",
		arena = "GladeLogs",
		obstacles = {
			{ offset = Vector2.new(11.5, -16), size = Vector3.new(3.5, 2.8, 7) },
			{ offset = Vector2.new(-11.5, -16), size = Vector3.new(3.5, 2.8, 7) },
			{ offset = Vector2.new(11.5, 4), size = Vector3.new(3.5, 2.8, 9) },
			{ offset = Vector2.new(-11.5, 4), size = Vector3.new(3.5, 2.8, 9) },
		},
		enemyCount = 6,
		roster = { meleeCharger, broodSlime, spreadShooter },
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
		enemyCount = 1,
		roster = { slimeKing },
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
		--[[ Walking speed multiplier once a room is cleared and its exit gate
		     is open, until the player leaves through it (owner, 2026-10-25:
		     "run faster towards door after the last enemy in the room is
		     killed"). The server says when (`ExitOpen` on Workspace, set
		     with the gate by `RoomController`); the client walks at it. ]]
		exitRush = 1.5,
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

			Six studs — three player-widths, about a sixth of the room's
			width. Scaled down with the room from the original sixteen and
			shortened to four after playtest, then lengthened by half on the
			owner's ask (2026-10-25, "dash further"): still an escape rather
			than a way across the room. The duration is the shortest that still reads as travel
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
		--[[ Share of an enemy's health under which Execute's bonus applies. ]]
		executeBelow = 0.3,
		--[[ The Warden's new cards (owner, 2026-10-25). Whirlwind's spin hits
		     everything within `radius` of the Warden. Shockwave's wave runs
		     ahead from the slam at `speed` studs a second, `width` wide,
		     hitting each enemy for `share` of the slam's blow as it arrives.
		     Battle Cry stacks once per kill, up to `maxStacks`, and the
		     stacks last `duration` seconds from the last kill. ]]
		whirlwind = { radius = 6.5 },
		shockwave = { speed = 32, width = 4, share = 0.5 },
		battleCry = { maxStacks = 5, duration = 4 },

		--[[ Meteor, the Arcanist's Mythic: every `every`th cast a meteor
		     falls on that cast's target, its circle shown for `delay`
		     seconds, hitting everything within `radius` for `damage` times
		     the caster's damage. ]]
		meteor = { every = 5, delay = 0.9, radius = 6, damage = 3.4 },
		--[[ Earthbreaker, the Warden's Mythic: a dash ends in a leap,
		     `leap` seconds from its end to the slam (the RubySword kit's
		     Earthbreaker clip's Impact marker; `ClassCards.spec` holds them
		     together), then a slam (`slamRadius`, `slamDamage` times his damage) that leaves
		     cracked ground erupting every `crackEvery` seconds for
		     `crackDuration`, for `crackDamage` times his damage. ]]
		earthbreaker = {
			leap = 0.56,
			slamRadius = 5.5,
			slamDamage = 2.1,
			crackRadius = 5,
			crackEvery = 0.5,
			crackDamage = 0.42,
			crackDuration = 3,
		},

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
			distance = 6,
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
			the footage's 190. Then halved (owner, 2026-10-24: "half both of
			them", the arrow and the mage orb), to 82.5: the orb, at the
			Arcanist's 0.6, flies 49.5.
		]]
		speed = 82.5,
		--[[ 45 studs of flight, the reach playtesting settled on: a little
		     over `Player.attackRange`, so a shot at the edge of range
		     arrives, and not so far that arrows sail on after the fight.
		     Held as a distance by `Balance.spec`, so this follows `speed`. ]]
		lifetime = 45 / 82.5,
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
		--[[ 0.6 (owner, 2026-10-25: every upgrade a little weaker, pets and
		     weapons to carry a player's power); was 0.7. ]]
		ricochetDamageScale = 0.6,
		--[[ How far ahead a Tracking Eye arrow looks for something to curve
		     towards. Under the archer's targeting range, so it bends shots
		     at the fight rather than hunting across the room. ]]
		homingRange = 20,
		--[[ Seconds between Multishot's volleys. Short enough that they read
		     as one attack; long enough that the next arrow is a second chance
		     at a target that moved. Held under the fastest fire rate by
		     `Balance.spec`. ]]
		multishotInterval = 0.12,
		--[[ Seconds before Arcane Echo casts again: longer than Multishot's
		     gap, so a slow orb's echo reads as a second cast. ]]
		echoInterval = 0.2,
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
		linkShare = 0.4,
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
		--[[ Seconds after a hit that an enemy only slides with the shove (the
		     slide's whole length): it does not walk, carry a lunge forward or
		     start an attack, then takes up where it was. Without it a Bramble Boar's charge (24 to
		     28 studs a second) cancelled the push and hits looked weightless
		     (owner, 2026-10-25: every enemy but a boss is knocked back). ]]
		stagger = 0.25,
	},

	--[[ Blaze. How long a burn lasts is the card's level; `rate` is the
	     share of the arrow's damage it burns for each second. ]]
	Burn = {
		-- 0.16 with every upgrade made a little weaker (2026-10-25); was 0.2
		rate = 0.16,
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
		--[[ The Lancer is benched while the Ember Wilf stands in for it
		     (owner, 2026-10-23: "have that replace the sniper enemy for
		     now"). Its config stays below; put it back here and in the
		     rosters to bring it back. ]]
		Tank = tank,
		Burrower = burrower,
		BroodSlime = broodSlime,
		BabySlime = babySlime,
		SlimeKing = slimeKing,
		Wilf = wilf,
		BrambleBoar = brambleBoar,
		BurrThistle = burrThistle,
		BrambleSow = brambleSow,
		Boarlet = boarlet,
		BrambleLurker = brambleLurker,
		Broodmother = broodmother,
		Thornling = thornling,
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
	--[[
		A boss's hit pushing the player (the Slime King's slam, lash and chest
		bump). The client drives its own character for `duration`, as the
		dash does, so walls stop it the way they stop walking; the server
		says only which way and how far.
	]]
	Shove = {
		duration = 0.22,
	},

	Telegraph = {
		--[[ A boss's warnings (the Slime King's handoff): red where a slam
		     or a lash will land, and a green shockwave ring when a slam hits.
		     A lane's width is the lash's own (`EnemyBoss.lash.width`), sent
		     with it. ]]
		bossColor = Color3.fromRGB(255, 70, 40),
		shockColor = Color3.fromRGB(190, 240, 120),
		shockDuration = 0.45,
		--[[ Goo flung off the Slime King's fist as it splats (the design's
		     lash): this many droplets, gone after this many seconds. ]]
		gooDroplets = 12,
		gooDuration = 0.8,
		--[[ A lash's grab: a square flash where the fist closed, this many
		     studs across, for this many seconds. ]]
		grabDuration = 0.25,
		grabSize = 2.6,
		--[[
			King Bloblin's effects, from the owner's design pages (Royal
			Bounce's royal-bounce-fx.js and King Bloblin Fight's lash):
			every one built of cubes and square tiles, nothing round. Sizes
			are studs, times seconds. Decoration is scaled by the device
			tier's `bossFxShare`; the warnings never are.
		]]
		king = {
			--[[ The landing warning: one-stud tiles filling the circle, its
			     edge tiles brighter, fading in, then pulsing faster (2 to 8
			     beats a second) as the fall nears; a white-gold flash as he
			     lands. ]]
			tile = 1,
			tileFadeIn = 0.37,
			pulseFrom = 2,
			pulseTo = 8,
			flashColor = Color3.fromRGB(255, 244, 200),
			flashTime = 0.3,
			--[[ The shockwave: cubes in a ring from the circle's edge out to
			     the shock radius, shrinking as they go, lime to gold. ]]
			shockCubes = 40,
			shockFrom = 1.6,
			shockTo = 0.3,
			shockLime = Color3.fromRGB(180, 221, 70),
			shockGold = Color3.fromRGB(255, 200, 60),
			--[[ Debris kicked up off the circle's edge on the far side from
			     the camera, and dust thrown out across the floor. ]]
			debrisCubes = 7,
			debrisSize = { 1.0, 1.6 },
			debrisRise = 2.2,
			debrisTime = 0.6,
			dustCubes = 18,
			dustSize = { 0.5, 1.0 },
			dustReach = { 6, 13 },
			dustTime = 1.1,
			moss = Color3.fromRGB(151, 201, 68),
			tan = Color3.fromRGB(196, 164, 112),
			gold = Color3.fromRGB(255, 200, 60),
			--[[ The wind-up's tell: gold cubes popping off his crown from 0.15
			     to 0.75 s in. ]]
			crownCubes = 6,
			crownCubeSize = 0.7,
			crownFrom = 0.15,
			crownTo = 0.75,
			--[[ Winded: cube stars circling over his crown, twice a loop. ]]
			stars = 4,
			starSize = 0.9,
			starRadius = 3.6,
			starLift = 2,
			starTurnsPerSecond = 2 / 1.4,
			starWhite = Color3.fromRGB(255, 252, 230),
			--[[ The lash lane: tiles this size, four across its 3.5, its
			     ends stepped in; filling row by row over the lash's tracking
			     (`laneFill`, its `track`), white as it locks, then pulsing
			     to the impact. It starts `laneStart` out, at his edge, and is
			     a solid red the player reads as "he strikes here". ]]
			laneTile = 0.875,
			laneStart = 3.3,
			laneHeight = 0.2,
			laneFill = 0.4,
			laneTracking = 0.25,
			laneColor = Color3.fromRGB(225, 25, 25),
			lanePulse = Color3.fromRGB(255, 105, 80),
			lanePulseRate = 10,
			laneLockFlash = 0.08,
			--[[ The fist's splat: a stepped cross of slime tiles 5 across,
			     and a ring of cubes thrown 3 out over the hold. ]]
			splatTile = 1,
			splatRing = 8,
			splatRingSize = 0.6,
			splatRingReach = 3,
			slime = Color3.fromRGB(151, 201, 68),
			slimeLight = Color3.fromRGB(180, 221, 70),
			gooSize = { 0.3, 0.5 },
			gooReach = 4,
			--[[ The chest bump: a square of cubes out from his belly. ]]
			bumpCubes = 24,
			bumpFrom = 2,
			bumpTo = 10,
			--[[ Colour flashes the model cannot carry: his eyes flare in the
			     wind-ups and dim when winded, his gems flash in the bounce's
			     wind-up, and the lashing arm glows as it coils. ]]
			eyeGlow = Color3.fromRGB(253, 253, 106),
			eyeDim = 0.45,
			armGlow = Color3.fromRGB(200, 245, 82),
			glowRate = 8,
		},
		--[[ The player's own area attacks (the Mythics): the Meteor's circle,
		     rock and blast, and Earthbreaker's slam and glowing cracks. Warm,
		     so they never read as an enemy's red. ]]
		meteorColor = Color3.fromRGB(255, 150, 60),
		meteorHeight = 45,
		quakeColor = Color3.fromRGB(255, 190, 90),
		crackColor = Color3.fromRGB(255, 110, 40),
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
	--[[ The eyes of an `Eyes` tell, as it winds up. ]]
	EyeTellColor = Color3.fromRGB(255, 36, 24),

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

	--[[ The rooms, then the tutorial's five (81-85). ]]
	Rooms = (function(): { RoomConfig }
		local all = table.clone(rooms)
		for _, room in tutorialRooms do
			table.insert(all, room)
		end
		return all
	end)(),

	--[[ Global light. Bright and even after the footage, nothing important
	     ever in shadow, and a soft bloom so glowing things glow (switched
	     off on the lowest device tier). Warmed to the Mossy Glade's
	     reference sheet (owner, 2026-10-24: "it doesnt look as good as the
	     pics"): a mid-afternoon sun with a golden cast, a warm ambient in
	     place of the old blue-violet one so the shade under the trees reads
	     green rather than black, softer shadows, and a tighter bloom, which
	     at the old size swelled every glowing mushroom into a cyan blob.
	     Then dimmed a step with a little more contrast, so the bright
	     lawn stops washing everything out (owner, 2026-10-24: "darker
	     lighting ... to make everything a little more readable"). ]]
	Lighting = {
		ambient = Color3.fromRGB(118, 118, 98),
		outdoorAmbient = Color3.fromRGB(140, 143, 112),
		brightness = 2.1,
		clockTime = 15.6,
		geographicLatitude = 30,
		sunTint = Color3.fromRGB(255, 225, 175),
		shadowSoftness = 0.6,
		environmentDiffuse = 0.8,
		environmentSpecular = 0.2,
		bloomIntensity = 0.6,
		bloomSize = 10,
		bloomThreshold = 1.1,
		saturation = 0.05,
		contrast = 0.12,
		gradeBrightness = -0.04,
		gradeTint = Color3.fromRGB(255, 247, 230),
		--[[ The distance haze: a sunlit yellow-green, so the screen's edges
		     read as the glade going on into warm mist, never grey space
		     (owner, 2026-10-22). ]]
		hazeDensity = 0.25,
		hazeColor = Color3.fromRGB(200, 215, 150),
		hazeDecay = Color3.fromRGB(110, 140, 70),
		hazeGlare = 0.3,
		haze = 1.2,
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
			--[[ Ten Mossy Glade rooms: logs, hollow, boulders, thorns, boss, twice. ]]
			name = "Level 1",
			mode = "Rooms",
			rooms = { 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
			--[[ The game's first level, eased after playtests (owner,
			     2026-10-22: "the difficulty is still too high"): enemies hit
			     at 0.7 and have 0.8 of their health, so the player takes
			     about six hits rather than four. ]]
			enemyDamage = 0.7,
			enemyHealth = 0.8,
			area = "MossyGlade",
		},
		{
			--[[ Twenty Thornwood rooms, a step harder than Level 1 (owner,
			     2026-10-25: "make thornwood only 20 rooms as well"): the first
			     nineteen of the forty `tools/thornwood_rooms.py` wrote (room
			     10 the elite fight in the boss arena), then the Broodmother
			     alone in the Brood Heart. The other twenty stay in `Rooms`. ]]
			name = "Level 2",
			mode = "Rooms",
			rooms = (function(): { number }
				local list = {}
				for index = 21, 39 do
					table.insert(list, index)
				end
				table.insert(list, 60)
				return list
			end)(),
			enemyDamage = 0.8,
			enemyHealth = 0.9,
			area = "Thornwood",
		},
		{
			--[[ Twenty Mossy Glade rooms ending in King Bloblin
			     (`tools/glade_rooms.py`), for a run-through of every class,
			     weapon and pet (owner, 2026-10-25). Level 1's ease. ]]
			name = "Mossy Glade Run",
			mode = "Rooms",
			rooms = (function(): { number }
				local list = {}
				for index = 61, 80 do
					table.insert(list, index)
				end
				return list
			end)(),
			enemyDamage = 0.7,
			enemyHealth = 0.8,
			area = "MossyGlade",
		},
		{
			--[[ The tutorial (`Config/Tutorial`), after the story cutscene:
			     five easy Mossy Glade rooms of Moss Slimes and Sprout
			     Spitters, no boss. ]]
			name = "Tutorial",
			mode = "Rooms",
			rooms = { 81, 82, 83, 84, 85 },
			enemyDamage = 0.5,
			enemyHealth = 0.6,
			area = "MossyGlade",
			tutorial = true,
		},
	} :: { StageConfig },

	--[[ The tutorial stage, played after the story cutscene and won into the
	     lobby (`Config/Tutorial`). ]]
	tutorialStage = 6,

	--[[ Which stage the first run plays: the Mossy Glade run. Level 2,
	     Thornwood, is 4; Level 1 is 3. ]]
	stage = 5,
	--[[ The stages played in turn (owner, 2026-10-25: "play the intro, then
	     go into mossy glade rooms 1-20 then after the victory sign, when the
	     player clicks next level, reset upgrades and go into thornwood"):
	     NEXT LEVEL on Victory starts the next one with the upgrades reset,
	     TRY AGAIN on Defeat the same one. After the last, it is played
	     again until there is an area past it. `RoomController`,
	     `Util/CurrentStage`. ]]
	campaign = { 5, 4 },

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
		--[[ No free revive (owner, 2026-10-25: "take out the automatic
		     revive"): a run is saved only by Second Wind or a pet that
		     revives. Was 1 a stage. ]]
		perStage = 0,
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
			--[[ The doors (owner, 2026-10-23: "a semblance of an actual
			     door opening"): two wooden leaves, banded in iron, hinged
			     at the pillars. They swing open towards the room, where
			     the top-down camera can see them, by `doorOpenAngle`
			     degrees over `doorOpenTime` seconds, and are shut again
			     in each new room. ]]
			doorColor = Color3.fromRGB(128, 84, 50),
			doorPlankColor = Color3.fromRGB(102, 64, 38),
			doorBandColor = Color3.fromRGB(64, 64, 72),
			doorRingColor = Color3.fromRGB(214, 178, 92),
			doorOpenAngle = 105,
			doorOpenTime = 0.9,
		},
		--[[ Seconds between a room clearing and the door opening, so a kill
		     gets its own beat instead of being swallowed by the next room. ]]
		clearPause = 0.8,
		--[[ Seconds the run-over message holds before the run restarts. ]]
		deathPause = 2.5,
		--[[ Seconds into a room before the next room is built in the
		     background (`Arena.prepare`; owner, 2026-10-26: "next rooms need
		     to preload while playing current room"): past the room's own
		     arrival (its enemies landing, the ROOM sign), so the two never
		     share a frame, and well before anyone reaches the door. ]]
		prepareDelay = 3,
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

	--[[
		The slimes hop (the owner's design_handoff_slime_movement, 2026-10-23):
		every `hop` studs travelled a slime crouches, lurches forward with a
		small hop `height` studs high, lands with a squash and jiggles back;
		standing still it breathes. Drawn on each client from the hitbox the
		server moves (`Fx/SlimeHop`), so the hitbox and every hit stay where
		they were. Keyed by enemy `displayName`; the Slime King is left out,
		his moves animate him.
	]]
	SlimeHop = {
		kinds = {
			-- The Moss Slime: about 2.3 hops a second at its speed.
			Charger = { hop = 3, height = 0.8 },
			-- Heavier, longer and lower.
			BroodSlime = { hop = 3.6, height = 0.6 },
			-- A quick skitter.
			BabySlime = { hop = 1.6, height = 0.5 },
		},
		--[[ The breath when standing: this share of height, over this many
		     seconds. ]]
		idleAmount = 0.025,
		idlePeriod = 1.6,
		--[[ Seconds a slime stands before it breathes. ]]
		idleAfter = 0.15,
		--[[ Slimes further than this from the camera are not animated. ]]
		maxDistance = 250,
		--[[ One hop, from the handoff's KEYS: at share `at` of the hop, the
		     body's height, width and depth scale; its tilt in radians
		     (+ leans forward); its lift as a share of the hop's height; and
		     how far through the hop's distance it has got (`ease`), so it
		     hangs back while crouching and catches up in the lurch. ]]
		keys = {
			{ at = 0, tall = 1, wide = 1, deep = 1, tilt = 0, lift = 0, ease = 0 },
			{ at = 0.12, tall = 0.9, wide = 1.06, deep = 1.05, tilt = -0.04, lift = 0, ease = 0 },
			{
				at = 0.3,
				tall = 0.74,
				wide = 1.16,
				deep = 1.12,
				tilt = -0.12,
				lift = 0,
				ease = 0.02,
			},
			{
				at = 0.4,
				tall = 1.22,
				wide = 0.88,
				deep = 0.92,
				tilt = 0.14,
				lift = 0.55,
				ease = 0.3,
			},
			{ at = 0.5, tall = 1.08, wide = 0.94, deep = 1.06, tilt = 0.08, lift = 1, ease = 0.62 },
			{ at = 0.62, tall = 0.78, wide = 1.15, deep = 1.12, tilt = 0, lift = 0, ease = 0.95 },
			{ at = 0.72, tall = 1.1, wide = 0.95, deep = 0.95, tilt = -0.05, lift = 0, ease = 1 },
			{ at = 0.82, tall = 0.95, wide = 1.03, deep = 1.03, tilt = 0.03, lift = 0, ease = 1 },
			{
				at = 0.91,
				tall = 1.03,
				wide = 0.985,
				deep = 0.985,
				tilt = -0.01,
				lift = 0,
				ease = 1,
			},
			{ at = 1, tall = 1, wide = 1, deep = 1, tilt = 0, lift = 0, ease = 1 },
		},
	},

	--[[
		Slime residue (owner, 2026-10-23: "each of the blocky slime enemies
		as well should have some sort of blocky slime residue come off of
		them each time they are hit"). Each hit throws a few little cubes of
		the slime's own jelly out of the face the shot struck, in an arc
		back the way it came; they tumble, land as flat splats, sit a moment
		and shrink away. A crit throws more, a kill more again and all the
		way round. Drawn on each client by `Fx/SlimeResidue` from the
		server's hit and death; the cubes touch nothing. Keyed by enemy
		`displayName`; an enemy not listed (the Ember Wilf) throws none.
		How many can be alive at once is `DeviceTiers.maxSlimeResidue`.
	]]
	SlimeResidue = {
		kinds = {
			-- The Moss Slime: lime jelly, darker moss.
			Charger = {
				light = Color3.fromRGB(170, 222, 60),
				dark = Color3.fromRGB(104, 156, 34),
				moss = Color3.fromRGB(66, 104, 22),
				size = 0.42,
				count = 5,
			},
			-- Its babies: small and bright.
			BabySlime = {
				light = Color3.fromRGB(150, 218, 74),
				dark = Color3.fromRGB(98, 178, 34),
				moss = Color3.fromRGB(64, 104, 24),
				size = 0.3,
				count = 4,
			},
			-- The Mother Slime: bigger chunks, more of them.
			BroodSlime = {
				light = Color3.fromRGB(176, 232, 56),
				dark = Color3.fromRGB(112, 164, 32),
				moss = Color3.fromRGB(64, 92, 18),
				size = 0.55,
				count = 6,
			},
			-- The Splitter Spitter: the palest lime.
			Spitter = {
				light = Color3.fromRGB(204, 242, 64),
				dark = Color3.fromRGB(152, 202, 36),
				moss = Color3.fromRGB(92, 160, 32),
				size = 0.42,
				count = 5,
			},
			-- King Bloblin throws chunks twice the size.
			SlimeKing = {
				light = Color3.fromRGB(170, 216, 70),
				dark = Color3.fromRGB(96, 168, 52),
				moss = Color3.fromRGB(44, 104, 56),
				size = 1.0,
				count = 7,
			},
		},
		--[[ Share of the cubes that are moss rather than jelly. ]]
		mossShare = 0.2,
		--[[ Each cube's size varies by up to this share either way. ]]
		sizeJitter = 0.35,
		--[[ How many more a crit and a kill throw: multipliers on `count`,
		     applied together on a critical killing blow. ]]
		critScale = 1.6,
		killScale = 2,
		--[[ Degrees across the arc a hit throws into, centred on the way
		     the shot came from. A kill throws all the way round. ]]
		arc = 110,
		--[[ Studs a second outwards and upwards as a cube leaves, picked
		     between `min` and `max` per cube. ]]
		speed = { min = 6, max = 11 },
		rise = { min = 8, max = 13 },
		--[[ Studs a second squared pulling them down: heavier than the
		     world's, so a cube lands while the hit is still news. ]]
		gravity = 70,
		--[[ Radians a second a cube tumbles at, at most. ]]
		spin = 14,
		--[[ The splat it lands as: this much wider and this share as tall,
		     resting on the floor `floorLift` studs above y = 0. ]]
		splatWide = 1.4,
		splatFlat = 0.3,
		floorLift = 0.03,
		--[[ Seconds a splat rests before it starts shrinking, and how long
		     the shrink takes. ]]
		rest = 0.6,
		shrink = 0.9,
	},

	--[[
		The life in the scenery past the walls, by `ArenaModels.ambience`
		(the owner's design_handoff_forest_ambience, 2026-10-23), drawn on
		each client by `Fx/ForestAmbience` and never inside the room.
		Counts are at the High tier; lower tiers draw `DeviceTiers.
		ambienceShare` of them. The glades' trees are one merged mesh, so the
		handoff's per-tree sway is left out until they are split into trees.
	]]
	Ambience = {
		Forest = {
			--[[ Where it lives: strips of forest floor this far past the
			     walls (studs), as far out as the screen shows, and this far
			     past the room's ends. ]]
			gap = 3,
			reach = 46,
			ends = 16,
			--[[ The camera looks straight down onto the canopy, which hides
			     the forest floor, so the life lives on top of the trees:
			     leaves drift down from `leafFrom` studs up and settle on the
			     canopy (`canopy`, its top's height) before fading; fireflies
			     and butterflies hover over it, and the mist hangs in it. ]]
			leafFrom = { 17, 21 },
			--[[ `canopy` and `hover` are for an arena whose trees the client
			     cannot find: with crowns (parts named CanopyMesh*), leaves
			     settle on the crown under them, and the hanging life floats
			     `clearance` studs over the tallest crown, so none of it
			     passes through a tree (owner, 2026-10-24). ]]
			canopy = { 13, 15.5 },
			hover = 16,
			clearance = 1.5,
			--[[ Toned down so the room reads first (owner, 2026-10-26: "make
			     outer arenas a little less distracting"): fewer leaves,
			     fireflies, butterflies and birds than the handoff's, birds
			     crossing less often and the shafts fainter. ]]
			leavesPerSecond = 2,
			leafPool = 60,
			leafFall = { 0.5, 0.9 },
			--[[ Seconds a fallen leaf lies before it fades, and how long the
			     fade takes. ]]
			leafRest = 2.5,
			leafFade = 1.5,
			leafColors = {
				Color3.fromRGB(111, 154, 54),
				Color3.fromRGB(134, 168, 60),
				Color3.fromRGB(201, 165, 58),
				Color3.fromRGB(208, 122, 44),
			},
			--[[ The wind: a band of gusts sweeping across, radians of phase a
			     second, pushing leaves along. ]]
			gustSpeed = 0.6,
			--[[ Fireflies a second per 60 square studs of floor, and mist
			     puffs per 400. ]]
			fireflyDensity = 1,
			--[[ Fireflies a second per strip, at most: the strips are big
			     enough that the density alone always reached it. ]]
			fireflyMax = 4,
			mistDensity = 1,
			fireflyColor = Color3.fromRGB(235, 255, 150),
			mistColor = Color3.fromRGB(238, 243, 230),
			butterflies = 3,
			butterflyColors = {
				Color3.fromRGB(242, 209, 74),
				Color3.fromRGB(245, 241, 230),
				Color3.fromRGB(232, 138, 58),
			},
			--[[ A flock crosses every `birdGap` seconds, `birdHeight` studs up:
			     over the canopy and under the top-down camera. ]]
			birds = 5,
			birdGap = { 20, 35 },
			birdHeight = 22,
			birdSpeed = 18,
			birdColor = Color3.fromRGB(45, 51, 40),
			--[[ Shafts of light slanting down between the trees, breathing. ]]
			lightShafts = 2,
			shaftColor = Color3.fromRGB(255, 244, 200),
			shaftTransparency = 0.92,
		},
		--[[ Thornwood's wood (assets/concepts/blocky/arenas/
		     area02_thornwood_ambience*.jpg): the same life as the glade's
		     in the sheet's colours, with crows for birds (the owner liked
		     them), magenta pollen for fireflies and no butterflies. ]]
		Thornwood = {
			gap = 3,
			reach = 46,
			ends = 16,
			leafFrom = { 17, 21 },
			-- Its crowns' tops, 12.3 to 15.1 studs.
			canopy = { 12, 15.5 },
			hover = 16,
			clearance = 1.5,
			leavesPerSecond = 2,
			leafPool = 60,
			leafFall = { 0.5, 0.9 },
			leafRest = 2.5,
			leafFade = 1.5,
			leafColors = {
				Color3.fromRGB(152, 213, 25),
				Color3.fromRGB(94, 154, 52),
				Color3.fromRGB(217, 120, 47),
			},
			gustSpeed = 0.6,
			fireflyDensity = 1,
			fireflyMax = 4,
			mistDensity = 1,
			fireflyColor = Color3.fromRGB(255, 120, 230),
			mistColor = Color3.fromRGB(238, 243, 230),
			butterflies = 0,
			butterflyColors = { Color3.fromRGB(245, 241, 230) },
			birds = 5,
			birdGap = { 18, 30 },
			birdHeight = 22,
			birdSpeed = 18,
			birdColor = Color3.fromRGB(30, 30, 33),
			lightShafts = 1,
			shaftColor = Color3.fromRGB(255, 244, 200),
			shaftTransparency = 0.92,
		},
	},

	--[[ How the Mythics' area attacks look (`Fx/MythicFx`), from the owner's
	     mythic-fx.js (design_handoff_ruby_greatsword_r15 and
	     design_handoff_arcane_staff_r15, 2026-10-23). Counts are at the High
	     tier; lower tiers draw a share (`DeviceTiers.mythicFxShare`). ]]
	MythicFx = {
		--[[ The falling meteor: a hot halo round the rock, and embers shed
		     a second behind it. ]]
		meteorHalo = 1.5,
		meteorEmbers = 40,
		--[[ Its landing: a fireball out to the strike's radius over
		     `fireballTime`; a scorch `scorchShare` of the radius across, held
		     `scorchHold` seconds then fading over `scorchFade`; and
		     `debris` rocks thrown out. ]]
		fireballTime = 0.35,
		scorchShare = 0.8,
		scorchHold = 1.2,
		scorchFade = 1,
		debris = 14,
		debrisLife = 1.6,
		--[[ Each Earthbreaker eruption: `spikes` rock spikes out of the
		     cracks, each rising, holding and sinking over `spikeLife`, over
		     a lava glow. ]]
		spikes = 5,
		spikeLife = 0.65,
		spikeHeight = { 1.2, 2.4 },
		rockColor = Color3.fromRGB(122, 90, 68),
		lavaColor = Color3.fromRGB(255, 138, 42),
		fireColor = Color3.fromRGB(255, 179, 71),
		scorchColor = Color3.fromRGB(42, 26, 20),
	},

	Feedback = {
		hitFlashDuration = 0.08,
		--[[ A hit washes a non-boss enemy solid white for `hitFlashDuration`,
		     then fades it over `hitFlashFade` (owner, 2026-10-25: "very
		     briefly flash white on hit"). The Highlight's fill transparency
		     at the hit: 0 is solid white, over the vertex-coloured meshes
		     the old recolour could not whiten. ]]
		hitFill = 0,
		hitFlashFade = 0.1,
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
		--[[ A boss is hit far faster than a flash lasts, so a full white-out
		     on every hit left King Bloblin washed white the whole fight
		     (owner, 2026-10-24: "the king is all white"). A boss keeps its
		     colours and gets only this faint white wash over the body, as
		     the Highlight's starting fill transparency (1 is none). ]]
		bossHitFill = 0.85,
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
		--[[ Studs the focus may follow the player either side of the room's
		     middle when the view is longer than the room (an upright
		     phone), rather than sitting still. ]]
		longViewFollow = 14,
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
	--[[ The upgrade cards' effects (`Fx/Upgrades`, docs/effects/). Phones
	     first (owner, 2026-10-24): each is a few merged parts, pooled, and
	     capped here per effect; all one-shots together are capped by
	     `DeviceTiers.maxUpgradeFx`. ]]
	UpgradeFx = {
		-- most copies of one effect alive at once, unless `caps` says
		defaultCap = 4,
		-- most parts an effect may be (tests/UpgradeFx.spec): each copy's
		-- parts are posed every frame
		maxParts = 40,
		caps = {
			FxSoulChain = 6,
			FxBlaze = 6,
			FxDeadlyStrike = 3,
			FxBloodletting = 3,
			FxCleave = 3,
			FxChainLightning = 6,
			-- the Broodmother's web: a strand is up to ten segments
			FxBroodWebStrand = 12,
		},
		-- the stepped pop of an effect with no clip: each step's length, and
		-- how long it takes to shrink away at the end
		popStep = 0.05,
		popOut = 0.15,
		-- studs above the floor a flat effect lies, clear of the grass
		floorLift = 0.08,
		-- seconds between checks of held cards and burning enemies
		poll = 0.2,
		-- Deadly Strike: the skull, this far above the hit, for its 0.45 s clip
		critLift = 1.5,
		critLife = 0.5,
		-- Blaze: the tuft's height up the burning body (0 feet, 1 head)
		blazeHeight = 0.9,
		-- Agility: the after-image's 0.4 s Dodge
		dodgeLife = 0.45,
		-- the chest's height above the root, and over the head, for effects
		-- that fly into or pop above the player
		chest = 0.6,
		overHead = 3.6,
		-- Bloodthirst: the drop leaves the corpse after the death pop, in a
		-- short arc this high
		dropDelay = 0.12,
		dropLift = 1,
		dropArc = 1.5,
		dropLife = 0.85,
		-- Second Wind: the winged heart rises this high over this long
		windLife = 1.65,
		windRise = 0.6,
		windHeight = 2.5,
		-- Vitality's heart and Heal's flask, over the head
		heartLife = 1.25,
		flaskLife = 1.05,
		-- what plays at the bow (Overdraw's release, Twin Cast, Arcane Echo)
		-- sits this far ahead of the player
		bowAhead = 1.4,
		flareLife = 0.32,
		-- Overdraw's sound: once, after standing still this long, and not again
		-- until the player moves (owner, 2026-10-24)
		overdrawSoundAfter = 2,
		pierceLife = 0.3,
		bounceLife = 0.35,
		-- Blast Arrows' starburst is this wide in its own studs; it is drawn
		-- at the blast's real radius
		blastRadius = 2.5,
		blastLife = 0.45,
		-- Soul Chain: the chain's own length, its lift off the floor, its life
		chainLength = 10,
		chainLift = 1.1,
		chainLife = 0.35,
		slamLife = 0.6,
		cleaveLife = 0.4,
		-- Bloodletting: its full length in studs, where its heart sits
		-- along it, and its life
		drainLength = 8,
		drainHeart = 3.6,
		drainLife = 0.5,
		-- Earthbreaker's debris, drawn at the slam's real radius
		earthbreakerRadius = 5.5,
		earthbreakerLife = 0.8,
		-- Whirlwind's ring of cubes, one whirl; and each Shockwave cube's burst.
		whirlwindLife = 0.35,
		shockwaveRise = 0.35,
		-- Arcanist: Twin Cast's and Arcane Echo's beats at the staff
		twinLife = 0.6,
		echoLife = 0.9,
		-- Chain Lightning's bolt: segments, width, how far each kink pushes
		-- off the line, how often it re-kinks, its colours and life
		boltSegments = 6,
		boltWidth = 0.42,
		boltKink = 0.9,
		boltCrackle = 0.05,
		boltCore = Color3.fromRGB(235, 250, 255),
		boltRim = Color3.fromRGB(60, 190, 255),
		boltLife = 0.28,
		nodeLift = 1.4,
		-- the chain's target is the enemy most nearly along its aim (the
		-- cosine it must beat), a little past the reach for one that moved
		boltAimed = 0.8,
		boltReachSlack = 3,
		-- Meteor: the rock rides the fall at most this long
		meteorLife = 2,
	},
}

return table.freeze(Balance)
