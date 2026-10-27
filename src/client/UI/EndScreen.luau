--!strict
--[[
	The Victory and Defeat screens, in the blocky design language (owner,
	2026-10-25), built to match their Codex reference sheets
	(`assets/concepts/blocky/ui/end_victory.jpg`, `end_defeat.jpg`). Built
	at the sheets' 1024 × 1536 and scaled as a whole: 85% of the screen's
	height, or the screen's width on a phone held upright.

	Every panel, plate, row and button is drawn from flat blocks: an ink
	outline, a fill with a lighter strip on top and a darker band below,
	and stair-stepped corners made of overlapping rectangles. The art the
	sheets draw (ribbons, the pictures, icons, cubes) is Codex's, in
	`Config/EndScreenAssets`; every word is live, in the blocky font.

	Presentation only. The server decides that the run is over, whether it
	was won, and every number shown; the button only asks it for the next
	run, and the server ignores that unless the run has ended.

	The motion lives in `EndScreenMotion`, posed from the timeline in
	`Config/EndScreenTimeline`. A tap anywhere jumps to the end of it; the
	button only takes a press once its own entrance has finished.

	The REWARDS box is there for the coins and gems a run will pay out
	(owner, 2026-10-25: "still leave an area on both screens for rewards");
	until the meta loop pays any, it counts up to whatever the summary
	carries, which is nothing yet.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EndScreenAssets = require(ReplicatedStorage.Shared.Config.EndScreenAssets)
local EndScreenLayout = require(ReplicatedStorage.Shared.Config.EndScreenLayout)
local EndScreenTheme = require(ReplicatedStorage.Shared.Config.EndScreenTheme)

local Device = require(script.Parent.Parent.Device)
local EndScreenMotion = require(script.Parent.EndScreenMotion)

local EndScreen = {}

export type Summary = {
	won: boolean,
	stage: number,
	kills: number,
	seconds: number,
	healthPercent: number,
	progressPercent: number,
	--[[ What the run paid out; nil until the meta loop pays anything.
	     `chests` are the stage's area's chest (Victory only). ]]
	coins: number?,
	gems: number?,
	chests: number?,
}

type Box = { x: number, y: number, w: number, h: number }
type Block = EndScreenTheme.Block

local Theme = EndScreenTheme
local CANVAS = EndScreenLayout.canvas
local INK = Theme.ink
local WHITE = Theme.white
local FONT = Theme.font

--[[ Share of the screen's height the sheet fills, and of its width when the
     width is the tighter fit. ]]
local HEIGHT_SHARE = 0.85
--[[ A phone held sideways is all height-bound, so it gets nearly the whole
     of it: "make the phone UI bigger". ]]
local PHONE_HEIGHT_SHARE = 0.97
local PHONE_WIDTH_SHARE = 0.98
local WIDTH_SHARE = 0.94
--[[ Roblox's largest TextSize. ]]
local MAX_TEXT = 100

local gui: ScreenGui? = nil
local scaler: UIScale? = nil
local viewportConnection: RBXScriptConnection? = nil
local inputConnection: RBXScriptConnection? = nil
local motion: EndScreenMotion.Motion? = nil
local onRestart: (() -> ())? = nil

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

local function rect(parent: Instance, name: string, b: Box, z: number, colour: Color3): Frame
	local f = frame(parent, name, b, z)
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = 0
	return f
end

local function image(parent: Instance, name: string, b: Box, z: number, asset: string): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.Position = UDim2.fromOffset(b.x, b.y)
	i.Size = UDim2.fromOffset(b.w, b.h)
	i.BackgroundTransparency = 1
	i.Image = asset
	i.ScaleType = Enum.ScaleType.Fit
	i.ResampleMode = Enum.ResamplerMode.Pixelated
	i.ZIndex = z
	i.Parent = parent
	return i
end

--[[ Blocky type with a hard ink outline. ]]
local function text(
	parent: Instance,
	name: string,
	b: Box,
	z: number,
	content: string,
	size: number,
	colour: Color3,
	stroke: number
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Position = UDim2.fromOffset(b.x, b.y)
	t.Size = UDim2.fromOffset(b.w, b.h)
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.Text = content
	t.TextColor3 = colour
	t.ZIndex = z
	t.Parent = parent
	--[[ Roblox draws type no larger than 100: a bigger title is drawn at a
	     fraction of its size, in a box that fraction of its own, and
	     scaled back up about its centre. ]]
	local k = math.ceil(size / MAX_TEXT)
	t.TextSize = size / k
	if k > 1 then
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromOffset(b.x + b.w / 2, b.y + b.h / 2)
		t.Size = UDim2.fromOffset(b.w / k, b.h / k)
		local up = Instance.new("UIScale")
		up.Scale = k
		up.Parent = t
	end
	if stroke > 0 then
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = stroke / k
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.LineJoinMode = Enum.LineJoinMode.Miter
		s.Parent = t
	end
	return t
end

local function width(content: string, size: number): number
	return TextService:GetTextSize(content, size, FONT, Vector2.new(4000, 400)).X
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", s // 60, s % 60)
end

--[[
	A stair-stepped box in one colour: `steps` steps at each corner, each
	`sx` across and `sy` down, drawn as overlapping rectangles (the widest
	one the shortest).
]]
local function stepped(
	parent: Instance,
	name: string,
	b: Box,
	z: number,
	colour: Color3,
	steps: number,
	sx: number,
	sy: number
)
	for i = 0, steps do
		local ix = (steps - i) * sx
		local iy = i * sy
		rect(
			parent,
			name,
			{ x = b.x + ix, y = b.y + iy, w = b.w - 2 * ix, h = b.h - 2 * iy },
			z,
			colour
		)
	end
end

--[[ A flat block (`Theme.Block`) filling `b` of `parent`, its layers at
     `z` and above. Returns the block's own frame. ]]
local function block(
	parent: Instance,
	name: string,
	b: Box,
	z: number,
	look: Block,
	steps: number?,
	sx: number?,
	sy: number?
): Frame
	local f = frame(parent, name, b, z)
	local n = steps or 0
	local stepX = sx or 0
	local stepY = sy or stepX
	local function layer(inset: number, top: number, bottom: number, colour: Color3, at: number)
		stepped(f, "Layer", {
			x = inset,
			y = inset + top,
			w = b.w - 2 * inset,
			h = b.h - 2 * inset - top - bottom,
		}, at, colour, n, stepX, stepY)
	end
	layer(0, 0, 0, look.ink, z)
	local inset = look.inkW
	if look.rim then
		layer(inset, 0, 0, look.rim, z)
		inset += look.rimW or 0
	end
	local topH = if look.top then look.topH or 0 else 0
	local bottomH = if look.bottom then look.bottomH or 0 else 0
	if look.bottom then
		layer(inset, 0, 0, look.bottom, z)
	end
	if look.top then
		layer(inset, 0, bottomH, look.top, z)
	end
	layer(inset, topH, bottomH, look.fill, z)
	return f
end

--[[ A grey Codex cube tinted `colour`, centred on (x, y). ]]
local function cube(
	parent: Instance,
	x: number,
	y: number,
	size: number,
	z: number,
	colour: Color3
): ImageLabel
	local c = image(
		parent,
		"Cube",
		{ x = x - size / 2, y = y - size / 2, w = size, h = size },
		z,
		EndScreenAssets.cube
	)
	c.ImageColor3 = colour
	return c
end

--[[ A little square stud with an ink edge, centred on (x, y). ]]
local function stud(parent: Instance, x: number, y: number, size: number, z: number, colour: Color3)
	rect(
		parent,
		"Stud",
		{ x = x - size / 2 - 4, y = y - size / 2 - 4, w = size + 8, h = size + 8 },
		z,
		INK
	)
	rect(parent, "Stud", { x = x - size / 2, y = y - size / 2, w = size, h = size }, z, colour)
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

local function buildRibbon(parent: Instance, look: any, layout: any, won: boolean): (Frame, Frame)
	local rb: Box = layout.ribbon
	local ribbon = frame(parent, "Ribbon", rb, 20)
	local art = image(
		ribbon,
		"Art",
		{ x = 0, y = 0, w = rb.w, h = rb.h },
		20,
		if won then EndScreenAssets.ribbonVictory else EndScreenAssets.ribbonDefeat
	)
	art.ScaleType = Enum.ScaleType.Stretch

	--[[ The title: white over a lighter-or-gold lower half, hard-split like
	     the sheet's letters, with an ink drop under it. ]]
	local tb: Box = layout.title
	local inner = { x = tb.x - rb.x, y = tb.y - rb.y, w = tb.w, h = tb.h }
	local drop = text(
		ribbon,
		"TitleDrop",
		{ x = inner.x, y = inner.y + 9, w = inner.w, h = inner.h },
		21,
		look.titleText,
		look.text.title,
		INK,
		look.text.titleStroke
	)
	drop.TextTransparency = 0
	local title = text(
		ribbon,
		"Title",
		inner,
		22,
		look.titleText,
		look.text.title,
		WHITE,
		look.text.titleStroke
	)
	local split = Instance.new("UIGradient")
	split.Rotation = 90
	split.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, look.title),
		ColorSequenceKeypoint.new(0.56, look.title),
		ColorSequenceKeypoint.new(0.561, look.titleLow),
		ColorSequenceKeypoint.new(1, look.titleLow),
	})
	split.Parent = title

	local sb: Box = layout.sub
	local sub = block(parent, "SubPlate", sb, 26, look.sub)
	text(
		sub,
		"Text",
		{ x = 0, y = 0, w = sb.w, h = sb.h - (look.sub.bottomH or 0) + 4 },
		29,
		look.subText,
		look.text.sub,
		look.subTextColour,
		look.text.subStroke
	)
	if look.studs then
		for _, at in { { 30, 30 }, { sb.w - 30, 30 }, { 30, sb.h - 34 }, { sb.w - 30, sb.h - 34 } } do
			cube(sub, at[1], at[2], 30, 28, look.studs)
		end
	end

	pivot(ribbon)
	pivot(sub)
	return ribbon, sub
end

local function buildHero(parent: Instance, layout: any, won: boolean): ImageLabel
	local hero = image(
		parent,
		"Hero",
		layout.hero,
		8,
		if won then EndScreenAssets.heroVictory else EndScreenAssets.heroDefeat
	)
	hero.ScaleType = Enum.ScaleType.Stretch
	pivot(hero)
	return hero
end

local function buildCubes(parent: Instance, look: any, layout: any): { ImageLabel }
	local cubes: { ImageLabel } = {}
	for _, c in layout.cubes do
		local piece = cube(parent, c[1], c[2], c[3], 7, look.cubes)
		pivot(piece)
		table.insert(cubes, piece)
	end
	return cubes
end

export type Count = {
	label: TextLabel,
	kind: "Count" | "Clock" | "Percent" | "Plus" | "Times",
	target: number,
}

--[[ A tab over a panel's top edge: a block with its words, and a stud at
     each end. ]]
local function tab(
	parent: Instance,
	name: string,
	b: Box,
	z: number,
	look: Block,
	words: string,
	size: number,
	stroke: number,
	studs: Color3?
)
	local t = block(parent, name, b, z, look)
	text(
		t,
		"Text",
		{ x = 0, y = 0, w = b.w, h = b.h - (look.bottomH or 0) + 4 },
		z + 2,
		words,
		size,
		WHITE,
		stroke
	)
	if studs then
		stud(t, 38, b.h / 2, 14, z + 1, studs)
		stud(t, b.w - 38, b.h / 2, 14, z + 1, studs)
	end
end

local function row(
	parent: Instance,
	look: any,
	layout: any,
	index: number,
	icon: string,
	label: string,
	value: string
): Frame
	local rl = layout.rows
	local r = block(parent, "Row" .. index, {
		x = rl.x,
		y = rl.y + (index - 1) * rl.pitch,
		w = rl.w,
		h = rl.h,
	}, 33, look.row)

	image(r, "Icon", { x = rl.iconX, y = (rl.h - rl.icon) / 2, w = rl.icon, h = rl.icon }, 35, icon)
	local l = text(
		r,
		"Label",
		{ x = rl.labelX, y = 2, w = 420, h = rl.h },
		35,
		label,
		look.text.rowLabel,
		WHITE,
		0
	)
	l.TextXAlignment = Enum.TextXAlignment.Left
	local v = text(
		r,
		"Value",
		{ x = rl.valueRight - 220, y = 2, w = 220, h = rl.h },
		35,
		value,
		look.text.rowValue,
		WHITE,
		look.text.rowStroke
	)
	v.TextXAlignment = Enum.TextXAlignment.Right
	return r
end

--[[ Defeat's progress bar on its third row: a run of blocky segments.
     Returns the function that lights them to a share. ]]
local function progressBar(r: Frame, look: any, layout: any): (number) -> ()
	local bar = layout.bar
	local b = {
		x = bar.x - layout.rows.x,
		y = bar.y - (layout.rows.y + 2 * layout.rows.pitch),
		w = bar.w,
		h = bar.h,
	}
	rect(r, "BarInk", b, 36, INK)
	local n = bar.segments
	local gap = 4
	local inner = { x = b.x + 5, y = b.y + 5, w = b.w - 10, h = b.h - 10 }
	local segW = (inner.w - (n - 1) * gap) / n
	type Segment = { body: Frame, top: Frame }
	local segments: { Segment } = {}
	for i = 1, n do
		local x = inner.x + (i - 1) * (segW + gap)
		local body =
			rect(r, "Segment", { x = x, y = inner.y, w = segW, h = inner.h }, 37, look.barOff)
		local top = rect(r, "SegmentTop", { x = x, y = inner.y, w = segW, h = 6 }, 38, look.barOff)
		table.insert(segments, { body = body, top = top })
	end
	return function(share: number)
		for i, s in segments do
			local on = (i - 0.5) / n <= share
			s.body.BackgroundColor3 = if on then look.barOn else look.barOff
			s.top.BackgroundColor3 = if on then look.barOnTop else look.barOff
		end
	end
end

--[[ Victory's chest slot, under the coins and gems: the chest of the
     stage's area, its sparkles, CHEST and how many. Dimmed while the run
     gave none (until chests exist, always). ]]
local function chestSlot(rewards: Frame, look: any, layout: any, summary: Summary): Count
	local c = layout.chest
	local rb: Box = layout.rewards
	local sb: Box = c.slot
	local slot = block(
		rewards,
		"ChestSlot",
		{ x = sb.x - rb.x, y = sb.y - rb.y, w = sb.w, h = sb.h },
		34,
		look.slot
	)
	local stage = Balance.Stages[summary.stage]
	local area = (stage and stage.area) or "MossyGlade"
	local chests: { [string]: string } = EndScreenAssets.chests
	local count = summary.chests or 0
	local dim = if count > 0 then 0 else look.chestDim
	local chest = image(slot, "Chest", c.icon, 36, chests[area] or chests.MossyGlade)
	chest.ImageTransparency = dim
	for _, at in c.sparkles do
		cube(slot, at[1], at[2], c.sparkle, 36, look.cubes).ImageTransparency = dim
	end
	local label = text(
		slot,
		"Label",
		{ x = c.labelX, y = 3, w = 260, h = sb.h },
		36,
		"CHEST",
		look.text.reward,
		WHITE,
		look.text.rewardStroke
	)
	label.TextXAlignment = Enum.TextXAlignment.Left
	local v = text(
		slot,
		"Value",
		{ x = c.countRight - 160, y = 3, w = 160, h = sb.h },
		36,
		"x" .. tostring(count),
		look.text.reward,
		WHITE,
		look.text.rewardStroke
	)
	v.TextXAlignment = Enum.TextXAlignment.Right
	return { label = v, kind = "Times", target = count }
end

export type Stats = {
	group: Frame,
	rows: { Frame },
	counts: { Count },
	setProgress: ((number) -> ())?,
	percent: number,
	rewards: Frame,
	rewardCounts: { Count },
}

local function levelOf(index: number): string?
	local stage = Balance.Stages[index]
	return stage and stage.level
end

local function buildStats(content: Instance, look: any, layout: any, summary: Summary): Stats
	--[[ Everything on the stats panel in one group, so it can slide in as
	     one piece. ]]
	local group = frame(content, "StatsGroup", { x = 0, y = 0, w = CANVAS.X, h = CANVAS.Y }, 30)
	block(group, "Stats", layout.stats, 30, look.stats, 2, 10)
	tab(
		group,
		"LevelTab",
		layout.tab,
		40,
		look.tab,
		-- the tutorial is not a numbered level (`Config/Tutorial`); an area's
		-- levels go by their own numbers ("LEVEL 1-3")
		if summary.stage == Balance.tutorialStage
			then "TUTORIAL"
			else "LEVEL " .. (levelOf(summary.stage) or tostring(summary.stage)),
		look.text.tab,
		look.text.tabStroke,
		look.tabStuds
	)

	local rows: { Frame } = {}
	local counts: { Count } = {}
	local setProgress: ((number) -> ())? = nil
	local function add(r: Frame, kind: "Count" | "Clock" | "Percent", target: number)
		table.insert(rows, r)
		table.insert(
			counts,
			{ label = r:FindFirstChild("Value") :: TextLabel, kind = kind, target = target }
		)
	end

	local labels = look.labels
	add(
		row(group, look, layout, 1, EndScreenAssets.skull, labels[1], tostring(summary.kills)),
		"Count",
		summary.kills
	)
	add(
		row(group, look, layout, 2, EndScreenAssets.hourglass, labels[2], clock(summary.seconds)),
		"Clock",
		summary.seconds
	)
	if summary.won then
		add(
			row(
				group,
				look,
				layout,
				3,
				EndScreenAssets.heart,
				labels[3],
				string.format("%d%%", summary.healthPercent)
			),
			"Percent",
			summary.healthPercent
		)
	else
		local r = row(
			group,
			look,
			layout,
			3,
			EndScreenAssets.chart,
			labels[3],
			string.format("%d%%", summary.progressPercent)
		)
		setProgress = progressBar(r, look, layout)
		add(r, "Percent", summary.progressPercent)
	end

	-- The rewards box: its own group, so it can pop in after the rows.
	local rewards = frame(group, "Rewards", layout.rewards, 32)
	local rb: Box = layout.rewards
	block(rewards, "Box", { x = 0, y = 0, w = rb.w, h = rb.h }, 32, look.rewards)
	local tb: Box = layout.rewardsTab
	tab(
		rewards,
		"RewardsTab",
		{ x = tb.x - rb.x, y = tb.y - rb.y, w = tb.w, h = tb.h },
		40,
		look.rewardsTabBlock or look.tab,
		"REWARDS",
		look.text.rewardsTab,
		look.text.tabStroke,
		if look.rewardsTabBlock then nil else look.tabStuds
	)
	local rewardCounts: { Count } = {}
	for i, sb in layout.slots do
		local slot = block(
			rewards,
			"Slot" .. i,
			{ x = sb.x - rb.x, y = sb.y - rb.y, w = sb.w, h = sb.h },
			34,
			look.slot
		)
		local size = layout.slotIcon
		image(
			slot,
			"Icon",
			{ x = layout.slotIconX, y = (sb.h - size) / 2, w = size, h = size },
			36,
			if i == 1 then EndScreenAssets.coin else EndScreenAssets.gem
		)
		local target = (if i == 1 then summary.coins else summary.gems) or 0
		local v = text(
			slot,
			"Value",
			{ x = layout.slotTextX, y = 3, w = sb.w - layout.slotTextX - 16, h = sb.h },
			36,
			"+" .. tostring(target),
			look.text.reward,
			WHITE,
			look.text.rewardStroke
		)
		v.TextXAlignment = Enum.TextXAlignment.Left
		table.insert(rewardCounts, { label = v, kind = "Plus", target = target })
	end
	if layout.chest then
		table.insert(rewardCounts, chestSlot(rewards, look, layout, summary))
	end
	pivot(rewards)

	return {
		group = group,
		rows = rows,
		counts = counts,
		setProgress = setProgress,
		percent = summary.progressPercent,
		rewards = rewards,
		rewardCounts = rewardCounts,
	}
end

export type ButtonParts = {
	group: Frame,
	button: TextButton,
	icon: ImageLabel,
	shine: Frame,
}

local function buildButton(content: Instance, look: any, layout: any, won: boolean): ButtonParts
	local lb: Box = layout.button
	local group = frame(content, "ButtonGroup", lb, 50)
	local face = block(group, "Face", { x = 0, y = 0, w = lb.w, h = lb.h }, 50, look.button)
	local ink = look.button.inkW
	local faceBottom: number
	if won then
		-- The sheet's foot: an ink line, then a dark band cut into segments.
		local foot = layout.buttonFoot
		faceBottom = foot.face
		local band = foot.band
		rect(
			face,
			"FootLine",
			{ x = ink, y = foot.line, w = lb.w - 2 * ink, h = band - foot.line },
			51,
			INK
		)
		rect(
			face,
			"Foot",
			{ x = ink, y = band, w = lb.w - 2 * ink, h = lb.h - band - ink },
			51,
			look.buttonFoot
		)
		local x = ink + 80
		while x < lb.w - ink - 20 do
			rect(
				face,
				"FootSeam",
				{ x = x, y = band, w = 7, h = lb.h - band - ink },
				52,
				look.buttonFootLine
			)
			x += 82
		end
		rect(face, "Shine", { x = 64, y = 29, w = lb.w - 128, h = 8 }, 52, look.buttonShine)
		local studY = layout.buttonStudsY
		for _, at in
			{ { 39, studY[1] }, { lb.w - 39, studY[1] }, { 39, studY[2] }, { lb.w - 39, studY[2] } }
		do
			cube(face, at[1], at[2], 34, 53, look.buttonStuds)
		end
	else
		faceBottom = lb.h - ink - (look.button.bottomH or 0)
		rect(
			face,
			"Low",
			{ x = ink, y = 102, w = lb.w - 2 * ink, h = faceBottom - 102 },
			51,
			look.buttonLow
		)
		for _, at in { { 40, 32 }, { lb.w - 40, 32 }, { 40, 124 }, { lb.w - 40, 124 } } do
			stud(face, at[1], at[2], 18, 53, look.buttonStuds)
		end
	end

	-- What takes the press: the whole button, drawn by the blocks under it.
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = 60
	button.Parent = group

	--[[ The shine that sweeps across the face now and then: a hard-edged,
	     slanted light band, clipped to the face. ]]
	local clip = Instance.new("CanvasGroup")
	clip.Name = "ShineClip"
	clip.Position = UDim2.fromOffset(ink, ink)
	clip.Size = UDim2.fromOffset(lb.w - 2 * ink, faceBottom - ink)
	clip.BackgroundTransparency = 1
	clip.ZIndex = 54
	clip.GroupTransparency = 0.55
	clip.Parent = group
	local shine = rect(clip, "Sweep", { x = -160, y = -40, w = 60, h = lb.h + 80 }, 55, WHITE)
	shine.Rotation = 18

	local inner = frame(group, "Content", { x = 0, y = 0, w = lb.w, h = faceBottom + 6 }, 56)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 24)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = inner

	local words = look.buttonText
	local label = text(
		inner,
		"Text",
		{ x = 0, y = 0, w = width(words, look.text.button) + 12, h = 90 },
		57,
		words,
		look.text.button,
		WHITE,
		look.text.buttonStroke
	)
	local icon: ImageLabel
	if won then
		label.LayoutOrder = 1
		icon =
			image(inner, "Chevron", { x = 0, y = 0, w = 56, h = 56 }, 57, EndScreenAssets.chevron)
		icon.LayoutOrder = 2
	else
		icon =
			image(inner, "Refresh", { x = 0, y = 0, w = 96, h = 96 }, 57, EndScreenAssets.refresh)
		icon.LayoutOrder = 1
		label.LayoutOrder = 2
	end

	pivot(group)
	return { group = group, button = button, icon = icon, shine = shine }
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
	scaler.Scale = math.min(
		view.Y * (if Device.isPhone() then PHONE_HEIGHT_SHARE else HEIGHT_SHARE) / CANVAS.Y,
		view.X * (if Device.isPhone() then PHONE_WIDTH_SHARE else WIDTH_SHARE) / CANVAS.X
	)
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
	local look: any = if won then Theme.victory else Theme.defeat
	local layout: any = if won then EndScreenLayout.victory else EndScreenLayout.defeat

	local screen = Instance.new("ScreenGui")
	screen.Name = "EndScreen"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	--[[ Over the card screens and the skill bar (100–120). A run cannot end
	     while a hand is open — the world is frozen — so this only matters
	     for the Studio preview, but the skill bar would otherwise sit on
	     top of the button. ]]
	screen.DisplayOrder = 130
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

	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y)
	root.BackgroundTransparency = 1
	root.Parent = screen
	local scale = Instance.new("UIScale")
	scale.Parent = root
	scaler = scale

	-- The panel: a big stepped block.
	local pb: Box = layout.panel
	local panel = block(
		root,
		"Back",
		pb,
		1,
		look.panel,
		layout.panelSteps,
		layout.panelStep,
		layout.panelStepY
	)
	local inset = look.panel.inkW + (look.panel.rimW or 0)
	--[[ The area inside the panel's stepped top corners, which the rays,
	     rain, flash and falling pieces are clipped to. A CanvasGroup, since
	     a plain frame does not clip children that turn. ]]
	local stepDown = layout.panelSteps * (layout.panelStepY or layout.panelStep)
	local inside: Box = {
		x = pb.x + inset,
		y = pb.y + inset + stepDown,
		w = pb.w - 2 * inset,
		h = pb.h - 2 * inset - stepDown - (look.panel.bottomH or 0),
	}
	if look.vignette then
		-- Defeat's gloom: a darker band round the inside of the edge.
		local v = look.vignetteW
		local fill = look.panel.fill
		local inner = {
			x = inset,
			y = inset,
			w = pb.w - 2 * inset,
			h = pb.h - 2 * inset - (look.panel.bottomH or 0),
		}
		stepped(
			panel,
			"Gloom",
			inner,
			2,
			look.vignette,
			layout.panelSteps,
			layout.panelStep,
			layout.panelStep
		)
		stepped(
			panel,
			"Light",
			{ x = inner.x + v, y = inner.y + v, w = inner.w - 2 * v, h = inner.h - 2 * v },
			2,
			fill,
			3,
			v / 2,
			v / 2
		)
	end

	local function clipped(name: string, z: number): CanvasGroup
		local c = Instance.new("CanvasGroup")
		c.Name = name
		c.Position = UDim2.fromOffset(inside.x, inside.y)
		c.Size = UDim2.fromOffset(inside.w, inside.h)
		c.BackgroundTransparency = 1
		c.ZIndex = z
		c.Parent = root
		return c
	end
	local behind = clipped("Behind", 3)
	local over = clipped("Over", 80)

	local content = frame(root, "Content", { x = 0, y = 0, w = CANVAS.X, h = CANVAS.Y }, 10)

	local rays: ImageLabel? = nil
	if won then
		local r: Box = layout.rays
		rays = image(
			behind,
			"Rays",
			{ x = r.x - inside.x, y = r.y - inside.y, w = r.w, h = r.h },
			3,
			EndScreenAssets.rays
		)
		local raysImage = rays :: ImageLabel
		raysImage.ImageColor3 = look.rays
		raysImage.ImageTransparency = look.raysTransparency
		raysImage.ScaleType = Enum.ScaleType.Stretch
		pivot(raysImage)
	end

	local cubes = buildCubes(content, look, layout)
	local ribbon, sub = buildRibbon(content, look, layout, won)
	local hero = buildHero(content, layout, won)
	local stats = buildStats(content, look, layout, summary)
	local buttonParts = buildButton(content, look, layout, won)
	local button = buttonParts.button

	local played = EndScreenMotion.play({
		won = won,
		root = root,
		size = CANVAS,
		inside = inside,
		heroCentre = layout.heroCentre,
		ribbon = ribbon,
		sub = sub,
		hero = hero,
		rays = rays,
		cubes = cubes,
		behind = behind,
		over = over,
		statsGroup = stats.group,
		rows = stats.rows,
		counts = stats.counts,
		setProgress = stats.setProgress,
		percent = stats.percent,
		rewards = stats.rewards,
		rewardCounts = stats.rewardCounts,
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
	--[[ Load the screens' images now, in the background: a run can end at
	     any moment, and art fetched only then pops in after the screen
	     (seen in Studio: the icons and the retry arrow came in late). ]]
	local images: { string } = {}
	for _, id in EndScreenAssets :: any do
		if type(id) == "string" then
			table.insert(images, id)
		end
	end
	local chests: { [string]: string } = EndScreenAssets.chests
	for _, id in chests do
		table.insert(images, id)
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(images)
	end)
end

return EndScreen
