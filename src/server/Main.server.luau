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

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyFiring = require(script.Parent.Combat.EnemyFiring)
local EnemyManager = require(script.Parent.Enemies.EnemyManager)
local FiringSystem = require(script.Parent.Combat.FiringSystem)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ProjectileSystem = require(script.Parent.Combat.ProjectileSystem)
local RoomController = require(script.Parent.Run.RoomController)
local RunSession = require(script.Parent.Run.RunSession)

local log = Log.forTag("Server")

log.info("%s v%s booting", Game.Name, Game.Version)

--[[
	Where Roblox drops a character on join and on respawn.

	Reads the same `spawnPosition` the run controller uses when it moves
	players into a new room, so arriving and advancing put you in the same
	place. Two sources of truth for "the start of a room" would drift the first
	time either moved.
]]
local function buildSpawn(parent: Instance)
	local existing = parent:FindFirstChild("ArenaSpawn")
	if existing then
		existing:Destroy()
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "ArenaSpawn"
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = Balance.Arena.spawnPosition
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.CastShadow = false
	spawnLocation.Transparency = 1
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = parent
end

buildSpawn(workspace)

--[[ The run controller owns the arena now: it builds a room on entry, so
     there is nothing to build here. ]]
RunSession.onDeath = function()
	RoomController.onPlayerDied()
end

RoomController.start()

local function onCharacterAdded(player: Player, character: Model)
	local session = RunSession.get(player) or RunSession.create(player)
	RunSession.bindCharacter(session, character)
	--[[ Enemy projectiles raycast against player characters, so the filter has
	     to learn about each new body. Without this a respawned player is
	     invisible to every enemy shot. ]]
	ProjectileSystem.refreshFilters()
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

RunService.Heartbeat:Connect(function(deltaTime: number)
	local now = os.clock()

	EnemyManager.step(deltaTime, now)
	--[[ Straight after the enemies decide, so a volley never waits a frame
	     between its telegraph ending and the projectiles existing. ]]
	EnemyFiring.step(now)
	FiringSystem.step(deltaTime, now)
	ProjectileSystem.step(deltaTime, now)

	--[[ Last, so a room is only ever declared clear after everything that
	     could still kill something has had its turn this frame. ]]
	RoomController.step(now)
end)

log.info("ready")
