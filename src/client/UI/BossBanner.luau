--!strict
--[[
	The banner that comes up as the player walks into a boss room, over the
	boss music's battle intro, like a trainer battle's flash (`Config/
	BossBanners`; the owner's pick, style A "Slash", 2026-10-24).

	A white flash over a dark ground in the boss's colour that hides the
	arena (owner, 2026-10-24: "i dont want the arena to be seen when the
	animation is playing"); a slanted band in the boss's deep colour tears across
	from the left with speed lines running through it; the boss's icon
	rushes in from the right and plays its attack (a 2x2 sheet of frames,
	shaking on each strike); the name slams down, a BOSS tag pops and the
	boss's title fades in under it. Then it all leaves to the sides and the
	ground fades, showing the arena. Until then the player is held still
	(`RunPaused.setIntro`), as the server holds the world.

	One RenderStepped loop poses every piece from the time since the banner
	appeared (as `UI/EndScreenMotion` does), so it can be frozen at any
	moment for a Studio capture (`Preview` and `HoldAt`, below). Starts on `Fx/BossWatch`, the
	same tick as the music's intro. Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossBanners = require(ReplicatedStorage.Shared.Config.BossBanners)

local BossWatch = require(script.Parent.Parent.Fx.BossWatch)
local RunPaused = require(script.Parent.Parent.RunPaused)

local BossBanner = {}

local TAG_COLOUR = Color3.fromRGB(255, 210, 63)
local TAG_TEXT = Color3.fromRGB(42, 28, 0)
local INK = Color3.fromRGB(16, 14, 10)
local NAME_FONT = Font.fromEnum(Enum.Font.Arcade)
local TAG_FONT = Font.fromEnum(Enum.Font.Arcade)
local SUB_FONT = Font.fromEnum(Enum.Font.Arcade)
local LINES = 9

type Parts = {
	gui: ScreenGui,
	ground: Frame,
	flash: Frame,
	band: Frame,
	edges: { Frame },
	lines: { Frame },
	icon: ImageLabel,
	words: Frame,
	tag: TextLabel,
	tagScale: UIScale,
	name: TextLabel,
	nameScale: UIScale,
	nameStroke: UIStroke,
	sub: TextLabel,
}

local parts: Parts? = nil
local shown: BossBanners.Banner? = nil
local startedAt = 0
local held: number? = nil

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

-- 0 → 1 between `from` and `to` seconds.
local function span(t: number, from: number, to: number): number
	return clamp01((t - from) / (to - from))
end

local function outCubic(x: number): number
	return 1 - (1 - x) ^ 3
end

local function inCubic(x: number): number
	return x ^ 3
end

local function outBack(x: number): number
	local c = 1.9
	return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2
end

local function label(name: string, font: Font, colour: Color3, parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.FontFace = font
	text.TextColor3 = colour
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = parent
	return text
end

local function build(playerGui: PlayerGui): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	--[[ Over the whole HUD (the skill bar is 101, the card screen 100): for
	     its 4.7 s nothing of the room shows. ]]
	gui.DisplayOrder = 102
	gui.Enabled = false

	--[[ Covers the arena: the boss's deep colour, darkening to the edges. ]]
	local ground = Instance.new("Frame")
	ground.Name = "Ground"
	ground.Size = UDim2.fromScale(1, 1)
	ground.BorderSizePixel = 0
	ground.BackgroundColor3 = Color3.new(1, 1, 1)
	ground.Parent = gui
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Parent = ground

	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.BorderSizePixel = 0
	band.Parent = gui

	local edges = {}
	for i = 1, 2 do
		local edge = Instance.new("Frame")
		edge.Name = "Edge"
		edge.BorderSizePixel = 0
		edge.Size = UDim2.fromScale(1, 0.07)
		edge.Position = UDim2.fromScale(0, if i == 1 then 0 else 0.93)
		edge.Parent = band
		table.insert(edges, edge)
	end

	local lines = {}
	for i = 1, LINES do
		local line = Instance.new("Frame")
		line.Name = "SpeedLine"
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BackgroundTransparency = 0.82
		line.Size = UDim2.fromScale(0.05 + (i % 3) * 0.03, 0.035)
		line.Parent = band
		table.insert(lines, line)
	end

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = gui

	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Parent = gui

	local tag = label("Tag", TAG_FONT, TAG_TEXT, words)
	tag.Text = "BOSS"
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.BackgroundTransparency = 0
	tag.BackgroundColor3 = TAG_COLOUR
	tag.BorderSizePixel = 0
	tag.Rotation = -4
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	local tagPad = Instance.new("UIPadding")
	tagPad.PaddingTop = UDim.new(0.12, 0)
	tagPad.PaddingBottom = UDim.new(0.12, 0)
	tagPad.Parent = tag
	local tagScale = Instance.new("UIScale")
	tagScale.Parent = tag

	local name = label("Name", NAME_FONT, Color3.new(1, 1, 1), words)
	name.AnchorPoint = Vector2.new(0, 0.5)
	local nameScale = Instance.new("UIScale")
	nameScale.Parent = name
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = INK
	nameStroke.Thickness = 3
	nameStroke.Parent = name

	local sub = label("Subtitle", SUB_FONT, Color3.fromRGB(235, 240, 230), words)

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	flash.Parent = gui

	gui.Parent = playerGui
	return {
		gui = gui,
		ground = ground,
		flash = flash,
		band = band,
		edges = edges,
		lines = lines,
		icon = icon,
		words = words,
		tag = tag,
		tagScale = tagScale,
		name = name,
		nameScale = nameScale,
		nameStroke = nameStroke,
		sub = sub,
	}
end

local function frameAt(t: number): (number, number)
	local frame, since = 1, 0
	for _, step in BossBanners.frames do
		if t >= step.at then
			frame, since = step.frame, t - step.at
		end
	end
	return frame, since
end

-- Every piece, for `t` seconds after the banner appeared.
local function pose(p: Parts, banner: BossBanners.Banner, t: number)
	local size = p.gui.AbsoluteSize
	local upright = size.Y > size.X

	p.flash.BackgroundTransparency = if t < 0.06 then 1 - t / 0.06 else span(t, 0.06, 0.5)

	-- the ground: there from the first frame (under the flash), gone as the band leaves
	local rim = banner.deep:Lerp(Color3.new(0, 0, 0), 0.75)
	local middle = banner.deep:Lerp(Color3.new(0, 0, 0), 0.35)
	local shade = p.ground:FindFirstChildOfClass("UIGradient") :: UIGradient
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rim),
		ColorSequenceKeypoint.new(0.5, middle),
		ColorSequenceKeypoint.new(1, rim),
	})
	p.ground.BackgroundTransparency = span(t, 4.35, 4.7)

	-- the band: in from the left, out to the right
	local bandIn = outCubic(span(t, 0.12, 0.44))
	local bandOut = inCubic(span(t, 4.25, 4.6))
	p.band.BackgroundColor3 = banner.deep
	p.band.Rotation = if upright then -5 else -7
	p.band.Size = UDim2.fromScale(1.5, if upright then 0.5 else 0.4)
	p.band.Position = UDim2.fromScale(-1 + 1.5 * bandIn + 1.5 * bandOut, 0.5)
	p.band.Visible = bandIn > 0 and bandOut < 1
	for _, edge in p.edges do
		edge.BackgroundColor3 = banner.tint
	end
	for i, line in p.lines do
		local x = ((i * 0.37) - t * (1.2 + (i % 4) * 0.25)) % 1
		line.Position = UDim2.fromScale(x, 0.12 + (i - 1) / (LINES - 1) * 0.76)
	end

	-- the icon: rushes in from the right, plays its attack, leaves left
	local iconIn = outBack(span(t, 0.35, 0.85))
	local iconOut = inCubic(span(t, 4.2, 4.5))
	local frame, since = frameAt(t)
	local grid, cell = BossBanners.sheet.grid, BossBanners.sheet.cell
	p.icon.Image = banner.icon
	p.icon.Visible = banner.icon ~= "" and t >= 0.35 and iconOut < 1
	p.icon.ImageRectSize = Vector2.new(cell, cell)
	p.icon.ImageRectOffset = Vector2.new(((frame - 1) % grid) * cell, (frame - 1) // grid * cell)
	local shake = 0
	if frame == 3 and since < BossBanners.shake.time then
		shake = BossBanners.shake.size * (1 - since / BossBanners.shake.time) * math.sin(since * 90)
	end
	local height = if upright then 0.32 else 0.6
	p.icon.Size = UDim2.fromScale(height, height)
	if upright then
		p.icon.AnchorPoint = Vector2.new(0.5, 0)
		p.icon.Position =
			UDim2.fromScale(1.6 - 1.1 * iconIn - 1.2 * iconOut + shake, 0.24 + shake * 0.5)
	else
		p.icon.AnchorPoint = Vector2.new(0, 0.5)
		p.icon.Position =
			UDim2.fromScale(1.2 - 1.12 * iconIn - 0.9 * iconOut + shake, 0.47 + shake * 0.5)
	end

	-- the words: the name slams down, the tag pops, the title fades in
	local gone = span(t, 4.25, 4.5)
	if upright then
		p.words.Position = UDim2.fromScale(0.08, 0.58)
		p.words.Size = UDim2.fromScale(0.84, 0.17)
	else
		p.words.Position = UDim2.fromScale(0.42, 0.34)
		p.words.Size = UDim2.fromScale(0.52, 0.3)
	end
	p.tag.Size = UDim2.fromScale(0.2, 0.2)
	p.tag.Position = UDim2.fromScale(0.1, 0.08)
	p.tagScale.Scale = outBack(span(t, 0.9, 1.2))
	p.tag.TextTransparency = gone
	p.tag.BackgroundTransparency = gone

	local slam = span(t, 0.65, 0.93)
	p.name.Text = banner.name
	p.name.Size = UDim2.fromScale(1, 0.45)
	p.name.Position = UDim2.fromScale(0, 0.45)
	p.nameScale.Scale = 2.4 - 1.4 * (slam ^ 2)
	p.name.TextTransparency = math.max(1 - slam / 0.7, gone)
	p.nameStroke.Transparency = math.max(1 - slam / 0.7, gone)

	p.sub.Text = banner.subtitle
	p.sub.Size = UDim2.fromScale(1, 0.16)
	p.sub.Position = UDim2.fromScale(0, 0.72)
	p.sub.TextTransparency = math.max(1 - span(t, 1.1, 1.5) * 0.9, gone)
end

local function show(title: string?)
	local banner = if title then BossBanners.bosses[title] else nil
	shown = banner
	startedAt = os.clock()
	if parts then
		parts.gui.Enabled = banner ~= nil
	end
	RunPaused.setIntro(banner ~= nil)
end

--[[ For a Studio capture (a probe cannot reach this module's state, only
     the DataModel): set the ScreenGui's `Preview` attribute to a boss's
     title to play its banner, and `HoldAt` to freeze it at that second;
     clear `HoldAt` to let it run. ]]
local function watchPreview(gui: ScreenGui)
	gui:GetAttributeChangedSignal("Preview"):Connect(function()
		local title = gui:GetAttribute("Preview")
		if type(title) == "string" and title ~= "" then
			show(title)
		end
	end)
	gui:GetAttributeChangedSignal("HoldAt"):Connect(function()
		local at = gui:GetAttribute("HoldAt")
		held = if type(at) == "number" then at else nil
	end)
end

function BossBanner.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("BossBanner")
	if existing then
		existing:Destroy()
	end
	local made = build(playerGui)
	parts = made
	watchPreview(made.gui)

	BossWatch.onChange(show)
	BossWatch.start()

	RunService.RenderStepped:Connect(function()
		local banner = shown
		if not banner then
			return
		end
		local t = held or (os.clock() - startedAt)
		if t >= BossBanners.duration then
			shown = nil
			made.gui.Enabled = false
			RunPaused.setIntro(false)
			return
		end
		pose(made, banner, t)
	end)
end

return BossBanner
