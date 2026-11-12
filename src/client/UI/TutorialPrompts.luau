--!strict
--[[
	The tutorial's prompts (`Config/Tutorial.prompts`), shown only while the
	stage is the tutorial (`Balance.tutorialStage`). Redone 2026-11-11 (owner:
	"highlight the important words and have the tutorial clearly explain the
	controls and have the music quiet down when there is something on the
	screen to read"):

	- One idea per prompt, in the words for the device in hand (keys, touch
	  or a gamepad): moving, that standing still shoots, the crystals, the
	  dash, the gate out of a cleared room, and, over the first upgrade hand,
	  picking a card. Which shows when is `Util/TutorialSteps`.
	- The control and the action in each are drawn in their own strong colours
	  (`Util/PromptText`), chosen for the ground they are read on.
	- The music ducks while a prompt is up, and under a NEW ENEMY! screen in
	  the tutorial (`MusicFx.setReading`), and comes back after.

	The room prompts wait behind anything that pauses the run (a NEW ENEMY!
	screen, a draft), so they never sit over a screen asking for a press.
	In the chunky UI's style, from its palette (`UI/Chunky`) so a re-skin
	carries over: the panel, an outlined header band striped in the header's
	two colours with the heading in it, and the words under it, sized from the
	screen so a phone held upright reads them as easily as a computer. Each
	new prompt pops in (`Chunky.pop`). Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local PromptText = require(ReplicatedStorage.Shared.Util.PromptText)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local TutorialSteps = require(ReplicatedStorage.Shared.Util.TutorialSteps)

local Chunky = require(script.Parent.Chunky)
local Dash = require(script.Parent.Parent.Input.Dash)
local Device = require(script.Parent.Parent.Device)
local MusicFx = require(script.Parent.Parent.Fx.MusicFx)
local RunPaused = require(script.Parent.Parent.RunPaused)

local TutorialPrompts = {}

--[[ The chunky palette's newer names (the cream re-skin's dark-brown edge
     and its orange header), with what stands in until it has them. ]]
local skin = Chunky :: any
local EDGE: Color3 = skin.edge or Chunky.navy
local HEADER_TOP: Color3 = skin.headerTop or Color3.fromRGB(255, 164, 52)
local HEADER_BOTTOM: Color3 = skin.headerBottom or Color3.fromRGB(240, 116, 24)
--[[ A header band's stripes: each this share of the band's height wide, a
     stripe apart, leaning this many degrees from upright. They are frames
     in a CanvasGroup, which clips turned children to its rounded corners; a
     turned UIGradient bunched its stripes into the middle of a wide band
     (`docs/FIXES.md`). ]]
local STRIPE = 0.42
local SLANT = 20

type Panel = {
	group: Frame,
	header: Frame,
	band: CanvasGroup,
	title: TextLabel,
	body: TextLabel,
	titleStroke: UIStroke,
	bodyStroke: UIStroke,
	outline: UIStroke,
	headerOutline: UIStroke,
	corner: UICorner,
	headerCorner: UICorner,
	bandCorner: UICorner,
	padding: UIPadding,
	gap: UIListLayout,
	--[[ What it is showing, so the same prompt does not pop in every frame. ]]
	showing: string?,
}

local roomPanel: Panel? = nil
local cardPanel: Panel? = nil

--[[ Where the run is, and what the player has done so far
     (`Util/TutorialSteps`). ]]
local steps = TutorialSteps.new()
local room = 0
local fighting = false
local cleared = false
local over = false
local lastPosition: Vector3? = nil
local cardShowing = false

local function inTutorial(): boolean
	return CurrentStage.index() == Balance.tutorialStage
end

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

--[[ The colours the words are written in, for the panel as it is skinned:
     the palette's ink on a light panel, white on a dark one. ]]
local function palette(): PromptText.Palette
	local chosen = PromptText.palette(Chunky.panelBottom)
	local light = PromptText.isLight(Chunky.panelBottom)
	return {
		words = if light then Chunky.ink else Chunky.white,
		control = chosen.control,
		action = chosen.action,
	}
end

--[[ Lays a band's leaning stripes for its size: the second header colour
     over the first, from past its left end to past its right. ]]
local function layStripes(band: CanvasGroup, width: number, height: number)
	for _, child in band:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local stripe = math.max(8, math.floor(height * STRIPE))
	for i = 0, math.ceil(width / (stripe * 2)) + 1 do
		local bar = Instance.new("Frame")
		bar.Name = "Stripe"
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.BackgroundColor3 = HEADER_BOTTOM
		bar.BorderSizePixel = 0
		bar.Rotation = SLANT
		bar.Size = UDim2.fromOffset(stripe, math.ceil(height * 2.2))
		bar.Position = UDim2.new(0, i * stripe * 2 - stripe, 0.5, 0)
		bar.Parent = band
	end
end

local function label(parent: Instance, name: string, order: number): (TextLabel, UIStroke)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = Chunky.font
	t.RichText = true
	t.TextWrapped = true
	t.Size = UDim2.fromScale(1, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.LayoutOrder = order
	t.ZIndex = 5
	t.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = EDGE
	stroke.Parent = t
	return t, stroke
end

--[[ A prompt's panel: the chunky panel lit from the top with a thick edge,
     a striped header band holding the heading, and the words under it. It
     grows to fit its words, which are sized from the screen (`fit`). ]]
local function panel(gui: Instance, name: string, y: number): Panel
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
	outline.Color = EDGE
	outline.Parent = group

	local content = Instance.new("Frame")
	content.Name = "Words"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.ZIndex = 3
	content.Parent = group
	local padding = Instance.new("UIPadding")
	padding.Parent = content
	local gap = Instance.new("UIListLayout")
	gap.SortOrder = Enum.SortOrder.LayoutOrder
	gap.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gap.Parent = content

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.BorderSizePixel = 0
	header.LayoutOrder = 1
	header.ZIndex = 4
	header.Parent = content
	local headerCorner = Instance.new("UICorner")
	headerCorner.Parent = header
	local headerOutline = Instance.new("UIStroke")
	headerOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerOutline.LineJoinMode = Enum.LineJoinMode.Round
	headerOutline.Color = EDGE
	headerOutline.Parent = header
	local band = Instance.new("CanvasGroup")
	band.Name = "Band"
	band.BackgroundColor3 = HEADER_TOP
	band.BorderSizePixel = 0
	band.Size = UDim2.fromScale(1, 1)
	band.ZIndex = 4
	band.Parent = header
	local bandCorner = Instance.new("UICorner")
	bandCorner.Parent = band
	local title, titleStroke = label(header, "Title", 1)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.Size = UDim2.fromScale(1, 1)
	title.TextWrapped = false
	title.TextColor3 = Chunky.white

	local body, bodyStroke = label(content, "Body", 2)
	return {
		group = group,
		header = header,
		band = band,
		title = title,
		body = body,
		titleStroke = titleStroke,
		bodyStroke = bodyStroke,
		outline = outline,
		headerOutline = headerOutline,
		corner = corner,
		headerCorner = headerCorner,
		bandCorner = bandCorner,
		padding = padding,
		gap = gap,
		showing = nil,
	}
end

--[[ Sizes a panel and its words for this screen: big enough to read at a
     glance on a computer, and on a phone held either way. ]]
local function fit(p: Panel?, maxWidth: number, view: Vector2, phone: boolean)
	if not p then
		return
	end
	local short = math.min(view.X, view.Y)
	local bodySize = math.floor(math.clamp(short * (if phone then 0.052 else 0.042), 20, 36))
	local titleSize = math.floor(math.clamp(short * 0.06, 26, 50))
	local width = math.min(view.X * (if phone then 0.94 else 0.62), maxWidth)
	p.group.Size = UDim2.fromOffset(width, 0)
	p.title.TextSize = titleSize
	p.body.TextSize = bodySize
	p.titleStroke.Thickness = math.max(2, titleSize * 0.12)
	-- dark words on a light panel need no outline; white ones on a dark one do
	p.bodyStroke.Thickness = if PromptText.isLight(Chunky.panelBottom)
		then 0
		else math.max(2, bodySize * 0.11)
	local edge = math.max(3, math.floor(short * 0.006))
	p.outline.Thickness = edge
	p.headerOutline.Thickness = math.max(2, edge - 1)
	p.corner.CornerRadius = UDim.new(0, edge * 4)
	p.headerCorner.CornerRadius = UDim.new(0, edge * 3)
	p.bandCorner.CornerRadius = UDim.new(0, edge * 3)
	local bandHeight = math.floor(titleSize * 1.5)
	p.header.Size = UDim2.new(1, 0, 0, bandHeight)
	local pad = math.floor(bodySize * 0.6)
	layStripes(p.band, width - pad * 2, bandHeight)
	p.padding.PaddingLeft = UDim.new(0, pad)
	p.padding.PaddingRight = UDim.new(0, pad)
	p.padding.PaddingTop = UDim.new(0, pad)
	p.padding.PaddingBottom = UDim.new(0, math.floor(pad * 1.1))
	p.gap.Padding = UDim.new(0, math.floor(bodySize * 0.45))
end

--[[ A prompt's words for this device's own controls. ]]
local function forDevice(words: Tutorial.Prompt): string
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

local function show(p: Panel?, id: string, device: string?)
	local words = Tutorial.prompts[id]
	if not p or not words then
		return
	end
	local colours = palette()
	p.title.Text = words.title
	p.body.TextColor3 = colours.words
	p.body.Text =
		PromptText.rich(if device then (words :: any)[device] else forDevice(words), colours)
	p.group.Visible = true
	if p.showing ~= id then
		p.showing = id
		Chunky.pop(p.group)
	end
end

local function hide(p: Panel?)
	if p then
		p.group.Visible = false
		p.showing = nil
	end
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

--[[ Studs walked along the floor since the last frame. ]]
local function walkedSince(): number
	local at = rootPosition()
	local was = lastPosition
	lastPosition = at
	if not at or not was then
		return 0
	end
	return (Vector3.new(at.X, 0, at.Z) - Vector3.new(was.X, 0, was.Z)).Magnitude
end

local newEnemy: ScreenGui? = nil
--[[ Whether a NEW ENEMY! screen is up (`UI/NewEnemyScreen`): something to
     read, so the music ducks under it in the tutorial too. ]]
local function meeting(): boolean
	local gui = newEnemy
	if not gui or not gui.Parent then
		local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local found = playerGui and playerGui:FindFirstChild("NewEnemyScreen")
		gui = if found and found:IsA("ScreenGui") then found else nil
		newEnemy = gui
	end
	return gui ~= nil and gui.Enabled
end

local function step(dt: number)
	if not inTutorial() then
		hide(roomPanel)
		hide(cardPanel)
		MusicFx.setReading(false)
		return
	end
	local paused = RunPaused.get() or over
	if paused then
		-- a walk is not measured across a hold
		lastPosition = nil
	end
	local id = TutorialSteps.step(steps, {
		room = room,
		fighting = fighting,
		cleared = cleared,
		paused = paused,
		walked = if paused then 0 else walkedSince(),
		dashing = Dash.isDashing(os.clock()),
	}, dt, Tutorial)
	if id then
		show(roomPanel, id)
	else
		hide(roomPanel)
	end
	MusicFx.setReading(id ~= nil or cardShowing or meeting())
end

--[[ The run's state, as `Remotes.RunStateChanged` tells it. A new tutorial
     teaches again from the start. ]]
function TutorialPrompts.onRunStateChanged(index: number, _total: number, state: string)
	over = state == "Complete" or state == "Dead"
	if state == "Lobby" then
		room = 0
		fighting = false
		cleared = false
		return
	end
	if index == 1 and state == "Fighting" and room ~= 1 then
		steps = TutorialSteps.new()
		lastPosition = nil
	end
	room = index
	fighting = state == "Fighting"
	cleared = state == "Cleared"
end

--[[ An upgrade hand opened: the first in the tutorial says how to pick a
     card, until one is picked. ]]
function TutorialPrompts.onOffer()
	if not inTutorial() or not TutorialSteps.offer(steps) then
		return
	end
	cardShowing = true
	show(cardPanel, "card")
end

--[[ One prompt, built inside `parent` and sized as if `parent` were the
     screen (a phone's when `phone`), in the words for `device`: for looking
     at a phone's layout in Studio, which cannot emulate one over MCP. Runs
     nothing; the caller destroys what it returns. `parent`'s ScreenGui
     must be in sibling order (`ZIndexBehavior`), as this one's is. ]]
function TutorialPrompts.preview(
	parent: GuiObject,
	id: string,
	device: string,
	phone: boolean
): Frame
	local p = panel(parent, "Preview_" .. id, 0.16)
	fit(p, 900, parent.AbsoluteSize, phone)
	show(p, id, device)
	return p.group
end

function TutorialPrompts.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialPrompts"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- sibling order: a header's CanvasGroup only clips its stripes in it
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over the draft (100) and the skill bar (101), so nothing on the fight's
	-- screen covers the words (the tutorial has no boss banner, 102); under a
	-- NEW ENEMY! screen (103), which the room prompts wait behind anyway
	gui.DisplayOrder = 102
	gui.Parent = playerGui
	roomPanel = panel(gui, "RoomPrompt", 0.16)
	-- over the draft's own heading, clear of its cards
	cardPanel = panel(gui, "CardPrompt", 0.012)
	local function refit()
		fit(roomPanel, 900, viewport(), Device.isPhone())
		fit(cardPanel, 1000, viewport(), Device.isPhone())
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
		if not paused and cardShowing then
			cardShowing = false
			hide(cardPanel)
		end
	end)
	Workspace:GetAttributeChangedSignal(CurrentStage.ATTRIBUTE):Connect(function()
		if not inTutorial() then
			hide(cardPanel)
			cardShowing = false
		end
	end)
	-- a crystal on the floor: the crystals prompt has something to point at
	Remotes.event(Remotes.PickupDropped).OnClientEvent:Connect(function(_id, kind)
		if kind == "Crystal" and inTutorial() then
			TutorialSteps.sawCrystal(steps)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return TutorialPrompts
