--!strict
--[[
	The tutorial's prompts (owner, 2026-10-25; `Config/Tutorial.prompts`), shown
	only while the stage is the tutorial (`Balance.tutorialStage`):

	- From room 1, how to move, in this device's own controls (keys, touch or
	  the left stick), until the player has walked `moveDistance` studs (the walk
	  to the gate counts: room 1's slimes fall fast to an archer standing still);
	  then, at the next fight, that standing still shoots, for `shootFor` seconds;
	  then how to dash, in this device's controls, until the player has dashed.
	- Over the first upgrade hand, how levelling up works with the upgrades,
	  until a card is picked.

	The room prompts wait behind anything that pauses the run (a NEW ENEMY!
	screen, a draft), so they never sit over a screen asking for a press.
	Blocky like the rest: an ink edge, a dark face, the Arcade font.
	Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local Dash = require(script.Parent.Parent.Input.Dash)
local Device = require(script.Parent.Parent.Device)
local RunPaused = require(script.Parent.Parent.RunPaused)

local TutorialPrompts = {}

local FONT = Font.fromEnum(Enum.Font.Arcade)
local INK = Color3.fromRGB(20, 14, 6)
local FACE = Color3.fromRGB(46, 40, 34)
local GOLD = Color3.fromRGB(255, 210, 63)

type Panel = { group: Frame, title: TextLabel, body: TextLabel }

local roomPanel: Panel? = nil
local levelPanel: Panel? = nil

--[[ Where the run is: the room, its state, and how far the player has walked
     in room 1 since it started fighting. ]]
local room = 0
local fighting = false
local walked = 0
local lastPosition: Vector3? = nil
--[[ Seconds the shooting prompt has left on screen: it counts down only
     while shown, so a NEW ENEMY! screen over it does not use it up. ]]
local shootLeft = 0
local moveTaught = false
local shootShown = false
local dashTaught = false
local levelTaught = false
local levelShowing = false

local function inTutorial(): boolean
	return CurrentStage.index() == Balance.tutorialStage
end

local function rect(parent: Instance, name: string, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, colour: Color3, z: number): TextLabel
	local words = Instance.new("TextLabel")
	words.Name = name
	words.BackgroundTransparency = 1
	words.FontFace = FONT
	words.TextColor3 = colour
	words.TextScaled = true
	words.TextWrapped = true
	words.ZIndex = z
	words.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = words
	return words
end

--[[ An ink-edged dark panel, a gold title line and white words under it. ]]
local function panel(gui: ScreenGui, name: string, y: number, tall: number): Panel
	local phone = Device.isPhone()
	local group = Instance.new("Frame")
	group.Name = name
	group.AnchorPoint = Vector2.new(0.5, 0)
	group.Position = UDim2.fromScale(0.5, y)
	group.Size = UDim2.new(if phone then 0.92 else 0.56, 0, 0, tall)
	group.BackgroundTransparency = 1
	group.Visible = false
	group.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(860, math.huge)
	limit.Parent = group
	local ink = rect(group, "Ink", INK, 1)
	ink.Size = UDim2.fromScale(1, 1)
	local face = rect(group, "Face", FACE, 2)
	face.Position = UDim2.fromOffset(4, 4)
	face.Size = UDim2.new(1, -8, 1, -8)
	face.BackgroundTransparency = 0.08
	local title = label(group, "Title", GOLD, 3)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, math.floor(tall * 0.3))
	local body = label(group, "Body", Color3.new(1, 1, 1), 3)
	body.Position = UDim2.fromOffset(16, math.floor(tall * 0.3) + 14)
	body.Size = UDim2.new(1, -32, 1, -math.floor(tall * 0.3) - 24)
	return { group = group, title = title, body = body }
end

--[[ A prompt in this device's own controls. ]]
local function forDevice(words: { keyboard: string, touch: string, gamepad: string }): string
	local last = UserInputService:GetLastInputType()
	if
		last == Enum.UserInputType.Gamepad1
		or last == Enum.UserInputType.Gamepad2
		or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled)
	then
		return words.gamepad
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return words.touch
	end
	return words.keyboard
end

local function show(p: Panel?, title: string, body: string)
	if not p then
		return
	end
	p.title.Text = title
	p.body.Text = body
	p.group.Visible = true
end

local function hide(p: Panel?)
	if p then
		p.group.Visible = false
	end
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function step(dt: number)
	if not inTutorial() then
		hide(roomPanel)
		hide(levelPanel)
		return
	end
	-- how to move, from room 1 until they have; then, in the next fight, that
	-- standing still shoots
	if room < 1 or RunPaused.get() then
		hide(roomPanel)
		lastPosition = nil
		return
	end
	if not moveTaught then
		local at = rootPosition()
		if at and lastPosition then
			walked += (Vector3.new(at.X, 0, at.Z) - Vector3.new(lastPosition.X, 0, lastPosition.Z)).Magnitude
		end
		lastPosition = at
		if walked >= Tutorial.moveDistance then
			moveTaught = true
		else
			show(roomPanel, "HOW TO MOVE", forDevice(Tutorial.prompts.move))
			return
		end
	end
	if not shootShown and fighting then
		shootShown = true
		shootLeft = Tutorial.shootFor
	end
	if shootLeft > 0 then
		shootLeft -= dt
		show(roomPanel, "HOW TO SHOOT", Tutorial.prompts.shoot)
	elseif shootShown and not dashTaught then
		if Dash.isDashing(os.clock()) then
			dashTaught = true
			hide(roomPanel)
		else
			show(roomPanel, "HOW TO DASH", forDevice(Tutorial.prompts.dash))
		end
	else
		hide(roomPanel)
	end
end

--[[ The run's state, as `Remotes.RunStateChanged` tells it. A new tutorial
     teaches again from the start. ]]
function TutorialPrompts.onRunStateChanged(index: number, _total: number, state: string)
	if state == "Lobby" then
		room = 0
		fighting = false
		return
	end
	if index == 1 and state == "Fighting" and room ~= 1 then
		walked = 0
		lastPosition = nil
		shootLeft = 0
		moveTaught = false
		shootShown = false
		dashTaught = false
		levelTaught = false
	end
	room = index
	fighting = state == "Fighting"
end

--[[ An upgrade hand opened: the first in the tutorial explains levelling up
     until a card is picked. ]]
function TutorialPrompts.onOffer()
	if not inTutorial() or levelTaught then
		return
	end
	levelTaught = true
	levelShowing = true
	show(levelPanel, Tutorial.prompts.levelUp.title, Tutorial.prompts.levelUp.body)
end

function TutorialPrompts.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialPrompts"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- over the draft (100), so the level-up words sit on its hand
	gui.DisplayOrder = 101
	gui.Parent = playerGui
	local phone = Device.isPhone()
	roomPanel = panel(gui, "RoomPrompt", 0.2, if phone then 96 else 110)
	levelPanel = panel(gui, "LevelPrompt", 0.015, if phone then 120 else 132)

	RunPaused.onChanged(function(paused: boolean)
		if not paused and levelShowing then
			levelShowing = false
			hide(levelPanel)
		end
	end)
	Workspace:GetAttributeChangedSignal(CurrentStage.ATTRIBUTE):Connect(function()
		if not inTutorial() then
			hide(levelPanel)
			levelShowing = false
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return TutorialPrompts
