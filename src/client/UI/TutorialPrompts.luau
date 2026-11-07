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
	Every prompt stays at least `Tutorial.minShow` seconds once shown.
	In the chunky UI's style (`UI/Chunky`): a blue panel with a navy edge, a
	gold title and white words in its one font with a navy stroke, sized from
	the screen so a phone reads them as easily as a computer, and drawn over
	the HUD and the draft. Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local Chunky = require(script.Parent.Chunky)
local Dash = require(script.Parent.Parent.Input.Dash)
local Device = require(script.Parent.Parent.Device)
local RunPaused = require(script.Parent.Parent.RunPaused)

local TutorialPrompts = {}

type Panel = {
	group: Frame,
	title: TextLabel,
	body: TextLabel,
	titleStroke: UIStroke,
	bodyStroke: UIStroke,
	outline: UIStroke,
	rim: UIStroke,
	corner: UICorner,
	rimCorner: UICorner,
	padding: UIPadding,
	gap: UIListLayout,
}

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
--[[ Seconds the move and dash prompts have been on screen: each stays at
     least `Tutorial.minShow`, so a quick walk or dash cannot whisk it away
     before it is read. ]]
local moveShown = 0
local dashShown = 0
local dashed = false
local moveTaught = false
local shootShown = false
local dashTaught = false
local levelTaught = false
local levelShowing = false

local function inTutorial(): boolean
	return CurrentStage.index() == Balance.tutorialStage
end

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function line(
	parent: Instance,
	name: string,
	colour: Color3,
	order: number
): (TextLabel, UIStroke)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = Chunky.font
	t.TextColor3 = colour
	t.TextWrapped = true
	t.Size = UDim2.fromScale(1, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.LayoutOrder = order
	t.ZIndex = 4
	t.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = Chunky.navy
	stroke.Parent = t
	return t, stroke
end

--[[ The chunky UI's blue panel (`UI/Chunky`): lit from the top, a thick
     navy outline and a lighter rim, a gold title and white words in the
     one font with a navy stroke. It grows to fit its words, which are
     sized from the screen (`fit`) rather than squeezed into a box. ]]
local function panel(gui: ScreenGui, name: string, y: number): Panel
	local group = Instance.new("Frame")
	group.Name = name
	group.AnchorPoint = Vector2.new(0.5, 0)
	group.Position = UDim2.fromScale(0.5, y)
	group.AutomaticSize = Enum.AutomaticSize.Y
	group.BackgroundColor3 = Color3.new(1, 1, 1)
	group.BorderSizePixel = 0
	group.ZIndex = 2
	group.Visible = false
	group.Parent = gui
	local light = Instance.new("UIGradient")
	light.Rotation = 90
	light.Color = ColorSequence.new(Chunky.panelTop, Chunky.panelBottom)
	light.Parent = group
	local corner = Instance.new("UICorner")
	corner.Parent = group
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Color = Chunky.navy
	outline.Parent = group

	local rimFrame = Instance.new("Frame")
	rimFrame.Name = "Rim"
	rimFrame.BackgroundTransparency = 1
	rimFrame.Size = UDim2.fromScale(1, 1)
	rimFrame.ZIndex = 3
	rimFrame.Parent = group
	local rimCorner = Instance.new("UICorner")
	rimCorner.Parent = rimFrame
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = Color3.fromRGB(130, 186, 255)
	rim.Parent = rimFrame

	local content = Instance.new("Frame")
	content.Name = "Words"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.ZIndex = 4
	content.Parent = group
	local padding = Instance.new("UIPadding")
	padding.Parent = content
	local gap = Instance.new("UIListLayout")
	gap.SortOrder = Enum.SortOrder.LayoutOrder
	gap.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gap.Parent = content
	local title, titleStroke = line(content, "Title", Chunky.gold, 1)
	local body, bodyStroke = line(content, "Body", Chunky.white, 2)
	return {
		group = group,
		title = title,
		body = body,
		titleStroke = titleStroke,
		bodyStroke = bodyStroke,
		outline = outline,
		rim = rim,
		corner = corner,
		rimCorner = rimCorner,
		padding = padding,
		gap = gap,
	}
end

--[[ Sizes a panel and its words for this screen: big enough to read at a
     glance on a computer, and on a phone held either way. ]]
local function fit(p: Panel?, maxWidth: number)
	if not p then
		return
	end
	local view = viewport()
	local short = math.min(view.X, view.Y)
	local phone = Device.isPhone()
	local bodySize = math.floor(math.clamp(short * 0.042, 20, 36))
	local titleSize = math.floor(math.clamp(short * 0.06, 26, 50))
	local width = math.min(view.X * (if phone then 0.94 else 0.62), maxWidth)
	p.group.Size = UDim2.fromOffset(width, 0)
	p.title.TextSize = titleSize
	p.body.TextSize = bodySize
	p.titleStroke.Thickness = math.max(2, titleSize * 0.12)
	p.bodyStroke.Thickness = math.max(2, bodySize * 0.11)
	local edge = math.max(3, math.floor(short * 0.006))
	p.outline.Thickness = edge
	p.rim.Thickness = math.max(1, math.floor(edge / 2))
	p.corner.CornerRadius = UDim.new(0, edge * 4)
	p.rimCorner.CornerRadius = UDim.new(0, edge * 4)
	local pad = math.floor(bodySize * 0.7)
	p.padding.PaddingLeft = UDim.new(0, pad)
	p.padding.PaddingRight = UDim.new(0, pad)
	p.padding.PaddingTop = UDim.new(0, math.floor(pad * 0.6))
	p.padding.PaddingBottom = UDim.new(0, math.floor(pad * 0.8))
	p.gap.Padding = UDim.new(0, math.floor(bodySize * 0.25))
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
		if walked >= Tutorial.moveDistance and moveShown >= Tutorial.minShow then
			moveTaught = true
		else
			moveShown += dt
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
			dashed = true
		end
		if dashed and dashShown >= Tutorial.minShow then
			dashTaught = true
			hide(roomPanel)
		else
			dashShown += dt
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
		moveShown = 0
		dashShown = 0
		dashed = false
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
	-- over the draft (100) and the skill bar (101), so nothing on the fight's
	-- screen covers the words (the tutorial has no boss banner, 102); under a
	-- NEW ENEMY! screen (103), which the room prompts wait behind anyway
	gui.DisplayOrder = 102
	gui.Parent = playerGui
	roomPanel = panel(gui, "RoomPrompt", 0.16)
	-- over the draft's own heading, clear of its cards
	levelPanel = panel(gui, "LevelPrompt", 0.012)
	local function refit()
		fit(roomPanel, 900)
		fit(levelPanel, 1000)
	end
	refit()
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
		end
		refit()
	end
	watchCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

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
