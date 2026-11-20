--!strict
--[[
	The Mossy Glade's twelve shots, cards 1 to 12 of the Projectile Shots
	page, line for line (`Fx/Shots/Kit`). `f` draws the flight, `h` a hit.
]]

local Canvas = require(script.Parent.Parent.Cleaves.Canvas)
local Kit = require(script.Parent.Kit)

type Ctx = Canvas.Ctx
type RGB = Canvas.RGB

local C = Canvas
local K = Kit
local hd, tr, sm, clamp, mix = Kit.hd, Kit.tr, Kit.sm, Kit.clamp, Canvas.mix
local PI, TAU, WHITE, S = Kit.PI, Kit.TAU, Kit.WHITE, Kit.S

local Glade: { [string]: Kit.Drawer } = {}

local function fang(c: Ctx, W: Kit.Look)
	-- the outer edge curves to (-6, -3.4), the inner to (-4.5, -0.6)
	local ax, ay, bx, by = { 8 }, { 0 }, { 8 }, { 0 }
	K.qcurve(ax, ay, 8, 0, 1, -4.6, -6, -3.4, 8)
	K.qcurve(bx, by, 8, 0, 1, -1.2, -4.5, -0.6, 8)
	K.band(c, ax, ay, bx, by, function(u)
		return if u < 0.5 then mix(WHITE, W.c1, u / 0.5) else mix(W.c1, W.c0, (u - 0.5) / 0.5), 1
	end)
	-- the shaft without its own glow: a stroke's halo is a hard strip, and
	-- the fang's covers it
	local glowBlur = c.glowBlur
	c.glowBlur = 0
	K.seg(c, -10, 0, -3, 0, 1.6, W.c2, 1)
	c.glowBlur = glowBlur
end

local function acorn(c: Ctx, cx: number, t: number, W: Kit.Look)
	C.ellipse(c, cx + 1.5, 0, 3.6, 3, 0, W.c0, 1)
	K.arcFill(c, cx - 0.5, 0, 3.4, PI / 2, PI * 1.5, W.c1, 1)
	local s = (t * 1.4) % 1
	for j = 0, 2 do
		local yy = (((s + j / 3) % 1) - 0.5) * 6.2
		K.seg(c, cx - 3.6, yy, cx - 0.6, yy, 0.7, { 60, 34, 14 }, 1)
	end
end

local function crown(c: Ctx, cx: number, cy: number, alpha: number, colour: RGB, rot: number?)
	if alpha <= 0 then
		return
	end
	K.at(c, cx, cy, rot or 0, function()
		K.rect(c, -3.6, 0.4, 7.2, 1.4, colour, alpha)
		C.tri(c, -3.6, 0.4, -1.8, 0.4, -3.6, -1, colour, alpha)
		C.tri(c, -1.8, 0.4, 1.8, 0.4, 0, -2.4, colour, alpha)
		C.tri(c, 1.8, 0.4, 3.6, 0.4, 3.6, -1, colour, alpha)
		C.dot(c, 0, 0.6, 0.8, { 230, 60, 70 }, alpha)
	end)
end

--[[ A teardrop flame pointing up, s across, at (p, q). ]]
local function flameUp(c: Ctx, p: number, q: number, s: number, colour: RGB, alpha: number)
	if s <= 0.1 or alpha <= 0 then
		return
	end
	local ax, ay, bx, by = K.lens(p, q - s * 1.6, p, q + s * 0.6, { p + s, q }, { p - s, q }, 5)
	K.band(c, ax, ay, bx, by, function()
		return colour, alpha
	end)
end

Glade.TwigBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.ribbon(c, tr(I, t, 0.05, 6), 3.6, 0, W.c1, W.c1, 0.5, 0)
		if t < I.tEnd then
			K.shade(c, p, 3)
			K.at(c, p[1], p[2], p[3], function()
				K.arrow(c, 20, W.c0, W.c1, W.c2, "leaf")
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		K.burst(c, P, a, I.seed, {
			n = 7,
			life = 0.4,
			spd = 44,
			cone = 1.8,
			grav = 50,
			draw = function(px, py, kk, h)
				C.chip(c, px, py, 2.2, h * 9 + kk * 6, W.c0, 1 - kk)
			end,
		})
		K.leafDrift(c, P, a, W.c2, I.seed, 0.8)
		if k == "wall" then
			K.stuck(c, P, a, W.c0, W.c2, "leaf")
		end
	end,
}

Glade.AcornBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.ribbon(c, tr(I, t, 0.05, 6), 3.4, 0, W.c0, W.c0, 0.45, 0)
		if t < I.tEnd then
			K.shade(c, p, 3)
			K.at(c, p[1], p[2], p[3], function()
				K.arrow(c, 18, { 122, 84, 48 }, nil, W.c2, "leaf")
				acorn(c, 6.5, t, W)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		if a < 0.6 then
			local kk = a / 0.6
			for _, s in { -1, 1 } do
				local d = P[3] + s * 1.9
				local px = P[1] + math.cos(d) * kk * 16
				local py = P[2] + math.sin(d) * kk * 16 + kk * kk * 10
				K.at(c, px, py, s * kk * 7, function()
					local from = if s > 0 then 0 else PI
					K.arcFill(c, 0, 0, 3.6, from, from + PI, W.c0, 1 - kk * kk)
					K.rect(c, -3.6, if s > 0 then -1.2 else 0, 7.2, 1.2, W.c1, 1 - kk * kk)
				end)
			end
		end
		K.puff(c, P, a, I.seed, { 176, 150, 120 }, 5, 0.5)
		if k == "wall" then
			K.stuck(c, P, a, { 122, 84, 48 }, W.c2, "leaf")
		end
	end,
}

Glade.FireflyBow = {
	f = function(c, I, t, W)
		if t >= I.tEnd then
			return
		end
		local p = hd(I, t)
		K.ribbon(c, tr(I, t, 0.04, 5), 2.4, 0, W.c2, W.c0, 0.6, 0)
		K.shade(c, p, 2.4)
		K.at(c, p[1], p[2], p[3], function()
			K.seg(c, -8, 0, 6, 0, 1.4, W.c0, 1)
			C.glowDot(c, 6, 0, 4, W.c2, 0.9)
			C.dot(c, 6, 0, 1.2, WHITE, 1)
		end)
		for k = 1, 3 do
			local q = hd(I, math.max(0, t - 0.05 * k))
			local o = math.sin(t * 16 + k * 2.2) * 4.5
			local px, py = q[1] - math.sin(q[3]) * o, q[2] + math.cos(q[3]) * o
			local bl = 0.55 + 0.45 * math.sin(t * 22 + k * 3)
			C.glowDot(c, px, py, 4.5, W.c0, 0.7 * bl)
			C.dot(c, px, py, 1.1, { 255, 255, 220 }, bl)
		end
	end,
	h = function(c, P, a, W, I, k)
		K.burst(c, P, a, I.seed, {
			n = 7,
			life = 0.9,
			spd = 18,
			even = true,
			draw = function(px, py, kk, _h, i)
				local bl = 0.5 + 0.5 * math.sin(a * 20 + i * 2)
				local ww = math.sin(a * 8 + i) * 3
				C.glowDot(c, px + ww, py, 4.5, W.c0, 0.75 * bl * (1 - kk))
				C.dot(c, px + ww, py, 1.1, { 255, 255, 220 }, bl * (1 - kk))
			end,
		})
		if a < 0.15 then
			C.glowDot(c, P[1], P[2], 9, W.c2, 0.7 * (1 - a / 0.15))
		end
		if k == "wall" then
			K.stuck(c, P, a, W.c1, W.c0, "vane")
		end
	end,
}

Glade.MossSlimeBow = {
	f = function(c, I, t, W)
		local lat = K.sw(0.35, 22)
		local p = hd(I, t, lat)
		K.ribbon(c, tr(I, t, 0.07, 10, lat), 5.5, 1, W.c0, W.c1, 0.75, 0)
		K.shed(c, I, t, {
			rate = 28,
			life = 0.35,
			spd = 6,
			grav = 110,
			lat = lat,
			draw = function(px, py, k)
				C.dot(c, px, py, 1.6 * (1 - k * 0.4), W.c0, 1 - k)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 3.6)
		K.at(c, p[1], p[2], p[3], function()
			local s = math.sin(t * 30) * 0.18
			C.tri(c, 6, -2, 6, 2, 11, 0, W.c2, 1)
			K.at(c, 0, 0, 0, function()
				C.ellipse(c, 0, 0, 7, 4.2, 0, W.c0, 1)
				C.arcLine(c, 0, 0, 7, 0, TAU, 1.1, W.c1, 0.9, 4.2 / 7)
				C.dot(c, 2, -1.6, 1.3, WHITE, 0.85)
			end, 1 + s, 1 - s)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		local g = sm(a / 0.08)
		local f = 1 - clamp((a - 0.25) / 0.5)
		if f > 0 then
			C.spiky(c, P[1], P[2], 9.5 * g, I.ph, W.c0, f * 0.9, 7, 0.55)
			C.spiky(c, P[1], P[2], 5 * g, I.ph + 0.4, W.c2, f * 0.8, 6, 0.6)
		end
		K.burst(c, P, a, I.seed, {
			n = 8,
			life = 0.45,
			spd = 42,
			even = true,
			grav = 60,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.8 * (1 - kk * 0.5), W.c0, 1 - kk)
			end,
		})
	end,
}

Glade.EmberFangBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		c.light = true
		local pts = tr(I, t, 0.1, 12, function(J, tt)
			return math.sin(tt * 95 + J.ph) * 1.3
		end)
		K.ribbon(c, pts, 8, 0, W.c0, W.c2, 0.85, 0)
		K.ribbon(c, pts, 3.6, 0, W.c1, W.c0, 0.95, 0)
		K.shed(c, I, t, {
			rate = 38,
			life = 0.55,
			spd = 8,
			rise = 26,
			draw = function(px, py, k)
				C.glowDot(c, px + math.sin(k * 9) * 2, py, 3.2, mix(W.c1, W.c2, k), 1 - k)
			end,
		})
		c.light = false
		if t < I.tEnd then
			K.shade(c, p, 3)
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, W.c0, 14)
				fang(c, W)
				C.noGlow(c)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		local sc = 1 - clamp((a - 0.2) / 0.7)
		if sc > 0 then
			C.ring(c, P[1], P[2], 9, { 60, 24, 10 }, 0.55 * sc, 3)
			C.ring(c, P[1], P[2], 9, W.c0, 0.8 * sc * math.max(0, 1 - a * 1.6), 1.2)
		end
		c.light = true
		K.burst(c, P, a, I.seed, {
			n = 12,
			life = 0.45,
			spd = 32,
			cone = 3.2,
			rise = 22,
			draw = function(px, py, kk)
				C.glowDot(c, px, py, 4.5 * (1 - kk * 0.5), K.heat(kk * 0.4), 1 - kk)
			end,
		})
		if k ~= "wall" and a < 0.85 then
			for i = 0, 2 do
				C.glowDot(
					c,
					P[1] + (i - 1) * 4,
					P[2] - 3 - math.abs(math.sin(a * 18 + i * 2)) * 4,
					3.6,
					W.c0,
					0.8 * (1 - a / 0.85)
				)
			end
		end
		c.light = false
	end,
}

Glade.GladeSpiritBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local sc = K.shim(t)
		K.lamp(c, p, W.c1, 32, 0.32 * K.fade(I, t))
		local pts = tr(I, t, 0.13, 14)
		K.ribbon(c, pts, 10, 0, W.c1, { 200, 240, 255 }, 0.42, 0)
		K.ribbon(c, pts, 3, 0, WHITE, W.c1, 0.95, 0)
		K.shed(c, I, t, {
			rate = 28,
			life = 0.6,
			spd = 7,
			rise = 10,
			draw = function(px, py, k, h, i)
				if i % 3 ~= 0 then
					C.cross(c, px, py, (2 + h * 2.2) * math.sin(PI * k), 0, WHITE, 0.95)
				else
					C.flower(
						c,
						px,
						py,
						1.4 * (1 - k * 0.5),
						{ 255, 200, 230 },
						{ 255, 240, 150 },
						1 - k
					)
				end
			end,
		})
		if t < I.tEnd then
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, sc, 18)
				local ax, ay, bx, by = K.lens(9, 0, -8, 0, { 1, -4.4 }, { 1, 4.4 }, 8)
				K.band(c, ax, ay, bx, by, function()
					return mix(sc, WHITE, 0.35), 1
				end)
				C.noGlow(c)
				K.seg(c, 8, 0, -6, 0, 1, WHITE, 0.9)
			end)
		end
	end,
	h = function(c, P, a, W, I, _k)
		local kk = a / 0.75
		if kk < 1 then
			for i = 0, 5 do
				local an = i / 6 * TAU + I.ph
				local d = sm(a / 0.25) * 9
				C.petal(
					c,
					P[1] + math.cos(an) * d,
					P[2] + math.sin(an) * d,
					4.2 * (0.6 + 0.4 * sm(a / 0.2)),
					an,
					mix(K.shim(a + i * 0.4), WHITE, 0.3),
					1 - kk
				)
			end
			C.glowDot(c, P[1], P[2], 8, WHITE, 0.8 * (1 - kk))
		end
		K.wave(c, P, a, 0.4, 15, W.c1, 2)
		K.burst(c, P, a, I.seed, {
			n = 8,
			life = 0.8,
			spd = 12,
			even = true,
			rise = 26,
			draw = function(px, py, k2, h)
				C.cross(c, px, py, (2 + h * 2) * math.sin(PI * k2), 0, WHITE, 1)
			end,
		})
	end,
}

Glade.BranchStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.ribbon(c, tr(I, t, 0.12, 8), 6.5, 0, W.c0, W.c1, 0.55, 0)
		K.shed(c, I, t, {
			rate = 14,
			life = 0.3,
			spd = 8,
			draw = function(px, py, k)
				C.dot(c, px, py, 1.1 * (1 - k), W.c2, 1 - k)
			end,
		})
		if t < I.tEnd then
			K.shade(c, p, 3.4)
			K.orb(c, p[1], p[2], 4, W.c2, W.c0)
		end
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.35, 20, W.c0, 2.4)
		if a < 0.18 then
			C.glowDot(c, P[1], P[2], 14, W.c0, 0.55 * (1 - a / 0.18))
		end
		K.burst(c, P, a, I.seed, {
			n = 6,
			life = 0.3,
			spd = 50,
			even = true,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.4 * (1 - kk), W.c2, 1 - kk)
			end,
		})
	end,
}

Glade.ToadstoolStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.shed(c, I, t, {
			rate = 24,
			life = 0.55,
			spd = 5,
			draw = function(px, py, k)
				C.dot(c, px, py, 1.3 + k * 1.2, W.c2, 0.7 * (1 - k))
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.5)
		K.at(c, p[1], p[2], t * 6, function()
			C.dot(c, 0, 0, 5.6, W.c0, 1)
			C.ring(c, 0, 0, 5.6, { 110, 30, 26 }, 1, 1.2)
			for i = 0, 4 do
				local an = i / 5 * TAU
				C.dot(c, math.cos(an) * 3.2, math.sin(an) * 3.2, 1.2, W.c1, 1)
			end
			C.dot(c, 0, 0, 1.4, W.c1, 1)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.burst(c, P, a, I.seed, {
			n = 10,
			life = 0.75,
			spd = 30,
			even = true,
			draw = function(px, py, kk)
				C.dot(c, px, py, 3 + kk * 6, mix(W.c2, W.c1, kk), 0.55 * (1 - kk))
			end,
		})
		if a < 0.16 then
			C.dot(c, P[1], P[2], 5.6 * (1 + a / 0.16 * 0.6), W.c0, 1 - a / 0.16)
		end
	end,
}

Glade.LanternStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local lift = 0.25 * S * math.sin(t * 20 + I.ph)
		K.ribbon(c, tr(I, t, 0.08, 8), 6, 0, W.c1, { 180, 50, 20 }, 0.8, 0)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 3.6, 5 + lift)
		local q = { p[1], p[2] - lift, p[3] }
		C.glowDot(c, q[1], q[2], 11, W.c0, 0.28)
		K.at(c, q[1], q[2], q[3], function()
			local ax, ay, bx, by = K.lens(
				-9,
				0,
				5,
				0,
				{ -3, -1.5, 3, -4.4 },
				{ -3, 1.5, 3, 4.4 },
				8
			)
			K.band(c, ax, ay, bx, by, function(u)
				-- the page's gradient runs from the nose (x 5) back to x -8
				local g = 1 - u
				if g < 0.5 then
					return mix(W.c2, W.c0, g / 0.5), 1
				end
				return mix(W.c0, W.c1, (g - 0.5) / 0.5), Kit.lerp(1, 0.6, (g - 0.5) / 0.5)
			end)
		end, 1 + math.sin(t * 40) * 0.12, 1)
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.4, 20, W.c0, 2.6)
		if a < 0.2 then
			C.glowDot(c, P[1], P[2], 14, W.c2, 0.6 * (1 - a / 0.2))
		end
		K.burst(c, P, a, I.seed, {
			n = 6,
			life = 0.75,
			spd = 24,
			even = true,
			rise = 22,
			draw = function(px, py, kk)
				flameUp(c, px, py, 3.4 * (1 - kk), mix(W.c2, W.c1, kk), 1 - kk)
			end,
		})
	end,
}

Glade.HootmossStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.shed(c, I, t, {
			rate = 20,
			life = 0.45,
			spd = 9,
			draw = function(px, py, k, h)
				C.spark(c, px, py, 2.6 * math.sin(PI * k), h, W.c2, 0.95)
			end,
		})
		K.ribbon(c, tr(I, t, 0.08, 8), 5, 0, W.c0, W.c0, 0.35, 0)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4)
		K.at(c, p[1], p[2], p[3], function()
			local fl = 0.55 + 0.45 * math.sin(t * 18)
			for _, s in { -1, 1 } do
				K.at(c, -1, s * 3, 0, function()
					C.leaf(c, -3.5, s * 2.6, 5.2, s * 0.5 + PI, W.c0, 1)
				end, 1, fl)
			end
			K.orb(c, 0, 0, 4.2, W.c2, W.c1)
			C.dot(c, 1.2, 0, 1.5, W.c0, 1)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.4, 20, W.c0, 2)
		K.burst(c, P, a, I.seed, {
			n = 8,
			life = 0.85,
			spd = 30,
			even = true,
			grav = 26,
			draw = function(px, py, kk, _h, i, dir)
				C.leaf(
					c,
					px + math.sin(a * 7 + i) * 2,
					py,
					4,
					dir + kk * 6,
					if i % 2 == 1 then W.c0 else W.c1,
					1 - kk
				)
			end,
		})
	end,
}

Glade.SlimeCrownStaff = {
	f = function(c, I, t, W)
		local lat = K.sw(0.3, 18)
		local p = hd(I, t, lat)
		K.lamp(c, p, W.c2, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.1, 10, lat), 7, 0, W.c0, W.c0, 0.6, 0)
		K.shed(c, I, t, {
			rate = 24,
			life = 0.4,
			spd = 5,
			grav = 110,
			lat = lat,
			draw = function(px, py, k)
				C.dot(c, px, py, 1.7, W.c0, 1 - k)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.6)
		K.at(c, p[1], p[2], p[3], function()
			C.glow(c, W, W.c0, 14)
			local s = math.sin(t * 25) * 0.15
			K.at(c, 0, 0, 0, function()
				K.orb(c, 0, 0, 5.2, W.c2, W.c0)
			end, 1 + s, 1 - s)
			C.noGlow(c)
			C.dot(c, 1.6, -1.8, 1.3, WHITE, 0.9)
		end)
		crown(c, p[1], p[2] - 7, 1, W.c1)
	end,
	h = function(c, P, a, W, I, k)
		if k == "pass" then
			local f = 1 - a / 0.35
			if f > 0 then
				C.spiky(c, P[1], P[2], 7 * sm(a / 0.06), I.ph, W.c0, 0.85 * f, 6, 0.55)
			end
			K.burst(c, P, a, I.seed + 3, {
				n = 5,
				life = 0.3,
				spd = 36,
				even = true,
				draw = function(px, py, kk)
					C.spark(c, px, py, 2.4 * (1 - kk), 0, W.c1, 1 - kk)
				end,
			})
			return
		end
		local f = 1 - clamp((a - 0.25) / 0.5)
		if f > 0 then
			C.spiky(c, P[1], P[2], 20 * sm(a / 0.1), I.ph, W.c0, 0.75 * f, 9, 0.6)
			C.spiky(c, P[1], P[2], 9 * sm(a / 0.1), I.ph + 0.3, W.c2, 0.8 * f, 7, 0.6)
		end
		if a < 0.6 then
			local kk = a / 0.6
			crown(c, P[1] + kk * 6, P[2] - 6 - kk * 22 + kk * kk * 10, 1 - kk, W.c1, kk * 5)
		end
	end,
}

Glade.WorldrootStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 32, 0.32 * K.fade(I, t))
		for j = 0, 2 do
			K.ribbon(
				c,
				tr(I, t, 0.11, 10, function(J, tt)
					return math.sin(tt * 30 + j * 2.1 + J.ph) * 3.4
				end),
				2.2,
				0.3,
				W.c1,
				W.c1,
				0.95,
				0
			)
		end
		if t >= I.tEnd then
			return
		end
		local pts = tr(I, t, 0.07, 8)
		local sd = I.seed * 31 + math.floor(t * 22)
		local xs, ys = {}, {}
		local n = #pts
		for idx, q in pts do
			local i = idx - 1
			local o = if i > 0 and i < n - 1 then (Kit.rnd(sd, i, 1) - 0.5) * 7 else 0
			xs[idx], ys[idx] = q[1] - math.sin(q[3]) * o, q[2] + math.cos(q[3]) * o
		end
		C.glow(c, W, W.c0, 8)
		K.stroke(c, xs, ys, 1.2, WHITE, 0.95)
		C.noGlow(c)
		K.shade(c, p, 3.6)
		K.at(c, p[1], p[2], p[3], function()
			C.glow(c, W, W.c0, 16)
			K.orb(c, 0, 0, 4.6, WHITE, W.c0)
			C.noGlow(c)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.35, 20, W.c0, 2.4)
		if a < 0.35 and math.floor(a * 30) % 3 ~= 2 then
			C.glowAlways(c, W.c0, 8)
			for i = 0, 4 do
				local an = i / 5 * TAU + I.ph
				local L = 20 * (0.7 + 0.3 * Kit.rnd(I.seed, i, 8))
				K.jag(
					c,
					P[1],
					P[2],
					P[1] + math.cos(an) * L,
					P[2] + math.sin(an) * L,
					I.seed * 7 + i + math.floor(a * 24),
					3.2,
					5,
					1.3,
					WHITE,
					1 - a / 0.35
				)
			end
			C.noGlow(c)
		end
		K.roots(c, P, a, I.seed, W.c1, 0.9, 18)
	end,
}

return table.freeze(Glade)
