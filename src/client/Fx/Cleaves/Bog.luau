--!strict
--[[
	Bogheart's cleaves, cards #28 to #37 of the Blade Cleaves page: five
	swords and five pairs of daggers. Each is its card's `ST` code, line
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
local PI, TAU = math.pi, C.TAU

local Bog = {}

-- #28: a thick iron-grey cut with a hot orange edge, throwing sparks;
-- fades and leaves mud splats behind.
function Bog.BogironBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K = C.KK(I)
	local ma = C.sm(C.dis(I, t) * 2) * (1 - C.after(I, t, 0.9))
	if ma > 0 then
		for i = 0, 5 do
			local p, q = C.pt(I, rnd(I.seed, i, 1), I.R - K * lerp(0.1, 0.6, rnd(I.seed, i, 2)))
			C.blob(c, p, q, 4 + rnd(I.seed, i, 3) * 5, I.seed + i, { 76, 58, 40 }, 0.6 * ma)
		end
	end
	local F = C.frame(I, 0, s.h, { w = 0.72 })
	if C.fillBand(c, F, W.c0, W.c1, s.a, 0, 1, 0.85) then
		C.strokePath(c, F, 0, 1, nil, 1, { 36, 38, 32 }, 0.55 * s.a)
		C.strokeLine(c, F, 0, 0.05, 0.95, nil, 2.4, W.c2, s.a)
	end
	C.motes(c, I, t, {
		n = 14,
		life = 0.3,
		spd = 80,
		spread = 0.8,
		f0 = 0,
		f1 = 0.15,
		draw = function(p, q, k, _hh, _i, th)
			C.shard(c, p, q, 3.2, th, W.c2, 1 - k)
		end,
	})
end

-- #29: overlapping shell scales laid along the arc; the scales flip over
-- and fall, tail first.
function Bog.ShellbackCleaver(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K, sg = C.headU(I, t), C.dis(I, t), C.KK(I), C.sweepSign(I)
	local n = 11
	for i = 0, n - 1 do
		local u = (i + 0.5) / n
		if u > h then
			break
		end
		local g = C.sm((t - C.passT(I, u)) / 0.06)
		local fl = clamp(d * 1.7 - (i / n) * 0.7)
		if fl >= 1 then
			continue
		end
		local p, q = C.pt(I, u, I.R - K * 0.3)
		local th = C.ang(I, u)
		local sz = (K * 0.2 + K * 0.14 * C.P.cres(u)) * g
		if sz < 0.5 then
			continue
		end
		-- the scale's own space: turned across the arc, squashed as it flips
		local rot = th + sg * PI / 2
		local cs, sn = math.cos(rot), math.sin(rot)
		local sy = math.max(0.05, math.cos(fl * PI * 0.5))
		local function at(x: number, y: number): (number, number)
			y *= sy
			return p + x * cs - y * sn, q + x * sn + y * cs
		end
		local saved = C.save(c)
		c.lift -= fl * fl * 12 / c.s
		c.alpha *= 1 - fl
		-- a fan: the centre and its arc from -1.15 to 1.15
		local xs, ys = { p }, { q }
		local m = C.segs(c, 6)
		for k = 0, m do
			local an = -1.15 + 2.3 * k / m
			local x, y = at(math.cos(an) * sz, math.sin(an) * sz)
			table.insert(xs, x)
			table.insert(ys, y)
		end
		C.fill(c, xs, ys, mix(W.c0, W.c1, if i % 2 == 1 then 0.3 else 0), 1)
		C.outline(c, xs, ys, 1.3, W.c2, 0.95)
		for _, r in { 0.45, 0.75 } do
			local ax, ay = {}, {}
			local arcs = C.segs(c, 4)
			for k = 0, arcs do
				local an = -1 + 2 * k / arcs
				ax[k + 1], ay[k + 1] = at(math.cos(an) * sz * r, math.sin(an) * sz * r)
			end
			C.polyline(c, ax, ay, 0.8, W.c1, 0.6)
		end
		C.restore(c, saved)
	end
end

-- #30: a glowing yellow-green arc with a dotted spore line, and mushroom
-- caps popping up on its edge; the caps puff into floating spores.
function Bog.CaplightBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local F = C.frame(I, 0, s.h, { w = 0.5 })
	c.light = true
	if C.fillBand(c, F, W.c0, W.c1, 0.7 * s.a, 0, 1, 0.4) then
		C.dashLine(c, F, 0.55, 2, 5, 2, W.c2, 0.95 * s.a)
	end
	c.light = false
	for i = 0, 3 do
		local u = 0.14 + i * 0.24
		if u > s.h then
			break
		end
		local g = C.sm((t - C.passT(I, u)) / 0.08) * (1 - s.e)
		if g <= 0 then
			continue
		end
		local p, q = C.pt(I, u, I.R - 1)
		local r = (5 + (i % 2) * 2) * g
		local rot = C.ang(I, u) + PI / 2
		local cs, sn = math.cos(rot), math.sin(rot)
		local function at(x: number, y: number): (number, number)
			return p + x * cs - y * sn, q + x * sn + y * cs
		end
		-- the stem
		local x0, y0 = at(-r * 0.22, 0)
		local x1, y1 = at(r * 0.22, 0)
		local x2, y2 = at(r * 0.22, r * 0.7)
		local x3, y3 = at(-r * 0.22, r * 0.7)
		C.quad(c, x0, y0, x1, y1, x2, y2, x3, y3, { 244, 240, 210 }, 0.95)
		-- the cap: a half disc, its rim outlined
		local ax, ay, bx, by = {}, {}, {}, {}
		local rim, rimY = {}, {}
		for k = 0, 6 do
			local x = -r + 2 * r * k / 6
			local top = -math.sqrt(math.max(0, r * r - x * x))
			ax[k + 1], ay[k + 1] = at(x, top)
			bx[k + 1], by[k + 1] = at(x, 0)
			rim[k + 1], rimY[k + 1] = ax[k + 1], ay[k + 1]
		end
		C.strip(c, ax, ay, bx, by, W.c0, 1)
		table.insert(rim, bx[1])
		table.insert(rimY, by[1])
		C.polyline(c, rim, rimY, 1, W.c1, 1)
		local d0x, d0y = at(-r * 0.4, -r * 0.45)
		local d1x, d1y = at(r * 0.25, -r * 0.6)
		C.dot(c, d0x, d0y, r * 0.15, WHITE, 0.9)
		C.dot(c, d1x, d1y, r * 0.12, WHITE, 0.9)
	end
	c.light = true
	C.motes(c, I, t, {
		n = 14,
		life = 0.9,
		spd = 6,
		rise = 20,
		sway = 5,
		f0 = 0,
		f1 = 0.6,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 3.5, W.c2, 0.9 * (1 - k))
		end,
	})
	C.motes(c, I, t, {
		n = 14,
		on = "dis",
		u0 = 0.1,
		u1 = 0.9,
		life = 0.9,
		spd = 8,
		rise = 24,
		sway = 5,
		f0 = 0,
		f1 = 0.2,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 4, W.c0, 1 - k)
		end,
	})
	c.light = false
end

-- #31 (Legendary, glows): a thick, wobbling slime arc with a wet shine,
-- dripping; sags flat into slime puddles.
function Bog.GulpfangBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e, K = s.e, C.KK(I)
	local pa = C.sm(e * 2) * (1 - C.after(I, t, 0.9))
	if pa > 0 then
		for i = 0, 4 do
			local p, q = C.pt(I, (i + 0.5) / 5, I.R - K * 0.32)
			C.ellipse(c, p, q + 6, 8 + rnd(I.seed, i, 1) * 5, 3.5, 0, W.c0, 0.4 * pa)
		end
	end
	local F = C.frame(I, 0, s.h, { w = 0.6 * (1 - e * 0.85), mid = I.R - K * 0.32 })
	local function goo(v: number, f: number): number
		return math.sin(v * s.h * 18 + f * 3 + t * 6) * 2.2 * (if f == 0 then 1 else 0.6)
	end
	C.glow(c, W, W.c0, 12)
	local ok = C.fillBand(c, F, W.c1, W.c0, 1 - e * 0.5, 0, 1, 0.85, goo, 1.5)
	C.noGlow(c)
	if ok then
		C.strokeLine(c, F, 0.18, 0.1, 0.85, function(v)
			return goo(v, 0) * 0.6
		end, 1.7, WHITE, 0.6 * (1 - e), 16)
	end
	for i = 0, 5 do
		local u = (i + 0.5) / 6
		if u > s.h or not F.ok then
			break
		end
		local ag = t - C.passT(I, u)
		local p, q = F.p(u / (if s.h ~= 0 then s.h else 1), 0.9)
		local L = clamp(ag / 0.4) * (6 + rnd(I.seed, i, 1) * 9) + e * 8
		C.ellipse(c, p, q + L / 2, L / 2 + 1.5, 2.3, PI / 2, W.c0, 0.95 * (1 - e * 0.6))
	end
end

-- #32 (Mythic, glows): a cyan glow line, then crystals jut out of the
-- floor along it; the crystals shatter into rising light.
function Bog.DeepglowBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e, K = s.e, C.KK(I)
	c.light = true
	C.glow(c, W, W.c0, 16)
	C.fillBand(c, C.frame(I, 0, s.h, { w = 0.28 }), W.c1, W.c0, 0.9 * (1 - e), 0, 1, 0.5)
	C.noGlow(c)
	c.light = false
	for i = 0, 8 do
		local u = (i + 0.5) / 9
		if u > s.h then
			break
		end
		local g = C.sm((t - C.passT(I, u) - 0.03) / 0.1)
		local br = clamp(e * 1.5 - rnd(I.seed, i, 1) * 0.5)
		if br >= 1 or g <= 0 then
			continue
		end
		local th = C.ang(I, u) + (rnd(I.seed, i, 2) - 0.5) * 0.6
		local p, q = C.pt(I, u, I.R - K * (0.22 + rnd(I.seed, i, 3) * 0.35))
		local L = (14 + rnd(I.seed, i, 4) * 12) * g * (1 - br)
		local wd = 4 + rnd(I.seed, i, 5) * 2.5
		local cs, sn = math.cos(th), math.sin(th)
		local function at(x: number, y: number): (number, number)
			return p + x * cs - y * sn, q + x * sn + y * cs
		end
		local xs, ys = {}, {}
		for k, corner in
			{
				{ L, 0 },
				{ L * 0.55, -wd },
				{ -L * 0.15, -wd * 0.7 },
				{ -L * 0.2, wd * 0.7 },
				{ L * 0.55, wd },
			}
		do
			xs[k], ys[k] = at(corner[1], corner[2])
		end
		C.glow(c, W, W.c0, 10)
		C.fill(c, xs, ys, mix(W.c0, WHITE, 0.25), 0.88)
		C.noGlow(c)
		local fx, fy = {}, {}
		for k, corner in { { L, 0 }, { L * 0.55, -wd }, { L * 0.3, 0 } } do
			fx[k], fy[k] = at(corner[1], corner[2])
		end
		C.fill(c, fx, fy, WHITE, 0.6)
	end
	c.light = true
	C.motes(c, I, t, {
		n = 18,
		on = "dis",
		life = 0.8,
		spd = 10,
		rise = 34,
		f0 = 0.2,
		f1 = 0.6,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 4, W.c0, 1 - k)
		end,
	})
	c.light = false
end

-- #33: a soft, fuzzy line of moss specks; the fuzz spreads and fades.
function Bog.MossShivs(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K = C.headU(I, t), C.sm(C.dis(I, t)), C.KK(I)
	for i = 0, 69 do
		local u = rnd(I.seed, i, 1)
		if u > h then
			continue
		end
		-- a weaker device draws a share of the specks
		if c.detail < 1 and rnd(I.seed, i, 15) > c.detail then
			continue
		end
		local sp = d * (6 + rnd(I.seed, i, 3) * 8)
		local an = rnd(I.seed, i, 4) * TAU
		local p, q = C.pt(I, u, I.R - K * 0.26 * C.P.cres(u) * rnd(I.seed, i, 2))
		C.dot(
			c,
			p + math.cos(an) * sp,
			q + math.sin(an) * sp,
			1.2 + rnd(I.seed, i, 5) * 1.4,
			if i % 4 ~= 0 then W.c0 else W.c1,
			(1 - d) * 0.92
		)
	end
end

-- #34: a thin pink cut that leaves spore puffs; the puffs swell and fade.
function Bog.SporeFangs(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K = C.KK(I)
	C.fillBand(c, C.frame(I, 0, s.h, { w = 0.16 }), W.c0, W.c0, s.a, 0, 1, 0.4)
	for i = 0, 3 do
		local u = 0.15 + i * 0.23
		if u > s.h then
			break
		end
		local g = clamp((t - C.passT(I, u)) / 0.55)
		local p, q = C.pt(I, u, I.R - K * 0.15)
		for j = 0, 2 do
			local an = j * 2.1 + i
			C.glowDot(
				c,
				p + math.cos(an) * 8 * g,
				q + math.sin(an) * 8 * g - g * 6,
				5 + g * 9,
				W.c1,
				0.65 * (1 - g)
			)
		end
	end
	C.motes(c, I, t, {
		n = 14,
		life = 0.7,
		spd = 6,
		rise = 18,
		sway = 5,
		f0 = 0,
		f1 = 0.4,
		draw = function(p, q, k)
			C.dot(c, p, q, 1.3, W.c2, 1 - k)
		end,
	})
end

-- #35: a glowing wavy line, like a kris blade's edge; flattens out and
-- fades.
function Bog.GlowcapKris(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e, K = s.e, C.KK(I)
	local amp = 6 * (1 - e)
	local mid = I.R - K * 0.15
	if s.h > 0.002 and e < 1 then
		local hh = if s.h ~= 0 then s.h else 1
		local xs, ys = {}, {}
		local n = C.segs(c, 30)
		for i = 0, n do
			local u = i / n * s.h
			xs[i + 1], ys[i + 1] = C.pt(I, u, mid + math.sin(u * PI * 6) * amp * C.P.cres(u / hh))
		end
		c.light = true
		C.glowAlways(c, W.c0, 10)
		C.polyline(c, xs, ys, 5, W.c0, 0.8 * (1 - e))
		C.noGlow(c)
		C.polyline(c, xs, ys, 1.8, W.c1, 1 - e)
		c.light = false
	end
	C.motes(c, I, t, {
		n = 8,
		on = "dis",
		life = 0.6,
		spd = 10,
		rise = 14,
		sway = 6,
		f0 = 0,
		f1 = 0.4,
		draw = function(p, q, k, hh)
			C.leaf(c, p, q, 3, hh * 6, W.c2, 1 - k)
		end,
	})
end

-- #36 (Legendary, glows): a pink sticky tongue with a round tip, spitting
-- yellow drops; stretches, then snaps back to where it started.
function Bog.ToadtongueDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K = C.headU(I, t), C.dis(I, t), C.KK(I)
	local u1 = h * (1 - C.easeInBack(d))
	local F = C.frame(I, 0, math.max(0, u1), {
		w = 0.24,
		prof = function(v: number): number
			return math.min(1, v * 5)
		end,
		mid = I.R - K * 0.14,
	})
	if F.ok then
		C.glow(c, W, W.c0, 10)
		C.fillBand(c, F, W.c0, mix(W.c0, { 120, 30, 60 }, 0.3), 1, 0, 1, 0.9)
		C.noGlow(c)
		C.strokeLine(c, F, 0.5, 0.08, 0.9, nil, 1.2, { 150, 40, 80 }, 0.7)
		local p, q = F.p(1, 0.5)
		C.dot(c, p, q, K * 0.12 + 2.5, mix(W.c0, WHITE, 0.15), 1)
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.4,
		spd = 40,
		grav = 100,
		f0 = 0,
		f1 = 0.3,
		draw = function(p, q, k)
			C.dot(c, p, q, 1.8, W.c1, 1 - k)
		end,
	})
end

-- #37 (Mythic, glows): a white cut that splits into cyan, gold and
-- pale-blue bands; the bands fan apart and fade.
function Bog.PrismStingers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K, e = C.KK(I), s.e
	c.light = true
	for j, colour in { W.c0, W.c1, W.c2 } do
		local off = (j - 2) * (2 + math.max(0, t - I.T) * 30)
		C.glow(c, W, colour, 10)
		C.fillBand(
			c,
			C.frame(I, 0, s.h, { w = 0.16, rOut = I.R - K * 0.1 + off }),
			colour,
			colour,
			0.85 * s.a,
			0,
			1,
			0.35
		)
		C.noGlow(c)
	end
	C.fillBand(
		c,
		C.frame(I, 0, s.h, { w = 0.12, rOut = I.R - K * 0.12 }),
		WHITE,
		WHITE,
		s.a * (1 - e),
		0,
		1,
		0.3
	)
	local bands = { W.c0, W.c1, W.c2 }
	C.motes(c, I, t, {
		n = 10,
		life = 0.45,
		spd = 24,
		f0 = 0,
		f1 = 0.4,
		draw = function(p, q, k, hh, i, th)
			C.shard(c, p, q, 3, th + hh * 4, bands[i % 3 + 1], 1 - k)
		end,
	})
	c.light = false
end

return table.freeze(Bog)
