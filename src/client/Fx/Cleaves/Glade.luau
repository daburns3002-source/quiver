--!strict
--[[
	The Mossy Glade's cleaves, cards #1 to #12 of the Blade Cleaves page:
	six swords and six pairs of daggers. Each is its card's `ST` code, line
	for line, in `Fx/Cleaves/Canvas`'s port of the page's helpers.
]]

local Canvas = require(script.Parent.Canvas)

type Ctx = Canvas.Ctx
type Inst = Canvas.Inst
type Look = Canvas.Look
type RGB = Canvas.RGB

local C = Canvas
local clamp, lerp, mix, rnd = C.clamp, C.lerp, C.mix, C.rnd
local WHITE = C.WHITE
local PI = math.pi

local Glade = {}

-- #1: a warm red crescent with wood-grain lines; sawdust flicks off.
function Glade.TimberBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "retract")
	local F = C.frame(I, s.u0, s.u1, { w = 0.62 })
	if C.fillBand(c, F, W.c0, W.c1, 1, 0, 1, 0.65) then
		for _, f in { 0.28, 0.52, 0.76 } do
			C.strokeLine(c, F, f, 0.06, 0.94, function(v)
				return math.sin(v * 22 + f * 7) * 1.3
			end, 1, W.c1, 0.55, 14)
		end
	end
	C.motes(c, I, t, {
		n = 18,
		life = 0.5,
		spd = 22,
		grav = 140,
		f0 = 0.1,
		f1 = 0.6,
		lag = 0.2,
		draw = function(p, q, k, h)
			C.chip(c, p, q, 2.4 + h * 1.5, h * 9, W.c2, 1 - k)
		end,
	})
end

-- #2: a heavy stone crescent with a bumpy moss rim; breaks into seven
-- chunks that drop, leaving hairline cracks.
function Glade.MossstoneBlade(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K = C.headU(I, t), C.dis(I, t), C.KK(I)
	local stone: RGB = { 136, 144, 126 }
	local ca = math.min(C.sm(d * 3), 1 - C.after(I, t, 0.8))
	if ca > 0 then
		for i = 0, 6 do
			local u = (i + 0.5) / 7
			local px, py = C.pt(I, u, I.R - K * 0.32)
			local xs, ys = { px }, { py }
			for j = 0, 2 do
				local th = C.ang(I, u) + (rnd(I.seed, i, j) - 0.5) * 2.4
				px += math.cos(th) * 7
				py += math.sin(th) * 7
				table.insert(xs, px)
				table.insert(ys, py)
			end
			C.polyline(c, xs, ys, 1.3, { 24, 30, 20 }, 0.6 * ca)
		end
	end
	local n = 7
	for i = 0, n - 1 do
		local g0 = i / n
		if g0 >= h then
			break
		end
		local k = clamp(d * 1.7 - rnd(I.seed, i, 3) * 0.7)
		if k >= 1 then
			continue
		end
		local saved = C.save(c)
		c.alpha = 1 - k
		c.lift -= k * k * 16 / c.s
		local F = C.frame(I, g0 + 0.004, math.min((i + 1) / n, h) - 0.004, {
			w = 0.78,
			g = { 0, math.max(h, 0.001) },
		})
		if
			C.fillBand(c, F, mix(stone, W.c0, 0.22), mix(stone, { 44, 48, 40 }, 0.45), 1, 0, 1, 0.9)
		then
			C.strokePath(c, F, 0, 1, nil, 1, { 40, 46, 36 }, 0.6)
			C.strokeLine(c, F, 0, 0, 1, function(v)
				return -math.abs(math.sin(v * 9 + i)) * 1.8
			end, 3.2, W.c0, 1, 6)
		end
		C.restore(c, saved)
	end
	C.motes(c, I, t, {
		n = 14,
		on = "dis",
		life = 0.5,
		spd = 16,
		grav = 170,
		f0 = 0.1,
		f1 = 0.8,
		draw = function(p, q, k, hh)
			C.chip(c, p, q, 3 + hh * 2, hh * 7, mix(stone, { 60, 66, 56 }, hh), 1 - k)
		end,
	})
end

-- #3: a twisting vine whose thorns spring out as the blade passes; the
-- thorns pull back and leaves drift off.
function Glade.ThornBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local a, h = 1 - s.e, s.h
	local F = C.frame(I, 0, h, { w = 0.42 })
	C.fillBand(c, F, W.c2, W.c1, 0.35 * a, 0, 1, 0.4)
	local function wv(v: number): number
		return math.sin(v * h * 16) * 2.2
	end
	if F.ok then
		C.strokeLine(c, F, 0.2, 0, 1, wv, 4.2, W.c1, a, 20)
		C.strokeLine(c, F, 0.2, 0, 1, wv, 1.7, W.c0, a, 20)
	end
	local n = 16
	for i = 0, n - 1 do
		local u = (i + 0.5) / n
		if u > h then
			break
		end
		local g = C.sm((t - C.passT(I, u)) / 0.06) * (1 - s.e * 0.9)
		if g <= 0 then
			continue
		end
		local v = u / (if h ~= 0 then h else 1)
		local px, py = C.pt(I, u, F.rad(v, 0.2) + wv(v))
		local out = if i % 2 == 1 then 0 else PI
		local th = C.ang(I, u) + out + (if i % 2 == 1 then -0.4 else 0.4) * C.sweepSign(I)
		local tg = C.ang(I, u) + PI / 2
		local L = (8 + rnd(I.seed, i, 2) * 5) * g
		local bx, by = math.cos(tg) * 2.8, math.sin(tg) * 2.8
		C.tri(
			c,
			px - bx,
			py - by,
			px + bx,
			py + by,
			px + math.cos(th) * L,
			py + math.sin(th) * L,
			W.c1,
			a
		)
	end
	C.motes(c, I, t, {
		n = 12,
		on = "dis",
		life = 0.7,
		spd = 14,
		grav = 30,
		sway = 8,
		f0 = 0.1,
		f1 = 0.6,
		draw = function(p, q, k, hh)
			C.leaf(c, p, q, 3.6, hh * 6 + k * 3, W.c2, 1 - k)
		end,
	})
end

-- #4: a violet crescent strung with silk, like a slice of web; the
-- threads snap one by one and sag away.
function Glade.BroodsplitBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e, h = s.e, s.h
	local a = 1 - e
	local F = C.frame(I, 0, h, { w = 0.85 })
	C.fillBand(c, F, W.c0, W.c1, 0.55 * a, 0, 1, 0.45)
	if F.ok then
		for _, f in { 0.06, 0.4, 0.74 } do
			C.strokeLine(c, F, f, 0, 1, function(v)
				return -math.abs(math.sin(v * h * PI * 7)) * (2 + e * 8)
			end, 1.1, W.c2, 0.9 * a, 28)
		end
		for i = 0, 8 do
			local u = i / 8
			if u > h + 1e-6 then
				break
			end
			local v = u / (if h ~= 0 then h else 1)
			local ox, oy = F.p(v, 0)
			local ix, iy = F.p(v, 0.95)
			local sn = clamp(e * 1.7 - rnd(I.seed, i, 4) * 0.6)
			if sn <= 0 then
				C.polyline(c, { ox, ix }, { oy, iy }, 1.1, W.c2, 0.9 * a)
			else
				local m = 0.5 * (1 - sn)
				C.polyline(c, { ox, lerp(ox, ix, m) }, { oy, lerp(oy, iy, m) }, 1.1, W.c2, 0.9 * a)
				C.polyline(c, { ix, lerp(ix, ox, m) }, { iy, lerp(iy, oy, m) }, 1.1, W.c2, 0.9 * a)
			end
		end
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.4,
		spd = 34,
		f0 = 0,
		f1 = 0.5,
		draw = function(p, q, k, _hh, _i, th)
			C.shard(c, p, q, 3.5, th, W.c0, 1 - k)
		end,
	})
end

-- #5 (Legendary, glows): flames lick off the outer edge and embers rise;
-- burns away from the tail and leaves a scorch mark that cools.
function Glade.EmberfangBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "retract")
	local h = C.headU(I, t)
	local sc = math.min(C.sm((t - I.T * 0.4) / 0.12), 1 - C.after(I, t, 0.9))
	if sc > 0 then
		local scorch: RGB = { 38, 18, 8 }
		C.fillBand(c, C.frame(I, 0, h, { w = 0.5 }), scorch, scorch, 0.4 * sc, 0, 1, 1)
	end
	c.light = true
	local F = C.frame(I, s.u0, s.u1, { w = 0.55 })
	local function fl(v: number, f: number): number
		if f ~= 0 then
			return 0
		end
		return (math.abs(math.sin(v * 26 + t * 30)) * 7 + math.abs(math.sin(v * 11 - t * 21)) * 4)
			* C.P.cres(v)
	end
	C.glow(c, W, W.c0, 16)
	C.fillBand(c, F, W.c1, W.c0, 0.95, 0, 1, 0.75, fl, 2.5)
	C.noGlow(c)
	C.fillBand(c, F, { 255, 250, 215 }, W.c1, 0.7, 0, 0.33, 0.3, fl, 2.5)
	C.motes(c, I, t, {
		n = 26,
		life = 0.7,
		spd = 12,
		rise = 30,
		f0 = 0,
		f1 = 0.5,
		sway = 6,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 4, W.c2, 1 - k)
		end,
	})
	C.motes(c, I, t, {
		n = 16,
		on = "dis",
		life = 0.6,
		spd = 10,
		rise = 36,
		f0 = 0,
		f1 = 0.6,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 3.5, { 255, 200, 90 }, 1 - k)
		end,
	})
	c.light = false
end

local GLADEHEART_PASTELS: { RGB } = {
	{ 226, 196, 246 },
	{ 196, 242, 224 },
	{ 255, 212, 236 },
	{ 204, 222, 255 },
}

-- #6 (Mythic, glows): a shimmering pastel crescent edged in white,
-- scattering little + stars; fades into stars that float up.
function Glade.GladeheartBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local F = C.frame(I, 0, s.h, { w = 0.6 })
	if F.ok and s.a > 0 then
		local stops: { Canvas.Stop } = {}
		for i = 0, 6 do
			local u = i / 6 * s.h
			local z = i * 0.7 + t * 3
			local j = math.floor(z) % 4
			local colour = mix(
				GLADEHEART_PASTELS[j + 1],
				GLADEHEART_PASTELS[(j + 1) % 4 + 1],
				z - math.floor(z)
			)
			table.insert(
				stops,
				{ u = u, c = mix(colour, WHITE, 0.2), a = s.a * (0.5 + 0.5 * i / 6) }
			)
		end
		C.glow(c, W, { 232, 205, 255 }, 20)
		C.fillBandStops(c, F, stops)
		C.noGlow(c)
		C.strokeLine(c, F, 0, 0, 1, nil, 1.8, WHITE, 0.95 * s.a)
		C.strokeLine(c, F, 0.55, 0, 1, nil, 1, W.c0, 0.9 * s.a)
	end
	C.motes(c, I, t, {
		n = 16,
		life = 0.8,
		spd = 10,
		rise = 26,
		f0 = 0.05,
		f1 = 0.6,
		draw = function(p, q, k, hh)
			C.cross(c, p, q, (2.6 + hh * 3) * math.sin(PI * k), 0, WHITE, 1 - k * 0.4)
		end,
	})
	C.motes(c, I, t, {
		n = 14,
		on = "dis",
		life = 0.7,
		spd = 16,
		rise = 32,
		f0 = 0,
		f1 = 0.6,
		draw = function(p, q, k, hh)
			C.cross(c, p, q, (2 + hh * 3) * math.sin(PI * k), 0, W.c0, 1)
		end,
	})
end

-- #7: a thin violet cut flicking wood chips; snaps into three splinters
-- that drift apart.
function Glade.SplinterDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local h = C.headU(I, t)
	local e = C.sm(C.dis(I, t))
	local parts = if e > 0 then 3 else 1
	for i = 0, parts - 1 do
		local u0 = i / parts * h
		local u1 = (i + 1) / parts * h - (if parts > 1 then 0.025 else 0)
		local F = C.frame(I, u0, u1, { w = 0.24, g = if parts > 1 then { 0, 1 } else nil })
		local saved = C.save(c)
		if parts > 1 then
			local th = C.ang(I, (u0 + u1) / 2)
			c.ox += math.cos(th) * e * 10 + (i - 1) * e * 5
			c.oy += math.sin(th) * e * 10
		end
		C.fillBand(c, F, W.c0, W.c1, 1 - e, 0, 1, 0.5)
		C.restore(c, saved)
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.4,
		spd = 30,
		grav = 120,
		f0 = 0,
		f1 = 0.25,
		draw = function(p, q, k, hh)
			C.chip(c, p, q, 2.4, hh * 8, W.c2, 1 - k)
		end,
	})
end

-- #8: two thin green scratches with thorn ticks; fades as a few leaves
-- drop.
function Glade.BrambleShivs(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local F = C.frame(I, 0, s.h, { w = 0.3 })
	if F.ok and s.a > 0 then
		for _, f in { 0.15, 0.75 } do
			C.strokeLine(c, F, f, 0, 1, nil, 2.6, W.c1, s.a)
			C.strokeLine(c, F, f, 0, 1, nil, 1.2, W.c0, s.a)
		end
		for i = 0, 13 do
			local u = (i + 0.5) / 14
			if u > s.h then
				break
			end
			local v = u / s.h
			local f = if i % 2 == 1 then 0.15 else 0.75
			local x0, y0 = F.p(v, f)
			local x1, y1 = F.p(math.min(1, v + 0.03), f, if i % 2 == 1 then 4.5 else -4.5)
			C.polyline(c, { x0, x1 }, { y0, y1 }, 1.2, W.c1, s.a)
		end
	end
	C.motes(c, I, t, {
		n = 8,
		on = "dis",
		life = 0.7,
		spd = 8,
		grav = 40,
		sway = 7,
		f0 = 0,
		f1 = 0.3,
		draw = function(p, q, k, hh)
			C.leaf(c, p, q, 3.4, hh * 6 + k * 3, W.c2, 1 - k)
		end,
	})
end

-- #9: a faint line dotted with glowing fireflies; they wander off,
-- blinking.
function Glade.FireflyFangs(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K = C.KK(I)
	C.fillBand(c, C.frame(I, 0, s.h, { w = 0.16 }), W.c1, W.c1, 0.55 * s.a, 0, 1, 0.3)
	c.light = true
	for i = 0, 11 do
		local u = (i + 0.5) / 12
		if u > s.h then
			break
		end
		local ag = t - C.passT(I, u)
		local wn = clamp(ag - 0.08)
		local p, q = C.pt(I, u, I.R - K * 0.08)
		p += math.sin(ag * 5 + i * 1.7) * 12 * wn + (rnd(I.seed, i, 1) - 0.5) * 34 * wn
		q += math.cos(ag * 4 + i) * 9 * wn - 14 * wn
		local life = 1 - clamp((ag - 0.25) / 0.85)
		local blink = 0.55 + 0.45 * math.sin(ag * 16 + i * 2)
		C.glowDot(c, p, q, 7, W.c2, 0.95 * blink * life)
		C.dot(c, p, q, 1.4, { 255, 255, 225 }, life)
	end
	c.light = false
end

-- #10: three lime claw marks with violet edges; they stay a moment as
-- dark scratches on the floor.
function Glade.GladeFoxClaws(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K = C.headU(I, t), C.dis(I, t), C.KK(I)
	local m = C.sm(d * 2) * (1 - C.after(I, t, 0.7))
	local scar: RGB = { 22, 28, 14 }
	for _, claw in { { 0, 0.92, 0 }, { 0.04, 1, 0.22 }, { 0.08, 0.96, 0.44 } } do
		local a0, a1, fo = claw[1], claw[2], claw[3]
		local u1 = math.min(h, a1)
		local F = C.frame(I, math.min(a0, u1), u1, { w = 0.12, rOut = I.R - K * fo })
		if not F.ok then
			continue
		end
		if m > 0 then
			C.fillBand(c, F, scar, scar, 0.5 * m, 0, 1, 1)
		end
		if d < 1 then
			C.strokePath(c, F, 0, 1, nil, 2.6, W.c1, 1 - d)
			C.fillBand(c, F, W.c0, W.c0, 1 - d, 0, 1, 0.6)
		end
	end
	C.motes(c, I, t, {
		n = 8,
		life = 0.35,
		spd = 40,
		f0 = 0,
		f1 = 0.5,
		draw = function(p, q, k, _hh, _i, th)
			C.shard(c, p, q, 3, th, W.c2, 1 - k)
		end,
	})
end

-- #11 (Legendary, glows): two flame fangs, one chasing the other; burns
-- out into embers.
function Glade.EmberWilfFangs(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "retract")
	local K = C.KK(I)
	c.light = true
	for j, fang in { { 0, 0 }, { 0.08, 0.42 } } do
		local lag, fo = fang[1], fang[2]
		local u1 = math.max(0, s.u1 - lag)
		local F =
			C.frame(I, math.min(s.u0, u1), u1, { w = 0.26, prof = C.P.head, rOut = I.R - K * fo })
		C.glow(c, W, W.c0, 12)
		C.fillBand(c, F, W.c2, W.c1, 1, 0, 1, 0.6, function(v, f)
			return if f == 0 then math.abs(math.sin(v * 22 + t * 34 + (j - 1))) * 4.5 * v else 0
		end, 2.5)
		C.noGlow(c)
	end
	C.motes(c, I, t, {
		n = 18,
		life = 0.6,
		spd = 10,
		rise = 30,
		sway = 6,
		f0 = 0,
		f1 = 0.6,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 3.6, W.c2, 1 - k)
		end,
	})
	c.light = false
end

-- #12 (Mythic, glows): a bright pastel cut with a pink and a blue
-- after-image; the ghosts drift apart and twinkle out.
function Glade.GlimmerhornDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K, e = C.KK(I), s.e
	local ghosts: { RGB } = { W.c1, W.c2 }
	local lags, sides = { -0.1, -0.05 }, { -1, 1 }
	for j, colour in ghosts do
		local F = C.frame(I, 0, clamp(s.h + lags[j]), {
			w = 0.22,
			rOut = I.R - K * 0.12 + sides[j] * (K * 0.09 + e * 12),
		})
		C.fillBand(c, F, colour, colour, 0.5 * s.a, 0, 1, 0.3)
	end
	C.glow(c, W, W.c0, 16)
	C.fillBand(
		c,
		C.frame(I, 0, s.h, { w = 0.24, rOut = I.R - K * 0.12 }),
		WHITE,
		W.c0,
		s.a,
		0,
		1,
		0.5
	)
	C.noGlow(c)
	C.motes(c, I, t, {
		n = 14,
		life = 0.7,
		spd = 12,
		rise = 14,
		f0 = 0,
		f1 = 0.4,
		draw = function(p, q, k, hh)
			local colour = if hh > 0.66 then W.c1 elseif hh > 0.33 then W.c2 else WHITE
			C.cross(c, p, q, 2.8 * math.sin(PI * k), 0, colour, 1)
		end,
	})
end

return table.freeze(Glade)
