--!strict
--[[
	The Victory and Defeat screens, from the owner's design
	(design_handoff_end_screens). Built at the design's 540 × 624 and
	scaled as a whole: 85% of the screen's height, or the screen's width on
	a phone held upright.

	Presentation only. The server decides that the run is over, whether it
	was won, and every number shown; the button only asks it for the next
	run, and the server ignores that unless the run has ended.

	The motion lives in `EndScreenMotion`, posed from the timeline in
	`Config/EndScreenTimeline`. A tap anywhere jumps to the end of it; the
	button only takes a press once its own entrance has finished.

	Not shown yet, by the owner's choice: the REWARDS box (there are no coins
	or gems until the meta loop) and HOME (there is no lobby). The stats
	panel closes up where the rewards would sit, and the button moves up
	with it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local EndScreenAssets = require(ReplicatedStorage.Shared.Config.EndScreenAssets)
local EndScreenLayout = require(ReplicatedStorage.Shared.Config.EndScreenLayout)
local EndScreenTheme = require(ReplicatedStorage.Shared.Config.EndScreenTheme)

local EndScreenMotion = require(script.Parent.EndScreenMotion)

local EndScreen = {}

export type Summary = {
	won: boolean,
	stage: number,
	kills: number,
	seconds: number,
	healthPercent: number,
	progressPercent: number,
}

type Stops = ColorSequence
type Box = { x: number, y: number, w: number, h: number }

local Theme = EndScreenTheme
local Layout = EndScreenLayout
local INK = Theme.ink
local WHITE = Theme.white
local DISPLAY = Theme.fonts.display
local BODY = Theme.fonts.body

--[[ Share of the screen's height the panel fills, and of its width when the
     width is the tighter fit. ]]
local HEIGHT_SHARE = 0.85
local WIDTH_SHARE = 0.94

local gui: ScreenGui? = nil
local scaler: UIScale? = nil
local panelHeight = Theme.panelSize.Y
local viewportConnection: RBXScriptConnection? = nil
local inputConnection: RBXScriptConnection? = nil
local motion: EndScreenMotion.Motion? = nil
local onRestart: (() -> ())? = nil

--[[ A top-to-bottom gradient over `target`, which is drawn white so the
     gradient's colours come through unchanged. ]]
local function gradient(target: GuiObject, stops: Stops)
	local g = Instance.new("UIGradient")
	g.Color = stops
	g.Rotation = 90
	g.Parent = target
end

local function frame(parent: Instance, name: string, b: Box, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = UDim2.fromOffset(b.x, b.y)
	f.Size = UDim2.fromOffset(b.w, b.h)
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function outline(parent: Instance, colour: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
end

local function image(parent: Instance, name: string, b: Box, z: number, asset: string): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.Position = UDim2.fromOffset(b.x, b.y)
	i.Size = UDim2.fromOffset(b.w, b.h)
	i.BackgroundTransparency = 1
	i.Image = asset
	i.ScaleType = Enum.ScaleType.Fit
	i.ZIndex = z
	i.Parent = parent
	return i
end

--[[
	Stroked type. `cssStroke` is the design's text-stroke width; half of it
	shows outside the glyph, so that is the UIStroke drawn.
]]
local function text(
	parent: Instance,
	name: string,
	b: Box,
	z: number,
	content: string,
	font: Enum.Font,
	size: number,
	colour: Color3,
	cssStroke: number
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Position = UDim2.fromOffset(b.x, b.y)
	t.Size = UDim2.fromOffset(b.w, b.h)
	t.BackgroundTransparency = 1
	t.Font = font
	t.Text = content
	t.TextSize = size
	t.TextColor3 = colour
	t.ZIndex = z
	t.Parent = parent
	if cssStroke > 0 then
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = cssStroke / 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = t
	end
	return t
end

local function width(content: string, font: Enum.Font, size: number): number
	return TextService:GetTextSize(content, size, font, Vector2.new(2000, 200)).X
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", s // 60, s % 60)
end

--[[ A hard drop shadow: the same rounded box in ink, `drop` lower. ]]
local function shadow(parent: Instance, b: Box, z: number, radius: number, drop: number)
	local s = frame(parent, "Shadow", { x = b.x, y = b.y + drop, w = b.w, h = b.h }, z)
	s.BackgroundColor3 = INK
	s.BackgroundTransparency = 0
	corner(s, radius)
end

--[[ Re-anchors `obj` on its own centre without moving it, and gives it a
     UIScale, so the motion can pop, drop and turn it about its middle. ]]
local function pivot(obj: GuiObject): UIScale
	local size = obj.Size
	obj.AnchorPoint = Vector2.new(0.5, 0.5)
	obj.Position = obj.Position + UDim2.fromOffset(size.X.Offset / 2, size.Y.Offset / 2)
	local scale = Instance.new("UIScale")
	scale.Parent = obj
	return scale
end

--[[ A white shape image tinted by a gradient, with an ink copy behind it
     `pad` larger all round: how the design outlines its ribbon pieces. ]]
local function shape(
	parent: Instance,
	name: string,
	asset: string,
	inkBox: Box,
	fillBox: Box,
	z: number,
	stops: Stops
)
	local back = image(parent, name .. "Ink", inkBox, z, asset)
	back.ScaleType = Enum.ScaleType.Stretch
	back.ImageColor3 = INK
	local front = image(parent, name, fillBox, z + 1, asset)
	front.ScaleType = Enum.ScaleType.Stretch
	gradient(front, stops)
end

local function buildRibbon(parent: Instance, look: any, won: boolean): (Frame, Frame)
	local b = Layout.banner
	local ribbon = frame(parent, "Ribbon", b, 20)

	shape(ribbon, "TailLeft", EndScreenAssets.tailLeft, { x = 0, y = 34, w = 90, h = 54 }, {
		x = 4,
		y = 38,
		w = 84,
		h = 46,
	}, 20, look.tails)
	shape(
		ribbon,
		"TailRight",
		EndScreenAssets.tailRight,
		{ x = b.w - 90, y = 34, w = 90, h = 54 },
		{
			x = b.w - 88,
			y = 38,
			w = 84,
			h = 46,
		},
		20,
		look.tails
	)
	shape(ribbon, "Band", EndScreenAssets.band, { x = 52, y = 4, w = b.w - 104, h = 80 }, {
		x = 57,
		y = 9,
		w = b.w - 114,
		h = 70,
	}, 22, look.band)

	-- The title, with a 5 px ink drop behind it.
	local titleBox = { x = 57, y = 9, w = b.w - 114, h = 70 }
	local drop = text(
		ribbon,
		"TitleDrop",
		{ x = titleBox.x, y = titleBox.y + 5, w = titleBox.w, h = titleBox.h },
		24,
		look.titleText,
		DISPLAY,
		Theme.text.banner,
		INK,
		Theme.text.bannerStroke
	)
	drop.TextTransparency = 0
	text(
		ribbon,
		"Title",
		titleBox,
		25,
		look.titleText,
		DISPLAY,
		Theme.text.banner,
		look.title,
		Theme.text.bannerStroke
	)

	-- The sub-ribbon, a trapezoid over the band's lower edge.
	local sb = if won then Layout.sub else Layout.subDefeat
	local sub = frame(parent, "SubRibbon", sb, 26)
	shape(sub, "Sub", EndScreenAssets.trapezoid, { x = 0, y = 0, w = sb.w, h = sb.h }, {
		x = 5,
		y = 4,
		w = sb.w - 10,
		h = sb.h - 8,
	}, 26, look.sub)
	text(
		sub,
		"Text",
		{ x = 0, y = 2, w = sb.w, h = sb.h },
		28,
		look.subText,
		DISPLAY,
		if won then Theme.text.sub else Theme.text.subDefeat,
		WHITE,
		Theme.text.subStroke
	)

	pivot(ribbon)
	pivot(sub)
	return ribbon, sub
end

local function buildHero(parent: Instance, look: any, won: boolean): CanvasGroup
	if won then
		local rays = image(parent, "Rays", Layout.rays, 3, CardAssets.rays)
		rays.ImageColor3 = look.rays
		rays.ImageTransparency = look.raysTransparency
		pivot(rays)
		local glow = image(
			parent,
			"Glow",
			{ x = 270 - 190, y = 196 - 190, w = 380, h = 380 },
			4,
			CardAssets.glow
		)
		pivot(glow)
		glow.ImageColor3 = look.glow
		glow.ImageTransparency = 0.25
	else
		local glow = image(
			parent,
			"Glow",
			{ x = 270 - 210, y = 196 - 150, w = 420, h = 300 },
			4,
			CardAssets.glow
		)
		glow.ScaleType = Enum.ScaleType.Stretch
		glow.ImageColor3 = look.glow
		glow.ImageTransparency = 0
		pivot(glow)
	end

	--[[ The art in a CanvasGroup, so its bottom edge can be faded as well as
	     its sides: the art was cut from the reference without its edges
	     quite faded out (alpha ~0.3 at mid-edge), which drew a pale box
	     round it, and the bottom shows while the stats panel slides in. ]]
	local box = if won then Layout.heroVictory else Layout.heroDefeat
	local hero = Instance.new("CanvasGroup")
	hero.Name = "Hero"
	hero.Position = UDim2.fromOffset(box.x, box.y)
	hero.Size = UDim2.fromOffset(box.w, box.h)
	hero.BackgroundTransparency = 1
	hero.ZIndex = 6
	hero.Parent = parent
	local down = Instance.new("UIGradient")
	down.Rotation = 90
	down.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.82, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	down.Parent = hero

	local art = image(
		hero,
		"Art",
		{ x = 0, y = 0, w = box.w, h = box.h },
		6,
		if won then EndScreenAssets.victoryHero else EndScreenAssets.defeatHero
	)
	local feather = Instance.new("UIGradient")
	feather.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0),
		NumberSequenceKeypoint.new(0.88, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	feather.Parent = art

	pivot(hero)
	return hero
end

local function row(
	panel: Instance,
	index: number,
	icon: string,
	label: string,
	value: string
): Frame
	local origin = Layout.rowsOrigin
	local r = frame(panel, "Row" .. index, {
		x = origin.X,
		y = origin.Y + (index - 1) * (Theme.row.height + Theme.row.gap),
		w = Layout.rowWidth,
		h = Theme.row.height,
	}, 33)
	r.BackgroundColor3 = Theme.row.fill
	r.BackgroundTransparency = 0
	corner(r, Theme.row.corner)
	outline(r, Theme.row.border, 2)

	image(r, "Icon", { x = 6, y = 2, w = 26, h = 26 }, 34, icon)
	local l = text(
		r,
		"Label",
		{ x = 40, y = 0, w = 220, h = Theme.row.height },
		34,
		label,
		BODY,
		Theme.text.rowLabel,
		WHITE,
		0
	)
	l.TextXAlignment = Enum.TextXAlignment.Left
	local v = text(
		r,
		"Value",
		{ x = Layout.rowWidth - 152, y = 1, w = 140, h = Theme.row.height },
		34,
		value,
		DISPLAY,
		Theme.text.rowValue,
		WHITE,
		Theme.text.rowValueStroke
	)
	v.TextXAlignment = Enum.TextXAlignment.Right
	return r
end

--[[ Defeat's third row: a label, a bar and a percentage. ]]
local function progressRow(panel: Instance, index: number, percent: number): Frame
	local r = row(panel, index, EndScreenAssets.chart, "", string.format("%d%%", percent))
	local l = r:FindFirstChild("Label") :: TextLabel
	l.Font = DISPLAY
	l.TextSize = Theme.text.rowLabelSmall
	l.Text = "LEVEL PROGRESS"
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = 1
	s.Parent = l

	local barX = 40 + width("LEVEL PROGRESS", DISPLAY, Theme.text.rowLabelSmall) + 12
	local barW = Layout.rowWidth - barX - 64
	local track = frame(r, "Track", { x = barX, y = 8, w = barW, h = 14 }, 35)
	track.BackgroundColor3 = Theme.progress.track
	track.BackgroundTransparency = 0
	corner(track, 7)
	outline(track, INK, 2)

	local fillBar = frame(track, "Fill", { x = 0, y = 0, w = 0, h = 14 }, 36)
	fillBar.Size = UDim2.fromScale(math.clamp(percent / 100, 0, 1), 1)
	fillBar.BackgroundTransparency = 0
	corner(fillBar, 7)
	gradient(fillBar, Theme.progress.fill)
	return fillBar
end

export type Count = { label: TextLabel, kind: "Count" | "Clock" | "Percent", target: number }

export type Stats = {
	group: Frame,
	rows: { Frame },
	counts: { Count },
	fill: Frame?,
	percent: number,
	shiftUp: number,
}

local function buildStats(content: Instance, summary: Summary): Stats
	--[[ Everything on the stats panel in one group, so it can slide in as
	     one piece. ]]
	local parent = frame(
		content,
		"StatsGroup",
		{ x = 0, y = 0, w = Theme.panelSize.X, h = Theme.panelSize.Y },
		30
	)
	local pb = Layout.panel
	local rowsBottom = Layout.rowsOrigin.Y + 3 * Theme.row.height + 2 * Theme.row.gap
	-- Closed up to the rows while the rewards box is not shown.
	local height = rowsBottom + 18
	local b = { x = pb.x, y = pb.y, w = pb.w, h = height }

	shadow(parent, b, 30, Theme.panel.corner, 6)
	local panel = frame(parent, "Stats", b, 31)
	panel.BackgroundTransparency = 0
	corner(panel, Theme.panel.corner)
	outline(panel, INK, 4)
	gradient(panel, Theme.panel.fill)

	local inner = frame(panel, "InnerLine", { x = 3, y = 3, w = b.w - 6, h = b.h - 6 }, 32)
	corner(inner, Theme.panel.corner - 3)
	outline(inner, Theme.panel.innerLine, 2)

	-- The LEVEL tab over the top edge, with its cyan accents.
	local tb = Layout.levelTab
	local tab = frame(parent, "LevelTab", { x = tb.x, y = tb.y, w = tb.w, h = tb.h }, 40)
	tab.BackgroundTransparency = 0
	corner(tab, 14)
	outline(tab, INK, 4)
	gradient(tab, Theme.tab.fill)
	text(
		tab,
		"Text",
		{ x = 0, y = 3, w = tb.w, h = tb.h },
		42,
		"LEVEL " .. tostring(summary.stage),
		DISPLAY,
		Theme.text.level,
		WHITE,
		Theme.text.levelStroke
	)
	for side = -1, 1, 2 do
		local accent = frame(tab, "Accent", {
			x = tb.w / 2 + side * (tb.w / 2 - 30) - 6,
			y = 12,
			w = 12,
			h = 20,
		}, 41)
		accent.BackgroundColor3 = Theme.tab.accent
		accent.BackgroundTransparency = 0
		accent.Rotation = side * 24
		corner(accent, 3)
		outline(accent, INK, 2)
	end

	local rows: { Frame } = {}
	local counts: { Count } = {}
	local fill: Frame? = nil
	local function add(r: Frame, kind: "Count" | "Clock" | "Percent", target: number)
		table.insert(rows, r)
		table.insert(
			counts,
			{ label = r:FindFirstChild("Value") :: TextLabel, kind = kind, target = target }
		)
	end

	add(
		row(panel, 1, EndScreenAssets.skull, "Enemies defeated", tostring(summary.kills)),
		"Count",
		summary.kills
	)
	if summary.won then
		add(
			row(panel, 2, EndScreenAssets.hourglass, "Time", clock(summary.seconds)),
			"Clock",
			summary.seconds
		)
		add(
			row(
				panel,
				3,
				EndScreenAssets.heart,
				"Health remaining",
				string.format("%d%%", summary.healthPercent)
			),
			"Percent",
			summary.healthPercent
		)
	else
		add(
			row(panel, 2, EndScreenAssets.hourglass, "Time survived", clock(summary.seconds)),
			"Clock",
			summary.seconds
		)
		fill = progressRow(panel, 3, summary.progressPercent)
		add(panel:FindFirstChild("Row3") :: Frame, "Percent", summary.progressPercent)
	end

	return {
		group = parent,
		rows = rows,
		counts = counts,
		fill = fill,
		percent = summary.progressPercent,
		shiftUp = pb.h - height,
	}
end

export type ButtonParts = {
	group: Frame,
	button: TextButton,
	icon: ImageLabel,
	shine: Frame,
}

local function buildButton(content: Instance, look: any, won: boolean, shiftUp: number): ButtonParts
	local lb = Layout.button
	-- The button and its shadow in one group, pivoted on the button's centre.
	local parent =
		frame(content, "ButtonGroup", { x = lb.x, y = lb.y - shiftUp, w = lb.w, h = lb.h }, 50)
	local b = { x = 0, y = 0, w = lb.w, h = lb.h }
	shadow(parent, b, 50, 22, 6)

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Position = UDim2.fromOffset(b.x, b.y)
	button.Size = UDim2.fromOffset(b.w, b.h)
	button.BackgroundColor3 = WHITE
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = 51
	button.Parent = parent
	corner(button, 22)
	outline(button, INK, 4)
	gradient(button, look.button)
	--[[ The shine that sweeps across it: a soft white band, slanted by its
	     gradient, in a rounded CanvasGroup so it is clipped to the button's
	     own rounded ends rather than to a rectangle. ]]
	local shineClip = Instance.new("CanvasGroup")
	shineClip.Name = "ShineClip"
	shineClip.Size = UDim2.fromScale(1, 1)
	shineClip.BackgroundTransparency = 1
	shineClip.ZIndex = 52
	shineClip.Parent = button
	corner(shineClip, 22)
	local shine = frame(shineClip, "Shine", { x = -120, y = 0, w = 70, h = b.h }, 55)
	shine.BackgroundTransparency = 0
	local band = Instance.new("UIGradient")
	band.Rotation = 18
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Parent = shine

	local highlight = frame(button, "Highlight", { x = 14, y = 3, w = b.w - 28, h = 3 }, 52)
	highlight.BackgroundTransparency = 0.5
	corner(highlight, 2)

	local inner = frame(button, "Content", { x = 0, y = 0, w = b.w, h = b.h }, 53)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 14)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = inner

	local words = look.buttonText
	local label = text(
		inner,
		"Text",
		{ x = 0, y = 0, w = width(words, DISPLAY, Theme.text.button) + 8, h = b.h },
		54,
		words,
		DISPLAY,
		Theme.text.button,
		WHITE,
		Theme.text.buttonStroke
	)
	-- Luckiest Guy sits high in its box; the design pads it down 4 px.
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.Parent = label

	local icon: ImageLabel
	if won then
		label.LayoutOrder = 1
		icon =
			image(inner, "Chevron", { x = 0, y = 0, w = 26, h = 26 }, 54, EndScreenAssets.chevron)
		icon.LayoutOrder = 2
	else
		icon =
			image(inner, "Refresh", { x = 0, y = 0, w = 36, h = 36 }, 54, EndScreenAssets.refresh)
		icon.LayoutOrder = 1
		label.LayoutOrder = 2
	end

	pivot(parent)
	return { group = parent, button = button, icon = icon, shine = shine }
end

local function fit()
	if not scaler then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local view = camera.ViewportSize
	scaler.Scale =
		math.min(view.Y * HEIGHT_SHARE / panelHeight, view.X * WIDTH_SHARE / Theme.panelSize.X)
end

function EndScreen.hide()
	if gui then
		gui:Destroy()
		gui = nil
	end
	scaler = nil
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
	if motion then
		motion.stop()
		motion = nil
	end
end

function EndScreen.show(summary: Summary)
	EndScreen.hide()

	local won = summary.won
	local look = if won then Theme.victory else Theme.defeat

	local screen = Instance.new("ScreenGui")
	screen.Name = "EndScreen"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	--[[ Over the card screens and the skill bar (100–120). A run cannot end
	     while a hand is open — the world is frozen — so this only matters
	     for the Studio preview, but the skill bar would otherwise sit on
	     top of the button. ]]
	screen.DisplayOrder = 130
	--[[ Sibling, not Global: under Global the background's CanvasGroup
	     stopped clipping, and the rays spilled out past the panel. ]]
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui = screen

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.ZIndex = 0
	dim.Parent = screen

	-- Built first so the panel's height can close up around what is shown.
	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.BackgroundTransparency = 1
	root.Parent = screen
	local scale = Instance.new("UIScale")
	scale.Parent = root
	scaler = scale

	local content =
		frame(root, "Content", { x = 0, y = 0, w = Theme.panelSize.X, h = Theme.panelSize.Y }, 10)
	local ribbon, sub = buildRibbon(content, look, won)
	local hero = buildHero(content, look, won)
	local stats = buildStats(content, summary)
	local shiftUp = stats.shiftUp
	local buttonParts = buildButton(content, look, won, shiftUp)
	local button = buttonParts.button

	local lb = Layout.button
	panelHeight = lb.y - shiftUp + lb.h + 6 + 22
	local size = Vector2.new(Theme.panelSize.X, panelHeight)
	root.Size = UDim2.fromOffset(size.X, size.Y)
	content.Size = UDim2.fromOffset(size.X, size.Y)

	-- The panel behind it all: hard shadow, then the background, then the ink edge.
	shadow(root, { x = 0, y = 0, w = size.X, h = size.Y }, 1, 24, 8)
	--[[ The gradient on a plain frame: drawn through a CanvasGroup it came
	     out banded, with a visible seam across the panel's lower third. ]]
	local back = frame(root, "Background", { x = 0, y = 0, w = size.X, h = size.Y }, 2)
	back.BackgroundTransparency = 0
	corner(back, 24)
	gradient(back, look.background)
	--[[ The rays and glow go in a CanvasGroup over it, whose rounded edge
	     clips them to the panel — the rays are far wider than it. ]]
	local glows = Instance.new("CanvasGroup")
	glows.Name = "Glows"
	glows.Size = UDim2.fromOffset(size.X, size.Y)
	glows.BackgroundTransparency = 1
	glows.ZIndex = 3
	glows.Parent = root
	corner(glows, 24)
	for _, name in { "Rays", "Glow" } do
		local piece = content:FindFirstChild(name)
		if piece then
			piece.Parent = glows
		end
	end
	--[[ Flash, sparks, confetti, rocks and the vignette: over the content,
	     under the ink edge, clipped to the panel like the rays. ]]
	local over = Instance.new("CanvasGroup")
	over.Name = "Over"
	over.Size = UDim2.fromOffset(size.X, size.Y)
	over.BackgroundTransparency = 1
	over.ZIndex = 80
	over.Parent = root
	corner(over, 24)

	local edge = frame(root, "Edge", { x = 0, y = 0, w = size.X, h = size.Y }, 90)
	corner(edge, 24)
	outline(edge, INK, 5)

	local played = EndScreenMotion.play({
		won = won,
		root = root,
		size = size,
		ribbon = ribbon,
		sub = sub,
		hero = hero,
		rays = glows:FindFirstChild("Rays") :: ImageLabel?,
		glow = glows:FindFirstChild("Glow") :: ImageLabel?,
		behind = glows,
		over = over,
		statsGroup = stats.group,
		rows = stats.rows,
		counts = stats.counts,
		fill = stats.fill,
		percent = stats.percent,
		buttonGroup = buttonParts.group,
		icon = buttonParts.icon,
		shine = buttonParts.shine,
	})
	motion = played

	--[[ A tap anywhere jumps the entrance to its end. Whether the button was
	     ready is read before the jump, so the tap that skips is never also
	     taken as a press. ]]
	local readyAtTap = false
	inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			readyAtTap = played.ready()
			played.skip()
		end
	end)

	local shownAt = os.clock()
	local pressed = false
	button.Activated:Connect(function()
		if pressed or not readyAtTap then
			return
		end
		pressed = true
		--[[ The server takes the request only once the run has been over for
		     `deathPause`; after a skip the button can be ready sooner, so the
		     request waits out the difference rather than being refused. ]]
		local wait = Balance.Run.deathPause + 0.1 - (os.clock() - shownAt)
		task.delay(math.max(0, wait), function()
			if onRestart and gui == screen then
				onRestart()
			end
		end)
	end)

	fit()
	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

--[[ Holds the showing screen's motion at `ms` milliseconds, or releases it
     with nil: for looking at one moment of it in Studio. ]]
function EndScreen.hold(ms: number?)
	if motion then
		motion.hold(ms)
	end
end

--[[ `restart` is called when the player presses the button; the caller asks
     the server, which decides. ]]
function EndScreen.start(restart: () -> ())
	onRestart = restart
end

return EndScreen
