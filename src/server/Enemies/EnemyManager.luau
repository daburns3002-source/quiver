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

local function buildModel(config: EnemyConfig, position: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = config.displayName

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = config.hitboxSize
	hitbox.Position = position
	hitbox.Anchored = true
	--[[
		Collision is resolved analytically in Arena.resolve, so the hitbox is
		only ever a raycast target. Leaving CanCollide on would let enemies shove
		the player's character around, which move-or-shoot cannot survive.
	]]
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CastShadow = false
	hitbox.Color = config.color
	hitbox.Material = Enum.Material.SmoothPlastic
	hitbox.Parent = model

	model.PrimaryPart = hitbox

	return model, hitbox
end

--[[ A spawn point inside the arena, clear of geometry and away from players. ]]
local function findSpawnPosition(config: EnemyConfig): Vector3
	local arena = Balance.Arena
	local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2
	local limitX = arena.size.X / 2 - radius - 2
	local limitZ = arena.size.Z / 2 - radius - 2
	local y = config.hitboxSize.Y / 2

	for _ = 1, 40 do
		local candidate =
			Vector3.new(math.random() * limitX * 2 - limitX, y, math.random() * limitZ * 2 - limitZ)

		if not Arena.isClear(candidate, radius) then
			continue
		end

		local tooClose = false

		for _, session in RunSession.all() do
			local root = session.root
			if root and session.alive then
				local flat =
					Vector3.new(candidate.X - root.Position.X, 0, candidate.Z - root.Position.Z)
				if flat.Magnitude < Balance.Spawning.minSpawnDistance then
					tooClose = true
					break
				end
			end
		end

		if not tooClose then
			return candidate
		end
	end

	-- Fell through: take a corner rather than failing to spawn.
	return Vector3.new(limitX, y, limitZ)
end

function EnemyManager.spawn(config: EnemyConfig): Model?
	local parent = folder
	if not parent then
		log.warn("spawn before init")
		return nil
	end

	local position = findSpawnPosition(config)
	local model, hitbox = buildModel(config, position)

	enemies[model] = {
		model = model,
		hitbox = hitbox,
		config = config,
		health = config.health,
		maxHealth = config.health,
		position = position,
		lastAttackAt = 0,
		volleyAt = nil,
		volleyDirection = nil,
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
function EnemyManager.spawnWave(count: number)
	--[[
		Cycled rather than randomised so a wave always contains one of each
		pressure — something that closes, something that makes you move,
		something that makes you reposition, and something that denies space —
		and so a playtest is comparing the same fight each run.
	]]
	local roster = {
		Balance.Enemies.MeleeCharger,
		Balance.Enemies.SpreadShooter,
		Balance.Enemies.MeleeCharger,
		Balance.Enemies.LineSniper,
		Balance.Enemies.MeleeCharger,
		Balance.Enemies.Tank,
	}

	for index = 1, count do
		EnemyManager.spawn(roster[(index - 1) % #roster + 1])
	end

	log.info("spawned wave of %d", count)
end

--[[
	Server-authoritative damage. Nothing on the client can reach this; the
	projectile system is the only caller.
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
		return false
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
	local radius = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2

	--[[ Whether the obstacle steering below committed to a side this step. The
	     commitment must not outlive the block that caused it. ]]
	local steering = false

	--[[ A ranged enemy also moves when it is *too close*, backing off to
	     recover its shooting lane. A melee one never does. ]]
	local tooFar = distance > config.attackRange
	local tooClose = shot ~= nil and distance < config.attackRange * HOLD_FRACTION

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
		if desired.Magnitude > 1e-3 then
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

		local nextPosition = enemy.position + move * enemy.config.moveSpeed * deltaTime
		enemy.position = Arena.resolve(nextPosition, radius)
		positions[enemy.model] = enemy.position
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
	local volleyAt = enemy.volleyAt

	if volleyAt and shot then
		if now >= volleyAt then
			enemy.volleyAt = nil
			enemy.hitbox.Color = config.color
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
		enemy.hitbox.Color = Balance.TelegraphColor

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
