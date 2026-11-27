--!strict
--[[
	Thornwood's cleaves, cards #13 to #17 of the Blade Cleaves page: five
	pairs of daggers. Each is its card's `ST` code, line for line, in
	`Fx/Cleaves/Canvas`'s port of the page's helpers.
]]

local Canvas = require(script.Parent.Canvas)

type Ctx = Canvas.Ctx
type Inst = Canvas.Inst
type Look = Canvas.Look
type RGB = Canvas.RGB

local C = Canvas
local clamp, mix, rnd = C.clamp, C.mix, C.rnd
local WHITE = C.WHITE
local PI = math.pi

local Thorn = {}

-- #13: a row of slanted needles, like stitches; the needles drop away.
function Thorn.HedgePrickers(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K, sg = C.headU(I, t), C.dis(I, t), C.KK(I), C.sweepSign(I)
	for i = 0, 15 do
		local u = (i + 0.5) / 16
		if u > h then
			break
		end
		local g = C.sm((t - C.passT(I, u)) / 0.04)
		local fall = clamp(d * 1.6 - rnd(I.seed, i, 1) * 0.6)
		if fall >= 1 then
			continue
		end
		local p, q = C.pt(I, u, I.R - K * 0.16)
		local dir = C.ang(I, u) + sg * 0.8
		local L = 9 * g
		local dx, dy = math.cos(dir) * L / 2, math.sin(dir) * L / 2
		local saved = C.save(c)
		c.lift -= fall * fall * 12 / c.s
		C.polyline(c, { p - dx, p + dx }, { q - dy, q + dy }, 2.1, W.c0, 1 - fall)
		C.dot(c, p + dx, q + dy, 1.4, W.c1, 1 - fall)
		C.restore(c, saved)
	end
end

-- #14: an ivory tusk shape, thick where it starts and sharp at the tip,
-- outlined in brown; flakes into bone chips.
function Thorn.TuskKnives(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local F = C.frame(I, 0, s.h, { w = 0.4, prof = C.P.tusk })
	if C.fillBand(c, F, W.c0, mix(W.c0, W.c1, 0.2), s.a, 0, 1, 0.9) then
		C.strokePath(c, F, 0, 1, nil, 1.7, W.c1, 0.95 * s.a)
		C.strokeLine(c, F, 0.25, 0.1, 0.8, nil, 1.2, WHITE, 0.65 * s.a)
	end
	C.motes(c, I, t, {
		n = 12,
		on = "dis",
		life = 0.5,
		spd = 22,
		grav = 120,
		f0 = 0,
		f1 = 0.4,
		draw = function(p, q, k, hh)
			C.chip(c, p, q, 2.6, hh * 8, W.c2, 1 - k)
		end,
	})
end

-- #15: a magenta cut studded with spiky burrs; the burrs roll off outward.
function Thorn.BurrfangDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K, e = C.KK(I), s.e
	C.fillBand(c, C.frame(I, 0, s.h, { w = 0.2 }), W.c0, W.c1, s.a, 0, 1, 0.5)
	for i = 0, 4 do
		local u = 0.12 + i * 0.19
		if u > s.h then
			break
		end
		local g = C.sm((t - C.passT(I, u)) / 0.06)
		local th = C.ang(I, u)
		local roll = e * e * (14 + rnd(I.seed, i, 1) * 14)
		local p, q = C.pt(I, u, I.R - K * 0.1)
		p += math.cos(th) * roll
		q += math.sin(th) * roll
		C.spiky(c, p, q, 6 * g, roll * 0.3 + i, W.c1, 1 - e, 8, 0.6)
		C.dot(c, p, q, 2.2 * g, W.c2, 1 - e)
	end
end

-- #16 (Legendary, glows): three glowing silk threads weaving round each
-- other, beaded with dew; the threads go slack and sag away.
function Thorn.SilkfangDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e, K = s.e, C.KK(I)
	local mid = I.R - K * 0.15
	local amp = 5.5 * (1 - e * 0.8)
	local hh = if s.h ~= 0 then s.h else 1
	local saved = C.save(c)
	c.lift -= e * e * 12 / c.s
	local function path(k: number, dy: number?): ({ number }, { number })
		local xs, ys = {}, {}
		local n = C.segs(c, 24)
		for i = 0, n do
			local u = i / n * s.h
			local p, q = C.pt(I, u, mid + math.sin(u * 18 + k * 2.1) * amp * C.P.cres(u / hh))
			xs[i + 1], ys[i + 1] = p, q + (dy or 0)
		end
		return xs, ys
	end
	if s.h > 0.002 then
		local xs, ys = path(0, 3)
		C.polyline(c, xs, ys, 2, W.c1, 0.45 * (1 - e))
		C.glow(c, W, W.c0, 10)
		for k = 0, 2 do
			local px, py = path(k)
			C.polyline(
				c,
				px,
				py,
				if k == 1 then 1 else 1.5,
				if k == 1 then WHITE else W.c0,
				(1 - e) * (if k == 1 then 0.75 else 0.95)
			)
		end
		C.noGlow(c)
	end
	for i = 0, 5 do
		local u = (i + 0.5) / 6
		if u > s.h then
			break
		end
		local p, q = C.pt(I, u, mid + math.sin(u * 18) * amp * C.P.cres(u / hh))
		C.dot(c, p, q, 1.9, W.c2, 1 - e)
	end
	C.restore(c, saved)
end

-- #17 (Mythic, glows): three shadow claw marks with hot-pink edges, firing
-- a fan of thorns; sinks into a shadow pool.
function Thorn.LurkerClaws(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e, K = s.e, C.KK(I)
	local pa = C.sm(e * 2) * (1 - C.after(I, t, 0.8))
	if pa > 0 then
		local p, q = C.pt(I, 0.5, I.R - K * 0.3)
		C.ellipse(c, p, q, 30 + e * 22, 12 + e * 9, C.ang(I, 0.5) + PI / 2, { 20, 8, 24 }, 0.5 * pa)
	end
	local shade: RGB = { 28, 14, 32 }
	for j, fo in { 0, 0.2, 0.4 } do
		local lead = (j - 1) * 0.05
		local F = C.frame(I, lead, math.max(lead, s.h - (j - 1) * 0.04), {
			w = 0.13 * (1 - e * 0.7),
			rOut = I.R - K * fo,
		})
		if not F.ok or e >= 1 then
			continue
		end
		C.glow(c, W, W.c0, 12)
		C.fillBand(c, F, shade, shade, 1 - e * 0.8, 0, 1, 1)
		C.noGlow(c)
		C.strokePath(c, F, 0, 1, nil, 1.5, W.c0, 1 - e)
	end
	C.motes(c, I, t, {
		n = 9,
		life = 0.35,
		spd = 110,
		spread = 0.7,
		f0 = 0,
		f1 = 0.2,
		draw = function(p, q, k, _hh, _i, th)
			C.shard(c, p, q, 4, th, W.c1, 1 - k)
		end,
	})
	C.motes(c, I, t, {
		n = 10,
		on = "dis",
		life = 0.7,
		spd = 6,
		rise = 30,
		sway = 5,
		f0 = 0,
		f1 = 0.5,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 6, { 70, 30, 80 }, 0.6 * (1 - k))
		end,
	})
end

return table.freeze(Thorn)
