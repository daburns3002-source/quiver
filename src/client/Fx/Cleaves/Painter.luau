--!strict
--[[
	Lays a cleave's draw list (`Fx/Cleaves/Canvas`) over the ground: every
	quad of a strip is one flat Beam between two Attachments, its width,
	colour and opacity running from one end to the other, so a band keeps
	its taper and its gradient. A glow, sparkle or ring is a beam with one
	of the textures every client ships (`Canvas.SOFT` and the rest). A
	'lighter' quad (the page's additive blending) is a beam with
	LightEmission.

	Immediate mode over a pool: each frame `begin`, `paint` per live
	cleave, `finish`, which switches off the beams no one used. A beam's
	properties are written only when they change. The pool stops at the
	device's budget (`budgetFor`), dropping what is drawn last (motes) over
	that.

	Presentation only: anchored, untouchable, under the camera, local.
]]

local Workspace = game:GetService("Workspace")

local Canvas = require(script.Parent.Canvas)

local Painter = {}

--[[ A beam with FaceCamera off takes its width along its attachments'
     Y axis (seen in Studio, 2026-11-19: with Y up the bands stood on edge
     as walls). Both attachments are turned so Y runs across the strip,
     flat over the floor. ]]
local UP = Vector3.yAxis

type Slot = {
	beam: Beam,
	a0: Attachment,
	a1: Attachment,
	on: boolean,
	w0: number,
	w1: number,
	light: number,
	tex: string,
	z: number,
	r0: number,
	g0: number,
	b0: number,
	r1: number,
	g1: number,
	b1: number,
	t0: number,
	t1: number,
	--[[ The attachments' last places. ]]
	p0: CFrame,
	p1: CFrame,
}

--[[ A set of beams drawn together, begun and finished each frame by one
     driver: the cleaves' (`Painter`'s own functions) or another's from
     `Painter.pool` (the projectile shots', `Fx/Shots/Play`), so neither
     switches off the other's beams. `cap` is its beams on a strong device. ]]
export type Pool = {
	name: string,
	cap: number,
	holder: Part?,
	slots: { Slot },
	used: number,
	budget: number,
}

local function newPool(name: string, cap: number): Pool
	return { name = name, cap = cap, holder = nil, slots = {}, used = 0, budget = cap }
end

local default = newPool("BladeCleaves", 900)

local function ensureHolder(pool: Pool): Part
	local part = pool.holder
	if part and part.Parent then
		return part
	end
	local made = Instance.new("Part")
	made.Name = pool.name
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Transparency = 1
	made.Size = Vector3.new(0.1, 0.1, 0.1)
	made.CFrame = CFrame.identity
	made.Parent = Workspace.CurrentCamera
	pool.holder = made
	-- the old pool lived in the old part
	pool.slots = {}
	return made
end

local function newSlot(part: Part): Slot
	local a0 = Instance.new("Attachment")
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Parent = part
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = false
	beam.Segments = 1
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.LightInfluence = 0
	beam.LightEmission = 0
	beam.Brightness = 1
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.TextureLength = 1
	beam.TextureSpeed = 0
	beam.Texture = ""
	beam.Enabled = false
	beam.Parent = part
	return {
		beam = beam,
		a0 = a0,
		a1 = a1,
		on = false,
		w0 = -1,
		w1 = -1,
		light = 0,
		tex = "",
		z = 0,
		r0 = -1,
		g0 = -1,
		b0 = -1,
		r1 = -1,
		g1 = -1,
		b1 = -1,
		t0 = -1,
		t1 = -1,
		p0 = CFrame.identity,
		p1 = CFrame.identity,
	}
end

--[[ Beams a device draws at most, all live cleaves together. ]]
function Painter.budgetFor(detail: number): number
	return math.floor(default.cap * detail)
end

--[[ Another driver's own beams, under their own part named `name`. ]]
function Painter.pool(name: string, cap: number): Pool
	return newPool(name, cap)
end

--[[ Makes `count` beams ahead of the first swing, so it does not hitch. ]]
function Painter.warmIn(pool: Pool, count: number)
	local part = ensureHolder(pool)
	while #pool.slots < count do
		table.insert(pool.slots, newSlot(part))
	end
end
function Painter.warm(count: number)
	Painter.warmIn(default, count)
end

function Painter.beginIn(pool: Pool, detail: number)
	pool.used = 0
	pool.budget = math.floor(pool.cap * detail)
end
function Painter.begin(detail: number)
	Painter.beginIn(default, detail)
end

local function take(pool: Pool): Slot?
	if pool.used >= pool.budget then
		return nil
	end
	pool.used += 1
	local slot = pool.slots[pool.used]
	if not slot then
		slot = newSlot(ensureHolder(pool))
		pool.slots[pool.used] = slot
	end
	return slot
end

local function channel(v: number): number
	return math.clamp(v, 0, 255) / 255
end

--[[ Draws one cleave's items. `origin` is the swinger's spot (at the
     streak's height, facing the swing); `(px, py)` is the swinger on the
     page and `s` its pixels to a stud; `zBase` lifts a newer cleave's
     drawing over an older one's. ]]
function Painter.paintIn(
	pool: Pool,
	items: { Canvas.Item },
	origin: CFrame,
	px: number,
	py: number,
	s: number,
	zBase: number
)
	local base = origin.Position
	local right = origin.RightVector
	local back = -origin.LookVector
	local order = 0
	for _, item in items do
		local n = #item.ax
		if n < 2 then
			continue
		end
		order += 1
		local lift = UP * item.lift
		local tex = item.tex or ""
		local light = if item.light then 1 else 0
		-- each sample's centre, width and across, in the world
		local frames: { CFrame } = table.create(n)
		local widths: { number } = table.create(n)
		local lastAcross = right
		for i = 1, n do
			local ax, ay = (item.ax[i] - px) / s, (item.ay[i] - py) / s
			local bx, by = (item.bx[i] - px) / s, (item.by[i] - py) / s
			local a = right * ax + back * ay
			local b = right * bx + back * by
			local across = a - b
			local width = across.Magnitude
			if width > 1e-4 then
				across /= width
			else
				-- a point: across the strip's way
				local j = if i < n then i + 1 else i - 1
				local ox, oy = (item.ax[j] - px) / s, (item.ay[j] - py) / s
				local way = right * ox + back * oy - a
				if way.Magnitude > 1e-4 then
					across = UP:Cross(way.Unit)
				else
					across = lastAcross
				end
			end
			lastAcross = across
			local centre = base + lift + (a + b) * 0.5
			frames[i] = CFrame.fromMatrix(centre, UP:Cross(across), across)
			widths[i] = width
		end
		for i = 1, n - 1 do
			local slot = take(pool)
			if not slot then
				return
			end
			local beam = slot.beam
			--[[ What stays still (a held cleave) costs no writes. ]]
			local f0, f1 = frames[i], frames[i + 1]
			if f0 ~= slot.p0 then
				slot.a0.CFrame = f0
				slot.p0 = f0
			end
			if f1 ~= slot.p1 then
				slot.a1.CFrame = f1
				slot.p1 = f1
			end
			local w0, w1 = widths[i], widths[i + 1]
			if w0 ~= slot.w0 then
				beam.Width0 = w0
				slot.w0 = w0
			end
			if w1 ~= slot.w1 then
				beam.Width1 = w1
				slot.w1 = w1
			end
			local c0, c1 = item.cols[i], item.cols[i + 1]
			if
				c0[1] ~= slot.r0
				or c0[2] ~= slot.g0
				or c0[3] ~= slot.b0
				or c1[1] ~= slot.r1
				or c1[2] ~= slot.g1
				or c1[3] ~= slot.b1
			then
				beam.Color = ColorSequence.new(
					Color3.new(channel(c0[1]), channel(c0[2]), channel(c0[3])),
					Color3.new(channel(c1[1]), channel(c1[2]), channel(c1[3]))
				)
				slot.r0, slot.g0, slot.b0 = c0[1], c0[2], c0[3]
				slot.r1, slot.g1, slot.b1 = c1[1], c1[2], c1[3]
			end
			local t0, t1 = 1 - item.alphas[i], 1 - item.alphas[i + 1]
			if t0 ~= slot.t0 or t1 ~= slot.t1 then
				beam.Transparency = NumberSequence.new(t0, t1)
				slot.t0, slot.t1 = t0, t1
			end
			if light ~= slot.light then
				beam.LightEmission = light
				slot.light = light
			end
			if tex ~= slot.tex then
				beam.Texture = tex
				slot.tex = tex
			end
			--[[ Drawn in the page's order: what comes later sits on top. ]]
			local z = zBase + order * 0.0003
			if z ~= slot.z then
				beam.ZOffset = z
				slot.z = z
			end
			if not slot.on then
				beam.Enabled = true
				slot.on = true
			end
		end
	end
end

function Painter.paint(
	items: { Canvas.Item },
	origin: CFrame,
	px: number,
	py: number,
	s: number,
	zBase: number
)
	Painter.paintIn(default, items, origin, px, py, s, zBase)
end

--[[ Switches off the beams this frame did not use. ]]
function Painter.finishIn(pool: Pool)
	local slots = pool.slots
	for i = pool.used + 1, #slots do
		local slot = slots[i]
		if not slot.on then
			break
		end
		slot.beam.Enabled = false
		slot.on = false
	end
end
function Painter.finish()
	Painter.finishIn(default)
end

--[[ Beams in use this frame (for a probe). ]]
function Painter.countIn(pool: Pool): number
	return pool.used
end
function Painter.count(): number
	return default.used
end

return Painter
