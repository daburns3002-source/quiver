--!strict
--[[
	The little that moves on the title picture (owner, 2026-10-26; see
	`Config/Intro.motion`): light sliding over the ponds with a few glints,
	and leaves falling from the left side's Mossy Glade tree and bushes. The
	picture itself stays still.

	Everything lives inside the picture's frame (`UI/IntroCutscene`'s
	"Picture"), placed by scale in the art's own pixels, so it stays on the
	art however the screen is shaped. Posed from the cutscene's clock, and
	faded with the picture as BEGIN ADVENTURE is pressed. Presentation only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Intro = require(ReplicatedStorage.Shared.Config.Intro)

local TitleMotion = {}

type Leaf = {
	image: ImageLabel,
	born: number,
	life: number,
	x: number,
	y: number,
	fall: number,
	drift: number,
	sway: number,
	phase: number,
	spin: number,
}
type Glint = { frame: Frame, born: number, x: number, y: number }

export type Motion = {
	picture: Frame,
	water: ImageLabel,
	band: UIGradient,
	leaves: { Leaf },
	glints: { Glint },
	nextLeaf: number,
	nextGlint: number,
	random: Random,
}

local W, H = Intro.picture.width, Intro.picture.height

local function between(random: Random, range: { number }): number
	return random:NextNumber(range[1], range[2])
end

-- a point in title pixels as a position inside the picture
local function at(x: number, y: number): UDim2
	return UDim2.fromScale(x / W, y / H)
end

function TitleMotion.build(picture: Frame): Motion
	picture.ClipsDescendants = true
	local w = Intro.motion.water
	local water = Instance.new("ImageLabel")
	water.Name = "Water"
	water.BackgroundTransparency = 1
	water.Image = w.image
	water.Position = at(w.box.x, w.box.y)
	water.Size = UDim2.fromScale(w.box.w / W, w.box.h / H)
	water.ZIndex = 4
	water.Parent = picture
	local band = Instance.new("UIGradient")
	band.Parent = water
	return {
		picture = picture,
		water = water,
		band = band,
		leaves = {},
		glints = {},
		nextLeaf = 0,
		nextGlint = 0,
		random = Random.new(),
	}
end

local function spawnLeaf(m: Motion, t: number)
	local c = Intro.motion.leaves
	local from = c.from[m.random:NextInteger(1, #c.from)]
	local frame = m.random:NextInteger(0, 3)
	local image = Instance.new("ImageLabel")
	image.Name = "Leaf"
	image.BackgroundTransparency = 1
	image.Image = c.sheet
	image.ImageRectSize = Vector2.new(c.cell, c.cell)
	image.ImageRectOffset = Vector2.new((frame % 2) * c.cell, (frame // 2) * c.cell)
	local size = between(m.random, c.size)
	image.Size = UDim2.fromScale(size / W, size / H)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.ImageTransparency = 1
	image.ZIndex = 5
	image.Parent = m.picture
	table.insert(m.leaves, {
		image = image,
		born = t,
		life = between(m.random, c.life),
		x = from.x + m.random:NextNumber() * from.w,
		y = from.y + m.random:NextNumber() * from.h,
		fall = between(m.random, c.fall),
		drift = between(m.random, c.drift),
		sway = between(m.random, c.sway),
		phase = m.random:NextNumber(0, 2 * math.pi),
		spin = m.random:NextNumber(-40, 40),
	})
end

local function spawnGlint(m: Motion, t: number)
	local spots = Intro.motion.water.spots
	local spot = spots[m.random:NextInteger(1, #spots)]
	local frame = Instance.new("Frame")
	frame.Name = "Glint"
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color3.fromRGB(235, 255, 255)
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromScale(5 / W, 3 / H)
	frame.ZIndex = 5
	frame.Parent = m.picture
	table.insert(m.glints, { frame = frame, born = t, x = spot[1], y = spot[2] })
end

--[[ Poses it all at `t` seconds since the picture appeared; `fade` 0 to 1
     as the title leaves. ]]
function TitleMotion.step(m: Motion, t: number, fade: number)
	local w = Intro.motion.water
	-- the band of light: a soft bright stripe crossing left to right, round and round
	local k = (t % w.period) / w.period
	local clear = 1 - w.strength * (1 - fade)
	m.band.Offset = Vector2.new(k * 2 - 1, 0)
	m.band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, clear),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})

	if fade <= 0 and t >= m.nextGlint then
		m.nextGlint = t + w.glintEvery * m.random:NextNumber(0.6, 1.4)
		spawnGlint(m, t)
	end
	for i = #m.glints, 1, -1 do
		local g = m.glints[i]
		local a = (t - g.born) / w.glintLife
		if a >= 1 then
			g.frame:Destroy()
			table.remove(m.glints, i)
		else
			g.frame.Position = at(g.x + w.glintDrift * a, g.y)
			g.frame.BackgroundTransparency = 1 - math.sin(a * math.pi) * 0.85 * (1 - fade)
		end
	end

	local c = Intro.motion.leaves
	if fade <= 0 and t >= m.nextLeaf and #m.leaves < c.most then
		m.nextLeaf = t + c.spawnEvery * m.random:NextNumber(0.6, 1.4)
		spawnLeaf(m, t)
	end
	for i = #m.leaves, 1, -1 do
		local leaf = m.leaves[i]
		local age = t - leaf.born
		if age >= leaf.life then
			leaf.image:Destroy()
			table.remove(m.leaves, i)
		else
			local wave = math.sin(age * 1.6 + leaf.phase)
			leaf.image.Position =
				at(leaf.x + leaf.drift * age + leaf.sway * wave, leaf.y + leaf.fall * age)
			leaf.image.Rotation = leaf.spin * age + 20 * wave
			-- in over half a second, out over the last second
			local show = math.clamp(math.min(age / 0.5, leaf.life - age), 0, 1)
			leaf.image.ImageTransparency = 1 - show * (1 - fade)
		end
	end
end

return TitleMotion
