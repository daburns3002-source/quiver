--!strict
--[[
	A Mythic card is dealt face down and revealed with ceremony
	(design_handoff_upgrade_cards; README "Mythic flip reveal" and the
	Mythic border lightning).

	This builds the card's back — the Glow Toy set's red rune-eye back
	(2026-10-24) over a red glow — and the lightning that runs round the face once it is
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

local SIZE = CardTheme.card.size
local TIMING = CardTheme.timing

local RED = Color3.fromRGB(232, 32, 46)

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

--[[ The face-down card, at the card's own size: the Glow Toy set's Mythic
     back (2026-10-24), its red rune-eye on obsidian, over a red glow. ]]
function MythicReveal.buildBack(): Frame
	local root = frame(nil :: any, "MythicBack", 1)
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(SIZE.X, SIZE.Y)

	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Image = CardAssets.glow
	glow.ImageColor3 = RED
	glow.ImageTransparency = 0.5
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(SIZE.X * 1.9, SIZE.Y * 1.35)
	glow.ZIndex = 1
	glow.Parent = root

	local back = Instance.new("ImageLabel")
	back.Name = "Back"
	back.BackgroundTransparency = 1
	back.Image = CardAssets.mythicBack
	back.AnchorPoint = Vector2.new(0.5, 0.5)
	back.Position = UDim2.fromScale(0.5, 0.5)
	--[[ Sized as the face's body is (`CardBuilder`): the crystal in the
	     398 x 960 art, 326 wide with its middle at 497.5, fills the card. ]]
	local scale = SIZE.X / 326
	back.Position = UDim2.new(0.5, 0, 0.5, (480 - 497.5) * scale)
	back.Size = UDim2.fromOffset(398 * scale, 960 * scale)
	back.ZIndex = 2
	back.Parent = root

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
