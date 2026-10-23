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

local Atmosphere = require(script.Parent.Arena.Atmosphere)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Burning = require(script.Parent.Combat.Burning)
local EnemyFiring = require(script.Parent.Combat.EnemyFiring)
local EnemyManager = require(script.Parent.Enemies.EnemyManager)
local EnemyModel = require(script.Parent.Enemies.EnemyModel)
local FiringSystem = require(script.Parent.Combat.FiringSystem)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ProjectileSystem = require(script.Parent.Combat.ProjectileSystem)
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Net.Remotes)
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

RunSession.onRevive = function(_session, position: Vector3)
	ProjectileSystem.clearEnemyShotsNear(position, Balance.Revive.clearRadius)
end

Atmosphere.apply()
-- Uploaded enemy meshes, made once before anything spawns.
EnemyModel.preload()
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

--[[
	The client picks a card.

	The only thing it is trusted with is an index into an offer this server
	sent it moments ago, and `Loadout.choose` checks even that. Anything else
	arriving here — a string, a float, an index out of range, a choice with no
	offer open — changes nothing.
]]
Remotes.event(Remotes.AbilityChosen).OnServerEvent:Connect(function(player, index)
	if typeof(index) ~= "number" then
		return
	end

	local session = RunSession.get(player)
	if not session then
		return
	end

	RunSession.chooseAbility(session, index)
end)

--[[ The client asks for a redeal. It sends nothing else: whether there is a
     hand to redeal and a reroll to spend is the server's to decide. ]]
--[[ Testing only: the next hand includes a Mythic. Honoured only when the
     game is running in Studio, so nothing a live client sends can use it. ]]
local FORCEABLE = { Mythic = true, Legendary = true }

Remotes.event(Remotes.DebugForceMythic).OnServerEvent:Connect(function(player, rarity)
	if not RunService:IsStudio() then
		return
	end
	local wanted = if typeof(rarity) == "string" and FORCEABLE[rarity] then rarity else "Mythic"
	local session = RunSession.get(player)
	if session then
		session.loadout.forceRarity = wanted
		log.info("%s queued a %s for the next hand (Studio)", player.Name, wanted)
	end
end)

Remotes.event(Remotes.AbilityReroll).OnServerEvent:Connect(function(player)
	local session = RunSession.get(player)
	if session then
		RunSession.reroll(session)
	end
end)

--[[ The end screen's button. Only a player in the run may ask, and
     `requestRestart` ignores the request unless the run is over. ]]
Remotes.event(Remotes.RunRestart).OnServerEvent:Connect(function(player)
	if RunSession.get(player) then
		RoomController.requestRestart()
	end
end)

RunService.Heartbeat:Connect(function(deltaTime: number)
	local now = os.clock()

	--[[ The world holds still while a card screen is up. A draft read under
	     fire is not a choice, and a player who takes damage while reading one
	     will stop reading them. ]]
	if RunSession.anyChoosing() then
		return
	end

	--[[ And behind the end screen, which now waits for its button rather
	     than a 2.5 s timer. A character respawns after five seconds; left
	     running, the arena killed it again behind the screen, every time. ]]
	if RoomController.isOver() then
		return
	end

	EnemyManager.step(deltaTime, now)
	--[[ Straight after the enemies decide, so a volley never waits a frame
	     between its telegraph ending and the projectiles existing. ]]
	EnemyFiring.step(now)
	FiringSystem.step(deltaTime, now)
	ProjectileSystem.step(deltaTime, now)
	--[[ After projectiles, so a burn lit this frame does not tick in it. ]]
	Burning.step(now)
	--[[ After projectiles, because a hit's knockback moves its enemy and can
	     push it into another. Overlaps are resolved once everything that can
	     move a body this frame has done so. ]]
	EnemyManager.resolveOverlaps()
	--[[ Crystals and hearts are taken by walking over them, so after
	     everything that moves the player this frame. ]]
	RunSession.pickUpFloor()
	--[[ Mending. ]]
	RunSession.regenerate(deltaTime, now)

	--[[ Last, so a room is only ever declared clear after everything that
	     could still kill something has had its turn this frame. ]]
	RoomController.step(now)
end)

log.info("ready")
