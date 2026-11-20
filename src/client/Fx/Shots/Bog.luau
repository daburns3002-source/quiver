--!strict
--[[
	Bogheart's ten shots, cards 22 to 31 of the Projectile Shots page, line
	for line (`Fx/Shots/Kit`). `f` draws the flight, `h` a hit.
]]

local Canvas = require(script.Parent.Parent.Cleaves.Canvas)
local Kit = require(script.Parent.Kit)

type Ctx = Canvas.Ctx
type RGB = Canvas.RGB

local C = Canvas
local K = Kit
local hd, tr, sm, clamp, mix = Kit.hd, Kit.tr, Kit.sm, Kit.clamp, Canvas.mix
local PI, TAU, WHITE = Kit.PI, Kit.TAU, Kit.WHITE

local Bog: { [string]: Kit.Drawer } = {}

--[[ The page's blob's outline (nine sides, squashed a fifth across). ]]
local function blobLine(
	c: Ctx,
	p: number,
	q: number,
	r: number,
	seed: number,
	w: number,
	colour: RGB,
	alpha: number
)
	local xs, ys = {}, {}
	for i = 0, 8 do
		local an = i / 9 * TAU
		local rr = r * (0.7 + 0.5 * Kit.rnd(seed, i, 7))
		xs[i + 1], ys[i + 1] = p + math.cos(an) * rr, q + math.sin(an) * rr * 0.8
	end
	C.outline(c, xs, ys, w, colour, alpha)
end

Bog.PeatwoodBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.ribbon(c, tr(I, t, 0.05, 6), 3.4, 0, W.c0, W.c1, 0.4, 0)
		K.shed(c, I, t, {
			rate = 26,
			life = 0.4,
			spd = 6,
			grav = 90,
			draw = function(px, py, k, h)
				C.chip(c, px, py, 1.7, h * 7, W.c1, 1 - k)
			end,
		})
		if t < I.tEnd then
			K.shade(c, p, 3)
			K.at(c, p[1], p[2], p[3], function()
				K.arrow(c, 20, W.c1, W.c0, W.c2, "vane", 2.2)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		local f = 1 - clamp((a - 0.2) / 0.7)
		if f > 0 then
			C.blob(c, P[1], P[2] + 2, 6, I.seed, W.c1, 0.4 * f)
		end
		K.puff(c, P, a, I.seed, mix(W.c0, W.c1, 0.4), 6, 0.5)
		K.burst(c, P, a, I.seed + 1, {
			n = 6,
			life = 0.35,
			spd = 34,
			cone = 2,
			grav = 70,
			draw = function(px, py, kk, h)
				C.chip(c, px, py, 2, h * 9, W.c1, 1 - kk)
			end,
		})
		if k == "wall" then
			K.stuck(c, P, a, W.c1, W.c2, "vane")
		end
	end,
}

Bog.SporestringBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.drops(c, I, t, 0.035, 0.6, function(q, k)
			C.dot(c, q[1], q[2], 1.4 + k * 4.5, W.c0, 0.55 * (1 - k))
		end)
		if t < I.tEnd then
			K.shade(c, p, 2.6)
			K.at(c, p[1], p[2], p[3], function()
				K.arrow(c, 17, W.c0, W.c1, nil, nil, 1.5)
				C.dot(c, -7.5, -1.6, 1.6, W.c1, 1)
				C.dot(c, -7.5, 1.6, 1.6, W.c1, 1)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		K.burst(c, P, a, I.seed, {
			n = 8,
			life = 0.65,
			spd = 26,
			even = true,
			draw = function(px, py, kk)
				C.dot(c, px, py, 2 + kk * 5, mix(W.c0, W.c1, kk), 0.6 * (1 - kk))
			end,
		})
		if a < 0.15 then
			C.glowDot(c, P[1], P[2], 9, W.c0, 0.6 * (1 - a / 0.15))
		end
		if k == "wall" then
			K.stuck(c, P, a, W.c0, W.c1, nil)
		end
	end,
}

Bog.GlowcapLongbow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.drops(c, I, t, 0.02, 0.35, function(q, k)
			C.glowDot(c, q[1], q[2], 3, W.c0, 0.35 * (1 - k))
			K.speck(c, q[1], q[2], 1.1, W.c2, 1 - k)
		end)
		if t < I.tEnd then
			K.shade(c, p, 2.6)
			K.at(c, p[1], p[2], p[3], function()
				K.seg(c, -13, 0, 8, 0, 1.6, W.c0, 1)
				K.seg(c, -13, 0, 8, 0, 0.6, WHITE, 0.9)
				K.arcFill(c, 9.5, 0, 3.2, -PI / 2, PI / 2, W.c1, 1)
				C.dot(c, 10.5, -1.2, 0.7, W.c0, 1)
				C.dot(c, 11, 1, 0.7, W.c0, 1)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		if a < 0.15 then
			C.glowDot(c, P[1], P[2], 12, W.c0, 0.55 * (1 - a / 0.15))
		end
		for i = 0, 4 do
			local an = Kit.rnd(I.seed, i, 61) * TAU
			local d = 4 + Kit.rnd(I.seed, i, 62) * 8
			local s = sm((a - i * 0.04) / 0.12) * (1 - sm((a - 0.5) / 0.3))
			if s <= 0 then
				continue
			end
			local px, py = P[1] + math.cos(an) * d, P[2] + math.sin(an) * d
			C.glowDot(c, px, py, 5 * s, W.c0, 0.5)
			C.dot(c, px, py, 2.8 * s, W.c1, 1)
			C.dot(c, px - 0.8 * s, py - 0.6 * s, 0.7 * s, W.c0, 1)
		end
		if k == "wall" then
			K.stuck(c, P, a, W.c0, W.c1, nil)
		end
	end,
}

Bog.GulpstringBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local pts = tr(I, t, 0.16, 16)
		K.lamp(c, p, W.c1, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, pts, 3.8, 5.6, W.c0, W.c2, 1, 0.95)
		K.line(c, pts, 0.8, W.c2, 0.6)
		K.shed(c, I, t, {
			rate = 18,
			life = 0.35,
			spd = 4,
			grav = 120,
			draw = function(px, py, k)
				C.dot(c, px, py, 1.5, W.c1, 1 - k)
			end,
		})
		if t < I.tEnd then
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, W.c1, 14)
				K.orb(c, 0, 0, 3.8, { 255, 245, 190 }, W.c1)
				C.noGlow(c)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		local big = k ~= "pass"
		local f = 1 - clamp((a - 0.2) / 0.5)
		if f > 0 then
			C.spiky(
				c,
				P[1],
				P[2],
				(if big then 10 else 6.5) * sm(a / 0.07),
				I.ph,
				W.c1,
				0.9 * f,
				if big then 8 else 6,
				0.55
			)
		end
		K.burst(c, P, a, I.seed + (if big then 0 else 5), {
			n = if big then 8 else 5,
			life = 0.4,
			spd = 36,
			even = true,
			grav = 70,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.6 * (1 - kk * 0.5), W.c1, 1 - kk)
			end,
		})
	end,
}

Bog.LumenveilBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 32, 0.32 * K.fade(I, t))
		c.light = true
		for _, s in { 1, -1 } do
			K.ribbon(
				c,
				tr(I, t, 0.12, 14, function(J, tt)
					return s * math.sin(tt * 20 + J.ph) * 4.2
				end),
				3.2,
				0,
				W.c1,
				W.c0,
				0.75,
				0
			)
		end
		K.ribbon(c, tr(I, t, 0.06, 6), 1.6, 0, WHITE, W.c0, 0.9, 0)
		c.light = false
		K.shed(c, I, t, {
			rate = 28,
			life = 0.5,
			spd = 6,
			rise = 12,
			draw = function(px, py, k, h)
				C.spark(c, px, py, 2.6 * math.sin(PI * k), h, W.c1, 1)
			end,
		})
		if t < I.tEnd then
			K.at(c, p[1], p[2], p[3], function()
				local xs, ys = { 9, 1, -8, 1 }, { 0, -3.2, 0, 3.2 }
				C.glow(c, W, W.c0, 16)
				C.fill(c, xs, ys, W.c0, 1)
				C.noGlow(c)
				C.tri(c, 9, 0, 1, -3.2, 1, 0, W.c1, 1)
				C.outline(c, xs, ys, 0.8, WHITE, 0.95)
			end)
		end
	end,
	h = function(c, P, a, W, I, _k)
		if a < 0.12 then
			C.glowDot(c, P[1], P[2], 13, W.c0, 0.8 * (1 - a / 0.12))
		end
		K.wave(c, P, a, 0.35, 14, W.c1, 2)
		K.burst(c, P, a, I.seed, {
			n = 8,
			life = 0.45,
			spd = 52,
			even = true,
			draw = function(px, py, kk, _h, i, dir)
				C.shard(c, px, py, 3.6, dir + kk * 4, if i % 2 == 1 then W.c0 else W.c1, 1 - kk)
			end,
		})
		K.burst(c, P, a, I.seed + 9, {
			n = 10,
			life = 0.8,
			spd = 10,
			rise = 28,
			draw = function(px, py, kk)
				C.glowDot(c, px, py, 3, W.c1, 1 - kk)
			end,
		})
	end,
}

Bog.LichenStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.shed(c, I, t, {
			rate = 22,
			life = 0.4,
			spd = 12,
			grav = 40,
			draw = function(px, py, k, h)
				C.chip(c, px, py, 1.8, h * 8, W.c0, 1 - k)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4)
		K.at(c, p[1], p[2], t * 7, function()
			C.blob(c, 0, 0, 4.6, I.seed, W.c0, 1)
			blobLine(c, 0, 0, 4.6, I.seed, 1, W.c1, 1)
			C.dot(c, -1.5, -1, 1.1, W.c2, 1)
			C.dot(c, 1.6, 1, 0.9, W.c2, 1)
			C.dot(c, 0.5, -2, 0.8, W.c1, 1)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.burst(c, P, a, I.seed, {
			n = 10,
			life = 0.32,
			spd = 56,
			even = true,
			draw = function(px, py, kk, h)
				C.chip(c, px, py, 2.2, h * 8, W.c0, 1 - kk)
			end,
		})
		local f = 1 - clamp((a - 0.3) / 0.6)
		if a > 0.12 and f > 0 then
			for i = 0, 7 do
				local an = i / 8 * TAU + Kit.rnd(I.seed, i, 71)
				local d = 8 + Kit.rnd(I.seed, i, 72) * 11
				C.blob(
					c,
					P[1] + math.cos(an) * d,
					P[2] + math.sin(an) * d,
					1.8 + Kit.rnd(I.seed, i, 74) * 1.4,
					I.seed + i,
					mix(W.c0, W.c1, Kit.rnd(I.seed, i, 73)),
					0.75 * f
				)
			end
		end
	end,
}

Bog.PuffballStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.drops(c, I, t, 0.05, 0.6, function(q, k)
			C.dot(c, q[1], q[2], 2.5 + k * 7, W.c1, 0.35 * (1 - k))
		end)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 6)
		local s = 1 + math.sin(t * 16) * 0.12
		K.at(c, p[1], p[2], p[3], function()
			K.orb(c, 0, 0, 6.5, W.c1, W.c0)
		end, s, 1 / s)
		for i = 0, 3 do
			local an = i * 1.7 + I.ph
			K.speck(c, p[1] + math.cos(an) * 3.4, p[2] + math.sin(an) * 3.4, 0.8, W.c2, 0.8)
		end
	end,
	h = function(c, P, a, W, I, _k)
		local f = 1 - a / 0.9
		if f > 0 then
			K.disc(c, P[1], P[2], 20 * sm(a / 0.2), W.c1, 0.32 * f)
		end
		K.burst(c, P, a, I.seed, {
			n = 10,
			life = 0.9,
			spd = 28,
			even = true,
			draw = function(px, py, kk)
				K.disc(c, px, py, 3.5 + kk * 7, mix(W.c0, W.c1, kk), 0.5 * (1 - kk))
			end,
		})
	end,
}

Bog.VentstoneStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.shed(c, I, t, {
			rate = 30,
			life = 0.55,
			spd = 8,
			rise = 16,
			draw = function(px, py, k)
				C.dot(c, px, py, 1.5 + k * 5, mix(WHITE, W.c2, 0.2), 0.42 * (1 - k))
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.4)
		K.at(c, p[1], p[2], t * 3, function()
			C.blob(c, 0, 0, 4.8, I.seed + 3, W.c1, 1)
			local al = 0.6 + 0.4 * math.sin(t * 14)
			C.polyline(c, { -3, 0, 2.6 }, { -1, 0.6, -1.8 }, 1.1, W.c2, al)
			K.seg(c, 0, 0.6, 0.6, 3, 1.1, W.c2, al)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.burst(c, P, a, I.seed, {
			n = 10,
			life = 0.6,
			spd = 40,
			even = true,
			draw = function(px, py, kk)
				C.dot(c, px, py, 2.5 + kk * 6, mix(WHITE, W.c2, 0.25), 0.5 * (1 - kk))
			end,
		})
		local f = 1 - a / 0.7
		if f > 0 then
			K.disc(c, P[1], P[2] - a * 10, 4 + a * 12, WHITE, 0.55 * f)
		end
		K.wave(c, P, a, 0.4, 20, W.c2, 1.6)
	end,
}

Bog.GrandmothersStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.1, 10), 7, 0, W.c0, W.c2, 0.35, 0)
		K.shed(c, I, t, {
			rate = 20,
			life = 0.5,
			spd = 6,
			rise = 8,
			draw = function(px, py, k)
				C.ring(c, px, py, 1.3 * (1 - k * 0.3), W.c1, 0.8 * (1 - k), 0.7)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.4)
		K.at(c, p[1], p[2], 0, function()
			if W.glow then
				-- the bubble's glow (the page's shadowBlur on its fill)
				local light = c.light
				c.light = true
				C.glowDot(c, 0, 0, 5.2 + 14 * 0.6, W.c0, 0.4 * 0.45)
				c.light = light
			end
			C.dot(c, 0, 0, 5.2, W.c0, 0.4)
			C.ring(c, 0, 0, 5.2, W.c1, 0.95, 1.3)
			C.arcLine(c, 0, 0, 3.4, PI * 1.1, PI * 1.55, 1.1, WHITE, 0.9)
			for j = 0, 1 do
				local an = t * 12 + j * PI
				C.ring(c, math.cos(an) * 8, math.sin(an) * 8, 1.8, W.c1, 0.9, 0.9)
			end
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.35, 20, W.c0, 2.4)
		K.burst(c, P, a, I.seed, {
			n = 8,
			life = 0.35,
			spd = 40,
			even = true,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.5 * (1 - kk), W.c1, 1 - kk)
			end,
		})
		local e = a - 0.24
		if e >= 0 then
			K.wave(c, P, e, 0.35, 14, W.c0, 2)
			if e < 0.1 then
				C.glowDot(c, P[1], P[2], 8, W.c0, 0.7 * (1 - e / 0.1))
			end
			K.burst(c, P, e, I.seed + 4, {
				n = 6,
				life = 0.3,
				spd = 30,
				even = true,
				draw = function(px, py, kk)
					C.ring(c, px, py, 1.4, W.c1, 1 - kk, 0.7)
				end,
			})
		end
	end,
}

Bog.MyceliadStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 32, 0.32 * K.fade(I, t))
		for j = 0, 4 do
			local side = if j % 2 == 1 then 1 else -1
			K.ribbon(
				c,
				tr(I, t, 0.1 + j * 0.015, 9, function(J, tt)
					return math.sin(tt * (16 + j * 3) + j * 1.3 + J.ph) * (1.2 + j * 0.9) * side
				end),
				1.5,
				0.2,
				W.c1,
				W.c1,
				0.85,
				0
			)
		end
		K.shed(c, I, t, {
			rate = 18,
			life = 0.45,
			spd = 6,
			draw = function(px, py, k, h)
				C.spark(c, px, py, 2.4 * math.sin(PI * k), h, W.c2, 1)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.at(c, p[1], p[2], 0, function()
			C.glow(c, W, W.c0, 16)
			K.orb(c, 0, 0, 4.6, WHITE, W.c0)
			C.noGlow(c)
			for i = 0, 5 do
				local an = i / 6 * TAU + t * 3
				K.seg(
					c,
					math.cos(an) * 4.6,
					math.sin(an) * 4.6,
					math.cos(an + 0.3) * 7,
					math.sin(an + 0.3) * 7,
					0.8,
					W.c1,
					0.8
				)
			end
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.roots(c, P, a, I.seed, W.c1, 0.85, 20, 8, 0.45)
		if a < 0.12 then
			C.glowDot(c, P[1], P[2], 12, W.c0, 0.8 * (1 - a / 0.12))
		end
		local e = a - 0.75
		if e >= 0 and e < 0.12 then
			C.glowDot(c, P[1], P[2], 10, W.c0, 0.8 * (1 - e / 0.12))
		end
		C.glowDot(c, P[1], P[2], 5, W.c0, 0.6 * (1 - clamp(a / 0.85)))
	end,
}

return table.freeze(Bog)
