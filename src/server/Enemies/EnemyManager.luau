--!strict
--[[
	Enemies.

	Phase 1 ships one archetype, the melee charger, but the shape here is the
	one all five will use: a config-driven record plus a behaviour step. Phase 2
	splits the step into behaviour modules; nothing else should need to change.

	Enemies are anchored Models moved by CFrame rather than Humanoids. A
	Humanoid each costs far more than this game can afford once rooms hold
	twenty of them, and it hands movement to the physics solver when what we
	want is readable, deterministic charging.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossBanners = require(ReplicatedStorage.Shared.Config.BossBanners)
local BossBody = require(script.Parent.BossBody)
local BossMoves = require(script.Parent.BossMoves)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local EnemyModel = require(script.Parent.EnemyModel)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Pathing = require(script.Parent.Pathing)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local Types = require(ReplicatedStorage.Shared.Types)

local log = Log.forTag("Enemies")

type EnemyConfig = Balance.EnemyConfig

--[[
	A volley an enemy has decided to fire. Queued rather than fired here
	because spawning a projectile needs ProjectileSystem, and ProjectileSystem
	needs this module to resolve damage — requiring each other would be a
	cycle. EnemyFiring drains these, exactly as FiringSystem sits beside
	RunSession rather than inside it.
]]
export type Volley = {
	origin: Vector3,
	direction: Vector3,
	damage: number,
	shot: Balance.EnemyShot,
}

--[[ A boss's own state (`EnemyConfig.boss`): the move it is playing, or
     when it may start the next, which one that is, its posed body, and
     whom it is holding. ]]
type BossState = {
	move: BossMoves.Move?,
	restUntil: number,
	next: number,
	body: BossBody.Body,
	holding: Player?,
	airborne: boolean,
	--[[ The clip its body is playing, for a body that plays its own
	     (`EnemyBoss.clips`), and the time it began on `os.clock()`. ]]
	clip: string?,
	clipAt: number,
}

type Enemy = {
	model: Model,
	hitbox: BasePart,
	--[[ Everything drawn for this enemy. Separate from `hitbox` on purpose:
	     the hitbox is what the server sweeps and the skin is what the player
	     sees, and only the first of those is allowed to matter to combat. ]]
	skin: EnemyModel.Skin,
	config: EnemyConfig,
	--[[ Radians about Y that the body currently faces, or nil before its first
	     step. Turned towards the target at the archetype's `turnRate` rather
	     than snapped, so a big enemy comes round slowly. ]]
	yaw: number?,
	--[[ `os.clock()` at which this enemy finishes arriving, or nil once it
	     has. Until then it is marked on the floor, cannot be seen, hit or
	     targeted, and does nothing — Archero 2 shows where a wave will appear
	     before it does. ]]
	arrivesAt: number?,
	--[[ Waypoints round the cover to its target (`Pathing`), and when they
	     were found; nil while it can walk straight at it. ]]
	route: { Vector3 }?,
	routeAt: number,
	--[[ The room the current route was planned with. ]]
	routeClearance: number?,
	health: number,
	maxHealth: number,
	position: Vector3,
	--[[ Studs a second this enemy is being shoved, by hits. Decays to rest
	     over `Balance.Knockback.slideTime`, so a hit reads as a push rather
	     than the one-frame jump it used to be. ]]
	knockbackVelocity: Vector3,
	lastAttackAt: number,
	--[[ `os.clock()` at which a telegraphed volley actually leaves, or nil
	     when this enemy is not winding one up. ]]
	volleyAt: number?,
	--[[ The direction a locked shot committed to when its wind-up began. Nil
	     for shots that re-aim as they fire. ]]
	volleyDirection: Vector3?,
	--[[ `os.clock()` at which a burrowed enemy comes up, or nil while it is
	     above ground. ]]
	surfacesAt: number?,
	--[[ Whether the ground marker for the current dive has gone out. One per
	     dive, not one per frame. ]]
	surfaceTold: boolean,
	--[[ `os.clock()` it last came up, which the burrow cooldown counts from. ]]
	lastSurfacedAt: number,
	--[[ Mirrors `surfacesAt ~= nil`, kept as its own field so the movement
	     code can skip republishing a position for something that is not
	     currently a target. ]]
	submerged: boolean,
	--[[
		Which way round an obstacle this enemy committed to, or nil when it has
		a clear path. Held rather than recomputed: see the steering block in
		`stepEnemy` for why re-deciding every frame deadlocks.
	]]
	slideSign: number?,
	boss: BossState?,
	--[[ The lunge under way (`EnemyConfig.lunges`), by index, or nil. It
	     winds up until `lungeGoesAt`, then travels `lungeDirection`, locked
	     when the wind-up began, until it has covered its distance or cover
	     stops it. `lungeHit` holds the players it has already struck, once
	     each per lunge. ]]
	lungeIndex: number?,
	lungeGoesAt: number,
	lungeDirection: Vector3,
	lungeTravelled: number,
	lungeMoving: boolean,
	lungeHit: { [Player]: boolean },
}

local EnemyManager = {}

--[[
	Half the room an enemy's hitbox covers along X and along Z, at its current
	turn. The hitbox turns with the enemy, and a square turned 45° is 1.41
	times as wide across as it is square-on; resolving it as if it never
	turned is what let its corners into pillars. Exact against the arena's
	axis-aligned faces; at a pillar's corner it is a little generous, which
	errs on the side of a gap rather than an overlap.
]]
local function footprint(config: Balance.EnemyConfig, yaw: number?): Vector2
	local half = config.hitboxSize / 2
	local angle = yaw or 0
	local c = math.abs(math.cos(angle))
	local s = math.abs(math.sin(angle))

	return Vector2.new(half.X * c + half.Z * s, half.X * s + half.Z * c)
end

local enemies: { [Model]: Enemy } = {}
--[[
	Mirror of enemy positions for Targeting, kept in step with `enemies` so the
	firing system never has to touch a BasePart property per shot.
]]
local positions: { [Model]: Vector3 } = {}

local folder: Folder? = nil
local aliveCount = 0

local enemyHit = Remotes.event(Remotes.EnemyHit)
local enemyDied = Remotes.event(Remotes.EnemyDied)
local enemyTelegraph = Remotes.event(Remotes.EnemyTelegraph)
local playerShoved = Remotes.event(Remotes.PlayerShoved)
local playerGrabbed = Remotes.event(Remotes.PlayerGrabbed)

--[[ Studs enemies try to keep between each other, so a wave reads as a group
     rather than one overlapping blob. ]]
--[[ How many time constants fit in `Balance.Knockback.slideTime`: three, so
     a shove is 95% spent by the end of it. ]]
local KNOCKBACK_SETTLE = 3

--[[ Set on an enemy's model while it winds up a shot, for the client's "!"
     warning — Archero 2's tell above an enemy about to attack. Presentation
     only; the wind-up itself is decided here as before. ]]
local WINDING_UP = "WindingUp"

local SEPARATION_DISTANCE = 3.5
local SEPARATION_STRENGTH = 6

--[[ Studs ahead of itself an enemy checks for a pillar before committing to a
     step. A charger has no pathfinding, so without this it walks into an
     obstacle face and Arena.resolve pins it there for ever. ]]
local OBSTACLE_PROBE = 1.25

--[[ Pathing: studs of room left round a body when planning its route, so
     it does not graze every corner; seconds between fresh routes as the
     target moves; and how near a waypoint counts as reached. ]]
local PATH_CLEARANCE = 0.3
local REPATH_INTERVAL = 0.4
local WAYPOINT_REACHED = 0.75

--[[ Fraction of its attackRange a ranged enemy backs away below, so it keeps a
     shooting lane instead of being walked over and turned into a melee enemy
     with a worse attack. ]]
local HOLD_FRACTION = 0.6

--[[ Studs between candidate spawn points when scanning the floor. Fine enough
     that a valid gap is never missed, coarse enough that the whole scan is a
     few hundred box tests. ]]
local SPAWN_GRID_STEP = 2

--[[ The stage's multipliers on enemy damage and health (`StageConfig`). ]]
local function difficulty(): { damage: number, health: number }
	local stage = Balance.Stages[Balance.stage]
	return {
		damage = stage and stage.enemyDamage or 1,
		health = stage and stage.enemyHealth or 1,
	}
end

--[[ Volleys decided this step, drained by EnemyFiring. ]]
local pendingVolleys: { Volley } = {}

--[[ Until when (os.clock) the run holds still for a boss's entry banner. ]]
local introUntil = 0

function EnemyManager.init(parent: Instance)
	local existing = parent:FindFirstChild("Enemies")
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = "Enemies"
	created.Parent = parent
	folder = created

	table.clear(enemies)
	table.clear(positions)
	aliveCount = 0
	introUntil = 0
end

--[[
	Whether the run is holding still for a boss's entry: its banner and the
	music's battle intro (`Config/BossBanners`, owner 2026-10-24: "make sure
	that the player and boss are frozen and not attacking until the intro
	banner is fully stopped"). The server loop skips its step meanwhile, as
	it does for a card screen; the client stops its own input from the same
	banner (`UI/BossBanner`, `RunPaused`).
]]
function EnemyManager.introHolding(now: number): boolean
	return now < introUntil
end

function EnemyManager.positions(): { [Model]: Vector3 }
	return positions
end

function EnemyManager.aliveCount(): number
	return aliveCount
end

--[[ How much of its health a live enemy has left, 0 to 1, or nil for
     anything that is not one. For damage that cares (Execute). ]]
function EnemyManager.healthFraction(model: Model): number?
	local enemy = enemies[model]
	if not enemy or enemy.maxHealth <= 0 then
		return nil
	end
	return enemy.health / enemy.maxHealth
end

function EnemyManager.folder(): Folder?
	return folder
end

--[[
	Everything a spawn has to keep its distance from.

	Live players, and — when there are none yet — the place players arrive at.
	That fallback is not a nicety: a room is built and populated before anyone
	has a character, so measuring only against live roots meant the first wave
	of every run measured against nothing and could spawn on top of the player.
]]
local function spawnKeepAwayPoints(): { Vector3 }
	local points: { Vector3 } = {}

	for _, session in RunSession.all() do
		local root = session.root
		if root and session.alive then
			table.insert(points, root.Position)
		end
	end

	if #points == 0 then
		table.insert(points, Balance.Arena.spawnPosition)
	end

	return points
end

--[[ Flat distance from `candidate` to the nearest thing it must avoid. ]]
local function distanceToNearest(candidate: Vector3, points: { Vector3 }): number
	local nearest = math.huge

	for _, point in points do
		local flat = Vector3.new(candidate.X - point.X, 0, candidate.Z - point.Z)
		nearest = math.min(nearest, flat.Magnitude)
	end

	return nearest
end

--[[ A spawn point inside the arena, clear of geometry and away from players. ]]
--[[
	Whether a body of `radius` standing at `candidate` would overlap any enemy
	already in the room.

	The spawn scan kept new enemies away from *players* and nothing else, so
	two members of one wave could be picked from neighbouring cells and arrive
	standing inside each other. In the original ninety-stud room that was rare
	enough to go unnoticed; at Archero's proportions the floor is a third the
	width and it happened constantly — 102 overlapping pair-frames in one
	playtest, with the separation pass spending its first few frames of every
	wave prising bodies apart.
]]
local SPAWN_BODY_GAP = 0.75

local function clearOfEnemies(candidate: Vector3, radius: number): boolean
	for _, enemy in enemies do
		local other = math.max(enemy.config.hitboxSize.X, enemy.config.hitboxSize.Z) / 2
		local flat = Vector3.new(candidate.X - enemy.position.X, 0, candidate.Z - enemy.position.Z)
		if flat.Magnitude < radius + other + SPAWN_BODY_GAP then
			return false
		end
	end

	return true
end

local function findSpawnPosition(config: EnemyConfig): Vector3
	local arena = Balance.Arena
	local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2
	local limitX = arena.size.X / 2 - radius - 2
	local limitZ = arena.size.Z / 2 - radius - 2
	local y = config.hitboxSize.Y / 2

	local keepAway = spawnKeepAwayPoints()
	local minimum = Balance.Spawning.minSpawnDistance

	--[[
		Every cell of a coarse grid over the floor, rather than a run of random
		guesses.

		Random sampling cannot promise anything. Two versions of it failed
		here: uniform sampling checked the distance last, so in a room with
		heavy cover the attempts ran out and the fallback handed back something
		near the player; sampling on a ring instead put most candidates outside
		the arena, where clamping them back inside destroyed the very distance
		they were placed to have. A 56-stud exclusion was still producing
		25-stud spawns.

		A scan is exhaustive, so if any valid cell exists it is found, and the
		cost is bounded and paid once per enemy at room entry rather than
		scaling with how awkward the room is.
	]]
	local viable: { Vector3 } = {}
	local bestPosition: Vector3? = nil
	local bestDistance = -1

	local x = -limitX
	while x <= limitX do
		local z = -limitZ
		while z <= limitZ do
			local candidate = Vector3.new(x, y, z)

			if Arena.isClear(candidate, radius) and clearOfEnemies(candidate, radius) then
				local distance = distanceToNearest(candidate, keepAway)

				if distance >= minimum then
					table.insert(viable, candidate)
				elseif distance > bestDistance then
					bestPosition = candidate
					bestDistance = distance
				end
			end

			z += SPAWN_GRID_STEP
		end

		x += SPAWN_GRID_STEP
	end

	if #viable > 0 then
		local chosen = viable[math.random(#viable)]

		--[[ Nudged off the lattice so a wave does not visibly line up, by less
		     than half a cell so it cannot cross into a neighbour that was
		     rejected. ]]
		local jitter = SPAWN_GRID_STEP / 2 - 0.5
		local nudged = Vector3.new(
			chosen.X + (math.random() * 2 - 1) * jitter,
			y,
			chosen.Z + (math.random() * 2 - 1) * jitter
		)

		if
			Arena.isClear(nudged, radius)
			and clearOfEnemies(nudged, radius)
			and distanceToNearest(nudged, keepAway) >= minimum
		then
			return nudged
		end

		return chosen
	end

	--[[ No cell anywhere satisfies the minimum — too many players spread
	     across a small room. Take the furthest clear spot rather than refusing
	     to spawn, and accept that this wave starts closer than it should. ]]
	return bestPosition or Vector3.new(limitX, y, limitZ)
end

--[[
	Takes an enemy out of play while its spawn marker is up, or puts it in.

	The same four things `setSubmerged` keeps in agreement — query, skin,
	targeting attribute and `positions` — for the same reason: an enemy the
	player can see but not hit, or hit but not see, reads as a bug. Kept as
	its own flag rather than reusing `submerged`, because an arriving Lurker
	must not trip the burrow logic into thinking it is mid-dive.
]]
local function setArriving(enemy: Enemy, arriving: boolean)
	enemy.hitbox.CanQuery = not arriving
	EnemyModel.setHidden(enemy.skin, arriving)
	enemy.model:SetAttribute("Targetable", not arriving)

	if arriving then
		positions[enemy.model] = nil
	else
		positions[enemy.model] = enemy.position
	end
end

--[[
	Where the members of a triangle stand, given its tip.

	The tip is the member nearest the player; the others stand in a row
	behind it, away from the player, so a cluster reads as a group arriving
	together and pointing at you. Spacing is from the widest member, so no
	two bodies in a cluster can touch.

	Returns spots for every member after the first. `turn` swings the row
	round the tip, in radians, for when the floor behind it is blocked — a
	tip found far from the player is often against the far wall.
]]
function EnemyManager.triangle(
	tip: Vector3,
	toward: Vector3,
	widest: number,
	count: number,
	turn: number?
): { Vector3 }
	local flat = Vector3.new(tip.X - toward.X, 0, tip.Z - toward.Z)
	local back = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis * -1
	back = CFrame.Angles(0, turn or 0, 0):VectorToWorldSpace(back)
	local across = Vector3.new(-back.Z, 0, back.X)

	local spacing = widest * 2 + Balance.Spawning.clusterGap
	--[[ An even row has no member straight behind the tip, so it can sit at
	     the height that makes equilateral triangles; an odd one has, and
	     must sit a full spacing back. ]]
	local rowIsOdd = (count - 1) % 2 == 1
	local height = if rowIsOdd then spacing else spacing * math.sqrt(3) / 2

	local spots: { Vector3 } = {}
	local rowCount = count - 1
	for index = 1, rowCount do
		local side = (index - 1) - (rowCount - 1) / 2
		table.insert(spots, tip + back * height + across * side * spacing)
	end
	return spots
end

--[[ `spot`, if an enemy of `config` may stand there: inside the walls, off
     the obstacles, clear of every other enemy, and not on top of a player. ]]
local function clusterSpot(config: EnemyConfig, spot: Vector3): Vector3?
	local arena = Balance.Arena
	local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2
	local limitX = arena.size.X / 2 - radius - 2
	local limitZ = arena.size.Z / 2 - radius - 2
	local position = Vector3.new(spot.X, config.hitboxSize.Y / 2, spot.Z)

	if math.abs(position.X) > limitX or math.abs(position.Z) > limitZ then
		return nil
	end

	if not Arena.isClear(position, radius) or not clearOfEnemies(position, radius) then
		return nil
	end

	if distanceToNearest(position, spawnKeepAwayPoints()) < Balance.Spawning.minSpawnDistance then
		return nil
	end

	return position
end

--[[ The player nearest `point`, or the room's start when nobody is in it. ]]
local function nearestKeepAway(point: Vector3): Vector3
	local best = Balance.Arena.spawnPosition
	local bestDistance = math.huge
	for _, candidate in spawnKeepAwayPoints() do
		local distance = (Vector3.new(candidate.X, 0, candidate.Z) - Vector3.new(
			point.X,
			0,
			point.Z
		)).Magnitude
		if distance < bestDistance then
			best = candidate
			bestDistance = distance
		end
	end
	return best
end

--[[ The turns a cluster's row tries, in order: straight behind the tip
     first, then swung further and further round it. ]]
local CLUSTER_TURNS = { 0, math.rad(60), math.rad(-60), math.rad(120), math.rad(-120), math.pi }

--[[
	The spots for a cluster's members after its tip: the first turn of the
	row where every one of them fits, or failing that the turn that fits the
	most. A member whose spot does not fit gets nil, and an ordinary spawn
	search.
]]
local function arrange(members: { EnemyConfig }, tip: Vector3, widest: number): { Vector3? }
	local toward = nearestKeepAway(tip)
	local best: { Vector3? } = {}
	local bestFits = -1

	for _, turn in CLUSTER_TURNS do
		local spots: { Vector3? } = {}
		local fits = 0
		for index, spot in EnemyManager.triangle(tip, toward, widest, #members, turn) do
			local placed = clusterSpot(members[index + 1], spot)
			spots[index] = placed
			if placed then
				fits += 1
			end
		end

		if fits == #members - 1 then
			return spots
		elseif fits > bestFits then
			best = spots
			bestFits = fits
		end
	end

	return best
end

--[[ `at` places the enemy there instead of searching; the caller has
     already checked the spot (see `clusterSpot`). ]]
--[[ `splitFrom` is where the enemy this one split out of fell: it arrives
     when its piece lands (`Balance.Split`) instead of after a spawn marker. ]]
function EnemyManager.spawn(
	config: EnemyConfig,
	extraDelay: number?,
	at: Vector3?,
	splitFrom: Vector3?
): Model?
	local parent = folder
	if not parent then
		log.warn("spawn before init")
		return nil
	end

	local position = at or findSpawnPosition(config)
	local model, hitbox, skin = EnemyModel.build(config, position)

	enemies[model] = {
		model = model,
		hitbox = hitbox,
		skin = skin,
		config = config,
		health = config.health * difficulty().health,
		maxHealth = config.health * difficulty().health,
		position = position,
		knockbackVelocity = Vector3.zero,
		lastAttackAt = 0,
		volleyAt = nil,
		volleyDirection = nil,
		surfacesAt = nil,
		surfaceTold = false,
		lastSurfacedAt = 0,
		submerged = false,
		lungeIndex = nil,
		lungeGoesAt = 0,
		lungeDirection = Vector3.zAxis,
		lungeTravelled = 0,
		lungeMoving = false,
		lungeHit = {},
		slideSign = nil,
		arrivesAt = nil,
		route = nil,
		routeAt = 0,
		routeClearance = nil,
	}
	positions[model] = position
	aliveCount += 1

	if config.boss then
		local parts: { BasePart } = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		--[[ A body that plays its own clips (King Bloblin's rig) is drawn by
		     each client (`Fx/ModelAnimator`), timed from here; only its
		     shadow is placed on the server. ]]
		local imported = (EnemyDesigns.Imported :: any)[config.displayName] :: EnemyDesigns.ImportedDesign?
		local clipped = config.boss.clips ~= nil and imported ~= nil
		if clipped and imported then
			model:SetAttribute("ModelClips", imported.clips)
			local stretch = imported.stretch
			if stretch then
				model:SetAttribute("ModelClipStretchJoint", stretch.joint)
				model:SetAttribute("ModelClipStretchKeep", table.concat(stretch.keep, ","))
			end
			CollectionService:AddTag(model, "ModelClips")
		end
		enemies[model].boss = {
			move = nil,
			restUntil = 0,
			next = 1,
			body = BossBody.new(model, hitbox, parts, clipped),
			holding = nil,
			airborne = false,
			clip = if clipped then "" else nil,
			clipAt = 0,
		}
		--[[ For the client: the boss bar, and no hit squash on a body the
		     server is posing. ]]
		model:SetAttribute("Boss", config.boss.title)
		if BossBanners.bosses[config.boss.title] then
			introUntil = os.clock() + BossBanners.hold
		end
	end

	--[[ Health travels as attributes so each client can draw the enemy's
	     bar. Read for drawing only; the server's own number is the truth. ]]
	model:SetAttribute("MaxHealth", config.health * difficulty().health)
	model:SetAttribute("Health", config.health * difficulty().health)

	model.Parent = parent

	--[[
		Marked on the floor before it exists, the way Archero 2 does it.

		Counted as alive from this moment, so a room cannot read as cleared
		during the warning. The marker carries the body's own radius, so a
		Bulwark's warning is visibly bigger than a Charger's — which is the
		first thing worth knowing about what is about to arrive.
	]]
	local enemy = enemies[model]
	local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2

	if splitFrom then
		--[[ No marker: the piece flying out is the warning. The direction
		     carries the whole throw, landing minus origin, so the client can
		     draw the arc from where it fell. ]]
		local tell = Balance.Split.flight + Balance.Split.settle
		enemy.arrivesAt = os.clock() + tell
		setArriving(enemy, true)
		enemyTelegraph:FireAllClients(position, position - splitFrom, tell, "Split", radius)
		return model
	end

	local tell = Balance.Spawning.arrivalTell + (extraDelay or 0)
	enemy.arrivesAt = os.clock() + tell
	setArriving(enemy, true)

	enemyTelegraph:FireAllClients(position, Vector3.zAxis, tell, "Spawn", radius)

	return model
end

--[[
	Phase 1 shipped one archetype; this mixes two so both counterplays — keep
	your distance, and find the gap — are exercised in the same room. A fixed
	ratio is a placeholder: room-authored rosters replace it when the room
	system lands, which is where a biome's identity will actually live.
]]
--[[
	Fills a wave from the room's own roster, cycled in order.

	Cycled rather than randomised so a room is the same fight every run, which
	is what makes it teachable and what makes a playtest comparable. The roster
	comes from the room because the order archetypes appear in *is* the
	tutorial — one shared order for every room put three different mechanics in
	the opening fight.
]]
function EnemyManager.spawnWave(count: number, roster: { EnemyConfig })
	if #roster == 0 then
		log.warn("room has no roster, nothing to spawn")
		return
	end

	local clusterSize = math.max(Balance.Spawning.clusterSize, 1)
	local index = 0

	--[[ In triangles, as the footage shows. Members are spawned one at a
	     time, so each later spot is checked against the bodies already
	     placed — including the rest of its own cluster. ]]
	while index < count do
		local members: { EnemyConfig } = {}
		for offset = 1, math.min(clusterSize, count - index) do
			members[offset] = roster[(index + offset - 1) % #roster + 1]
		end

		local widest = 0
		for _, config in members do
			widest = math.max(widest, math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2)
		end

		local spots: { Vector3? } = {}
		for offset, config in members do
			--[[ Staggered by a beat each, as the footage shows: markers appear
			     a few at a time rather than all on one frame, which reads as a
			     wave arriving rather than a level loading. ]]
			local delay = (index + offset - 1) * Balance.Spawning.arrivalStagger
			--[[ Checked again at its turn, against the bodies placed since. ]]
			local spot = spots[offset - 1]
			local at = if spot then clusterSpot(config, spot) else nil
			local model = EnemyManager.spawn(config, delay, at)

			if offset == 1 and model then
				spots = arrange(members, enemies[model].position, widest)
			end
		end

		index += #members
	end

	log.info("spawned wave of %d from %d archetypes", count, #roster)
end

--[[
	Where a piece of a split lands: `reach` out along `angle`, or nearer if
	that is in a wall, a pillar or another enemy. Unlike a wave's spawn it
	does not keep away from players — the pieces land where the body fell,
	and that is usually beside one. Falls back to the spot it fell on.
]]
local function splitSpot(config: EnemyConfig, origin: Vector3, angle: number): Vector3
	local arena = Balance.Arena
	local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2
	local limitX = arena.size.X / 2 - radius - 1
	local limitZ = arena.size.Z / 2 - radius - 1
	local y = config.hitboxSize.Y / 2
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))

	for _, share in { 1, 0.75, 0.5, 0.25 } do
		local spot = origin + direction * Balance.Split.reach * share
		local candidate =
			Vector3.new(math.clamp(spot.X, -limitX, limitX), y, math.clamp(spot.Z, -limitZ, limitZ))
		if Arena.isClear(candidate, radius) and clearOfEnemies(candidate, radius) then
			return candidate
		end
	end

	return Vector3.new(
		math.clamp(origin.X, -limitX, limitX),
		y,
		math.clamp(origin.Z, -limitZ, limitZ)
	)
end

--[[ Spawns what a dead enemy splits into, spread evenly round where it fell
     from a random first angle, so two splits never look the same. ]]
local function spawnSplit(split: Balance.EnemySplit, origin: Vector3)
	local first = math.random() * math.pi * 2
	for index = 1, split.count do
		local angle = first + (index - 1) / split.count * math.pi * 2
		local model =
			EnemyManager.spawn(split.into, nil, splitSpot(split.into, origin, angle), origin)
		local piece = model and enemies[model]
		if piece then
			piece.health *= split.health
			piece.maxHealth *= split.health
			piece.model:SetAttribute("MaxHealth", piece.maxHealth)
			piece.model:SetAttribute("Health", piece.health)
		end
	end
end

--[[
	Server-authoritative damage. Nothing on the client can reach this; the
	projectile system is the only caller.
]]
--[[
	Applies damage and reports whether it *landed* — not whether it killed.

	The caller needs one thing from this: did the projectile connect with a
	live enemy, and should it therefore stop. Reporting the kill instead made
	every non-fatal hit indistinguishable from a miss, which is the wrong
	question asked of the wrong function.

	The second return is the XP this hit earned, which is non-zero only on the
	blow that kills. It is returned rather than awarded here because this
	module has no idea whose arrow it was, and guessing is exactly how XP ends
	up credited to the wrong player the moment there are two of them. The
	third is where the enemy fell, on the killing blow only: it is where the
	kill's crystals drop, and the model is gone by the time anyone asks.
]]
--[[ `fromPosition` is where the blow came from, for knockback; nil for
     damage that does not push, like a burn ticking. `kind` is how the
     number is drawn; omitted is a plain hit. ]]
function EnemyManager.damage(
	model: Model,
	amount: number,
	fromPosition: Vector3?,
	kind: Types.HitKind?
): (boolean, number, Vector3?)
	local enemy = enemies[model]
	if not enemy or amount <= 0 then
		return false, 0, nil
	end

	enemy.health -= amount

	--[[ The shove is a velocity that slides off over `slideTime`, not a
	     jump: an instant two-stud teleport was too quick to see, which made
	     hits read as weightless. Started at `distance · k` so the slide covers
	     exactly the archetype's `knockback` before it rests. Further hits add
	     to it, up to twice one hit's worth, so a volley pushes harder without
	     flinging anything across the room. ]]
	local knockbackDirection = if fromPosition then enemy.position - fromPosition else Vector3.zero
	if knockbackDirection.Magnitude > 1e-3 then
		local flat = Vector3.new(knockbackDirection.X, 0, knockbackDirection.Z).Unit
		local rate = KNOCKBACK_SETTLE / Balance.Knockback.slideTime
		local impulse = enemy.config.knockback * rate
		local combined = enemy.knockbackVelocity + flat * impulse

		if combined.Magnitude > impulse * 2 then
			combined = combined.Unit * impulse * 2
		end

		enemy.knockbackVelocity = combined
	end

	if enemy.health > 0 then
		model:SetAttribute("Health", enemy.health)
		--[[ Where the blow came from travels too, for the client's slime
		     residue to fly back out of the struck face. ]]
		enemyHit:FireAllClients(model, amount, enemy.position, kind or "Hit", fromPosition)
		return true, 0, nil
	end

	enemies[model] = nil
	positions[model] = nil
	aliveCount -= 1

	--[[ A boss killed mid-grab lets go at once. ]]
	local holding = enemy.boss and enemy.boss.holding
	if holding then
		playerGrabbed:FireClient(holding, 0)
	end

	--[[
		Position only, deliberately. Passing `model` here raced the `Destroy`
		on the next line: whether the client received a usable reference or nil
		depended on replication ordering within the frame. Anything the client
		needs about a dead enemy has to travel as data, because the instance it
		would describe is already gone.
	]]
	--[[ The killing blow's number travels with the death, so the hit that
	     finishes an enemy is shown like every other — it used to show
	     nothing, which made the strongest hit of a fight the invisible one. ]]
	--[[ Its archetype and where the blow came from travel as data too, for
	     the client's slime residue (`Fx/SlimeResidue`). ]]
	enemyDied:FireAllClients(
		enemy.position,
		amount,
		kind or "Hit",
		enemy.config.displayName,
		fromPosition
	)
	model:Destroy()

	--[[ Spawned before this returns, so the room never reads as clear in
	     the moment between the body dying and its pieces existing. ]]
	local split = enemy.config.split
	if split then
		spawnSplit(split, enemy.position)
	end

	return true, enemy.config.xpReward, enemy.position
end

local function nearestAlivePlayerRoot(position: Vector3): (BasePart?, number)
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge

	for _, session in RunSession.all() do
		local root = session.root
		if not root or not session.alive then
			continue
		end

		local flat = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
		local distance = flat.Magnitude

		if distance < bestDistance then
			bestRoot = root
			bestDistance = distance
		end
	end

	return bestRoot, bestDistance
end

--[[
	Queues a volley aimed where the target is *now*, at the end of the wind-up
	rather than at the start of it. The telegraph is the player's window to
	move; aiming at the old position would hand them a free dodge and make the
	tell meaningless.
]]
--[[
	Takes an enemy out of play as a target, or puts it back.

	Three things have to agree or the illusion breaks in a way players read as
	a bug rather than a mechanic: it must vanish from `positions`, which is
	what server targeting iterates; its hitbox must stop answering raycasts, or
	arrows would still stop dead in mid-air on something invisible; and the
	model carries an attribute so the client's own targeting and prediction
	agree with the server about what is shootable.
]]

local function setSubmerged(enemy: Enemy, submerged: boolean)
	enemy.submerged = submerged
	enemy.hitbox.CanQuery = not submerged
	EnemyModel.setHidden(enemy.skin, submerged)
	enemy.model:SetAttribute("Targetable", not submerged)

	if submerged then
		positions[enemy.model] = nil
	else
		positions[enemy.model] = enemy.position
	end
end

local function aimAt(from: Vector3, targetRoot: BasePart): Vector3?
	local flat = Vector3.new(targetRoot.Position.X - from.X, 0, targetRoot.Position.Z - from.Z)

	if flat.Magnitude < 1e-3 then
		return nil
	end

	return flat.Unit
end

local function queueVolley(enemy: Enemy, targetRoot: BasePart, shot: Balance.EnemyShot)
	--[[
		A locked shot fires down the direction it committed to when the wind-up
		began — the same one the player was shown. An unlocked shot re-aims
		now, so standing still through the tell is punished.
	]]
	local direction = enemy.volleyDirection or aimAt(enemy.position, targetRoot)

	if not direction then
		return
	end

	table.insert(pendingVolleys, {
		origin = enemy.position,
		direction = direction,
		damage = enemy.config.attackDamage * difficulty().damage,
		shot = shot,
	})
end

--[[
	One behaviour for both archetypes, because they differ in data rather than
	in kind: a melee charger closes to `attackRange` and swings, a ranged enemy
	treats the same number as the distance it wants to *hold* and fires a
	telegraphed volley from there. No pathfinding either way — Archero rooms
	are open, and an enemy that beelines is readable in a way one that
	navigates is not.
]]
--[[
	Puts an enemy's hitbox, and the body welded to it, where the enemy is.

	Always by CFrame, never by Position. A WeldConstraint only drags its
	other parts along when a part's CFrame is set; setting Position moves the
	hitbox alone and quietly re-welds the body at the new offset. That is how
	a knocked-back enemy's ring slid away while its body stayed put — and
	then stayed apart, leaving arrows to hit an invisible box beside the
	visible enemy.
]]
local function placeHitbox(enemy: Enemy)
	enemy.hitbox.CFrame = CFrame.new(enemy.position) * CFrame.Angles(0, enemy.yaw or 0, 0)
end

--[[
	Moves an enemy along whatever shove it is carrying and lets it decay.
	Integrated exactly for exponential decay, so the distance a hit pushes is
	the same at 30 fps as at 144.
]]
local function slide(enemy: Enemy, deltaTime: number)
	local velocity = enemy.knockbackVelocity
	if velocity.Magnitude < 1e-2 or enemy.submerged then
		enemy.knockbackVelocity = Vector3.zero
		return
	end

	local rate = KNOCKBACK_SETTLE / Balance.Knockback.slideTime
	local decay = math.exp(-rate * deltaTime)
	local moved = velocity * (1 - decay) / rate

	enemy.knockbackVelocity = velocity * decay
	enemy.position = Arena.resolveBox(enemy.position + moved, footprint(enemy.config, enemy.yaw))
	positions[enemy.model] = enemy.position
	placeHitbox(enemy)
end

--[[
	A boss in the air (a Royal Bounce) is out of reach of everything on the
	floor, and nothing should try: off the target list and out of the sweep,
	as a dive is, but still drawn.
]]
local function setAirborne(enemy: Enemy, state: BossState, airborne: boolean)
	if state.airborne == airborne then
		return
	end
	state.airborne = airborne
	enemy.hitbox.CanQuery = not airborne
	enemy.model:SetAttribute("Targetable", not airborne)
	if airborne then
		positions[enemy.model] = nil
	else
		positions[enemy.model] = enemy.position
	end
end

--[[ Tells a player's client to push its character `distance` studs along
     `direction`. The client moves it, as it does a dash. ]]
local function shove(session: RunSession.Session, direction: Vector3, distance: number)
	local along = Vector3.new(direction.X, 0, direction.Z)
	if along.Magnitude < 1e-3 or distance <= 0 then
		return
	end
	playerShoved:FireClient(session.player, along.Unit, distance)
end

--[[ Damage that reports whether it landed: a dodge (Agility) or a shield
     takes nothing, and a lash that took nothing grabs nobody. ]]
local function hurt(session: RunSession.Session, amount: number): boolean
	local before = session.health
	RunSession.applyDamage(session, amount)
	return session.health < before or not session.alive
end

--[[ Resolves what a boss's move did this step: draws its warnings, and
     hits, shoves, grabs and releases players. ]]
local function resolveBossEvent(
	state: BossState,
	boss: Balance.EnemyBoss,
	e: BossMoves.Event,
	now: number,
	clamp: (Vector3) -> Vector3
)
	local scale = difficulty().damage

	if e.kind == "SlamTell" then
		enemyTelegraph:FireAllClients(e.at, Vector3.zAxis, e.duration, "Slam", e.radius)
	elseif e.kind == "Slam" then
		--[[ The landing: its flash, debris and dust on the circle, and the
		     shockwave out from its edge (`radius`) to `shockRadius`. ]]
		enemyTelegraph:FireAllClients(
			e.at,
			Vector3.zAxis,
			Balance.Telegraph.shockDuration,
			"SlamImpact",
			boss.bounce.shockRadius,
			e.radius
		)
		for _, session in RunSession.all() do
			local root = session.root
			if not root or not session.alive then
				continue
			end
			local away = Vector3.new(root.Position.X - e.at.X, 0, root.Position.Z - e.at.Z)
			if away.Magnitude <= e.radius then
				hurt(session, boss.bounce.damage * scale)
				shove(
					session,
					if away.Magnitude > 0.1 then away else Vector3.zAxis,
					boss.bounce.shove
				)
			end
		end
	elseif e.kind == "LaneAim" or e.kind == "Lane" then
		enemyTelegraph:FireAllClients(e.at, e.direction, e.duration, e.kind, e.length, e.width)
	elseif e.kind == "Splat" then
		enemyTelegraph:FireAllClients(e.at, e.direction, boss.lash.hold, "Splat", e.radius)
	elseif e.kind == "BumpShock" then
		enemyTelegraph:FireAllClients(
			e.at,
			e.direction,
			Balance.Telegraph.shockDuration,
			"BumpShock",
			e.radius
		)
	elseif e.kind == "Shake" then
		enemyTelegraph:FireAllClients(Vector3.zero, Vector3.zAxis, e.duration, "Shake", e.radius)
	elseif e.kind == "Goo" then
		enemyTelegraph:FireAllClients(
			e.at,
			e.direction,
			Balance.Telegraph.gooDuration,
			"Goo",
			Balance.Telegraph.gooDroplets
		)
	elseif e.kind == "LaneHit" then
		local side = Vector3.new(-e.direction.Z, 0, e.direction.X)
		local held: Vector3? = nil
		for _, session in RunSession.all() do
			local root = session.root
			if not root or not session.alive then
				continue
			end
			local offset = Vector3.new(root.Position.X - e.at.X, 0, root.Position.Z - e.at.Z)
			local along = offset:Dot(e.direction)
			local across = offset:Dot(side)
			if along <= 0 or along >= e.length + 1 or math.abs(across) >= e.width / 2 + 1 then
				continue
			end
			local landed = hurt(session, boss.lash.damage * scale)
			if landed and not held and session.alive then
				--[[ The first one caught is held, long enough for the pull
				     and the bump; the bump lets go sooner. ]]
				held = root.Position
				state.holding = session.player
				playerGrabbed:FireClient(session.player, boss.lash.pull + boss.lash.bump + 0.1)
				--[[ Everyone sees the grab: a flash where the fist closed. ]]
				enemyTelegraph:FireAllClients(
					root.Position,
					e.direction,
					Balance.Telegraph.grabDuration,
					"Grab",
					Balance.Telegraph.grabSize
				)
			elseif landed then
				shove(session, side * (if across >= 0 then 1 else -1), boss.lash.shove)
			end
		end
		local move = state.move
		if held and move then
			BossMoves.grab(move, boss, now, held, clamp)
		end
	elseif e.kind == "Bump" then
		local player = state.holding
		state.holding = nil
		if player then
			playerGrabbed:FireClient(player, 0)
			local session = RunSession.get(player)
			if session and session.alive then
				hurt(session, boss.lash.bumpDamage * scale)
				shove(session, e.direction, boss.lash.bumpShove)
			end
		end
	end
end

--[[
	Tells the clients which clip a boss's body is playing (`Fx/ModelAnimator`):
	its name, the server time it began (`ModelClipAt`), and the seconds it
	is to last (`ModelClipSpan`, which fits its pace to the phases), set
	only when the clip changes. Nothing for a body the server poses.
]]
local function showClip(
	enemy: Enemy,
	state: BossState,
	clip: string,
	clipAt: number,
	now: number,
	span: number
)
	if state.clip == nil or (clip == state.clip and clipAt == state.clipAt) then
		return
	end
	state.clip = clip
	state.clipAt = clipAt
	local model = enemy.model
	model:SetAttribute("ModelClipAt", Workspace:GetServerTimeNow() - (now - clipAt))
	model:SetAttribute("ModelClipSpan", if span > 0 then span else nil)
	model:SetAttribute("ModelClip", if clip ~= "" then clip else nil)
end

--[[
	A boss's turn: rest, then the next move in `BossMoves.LOOP`, played to
	its end. It does not walk; every step it takes is part of a move.
]]
local function stepBoss(enemy: Enemy, state: BossState, now: number)
	local config = enemy.config
	local boss = config.boss :: Balance.EnemyBoss
	local half = config.hitboxSize.Y / 2
	local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2

	--[[ Inside the room and clear of cover: where a slam may land or a
	     pull may end. ]]
	local function clamp(point: Vector3): Vector3
		local resolved = Arena.resolve(Vector3.new(point.X, half, point.Z), radius)
		return Vector3.new(resolved.X, 0, resolved.Z)
	end

	if state.restUntil == 0 then
		state.restUntil = now + boss.opening
	end

	local feet = Vector3.new(enemy.position.X, 0, enemy.position.Z)
	local targetRoot = nearestAlivePlayerRoot(feet)
	local move = state.move

	if not move then
		if now < state.restUntil or not targetRoot then
			BossBody.pose(state.body, BossMoves.idle(feet, enemy.yaw or 0, now))
			local idle = if boss.clips then boss.clips.idle else ""
			showClip(enemy, state, idle, if state.clip == idle then state.clipAt else now, now, 0)
			return
		end
		move = BossMoves.start(BossMoves.LOOP[state.next], now, feet, enemy.yaw or 0)
		state.move = move
	end
	assert(move, "a boss move")

	local target = if targetRoot then targetRoot.Position else feet
	local pose, events, done = BossMoves.step(move, boss, now, target, clamp)

	enemy.position = pose.feet + Vector3.new(0, half + pose.lift, 0)
	enemy.yaw = pose.yaw
	setAirborne(enemy, state, pose.airborne)
	if not state.airborne then
		positions[enemy.model] = enemy.position
	end
	placeHitbox(enemy)
	BossBody.pose(state.body, pose)

	for _, e in events do
		resolveBossEvent(state, boss, e, now, clamp)
	end

	--[[ After the events: a grab switches the clip to the pull. ]]
	local clip, clipAt, span = BossMoves.clip(move, boss)
	showClip(enemy, state, clip, clipAt, now, span)
	if state.clip and move.kind == "Lash" and move.length > 0 then
		local stretch = BossMoves.chainScale(move.length, boss.lash)
		enemy.model:SetAttribute("ModelClipStretch", Vector3.new(1, 1, stretch))
	end

	if done then
		state.move = nil
		state.restUntil = now + BossMoves.restAfter(move.kind, boss)
		state.next = state.next % #BossMoves.LOOP + 1
	end
end

--[[ Studs a player's body reaches out from its centre, for a lunge's touch. ]]
local PLAYER_REACH = 1

--[[
	A lunging enemy's turn (`EnemyConfig.lunges`). Returns whether the lunge
	took the turn, so walking and the plain attack wait.

	Off cooldown, with the target inside one lunge's range and nothing in
	the way, it winds up where it stands: aim locked, the tell shown (a line
	as long as the lunge for `Line`, the recolour for `Flash`). Then it bolts
	down that line, striking each player it touches once, and stops at the
	end of its distance or against cover. The line it showed is the line it
	takes, so stepping off it works.
]]
local function stepLunge(
	enemy: Enemy,
	targetRoot: BasePart,
	distance: number,
	deltaTime: number,
	now: number
): boolean
	local config = enemy.config
	local lunges = config.lunges :: { Balance.EnemyLunge }
	local index = enemy.lungeIndex

	if not index then
		if now - enemy.lastAttackAt < config.attackCooldown then
			return false
		end
		local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2
		for i, lunge in lunges do
			if distance < lunge.minRange or distance >= lunge.maxRange then
				continue
			end
			if
				not Arena.isSegmentClear(
					enemy.position,
					targetRoot.Position,
					config.hitboxSize.X / 2
				)
			then
				continue
			end
			local aim = aimAt(enemy.position, targetRoot)
			if not aim then
				continue
			end
			enemy.lungeIndex = i
			enemy.lungeGoesAt = now + lunge.telegraph
			enemy.lungeDirection = aim
			enemy.lungeTravelled = 0
			enemy.lungeMoving = false
			enemy.lungeHit = {}
			enemy.lastAttackAt = now
			enemy.yaw = math.atan2(-aim.X, -aim.Z)
			placeHitbox(enemy)
			--[[ An `Eyes` tell lights only the eyes, red; the client pulses
			     them (`Fx/EnemyRig`). Any other recolours the body. ]]
			if lunge.tell == "Eyes" then
				EnemyModel.tintEyes(enemy.skin, Balance.EyeTellColor)
			else
				EnemyModel.tint(enemy.skin, Balance.TelegraphColor)
			end
			enemy.model:SetAttribute("LungeTell", lunge.tell)
			--[[ How long the wind-up and the bolt take, so a rigged body
			     can fit its dash to them (`Fx/EnemyRig`). Set before the
			     wind-up flag that starts it. ]]
			enemy.model:SetAttribute("LungeWindup", lunge.telegraph)
			enemy.model:SetAttribute("LungeTravel", lunge.distance / lunge.speed)
			enemy.model:SetAttribute(WINDING_UP, true)
			enemyTelegraph:FireAllClients(
				enemy.position,
				aim,
				lunge.telegraph,
				lunge.tell,
				lunge.distance + radius
			)
			return true
		end
		return false
	end

	local lunge = lunges[index]
	if now < enemy.lungeGoesAt then
		-- Winding up: it holds still, pointed down its line.
		return true
	end

	if not enemy.lungeMoving then
		enemy.lungeMoving = true
		EnemyModel.restore(enemy.skin, config)
		enemy.model:SetAttribute(WINDING_UP, nil)
	end

	local step = math.min(lunge.speed * deltaTime, lunge.distance - enemy.lungeTravelled)
	local wanted = enemy.position + enemy.lungeDirection * step
	local reached = Arena.resolveBox(wanted, footprint(config, enemy.yaw))
	local moved =
		Vector3.new(reached.X - enemy.position.X, 0, reached.Z - enemy.position.Z).Magnitude
	enemy.position = reached
	enemy.lungeTravelled += step
	positions[enemy.model] = enemy.position
	placeHitbox(enemy)

	--[[ Each player it touches on the way, once. The body is long, so the
	     touch is measured against its box, turned with it, not a circle. ]]
	local half = config.hitboxSize / 2
	local frame = CFrame.new(enemy.position) * CFrame.Angles(0, enemy.yaw or 0, 0)
	for _, session in RunSession.all() do
		local root = session.root
		if not root or not session.alive or enemy.lungeHit[session.player] then
			continue
		end
		local at = frame:PointToObjectSpace(root.Position)
		if math.abs(at.X) <= half.X + PLAYER_REACH and math.abs(at.Z) <= half.Z + PLAYER_REACH then
			enemy.lungeHit[session.player] = true
			RunSession.applyDamage(
				session,
				config.attackDamage * lunge.damageScale * difficulty().damage
			)
		end
	end

	if enemy.lungeTravelled >= lunge.distance - 1e-3 or moved < step * 0.3 then
		enemy.lungeIndex = nil
		enemy.lungeMoving = false
		-- The cooldown runs from the end of the lunge, not its wind-up.
		enemy.lastAttackAt = now
	end
	return true
end

local function stepEnemy(enemy: Enemy, deltaTime: number, now: number)
	local arrivesAt = enemy.arrivesAt
	if arrivesAt then
		if now < arrivesAt then
			return
		end

		enemy.arrivesAt = nil
		setArriving(enemy, false)
	end

	local boss = enemy.boss
	if boss then
		stepBoss(enemy, boss, now)
		return
	end

	slide(enemy, deltaTime)

	local targetRoot, distance = nearestAlivePlayerRoot(enemy.position)
	if not targetRoot then
		return
	end

	local config = enemy.config
	local shot = config.shot
	local burrow = config.burrow
	local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2

	if config.lunges and stepLunge(enemy, targetRoot, distance, deltaTime, now) then
		return
	end

	--[[
		Dive and surface. A burrower spends the trip untargetable, which is the
		whole threat, so the two things that bound it are the marker that warns
		where it comes up and the cooldown that stops it chaining dives.
	]]
	if burrow then
		local surfacesAt = enemy.surfacesAt

		if surfacesAt then
			if not enemy.surfaceTold and now >= surfacesAt - burrow.surfaceTell then
				enemy.surfaceTold = true

				--[[
					The marker is a promise, so the trip ends here.

					This used to send the marker and then let the enemy carry
					on travelling for the whole tell — about ten studs at
					burrow speed, against a marker six and a half across — so
					it routinely came up outside its own warning. A player who
					steps off the circle and is hit anyway learns to ignore
					the circle, which costs this archetype its entire
					counterplay.

					Resolved out of any obstacle *before* the marker is drawn
					rather than after it surfaces, or the push out of a pillar
					would move it off the spot it just promised.
				]]
				enemy.position = Arena.resolve(enemy.position, radius)

				enemyTelegraph:FireAllClients(
					enemy.position,
					Vector3.zAxis,
					burrow.surfaceTell,
					"Ground",
					0
				)
			end

			if now >= surfacesAt then
				enemy.surfacesAt = nil
				enemy.surfaceTold = false
				enemy.lastSurfacedAt = now

				--[[ A no-op in the normal case, because the position was
				     already resolved and frozen when the marker went out. Kept
				     as the backstop for a dive that somehow surfaces without
				     having told anyone: coming up inside a pillar means being
				     shot at through geometry. ]]
				enemy.position = Arena.resolve(enemy.position, radius)
				setSubmerged(enemy, false)

				--[[ Comes up already attacking. Surfacing is itself the tell,
				     and the player was warned by the marker. ]]
				enemy.lastAttackAt = now
				if shot then
					enemy.volleyAt = now + shot.telegraph
					enemy.volleyDirection = if shot.locksAim
						then aimAt(enemy.position, targetRoot)
						else nil
					EnemyModel.tint(enemy.skin, Balance.TelegraphColor)
					enemy.model:SetAttribute(WINDING_UP, true)
				end
			end
		elseif now - enemy.lastSurfacedAt >= burrow.cooldown and not enemy.volleyAt then
			--[[
				Deliberately not gated on distance. A ranged enemy holds at
				`attackRange`, so requiring "further than attackRange" to dive
				meant it dived once on spawn and then sat on that boundary for
				ever. Diving is this archetype's rhythm, not an escape from
				being too far away.
			]]
			enemy.surfacesAt = now + burrow.duration
			enemy.surfaceTold = false
			setSubmerged(enemy, true)

			--[[
				Announced, because going under used to be completely silent.

				The enemy simply stopped existing on screen, which reads as a
				despawn rather than as a threat that has gone mobile — and a
				player who thinks something despawned stops watching for it,
				which is exactly backwards for the one archetype whose whole
				pressure is arriving somewhere else.

				No wind-up, unlike every other use of this channel: the dive
				has already happened. The duration is how long the mark takes
				to clear, not a window to act in.
			]]
			enemyTelegraph:FireAllClients(
				enemy.position,
				Vector3.zAxis,
				Balance.Telegraph.diveDuration,
				"Dive",
				0
			)
		end
	end

	--[[ Whether the obstacle steering below committed to a side this step. The
	     commitment must not outlive the block that caused it. ]]
	local steering = false

	--[[
		Underground it closes to `surfaceDistance` instead of holding a firing
		lane: the whole point of the trip is to come up beside the player.
		Above ground a ranged enemy also moves when it is *too close*, backing
		off to recover that lane. A melee one never does.
	]]
	local holdAt = if enemy.submerged and burrow then burrow.surfaceDistance else config.attackRange

	local tooFar = distance > holdAt
	local tooClose = shot ~= nil
		and not enemy.submerged
		and distance < config.attackRange * HOLD_FRACTION

	--[[ Once the surface marker is out, the spot under it is committed and the
	     enemy stops travelling. This freeze is what makes stepping off the
	     circle actually work. ]]
	if (tooFar or tooClose) and not enemy.surfaceTold then
		local toTarget = Vector3.new(
			targetRoot.Position.X - enemy.position.X,
			0,
			targetRoot.Position.Z - enemy.position.Z
		)

		local heading = if toTarget.Magnitude > 1e-3 then toTarget.Unit else Vector3.zero

		--[[ Round the cover rather than into it. Walking at the target is
		     the default; when cover stands in the straight line, follow
		     the route `Pathing` finds, refreshed a few times a second as
		     the target moves and cut short whenever a later waypoint comes
		     into a clear line. Only when closing in: backing away to hold a
		     lane never needs a route. ]]
		if not tooClose and not enemy.submerged then
			--[[ Room for the body at its widest: the hitbox is a square that
			     turns to face its target, and turned diagonally it is 1.41
			     times as wide. Planned for that first, so a big body never
			     catches a corner; then a tight fit, then flush, only where
			     nothing wider gets through. ]]
			local wide = radius * math.sqrt(2) + 0.1
			local tight = radius + PATH_CLEARANCE
			local clearance = enemy.routeClearance or wide
			if Arena.isSegmentClear(enemy.position, targetRoot.Position, clearance) then
				enemy.route = nil
				enemy.routeClearance = nil
			else
				local route = enemy.route
				if not route or now - enemy.routeAt >= REPATH_INTERVAL then
					clearance = wide
					route = Pathing.find(enemy.position, targetRoot.Position, wide)
					if not route then
						clearance = tight
						route = Pathing.find(enemy.position, targetRoot.Position, tight)
					end
					if not route then
						-- A gap barely its own width: flush with the sides.
						clearance = radius
						route = Pathing.find(enemy.position, targetRoot.Position, radius)
					end
					enemy.route = route
					enemy.routeClearance = if route then clearance else nil
					enemy.routeAt = now
				end
				if route then
					while
						#route > 1
						and (
							Vector3.new(
									route[1].X - enemy.position.X,
									0,
									route[1].Z - enemy.position.Z
								).Magnitude
								< WAYPOINT_REACHED
							or Arena.isSegmentClear(enemy.position, route[2], clearance)
						)
					do
						table.remove(route, 1)
					end
					local leg =
						Vector3.new(route[1].X - enemy.position.X, 0, route[1].Z - enemy.position.Z)
					if leg.Magnitude > 1e-3 then
						heading = leg.Unit
					end
				end
			end
		end

		local desired = if tooClose then -heading else heading

		--[[
			Steer along a pillar face rather than into it. Targeting
			deliberately ignores line of sight, so a charger is routinely sent
			straight at an obstacle; without this it presses against the face,
			Arena.resolve returns it to the same spot every frame, and the room
			deadlocks with the player's arrows blocked by that same pillar.
		]]
		--[[ Not while following a route: its legs are already clear, and a
		     big body's probe reaches past the corner it is rounding, so the
		     slide fought the route and stalled it. ]]
		if desired.Magnitude > 1e-3 and not enemy.submerged and not enemy.route then
			local probe = enemy.position + desired * (radius + OBSTACLE_PROBE)
			local normal = Arena.deflectionNormal(enemy.position, probe, radius)

			if normal then
				local tangent = Vector3.new(-normal.Z, 0, normal.X)

				--[[
					Commit to one side for as long as the obstacle keeps
					blocking. Either tangent walks around the pillar, but
					re-deciding each frame makes an enemy level with its target
					jitter on the spot for ever: the side it picks depends on
					which way the target lies, and sliding across flips that,
					which flips the choice straight back.
				]]
				local side = enemy.slideSign or (if tangent:Dot(desired) < 0 then -1 else 1)

				enemy.slideSign = side
				desired = tangent * side
				steering = true
			end
		end

		local separation = Vector3.zero

		for otherModel, otherPosition in positions do
			if otherModel == enemy.model then
				continue
			end

			local away = enemy.position - otherPosition
			local gap = away.Magnitude

			if gap > 1e-3 and gap < SEPARATION_DISTANCE then
				separation += Vector3.new(away.X, 0, away.Z).Unit * (1 - gap / SEPARATION_DISTANCE)
			end
		end

		local move = desired + separation * SEPARATION_STRENGTH * deltaTime
		if move.Magnitude > 1e-3 then
			move = move.Unit
		end

		--[[ Faster underground, or diving would be a slower way to cross the
		     room than walking and no player would ever have to respect it. ]]
		local speed = config.moveSpeed
			* (if enemy.submerged and burrow then burrow.speedScale else 1)

		local nextPosition = enemy.position + move * speed * deltaTime

		--[[ Underground it passes beneath obstacles and only the outer walls
		     still apply. Steering around pillars on a dive would burn the
		     whole trip and surface it no closer than it started. ]]
		enemy.position = if enemy.submerged
			then Arena.clampToWalls(nextPosition, radius)
			else Arena.resolveBox(nextPosition, footprint(config, enemy.yaw))

		--[[ Not republished while submerged: `positions` is what targeting
		     iterates, so writing here would put an untargetable enemy straight
		     back into the list `setSubmerged` just removed it from. ]]
		if not enemy.submerged then
			positions[enemy.model] = enemy.position
		end
	end

	--[[
		Cleared whenever the steering above did not run this step — including
		when the enemy is inside attack range, which the old placement never
		reached. A commitment that outlived its obstacle sent the enemy the
		long way round the next time anything blocked it.
	]]
	if not steering then
		enemy.slideSign = nil
	end

	--[[
		Turn towards the player, at the archetype's own rate.

		This used to snap straight at the player every frame. On a Bulwark,
		whose shield is wider than its body, that meant the whole slab swung
		in step with every move the player made — 315 degrees in three seconds
		of strafing, up to 30 in a single frame — and read as the enemy
		copying them. A player standing inside its hitbox, which they can,
		flipped it round completely as they crossed its centre.

		Facing is presentation only: every shot is aimed separately, so a
		slow turn never makes an enemy easier to dodge.
	]]
	local facing = Vector3.new(
		targetRoot.Position.X - enemy.position.X,
		0,
		targetRoot.Position.Z - enemy.position.Z
	)

	if facing.Magnitude > 1e-3 then
		--[[ The yaw at which LookVector points along `facing`. ]]
		local target = math.atan2(-facing.X, -facing.Z)
		local current = enemy.yaw

		if current == nil then
			--[[ First step: face the player outright. Turning in from an
			     arbitrary spawn orientation would show a newly arrived enemy
			     spinning on the spot for no reason. ]]
			enemy.yaw = target
		else
			local delta = ((target - current + math.pi) % (2 * math.pi)) - math.pi
			local maxStep = math.rad(config.turnRate) * deltaTime
			enemy.yaw = current + math.clamp(delta, -maxStep, maxStep)
		end
	end

	--[[ Resolved again at the new turn: turning in place beside a pillar
	     swings the hitbox's corners as surely as walking into it does.
	     Underground there is nothing to hit, and the walls are the only
	     limit. ]]
	if not enemy.submerged then
		enemy.position = Arena.resolveBox(enemy.position, footprint(config, enemy.yaw))
		positions[enemy.model] = enemy.position
	end

	placeHitbox(enemy)

	--[[
		A wind-up already in flight resolves wherever the enemy now is, even if
		the player has since walked out of range. Cancelling it on range would
		let a player cancel every shot by stepping back during the tell, which
		turns the telegraph from a window into an exploit.
	]]
	--[[ Nothing underground attacks. Its entire turn is the trip and the
	     marker; the volley belongs to the moment it comes up. ]]
	if enemy.submerged then
		return
	end

	local volleyAt = enemy.volleyAt

	if volleyAt and shot then
		if now >= volleyAt then
			enemy.volleyAt = nil
			EnemyModel.restore(enemy.skin, config)
			enemy.model:SetAttribute(WINDING_UP, nil)
			queueVolley(enemy, targetRoot, shot)
			enemy.volleyDirection = nil
		end

		return
	end

	--[[ A shot may fire from further out than the enemy holds (`shot.range`). ]]
	local fireRange = if shot and shot.range then shot.range else config.attackRange
	if distance > fireRange then
		return
	end

	if now - enemy.lastAttackAt < config.attackCooldown then
		return
	end

	--[[ Cooldown starts at the wind-up, not at the shot, so the telegraph is
	     paid for out of the enemy's own rhythm rather than added to it. ]]
	enemy.lastAttackAt = now

	if shot then
		local aim = aimAt(enemy.position, targetRoot)
		if not aim then
			return
		end

		enemy.volleyAt = now + shot.telegraph
		enemy.volleyDirection = if shot.locksAim then aim else nil

		--[[ The flash stays on for both tells: it marks *which* enemy is
		     winding up, which a line alone does not, since a line drawn across
		     a busy room is hard to trace back to its owner. ]]
		EnemyModel.tint(enemy.skin, Balance.TelegraphColor)
		enemy.model:SetAttribute(WINDING_UP, true)

		enemyTelegraph:FireAllClients(
			enemy.position,
			aim,
			shot.telegraph,
			shot.tell,
			config.attackRange
		)

		return
	end

	--[[ A lunging archetype has no plain bite: its lunges are its attacks. ]]
	if config.lunges then
		return
	end

	local player = Players:GetPlayerFromCharacter(targetRoot.Parent :: Instance)
	if not player then
		return
	end

	local session = RunSession.get(player)
	if not session then
		return
	end

	RunSession.applyDamage(session, config.attackDamage * difficulty().damage)
end

--[[
	Pushes overlapping enemies apart.

	Nothing stopped two enemies occupying the same ground: collision is
	resolved analytically against the arena, and the arena is the only thing
	that was ever considered. While every archetype was an identical box this
	was merely untidy. Now that they have bodies it is visible clipping, and
	two merged silhouettes read as one target — which matters, because
	choosing what to shoot first is most of the decision in a mixed room.

	This is **not** the same thing as the separation steering above, and does
	not replace it. That is a soft force folded into an enemy's desired
	heading, so it only applies while the enemy is moving — and it uses a flat
	3.5 studs, which is less than a Bulwark's own width. Once an enemy reaches
	its hold distance it stops moving, the steering stops being applied, and
	nothing ever pushes it back out of whatever it has drifted into.

	So: that one keeps a moving group loose, this one guarantees bodies never
	intersect, including when everything is standing still, and it measures
	against real hitbox sizes rather than one constant.

	Measured before this existed: 348 frames out of 1801 had at least one
	overlapping pair.

	Deliberately a nudge rather than a hard constraint. Each pass moves the
	pair a fraction of the way out, so a crowd settles over several frames
	instead of snapping, and a Charger can still press right up against the
	player without being shoved off its line by the enemy behind it. Submerged
	enemies are skipped: they are underground, where sharing ground with
	something above it is not a collision.
]]
--[[ The whole overlap, resolved each frame: each half of a pair moves half
     of it. It used to close a quarter per side per frame, which in the
     original ninety-stud room was plenty; at Archero's proportions every
     enemy closes on the player in a room a third the width, steering pushed
     bodies back together every frame, and they spent 260 frames of one
     playtest brushing into each other. A full projection leaves them exactly
     touching instead. ]]
local OVERLAP_PUSH = 1

local function separate()
	local live: { Enemy } = {}
	for _, enemy in enemies do
		if not enemy.submerged and not enemy.arrivesAt then
			table.insert(live, enemy)
		end
	end

	for i = 1, #live do
		local a = live[i]
		local aRadius = math.max(a.config.hitboxSize.X, a.config.hitboxSize.Z) / 2

		for j = i + 1, #live do
			local b = live[j]
			local bRadius = math.max(b.config.hitboxSize.X, b.config.hitboxSize.Z) / 2
			local minimum = aRadius + bRadius

			local offset = Vector3.new(b.position.X - a.position.X, 0, b.position.Z - a.position.Z)
			local gap = offset.Magnitude

			if gap >= minimum then
				continue
			end

			--[[ Exactly coincident, which a shared spawn cell can produce.
			     Any direction will do, so long as it is the same one for both
			     halves of the pair. ]]
			local direction = if gap > 1e-3
				then offset.Unit
				else Vector3.new(math.cos(i * 2.4), 0, math.sin(i * 2.4))

			local push = (minimum - gap) * 0.5 * OVERLAP_PUSH

			--[[ Back through the arena, or a pair pressed against a wall would
			     be separated straight through it. ]]
			a.position = Arena.resolveBox(a.position - direction * push, footprint(a.config, a.yaw))
			b.position = Arena.resolveBox(b.position + direction * push, footprint(b.config, b.yaw))

			placeHitbox(a)
			placeHitbox(b)
			positions[a.model] = a.position
			positions[b.model] = b.position
		end
	end
end

function EnemyManager.step(deltaTime: number, now: number)
	for _, enemy in enemies do
		stepEnemy(enemy, deltaTime, now)
	end
end

--[[
	Pushes overlapping bodies apart. Called once per frame, *last*, by the
	server loop.

	It used to run at the end of `step`, before projectiles were resolved.
	But a hit shoves its enemy back, into whatever stands behind it, and that
	happened after separation had already run for the frame —
	so the overlap stood until the next one. One playtest caught a body 1.8
	studs inside another. Running this after everything that can move an
	enemy means nothing is left overlapping at the end of a frame.
]]
function EnemyManager.resolveOverlaps()
	separate()
end

--[[
	Hands over the volleys decided this step and clears the queue. Drained once
	per frame by EnemyFiring; anything left undrained would fire late rather
	than twice.
]]
function EnemyManager.takeVolleys(): { Volley }
	if #pendingVolleys == 0 then
		return {}
	end

	local drained = pendingVolleys
	pendingVolleys = {}
	return drained
end

return EnemyManager
