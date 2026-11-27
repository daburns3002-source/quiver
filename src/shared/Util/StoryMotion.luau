--!strict
--[[
	What the story cutscene draws at a moment (`Config/StoryMotion`): pure, so
	`UI/StoryCutscene` draws it from one clock and `tests/StoryMotion.spec`
	pins it. A port of the approved Claude Design project's `cutscene.jsx`.

	`StoryMotion.draw` fills a `Scene` in place every frame (no tables made
	per frame): the groups on screen, each its camera, its opacity, its frames'
	opacities and its pixel overlays, then the overlays across the whole
	screen, the flash and the black. Everything is in stage pixels; overlay
	blocks are already on whole pixels.
]]

local Config = require(script.Parent.Parent.Config.StoryMotion)

local StoryMotion = {}

export type Rects = {
	n: number,
	x: { number },
	y: { number },
	w: { number },
	h: { number },
	colour: { Color3 },
	alpha: { number },
}

export type Layer = {
	group: number,
	opacity: number,
	s: number,
	tx: number,
	ty: number,
	--[[ The frames showing (frame numbers) and how opaque each is. ]]
	count: number,
	frames: { number },
	alphas: { number },
	rects: Rects,
}

export type Scene = {
	count: number,
	layers: { Layer },
	screen: Rects,
	flash: number,
	black: number,
}

type Timed = {
	g: Config.Group,
	gs: number,
	ge: number,
	dIn: number,
	a: number,
	b: number,
}

--[[ When each frame starts, from the first frame (frame numbers 1 to n),
     and when the last ends. ]]
export type Cues = { starts: { number }, black: number }

local IMAGE = Config.image
local NONE: { { number } } = {}
local DEFAULT_DISSOLVE = 0.14

local function c01(v: number): number
	return if v < 0 then 0 elseif v > 1 then 1 else v
end

local function lerp(a: number, b: number, u: number): number
	return a + (b - a) * u
end

--[[ Rises over `f` after `a` and falls over `f` before `b`. ]]
local function env(t: number, a: number, b: number, f: number): number
	return c01(math.min((t - a) / f, (b - t) / f))
end

local function round(v: number): number
	return math.floor(v + 0.5)
end

local function snapPx(v: number, g: number): number
	return round(v / g) * g
end

--[[ The same pseudo-random number for the same `i`, as the Design has it. ]]
local function rnd(i: number): number
	local x = math.sin(i * 127.1 + 311.7) * 43758.5453
	return x - math.floor(x)
end

local EASE: { [string]: (number) -> number } = {
	drift = function(u)
		return -(math.cos(math.pi * u) - 1) / 2
	end,
	snap = function(u)
		return if u == 1 then 1 else 1 - 2 ^ (-10 * u)
	end,
	glide = function(u)
		return u
	end,
}

--[[ Each sprite as runs of one colour along a row (fewer blocks to draw,
     the same picture). ]]
type Run = { col: number, row: number, len: number, colour: Color3, dim: number }
local RUNS: { [string]: { cols: number, rows: number, runs: { Run } } } = {}
for name, rows in Config.sprites do
	local runs = {}
	for r, row in rows do
		local c = 1
		while c <= #row do
			local ch = row:sub(c, c)
			local len = 1
			while c + len <= #row and row:sub(c + len, c + len) == ch do
				len += 1
			end
			if ch ~= "." then
				table.insert(runs, {
					col = c - 1,
					row = r - 1,
					len = len,
					colour = Config.palette[ch],
					dim = Config.dim[ch] or 1,
				})
			end
			c += len
		end
	end
	RUNS[name] = { cols = #rows[1], rows = #rows, runs = runs }
end
local LEAVES = { "leafA", "leafC", "leafB" }

local function newRects(): Rects
	return { n = 0, x = {}, y = {}, w = {}, h = {}, colour = {}, alpha = {} }
end

function StoryMotion.newScene(): Scene
	return { count = 0, layers = {}, screen = newRects(), flash = 0, black = 1 }
end

--[[ The frames' start times from their holds, in show order. ]]
function StoryMotion.cues(holds: { number }): Cues
	local starts, at = {}, 0
	for i, hold in holds do
		starts[i] = at
		at += hold
	end
	return { starts = starts, black = at }
end

local function finish(cues: Cues, n: number): number
	return if n >= #cues.starts then cues.black else cues.starts[n + 1]
end

local timedFor: { [Config.Layout]: { cues: Cues, list: { Timed } } } = {}

local function timing(layout: Config.Layout, cues: Cues): { Timed }
	local known = timedFor[layout]
	if known and known.cues == cues then
		return known.list
	end
	local list = {}
	for i, g in layout.groups do
		local dIn = g.dIn or DEFAULT_DISSOLVE
		local nextGroup = layout.groups[i + 1]
		local dOut = if nextGroup then nextGroup.dIn or DEFAULT_DISSOLVE else 0
		local gs = cues.starts[g.f[1]]
		local ge = finish(cues, g.f[#g.f])
		list[i] = { g = g, gs = gs, ge = ge, dIn = dIn, a = gs - dIn / 2, b = ge + dOut / 2 }
	end
	timedFor[layout] = { cues = cues, list = list }
	return list
end

local function noise(t: number, seed: number): number
	return math.sin(t * 47 + seed) * 0.6 + math.sin(t * 83 + seed * 2.3) * 0.4
end

local function push(
	r: Rects,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3,
	alpha: number
)
	local n = r.n + 1
	r.n = n
	r.x[n], r.y[n], r.w[n], r.h[n], r.colour[n], r.alpha[n] = x, y, w, h, colour, alpha
end

type Cam = { s: number, tx: number, ty: number }
local SCREEN_CAM: Cam = { s = 1, tx = 0, ty = 0 }

local function sprite(
	r: Rects,
	stage: Vector2,
	name: string,
	p: number,
	x: number,
	y: number,
	scale: number,
	op: number,
	cam: Cam
)
	if op <= 0.003 then
		return
	end
	local s = RUNS[name]
	local q = math.max(1, round(p * scale * cam.s))
	local ox = round(cam.tx + x * cam.s - s.cols * q / 2)
	local oy = round(cam.ty + y * cam.s - s.rows * q / 2)
	if ox > stage.X or oy > stage.Y or ox + s.cols * q < 0 or oy + s.rows * q < 0 then
		return
	end
	for _, run in s.runs do
		push(r, ox + run.col * q, oy + run.row * q, run.len * q, q, run.colour, op * run.dim)
	end
end

local function block(
	r: Rects,
	stage: Vector2,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3,
	op: number
)
	if op <= 0.003 then
		return
	end
	local bx, by = round(x), round(y)
	local bw, bh = math.max(1, round(w)), math.max(1, round(h))
	if bx > stage.X or by > stage.Y or bx + bw < 0 or by + bh < 0 then
		return
	end
	push(r, bx, by, bw, bh, colour, op)
end

local function camera(layout: Config.Layout, timed: Timed, t: number, cues: Cues): Cam
	local g = timed.g
	local p = c01((t - timed.a) / (timed.b - timed.a))
	local u = EASE[g.e](p)
	local uc = EASE[g.ec or g.e](p)
	local s = lerp(g.s[1], g.s[2], u)
	local cx = lerp(g.c[1][1], g.c[2][1], uc)
	local cy = lerp(g.c[1][2], g.c[2][2], uc)
	for _, kick in g.kicks or NONE do
		local t0 = cues.starts[kick[1]]
		if t >= t0 then
			s += kick[2] * math.exp(-(t - t0) * 10)
		end
	end
	local amp = g.rumble or 0
	for _, shake in g.shakes or NONE do
		local t0 = cues.starts[shake[1]]
		if t >= t0 then
			amp += shake[2] * math.exp(-(t - t0) * shake[3])
		end
	end
	s *= layout.base
	local shx = snapPx(amp * noise(t, 1.7), 2)
	local shy = snapPx(amp * noise(t, 5.1) * 0.7, 2)
	local stage = layout.stage
	local tx = math.min(0, math.max(stage.X - IMAGE.X * s, stage.X / 2 - cx * s + shx))
	local ty = math.min(0, math.max(stage.Y - IMAGE.Y * s, stage.Y / 2 - cy * s + shy))
	return { s = s, tx = tx, ty = ty }
end

local function ring(
	r: Rects,
	stage: Vector2,
	cx: number,
	cy: number,
	radius: number,
	sy: number,
	op: number,
	cam: Cam
)
	local n = math.max(24, math.min(120, round(2 * math.pi * radius / 18)))
	local b = round((8 + radius * 0.012) / 2) * 2
	local size = math.max(1, round(b * cam.s))
	for j = 0, n - 1 do
		local th = (j / n) * math.pi * 2
		local x = cx + math.cos(th) * radius
		local y = cy + math.sin(th) * radius * sy
		if x < -20 or x > IMAGE.X + 20 or y < -20 or y > IMAGE.Y + 20 then
			continue
		end
		block(
			r,
			stage,
			cam.tx + snapPx(x - b / 2, 4) * cam.s,
			cam.ty + snapPx(y - b / 2, 4) * cam.s,
			size,
			size,
			Config.ringColour,
			op
		)
	end
end

--[[ The overlays that move with a group's camera. ]]
local function groupFx(
	r: Rects,
	layout: Config.Layout,
	timed: Timed,
	t: number,
	cues: Cues,
	cam: Cam
)
	local g = timed.g
	local stage = layout.stage
	local steam = g.steam
	if steam then
		local e = env(t, timed.gs - 0.1, timed.ge, 0.25)
		if e > 0 then
			local big = if g.bigSteamAt and t >= cues.starts[g.bigSteamAt] then 1.5 else 1
			local life, count = 0.9, 6
			for k, vent in steam do
				for i = 0, count - 1 do
					local age = (((t - timed.gs) + i * life / count) % life + life) % life
					local q = age / life
					sprite(
						r,
						stage,
						"puff",
						5,
						vent[1] + vent[3] * (30 + q * 120),
						vent[2] - q * 90 - rnd(i + (k - 1) * 9) * 10,
						(0.8 + q * 2.4) * big,
						e * (1 - q) * 0.9,
						cam
					)
				end
			end
		end
	end
	local roar = g.roar
	if roar then
		local bursts = { { cues.starts[g.f[1]], 26, 1 }, { cues.starts[g.f[2]], 14, 0.7 } }
		for bi, burst in bursts do
			local a = t - burst[1]
			if a < 0 or a > 1.6 then
				continue
			end
			local seed = (bi - 1) * 50
			for i = 0, burst[2] - 1 do
				local th = rnd(i * 3 + seed) * math.pi * 2
				local v = (350 + rnd(i * 7 + seed) * 550) * burst[3]
				sprite(
					r,
					stage,
					"drop",
					6,
					roar[1] + math.cos(th) * v * a,
					roar[2] + math.sin(th) * v * a + 450 * a * a,
					1 + rnd(i + 11) * 0.8,
					c01(1.4 - a),
					cam
				)
			end
		end
		for k = 0, 5 do
			local a = t - (timed.gs + k * 0.3)
			if a >= 0 and a <= 1.2 then
				ring(r, stage, roar[1], roar[2], 60 + 1000 * a ^ 0.8, 1, (1 - a / 1.2) * 0.75, cam)
			end
		end
	end
	if g.wave then
		for k = 0, 4 do
			local a = t - (timed.gs - 0.2 + k * 0.45)
			if a >= 0 and a <= 1.6 then
				ring(r, stage, -150, 380, 300 + 800 * a, 0.7, (1 - a / 1.6) * 0.7, cam)
			end
		end
	end
	local rustle = g.rustle
	if rustle then
		local t0 = cues.starts[8]
		for i = 0, 6 do
			local a = t - t0 - i * 0.06
			if a < 0 or a > 1.4 then
				continue
			end
			local vx = (rnd(i + 3) - 0.5) * 360
			local vy = -220 - rnd(i + 8) * 160
			sprite(
				r,
				stage,
				LEAVES[math.floor(t * 8 + i) % 3 + 1],
				6,
				rustle[1] + vx * a + math.sin(a * 6 + i) * 20,
				rustle[2] + vy * a + 260 * a * a,
				1,
				c01((1.4 - a) * 2),
				cam
			)
		end
	end
	if g.sparkle then
		for i, at in Config.sparks do
			local w = math.max(0, math.sin(t * 5 + (i - 1) * 1.9))
			sprite(
				r,
				stage,
				"spark",
				5,
				at[1],
				at[2],
				0.6 + w * 0.6,
				w * env(t, timed.gs - 0.1, timed.ge, 0.2),
				cam
			)
		end
	end
end

--[[ How strongly an overlay that belongs to some groups shows now. ]]
local function windowEnv(list: { Timed }, t: number, key: string, fade: number): number
	local e = 0
	for _, timed in list do
		local v = (timed.g :: any)[key]
		if v then
			local strength = if v == true then 1 else v :: number
			e = math.max(e, env(t, timed.gs - 0.05, timed.ge + 0.05, fade) * strength)
		end
	end
	return e
end

--[[ The overlays across the whole screen. ]]
local function screenFx(r: Rects, layout: Config.Layout, list: { Timed }, t: number)
	local stage = layout.stage
	local ff = windowEnv(list, t, "ff", 0.3)
	if ff > 0 then
		local spec = layout.fireflies
		for i = 0, spec.count - 1 do
			local x = spec.x + rnd(i) * spec.w + math.sin(t * 0.5 + i * 2.1) * 34
			local y = 60
				+ rnd(i + 40) * spec.h
				+ math.sin(t * 0.7 + i * 1.3) * 22
				- ((t * 8 + i * 30) % 60)
			local twinkle = (0.5 + 0.5 * math.sin(t * 3 + i * 4.7)) ^ 2
			sprite(r, stage, "fly", 4, x, y, 1, ff * (0.25 + twinkle * 0.75), SCREEN_CAM)
		end
	end
	local wind = windowEnv(list, t, "wind", 0.15)
	if wind > 0 then
		local n = round(26 * wind)
		local op = math.min(1, wind * 2)
		for i = 0, n - 1 do
			local speed = 0.55 + rnd(i + 70) * 0.6
			local u = (t * speed + rnd(i + 90)) % 1
			local x = -80 + u * (stage.X + 160)
			local y = 40 + rnd(i + 110) * (stage.Y - 100) + math.sin(t * 4 + i) * 30 - u * 80
			sprite(
				r,
				stage,
				LEAVES[math.floor(t * 9 + i) % 3 + 1],
				5 + (i % 3),
				x,
				y,
				1,
				op,
				SCREEN_CAM
			)
		end
	end
	local fall = windowEnv(list, t, "fall", 0.3)
	if fall > 0 then
		local fx = layout.fallX
		for i = 0, 4 do
			local u = (t * 0.18 + rnd(i + 200)) % 1
			sprite(
				r,
				stage,
				LEAVES[math.floor(t * 3 + i) % 3 + 1],
				5,
				fx[1] + rnd(i + 220) * fx[2] + math.sin(t * 1.5 + i) * 40,
				-40 + u * (stage.Y + 80),
				1,
				fall,
				SCREEN_CAM
			)
		end
	end
	local speed = windowEnv(list, t, "speed", 0.08)
	if speed > 0 then
		local spec = layout.speed
		for i = 0, 13 do
			local len = 80 + rnd(i + 300) * 160
			local x = spec.x + ((t * 1600 + rnd(i + 310) * spec.span) % spec.span)
			local y = snapPx(spec.y + rnd(i + 320) * spec.h, 4)
			block(
				r,
				stage,
				snapPx(x, 4),
				y,
				snapPx(len, 4),
				if i % 3 == 0 then 6 else 4,
				Color3.new(1, 1, 1),
				speed * 0.6 * c01((x - spec.x) / spec.fade)
			)
		end
	end
	local zoom = windowEnv(list, t, "zoomLines", 0.2)
	if zoom > 0 then
		local from = layout.zoomFrom
		for i = 0, 19 do
			local th = rnd(i + 400) * math.pi * 2
			if th > math.pi * 0.3 and th < math.pi * 0.7 then
				th += math.pi * 0.9
			end
			local radius = 260 + ((t * 900 + rnd(i + 410) * 600) % 600)
			local len = 60 + rnd(i + 420) * 90
			local op = zoom * 0.5 * c01((radius - 260) / 120)
			if op <= 0.003 then
				continue
			end
			local sx, sy = from.X + math.cos(th) * radius, from.Y + math.sin(th) * radius
			local lx, ly = math.huge, math.huge
			for k = 0, len, 2 do
				local gx = math.floor((sx + math.cos(th) * k) / 4) * 4
				local gy = math.floor((sy + math.sin(th) * k + 2) / 4) * 4
				if gx ~= lx or gy ~= ly then
					lx, ly = gx, gy
					block(r, stage, gx, gy, 4, 4, Color3.new(1, 1, 1), op)
				end
			end
		end
	end
end

--[[ Fills `scene` for `t` seconds after the first frame. `ready(n)` says
     whether frame `n` can draw: one that cannot is left out, and the frame
     before it stays up instead (in its own group, or the group before). ]]
function StoryMotion.draw(
	scene: Scene,
	layout: Config.Layout,
	cues: Cues,
	t: number,
	ready: (number) -> boolean
)
	local list = timing(layout, cues)
	scene.count = 0
	scene.screen.n = 0
	scene.flash = 0
	for i, timed in list do
		local g = timed.g
		if g.flash then
			local t0 = cues.starts[g.flash]
			if t >= t0 then
				scene.flash =
					math.max(scene.flash, c01(1 - (t - t0) / Config.flashFor) * Config.flashPeak)
			end
		end
		local nextTimed = list[i + 1]
		local held = nextTimed ~= nil and not ready(nextTimed.g.f[1])
		if t < timed.a or (t >= timed.b and not held) then
			continue
		end
		local index = scene.count + 1
		local layer = scene.layers[index]
		if not layer then
			layer = {
				group = 0,
				opacity = 0,
				s = 1,
				tx = 0,
				ty = 0,
				count = 0,
				frames = {},
				alphas = {},
				rects = newRects(),
			}
			scene.layers[index] = layer
		end
		scene.count = index
		local cam = camera(layout, timed, t, cues)
		layer.group = i
		layer.opacity = if timed.dIn > 0
			then c01((t - timed.a) / timed.dIn)
			elseif t >= timed.gs then 1
			else 0
		layer.s, layer.tx, layer.ty = cam.s, cam.tx, cam.ty
		layer.count = 0
		local pair = g.dPair or 0.3
		for j, n in g.f do
			if not ready(n) then
				continue
			end
			local fs = cues.starts[n]
			local last = j == #g.f
			local nextReady = not last and ready(g.f[j + 1])
			local fa = if j == 1 then -math.huge else fs - pair / 2
			local fb = if last or not nextReady then math.huge else finish(cues, n) + pair / 2
			if t >= fa and t < fb then
				layer.count += 1
				layer.frames[layer.count] = n
				layer.alphas[layer.count] = if j == 1 then 1 else c01((t - fa) / pair)
			end
		end
		layer.rects.n = 0
		groupFx(layer.rects, layout, timed, t, cues, cam)
	end
	screenFx(scene.screen, layout, list, t)
	scene.black = math.max(
		c01(1 - t / Config.fadeIn),
		c01((t - (cues.black - Config.fadeOut)) / Config.fadeOut)
	)
end

return StoryMotion
