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

local AbilityCards = require(script.Parent.UI.AbilityCards)
local Device = require(script.Parent.Device)
local Game = require(Shared.Config.Game)
local HealthBar = require(script.Parent.UI.HealthBar)
local HitFeedback = require(script.Parent.Fx.HitFeedback)
local LocalFiring = require(script.Parent.Combat.LocalFiring)
local Log = require(Shared.Util.Log)
local MoveController = require(script.Parent.Input.MoveController)
local PlayerStats = require(script.Parent.PlayerStats)
local ProjectileRenderer = require(script.Parent.Fx.ProjectileRenderer)
local Remotes = require(Shared.Net.Remotes)
local RunBanner = require(script.Parent.UI.RunBanner)
local TelegraphRenderer = require(script.Parent.Fx.TelegraphRenderer)
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
RunBanner.start()
ProjectileRenderer.start(Workspace)
HitFeedback.start(Workspace)
TelegraphRenderer.start(Workspace)
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
	ProjectileRenderer.refreshFilters()
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Enemies" or child.Name == "Arena" then
		ProjectileRenderer.refreshFilters()
	end
end)

Remotes.event(Remotes.ShotFired).OnClientEvent:Connect(function(event: ShotEvent)
	--[[
		The local player's own volleys are drawn by prediction the moment they
		happen. Drawing the server's copy too would double every arrow. Only
		player volleys carry a real shooterId, so the faction check keeps an
		enemy volley from ever matching a UserId of 0.
	]]
	if event.faction == "Player" and event.shooterId == player.UserId then
		return
	end

	ProjectileRenderer.spawnVolley(event.faction, event.origin, event.direction, event.specs, 0)
end)

Remotes.event(Remotes.EnemyTelegraph).OnClientEvent:Connect(TelegraphRenderer.onTelegraph)
Remotes.event(Remotes.EnemyHit).OnClientEvent:Connect(HitFeedback.onEnemyHit)
Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(HitFeedback.onEnemyDied)
Remotes.event(Remotes.PlayerDamaged).OnClientEvent:Connect(HitFeedback.onPlayerDamaged)
Remotes.event(Remotes.HealthChanged).OnClientEvent:Connect(HealthBar.update)
Remotes.event(Remotes.RunStateChanged).OnClientEvent:Connect(RunBanner.onRunStateChanged)

--[[ Prediction inputs only — move speed and dash cooldown. Nothing that
     decides an outcome arrives here. ]]
Remotes.event(Remotes.PlayerStats).OnClientEvent:Connect(PlayerStats.set)

--[[
	The draft.

	The screen reports an index and nothing else, and the server validates even
	that against the offer it is holding. Hiding on send rather than waiting
	for a confirmation is deliberate: the run is paused behind this, and a
	screen that lingered for a round trip would feel like the tap was missed.
	A rejected choice simply leaves the offer open and the server re-sends it.
]]
AbilityCards.start(function(index: number)
	AbilityCards.hide()
	Remotes.event(Remotes.AbilityChosen):FireServer(index)
end)

Remotes.event(Remotes.AbilityOffer).OnClientEvent:Connect(function(offer: { string }, level: number)
	AbilityCards.show(offer, level)
end)

Remotes.event(Remotes.XpChanged).OnClientEvent:Connect(RunBanner.onXpChanged)

--[[ A death ends the draft with it. Without this a card screen owed by the
     run that just ended would still be up when the next one starts, pausing a
     room the player cannot see. ]]
player.CharacterRemoving:Connect(function()
	AbilityCards.hide()
	PlayerStats.reset()
end)

log.info("client ready")
