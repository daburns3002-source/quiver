--!strict
--[[
	Client entry point.

	Wires input, camera, prediction and feedback. Nothing here is authoritative:
	every remote below is server→client, and the only thing the client decides
	is what to draw.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local Device = require(script.Parent.Device)
local Game = require(Shared.Config.Game)
local HealthBar = require(script.Parent.UI.HealthBar)
local HitFeedback = require(script.Parent.Fx.HitFeedback)
local LocalFiring = require(script.Parent.Combat.LocalFiring)
local Log = require(Shared.Util.Log)
local MoveController = require(script.Parent.Input.MoveController)
local ProjectileRenderer = require(script.Parent.Fx.ProjectileRenderer)
local Remotes = require(Shared.Net.Remotes)
local TopDownCamera = require(script.Parent.Camera.TopDownCamera)
local Types = require(Shared.Types)

type ShotEvent = Types.ShotEvent

local log = Log.forTag("Client")
local player = Players.LocalPlayer

log.info("%s v%s client starting on tier %s", Game.Name, Game.Version, Device.tier().name)

--[[
	Health lives on the run session, not the Humanoid, so the built-in bar would
	show a meaningless number.
]]
local function hideDefaultHealthGui()
	local attempts = 0

	while attempts < 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)

		if ok then
			return
		end

		attempts += 1
		task.wait(0.2)
	end

	log.warn("could not hide the default health GUI")
end

task.spawn(hideDefaultHealthGui)

local function currentRoot(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

HealthBar.start()
ProjectileRenderer.start(Workspace)
HitFeedback.start(Workspace)
TopDownCamera.start(currentRoot)
LocalFiring.start()
MoveController.start()

if not MoveController.hasSupportedInput() then
	log.warn("no keyboard or gamepad: this device has no movement input yet")
end

player.CharacterAdded:Connect(function()
	TopDownCamera.reset()
	LocalFiring.reset()
	--[[ The server rebuilds the enemy folder between rooms, so both raycast
	     filters have to be rebuilt against the new instances. ]]
	ProjectileRenderer.refreshFilter()
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Enemies" or child.Name == "Arena" then
		ProjectileRenderer.refreshFilter()
	end
end)

Remotes.event(Remotes.ShotFired).OnClientEvent:Connect(function(event: ShotEvent)
	--[[
		The local player's own volleys are drawn by prediction the moment they
		happen. Drawing the server's copy too would double every arrow.
	]]
	if event.shooterId == player.UserId then
		return
	end

	ProjectileRenderer.spawnVolley(event.origin, event.direction, event.specs, 0)
end)

Remotes.event(Remotes.EnemyHit).OnClientEvent:Connect(HitFeedback.onEnemyHit)
Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(HitFeedback.onEnemyDied)
Remotes.event(Remotes.PlayerDamaged).OnClientEvent:Connect(HitFeedback.onPlayerDamaged)
Remotes.event(Remotes.HealthChanged).OnClientEvent:Connect(HealthBar.update)

log.info("client ready")
