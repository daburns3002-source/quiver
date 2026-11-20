--!strict
--[[
	The projectile shots' drawing kit (owner, 2026-11-19, "build all 49"
	from the Projectile Shots page,
	https://claude.ai/artifact/T2EwHuQhKJosJ95wZSU14n).

	The page's flight helpers and shared pieces, ported onto the blade
	cleaves' canvas (`Fx/Cleaves/Canvas`): its seeded hash, its shapes, the
	page's pixels (`S` of them to a stud). Each area's module (`Glade`, ...)
	is its cards' `D` code line for line on top of these.

	Where the page reads a shot's path from its plan, the game reads the
	real flight: `Fx/Shots/Play` samples every drawn shot each frame (time,
	place, heading) and `hd` reads the samples back, so a shot that homes,
	pierces or bounces trails the way it really flew.

	Page x is the world's X and page y its Z. The camera looks down toward
	-Z, so what the page draws up the card is up the screen here too, and
	every drawing sits flat in the shot's own flight plane.
]]

local Canvas = require(script.Parent.Parent.Cleaves.Canvas)

local Kit = {}

type RGB = Canvas.RGB
type Ctx = Canvas.Ctx

local TAU = math.pi * 2
local PI = math.pi
Kit.TAU = TAU
Kit.PI = PI
Kit.WHITE = { 255, 255, 255 } :: RGB
Kit.BLACK = { 0, 0, 0 } :: RGB

--[[ The page's pixels to a stud: its card is 48 studs across 320. ]]
Kit.S = 320 / 48
--[[ Seconds a hit draws for, as on the page. ]]
Kit.HITLIFE = 0.9

--[[ Set by `Fx/Shots/Play` each frame: on the lowest device tier, as
     today's shots there, no tails and nothing shed. ]]
Kit.lite = false

export type P = { number }

--[[ Where a shot has been: `ts[i]` seconds into its flight it was at
     (`xs[i]`, `ys[i]`) on the page, heading `as[i]`. ]]
export type Shot = {
	kind: string,
	seed: number,
	ph: number,
	ts: { number },
	xs: { number },
	ys: { number },
	as: { number },
	--[[ When it stopped, or math.huge while it flies. ]]
	tEnd: number,
}

--[[ A weapon's three colours (main, second, accent) and whether its shot
     glows (a Legendary or Mythic): the cleaves' look. ]]
export type Look = Canvas.Look

export type Lat = (I: Shot, t: number) -> number

export type Drawer = {
	f: (c: Ctx, I: Shot, t: number, W: Look) -> (),
	--[[ A hit `a` seconds old at P = { x, y, heading }: "body" where it
	     stopped in an enemy, "pass" where it went on through one, "wall",
	     or "end" where its reach ran out. ]]
	h: (c: Ctx, P: P, a: number, W: Look, I: Shot, k: string) -> (),
}

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
Kit.clamp = clamp
Kit.lerp = lerp
Kit.sm = sm
Kit.rnd = Canvas.rnd
Kit.mix = Canvas.mix

function Kit.hx(s: string): RGB
	return {
		tonumber(string.sub(s, 2, 3), 16) :: number,
		tonumber(string.sub(s, 4, 5), 16) :: number,
		tonumber(string.sub(s, 6, 7), 16) :: number,
	}
end

--[[ The page's cyc: round a list of colours, one step a unit of z. ]]
function Kit.cyc(list: { RGB }, z: number): RGB
	local n = #list
	local j = math.floor(z) % n
	return Canvas.mix(list[j + 1], list[(j + 1) % n + 1], z - math.floor(z))
end
local PASTEL: { RGB } =
	{ { 226, 196, 246 }, { 196, 242, 224 }, { 255, 212, 236 }, { 204, 222, 255 } }
function Kit.shim(t: number): RGB
	return Kit.cyc(PASTEL, t * 2)
end
function Kit.dusk(W: Look, t: number): RGB
	return Kit.cyc({ W.c0, W.c1, W.c2 }, t * 0.7)
end
local SEA: { RGB } = { { 58, 90, 255 }, { 40, 190, 230 }, { 120, 90, 255 } }
function Kit.sea(t: number): RGB
	return Kit.cyc(SEA, t * 0.6)
end
function Kit.heat(ag: number): RGB
	local k = clamp(ag / 0.45)
	local mix = Canvas.mix
	if k < 0.3 then
		return mix({ 255, 246, 205 }, { 255, 170, 40 }, k / 0.3)
	elseif k < 0.7 then
		return mix({ 255, 170, 40 }, { 205, 70, 22 }, (k - 0.3) / 0.4)
	end
	return mix({ 205, 70, 22 }, { 74, 36, 26 }, (k - 0.7) / 0.3)
end

---------------------------------------------------------------- the flight

--[[ Where the shot was `t` seconds in (held at its last place once it has
     stopped), its sway `lat` (pixels across its heading) added. ]]
function Kit.hd(I: Shot, t: number, lat: Lat?): P
	local ts = I.ts
	local n = #ts
	local last = ts[n]
	local tt = clamp(t, ts[1], math.min(I.tEnd, last))
	local x, y, a
	if n == 1 or tt >= last then
		x, y, a = I.xs[n], I.ys[n], I.as[n]
	else
		-- the sample at or before tt
		local lo, hi = 1, n
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if ts[mid] <= tt then
				lo = mid
			else
				hi = mid
			end
		end
		local span = ts[hi] - ts[lo]
		local u = if span > 1e-9 then (tt - ts[lo]) / span else 0
		x, y = lerp(I.xs[lo], I.xs[hi], u), lerp(I.ys[lo], I.ys[hi], u)
		local a0, a1 = I.as[lo], I.as[hi]
		local d = (a1 - a0 + PI) % TAU - PI
		a = a0 + d * u
	end
	if lat then
		local o = lat(I, math.min(math.max(t, 0), I.tEnd))
		x -= math.sin(a) * o
		y += math.cos(a) * o
	end
	return { x, y, a }
end
local hd = Kit.hd

--[[ The head and the points behind it `dur` seconds back. ]]
function Kit.tr(I: Shot, t: number, dur: number, n: number?, lat: Lat?): { P }
	local out = {}
	local count = n or 12
	for i = 0, count do
		local tt = t - dur * i / count
		table.insert(out, hd(I, math.max(tt, 0), lat))
		if tt <= 0 then
			break
		end
	end
	return out
end

--[[ The page's sw: a sideways sway `A` studs wide at `r` radians a second. ]]
function Kit.sw(A: number, r: number, ph: number?): Lat
	local extra = ph or 0
	return function(I: Shot, t: number): number
		return A * Kit.S * math.sin(r * t + I.ph + extra)
	end
end

--[[ 1 while the shot flies, gone a tenth of a second after it stops. ]]
function Kit.fade(I: Shot, t: number): number
	return 1 - clamp((t - I.tEnd) / 0.1)
end

---------------------------------------------------------------- drawing

--[[ A tapering band through points (head first), its colour and opacity
     running from the head's to the tail's. ]]
function Kit.ribbon(
	c: Ctx,
	pts: { P },
	w0: number,
	w1: number,
	c0: RGB,
	c1: RGB,
	a0: number?,
	a1: number?
)
	if Kit.lite then
		return
	end
	local n = #pts
	if n < 2 then
		return
	end
	local h, e = pts[1], pts[n]
	if math.sqrt((h[1] - e[1]) ^ 2 + (h[2] - e[2]) ^ 2) < 0.6 then
		return
	end
	local ha, ta = a0 or 1, a1 or 0
	local ax, ay, bx, by, cols, alphas = {}, {}, {}, {}, {}, {}
	for i = 1, n do
		local p, q, r = pts[i], pts[math.max(1, i - 1)], pts[math.min(n, i + 1)]
		local dx, dy = q[1] - r[1], q[2] - r[2]
		local a = if math.sqrt(dx * dx + dy * dy) > 1e-4 then math.atan2(dy, dx) else p[3]
		local u = (i - 1) / (n - 1)
		local w = lerp(w0, w1, u) / 2
		local nx, ny = -math.sin(a) * w, math.cos(a) * w
		ax[i], ay[i], bx[i], by[i] = p[1] + nx, p[2] + ny, p[1] - nx, p[2] - ny
		cols[i] = Canvas.mix(c0, c1, u)
		alphas[i] = lerp(ha, ta, u)
	end
	Canvas.push(c, ax, ay, bx, by, cols, alphas)
end

--[[ A stroke through points. Glowing (the page's shadowBlur on a line),
     it sits on soft lit glows of the glow's colour strung along it: the
     cleaves' halo strip reads as a block round a short line. ]]
function Kit.stroke(c: Ctx, xs: { number }, ys: { number }, w: number, colour: RGB, alpha: number)
	local glowCol = c.glowCol
	local blur = c.glowBlur
	if blur > 0 and glowCol then
		c.glowBlur = 0
		local light = c.light
		c.light = true
		-- soft glows along the line, one a radius apart
		local r = (w + blur) * 0.55
		for i = 1, #xs - 1 do
			local dx, dy = xs[i + 1] - xs[i], ys[i + 1] - ys[i]
			local n = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / r))
			for step = if i == 1 then 0 else 1, n do
				local u = step / n
				Canvas.glowDot(c, xs[i] + dx * u, ys[i] + dy * u, r, glowCol, alpha * 0.3)
			end
		end
		c.light = light
		Canvas.polyline(c, xs, ys, w, colour, alpha)
		c.glowBlur = blur
		return
	end
	Canvas.polyline(c, xs, ys, w, colour, alpha)
end

--[[ A stroked line through points. ]]
function Kit.line(c: Ctx, pts: { P }, w: number, colour: RGB, alpha: number)
	if #pts < 2 then
		return
	end
	local xs, ys = {}, {}
	for i, p in pts do
		xs[i], ys[i] = p[1], p[2]
	end
	Kit.stroke(c, xs, ys, w, colour, alpha)
end

--[[ A straight stroke from (x0, y0) to (x1, y1). ]]
function Kit.seg(
	c: Ctx,
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	w: number,
	colour: RGB,
	alpha: number
)
	Kit.stroke(c, { x0, x1 }, { y0, y1 }, w, colour, alpha)
end

--[[ The page's at(): draws `f` in a frame at (x, y) turned `r`, scaled
     `sx` along and `sy` across first. Whatever `f` draws is moved after. ]]
function Kit.at(c: Ctx, x: number, y: number, r: number, f: () -> (), sx: number?, sy: number?)
	local first = #c.items + 1
	local ox, oy = c.ox, c.oy
	c.ox, c.oy = 0, 0
	f()
	c.ox, c.oy = ox, oy
	local cs, sn = math.cos(r), math.sin(r)
	local kx, ky = sx or 1, sy or 1
	local px, py = x + ox, y + oy
	for i = first, #c.items do
		local it = c.items[i]
		for j = 1, #it.ax do
			local X, Y = it.ax[j] * kx, it.ay[j] * ky
			it.ax[j], it.ay[j] = px + X * cs - Y * sn, py + X * sn + Y * cs
			X, Y = it.bx[j] * kx, it.by[j] * ky
			it.bx[j], it.by[j] = px + X * cs - Y * sn, py + X * sn + Y * cs
		end
	end
end

--[[ The page's lamp: the shot's light on what is round it. ]]
function Kit.lamp(c: Ctx, p: P, colour: RGB, r: number?, a: number?)
	local alpha = a or 0.3
	if alpha <= 0 then
		return
	end
	local light = c.light
	c.light = true
	Canvas.glowDot(c, p[1], p[2], r or 30, colour, alpha)
	c.light = light
end

--[[ Its shadow, `h` pixels below it. ]]
function Kit.shade(c: Ctx, p: P, r: number, h: number?)
	local up = h or 5
	Canvas.ellipse(c, p[1] + up * 0.25, p[2] + up, r, r * 0.6, 0, Kit.BLACK, 0.22)
end

--[[ A ball lit from the upper left: the page's radial gradient. ]]
function Kit.orb(c: Ctx, p: number, q: number, r: number, cIn: RGB, cOut: RGB, a: number?)
	local alpha = a or 1
	if r <= 0.1 or alpha <= 0 then
		return
	end
	local glowCol = c.glowCol
	if c.glowBlur > 0 and glowCol then
		local light = c.light
		c.light = true
		Canvas.glowDot(c, p, q, r + c.glowBlur * 0.6, glowCol, alpha * 0.45)
		c.light = light
	end
	Kit.disc(c, p, q, r, cOut, alpha)
	Canvas.glowDot(c, p - r * 0.3, q - r * 0.3, r * 0.95, cIn, alpha)
end

--[[ A filled circle: the cleaves' octagon when small, twelve-sided past
     8 pixels across the middle, where an octagon's corners show. ]]
function Kit.disc(c: Ctx, p: number, q: number, r: number, colour: RGB, alpha: number)
	if r <= 8 then
		Canvas.dot(c, p, q, r, colour, alpha)
		return
	end
	local xs, ys = {}, {}
	for i = 0, 11 do
		local an = i / 12 * TAU
		xs[i + 1], ys[i + 1] = p + math.cos(an) * r, q + math.sin(an) * r
	end
	local glowBlur = c.glowBlur
	c.glowBlur = 0
	Kit.fan(c, p, q, xs, ys, colour, alpha)
	c.glowBlur = glowBlur
end

--[[ A filled slice of a circle, `from` to `to` radians. ]]
function Kit.arcFill(
	c: Ctx,
	cx: number,
	cy: number,
	r: number,
	from: number,
	to: number,
	colour: RGB,
	alpha: number
)
	local xs, ys = {}, {}
	local n = math.max(4, math.ceil(math.abs(to - from) / 0.35))
	for i = 0, n do
		local an = lerp(from, to, i / n)
		table.insert(xs, cx + math.cos(an) * r)
		table.insert(ys, cy + math.sin(an) * r)
	end
	Kit.fan(c, cx, cy, xs, ys, colour, alpha)
end

--[[ A band between two edges sampled alike (the page's closed curves:
     a fang, a flame, a lens), coloured by `colour(u)`, u 0 to 1 along. ]]
function Kit.band(
	c: Ctx,
	ax: { number },
	ay: { number },
	bx: { number },
	by: { number },
	colour: (u: number) -> (RGB, number)
)
	local n = #ax
	if n < 2 then
		return
	end
	local glowCol = c.glowCol
	if c.glowBlur > 0 and glowCol then
		local mx, my, far = 0, 0, 0
		for i = 1, n do
			mx += (ax[i] + bx[i]) / (2 * n)
			my += (ay[i] + by[i]) / (2 * n)
		end
		for i = 1, n do
			far = math.max(far, math.sqrt((ax[i] - mx) ^ 2 + (ay[i] - my) ^ 2))
		end
		local light = c.light
		c.light = true
		Canvas.glowDot(c, mx, my, far + c.glowBlur * 0.6, glowCol, 0.45)
		c.light = light
	end
	local cols, alphas = {}, {}
	for i = 1, n do
		cols[i], alphas[i] = colour((i - 1) / (n - 1))
	end
	Canvas.push(c, table.clone(ax), table.clone(ay), table.clone(bx), table.clone(by), cols, alphas)
end

--[[ The two edges of a closed shape the page draws as two curves from
     one point to another: both sampled `n` times from (x0, y0). ]]
function Kit.lens(
	x0: number,
	y0: number,
	x1: number,
	y1: number,
	top: { number },
	bottom: { number },
	n: number?
): ({ number }, { number }, { number }, { number })
	local count = n or 8
	local ax, ay, bx, by = { x0 }, { y0 }, { x0 }, { y0 }
	if #top == 2 then
		Kit.qcurve(ax, ay, x0, y0, top[1], top[2], x1, y1, count)
		Kit.qcurve(bx, by, x0, y0, bottom[1], bottom[2], x1, y1, count)
	else
		Kit.bcurve(ax, ay, x0, y0, top[1], top[2], top[3], top[4], x1, y1, count)
		Kit.bcurve(bx, by, x0, y0, bottom[1], bottom[2], bottom[3], bottom[4], x1, y1, count)
	end
	return ax, ay, bx, by
end

--[[ A filled outline, fanned from (cx, cy) (any shape that point sees all
     of). `colour` may be a function of a place: the page's gradient. A
     glowing fill sits on a soft glow, as `Canvas.fill`'s does. ]]
function Kit.fan(
	c: Ctx,
	cx: number,
	cy: number,
	xs: { number },
	ys: { number },
	colour: RGB | (x: number, y: number) -> RGB,
	alpha: number
)
	local n = #xs
	if n < 3 or alpha <= 0 then
		return
	end
	local at: (x: number, y: number) -> RGB = if type(colour) == "function"
		then colour
		else function()
			return colour :: RGB
		end
	local glowCol = c.glowCol
	if c.glowBlur > 0 and glowCol then
		local far = 0
		for i = 1, n do
			far = math.max(far, math.sqrt((xs[i] - cx) ^ 2 + (ys[i] - cy) ^ 2))
		end
		local light = c.light
		c.light = true
		Canvas.glowDot(c, cx, cy, far + c.glowBlur * 0.6, glowCol, alpha * 0.45)
		c.light = light
	end
	local mid = at(cx, cy)
	for i = 1, n do
		local j = i % n + 1
		local ex, ey = (xs[i] + xs[j]) / 2, (ys[i] + ys[j]) / 2
		Canvas.push(
			c,
			{ xs[i], cx },
			{ ys[i], cy },
			{ xs[j], cx },
			{ ys[j], cy },
			{ at(ex, ey), mid },
			{ alpha, alpha }
		)
	end
end

--[[ Points along a quadratic curve and a cubic one, from (x0, y0) (left
     out, the caller has it) to (x1, y1). ]]
function Kit.qcurve(
	xs: { number },
	ys: { number },
	x0: number,
	y0: number,
	cx: number,
	cy: number,
	x1: number,
	y1: number,
	n: number?
)
	local count = n or 6
	for i = 1, count do
		local u = i / count
		local a, b, e = (1 - u) ^ 2, 2 * u * (1 - u), u * u
		table.insert(xs, a * x0 + b * cx + e * x1)
		table.insert(ys, a * y0 + b * cy + e * y1)
	end
end
function Kit.bcurve(
	xs: { number },
	ys: { number },
	x0: number,
	y0: number,
	c1x: number,
	c1y: number,
	c2x: number,
	c2y: number,
	x1: number,
	y1: number,
	n: number?
)
	local count = n or 8
	for i = 1, count do
		local u = i / count
		local v = 1 - u
		table.insert(
			xs,
			v * v * v * x0 + 3 * v * v * u * c1x + 3 * v * u * u * c2x + u * u * u * x1
		)
		table.insert(
			ys,
			v * v * v * y0 + 3 * v * v * u * c1y + 3 * v * u * u * c2y + u * u * u * y1
		)
	end
end

--[[ An axis-lined rectangle (the page's fillRect) and its outline. ]]
function Kit.rect(c: Ctx, x: number, y: number, w: number, h: number, colour: RGB, alpha: number)
	if w <= 0 or h <= 0 then
		return
	end
	Canvas.quad(c, x, y, x + w, y, x + w, y + h, x, y + h, colour, alpha)
end
function Kit.strokeRect(
	c: Ctx,
	x: number,
	y: number,
	w: number,
	h: number,
	width: number,
	colour: RGB,
	alpha: number
)
	Canvas.outline(c, { x, x + w, x + w, x }, { y, y, y + h, y + h }, width, colour, alpha)
end

--[[ The page's jag: a lightning line from a to b. ]]
function Kit.jag(
	c: Ctx,
	ax: number,
	ay: number,
	bx: number,
	by: number,
	seed: number,
	amp: number,
	n: number,
	w: number,
	colour: RGB,
	alpha: number
)
	local an = math.atan2(by - ay, bx - ax)
	local xs, ys = { ax }, { ay }
	for i = 1, n - 1 do
		local u = i / n
		local o = (Canvas.rnd(seed, i, 5) - 0.5) * 2 * amp
		table.insert(xs, lerp(ax, bx, u) - math.sin(an) * o)
		table.insert(ys, lerp(ay, by, u) + math.cos(an) * o)
	end
	table.insert(xs, bx)
	table.insert(ys, by)
	Kit.stroke(c, xs, ys, w, colour, alpha)
end

---------------------------------------------------------------- what is shed

export type ShedOpts = {
	rate: number,
	life: number,
	spd: number?,
	spread: number?,
	rise: number?,
	grav: number?,
	side: number?,
	lat: Lat?,
	draw: (px: number, py: number, k: number, h: number, i: number, ang: number) -> (),
}

--[[ Particles shed along the flight, worked out from time alone so
     nothing is stored (`k` runs 0 to 1 over each one's life). ]]
function Kit.shed(_c: Ctx, I: Shot, t: number, o: ShedOpts)
	if Kit.lite then
		return
	end
	local rnd = Canvas.rnd
	local n = math.ceil(math.min(I.tEnd, t) * o.rate)
	for i = 0, n - 1 do
		local h1, h2, h3 = rnd(I.seed, i, 31), rnd(I.seed, i, 32), rnd(I.seed, i, 33)
		local te = (i + h1) / o.rate
		if te > I.tEnd then
			break
		end
		local age = t - te
		local L = o.life * (0.7 + 0.6 * h2)
		if age < 0 or age > L then
			continue
		end
		local p = hd(I, te, o.lat)
		local dir = p[3] + PI + (h3 - 0.5) * (o.spread or 2.4)
		local sp = (o.spd or 10) * (0.4 + h2 * 1.2)
		local px = p[1] + math.cos(dir) * sp * age
		local py = p[2]
			+ math.sin(dir) * sp * age
			- (o.rise or 0) * age
			+ 0.5 * (o.grav or 0) * age * age
		if o.side then
			local sd = (h1 - 0.5) * 2 * o.side
			px -= math.sin(p[3]) * sd
			py += math.cos(p[3]) * sd
		end
		o.draw(px, py, age / L, h3, i, p[3])
	end
end

--[[ Marks left behind at a steady beat, each `life` seconds. ]]
function Kit.drops(
	_c: Ctx,
	I: Shot,
	t: number,
	gap: number,
	life: number,
	draw: (q: P, k: number, i: number) -> (),
	lat: Lat?
)
	if Kit.lite then
		return
	end
	local n = math.floor(math.min(t, I.tEnd) / gap)
	for i = math.max(0, math.floor((t - life) / gap)), n do
		local te = i * gap
		local age = t - te
		if te > I.tEnd or age < 0 or age > life then
			continue
		end
		draw(hd(I, te, lat), age / life, i)
	end
end

export type BurstOpts = {
	n: number,
	life: number,
	spd: number,
	even: boolean?,
	rot: number?,
	cone: number?,
	base: number?,
	rise: number?,
	grav: number?,
	draw: (px: number, py: number, k: number, h: number, i: number, dir: number) -> (),
}

--[[ A burst from a hit: `base` aims a cone (back the way the shot came,
     by default), `even` spaces the pieces round a ring. ]]
function Kit.burst(_c: Ctx, P: P, a: number, seed: number, o: BurstOpts)
	if a < 0 then
		return
	end
	local rnd = Canvas.rnd
	for i = 0, o.n - 1 do
		local h1, h2, h3 = rnd(seed, i, 41), rnd(seed, i, 42), rnd(seed, i, 43)
		local L = o.life * (0.7 + 0.6 * h3)
		if a > L then
			continue
		end
		local dir
		if o.even then
			dir = i / o.n * TAU + (h1 - 0.5) * 0.5 + (o.rot or 0)
		elseif o.cone then
			dir = (o.base or P[3] + PI) + (h1 - 0.5) * o.cone
		else
			dir = h1 * TAU
		end
		local sp = o.spd * (0.5 + h2)
		local d = sp * a * (1 - 0.5 * a / L)
		o.draw(
			P[1] + math.cos(dir) * d,
			P[2] + math.sin(dir) * d - (o.rise or 0) * a + 0.5 * (o.grav or 0) * a * a,
			a / L,
			h2,
			i,
			dir
		)
	end
end

--[[ A ring growing to R pixels over `life` seconds, fading as it goes. ]]
function Kit.wave(
	c: Ctx,
	P: P,
	a: number,
	life: number,
	R: number,
	colour: RGB,
	w: number?,
	r0: number?
)
	if a < 0 or a > life then
		return
	end
	local k = a / life
	local r = lerp(r0 or 0, R, 1 - (1 - k) * (1 - k))
	Canvas.ring(c, P[1], P[2], r, colour, 1 - k, (w or 2) * (1 - k) + 0.4)
end

--[[ Soft puffs out from a hit. ]]
function Kit.puff(
	c: Ctx,
	P: P,
	a: number,
	seed: number,
	colour: RGB,
	n: number?,
	life: number?,
	spd: number?
)
	Kit.burst(c, P, a, seed + 11, {
		n = n or 6,
		life = life or 0.5,
		spd = spd or 16,
		even = true,
		draw = function(px, py, kk)
			Canvas.dot(c, px, py, 2.5 + kk * 5, colour, 0.45 * (1 - kk))
		end,
	})
end

---------------------------------------------------------------- shared pieces

--[[ An arrow centred on its point, nose forward (+x): `fl` is "leaf",
     "vane" or nil for no fletching; no `ch`, no head. ]]
function Kit.arrow(c: Ctx, L: number, cs: RGB, ch: RGB?, cf: RGB?, fl: string?, w: number?)
	local n, b = L / 2, -L / 2
	Kit.seg(c, b, 0, n - 3, 0, w or 1.8, cs, 1)
	if ch then
		Canvas.tri(c, n - 5, -2.6, n - 4, 0, n, 0, ch, 1)
		Canvas.tri(c, n - 4, 0, n - 5, 2.6, n, 0, ch, 1)
	end
	if cf and fl == "leaf" then
		Canvas.leaf(c, b + 3, -1.7, 3, -0.45, cf, 1)
		Canvas.leaf(c, b + 3, 1.7, 3, 0.45, cf, 1)
	elseif cf and fl == "vane" then
		Canvas.quad(c, b + 6, 0, b + 1, -2.8, b - 0.5, -2.8, b + 2, 0, cf, 1)
		Canvas.quad(c, b + 6, 0, b + 2, 0, b - 0.5, 2.8, b + 1, 2.8, cf, 1)
	end
end

--[[ An arrow stuck in the wall, quivering, then fading (as today's). ]]
function Kit.stuck(c: Ctx, P: P, a: number, cs: RGB, cf: RGB?, fl: string?)
	if a > 0.8 then
		return
	end
	local wob = math.sin(a * 55) * 0.12 * math.exp(-a * 9)
	local alpha = c.alpha
	c.alpha *= 1 - clamp((a - 0.55) / 0.25)
	Kit.at(c, P[1], P[2], P[3] + wob, function()
		Kit.at(c, -3.5, 0, 0, function()
			Kit.arrow(c, 11, cs, nil, cf, fl, 1.8)
		end)
	end)
	c.alpha = alpha
end

function Kit.leafDrift(c: Ctx, P: P, a: number, colour: RGB, seed: number, life: number)
	local k = a / life
	if k > 1 then
		return
	end
	Canvas.leaf(
		c,
		P[1] - math.cos(P[3]) * k * 12 + math.sin(a * 9 + seed) * 4,
		P[2] + k * 10,
		3.4,
		a * 5,
		colour,
		1 - k
	)
end

--[[ A ring of short lines growing out from P, like roots; with `back` they
     pull back in from that age. ]]
function Kit.roots(
	c: Ctx,
	P: P,
	a: number,
	seed: number,
	colour: RGB,
	life: number,
	R: number,
	n: number?,
	back: number?
)
	if a < 0 or a > life then
		return
	end
	local g = sm(a / 0.25)
	if back then
		g *= 1 - sm((a - back) / (life - back))
	end
	local f = if back then 1 else 1 - clamp((a - 0.4) / (life - 0.4))
	if g <= 0.01 or f <= 0 then
		return
	end
	local rnd = Canvas.rnd
	local count = n or 6
	for i = 0, count - 1 do
		local an = i / count * TAU + rnd(seed, i, 1) * 0.6
		local px, py = P[1], P[2]
		local seg = R * g / 4
		local xs, ys = { px }, { py }
		local mx, my, ma = 0, 0, 0
		for s = 0, 3 do
			an += (rnd(seed, i, s + 3) - 0.5) * 0.9
			px += math.cos(an) * seg
			py += math.sin(an) * seg
			table.insert(xs, px)
			table.insert(ys, py)
			if s == 1 then
				mx, my, ma = px, py, an
			end
		end
		Canvas.polyline(c, xs, ys, 1.4, colour, f)
		local b = ma + (if rnd(seed, i, 9) < 0.5 then -0.9 else 0.9)
		Kit.seg(
			c,
			mx,
			my,
			mx + math.cos(b) * seg * 1.2,
			my + math.sin(b) * seg * 1.2,
			1.4,
			colour,
			f
		)
	end
end

--[[ A seed of fluff: a dot with its hairs, the hairs one sparkle quad
     (two beams where three strokes took six). ]]
function Kit.fluff(c: Ctx, p: number, q: number, a: number, colour: RGB, h: number)
	if a <= 0 then
		return
	end
	Kit.rect(c, p - 0.9, q - 0.9, 1.8, 1.8, colour, a)
	local r = 2.4
	local an = h * TAU
	local ux, uy = math.cos(an) * r, math.sin(an) * r
	Canvas.quad(
		c,
		p - ux - uy,
		q - uy + ux,
		p - ux + uy,
		q - uy - ux,
		p + ux + uy,
		q + uy - ux,
		p + ux - uy,
		q + uy + ux,
		colour,
		a * 0.8,
		Canvas.SPARKLE
	)
end

--[[ A speck too small to see as round: one beam, not a dot's three. ]]
function Kit.speck(c: Ctx, p: number, q: number, r: number, colour: RGB, alpha: number)
	if r <= 0.05 or alpha <= 0 then
		return
	end
	Kit.rect(c, p - r * 0.9, q - r * 0.9, r * 1.8, r * 1.8, colour, alpha)
end

--[[ The coin-op shots' pixel grid. ]]
Kit.G = 2.5
function Kit.qz(v: number): number
	return math.round(v / Kit.G) * Kit.G
end
function Kit.pix(c: Ctx, px: number, py: number, colour: RGB, alpha: number?, s: number?)
	local size = s or Kit.G
	Kit.rect(c, Kit.qz(px) - size / 2, Kit.qz(py) - size / 2, size, size, colour, alpha or 1)
end

return Kit
