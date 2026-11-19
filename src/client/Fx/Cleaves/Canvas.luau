--!strict
--[[
	The blade cleaves' drawing kit (owner, 2026-11-19: "unique cleave
	animations ... not the swing itself but the slash that it leaves
	behind"; direction A, a new cleave per blade with no new swing).

	A port of the owner-approved reference page, Blade Cleaves
	(https://claude.ai/artifact/VsZDJFnTWESCg2gnn5Cb9J): the same maths, the
	same seeded hash, the same helpers, in the page's own units (pixels on a
	320 wide card, `GEO.s` of them to a stud), so each cleave in
	`Fx/Cleaves/<Area>` reads line for line as its card's code does and
	draws the same picture.

	Nothing here touches the engine. Drawing appends quads to a draw list
	(`Ctx.items`): a strip of samples, each two points across it (an edge
	each side), with a colour and an opacity; a shape is a short strip, a
	glow, sparkle or ring a textured one. `Fx/Cleaves/Painter` lays the list
	over the ground with pooled Beams, so `tests/BladeCleaves.spec` (and
	Lune, outside Studio) can run every cleave.

	Canvas habits kept: `alpha` is the page's `globalAlpha`, `light` its
	'lighter' blending, `ox`/`oy` a `translate` in the floor's plane, and
	`glowBlur` its `shadowBlur` (a soft halo under what is filled). What the
	page drew as rising or falling (`rise`, `grav` and the chunks that drop)
	goes up or down for real here: `lift`, in studs.
]]

local Canvas = {}

export type RGB = { number }

--[[ One blow's geometry and timing, as the page's `makeInst` builds it:
     centre, outer and inner radius, start and end angle (canvas angles:
     0 is the swinger's right, -pi/2 straight ahead), the dagger's inward
     slant, sweep, hold and fade seconds, and the seed its motes hash. ]]
export type Inst = {
	cx: number,
	cy: number,
	R: number,
	r: number,
	a0: number,
	a1: number,
	sl: number,
	T: number,
	H: number,
	F: number,
	seed: number,
}

export type Item = {
	ax: { number },
	ay: { number },
	bx: { number },
	by: { number },
	cols: { RGB },
	alphas: { number },
	light: boolean,
	lift: number,
	tex: string?,
}

export type Ctx = {
	items: { Item },
	alpha: number,
	light: boolean,
	ox: number,
	oy: number,
	lift: number,
	glowCol: RGB?,
	glowBlur: number,
	--[[ Share of segments and motes drawn: 1 on a strong device. ]]
	detail: number,
	--[[ Pixels to a stud. ]]
	s: number,
}

export type Look = {
	key: string,
	c0: RGB,
	c1: RGB,
	c2: RGB,
	glow: boolean,
}

export type Frame = {
	u0: number,
	u1: number,
	--[[ The radians it spans. ]]
	arc: number,
	ok: boolean,
	rad: (v: number, f: number) -> number,
	p: (v: number, f: number, dr: number?) -> (number, number),
}

export type FrameOpts = {
	prof: ((number) -> number)?,
	thick: number?,
	w: number?,
	rOut: number?,
	mid: number?,
	g: { number }?,
}

export type Wob = (v: number, f: number) -> number

local TAU = math.pi * 2
Canvas.TAU = TAU
Canvas.WHITE = { 255, 255, 255 } :: RGB

--[[ Textures every Roblox client ships with (no uploads): a soft round
     glow, a four-point sparkle and a ring. ]]
Canvas.SOFT = "rbxasset://textures/particles/explosion01_implosion_main.dds"
Canvas.SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
Canvas.RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds"

--[[ A sample every this many radians round a band or line (the page
     draws 30 along any band): 16 along a sword's 100 degrees. ]]
local STEP = math.rad(6.5)
local MOST_SEGS = 24

---------------------------------------------------------------- maths

local function clamp(v: number, a: number?, b: number?): number
	local lo, hi = a or 0, b or 1
	return if v < lo then lo elseif v > hi then hi else v
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
local function sm(v: number): number
	v = clamp(v)
	return v * v * (3 - 2 * v)
end
Canvas.clamp = clamp
Canvas.lerp = lerp
Canvas.sm = sm

function Canvas.easeInBack(v: number): number
	v = clamp(v)
	local c = 1.9
	return v * v * ((c + 1) * v - c)
end

--[[ JavaScript's Math.imul, as an unsigned 32 bit result. ]]
local TWO32 = 4294967296
local function imul(a: number, b: number): number
	a %= TWO32
	b %= TWO32
	local aHi, aLo = a // 65536, a % 65536
	local bHi, bLo = b // 65536, b % 65536
	return (((aHi * bLo + aLo * bHi) % 65536) * 65536 + aLo * bLo) % TWO32
end

--[[ The page's hash: the same three integers give the same number in
     [0, 1), so a cleave's motes fall where its card's do. ]]
function Canvas.rnd(a: number, b: number, c: number): number
	local h =
		bit32.bxor(imul(a // 1, 374761393), imul(b // 1, 668265263), imul(c // 1 + 7, 2246822519))
	h = imul(bit32.bxor(h, bit32.rshift(h, 13)), 1274126177)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / TWO32
end

function Canvas.mix(p: RGB, q: RGB, t: number): RGB
	return { lerp(p[1], q[1], t), lerp(p[2], q[2], t), lerp(p[3], q[3], t) }
end

---------------------------------------------------------------- a swing

function Canvas.ang(I: Inst, u: number): number
	return I.a0 + (I.a1 - I.a0) * u
end

function Canvas.pt(I: Inst, u: number, r: number): (number, number)
	local a = I.a0 + (I.a1 - I.a0) * u
	local rr = r - (if I.sl ~= 0 then (I.R - I.r) * I.sl * u else 0)
	return I.cx + math.cos(a) * rr, I.cy + math.sin(a) * rr
end

function Canvas.KK(I: Inst): number
	return I.R - I.r
end

--[[ How far round the sweep's head is, `t` seconds in: fast, easing out. ]]
function Canvas.headU(I: Inst, t: number): number
	return if t <= 0 then 0 elseif t >= I.T then 1 else 1 - (1 - t / I.T) ^ 3
end

--[[ When the head passed `u`. ]]
function Canvas.passT(I: Inst, u: number): number
	return I.T * (1 - (1 - clamp(u)) ^ (1 / 3))
end

--[[ How far it has gone away (0 until the hold ends, 1 when gone). ]]
function Canvas.dis(I: Inst, t: number): number
	return clamp((t - I.T - I.H) / I.F)
end

function Canvas.after(I: Inst, t: number, G: number): number
	return clamp((t - I.T - I.H - I.F) / G)
end

function Canvas.sweepSign(I: Inst): number
	return if I.a1 > I.a0 then 1 else -1
end

--[[ A band's thickness along it. ]]
Canvas.P = {
	cres = function(v: number): number
		return math.sin(math.pi * clamp(v)) ^ 0.7
	end,
	head = function(v: number): number
		return clamp(v) ^ 1.2 * math.min(1, (1 - v) * 9 + 0.05)
	end,
	tusk = function(v: number): number
		return math.min(1, v * 5) * clamp(1 - v) ^ 0.55
	end,
	rib = function(v: number): number
		return 0.25 + 0.75 * clamp(v)
	end,
	one = function(_v: number): number
		return 1
	end,
}

--[[ A band along the arc between u0 and u1. f = 0 is its outer edge,
     f = 1 its inner. ]]
function Canvas.frame(I: Inst, u0: number, u1: number, o: FrameOpts?): Frame
	local opts: FrameOpts = o or {}
	local prof = opts.prof or Canvas.P.cres
	local th = (opts.thick or (I.R - I.r)) * (opts.w or 1)
	local out = opts.rOut or I.R
	local mid = opts.mid
	local g = opts.g
	local function pv(v: number): number
		if not g then
			return prof(v)
		end
		local u = lerp(u0, u1, v)
		local den = g[2] - g[1]
		return prof((u - g[1]) / (if den ~= 0 then den else 1))
	end
	local function rad(v: number, f: number): number
		if mid then
			return mid + th * pv(v) * (0.5 - f)
		end
		return out - th * pv(v) * f
	end
	return {
		u0 = u0,
		u1 = u1,
		arc = math.abs((I.a1 - I.a0) * (u1 - u0)),
		ok = u1 - u0 > 0.002,
		rad = rad,
		p = function(v: number, f: number, dr: number?): (number, number)
			return Canvas.pt(I, lerp(u0, u1, v), rad(v, f) + (dr or 0))
		end,
	}
end

export type Span = { h: number, d: number, e: number, u0: number, u1: number, a: number }

--[[ The streak's lit stretch at `t`, by how it goes away. ]]
function Canvas.span(I: Inst, t: number, mode: string?, tail: number?): Span
	local how = mode or "fade"
	local h = Canvas.headU(I, t)
	local d = Canvas.dis(I, t)
	local e = sm(d)
	local u0, u1, a = 0, h, 1
	if how == "retract" then
		u0 = h * e
	elseif how == "close" then
		u0 = h * 0.5 * e
		u1 = h - h * 0.5 * e
	elseif how == "streak" then
		u0 = Canvas.headU(I, t - (tail or 0.14))
	elseif how == "fade" then
		a = 1 - e
	end
	return { h = h, d = d, e = e, u0 = u0, u1 = u1, a = a }
end

---------------------------------------------------------------- a blow

--[[ The page's GEO: pixels to a stud, the inner edge as a share of the
     reach, the dagger's slant, sweep, hold and fade seconds, and how long
     a blow's cleave and motes last. The geometry itself comes from the
     swing's real shape (`SwingBox.shape`), so Cleave and Long Reach grow
     it as they grow the hit. ]]
Canvas.GEO = table.freeze({
	sword = table.freeze({
		s = 14.5,
		inner = 0.3,
		sl = 0,
		T = 0.17,
		H = 0.12,
		F = 0.38,
		life = 1.6,
	}),
	dagger = table.freeze({
		s = 19,
		inner = 0.45,
		sl = 0.4,
		T = 0.1,
		H = 0.08,
		F = 0.28,
		life = 1.25,
	}),
})
--[[ Where the swinger stands on a card. ]]
Canvas.PX = 160
Canvas.PY = 214

export type Shape = {
	kind: "Arc" | "Circle",
	reach: number,
	arc: number,
	radius: number,
	ahead: number,
}

--[[ A blow's `Inst` and how long its cleave lasts, as the page's
     `makeInst` builds the card's three: the side-to-side arcs (blow 1
     right to left, blow 2 left to right) and the slam's circle. `window`
     is the blade's real sweep in seconds (its `TrailOn` to `TrailOff`),
     so the head keeps up with the blade; `card` seeds the motes as the
     card's do. ]]
function Canvas.inst(
	kind: string,
	shape: Shape,
	sweep: string,
	window: number?,
	card: number,
	linger: number?
): (Inst, number)
	local g = Canvas.GEO[kind] or Canvas.GEO.sword
	local up = -math.pi / 2
	local T = if window and window > 0 then math.clamp(window, 0.05, 0.4) else g.T
	local H = g.H * (linger or 1)
	local life = g.life + (H - g.H)
	if shape.kind == "Circle" then
		local R = shape.radius * g.s
		return {
			cx = Canvas.PX,
			cy = Canvas.PY - shape.ahead * g.s,
			R = R,
			r = R * 0.2,
			a0 = up,
			a1 = up + TAU,
			sl = 0,
			T = T * 1.3,
			H = H,
			F = g.F * 1.1,
			seed = card * 3 + 3,
		},
			life
	end
	local R = shape.reach * g.s
	local half = math.rad(shape.arc / 2)
	local rightToLeft = sweep == "RightToLeft"
	return {
		cx = Canvas.PX,
		cy = Canvas.PY,
		R = R,
		r = R * g.inner,
		a0 = if rightToLeft then up + half else up - half,
		a1 = if rightToLeft then up - half else up + half,
		sl = g.sl,
		T = T,
		H = H,
		F = g.F,
		seed = card * 3 + (if rightToLeft then 1 else 2),
	},
		life
end

--[[ A blade's three colours (streak, tail, motes) in the page's units. ]]
function Canvas.look(key: string, colours: { Color3 }, glow: boolean): Look
	local function rgb(colour: Color3): RGB
		return { math.round(colour.R * 255), math.round(colour.G * 255), math.round(colour.B * 255) }
	end
	return {
		key = key,
		c0 = rgb(colours[1]),
		c1 = rgb(colours[2]),
		c2 = rgb(colours[3]),
		glow = glow,
	}
end

---------------------------------------------------------------- the list

function Canvas.new(s: number, detail: number): Ctx
	return {
		items = {},
		alpha = 1,
		light = false,
		ox = 0,
		oy = 0,
		lift = 0,
		glowCol = nil,
		glowBlur = 0,
		detail = detail,
		s = s,
	}
end

--[[ The page's save() and restore(). ]]
function Canvas.save(c: Ctx): Ctx
	return table.clone(c)
end
function Canvas.restore(c: Ctx, saved: Ctx)
	c.alpha, c.light, c.ox, c.oy, c.lift = saved.alpha, saved.light, saved.ox, saved.oy, saved.lift
	c.glowCol, c.glowBlur = saved.glowCol, saved.glowBlur
end

function Canvas.glow(c: Ctx, W: Look, colour: RGB, blur: number?)
	if W.glow then
		c.glowCol = colour
		c.glowBlur = blur or 12
	end
end
--[[ A glow whatever the blade (the page's glow(x, {glow: true}, ...)). ]]
function Canvas.glowAlways(c: Ctx, colour: RGB, blur: number?)
	c.glowCol = colour
	c.glowBlur = blur or 12
end
function Canvas.noGlow(c: Ctx)
	c.glowBlur = 0
end

local function segs(c: Ctx, n: number): number
	return math.max(2, math.round(n * c.detail))
end
Canvas.segs = segs

--[[ Samples for `radians` of band, `dens` times the usual for a wavy edge. ]]
local function samples(c: Ctx, radians: number, dens: number?): number
	return segs(c, math.clamp(math.ceil(radians / STEP * (dens or 1)), 2, MOST_SEGS * (dens or 1)))
end

--[[ Appends a strip as it stands, the translate and the global alpha
     applied. ]]
local function push(
	c: Ctx,
	ax: { number },
	ay: { number },
	bx: { number },
	by: { number },
	cols: { RGB },
	alphas: { number },
	tex: string?
)
	local ox, oy, ga = c.ox, c.oy, c.alpha
	for i = 1, #ax do
		ax[i] += ox
		ay[i] += oy
		bx[i] += ox
		by[i] += oy
		alphas[i] = clamp(alphas[i] * ga)
	end
	table.insert(c.items, {
		ax = ax,
		ay = ay,
		bx = bx,
		by = by,
		cols = cols,
		alphas = alphas,
		light = c.light,
		lift = c.lift,
		tex = tex,
	})
end
Canvas.push = push

--[[ A soft halo under a filled strip: the page's shadowBlur, as a wider,
     fainter strip glowing in the shadow's colour. ]]
local function halo(
	c: Ctx,
	ax: { number },
	ay: { number },
	bx: { number },
	by: { number },
	alphas: { number }
)
	local colour = c.glowCol
	if c.glowBlur <= 0 or not colour then
		return
	end
	local grow = c.glowBlur * 0.5
	local hax, hay, hbx, hby, cols, as = {}, {}, {}, {}, {}, {}
	for i = 1, #ax do
		local dx, dy = ax[i] - bx[i], ay[i] - by[i]
		local len = math.sqrt(dx * dx + dy * dy)
		local ux, uy = 0, 0
		if len > 1e-6 then
			ux, uy = dx / len, dy / len
		end
		hax[i], hay[i] = ax[i] + ux * grow, ay[i] + uy * grow
		hbx[i], hby[i] = bx[i] - ux * grow, by[i] - uy * grow
		cols[i] = colour
		as[i] = alphas[i] * 0.4
	end
	local light = c.light
	c.light = true
	push(c, hax, hay, hbx, hby, cols, as)
	c.light = light
end

--[[ The page's fillBand: the band between edges f0 and f1, its colour and
     opacity running from the tail's (at u0) to the head's (at u1). ]]
function Canvas.fillBand(
	c: Ctx,
	F: Frame,
	cHead: RGB,
	cTail: RGB,
	a: number?,
	f0: number?,
	f1: number?,
	tailA: number?,
	wob: Wob?,
	dens: number?
): boolean
	local alpha = a or 1
	if not F.ok or alpha <= 0 then
		return false
	end
	local e0, e1, ta = f0 or 0, f1 or 1, tailA or 0.5
	local n = samples(c, F.arc, dens)
	local ax, ay, bx, by, cols, as = {}, {}, {}, {}, {}, {}
	for i = 0, n do
		local v = i / n
		ax[i + 1], ay[i + 1] = F.p(v, e0, if wob then wob(v, e0) else 0)
		bx[i + 1], by[i + 1] = F.p(v, e1, if wob then wob(v, e1) else 0)
		cols[i + 1] = Canvas.mix(cTail, cHead, v)
		as[i + 1] = lerp(alpha * ta, alpha, v)
	end
	halo(c, ax, ay, bx, by, as)
	push(c, ax, ay, bx, by, cols, as)
	return true
end

export type Stop = { u: number, c: RGB, a: number }

--[[ fillBand with a gradient of many stops, in u order. ]]
function Canvas.fillBandStops(
	c: Ctx,
	F: Frame,
	stops: { Stop },
	f0: number?,
	f1: number?,
	count: number?
): boolean
	if not F.ok or #stops == 0 then
		return false
	end
	local e0, e1 = f0 or 0, f1 or 1
	local n = count or samples(c, F.arc, 1.5)
	local ax, ay, bx, by, cols, as = {}, {}, {}, {}, {}, {}
	for i = 0, n do
		local v = i / n
		local u = lerp(F.u0, F.u1, v)
		ax[i + 1], ay[i + 1] = F.p(v, e0)
		bx[i + 1], by[i + 1] = F.p(v, e1)
		local last = stops[#stops]
		local colour, alpha = last.c, last.a
		if u <= stops[1].u then
			colour, alpha = stops[1].c, stops[1].a
		else
			for k = 1, #stops - 1 do
				local s0, s1 = stops[k], stops[k + 1]
				if u <= s1.u then
					local w = if s1.u > s0.u then (u - s0.u) / (s1.u - s0.u) else 1
					colour = Canvas.mix(s0.c, s1.c, w)
					alpha = lerp(s0.a, s1.a, w)
					break
				end
			end
		end
		cols[i + 1] = colour
		as[i + 1] = alpha
	end
	halo(c, ax, ay, bx, by, as)
	push(c, ax, ay, bx, by, cols, as)
	return true
end

--[[ A stroked line through points, `width` pixels wide. ]]
function Canvas.polyline(
	c: Ctx,
	xs: { number },
	ys: { number },
	width: number,
	colour: RGB,
	alpha: number
)
	local n = #xs
	if n < 2 or alpha <= 0 or width <= 0 then
		return
	end
	local half = width / 2
	local ax, ay, bx, by, cols, as = {}, {}, {}, {}, {}, {}
	for i = 1, n do
		local pi, ni = math.max(1, i - 1), math.min(n, i + 1)
		local tx, ty = xs[ni] - xs[pi], ys[ni] - ys[pi]
		local len = math.sqrt(tx * tx + ty * ty)
		local nx, ny = 0, 0
		if len > 1e-6 then
			nx, ny = -ty / len, tx / len
		end
		ax[i], ay[i] = xs[i] + nx * half, ys[i] + ny * half
		bx[i], by[i] = xs[i] - nx * half, ys[i] - ny * half
		cols[i] = colour
		as[i] = alpha
	end
	-- a glowing stroke glows round its line too
	halo(c, table.clone(ax), table.clone(ay), table.clone(bx), table.clone(by), as)
	push(c, ax, ay, bx, by, cols, as)
end

--[[ The page's arc(cx, cy, r, from, to) stroked: an open circle's arc,
     squashed across by `squash` (an ellipse's, as the page's whirlpool). ]]
function Canvas.arcLine(
	c: Ctx,
	cx: number,
	cy: number,
	r: number,
	from: number,
	to: number,
	width: number,
	colour: RGB,
	alpha: number,
	squash: number?
)
	if r <= 0.05 or alpha <= 0 then
		return
	end
	local n = segs(c, math.clamp(math.ceil(math.abs(to - from) / 0.35), 4, MOST_SEGS))
	local xs, ys = {}, {}
	for i = 0, n do
		local an = lerp(from, to, i / n)
		xs[i + 1], ys[i + 1] = cx + math.cos(an) * r, cy + math.sin(an) * r * (squash or 1)
	end
	Canvas.polyline(c, xs, ys, width, colour, alpha)
end

--[[ The page's F.line(f, v0, v1, wob) and a stroke. ]]
function Canvas.strokeLine(
	c: Ctx,
	F: Frame,
	f: number,
	v0: number?,
	v1: number?,
	wob: ((number) -> number)?,
	width: number,
	colour: RGB,
	alpha: number,
	n: number?
)
	if not F.ok then
		return
	end
	local from, to = v0 or 0, v1 or 1
	-- a thin line bends gently: fewer samples than a filled band
	local count = if n then segs(c, n) else samples(c, F.arc * math.abs(to - from), 0.6)
	local xs, ys = {}, {}
	for i = 0, count do
		local v = lerp(from, to, i / count)
		xs[i + 1], ys[i + 1] = F.p(v, f, if wob then wob(v) else 0)
	end
	Canvas.polyline(c, xs, ys, width, colour, alpha)
end

--[[ A band's outline (its path stroked): both edges and both ends. ]]
function Canvas.strokePath(
	c: Ctx,
	F: Frame,
	f0: number,
	f1: number,
	wob: Wob?,
	width: number,
	colour: RGB,
	alpha: number,
	n: number?
)
	if not F.ok then
		return
	end
	for _, f in { f0, f1 } do
		Canvas.strokeLine(
			c,
			F,
			f,
			0,
			1,
			if wob
				then function(v)
					return wob(v, f)
				end
				else nil,
			width,
			colour,
			alpha,
			n
		)
	end
	for _, v in { 0, 1 } do
		local x0, y0 = F.p(v, f0, if wob then wob(v, f0) else 0)
		local x1, y1 = F.p(v, f1, if wob then wob(v, f1) else 0)
		Canvas.polyline(c, { x0, x1 }, { y0, y1 }, width, colour, alpha)
	end
end

--[[ A quad from four corners (p0, p1 at one end, p3, p2 at the other). ]]
function Canvas.quad(
	c: Ctx,
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	x3: number,
	y3: number,
	colour: RGB,
	alpha: number,
	tex: string?
)
	if alpha <= 0 then
		return
	end
	push(
		c,
		{ x0, x3 },
		{ y0, y3 },
		{ x1, x2 },
		{ y1, y2 },
		{ colour, colour },
		{ alpha, alpha },
		tex
	)
end

--[[ A triangle: its base p0 to p1, its tip p2. ]]
function Canvas.tri(
	c: Ctx,
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	colour: RGB,
	alpha: number
)
	if alpha <= 0 then
		return
	end
	push(c, { x0, x2 }, { y0, y2 }, { x1, x2 }, { y1, y2 }, { colour, colour }, { alpha, alpha })
end

--[[ A rectangle `l` long and `w` wide, centred at (p, q), turned `r`. ]]
local function rect(
	c: Ctx,
	p: number,
	q: number,
	l: number,
	w: number,
	r: number,
	colour: RGB,
	alpha: number,
	tex: string?
)
	local ux, uy = math.cos(r), math.sin(r)
	local nx, ny = -uy, ux
	local hl, hw = l / 2, w / 2
	Canvas.quad(
		c,
		p - ux * hl + nx * hw,
		q - uy * hl + ny * hw,
		p - ux * hl - nx * hw,
		q - uy * hl - ny * hw,
		p + ux * hl - nx * hw,
		q + uy * hl - ny * hw,
		p + ux * hl + nx * hw,
		q + uy * hl + ny * hw,
		colour,
		alpha,
		tex
	)
end
Canvas.rect = rect

--[[ A strip along a straight line through (p, q) at angle r, its half
     widths at the given offsets along it (a lens, a diamond, a kite). ]]
local function spindle(
	c: Ctx,
	p: number,
	q: number,
	r: number,
	along: { number },
	halfs: { number },
	colour: RGB,
	alpha: number
)
	local ux, uy = math.cos(r), math.sin(r)
	local nx, ny = -uy, ux
	local ax, ay, bx, by, cols, as = {}, {}, {}, {}, {}, {}
	for i, d in along do
		local cx, cy = p + ux * d, q + uy * d
		ax[i], ay[i] = cx + nx * halfs[i], cy + ny * halfs[i]
		bx[i], by[i] = cx - nx * halfs[i], cy - ny * halfs[i]
		cols[i] = colour
		as[i] = alpha
	end
	push(c, ax, ay, bx, by, cols, as)
end
Canvas.spindle = spindle

---------------------------------------------------------------- shapes (the page's sh)

--[[ Below this many studs across, a round thing is drawn square: no one
     can tell at that size. ]]
local TINY = 0.22

function Canvas.dot(c: Ctx, p: number, q: number, s: number, colour: RGB, alpha: number)
	if s <= 0.05 or alpha <= 0 then
		return
	end
	if s * 2 / c.s < TINY then
		rect(c, p, q, s * 1.8, s * 1.8, 0, colour, alpha)
		return
	end
	-- an octagon: a band, ends cut at 45 degrees
	local k = s * 0.4142
	spindle(c, p, q, 0, { -s, -k, k, s }, { k, s, s, k }, colour, alpha)
end

function Canvas.ring(
	c: Ctx,
	p: number,
	q: number,
	s: number,
	colour: RGB,
	alpha: number,
	w: number?
)
	if s <= 0.05 or alpha <= 0 then
		return
	end
	local width = w or 1.2
	if s / c.s < 0.5 then
		-- small: the ring texture, sized so its line sits on the circle
		rect(c, p, q, s * 2.3, s * 2.3, 0, colour, alpha, Canvas.RING)
		return
	end
	local n = segs(c, 16)
	local xs, ys = {}, {}
	for i = 0, n do
		local an = i / n * TAU
		xs[i + 1], ys[i + 1] = p + math.cos(an) * s, q + math.sin(an) * s
	end
	Canvas.polyline(c, xs, ys, width, colour, alpha)
end

--[[ A radial glow, bright in the middle, gone at radius s. ]]
function Canvas.glowDot(c: Ctx, p: number, q: number, s: number, colour: RGB, alpha: number)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	rect(c, p, q, s * 2, s * 2, 0, colour, alpha, Canvas.SOFT)
end

function Canvas.cross(
	c: Ctx,
	p: number,
	q: number,
	s: number,
	r: number,
	colour: RGB,
	alpha: number
)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	local w = s * 0.34
	rect(c, p, q, 2 * s, w, r, colour, alpha)
	rect(c, p, q, 2 * s, w, r + math.pi / 2, colour, alpha)
end

--[[ A four-point star, points at s and waist at a quarter of it. ]]
function Canvas.spark(
	c: Ctx,
	p: number,
	q: number,
	s: number,
	r: number,
	colour: RGB,
	alpha: number
)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	local waist = s * 0.25 * math.sqrt(0.5)
	spindle(c, p, q, r, { -s, -waist, waist, s }, { 0, waist, waist, 0 }, colour, alpha)
	spindle(
		c,
		p,
		q,
		r + math.pi / 2,
		{ -s, -waist, waist, s },
		{ 0, waist, waist, 0 },
		colour,
		alpha
	)
end

--[[ A five-point star, inner radius 0.45 of the points'. ]]
function Canvas.star5(
	c: Ctx,
	p: number,
	q: number,
	s: number,
	r: number,
	colour: RGB,
	alpha: number
)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	local inner = s * 0.45
	for i = 0, 4 do
		local a = r - math.pi / 2 + i * TAU / 5
		local half = inner * math.sin(math.pi / 5)
		spindle(
			c,
			p,
			q,
			a,
			{ 0, inner * math.cos(math.pi / 5), s },
			{ half * 0.6, half, 0 },
			colour,
			alpha
		)
	end
end

function Canvas.shard(
	c: Ctx,
	p: number,
	q: number,
	s: number,
	r: number,
	colour: RGB,
	alpha: number
)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	local cs, sn = math.cos(r), math.sin(r)
	local function at(x: number, y: number): (number, number)
		return p + x * cs - y * sn, q + x * sn + y * cs
	end
	local x0, y0 = at(-s * 0.6, s * 0.34)
	local x1, y1 = at(-s * 0.4, -s * 0.3)
	local x2, y2 = at(s, 0)
	Canvas.tri(c, x0, y0, x1, y1, x2, y2, colour, alpha)
end

function Canvas.chip(c: Ctx, p: number, q: number, s: number, r: number, colour: RGB, alpha: number)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	rect(c, p, q, s, s, r, colour, alpha)
end

--[[ A leaf: pointed both ends, 0.7 of its length at the widest. ]]
function Canvas.leaf(c: Ctx, p: number, q: number, s: number, r: number, colour: RGB, alpha: number)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	spindle(
		c,
		p,
		q,
		r,
		{ -s, -s * 0.5, 0, s * 0.5, s },
		{ 0, s * 0.26, s * 0.35, s * 0.26, 0 },
		colour,
		alpha
	)
end

--[[ A petal: round at the root, notched at the tip. ]]
function Canvas.petal(
	c: Ctx,
	p: number,
	q: number,
	s: number,
	r: number,
	colour: RGB,
	alpha: number
)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	spindle(
		c,
		p,
		q,
		r,
		{ -s, -s * 0.4, s * 0.3, s * 0.85 },
		{ 0, s * 0.62, s * 0.62, s * 0.42 },
		colour,
		alpha
	)
end

function Canvas.flower(
	c: Ctx,
	p: number,
	q: number,
	s: number,
	colour: RGB,
	centre: RGB,
	alpha: number
)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	for i = 0, 4 do
		local a = i / 5 * TAU
		Canvas.dot(c, p + math.cos(a) * s, q + math.sin(a) * s, s * 0.7, colour, alpha)
	end
	Canvas.dot(c, p, q, s * 0.55, centre, alpha)
end

--[[ The page's spiky: an n-point burr, its waist `inner` of its points. ]]
function Canvas.spiky(
	c: Ctx,
	p: number,
	q: number,
	s: number,
	r: number,
	colour: RGB,
	alpha: number,
	n: number,
	inner: number
)
	if s <= 0.2 or alpha <= 0 then
		return
	end
	local waist = s * inner
	Canvas.dot(c, p, q, waist, colour, alpha)
	for i = 0, n - 1 do
		local an = r + i / n * TAU
		local b0, b1 = an - math.pi / n, an + math.pi / n
		Canvas.tri(
			c,
			p + math.cos(b0) * waist,
			q + math.sin(b0) * waist,
			p + math.cos(b1) * waist,
			q + math.sin(b1) * waist,
			p + math.cos(an) * s,
			q + math.sin(an) * s,
			colour,
			alpha
		)
	end
end

--[[ A filled ellipse, `rx` along angle `rot` and `ry` across it. ]]
function Canvas.ellipse(
	c: Ctx,
	p: number,
	q: number,
	rx: number,
	ry: number,
	rot: number,
	colour: RGB,
	alpha: number
)
	if rx <= 0.1 or ry <= 0.1 or alpha <= 0 then
		return
	end
	local along, halfs = {}, {}
	for i = 0, 8 do
		local phi = math.pi - i / 8 * math.pi
		along[i + 1] = rx * math.cos(phi)
		halfs[i + 1] = ry * math.sin(phi)
	end
	spindle(c, p, q, rot, along, halfs, colour, alpha)
end

--[[ A closed outline through points. ]]
function Canvas.outline(
	c: Ctx,
	xs: { number },
	ys: { number },
	width: number,
	colour: RGB,
	alpha: number
)
	local cx, cy = table.clone(xs), table.clone(ys)
	table.insert(cx, xs[1])
	table.insert(cy, ys[1])
	Canvas.polyline(c, cx, cy, width, colour, alpha)
end

--[[ A convex polygon filled (a fan from its first corner). Glowing, it
     sits on a soft glow as wide as it is. ]]
function Canvas.fill(c: Ctx, xs: { number }, ys: { number }, colour: RGB, alpha: number)
	local n = #xs
	if n < 3 or alpha <= 0 then
		return
	end
	local glowCol = c.glowCol
	if c.glowBlur > 0 and glowCol then
		local mx, my = 0, 0
		for i = 1, n do
			mx += xs[i] / n
			my += ys[i] / n
		end
		local far = 0
		for i = 1, n do
			far = math.max(far, math.sqrt((xs[i] - mx) ^ 2 + (ys[i] - my) ^ 2))
		end
		local light = c.light
		c.light = true
		Canvas.glowDot(c, mx, my, far + c.glowBlur * 0.6, glowCol, alpha * 0.45)
		c.light = light
	end
	for i = 2, n - 1 do
		Canvas.tri(c, xs[i], ys[i], xs[i + 1], ys[i + 1], xs[1], ys[1], colour, alpha)
	end
end

--[[ The page's blob: a lumpy nine-sided splat, squashed a fifth across. ]]
function Canvas.blob(
	c: Ctx,
	p: number,
	q: number,
	r: number,
	seed: number,
	colour: RGB,
	alpha: number
)
	if r <= 0.1 or alpha <= 0 then
		return
	end
	local xs, ys = {}, {}
	for i = 0, 8 do
		local an = i / 9 * TAU
		local rr = r * (0.7 + 0.5 * Canvas.rnd(seed, i, 7))
		xs[i + 1], ys[i + 1] = p + math.cos(an) * rr, q + math.sin(an) * rr * 0.8
	end
	for i = 1, 9 do
		local j = i % 9 + 1
		Canvas.tri(c, xs[i], ys[i], xs[j], ys[j], p, q, colour, alpha)
	end
end

--[[ A line drawn as dashes `dash` long with `gap` between (the page's
     setLineDash), along a band's edge `f`. ]]
function Canvas.dashLine(
	c: Ctx,
	F: Frame,
	f: number,
	dash: number,
	gap: number,
	width: number,
	colour: RGB,
	alpha: number
)
	if not F.ok or alpha <= 0 then
		return
	end
	local n = 60
	local px, py = F.p(0, f)
	local walked, nextAt = 0, 0
	for i = 1, n do
		local x, y = F.p(i / n, f)
		local step = math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
		while step > 0 and nextAt <= walked + step do
			local k = (nextAt - walked) / step
			local sx, sy = px + (x - px) * k, py + (y - py) * k
			local ux, uy = (x - px) / step, (y - py) / step
			Canvas.rect(
				c,
				sx + ux * dash / 2,
				sy + uy * dash / 2,
				dash,
				width,
				math.atan2(uy, ux),
				colour,
				alpha
			)
			nextAt += dash + gap
		end
		walked += step
		px, py = x, y
	end
end

--[[ A strip given both edges (in order along it), one colour. ]]
function Canvas.strip(
	c: Ctx,
	ax: { number },
	ay: { number },
	bx: { number },
	by: { number },
	colour: RGB,
	alpha: number
)
	if #ax < 2 or alpha <= 0 then
		return
	end
	local cols, as = {}, {}
	for i = 1, #ax do
		cols[i] = colour
		as[i] = alpha
	end
	push(c, ax, ay, bx, by, cols, as)
end

--[[ The page's underGlow: a soft glow under the swept stretch, whatever
     the blade, gone as the cleave goes. ]]
function Canvas.underGlow(c: Ctx, I: Inst, t: number, w: number, colour: RGB, a: number)
	local h = Canvas.headU(I, t)
	local e = sm(Canvas.dis(I, t))
	local F = Canvas.frame(I, 0, h, { w = w })
	if not F.ok or e >= 1 then
		return
	end
	local saved = Canvas.save(c)
	c.glowCol = colour
	c.glowBlur = 18
	Canvas.fillBand(c, F, colour, colour, a * (1 - e), 0, 1, 0.6)
	Canvas.restore(c, saved)
end

---------------------------------------------------------------- motes

export type MoteOpts = {
	n: number,
	life: number,
	on: string?,
	spreadT: number?,
	lag: number?,
	u0: number?,
	u1: number?,
	f0: number?,
	f1: number?,
	spd: number?,
	spread: number?,
	rise: number?,
	grav: number?,
	sway: number?,
	draw: (p: number, q: number, k: number, h1: number, i: number, th: number, h2: number) -> (),
}

--[[ The page's particles, worked out from time alone, so nothing is
     stored. Its rise and fall (up and down the card) are height here: the
     ctx's `lift` is set for each mote while it is drawn, and a falling
     one comes to rest on the floor. ]]
function Canvas.motes(c: Ctx, I: Inst, t: number, o: MoteOpts, floor: number?)
	local K = I.R - I.r
	local liftWas = c.lift
	local ground = -(floor or 1.35)
	for i = 0, o.n - 1 do
		local h1, h2 = Canvas.rnd(I.seed, i, 11), Canvas.rnd(I.seed, i, 12)
		local h3, h4 = Canvas.rnd(I.seed, i, 13), Canvas.rnd(I.seed, i, 14)
		-- a weaker device draws a share of them, the same ones each time
		if c.detail < 1 and Canvas.rnd(I.seed, i, 15) > c.detail then
			continue
		end
		local u = if o.u0 ~= nil then lerp(o.u0, o.u1 or 1, h1) else h1
		local t0 = if o.on == "dis"
			then I.T + I.H + h4 * I.F * (o.spreadT or 0.7)
			else Canvas.passT(I, u) + (o.lag or 0) * h4
		local L = o.life * (0.7 + 0.6 * h3)
		local a = t - t0
		if a < 0 or a > L then
			continue
		end
		local th = Canvas.ang(I, u)
		local px, py = Canvas.pt(I, u, I.R - K * lerp(o.f0 or 0, o.f1 or 1, h2))
		local sp = (o.spd or 0) * (0.5 + h3)
		local dir = th + (h4 - 0.5) * (o.spread or 1.2)
		px += math.cos(dir) * sp * a
		py += math.sin(dir) * sp * a
		if o.sway then
			px += math.sin(a * o.sway + h1 * 9) * 4
		end
		local up = ((o.rise or 0) * a - 0.5 * (o.grav or 0) * a * a) / c.s
		c.lift = liftWas + math.max(up, ground)
		o.draw(px, py, a / L, h1, i, th, h2)
	end
	c.lift = liftWas
end

return Canvas
