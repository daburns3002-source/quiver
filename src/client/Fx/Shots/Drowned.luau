--!strict
--[[
	The Drowned Village's nine shots, cards 13 to 21 of the Projectile
	Shots page, line for line (`Fx/Shots/Kit`). `f` draws the flight, `h`
	a hit.
]]

local Canvas = require(script.Parent.Parent.Cleaves.Canvas)
local Kit = require(script.Parent.Kit)

type Ctx = Canvas.Ctx
type RGB = Canvas.RGB

local C = Canvas
local K = Kit
local hd, tr, sm, clamp, mix = Kit.hd, Kit.tr, Kit.sm, Kit.clamp, Canvas.mix
local PI, TAU, WHITE, S = Kit.PI, Kit.TAU, Kit.WHITE, Kit.S

local Drowned: { [string]: Kit.Drawer } = {}

--[[ The Tollstring's bell, mouth forward: bronze rims, a gold body and a
     highlight sliding across it as it spins. ]]
local function bell(c: Ctx, W: Kit.Look, t: number)
	local ax, ay, bx, by = { 5 }, { -4.6 }, { 5 }, { 4.6 }
	K.qcurve(ax, ay, 5, -4.6, 1, -3.6, -1, -2.6, 4)
	K.qcurve(ax, ay, -1, -2.6, -6, -2.6, -6, 0, 4)
	K.qcurve(bx, by, 5, 4.6, 1, 3.6, -1, 2.6, 4)
	K.qcurve(bx, by, -1, 2.6, -6, 2.6, -6, 0, 4)
	K.band(c, ax, ay, bx, by, function()
		return W.c0, 1
	end)
	local glowBlur = c.glowBlur
	c.glowBlur = 0
	C.polyline(c, ax, ay, 1, W.c1, 1)
	C.polyline(c, bx, by, 1, W.c1, 1)
	local hl = (math.sin(t * 16) + 1) / 2
	local y = -4.6 + 9.2 * (hl * 0.8 + 0.1)
	if math.abs(y) < 3.6 then
		K.seg(c, -4, y * 0.6, 4.5, y, 1.6, W.c2, 0.85)
	end
	K.seg(c, 5, -4.6, 5, 4.6, 1.2, W.c1, 1)
	C.dot(c, 6.2, 0, 1.3, W.c1, 1)
	c.glowBlur = glowBlur
end

Drowned.SlatefinBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local pts = tr(I, t, 0.09, 8)
		if #pts > 1 then
			for _, s in { -1, 1 } do
				local xs, ys = {}, {}
				for idx, q in pts do
					local o = s * (1.5 + (idx - 1) * 0.9)
					xs[idx], ys[idx] = q[1] - math.sin(q[3]) * o, q[2] + math.cos(q[3]) * o
				end
				C.polyline(c, xs, ys, 1, W.c2, 0.55)
			end
		end
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 3)
		K.at(c, p[1], p[2], p[3], function()
			K.arrow(c, 20, W.c1, nil, W.c0, "vane")
			local fk = math.sin(t * 34) * 0.45
			C.tri(c, 3, -3.4, 4.5, 0, 10, 0, W.c0, 1)
			C.tri(c, 4.5, 0, 3, 3.4, 10, 0, W.c0, 1)
			K.seg(c, 9, 0, 4, -2.2, 0.7, W.c1, 0.8)
			K.seg(c, 9, 0, 4, 2.2, 0.7, W.c1, 0.8)
			for _, s in { -1, 1 } do
				K.at(c, -2, s, s * (0.9 + fk), function()
					C.leaf(c, 2.4, 0, 2.4, 0, W.c0, 0.9)
				end)
			end
		end)
	end,
	h = function(c, P, a, W, I, k)
		K.burst(c, P, a, I.seed, {
			n = 9,
			life = 0.45,
			spd = 44,
			cone = 2.6,
			grav = 60,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.6 * (1 - kk * 0.5), W.c2, 1 - kk)
			end,
		})
		for j = 0, 1 do
			local aa = a - j * 0.12
			if aa > 0 and aa < 0.5 then
				local kk = aa / 0.5
				C.arcLine(c, P[1], P[2] + 3, 4 + kk * 12, 0, TAU, 1.2, W.c0, 0.8 * (1 - kk), 0.55)
			end
		end
		if k == "wall" then
			K.stuck(c, P, a, W.c1, W.c0, "vane")
		end
	end,
}

Drowned.EelcrestBow = {
	f = function(c, I, t, W)
		local lat = K.sw(0.55, 26)
		local p = hd(I, t, lat)
		local pts = tr(I, t, 0.07, 14, lat)
		K.ribbon(c, pts, 4.6, 1.2, W.c0, W.c2, 1, 0.95)
		K.line(c, pts, 1, W.c2, 0.9)
		if t >= I.tEnd then
			return
		end
		local sd = I.seed * 13 + math.floor(t * 24)
		for i = 0, 2 do
			local q = pts[math.floor(Kit.rnd(sd, i, 1) * #pts) + 1]
			local an = Kit.rnd(sd, i, 2) * TAU
			K.jag(
				c,
				q[1],
				q[2],
				q[1] + math.cos(an) * 5,
				q[2] + math.sin(an) * 5,
				sd + i,
				1.4,
				3,
				1,
				W.c1,
				0.95
			)
		end
		K.at(c, p[1], p[2], p[3], function()
			C.ellipse(c, 1, 0, 4, 3, 0, W.c0, 1)
			C.dot(c, 2.4, -1.4, 0.9, W.c1, 1)
			C.dot(c, 2.4, 1.4, 0.9, W.c1, 1)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		if a < 0.3 and math.floor(a * 28) % 3 ~= 2 then
			for i = 0, 5 do
				local an = i / 6 * TAU + I.ph
				K.jag(
					c,
					P[1],
					P[2],
					P[1] + math.cos(an) * 13,
					P[2] + math.sin(an) * 13,
					I.seed * 5 + i + math.floor(a * 20),
					2.2,
					4,
					1.3,
					if i % 2 == 1 then W.c1 else WHITE,
					1 - a / 0.3
				)
			end
		end
		K.wave(c, P, a, 0.35, 12, W.c0, 1.8)
	end,
}

Drowned.TollstringBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c2, 30, 0.3 * K.fade(I, t))
		K.drops(c, I, t, 0.05, 0.3, function(q, k)
			C.ring(c, q[1], q[2], 2 + k * 9, W.c0, 0.75 * (1 - k), 1.4 * (1 - k) + 0.3)
		end)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 3.6)
		K.at(c, p[1], p[2], p[3], function()
			C.glow(c, W, W.c0, 14)
			bell(c, W, t)
			C.noGlow(c)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.4, 14, W.c0, 2.6)
		K.wave(c, P, a - 0.15, 0.4, 11, W.c0, 2)
		K.burst(c, P, a, I.seed, {
			n = 6,
			life = 0.35,
			spd = 36,
			even = true,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.5 * (1 - kk), W.c1, 1 - kk)
			end,
		})
		if a < 0.12 then
			C.glowDot(c, P[1], P[2], 10, W.c2, 0.8 * (1 - a / 0.12))
		end
	end,
}

--[[ Where Eventide's soul leaps to: an enemy beside the one it hit, as on
     the card (7.6 studs on and 7 to the side of where it struck). ]]
local SOUL_ON, SOUL_SIDE = 7.6 * S, 7 * S

Drowned.EventideBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local col = Kit.dusk(W, t)
		K.lamp(c, p, col, 32, 0.32 * K.fade(I, t))
		local pts = tr(I, t, 0.14, 14)
		K.ribbon(c, pts, 11, 0, W.c2, W.c1, 0.35, 0)
		K.ribbon(c, pts, 6, 0, W.c1, W.c0, 0.6, 0)
		K.ribbon(c, pts, 2.4, 0, mix(col, WHITE, 0.6), W.c0, 0.95, 0)
		K.shed(c, I, t, {
			rate = 26,
			life = 0.6,
			spd = 3,
			spread = TAU,
			draw = function(px, py, k, h)
				C.cross(c, px, py, (1.6 + h * 1.6) * math.sin(PI * k), 0, WHITE, 0.95)
			end,
		})
		if t < I.tEnd then
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, col, 16)
				local ax, ay = { 9, 4.5, 0, -3.5, -7 }, { 0, -1.5, -3, -1.5, 0 }
				local bx, by = { 9, 4.5, 0, -3.5, -7 }, { 0, 1.5, 3, 1.5, 0 }
				K.band(c, ax, ay, bx, by, function(u)
					return mix(WHITE, col, u), 1
				end)
				C.noGlow(c)
			end)
		end
	end,
	h = function(c, P, a, W, _I, k)
		K.wave(c, P, a, 0.4, 16, W.c0, 2.4)
		K.wave(c, P, a - 0.07, 0.4, 11, W.c2, 2)
		if a < 0.15 then
			C.glowDot(c, P[1], P[2], 10, Kit.dusk(W, a), 0.8 * (1 - a / 0.15))
		end
		if k ~= "body" then
			return
		end
		local life = 0.5
		if a >= life + 0.2 then
			return
		end
		local cs, sn = math.cos(P[3]), math.sin(P[3])
		local tx = P[1] + cs * SOUL_ON - sn * SOUL_SIDE
		local ty = P[2] + sn * SOUL_ON + cs * SOUL_SIDE
		local u = sm(clamp(a / life))
		local cx, cy = (P[1] + tx) / 2, math.min(P[2], ty) - 14
		local al = if a < life then 1 else 1 - (a - life) / 0.2
		for j = 4, 0, -1 do
			local v = clamp(u - j * 0.05)
			local sx = (1 - v) * (1 - v) * P[1] + 2 * v * (1 - v) * cx + v * v * tx
			local sy = (1 - v) * (1 - v) * P[2] + 2 * v * (1 - v) * cy + v * v * ty
			C.glowDot(c, sx, sy, 4.5 - j * 0.6, if j > 0 then W.c1 else WHITE, (1 - j / 5) * al)
		end
		if a > life then
			C.glowDot(c, tx, ty, 10, W.c0, 0.7 * al)
		end
	end,
}

Drowned.ReedStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.shed(c, I, t, {
			rate = 30,
			life = 0.75,
			spd = 5,
			side = 3,
			draw = function(px, py, k, h)
				K.fluff(c, px + math.sin(k * 6 + h * 9) * 2, py, 1 - k, W.c2, h)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 3)
		K.at(c, p[1], p[2], p[3], function()
			K.seg(c, -9, 0, -4, 0, 1.3, W.c0, 1)
			C.ellipse(c, 1, 0, 5, 2.3, 0, W.c1, 1)
			C.arcLine(c, 1, 0, 5, 0, TAU, 0.7, { 70, 44, 24 }, 1, 2.3 / 5)
			C.dot(c, -1, -0.8, 0.7, W.c2, 0.7)
			C.dot(c, 2, 0.6, 0.7, W.c2, 0.7)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.burst(c, P, a, I.seed, {
			n = 12,
			life = 0.95,
			spd = 22,
			even = true,
			rise = 6,
			draw = function(px, py, kk, h)
				K.fluff(c, px + math.sin(a * 6 + h * 9) * 2, py, 1 - kk, W.c2, h)
			end,
		})
		K.wave(c, P, a, 0.45, 20, W.c0, 1.2)
	end,
}

--[[ A stripe across a ball r round, from y0 to y1 (both inside it). ]]
local function stripe(c: Ctx, r: number, y0: number, y1: number, colour: RGB)
	local w0, w1 = math.sqrt(r * r - y0 * y0), math.sqrt(r * r - y1 * y1)
	C.quad(c, -w0, y0, w0, y0, w1, y1, -w1, y1, colour, 1)
end

Drowned.BuoyStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local lift = 0.6 * S * math.sin(t * 8 + I.ph)
		K.drops(c, I, t, 0.07, 0.5, function(q, k)
			C.arcLine(c, q[1], q[2] + 3, 2 + k * 9, 0, TAU, 1, W.c2, 0.55 * (1 - k), 0.55)
		end)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.4, 6 + lift)
		local qx, qy = p[1], p[2] - lift - 2
		C.dot(c, qx, qy, 5, W.c0, 1)
		K.at(c, qx, qy, t * 5, function()
			stripe(c, 5, -3.2, -1.2, W.c1)
			stripe(c, 5, 1.2, 3.2, W.c1)
		end)
		C.ring(c, qx, qy, 5, { 120, 50, 30 }, 0.8, 1)
		C.dot(c, qx - 1.6, qy - 1.8, 1.2, WHITE, 0.8)
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.45, 20, W.c2, 2.2)
		K.burst(c, P, a, I.seed, {
			n = 10,
			life = 0.5,
			spd = 42,
			even = true,
			grav = 50,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.6 * (1 - kk * 0.5), W.c2, 1 - kk)
			end,
		})
		if a < 0.3 then
			local kk = a / 0.3
			C.dot(c, P[1], P[2] - kk * 8, 5 * (1 + math.sin(kk * PI) * 0.4), W.c0, 1 - kk)
		end
	end,
}

Drowned.WellpearlStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		for _, s in { 1, -1 } do
			K.ribbon(
				c,
				tr(I, t, 0.11, 14, function(J, tt)
					return s * math.sin(tt * 24 + J.ph) * 3.6
				end),
				2,
				0.3,
				W.c1,
				W.c1,
				0.95,
				0
			)
		end
		K.shed(c, I, t, {
			rate = 20,
			life = 0.35,
			spd = 8,
			grav = 60,
			draw = function(px, py, k)
				C.dot(c, px, py, 1.2 * (1 - k * 0.5), W.c1, 1 - k)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 3.8)
		C.dot(c, p[1], p[2], 4.8, mix(W.c2, W.c1, 0.5 + 0.5 * math.sin(t * 6)), 1)
		C.glowDot(c, p[1] - 0.6, p[2] - 0.6, 4.4, W.c0, 1)
		C.glowDot(c, p[1] - 1.5, p[2] - 1.5, 2.4, WHITE, 1)
		C.arcLine(c, p[1], p[2], 3.4, t * 5, t * 5 + 1.6, 1, W.c2, 0.8)
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.4, 20, W.c1, 2)
		K.burst(c, P, a, I.seed, {
			n = 10,
			life = 0.45,
			spd = 46,
			even = true,
			grav = 40,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.7 * (1 - kk * 0.4), W.c1, 1 - kk)
			end,
		})
		if a < 0.3 then
			C.spark(c, P[1], P[2], 7 * (1 - a / 0.3), a * 3, WHITE, 1)
		end
	end,
}

Drowned.TollkeeperStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.1, 10), 7, 0, W.c0, W.c1, 0.5, 0)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.4)
		K.at(c, p[1], p[2], 0, function()
			C.glow(c, W, W.c0, 14)
			K.orb(c, 0, 0, 5, W.c2, W.c0)
			C.noGlow(c)
			C.ring(c, 0, 0, 5, W.c1, 1, 1.3)
			local cl = PI + p[3] + math.sin(t * 14) * 0.8
			K.seg(c, 0, 0, math.cos(cl) * 3.6, math.sin(cl) * 3.6, 1.2, W.c1, 1)
			C.dot(c, math.cos(cl) * 3.6, math.sin(cl) * 3.6, 1.2, W.c1, 1)
			-- the turning halo: dashes 2.2 long, 2.6 apart, running round
			local r = 7.6
			local shift = t * 24 / r
			local n = math.floor(TAU * r / 4.8)
			for d = 0, n - 1 do
				local from = d * TAU / n + shift
				C.arcLine(c, 0, 0, r, from, from + 2.2 / r, 1.1, W.c0, 0.85)
			end
		end)
	end,
	h = function(c, P, a, W, I, _k)
		for _, step in { { 0, 20 }, { 0.22, 17 } } do
			local aa = a - step[1]
			K.wave(c, P, aa, 0.4, step[2], W.c0, 2.8)
			if aa >= 0 and aa < 0.12 then
				for i = 0, 7 do
					local an = i / 8 * TAU
					K.seg(
						c,
						P[1] + math.cos(an) * 8,
						P[2] + math.sin(an) * 8,
						P[1] + math.cos(an) * 12,
						P[2] + math.sin(an) * 12,
						1.3,
						W.c2,
						1 - aa / 0.12
					)
				end
			end
		end
		K.burst(c, P, a, I.seed, {
			n = 6,
			life = 0.35,
			spd = 34,
			even = true,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.4 * (1 - kk), W.c1, 1 - kk)
			end,
		})
	end,
}

--[[ A spiral's arms from the centre out to r, turned by `turn`. ]]
local function arms(
	c: Ctx,
	n: number,
	r: number,
	twist: number,
	turn: number,
	steps: number,
	w: number,
	colour: RGB,
	alpha: number
)
	for j = 0, n - 1 do
		local xs, ys = { 0 }, { 0 }
		for s = 1, steps do
			local u = s / steps
			local an = j * TAU / n + u * twist + turn
			table.insert(xs, math.cos(an) * u * r)
			table.insert(ys, math.sin(an) * u * r)
		end
		C.polyline(c, xs, ys, w, colour, alpha)
	end
end

Drowned.MaelstromStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local col = Kit.sea(t)
		K.lamp(c, p, col, 32, 0.32 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.12, 12), 10, 0, col, { 20, 30, 90 }, 0.5, 0)
		K.shed(c, I, t, {
			rate = 30,
			life = 0.4,
			spd = 16,
			spread = 3,
			draw = function(px, py, k)
				K.speck(c, px, py, 1.3 * (1 - k), W.c2, 1 - k)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 5)
		K.at(c, p[1], p[2], 0, function()
			C.glow(c, W, col, 16)
			K.orb(c, 0, 0, 6.2, mix(col, WHITE, 0.25), { 20, 30, 110 })
			C.noGlow(c)
			arms(c, 3, 6.2, 2.6, -t * 18, 6, 1.3, W.c2, 0.95)
			local sd = math.floor(t * 20)
			for i = 0, 1 do
				local an = Kit.rnd(I.seed, sd, i) * TAU
				C.spark(c, math.cos(an) * 7, math.sin(an) * 7, 2.4, an, W.c1, 1)
			end
		end)
	end,
	h = function(c, P, a, W, I, _k)
		local R = 20 * sm(a / 0.15) * (1 - sm((a - 0.45) / 0.4))
		if R > 0.5 and a < 0.85 then
			local col = Kit.sea(a)
			K.at(c, P[1], P[2], 0, function()
				K.orb(c, 0, 0, R, { 20, 30, 110 }, col, 0.55)
				arms(c, 4, R, 3, -a * 14, 8, 1.4, W.c2, 0.9)
			end)
		end
		K.burst(c, P, a, I.seed, {
			n = 6,
			life = 0.35,
			spd = 40,
			even = true,
			draw = function(px, py, kk, h)
				C.spark(c, px, py, 2.6 * (1 - kk), h, W.c1, 1)
			end,
		})
	end,
}

return table.freeze(Drowned)
