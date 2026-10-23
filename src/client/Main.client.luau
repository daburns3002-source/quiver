--!strict
--[[
	Client entry point.

	Wires input, camera, prediction and feedback. Nothing here is authoritative:
	every remote below is server→client, and the only thing the client decides
	is what to draw.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local BurnFx = require(script.Parent.Fx.BurnFx)
local CombatMarkers = require(script.Parent.Fx.CombatMarkers)
local DashBar = require(script.Parent.UI.DashBar)
local DevKeys = require(script.Parent.DevKeys)
local Device = require(script.Parent.Device)
local DraftScreen = require(script.Parent.UI.Cards.DraftScreen)
local EndScreen = require(script.Parent.UI.EndScreen)
local EnemyHealthBars = require(script.Parent.Fx.EnemyHealthBars)
local Game = require(Shared.Config.Game)
local HealthBar = require(script.Parent.UI.HealthBar)
local HitFeedback = require(script.Parent.Fx.HitFeedback)
local HitSquash = require(script.Parent.Fx.HitSquash)
local LocalFiring = require(script.Parent.Combat.LocalFiring)
local Log = require(Shared.Util.Log)
local MoveController = require(script.Parent.Input.MoveController)
local PickupFx = require(script.Parent.Fx.PickupFx)
local PlayerStats = require(script.Parent.PlayerStats)
local ProjectileRenderer = require(script.Parent.Fx.ProjectileRenderer)
local Remotes = require(Shared.Net.Remotes)
local ReviveFx = require(script.Parent.Fx.ReviveFx)
local RunBanner = require(script.Parent.UI.RunBanner)
local RunPaused = require(script.Parent.RunPaused)
local SkillBar = require(script.Parent.UI.Cards.SkillBar)
local TelegraphRenderer = require(script.Parent.Fx.TelegraphRenderer)
local TopDownCamera = require(script.Parent.Camera.TopDownCamera)
local Types = require(Shared.Types)

type ShotEvent = Types.ShotEvent

local log = Log.forTag("Client")
local player = Players.LocalPlayer

log.info("%s v%s client starting on tier %s", Game.Name, Game.Version, Device.tier().name)

--[[ The server lights the scene for everyone; a device whose tier cannot
     afford a full-screen bloom turns its own copy off. ]]
task.spawn(function()
	local bloom = Lighting:WaitForChild("ArenaBloom", 10)
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = Device.tier().enableBloom
	end
end)

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
DashBar.start()
EndScreen.start(function()
	Remotes.event(Remotes.RunRestart):FireServer()
end)
RunBanner.start()
ProjectileRenderer.start(Workspace)
HitFeedback.start(Workspace)
HitSquash.start(Workspace)
BurnFx.start()
EnemyHealthBars.start()
PickupFx.start(Workspace)
CombatMarkers.start(Workspace)
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

		`predicted` separates "you already drew this" from "the server
		invented this on your behalf". A chain shot off a kill belongs to the
		player and carries their id, but no client saw it coming — skipping it
		on ownership alone would make the one ability that fires free arrows
		fire invisible ones.
	]]
	if event.faction == "Player" and event.shooterId == player.UserId and event.predicted then
		return
	end

	ProjectileRenderer.spawnVolley(
		event.faction,
		event.origin,
		event.direction,
		event.specs,
		0,
		event.from
	)
end)

Remotes.event(Remotes.EnemyTelegraph).OnClientEvent:Connect(TelegraphRenderer.onTelegraph)
Remotes.event(Remotes.EnemyHit).OnClientEvent:Connect(HitFeedback.onEnemyHit)
Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(HitFeedback.onEnemyDied)
Remotes.event(Remotes.Explosion).OnClientEvent:Connect(HitFeedback.onExplosion)
Remotes.event(Remotes.SoulLink).OnClientEvent:Connect(HitFeedback.onSoulLink)
Remotes.event(Remotes.PlayerDodged).OnClientEvent:Connect(HitFeedback.onPlayerDodged)
Remotes.event(Remotes.PickupDropped).OnClientEvent:Connect(PickupFx.onDropped)
Remotes.event(Remotes.PickupsTaken).OnClientEvent:Connect(PickupFx.onTaken)
Remotes.event(Remotes.PickupsCleared).OnClientEvent:Connect(PickupFx.onCleared)
Remotes.event(Remotes.PlayerRevived).OnClientEvent:Connect(ReviveFx.onRevived)
Remotes.event(Remotes.PlayerDamaged).OnClientEvent:Connect(HitFeedback.onPlayerDamaged)
Remotes.event(Remotes.HealthChanged).OnClientEvent:Connect(HealthBar.update)
Remotes.event(Remotes.RunStateChanged).OnClientEvent
	:Connect(function(index, total, state, name, unit)
		RunBanner.onRunStateChanged(index, total, state, name, unit)

		--[[ The end screen belongs to the run that ended, so it clears the
		     moment the next one starts fighting. ]]
		if state == "Fighting" then
			EndScreen.hide()
		end
	end)

Remotes.event(Remotes.RunSummary).OnClientEvent:Connect(EndScreen.show)

--[[ Prediction inputs only — move speed and dash cooldown. Nothing that
     decides an outcome arrives here. ]]
Remotes.event(Remotes.PlayerStats).OnClientEvent:Connect(function(stats)
	PlayerStats.set(stats)

	--[[
		The authoritative end of a draft.

		The server sends this on every grant and on every run reset, so it is
		the one signal that means "the world is running again" regardless of
		how the choice was made. Resuming on the card button alone tied the
		player's ability to shoot to a UI callback — miss that click once, for
		any reason, and prediction stays frozen for the rest of the run while
		the server fires arrows nobody can see.
	]]
	RunPaused.set(false)
end)

--[[
	The draft.

	The screen reports an index and nothing else, and the server validates even
	that against the offer it is holding. Hiding on send rather than waiting
	for a confirmation is deliberate: the run is paused behind this, and a
	screen that lingered for a round trip would feel like the tap was missed.
	A rejected choice simply leaves the offer open and the server re-sends it.
]]
SkillBar.start()
-- On screen through the whole run, not only under the draft.
SkillBar.toCombat()
DevKeys.start()

DraftScreen.start(function(index: number)
	DraftScreen.hide()
	RunPaused.set(false)
	Remotes.event(Remotes.AbilityChosen):FireServer(index)
end, function()
	--[[ Asks only. The server decides whether a reroll is left and sends the
	     new hand as an ordinary offer. ]]
	Remotes.event(Remotes.AbilityReroll):FireServer()
end)

Remotes.event(Remotes.AbilityOffer).OnClientEvent
	:Connect(function(offer: { string }, level: number, source: string?, rerolls: number?)
		--[[ Paused alongside the server, which stops the run for a draft. Without
	     this the prediction draws volleys across a frozen room that the server
	     never fired. ]]
		RunPaused.set(true)
		DraftScreen.show(offer, level, source, rerolls)
	end)

Remotes.event(Remotes.XpChanged).OnClientEvent:Connect(RunBanner.onXpChanged)

--[[ A death ends the draft with it. Without this a card screen owed by the
     run that just ended would still be up when the next one starts, pausing a
     room the player cannot see. ]]
player.CharacterRemoving:Connect(function()
	DraftScreen.hide()
	RunPaused.set(false)
	PlayerStats.reset()
end)

log.info("client ready")
