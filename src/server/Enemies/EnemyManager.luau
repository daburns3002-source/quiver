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

type EnemyConfig = typeof(Balance.Enemies.MeleeCharger)

type Enemy = {
	model: Model,
	hitbox: BasePart,
	config: EnemyConfig,
	health: number,
	maxHealth: number,
	position: Vector3,
	lastAttackAt: number,
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

--[[ Studs enemies try to keep between each other, so a wave reads as a group
     rather than one overlapping blob. ]]
local SEPARATION_DISTANCE = 3.5
local SEPARATION_STRENGTH = 6

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
	}
	positions[model] = position
	aliveCount += 1

	model.Parent = parent

	return model
end

function EnemyManager.spawnWave(count: number)
	for _ = 1, count do
		EnemyManager.spawn(Balance.Enemies.MeleeCharger)
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

	enemyDied:FireAllClients(model, enemy.position)
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
	Melee charger behaviour: walk at the nearest living player, hit them on
	cooldown when close enough. No pathfinding — Archero rooms are open, and a
	charger that beelines is readable in a way one that navigates is not.
]]
local function stepEnemy(enemy: Enemy, deltaTime: number, now: number)
	local targetRoot, distance = nearestAlivePlayerRoot(enemy.position)
	if not targetRoot then
		return
	end

	local radius = math.max(enemy.config.hitboxSize.X, enemy.config.hitboxSize.Z) / 2

	if distance > enemy.config.attackRange then
		local toTarget = Vector3.new(
			targetRoot.Position.X - enemy.position.X,
			0,
			targetRoot.Position.Z - enemy.position.Z
		)

		local desired = if toTarget.Magnitude > 1e-3 then toTarget.Unit else Vector3.zero
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

	if distance > enemy.config.attackRange then
		return
	end

	if now - enemy.lastAttackAt < enemy.config.attackCooldown then
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

	enemy.lastAttackAt = now
	RunSession.applyDamage(session, enemy.config.attackDamage)
end

function EnemyManager.step(deltaTime: number, now: number)
	for _, enemy in enemies do
		stepEnemy(enemy, deltaTime, now)
	end
end

return EnemyManager
