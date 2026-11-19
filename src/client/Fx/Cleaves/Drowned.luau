--!strict
--[[
	The Drowned Village's cleaves, cards #18 to #27 of the Blade Cleaves
	page: five swords and five pairs of daggers. Each is its card's `ST`
	code, line for line, in `Fx/Cleaves/Canvas`'s port of the page's
	helpers.
]]

local Canvas = require(script.Parent.Canvas)

type Ctx = Canvas.Ctx
type Inst = Canvas.Inst
type Look = Canvas.Look
type RGB = Canvas.RGB

local C = Canvas
local clamp, mix, rnd = C.clamp, C.mix, C.rnd
local WHITE = C.WHITE
local PI, TAU = math.pi, C.TAU

local Drowned = {}

-- #18: a teal water crescent with a foamy outer edge; falls as drops
-- that ripple on the floor.
function Drowned.TidewoodBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local F = C.frame(I, 0, s.h, { w = 0.55 })
	if C.fillBand(c, F, W.c0, W.c1, 0.88 * s.a, 0, 1, 0.5) then
		C.strokeLine(c, F, 0, 0, 1, function(v)
			return -math.abs(math.sin(v * s.h * 34)) * 2.6
		end, 2.6, WHITE, 0.9 * s.a, 40)
	end
	C.motes(c, I, t, {
		n = 16,
		on = "dis",
		life = 0.8,
		spd = 10,
		f0 = 0.1,
		f1 = 0.7,
		draw = function(p, q, k)
			if k < 0.35 then
				-- a drop falling onto the floor
				local saved = C.save(c)
				c.lift += (1 - k / 0.35) * 10 / c.s
				C.dot(c, p, q, 1.9, W.c2, 0.95)
				C.restore(c, saved)
			else
				local r = (k - 0.35) / 0.65
				C.ring(c, p, q, 2 + r * 9, WHITE, 0.65 * (1 - r), 1.1)
			end
		end,
	})
end

-- #19: a wave that thickens toward the tip and curls over into a hook;
-- washes forward and sprays.
function Drowned.TidehookBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K, e, sg = C.KK(I), s.e, C.sweepSign(I)
	local saved = C.save(c)
	local up = C.ang(I, 0.5)
	c.ox += math.cos(up) * e * 16
	c.oy += math.sin(up) * e * 16
	local F = C.frame(I, 0, s.h, { w = 0.52, prof = C.P.head })
	if C.fillBand(c, F, W.c0, W.c1, s.a, 0, 1, 0.3) then
		local th = C.ang(I, s.h)
		local hx0, hy0 = C.pt(I, s.h, I.R - K * 0.2)
		local cx, cy = hx0 - math.cos(th) * 8, hy0 - math.sin(th) * 8
		C.arcLine(c, cx, cy, 8, th, th + sg * 4.4, 6, W.c0, s.a)
		C.arcLine(c, cx, cy, 8, th, th + sg * 4.4, 1.8, WHITE, 0.92 * s.a)
		C.strokeLine(c, F, 0, 0.15, 0.97, nil, 2, W.c2, 0.9 * s.a)
	end
	C.restore(c, saved)
	C.motes(c, I, t, {
		n = 16,
		u0 = 0.6,
		u1 = 1,
		life = 0.45,
		spd = 46,
		grav = 40,
		f0 = 0,
		f1 = 0.3,
		draw = function(p, q, k)
			C.dot(c, p, q, 1.8 * (1 - k * 0.5), W.c2, 1 - k)
		end,
	})
end

-- #20: paving slabs pop up along the arc; they sink back in a puff of
-- dust.
function Drowned.CausewayBlade(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K = C.headU(I, t), C.dis(I, t), C.KK(I)
	local n = 8
	for i = 0, n - 1 do
		local u0, u1 = i / n + 0.008, (i + 1) / n - 0.008
		if u0 > h then
			break
		end
		local pop = C.sm((t - C.passT(I, (u0 + u1) / 2)) / 0.07)
		local sk = clamp(d * 1.6 - rnd(I.seed, i, 2) * 0.6)
		if sk >= 1 then
			continue
		end
		local F = C.frame(I, u0, math.min(u1, h), {
			w = 0.6 * pop * (1 - sk * 0.6),
			prof = C.P.one,
			rOut = I.R - K * 0.04 + (rnd(I.seed, i, 1) - 0.5) * 7,
		})
		if
			C.fillBand(
				c,
				F,
				mix(W.c0, { 60, 50, 40 }, sk * 0.5),
				mix(W.c0, W.c1, 0.35),
				1 - sk,
				0,
				1,
				1
			)
		then
			C.strokePath(c, F, 0, 1, nil, 1.4, W.c1, 0.85 * (1 - sk), 3)
			C.strokeLine(c, F, 0.12, 0.1, 0.9, nil, 1, WHITE, 0.35 * (1 - sk), 3)
		end
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.6,
		spd = 8,
		f0 = 0,
		f1 = 0.8,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 5 + k * 6, W.c2, 0.45 * (1 - k))
		end,
	})
	C.motes(c, I, t, {
		n = 12,
		on = "dis",
		life = 0.6,
		spd = 12,
		f0 = 0,
		f1 = 0.8,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 5 + k * 8, W.c2, 0.5 * (1 - k))
		end,
	})
end

-- #21 (Legendary, glows): a bright gold arc with a bronze rim; rings pulse
-- out of it like a struck bell.
function Drowned.TollguardBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K = C.KK(I)
	local F = C.frame(I, 0, s.h, { w = 0.4 })
	C.glow(c, W, W.c0, 14)
	local ok = C.fillBand(c, F, W.c1, W.c0, s.a, 0, 1, 0.6)
	C.noGlow(c)
	if ok then
		C.strokePath(c, F, 0, 1, nil, 1.6, { 156, 98, 30 }, 0.95 * s.a)
	end
	for _, u in { 0.2, 0.5, 0.8 } do
		if u > s.h then
			continue
		end
		local tt = t - C.passT(I, u)
		local p, q = C.pt(I, u, I.R - K * 0.18)
		for k = 0, 1 do
			local r = (tt - k * 0.13) / 0.5
			if r > 0 and r < 1 then
				C.ring(c, p, q, 4 + r * 24, W.c2, (1 - r) * 0.9, 2.2 * (1 - r) + 0.5)
			end
		end
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.5,
		spd = 10,
		rise = 14,
		f0 = 0,
		f1 = 0.4,
		draw = function(p, q, k, hh)
			C.spark(c, p, q, 3.2 * math.sin(PI * k), hh, W.c1, 1)
		end,
	})
end

-- #22 (Mythic, glows): a pane of faceted glass with lightning crackling
-- inside; shatters into shards that fly outward.
function Drowned.StormglassBlade(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, n = C.headU(I, t), C.dis(I, t), 10
	if d <= 0 then
		local F = C.frame(I, 0, h, { w = 0.62 })
		if F.ok then
			C.glow(c, W, { 186, 218, 255 }, 20)
			C.fillBandStops(c, F, {
				{ u = 0, c = W.c0, a = 0.3 },
				{ u = h, c = W.c1, a = 0.68 },
			}, 0, 1, n)
			C.noGlow(c)
			C.strokePath(c, F, 0, 1, nil, 1.2, WHITE, 0.85, n)
			for i = 1, n - 1 do
				local a, b = F.p(i / n, 0)
				local cc, e = F.p(math.min(1, (i + 0.5) / n), 1)
				C.polyline(c, { a, cc }, { b, e }, 0.8, WHITE, 0.35)
			end
			local sd = I.seed * 97 + math.floor(t * 22)
			local xs, ys = {}, {}
			for i = 0, 12 do
				local x, y =
					F.p(i / 12, 0.45, if i > 0 and i < 12 then (rnd(sd, i, 1) - 0.5) * 14 else 0)
				xs[i + 1], ys[i + 1] = x, y
			end
			C.glowAlways(c, { 210, 230, 255 }, 8)
			C.polyline(c, xs, ys, 1.5, WHITE, 1)
			C.noGlow(c)
		end
	else
		local F = C.frame(I, 0, 1, { w = 0.62 })
		local k = C.sm(d)
		for i = 0, n - 1 do
			local v0, v1 = i / n, (i + 1) / n
			local th = C.ang(I, (v0 + v1) / 2)
			local corners = {
				{ { F.p(v0, 0) }, { F.p(v1, 0) }, { F.p(v0, 1) } },
				{ { F.p(v1, 0) }, { F.p(v1, 1) }, { F.p(v0, 1) } },
			}
			for j, tr in corners do
				local cx = (tr[1][1] + tr[2][1] + tr[3][1]) / 3
				local cy = (tr[1][2] + tr[2][2] + tr[3][2]) / 3
				local fly = k * (18 + rnd(I.seed, i, j - 1) * 24)
				local rot = k * (rnd(I.seed, i, j - 1 + 5) - 0.5) * 5
				local ox, oy = cx + math.cos(th) * fly, cy + math.sin(th) * fly
				local cs, sn = math.cos(rot), math.sin(rot)
				local xs, ys = {}, {}
				for m, corner in tr do
					local dx, dy = corner[1] - cx, corner[2] - cy
					xs[m], ys[m] = ox + dx * cs - dy * sn, oy + dx * sn + dy * cs
				end
				C.tri(c, xs[1], ys[1], xs[2], ys[2], xs[3], ys[3], W.c0, 0.55 * (1 - k))
				C.outline(c, xs, ys, 1, WHITE, 0.85 * (1 - k))
			end
		end
	end
	C.motes(c, I, t, {
		n = 10,
		on = "dis",
		life = 0.5,
		spd = 30,
		f0 = 0,
		f1 = 1,
		draw = function(p, q, k, hh)
			C.spark(c, p, q, 3.5 * math.sin(PI * k), hh, WHITE, 1)
		end,
	})
end

-- #23: two grainy grey-blue lines, dripping; fades and dries.
function Drowned.DriftwoodDirks(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local F = C.frame(I, 0, s.h, { w = 0.24 })
	if F.ok and s.a > 0 then
		for _, f in { 0.1, 0.8 } do
			local function g(v: number): number
				return math.sin(v * 30 + f * 5) * 0.8
			end
			C.strokeLine(c, F, f, 0, 1, g, 2.8, W.c1, s.a, 24)
			C.strokeLine(c, F, f, 0, 1, g, 1.2, W.c0, s.a, 24)
		end
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.5,
		spd = 4,
		grav = 70,
		f0 = 0.1,
		f1 = 0.9,
		draw = function(p, q, k)
			C.dot(c, p, q, 1.6, { 196, 226, 240 }, 1 - k)
		end,
	})
end

-- #24: a cut made of bubbles; the bubbles pop one by one.
function Drowned.BarnacleKnives(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K = C.headU(I, t), C.dis(I, t), C.KK(I)
	C.fillBand(c, C.frame(I, 0, h, { w = 0.14 }), W.c1, W.c1, 0.4 * (1 - C.sm(d)), 0, 1, 0.4)
	for i = 0, 15 do
		local u = rnd(I.seed, i, 1)
		if u > h then
			continue
		end
		local g = C.sm((t - C.passT(I, u)) / 0.06)
		local r = 2.2 + rnd(I.seed, i, 3) * 4.5
		local p, q = C.pt(I, u, I.R - K * 0.3 * rnd(I.seed, i, 2) * C.P.cres(u) - 2)
		local k = clamp((d - rnd(I.seed, i, 4) * 0.8) / 0.2)
		if k <= 0 then
			C.dot(c, p, q, r * g, W.c0, 0.18)
			C.ring(c, p, q, r * g, W.c0, 0.95, 1.4)
			C.dot(c, p - r * 0.35, q - r * 0.35, r * 0.25 * g, WHITE, 0.9)
		elseif k < 1 then
			for j = 0, 3 do
				local a = j * PI / 2 + 0.4
				C.dot(
					c,
					p + math.cos(a) * r * (1 + k),
					q + math.sin(a) * r * (1 + k),
					1.2 * (1 - k),
					W.c2,
					1 - k
				)
			end
		end
	end
end

-- #25: a jagged electric line, yellow over blue; flickers off.
function Drowned.EeltoothDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e = s.e
	if not (e > 0 and rnd(I.seed, math.floor(t * 30), 9) < e) then
		local F = C.frame(I, 0, s.h, { w = 0.2 })
		if F.ok then
			local sd = I.seed * 97 + math.floor(t * 25)
			local xs, ys = {}, {}
			for i = 0, 12 do
				local x, y =
					F.p(i / 12, 0.5, if i > 0 and i < 12 then (rnd(sd, i, 1) - 0.5) * 11 else 0)
				xs[i + 1], ys[i + 1] = x, y
			end
			C.glowAlways(c, W.c0, 12)
			C.polyline(c, xs, ys, 4, W.c0, 0.9)
			C.noGlow(c)
			C.polyline(c, xs, ys, 1.6, W.c1, 1)
		end
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.25,
		spd = 60,
		f0 = 0,
		f1 = 0.5,
		draw = function(p, q, k, hh, _i, th)
			C.shard(c, p, q, 2.6, th + hh * 3, W.c2, 1 - k)
		end,
	})
end

-- #26 (Legendary, glows): a thin teal cut that stamps a bronze bell mark
-- at its tip; the mark rings out twice and fades.
function Drowned.TollbellDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K = C.KK(I)
	local F = C.frame(I, 0, s.h, { w = 0.18 })
	C.glow(c, W, W.c0, 10)
	local ok = C.fillBand(c, F, W.c2, W.c0, s.a, 0, 1, 0.5)
	C.noGlow(c)
	if ok then
		C.strokeLine(c, F, 0, 0.1, 0.95, nil, 1, W.c1, 0.85 * s.a)
	end
	local mt = t - I.T
	if mt > 0 then
		local p, q = C.pt(I, 1, I.R - K * 0.1)
		local a = 1 - C.sm(clamp((mt - (I.H + I.F + 0.25)) / 0.35))
		local g = C.sm(mt / 0.08)
		C.glow(c, W, W.c1, 10)
		C.arcLine(c, p, q, 7 * g, -PI / 2 + 0.45, -PI / 2 + TAU - 0.45, 2.4, W.c1, a)
		C.noGlow(c)
		C.dot(c, p, q, 2.2 * g, W.c2, a)
		for k = 0, 1 do
			local r = (mt - 0.05 - k * 0.2) / 0.45
			if r > 0 and r < 1 then
				C.ring(c, p, q, 8 + r * 20, W.c2, (1 - r) * 0.85 * a, 1.5)
			end
		end
	end
end

-- #27 (Mythic, glows): an aqua cut that spirals into a small whirlpool at
-- its tip; the whirlpool spins faster and shrinks away.
function Drowned.RiptideFangs(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K, e = C.KK(I), s.e
	C.glow(c, W, W.c0, 12)
	C.fillBand(c, C.frame(I, 0, s.h, { w = 0.2, prof = C.P.head }), W.c1, W.c0, s.a, 0, 1, 0.4)
	C.noGlow(c)
	if t > I.T * 0.6 then
		local p, q = C.pt(I, s.h, I.R - K * 0.12)
		local sz = 11 * (1 - e * 0.9) * C.sm((t - I.T * 0.6) / 0.1)
		local sp = t * 9 + e * e * 14
		local xs, ys = {}, {}
		local n = C.segs(c, 32)
		for i = 0, n do
			local k = i / n
			local an = sp + k * TAU * 2.2
			local rr = sz * (1 - k)
			xs[i + 1], ys[i + 1] = p + math.cos(an) * rr, q + math.sin(an) * rr * 0.78
		end
		C.glow(c, W, W.c0, 10)
		C.polyline(c, xs, ys, 1.8, W.c1, 0.95 * (1 - e * 0.4))
		C.noGlow(c)
	end
	C.motes(c, I, t, {
		n = 12,
		life = 0.5,
		spd = 14,
		f0 = 0,
		f1 = 0.4,
		draw = function(p, q, k)
			C.dot(c, p, q, 1.5, WHITE, 1 - k)
		end,
	})
end

return table.freeze(Drowned)
