--!strict
--[[
	A Mythic card is dealt face down and revealed with ceremony
	(design_handoff_upgrade_cards; README "Mythic flip reveal" and the
	Mythic border lightning).

	This builds the card's back — obsidian with red cracks, a crimson crown
	and a rune eye — and the lightning that runs round the face once it is
	up, and says where in the reveal a given moment is. The draft screen
	runs the clock and places the cards; this knows what each moment looks
	like.

	Roblox scales GuiObjects uniformly, so the design's flip (width to zero
	and back) is drawn as a squeeze to a sliver, a flash, and a swap.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local CardTheme = require(ReplicatedStorage.Shared.Config.CardTheme)

local MythicReveal = {}

local INK = CardTheme.colors.ink
local SIZE = CardTheme.card.size
local TIMING = CardTheme.timing

local OBSIDIAN = Color3.fromRGB(26, 5, 11)
local OBSIDIAN_DEEP = Color3.fromRGB(11, 2, 5)
local RED = Color3.fromRGB(232, 32, 46)
local EMBER = Color3.fromRGB(255, 177, 153)

--[[ The moments of a reveal, in seconds from its start. ]]
MythicReveal.shakeEnd = TIMING.mythicShake
MythicReveal.flipEnd = TIMING.mythicShake + TIMING.mythicFlip
MythicReveal.flashAt = 1.35
MythicReveal.raysAt = 1.25
MythicReveal.titleAt = TIMING.mythicTitleAt
MythicReveal.settleEnd = 2.1
--[[ The lightning starts once the face is up, runs, then fades. ]]
MythicReveal.lightningStart = TIMING.mythicShake + TIMING.mythicFlip * 0.5
MythicReveal.lightningEnd = MythicReveal.lightningStart + TIMING.lightningRun + TIMING.lightningFade

local function frame(parent: Instance, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
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

local function stroke(parent: Instance, colour: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = parent
end

local function centred(
	parent: Instance,
	name: string,
	z: number,
	x: number,
	y: number,
	w: number,
	h: number
): Frame
	local f = frame(parent, name, z)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	return f
end

local function glow(
	parent: Instance,
	z: number,
	x: number,
	y: number,
	size: number,
	transparency: number
)
	local g = Instance.new("ImageLabel")
	g.Name = "Glow"
	g.BackgroundTransparency = 1
	g.Image = CardAssets.glow
	g.ImageColor3 = RED
	g.ImageTransparency = transparency
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromOffset(x, y)
	g.Size = UDim2.fromOffset(size, size)
	g.ZIndex = z
	g.Parent = parent
	return g
end

local function shard(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	rot: number,
	colour: Color3
)
	local pivot = centred(parent, "Shard", 1, x, y, w + 7, (h + 7) * 2)
	pivot.BackgroundTransparency = 1
	pivot.Rotation = rot
	local layers: { { any } } = { { INK, w + 7, h + 7, 4 }, { colour, w, h, 0 } }
	for _, layer in layers do
		local i = Instance.new("ImageLabel")
		i.BackgroundTransparency = 1
		i.Image = CardAssets.shard
		i.ImageColor3 = layer[1] :: Color3
		i.AnchorPoint = Vector2.new(0.5, 1)
		i.Position = UDim2.new(0.5, 0, 0.5, layer[4] :: number)
		i.Size = UDim2.fromOffset(layer[2] :: number, layer[3] :: number)
		i.ZIndex = 1
		i.Parent = pivot
	end
end

--[[ The face-down card, at the card's own size. ]]
function MythicReveal.buildBack(): Frame
	local root = frame(nil :: any, "MythicBack", 1)
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(SIZE.X, SIZE.Y)

	-- Crown and bottom cluster, behind the card.
	local mid = SIZE.X / 2
	local crown: { { any } } = {
		{ 0, 26, 70, 0, Color3.fromRGB(255, 59, 71) },
		{ -20, 18, 50, -16, Color3.fromRGB(138, 15, 31) },
		{ 20, 18, 50, 16, Color3.fromRGB(138, 15, 31) },
		{ -38, 14, 34, -34, Color3.fromRGB(61, 10, 20) },
		{ 38, 14, 34, 34, Color3.fromRGB(61, 10, 20) },
	}
	for _, s in crown do
		shard(root, mid + s[1], 4, s[2], s[3], s[4], s[5])
	end
	for _, s in { { 0, 16, 26, 180 }, { -14, 12, 18, 196 }, { 14, 12, 18, 164 } } do
		shard(root, mid + s[1], SIZE.Y - 4, s[2], s[3], s[4], Color3.fromRGB(138, 15, 31))
	end

	local shadow = frame(root, "Shadow", 2)
	shadow.BackgroundColor3 = INK
	shadow.Position = UDim2.fromOffset(0, 7)
	shadow.Size = UDim2.fromScale(1, 1)
	corner(shadow, 18)

	local body = frame(root, "Body", 3)
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.Size = UDim2.fromScale(1, 1)
	corner(body, 18)
	stroke(body, INK, 4)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(OBSIDIAN, OBSIDIAN_DEEP)
	gradient.Parent = body

	-- Dark inner bezel with a thin red neon line.
	local bezel = frame(root, "Bezel", 4)
	bezel.BackgroundTransparency = 1
	bezel.Position = UDim2.fromOffset(6, 6)
	bezel.Size = UDim2.new(1, -12, 1, -12)
	corner(bezel, 13)
	stroke(bezel, Color3.fromRGB(36, 9, 15), 4)
	local neon = frame(root, "Neon", 5)
	neon.BackgroundTransparency = 1
	neon.Position = UDim2.fromOffset(11, 11)
	neon.Size = UDim2.new(1, -22, 1, -22)
	corner(neon, 9)
	stroke(neon, RED, 1.5)

	-- Red cracks across the obsidian, glowing.
	for _, c in
		{
			{ 30, 70, 46, 38 },
			{ 52, 92, 30, -24 },
			{ 98, 230, 52, 62 },
			{ 82, 262, 34, -40 },
			{ 24, 250, 40, 112 },
			{ 108, 60, 28, 120 },
		}
	do
		local crack = centred(root, "Crack", 5, c[1], c[2], c[3], 2)
		crack.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
		crack.Rotation = c[4]
		glow(root, 4, c[1], c[2], c[3] * 1.4, 0.75)
	end

	-- Corner and side jewels.
	for _, p in
		{
			{ 0, 0 },
			{ SIZE.X, 0 },
			{ 0, SIZE.Y },
			{ SIZE.X, SIZE.Y },
			{ 0, SIZE.Y / 2 },
			{ SIZE.X, SIZE.Y / 2 },
		}
	do
		local gem = centred(root, "Jewel", 6, p[1], p[2], 12, 12)
		gem.BackgroundColor3 = RED
		gem.Rotation = 45
		stroke(gem, INK, 3)
	end

	-- The rune eye sigil.
	local cx, cy = SIZE.X / 2, SIZE.Y / 2 - 8
	glow(root, 5, cx, cy, 150, 0.45)
	for _, r in { { 96, 3 }, { 84, 2 }, { 40, 2 } } do
		local ring = centred(root, "SigilRing", 6, cx, cy, r[1], r[1])
		ring.BackgroundTransparency = 1
		corner(ring, 999)
		stroke(ring, RED, r[2])
	end
	local frameDiamond = centred(root, "SigilDiamond", 6, cx, cy, 58, 58)
	frameDiamond.BackgroundTransparency = 1
	frameDiamond.Rotation = 45
	stroke(frameDiamond, RED, 2)
	for index = 0, 7 do
		local a = index * math.pi / 4
		local marker =
			centred(root, "Marker", 7, cx + math.cos(a) * 48, cy + math.sin(a) * 48, 7, 7)
		marker.BackgroundColor3 = RED
		marker.Rotation = 45
	end
	local eye = centred(root, "Eye", 8, cx, cy, 46, 24)
	eye.BackgroundColor3 = RED
	corner(eye, 999)
	stroke(eye, INK, 2)
	local pupil = centred(root, "Pupil", 9, cx, cy, 6, 22)
	pupil.BackgroundColor3 = INK
	corner(pupil, 999)

	local question = Instance.new("TextLabel")
	question.Name = "Unknown"
	question.BackgroundTransparency = 1
	question.AnchorPoint = Vector2.new(0.5, 0)
	question.Position = UDim2.new(0.5, 0, 0, cy + 66)
	question.Size = UDim2.fromOffset(110, 20)
	question.Font = CardTheme.fonts.display
	question.Text = "??????"
	question.TextSize = 15
	question.TextColor3 = EMBER
	question.ZIndex = 9
	question.Parent = root

	return root
end

--[[ The point `distance` along a rounded rectangle's border, and the
     outward normal there, starting at the top middle and running clockwise. ]]
local function border(distance: number, w: number, h: number, r: number): (Vector2, Vector2)
	local straightX, straightY = w - 2 * r, h - 2 * r
	local arc = math.pi * r / 2
	local perimeter = 2 * (straightX + straightY) + 4 * arc
	local d = distance % perimeter

	local segments: { any } = {
		{
			kind = "line",
			length = straightX / 2,
			from = Vector2.new(w / 2, 0),
			dir = Vector2.new(1, 0),
			normal = Vector2.new(0, -1),
		},
		{ kind = "arc", length = arc, centre = Vector2.new(w - r, r), start = -math.pi / 2 },
		{
			kind = "line",
			length = straightY,
			from = Vector2.new(w, r),
			dir = Vector2.new(0, 1),
			normal = Vector2.new(1, 0),
		},
		{ kind = "arc", length = arc, centre = Vector2.new(w - r, h - r), start = 0 },
		{
			kind = "line",
			length = straightX,
			from = Vector2.new(w - r, h),
			dir = Vector2.new(-1, 0),
			normal = Vector2.new(0, 1),
		},
		{ kind = "arc", length = arc, centre = Vector2.new(r, h - r), start = math.pi / 2 },
		{
			kind = "line",
			length = straightY,
			from = Vector2.new(0, h - r),
			dir = Vector2.new(0, -1),
			normal = Vector2.new(-1, 0),
		},
		{ kind = "arc", length = arc, centre = Vector2.new(r, r), start = math.pi },
		{
			kind = "line",
			length = straightX / 2,
			from = Vector2.new(r, 0),
			dir = Vector2.new(1, 0),
			normal = Vector2.new(0, -1),
		},
	}

	for _, seg in segments do
		if d <= seg.length then
			if seg.kind == "line" then
				return (seg.from :: Vector2) + (seg.dir :: Vector2) * d, seg.normal :: Vector2
			end
			local a = (seg.start :: number) + d / r
			local n = Vector2.new(math.cos(a), math.sin(a))
			return (seg.centre :: Vector2) + n * r, n
		end
		d -= seg.length
	end

	return Vector2.new(w / 2, 0), Vector2.new(0, -1)
end

export type Lightning = {
	step: (elapsed: number) -> (),
	destroy: () -> (),
}

--[[
	Three bolts circling the card's border once the face is up: polylines
	sampled every seven pixels along the edge, each point pushed out along
	the edge's normal by a random amount tapered to nothing at the bolt's
	ends, re-rolled about thirty times a second for the crackle. Then they
	grow wild, slow and fade. `elapsed` is seconds since the lightning began.
]]
function MythicReveal.lightning(parent: Instance): Lightning
	local w, h, r = SIZE.X + 4, SIZE.Y + 4, 20
	local perimeter = 2 * ((w - 2 * r) + (h - 2 * r)) + 2 * math.pi * r
	local container = frame(parent, "Lightning", 30)
	container.BackgroundTransparency = 1
	container.Position = UDim2.fromOffset(-2, -2)
	container.Size = UDim2.fromOffset(w, h)

	local SPACING = 7
	local bolts = {}
	for b = 1, TIMING.lightningBolts do
		local segments = {}
		for index = 1, 22 do
			local outer = frame(container, "Bolt", 30)
			outer.AnchorPoint = Vector2.new(0.5, 0.5)
			outer.BackgroundColor3 = CardTheme.colors.lightning
			local core = frame(outer, "Core", 31)
			core.AnchorPoint = Vector2.new(0.5, 0.5)
			core.Position = UDim2.fromScale(0.5, 0.5)
			core.BackgroundColor3 = CardTheme.colors.lightningCore
			segments[index] = { outer = outer, core = core }
		end
		bolts[b] = {
			offset = (b - 1) * perimeter / TIMING.lightningBolts,
			segments = segments,
			jitter = {},
		}
	end

	local rolledAt = -1
	local travelled = 0
	local lastElapsed = 0

	local function step(elapsed: number)
		local run, fade = TIMING.lightningRun, TIMING.lightningFade
		local fading = math.clamp((elapsed - run) / fade, 0, 1)
		local speed = TIMING.lightningSpeed * (1 - 0.7 * fading)
		travelled += speed * math.max(elapsed - lastElapsed, 0)
		lastElapsed = elapsed

		local grow = math.clamp(elapsed / 0.2, 0, 1)
		local length = TIMING.lightningLength * grow * (1 - 0.3 * fading)
		local amp = 8 * (1 + 2 * fading)
		local opacity = (1 - fading) * (if fading > 0 and math.random() < 0.3 then 0.4 else 1)
		local reroll = elapsed - rolledAt >= 0.034
		if reroll then
			rolledAt = elapsed
		end

		for _, bolt in bolts do
			local points = {}
			local count = math.max(math.floor(length / SPACING), 2)
			for index = 0, count do
				local q = index * SPACING
				local p, n = border(bolt.offset + travelled + q, w, h, r)
				if reroll or bolt.jitter[index] == nil then
					bolt.jitter[index] = (math.random() * 2 - 1)
				end
				local taper = math.sin(math.pi * q / math.max(length, 1))
				points[index + 1] = p + n * (bolt.jitter[index] * amp * taper)
			end

			for index, seg in bolt.segments do
				local a, b = points[index], points[index + 1]
				if not a or not b or opacity <= 0 then
					seg.outer.Visible = false
					continue
				end
				local delta = b - a
				seg.outer.Visible = true
				seg.outer.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
				seg.outer.Size = UDim2.fromOffset(delta.Magnitude + 2, 5)
				seg.outer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
				seg.outer.BackgroundTransparency = 1 - opacity
				seg.core.Size = UDim2.new(1, 0, 0, 1.6)
				seg.core.BackgroundTransparency = 1 - opacity
			end
		end
	end

	return {
		step = step,
		destroy = function()
			container:Destroy()
		end,
	}
end

--[[ How the reveal holds the card at `t` seconds: shake, lift, scale and
     which face shows. ]]
function MythicReveal.pose(t: number): (Vector2, number, number, boolean)
	local offset = Vector2.zero
	local scale = 1
	local lift = 0
	local faceUp = t >= MythicReveal.shakeEnd + TIMING.mythicFlip / 2

	if t < MythicReveal.shakeEnd then
		-- A shake that builds.
		local e = t * 1000
		local k = e / 1000
		offset = Vector2.new(math.sin(e * 0.09) * 7 * k, math.cos(e * 0.13) * 4 * k)
		scale = 1 + 0.05 * k
	elseif t < MythicReveal.flipEnd then
		local f = (t - MythicReveal.shakeEnd) / TIMING.mythicFlip
		-- The squeeze through the swap, with the design's lift and swell.
		local squeeze = 1 - math.sin(math.pi * f) * 0.94
		scale = (1.05 + math.sin(math.pi * f) * 0.28) * squeeze
		lift = -math.sin(math.pi * f) * 40
	elseif t < MythicReveal.settleEnd then
		local s = (t - MythicReveal.flipEnd) / (MythicReveal.settleEnd - MythicReveal.flipEnd)
		scale = 1 + 0.08 * math.sin(math.pi * s) * (1 - s)
	end

	return offset, scale, lift, faceUp
end

return MythicReveal
