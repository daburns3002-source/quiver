--!strict
--[[
	The NEW ENEMY! screen (`Config/NewEnemies`; owner, 2026-10-25): the
	first time this player meets a kind of enemy, the server sends its kind
	(`Remotes.NewEnemy`) and holds the run; this shows the area's sheet with
	the enemy's picture, name and description on it, and GOT IT! closes it
	(`Remotes.NewEnemySeen`), which lets the server go on. Several kinds met
	at once are shown one after another.

	Built 1:1 from the owner's approved sheet: its two halves stacked, the
	sheet's own banner, plaque and button, and the live parts at the boxes
	measured off it. The whole thing is laid out in the sheet's pixels and
	scaled to the screen. The sheet drops in, and leaves upward.

	For a Studio capture, set the ScreenGui's `Preview` attribute to a kind
	(an `EnemyConfig.displayName`) to show its screen without the server.
	Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local RunPaused = require(script.Parent.Parent.RunPaused)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local NewEnemyScreen = {}

local FONT = Font.fromEnum(Enum.Font.Arcade)

type Parts = {
	gui: ScreenGui,
	shade: Frame,
	panel: Frame,
	top: ImageLabel,
	bottom: ImageLabel,
	picture: ImageLabel,
	name: TextLabel,
	nameStroke: UIStroke,
	description: TextLabel,
	button: TextButton,
}

local parts: Parts? = nil
--[[ Kinds waiting to be shown, the one showing first. ]]
local queue: { string } = {}
local shownAt = 0
--[[ When GOT IT! was pressed on the one showing, or nil while it is up. ]]
local leavingAt: number? = nil
--[[ Kinds the server sent, so closing their screen answers it (a Studio
     preview's does not). ]]
local fromServer: { [string]: boolean } = {}

-- eased in and out: a gentle overshoot as it lands, a small lift before it goes
local function outBack(x: number): number
	local c = NewEnemies.overshoot
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end

local function inBack(x: number): number
	local c = NewEnemies.overshoot
	return (c + 1) * x ^ 3 - c * x ^ 2
end

local function outQuad(x: number): number
	return 1 - (1 - x) ^ 2
end

local function place(item: GuiObject, box: NewEnemies.Box)
	local canvas = NewEnemies.canvas
	item.Position = UDim2.fromScale(box.x / canvas.X, box.y / canvas.Y)
	item.Size = UDim2.fromScale(box.w / canvas.X, box.h / canvas.Y)
end

local function text(name: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.Parent = parent
	return label
end

--[[ The largest size up to `most` at which `label`'s words fit its box: on
     one line, or wrapped. Measured, because TextScaled shrank them well
     below the sheet's own letters. ]]
local function fit(label: TextLabel, most: number, wrap: boolean)
	local box = label.AbsoluteSize
	local size = math.max(1, math.floor(most))
	while size > 1 do
		local params = Instance.new("GetTextBoundsParams")
		params.Text = label.Text
		params.Font = FONT
		params.Size = size
		params.Width = if wrap then box.X else math.huge
		local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
		if not ok or (bounds.X <= box.X and bounds.Y <= box.Y) then
			break
		end
		size -= 1
	end
	label.TextSize = size
end

local function build(playerGui: PlayerGui): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "NewEnemyScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	--[[ Over the HUD and the card screen (100, 101), as the boss banner
	     (102), which never shows with it: bosses have no screen. ]]
	gui.DisplayOrder = 103
	gui.Enabled = false

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.fromScale(1, NewEnemies.height)
	panel.BackgroundTransparency = 1
	panel.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = NewEnemies.canvas.X / NewEnemies.canvas.Y
	aspect.Parent = panel

	local function half(name: string, y: number): ImageLabel
		local image = Instance.new("ImageLabel")
		image.Name = name
		image.BackgroundTransparency = 1
		image.Position = UDim2.fromScale(0, y)
		image.Size = UDim2.fromScale(1, 0.5)
		image.Parent = panel
		return image
	end
	local top = half("Top", 0)
	local bottom = half("Bottom", 0.5)

	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Parent = panel

	local name = text("Name", panel)
	name.TextColor3 = Color3.new(1, 1, 1)
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = NewEnemies.ink
	nameStroke.LineJoinMode = Enum.LineJoinMode.Miter
	nameStroke.Parent = name

	local description = text("Description", panel)
	description.TextWrapped = true

	local button = Instance.new("TextButton")
	button.Name = "GotIt"
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = panel

	gui.Parent = playerGui
	return {
		gui = gui,
		shade = shade,
		panel = panel,
		top = top,
		bottom = bottom,
		picture = picture,
		name = name,
		nameStroke = nameStroke,
		description = description,
		button = button,
	}
end

--[[ The sheet for this stage's area, or the enemy's own in a stage that has
     no area (the courtyards, the Moonlit Arena). ]]
local function sheetFor(enemy: NewEnemies.Enemy): NewEnemies.Sheet
	local stage = Balance.Stages[Balance.stage]
	local area = stage and stage.area
	return (area and NewEnemies.sheets[area])
		or NewEnemies.sheets[enemy.area]
		or NewEnemies.sheets.MossyGlade
end

local function fill(p: Parts, kind: string)
	local enemy = NewEnemies.enemies[kind]
	local sheet = sheetFor(enemy)
	p.top.Image = sheet.top
	p.bottom.Image = sheet.bottom
	p.picture.Image = enemy.picture
	place(p.picture, sheet.picture)
	p.name.Text = enemy.name
	place(p.name, sheet.name)
	p.description.Text = enemy.description
	p.description.TextColor3 = sheet.text
	place(p.description, sheet.description)
	place(p.button, sheet.button)
end

--[[ Shows the next kind waiting, or puts the screen away. ]]
local function showNext(p: Parts)
	local kind = queue[1]
	if not kind then
		p.gui.Enabled = false
		RunPaused.setMeeting(false)
		return
	end
	fill(p, kind)
	shownAt = os.clock()
	leavingAt = nil
	p.gui.Enabled = true
	RunPaused.setMeeting(true)
end

local function enqueue(kind: string, server: boolean)
	if not NewEnemies.enemies[kind] then
		return
	end
	-- already waiting (a preview of it): the server's must still be answered
	if table.find(queue, kind) then
		fromServer[kind] = fromServer[kind] or server
		return
	end
	table.insert(queue, kind)
	fromServer[kind] = server
	local p = parts
	if p and #queue == 1 then
		showNext(p)
	end
end

local function gotIt()
	local kind = queue[1]
	if not kind or leavingAt or os.clock() - shownAt < NewEnemies.ready then
		return
	end
	leavingAt = os.clock()
	-- the upgrade cards' click (owner, 2026-10-25)
	SoundFx.play("card_click")
	if fromServer[kind] then
		Remotes.event(Remotes.NewEnemySeen):FireServer(kind)
	end
	fromServer[kind] = nil
end

--[[ The letters at the sheet's scale, refitted when the words or the
     screen's size change. ]]
local fitted = ""
local function size(p: Parts)
	local scale = p.panel.AbsoluteSize.Y / NewEnemies.canvas.Y
	local key = `{p.name.Text}|{p.panel.AbsoluteSize.Y}`
	if key == fitted then
		return
	end
	fitted = key
	p.nameStroke.Thickness = math.max(1, NewEnemies.inkWidth * scale)
	-- measuring can yield, so never inside the frame
	task.spawn(fit, p.name, NewEnemies.nameSize * scale, false)
	task.spawn(fit, p.description, NewEnemies.descriptionSize * scale, true)
end

--[[ Poses the sheet from the time since it appeared (and since GOT IT!). ]]
local function pose(p: Parts, now: number)
	size(p)

	local enter = math.clamp((now - shownAt) / NewEnemies.enter, 0, 1)
	local leave = if leavingAt then math.clamp((now - leavingAt) / NewEnemies.leave, 0, 1) else 0
	-- drops in from above the screen and settles; dips, then sweeps back up
	local y = -0.6 + 1.1 * outBack(enter) - 1.1 * inBack(leave)
	p.panel.Position = UDim2.fromScale(0.5, y)
	-- tilted as it falls, straight as it lands, tipping the other way as it goes
	p.panel.Rotation = NewEnemies.tilt * ((1 - outQuad(enter)) - leave ^ 2)
	p.shade.BackgroundTransparency = 1 - NewEnemies.shade * outQuad(enter) * (1 - outQuad(leave))

	if leavingAt and leave >= 1 then
		table.remove(queue, 1)
		showNext(p)
	end
end

function NewEnemyScreen.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("NewEnemyScreen")
	if existing then
		existing:Destroy()
	end
	local made = build(playerGui)
	parts = made

	made.button.Activated:Connect(gotIt)
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if not made.gui.Enabled then
			return
		end
		local key = input.KeyCode
		if
			key == Enum.KeyCode.ButtonA
			or key == Enum.KeyCode.Return
			or key == Enum.KeyCode.KeypadEnter
		then
			gotIt()
		end
	end)

	Remotes.event(Remotes.NewEnemy).OnClientEvent:Connect(function(kind: unknown)
		if type(kind) == "string" then
			enqueue(kind, true)
		end
	end)
	made.gui:GetAttributeChangedSignal("Preview"):Connect(function()
		local kind = made.gui:GetAttribute("Preview")
		if type(kind) == "string" and kind ~= "" then
			enqueue(kind, false)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if made.gui.Enabled then
			pose(made, os.clock())
		end
	end)
end

return NewEnemyScreen
