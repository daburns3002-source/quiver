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

local ArcanistFx = require(script.Parent.Fx.Upgrades.ArcanistFx)
local Balance = require(Shared.Config.Balance)
local BossBanner = require(script.Parent.UI.BossBanner)
local BossBar = require(script.Parent.UI.BossBar)
local BurnFx = require(script.Parent.Fx.BurnFx)
local CardPreload = require(script.Parent.UI.Cards.CardPreload)
local ClassScreen = require(script.Parent.UI.ClassScreen)
local Classes = require(Shared.Config.Classes)
local CombatMarkers = require(script.Parent.Fx.CombatMarkers)
local ControlMenu = require(script.Parent.UI.ControlMenu)
local DashBar = require(script.Parent.UI.DashBar)
local DevKeys = require(script.Parent.DevKeys)
local Device = require(script.Parent.Device)
local DraftScreen = require(script.Parent.UI.Cards.DraftScreen)
local EggScreen = require(script.Parent.UI.EggScreen)
local EndScreen = require(script.Parent.UI.EndScreen)
local EndlessCheckpoint = require(script.Parent.UI.EndlessCheckpoint)
local EnemyHealthBars = require(script.Parent.Fx.EnemyHealthBars)
local EnemyRig = require(script.Parent.Fx.EnemyRig)
local EnemySounds = require(script.Parent.Fx.EnemySounds)
local ForestAmbience = require(script.Parent.Fx.ForestAmbience)
local Game = require(Shared.Config.Game)
local GearScreen = require(script.Parent.UI.GearScreen)
local HealthBar = require(script.Parent.UI.HealthBar)
local HitFeedback = require(script.Parent.Fx.HitFeedback)
local HitSquash = require(script.Parent.Fx.HitSquash)
local IntroCutscene = require(script.Parent.UI.IntroCutscene)
local LocalFiring = require(script.Parent.Combat.LocalFiring)
local Log = require(Shared.Util.Log)
local ModelAnimator = require(script.Parent.Fx.ModelAnimator)
local MoveController = require(script.Parent.Input.MoveController)
local MusicFx = require(script.Parent.Fx.MusicFx)
local NameTags = require(script.Parent.UI.NameTags)
local NewEnemyScreen = require(script.Parent.UI.NewEnemyScreen)
local PetPreview = require(script.Parent.Fx.PetPreview)
local PickupFx = require(script.Parent.Fx.PickupFx)
local PlayerStats = require(script.Parent.PlayerStats)
local PortalScreen = require(script.Parent.UI.PortalScreen)
local ProjectileRenderer = require(script.Parent.Fx.ProjectileRenderer)
local RangerFx = require(script.Parent.Fx.Upgrades.RangerFx)
local Remotes = require(Shared.Net.Remotes)
local ReviveFx = require(script.Parent.Fx.ReviveFx)
local RoomPreload = require(script.Parent.Fx.RoomPreload)
local RoomSign = require(script.Parent.UI.RoomSign)
local RootHoldFx = require(script.Parent.Fx.RootHoldFx)
local RunBanner = require(script.Parent.UI.RunBanner)
local RunPaused = require(script.Parent.RunPaused)
local SandboxMenu = require(script.Parent.UI.SandboxMenu)
local SharedFx = require(script.Parent.Fx.Upgrades.SharedFx)
local ShopScreen = require(script.Parent.UI.ShopScreen)
local Shove = require(script.Parent.Input.Shove)
local SkillBar = require(script.Parent.UI.Cards.SkillBar)
local SlimeHop = require(script.Parent.Fx.SlimeHop)
local SlimeResidue = require(script.Parent.Fx.SlimeResidue)
local SoundFx = require(script.Parent.Fx.SoundFx)
local StoryCutscene = require(script.Parent.UI.StoryCutscene)
local TelegraphRenderer = require(script.Parent.Fx.TelegraphRenderer)
local TopDownCamera = require(script.Parent.Camera.TopDownCamera)
local TutorialPrompts = require(script.Parent.UI.TutorialPrompts)
local Types = require(Shared.Types)
local UpgradeFx = require(script.Parent.Fx.Upgrades.UpgradeFx)
local VitalFx = require(script.Parent.Fx.Upgrades.VitalFx)
local WardenFx = require(script.Parent.Fx.Upgrades.WardenFx)
local WeaponGlow = require(script.Parent.Fx.WeaponGlow)
local WeaponPose = require(script.Parent.Fx.WeaponPose)
local Weapons = require(Shared.Config.Weapons)

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

--[[ The intro cutscene first, so its black screen is up before anything
     else draws. BEGIN ADVENTURE plays the story cutscene (`UI/StoryCutscene`),
     and only its end lets the run in: the run's music and the first room's
     sign wait, and the server keeps the player on the title until
     `Remotes.IntroBegin`. If either cutscene cannot start, the run is let go
     at once rather than held for ever. ]]
local function beginRun()
	MusicFx.setQuiet(false)
	RoomSign.setWaiting(false)
	Remotes.event(Remotes.IntroBegin):FireServer()
end
local function playStory()
	-- the cards' images, once the title has given the story's frames their turn
	CardPreload.start()
	local ok, problem = pcall(function()
		StoryCutscene.start(beginRun)
	end)
	if not ok then
		log.warn("story cutscene failed to start: %s", tostring(problem))
		StoryCutscene.stop()
		beginRun()
	end
end
if IntroCutscene.skipped() then
	CardPreload.start()
else
	MusicFx.setQuiet(true)
	RoomSign.setWaiting(true)
	StoryCutscene.preload()
	local ok, problem = pcall(function()
		IntroCutscene.start(playStory)
	end)
	if not ok then
		log.warn("intro cutscene failed to start: %s", tostring(problem))
		IntroCutscene.stop()
		beginRun()
	end
end

--[[ The intro is up (or skipped): the loading screen can lift
     (`first/Loading`). ]]
player:SetAttribute("ClientReady", true)

NameTags.start()
HealthBar.start()
DashBar.start()
EndScreen.start(function()
	Remotes.event(Remotes.RunRestart):FireServer()
end)
RunBanner.start()
RoomSign.start()
ProjectileRenderer.start(Workspace)
HitFeedback.start(Workspace)
HitSquash.start(Workspace)
EnemySounds.start(Workspace)
SlimeHop.start(Workspace)
SlimeResidue.start(Workspace)
EnemyRig.start(Workspace)
ModelAnimator.start()
UpgradeFx.start()
MusicFx.start()
SharedFx.start()
VitalFx.start()
RangerFx.start()
WardenFx.start()
WeaponGlow.start()
ArcanistFx.start(Workspace)
ForestAmbience.start()
RoomPreload.start()
BurnFx.start()
RootHoldFx.start()
EnemyHealthBars.start()
BossBar.start()
BossBanner.start()
NewEnemyScreen.start()
EndlessCheckpoint.start()
TutorialPrompts.start()
PickupFx.start(Workspace)
CombatMarkers.start(Workspace)
TelegraphRenderer.start(Workspace)
TopDownCamera.start(currentRoot)
LocalFiring.start()
WeaponPose.start(function()
	return LocalFiring.currentTarget() ~= nil
end)
LocalFiring.onFired(WeaponPose.release)
LocalFiring.onFired(function()
	local class = Classes[player:GetAttribute("Class") :: string? or "Ranger"] or Classes.Ranger
	local recorded = player:GetAttribute("Weapon")
	local weapon = (
		(Weapons :: any)[if type(recorded) == "string" then recorded else class.weapon]
		or (Weapons :: any)[class.weapon]
	) :: Weapons.Weapon
	--[[ After `WeaponPose.release`, registered first, so the combo has
	     already moved on to the blow this is. ]]
	local blow = weapon.comboSounds and weapon.comboSounds[WeaponPose.comboIndex()]
	SoundFx.play(blow or weapon.fireSound)
end)
SoundFx.preload()
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
		event.from,
		event.look
	)
end)

Remotes.event(Remotes.EnemyTelegraph).OnClientEvent:Connect(TelegraphRenderer.onTelegraph)
Remotes.event(Remotes.EnemyHit).OnClientEvent:Connect(HitFeedback.onEnemyHit)
Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(HitFeedback.onEnemyDied)
Remotes.event(Remotes.EnemyHit).OnClientEvent:Connect(SlimeResidue.onEnemyHit)
Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(SlimeResidue.onEnemyDied)
Remotes.event(Remotes.EnemyHit).OnClientEvent:Connect(function()
	SoundFx.play("enemy_hit")
end)
Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(function()
	SoundFx.play("enemy_death")
end)
Remotes.event(Remotes.PlayerDamaged).OnClientEvent:Connect(function()
	SoundFx.play("player_hurt")
end)
Remotes.event(Remotes.Explosion).OnClientEvent:Connect(HitFeedback.onExplosion)
Remotes.event(Remotes.SoulLink).OnClientEvent:Connect(HitFeedback.onSoulLink)
Remotes.event(Remotes.PlayerDodged).OnClientEvent:Connect(HitFeedback.onPlayerDodged)
--[[ A boss's hit moving this player: pushed, or held still by a grab. ]]
Remotes.event(Remotes.PlayerShoved).OnClientEvent:Connect(function(direction, distance)
	if typeof(direction) == "Vector3" and type(distance) == "number" then
		Shove.push(os.clock(), direction, distance)
	end
end)
Remotes.event(Remotes.PlayerGrabbed).OnClientEvent:Connect(function(seconds)
	if type(seconds) == "number" then
		Shove.hold(os.clock(), seconds)
	end
end)
Remotes.event(Remotes.PickupDropped).OnClientEvent:Connect(PickupFx.onDropped)
Remotes.event(Remotes.PickupsTaken).OnClientEvent:Connect(PickupFx.onTaken)
Remotes.event(Remotes.PickupsCleared).OnClientEvent:Connect(PickupFx.onCleared)
Remotes.event(Remotes.PlayerRevived).OnClientEvent:Connect(ReviveFx.onRevived)
Remotes.event(Remotes.PlayerDamaged).OnClientEvent:Connect(HitFeedback.onPlayerDamaged)
Remotes.event(Remotes.HealthChanged).OnClientEvent:Connect(HealthBar.update)
Remotes.event(Remotes.RunStateChanged).OnClientEvent
	:Connect(function(index, total, state, name, unit)
		RunBanner.onRunStateChanged(index, total, state, name, unit)
		RoomSign.onRunStateChanged(index, total, state, name, unit)
		TutorialPrompts.onRunStateChanged(index, total, state)
		ControlMenu.onRunStateChanged(index, total, state)

		--[[ The end screen belongs to the run that ended, so it clears the
		     moment the next one starts fighting. ]]
		if state == "Fighting" or state == "Lobby" then
			EndScreen.hide()
		elseif state == "Cleared" and unit ~= "Wave" then
			--[[ With the doors, which start to swing once the clear's
			     own beat has passed (`Arena/ExitGate`). Only a Rooms stage
			     has an exit to open. ]]
			task.delay(Balance.Run.clearPause, SoundFx.play, "gate_open")
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
-- Studio only: the playtest sandbox's SANDBOX tab (also the O key)
SandboxMenu.start()
-- the Blacksmith's weapon shop, and the wallet, in the lobby
ClassScreen.start()
ShopScreen.start()
EggScreen.start()
GearScreen.start()
-- the pets in this player's two slots, at heel
PetPreview.follow()
-- a lit portal's screen and its level selector, in the lobby
PortalScreen.start()

DraftScreen.start(function(index: number)
	DraftScreen.hide()
	RunPaused.set(false)
	SoundFx.play("card_pick")
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
		--[[ A reroll re-sends the offer to an open draft; the chime is for
		     the draft opening. ]]
		if not RunPaused.get() then
			SoundFx.play("level_up")
		end
		RunPaused.set(true)
		DraftScreen.show(offer, level, source, rerolls)
		TutorialPrompts.onOffer()
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
