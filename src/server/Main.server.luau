--!strict
--[[
	Server entry point.

	Builds the Phase 1 room, binds a run session per player, and drives the
	three systems from one loop so their order is explicit rather than emergent:

		enemies move and swing
		players fire
		projectiles travel and resolve

	Projectiles step last so a shot fired this frame starts from where the
	player actually is, and an enemy that moved this frame is where the raycast
	expects it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = require(script.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyManager = require(script.Parent.Enemies.EnemyManager)
local FiringSystem = require(script.Parent.Combat.FiringSystem)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ProjectileSystem = require(script.Parent.Combat.ProjectileSystem)
local RunSession = require(script.Parent.Run.RunSession)

local log = Log.forTag("Server")

log.info("%s v%s booting", Game.Name, Game.Version)

--[[
	Players spawn at the arena centre. Phase 2 replaces this with a room
	entrance.
]]
local function buildSpawn(parent: Instance)
	local existing = parent:FindFirstChild("ArenaSpawn")
	if existing then
		existing:Destroy()
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "ArenaSpawn"
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = Vector3.new(0, 0.5, 30)
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.CastShadow = false
	spawnLocation.Transparency = 1
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = parent
end

Arena.build(workspace)
buildSpawn(workspace)
EnemyManager.init(workspace)
ProjectileSystem.refreshFilter()
EnemyManager.spawnWave(Balance.Spawning.enemyCount)

local function onCharacterAdded(player: Player, character: Model)
	local session = RunSession.get(player) or RunSession.create(player)
	RunSession.bindCharacter(session, character)
end

local function onPlayerAdded(player: Player)
	local session = RunSession.create(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	player.CharacterRemoving:Connect(function()
		RunSession.unbindCharacter(session)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

--[[
	Phase 1 has no room progression, so a cleared wave simply comes back. It
	exists only so the slice can be played for more than one fight; Phase 2
	deletes it.
]]
local respawnAt: number? = nil

RunService.Heartbeat:Connect(function(deltaTime: number)
	local now = os.clock()

	EnemyManager.step(deltaTime, now)
	FiringSystem.step(deltaTime, now)
	ProjectileSystem.step(deltaTime, now)

	if EnemyManager.aliveCount() > 0 then
		respawnAt = nil
		return
	end

	if not respawnAt then
		respawnAt = now + Balance.Spawning.respawnDelay
		return
	end

	if now >= (respawnAt :: number) then
		respawnAt = nil
		EnemyManager.spawnWave(Balance.Spawning.enemyCount)
	end
end)

log.info("ready")
