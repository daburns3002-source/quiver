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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyModel = require(script.Parent.EnemyModel)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)

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

type Enemy = {
	model: Model,
	hitbox: BasePart,
	--[[ Everything drawn for this enemy. Separate from `hitbox` on purpose:
	     the hitbox is what the server sweeps and the skin is what the player
	     sees, and only the first of those is allowed to matter to combat. ]]
	skin: EnemyModel.Skin,
	config: EnemyConfig,
	health: number,
	maxHealth: number,
	position: Vector3,
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
}

local EnemyManager = {}

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

--[[ Studs enemies try to keep between each other, so a wave reads as a group
     rather than one overlapping blob. ]]
local SEPARATION_DISTANCE = 3.5
local SEPARATION_STRENGTH = 6

--[[ Studs ahead of itself an enemy checks for a pillar before committing to a
     step. A charger has no pathfinding, so without this it walks into an
     obstacle face and Arena.resolve pins it there for ever. ]]
local OBSTACLE_PROBE = 1.25

--[[ Fraction of its attackRange a ranged enemy backs away below, so it keeps a
     shooting lane instead of being walked over and turned into a melee enemy
     with a worse attack. ]]
local HOLD_FRACTION = 0.6

--[[ Studs between candidate spawn points when scanning the floor. Fine enough
     that a valid gap is never missed, coarse enough that the whole scan is a
     few hundred box tests. ]]
local SPAWN_GRID_STEP = 4

--[[ Volleys decided this step, drained by EnemyFiring. ]]
local pendingVolleys: { Volley } = {}

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
end

function EnemyManager.positions(): { [Model]: Vector3 }
	return positions
end

function EnemyManager.aliveCount(): number
	return aliveCount
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

			if Arena.isClear(candidate, radius) then
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

		if Arena.isClear(nudged, radius) and distanceToNearest(nudged, keepAway) >= minimum then
			return nudged
		end

		return chosen
	end

	--[[ No cell anywhere satisfies the minimum — too many players spread
	     across a small room. Take the furthest clear spot rather than refusing
	     to spawn, and accept that this wave starts closer than it should. ]]
	return bestPosition or Vector3.new(limitX, y, limitZ)
end

function EnemyManager.spawn(config: EnemyConfig): Model?
	local parent = folder
	if not parent then
		log.warn("spawn before init")
		return nil
	end

	local position = findSpawnPosition(config)
	local model, hitbox, skin = EnemyModel.build(config, position)

	enemies[model] = {
		model = model,
		hitbox = hitbox,
		skin = skin,
		config = config,
		health = config.health,
		maxHealth = config.health,
		position = position,
		lastAttackAt = 0,
		volleyAt = nil,
		volleyDirection = nil,
		surfacesAt = nil,
		surfaceTold = false,
		lastSurfacedAt = 0,
		submerged = false,
		slideSign = nil,
	}
	positions[model] = position
	aliveCount += 1

	model.Parent = parent

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

	for index = 1, count do
		EnemyManager.spawn(roster[(index - 1) % #roster + 1])
	end

	log.info("spawned wave of %d from %d archetypes", count, #roster)
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
	question asked of the wrong function. Death is handled here and announced
	on `enemyDied`; nothing outside needs to be told about it.
]]
function EnemyManager.damage(model: Model, amount: number, fromPosition: Vector3): boolean
	local enemy = enemies[model]
	if not enemy or amount <= 0 then
		return false
	end

	enemy.health -= amount

	local knockbackDirection = enemy.position - fromPosition
	if knockbackDirection.Magnitude > 1e-3 then
		local flat = Vector3.new(knockbackDirection.X, 0, knockbackDirection.Z).Unit
		local radius = math.max(enemy.config.hitboxSize.X, enemy.config.hitboxSize.Z) / 2
		enemy.position = Arena.resolve(enemy.position + flat * enemy.config.knockback, radius)
		positions[model] = enemy.position
		enemy.hitbox.Position = enemy.position
	end

	if enemy.health > 0 then
		enemyHit:FireAllClients(model, amount, enemy.position)
		return true
	end

	enemies[model] = nil
	positions[model] = nil
	aliveCount -= 1

	--[[
		Position only, deliberately. Passing `model` here raced the `Destroy`
		on the next line: whether the client received a usable reference or nil
		depended on replication ordering within the frame. Anything the client
		needs about a dead enemy has to travel as data, because the instance it
		would describe is already gone.
	]]
	enemyDied:FireAllClients(enemy.position)
	model:Destroy()

	return true
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
		damage = enemy.config.attackDamage,
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
local function stepEnemy(enemy: Enemy, deltaTime: number, now: number)
	local targetRoot, distance = nearestAlivePlayerRoot(enemy.position)
	if not targetRoot then
		return
	end

	local config = enemy.config
	local shot = config.shot
	local burrow = config.burrow
	local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2

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
				--[[ Sent from where it will actually come up, which is where it
				     is now — it keeps travelling during the tell, so the marker
				     is a prediction the player can still beat on foot. ]]
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

				--[[ It ignored obstacles on the way, so it can be standing
				     inside one now. Pushed out before it becomes solid again,
				     or it would surface embedded in a pillar and be shot at
				     through geometry. ]]
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

	if tooFar or tooClose then
		local toTarget = Vector3.new(
			targetRoot.Position.X - enemy.position.X,
			0,
			targetRoot.Position.Z - enemy.position.Z
		)

		local heading = if toTarget.Magnitude > 1e-3 then toTarget.Unit else Vector3.zero
		local desired = if tooClose then -heading else heading

		--[[
			Steer along a pillar face rather than into it. Targeting
			deliberately ignores line of sight, so a charger is routinely sent
			straight at an obstacle; without this it presses against the face,
			Arena.resolve returns it to the same spot every frame, and the room
			deadlocks with the player's arrows blocked by that same pillar.
		]]
		if desired.Magnitude > 1e-3 and not enemy.submerged then
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
			else Arena.resolve(nextPosition, radius)

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

	-- Face the player regardless of whether it is closing or swinging.
	local facing = Vector3.new(
		targetRoot.Position.X - enemy.position.X,
		0,
		targetRoot.Position.Z - enemy.position.Z
	)

	if facing.Magnitude > 1e-3 then
		enemy.hitbox.CFrame = CFrame.lookAt(enemy.position, enemy.position + facing.Unit)
	else
		enemy.hitbox.Position = enemy.position
	end

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
			queueVolley(enemy, targetRoot, shot)
			enemy.volleyDirection = nil
		end

		return
	end

	if distance > config.attackRange then
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

		enemyTelegraph:FireAllClients(
			enemy.position,
			aim,
			shot.telegraph,
			shot.tell,
			config.attackRange
		)

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

	RunSession.applyDamage(session, config.attackDamage)
end

function EnemyManager.step(deltaTime: number, now: number)
	for _, enemy in enemies do
		stepEnemy(enemy, deltaTime, now)
	end
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
