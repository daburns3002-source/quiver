--!strict
--[[
	The themed sets' sixteen shots, cards 34 to 49 of the Projectile Shots
	page, line for line (`Fx/Shots/Kit`): a bow and a staff for each of
	Neon Circuit, Starwish, Tumbleweed, Splash Day, Coin-Op, Voidglass,
	Lantern Bloom and Cinderforge. `f` draws the flight, `h` a hit.
]]

local Canvas = require(script.Parent.Parent.Cleaves.Canvas)
local Kit = require(script.Parent.Kit)

type Ctx = Canvas.Ctx
type RGB = Canvas.RGB

local C = Canvas
local K = Kit
local hd, tr, sm, clamp, mix = Kit.hd, Kit.tr, Kit.sm, Kit.clamp, Canvas.mix
local PI, TAU, WHITE, S, G = Kit.PI, Kit.TAU, Kit.WHITE, Kit.S, Kit.G

local Sets: { [string]: Kit.Drawer } = {}

local ROPE: RGB = { 176, 124, 60 }

--[[ A ring of eight arcs in two colours (a swim ring), r round, w wide. ]]
local function swimRing(c: Ctx, r: number, w: number, a: RGB, b: RGB, alpha: number)
	for j = 0, 7 do
		C.arcLine(
			c,
			0,
			0,
			r,
			j / 8 * TAU,
			(j + 1) / 8 * TAU + 0.02,
			w,
			if j % 2 == 1 then b else a,
			alpha
		)
	end
end

--[[ The Cinderstring's tail: white-hot behind the head, cooling to dark
     red, thinning as it goes. ]]
local function heatTail(c: Ctx, pts: { Kit.P })
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
	local ax, ay, bx, by, cols, alphas = {}, {}, {}, {}, {}, {}
	for i = 1, n do
		local p, q, r = pts[i], pts[math.max(1, i - 1)], pts[math.min(n, i + 1)]
		local dx, dy = q[1] - r[1], q[2] - r[2]
		local a = if math.sqrt(dx * dx + dy * dy) > 1e-4 then math.atan2(dy, dx) else p[3]
		local u = (i - 1) / (n - 1)
		local w = (4.4 * (1 - u) + 0.4) / 2
		local nx, ny = -math.sin(a) * w, math.cos(a) * w
		ax[i], ay[i], bx[i], by[i] = p[1] + nx, p[2] + ny, p[1] - nx, p[2] - ny
		cols[i] = Kit.heat(u * 0.5)
		alphas[i] = 1 - u * 0.7
	end
	Canvas.push(c, ax, ay, bx, by, cols, alphas)
end

---------------------------------------------------------------- Neon Circuit

Sets.LivewireBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local pts = tr(I, t, 0.1, 10)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		if #pts > 1 and not Kit.lite then
			-- the circuit trace: steps of three pixels either side, square corners
			local xs, ys = {}, {}
			local last = 0
			for idx, q in pts do
				local i = idx - 1
				local o = if i == 0 then 0 elseif (i // 2) % 2 == 1 then 3 else -3
				local nx, ny = -math.sin(q[3]), math.cos(q[3])
				if i > 0 then
					table.insert(xs, q[1] + nx * last)
					table.insert(ys, q[2] + ny * last)
				end
				table.insert(xs, q[1] + nx * o)
				table.insert(ys, q[2] + ny * o)
				last = o
			end
			C.glow(c, W, W.c0, 8)
			K.stroke(c, xs, ys, 1.6, W.c0, 0.95)
			C.noGlow(c)
			local m = #xs
			for j = 0, 2 do
				local u = (t * 5 + j / 3) % 1
				local k = math.min(m - 1, math.floor((1 - u) * m)) + 1
				C.glowDot(c, xs[k], ys[k], 3.2, W.c1, 1)
				K.speck(c, xs[k], ys[k], 1, WHITE, 1)
			end
		end
		if t < I.tEnd then
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, W.c0, 14)
				K.halo(c, 0, 0, 5)
				C.noGlow(c)
				K.rect(c, -5, -1.8, 10, 3.6, W.c0, 1)
				K.rect(c, -3, -0.8, 7, 1.6, W.c2, 1)
			end)
		end
	end,
	h = function(c, P, a, W, _I, _k)
		if a >= 0.45 then
			return
		end
		local kk = a / 0.45
		local st = math.floor(kk * 4) * 4.5 + 3
		for i = 0, 7 do
			local an = i / 8 * TAU
			K.rect(
				c,
				P[1] + math.cos(an) * st - 1.3,
				P[2] + math.sin(an) * st - 1.3,
				2.6,
				2.6,
				if i % 2 == 1 then W.c1 else W.c0,
				1 - kk
			)
		end
		local sq = 6 + kk * 16
		K.strokeRect(c, P[1] - sq / 2, P[2] - sq / 2, sq, sq, 1.3, W.c0, 1 - kk)
	end,
}

Sets.MainframeStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.drops(c, I, t, 0.03, 0.35, function(q, k, i)
			if k > 0.4 and math.floor(k * 7) % 2 == 1 then
				return
			end
			local o = (Kit.rnd(I.seed, i, 81) - 0.5) * 7
			K.rect(
				c,
				q[1] - math.sin(q[3]) * o - 1.1,
				q[2] + math.cos(q[3]) * o - 1.1,
				2.2,
				2.2,
				W.c1,
				1 - k * 0.5
			)
		end)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.4)
		K.at(c, p[1], p[2], t * 10, function()
			C.glow(c, W, W.c0, 14)
			K.halo(c, 0, 0, 4.2)
			C.noGlow(c)
			K.rect(c, -4.2, -4.2, 8.4, 8.4, W.c0, 1)
			K.strokeRect(c, -2.4, -2.4, 4.8, 4.8, 1, W.c2, 1)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.burst(c, P, a, I.seed, {
			n = 9,
			life = 0.45,
			spd = 46,
			even = true,
			draw = function(px, py, kk, _h, i)
				C.chip(
					c,
					px,
					py,
					3 * (1 - kk * 0.5),
					kk * 6,
					if i % 2 == 1 then W.c1 else W.c0,
					1 - kk
				)
			end,
		})
		if a < 0.45 then
			local kk = a / 0.45
			local s = 8 + kk * 32
			K.strokeRect(c, P[1] - s / 2, P[2] - s / 2, s, s, 1.5, W.c0, 1 - kk)
			local y = -s / 2
			while y < s / 2 do
				K.rect(c, P[1] - s / 2, P[2] + y, s, 1, W.c1, 0.25 * (1 - kk))
				y += 3
			end
		end
	end,
}

---------------------------------------------------------------- Starwish

Sets.WishbrightBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.1, 12), 6, 0, W.c0, W.c1, 0.8, 0)
		K.shed(c, I, t, {
			rate = 34,
			life = 0.5,
			spd = 8,
			draw = function(px, py, k, h)
				K.twinkle(c, px, py, 2.8 * math.sin(PI * k), h, if h < 0.5 then W.c1 else W.c0, 1)
			end,
		})
		if t < I.tEnd then
			K.shade(c, p, 4)
			K.at(c, p[1], p[2], 0, function()
				C.glow(c, W, W.c0, 14)
				K.halo(c, 0, 0, 5.8)
				C.noGlow(c)
				C.star5(c, 0, 0, 5.8, t * 12, W.c0, 1)
				C.dot(c, 0, 0, 1.5, W.c2, 1)
			end)
		end
	end,
	h = function(c, P, a, W, I, _k)
		if a < 0.18 then
			C.glowDot(c, P[1], P[2], 13, W.c0, 0.75 * (1 - a / 0.18))
		end
		K.burst(c, P, a, I.seed, {
			n = 7,
			life = 0.5,
			spd = 48,
			even = true,
			draw = function(px, py, kk, _h, i)
				C.star5(
					c,
					px,
					py,
					3.2 * (1 - kk * 0.5),
					kk * 6,
					if i % 2 == 1 then W.c1 else W.c0,
					1 - kk
				)
			end,
		})
	end,
}

Sets.DreamdropStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.1, 10), 7, 0, W.c0, W.c2, 0.5, 0)
		K.shed(c, I, t, {
			rate = 22,
			life = 0.6,
			spd = 4,
			draw = function(px, py, k, h)
				C.dot(c, px, py, 2 + k * 4, if h < 0.5 then WHITE else W.c2, 0.5 * (1 - k))
			end,
		})
		if t < I.tEnd then
			K.shade(c, p, 4)
			K.at(c, p[1], p[2], p[3], function()
				-- the drop: a tail at -9, swelling into a round head at the front
				local ax, ay, bx, by = { -9 }, { 0 }, { -9 }, { 0 }
				K.bcurve(ax, ay, -9, 0, -3, -1.5, 2, -5.2, 4.6, -2.6, 8)
				K.bcurve(bx, by, -9, 0, -3, 1.5, 2, 5.2, 4.6, 2.6, 8)
				for i = 1, 3 do
					local an = -0.75 + 0.75 * i / 3
					table.insert(ax, 1.8 + math.cos(an) * 3.8)
					table.insert(ay, math.sin(an) * 3.8)
					table.insert(bx, 1.8 + math.cos(-an) * 3.8)
					table.insert(by, math.sin(-an) * 3.8)
				end
				C.glow(c, W, W.c0, 14)
				K.band(c, ax, ay, bx, by, function(u)
					return mix(W.c0, W.c2, u), 1
				end)
				C.noGlow(c)
				C.star5(c, 1.6, 0, 2.4, -PI / 2 - p[3], W.c1, 1)
			end)
		end
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.45, 20, W.c0, 2)
		K.burst(c, P, a, I.seed, {
			n = 8,
			life = 0.6,
			spd = 30,
			even = true,
			draw = function(px, py, kk)
				C.dot(c, px, py, 3 + kk * 4, W.c2, 0.55 * (1 - kk))
			end,
		})
		K.burst(c, P, a, I.seed + 6, {
			n = 5,
			life = 0.7,
			spd = 14,
			rise = 20,
			draw = function(px, py, kk)
				K.twinkle(c, px, py, 2.2 * (1 - kk * 0.5), 0, W.c1, 1 - kk)
			end,
		})
	end,
}

---------------------------------------------------------------- Tumbleweed

Sets.SaddlehornBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local pts = tr(I, t, 0.12, 18)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		if #pts > 1 and not Kit.lite then
			-- the rope, looping round the line it flew
			local xs, ys = {}, {}
			for idx, q in pts do
				local i = idx - 1
				local ph = i * 1.2 - t * 30
				local r = if i > 0 then 3.4 else 0
				local nx, ny = -math.sin(q[3]), math.cos(q[3])
				xs[idx] = q[1] + math.cos(q[3]) * math.cos(ph) * r + nx * math.sin(ph) * r
				ys[idx] = q[2] + math.sin(q[3]) * math.cos(ph) * r + ny * math.sin(ph) * r
			end
			C.polyline(c, xs, ys, 1.5, W.c1, 0.95)
			for i = 1, #xs - 1, 3 do
				K.seg(c, xs[i], ys[i], xs[i + 1], ys[i + 1], 0.6, { 140, 96, 40 }, 0.7)
			end
		end
		K.shed(c, I, t, {
			rate = 16,
			life = 0.45,
			spd = 6,
			draw = function(px, py, k)
				C.dot(c, px, py, 1.4 + k * 2.5, W.c2, 0.45 * (1 - k))
			end,
		})
		if t < I.tEnd then
			K.shade(c, p, 3)
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, W.c0, 12)
				K.arrow(c, 20, ROPE, W.c0, W.c0, "vane", 2)
				C.noGlow(c)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		K.puff(c, P, a, I.seed, W.c2, 7, 0.55)
		if a < 0.35 then
			local kk = a / 0.35
			C.ring(c, P[1], P[2], 4 + kk * 8, W.c1, 1 - kk, 1.5)
		end
		K.burst(c, P, a, I.seed + 2, {
			n = 5,
			life = 0.3,
			spd = 34,
			even = true,
			draw = function(px, py, kk, h)
				K.twinkle(c, px, py, 2.4 * (1 - kk), h, W.c0, 1)
			end,
		})
		if k == "wall" then
			K.stuck(c, P, a, ROPE, W.c0, "vane")
		end
	end,
}

Sets.WagonwheelStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.drops(c, I, t, 0.05, 0.5, function(q, k)
			C.dot(c, q[1], q[2] + 2, 2 + k * 5, W.c2, 0.32 * (1 - k))
		end)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 5)
		K.at(c, p[1], p[2], t * 14, function()
			C.glow(c, W, W.c0, 12)
			K.oval(c, 0, 0, 6, 6, 0, 0, TAU, 2.2, W.c1, 1)
			C.noGlow(c)
			for j = 0, 5 do
				local an = j / 6 * TAU
				K.seg(c, 0, 0, math.cos(an) * 5.4, math.sin(an) * 5.4, 1.1, W.c1, 1)
			end
			for j = 0, 5 do
				local an = (j + 0.5) / 6 * TAU
				K.speck(c, math.cos(an) * 6, math.sin(an) * 6, 0.8, W.c2, 1)
			end
			C.dot(c, 0, 0, 2.2, W.c0, 1)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.puff(c, P, a, I.seed, W.c2, 9, 0.7, 30)
		K.wave(c, P, a, 0.4, 20, W.c0, 2.2)
		K.burst(c, P, a, I.seed + 3, {
			n = 6,
			life = 0.45,
			spd = 40,
			even = true,
			draw = function(px, py, kk, _h, _i, dir)
				local an = dir + kk * 8
				K.seg(
					c,
					px - math.cos(an) * 2.6,
					py - math.sin(an) * 2.6,
					px + math.cos(an) * 2.6,
					py + math.sin(an) * 2.6,
					1.2,
					W.c1,
					1 - kk
				)
			end,
		})
	end,
}

---------------------------------------------------------------- Splash Day

Sets.NoodleBow = {
	f = function(c, I, t, W)
		local lat = K.sw(0.15, 14)
		local p = hd(I, t, lat)
		local pts = tr(I, t, 0.12, 14, lat)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, pts, 6.4, 2, W.c0, W.c0, 0.95, 0.15)
		K.ribbon(c, pts, 2.4, 0, W.c1, W.c1, 0.95, 0)
		K.shed(c, I, t, {
			rate = 36,
			life = 0.4,
			spd = 14,
			grav = 90,
			lat = lat,
			draw = function(px, py, k)
				K.speck(c, px, py, 1.4 * (1 - k * 0.4), mix(W.c0, WHITE, 0.4), 1 - k)
			end,
		})
		if t < I.tEnd then
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, W.c0, 12)
				K.halo(c, 1, 0, 4.4)
				C.noGlow(c)
				C.ellipse(c, 1, 0, 4.4, 3.4, 0, mix(W.c0, WHITE, 0.6), 1)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		if k == "pass" then
			for _, s in { -1, 1 } do
				K.burst(c, P, a, I.seed + (if s > 0 then 1 else 2), {
					n = 6,
					life = 0.4,
					spd = 40,
					cone = 1,
					base = P[3] + s * PI / 2,
					grav = 60,
					draw = function(px, py, kk)
						C.dot(c, px, py, 1.5 * (1 - kk * 0.4), W.c0, 1 - kk)
					end,
				})
			end
			return
		end
		local f = 1 - clamp((a - 0.2) / 0.7)
		if f > 0 then
			C.ellipse(
				c,
				P[1] - 4,
				P[2] + 2,
				8 * sm(a / 0.15) + 0.1,
				5 * sm(a / 0.15) + 0.1,
				0,
				W.c0,
				0.4 * f
			)
		end
		K.burst(c, P, a, I.seed, {
			n = 14,
			life = 0.45,
			spd = 48,
			cone = 2.8,
			grav = 60,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.7 * (1 - kk * 0.4), if kk < 0.3 then W.c1 else W.c0, 1 - kk)
			end,
		})
	end,
}

Sets.SplashringStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c2, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.08, 8), 6, 0, W.c2, W.c2, 0.35, 0)
		K.shed(c, I, t, {
			rate = 24,
			life = 0.35,
			spd = 8,
			grav = 70,
			draw = function(px, py, k)
				K.speck(c, px, py, 1.3, W.c2, 1 - k)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 5)
		K.at(c, p[1], p[2], t * 8, function()
			C.glow(c, W, W.c0, 12)
			K.halo(c, 0, 0, 6.3)
			C.noGlow(c)
			swimRing(c, 4.6, 3.4, W.c0, W.c1, 1)
			C.arcLine(c, 0, 0, 5.6, -2.4, -1.4, 0.8, WHITE, 0.7)
		end)
	end,
	h = function(c, P, a, W, I, k)
		if k == "pass" then
			K.wave(c, P, a, 0.3, 9, W.c2, 1.4)
			K.burst(c, P, a, I.seed + 1, {
				n = 6,
				life = 0.35,
				spd = 36,
				even = true,
				grav = 40,
				draw = function(px, py, kk)
					C.dot(c, px, py, 1.4, W.c2, 1 - kk)
				end,
			})
			return
		end
		K.wave(c, P, a, 0.45, 20, W.c2, 2.4)
		K.burst(c, P, a, I.seed, {
			n = 12,
			life = 0.5,
			spd = 46,
			even = true,
			grav = 40,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.8 * (1 - kk * 0.4), W.c2, 1 - kk)
			end,
		})
		if a < 0.3 then
			local kk = a / 0.3
			K.at(c, P[1], P[2] - kk * 6, 0, function()
				swimRing(c, 4.6, 3, W.c0, W.c1, 1 - kk)
			end, 1, 1 - kk * 0.8)
		end
	end,
}

---------------------------------------------------------------- Coin-Op

local ARROW_PIXELS = {
	{ 3, 0, 1 },
	{ 2, -1, 1 },
	{ 2, 1, 1 },
	{ 1, -2, 1 },
	{ 1, 2, 1 },
	{ 2, 0, 3 },
	{ 1, 0, 3 },
	{ 0, 0, 3 },
	{ -1, 0, 3 },
	{ -2, 0, 3 },
	{ -3, 0, 3 },
	{ -4, 0, 3 },
	{ -4, -1, 2 },
	{ -4, 1, 2 },
	{ -5, -2, 2 },
	{ -5, 2, 2 },
}

Sets.HighscoreBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.drops(c, I, t, 0.022, 0.3, function(q, k, i)
			if k > 0.6 and math.floor(k * 12) % 2 == 1 then
				return
			end
			K.pix(c, q[1], q[2], if i % 2 == 1 then W.c1 else W.c0)
		end)
		if t >= I.tEnd then
			return
		end
		local dir = if math.cos(p[3]) >= 0 then 1 else -1
		local pal = { W.c0, W.c1, W.c2 }
		C.glow(c, W, W.c0, 10)
		K.halo(c, p[1], p[2], 8)
		C.noGlow(c)
		for _, px in ARROW_PIXELS do
			K.pix(c, p[1] + px[1] * G * dir, p[2] + px[2] * G, pal[px[3]])
		end
	end,
	h = function(c, P, a, W, _I, _k)
		if a >= 0.5 then
			return
		end
		local kk = a / 0.5
		local st = (math.floor(kk * 5) + 1) * G * 1.4
		local pal = { W.c0, W.c1, W.c2 }
		for i = 0, 7 do
			local an = i / 8 * TAU
			K.pix(c, P[1] + math.cos(an) * st, P[2] + math.sin(an) * st, pal[i % 3 + 1], 1 - kk)
		end
		if kk < 0.4 then
			for _, d in { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				K.pix(c, P[1] + d[1] * G, P[2] + d[2] * G, WHITE, 1 - kk / 0.4)
			end
		end
	end,
}

Sets.JoystickStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local lift = 0.3 * S * math.sin(t * 9 + I.ph)
		K.lamp(c, p, W.c1, 30, 0.3 * K.fade(I, t))
		K.drops(c, I, t, 0.035, 0.4, function(q, k)
			if k > 0.5 and math.floor(k * 10) % 2 == 1 then
				return
			end
			K.pix(c, q[1], q[2], if k < 0.3 then W.c2 else W.c1)
		end)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.4, 5 + lift)
		local cx, cy = p[1], p[2] - lift
		C.glow(c, W, W.c0, 10)
		K.halo(c, cx, cy, 6)
		C.noGlow(c)
		local rim = mix(W.c0, { 0, 0, 0 }, 0.25)
		for gx = -2, 2 do
			for gy = -2, 2 do
				local r = gx * gx + gy * gy
				if r <= 5 then
					K.pix(c, cx + gx * G, cy + gy * G, if r >= 4 then rim else W.c0)
				end
			end
		end
		K.pix(c, cx - G, cy - G, WHITE)
	end,
	h = function(c, P, a, W, _I, _k)
		if a >= 0.55 then
			return
		end
		local kk = a / 0.55
		local R = (math.min(3, math.floor(kk * 4)) + 1) * 5
		for i = 0, 15 do
			local an = i / 16 * TAU
			K.pix(
				c,
				P[1] + math.cos(an) * R,
				P[2] + math.sin(an) * R,
				if i % 2 == 1 then W.c0 else W.c1,
				1 - kk * 0.8
			)
		end
	end,
}

---------------------------------------------------------------- Voidglass

Sets.OrbitBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local pts = tr(I, t, 0.12, 12)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, pts, 7, 0, W.c2, W.c2, 0.85, 0)
		K.ribbon(c, pts, 2.4, 0, W.c0, W.c0, 0.8, 0)
		if not Kit.lite then
			for idx, q in pts do
				local i = idx - 1
				if i == 0 or i % 2 == 1 then
					continue
				end
				local o = (Kit.rnd(I.seed, i, 91) - 0.5) * 5
				local tw = 0.5 + 0.5 * math.sin(t * 24 + i * 1.7)
				K.speck(
					c,
					q[1] - math.sin(q[3]) * o,
					q[2] + math.cos(q[3]) * o,
					0.8,
					WHITE,
					tw * (1 - i / #pts)
				)
			end
		end
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 3)
		K.at(c, p[1], p[2], p[3], function()
			C.glow(c, W, W.c0, 14)
			K.arrow(c, 20, W.c0, W.c1, W.c0, "vane", 2)
			C.noGlow(c)
		end)
		for j = 0, 1 do
			local an = t * 16 + j * PI + I.ph
			local o, d = math.sin(an) * 6.5, math.cos(an)
			local mx = p[1] - math.sin(p[3]) * o - math.cos(p[3]) * 2
			local my = p[2] + math.cos(p[3]) * o - d * 1.2
			C.dot(c, mx, my, 1.6 + 0.6 * d, if j == 1 then WHITE else W.c1, 0.75 + 0.25 * d)
		end
	end,
	h = function(c, P, a, W, I, k)
		if a < 0.12 then
			C.glowDot(c, P[1], P[2], 10, WHITE, 0.9 * (1 - a / 0.12))
		end
		K.wave(c, P, a, 0.4, 15, W.c0, 2.4)
		K.wave(c, P, a - 0.06, 0.4, 10, W.c1, 1.8)
		K.burst(c, P, a, I.seed, {
			n = 6,
			life = 0.5,
			spd = 28,
			even = true,
			draw = function(px, py, kk)
				C.cross(c, px, py, 2.6 * (1 - kk), 0.6, W.c1, 1 - kk)
			end,
		})
		if k == "wall" then
			K.stuck(c, P, a, W.c0, W.c0, "vane")
		end
	end,
}

Sets.StarwellStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c1, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.1, 10), 6, 0, W.c1, W.c0, 0.5, 0)
		K.shed(c, I, t, {
			rate = 20,
			life = 0.6,
			spd = 6,
			draw = function(px, py, k, h)
				K.twinkle(
					c,
					px,
					py,
					1.6 * (1 - k * 0.4),
					h * 3,
					if h < 0.5 then W.c2 else W.c1,
					1 - k
				)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.4)
		K.at(c, p[1], p[2], 0, function()
			local rr = t * 2.4
			-- the ring's far half, the planet, then the near half over it
			K.oval(c, 0, 0, 8.4, 2.8, rr, PI, TAU, 1.5, W.c1, 0.95)
			C.glow(c, W, W.c0, 14)
			K.orb(c, 0, 0, 4.6, mix(W.c0, WHITE, 0.4), W.c0)
			C.noGlow(c)
			local xs, ys = { -4 }, { 1 }
			K.qcurve(xs, ys, -4, 1, 0, 2.4, 4, 1, 4)
			C.polyline(c, xs, ys, 0.8, { 90, 40, 150 }, 0.6)
			K.oval(c, 0, 0, 8.4, 2.8, rr, 0, PI, 1.5, W.c1, 0.95)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		if a < 0.5 then
			local kk = a / 0.5
			local rx = 8 + kk * 14
			K.oval(c, P[1], P[2], rx, rx * 0.36, I.ph, 0, TAU, 2 * (1 - kk) + 0.5, W.c1, 1 - kk)
		end
		if a < 0.15 then
			C.glowDot(c, P[1], P[2], 10, W.c0, 0.8 * (1 - a / 0.15))
		end
		K.burst(c, P, a, I.seed, {
			n = 6,
			life = 0.55,
			spd = 30,
			even = true,
			draw = function(px, py, kk)
				C.star5(c, px, py, 2.4 * (1 - kk * 0.4), kk * 4, W.c2, 1 - kk)
			end,
		})
	end,
}

---------------------------------------------------------------- Lantern Bloom

Sets.BlossomBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.06, 8), 3.6, 0, W.c0, W.c0, 0.6, 0)
		K.shed(c, I, t, {
			rate = 30,
			life = 0.7,
			spd = 10,
			draw = function(px, py, k, h)
				C.petal(
					c,
					px + math.sin(k * 7 + h * 9) * 2.4,
					py,
					2.6,
					h * 6 + k * 5,
					if h < 0.5 then W.c0 else W.c2,
					1 - k
				)
			end,
		})
		if t < I.tEnd then
			K.shade(c, p, 3)
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, W.c0, 12)
				K.arrow(c, 20, W.c0, W.c2, W.c1, "leaf", 2)
				C.noGlow(c)
				C.flower(c, -2, 0, 1.4, W.c2, W.c1, 1)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		if a < 0.12 then
			C.glowDot(c, P[1], P[2], 10, W.c0, 0.7 * (1 - a / 0.12))
		end
		K.burst(c, P, a, I.seed, {
			n = 10,
			life = 0.9,
			spd = 36,
			even = true,
			grav = 26,
			draw = function(px, py, kk, h, i)
				C.petal(
					c,
					px + math.sin(a * 8 + i) * 2.5,
					py,
					3.2,
					h * 6 + kk * 6,
					if i % 2 == 1 then W.c0 else W.c2,
					1 - kk
				)
			end,
		})
		if k == "wall" then
			K.stuck(c, P, a, W.c0, W.c1, "leaf")
		end
	end,
}

Sets.PaperglowStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		local lift = 0.3 * S * math.sin(t * 8 + I.ph)
		K.lamp(c, p, W.c1, 34, 0.34 * K.fade(I, t))
		K.shed(c, I, t, {
			rate = 14,
			life = 0.6,
			spd = 4,
			rise = 20,
			draw = function(px, py, k)
				C.glowDot(c, px, py, 2.6, W.c1, 1 - k)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 5, 5 + lift)
		local qx, qy = p[1], p[2] - lift
		-- the tassel, swaying behind
		local tp = tr(I, t, 0.05, 6, function(_J, tt)
			return math.sin(tt * 20) * 2
		end)
		local xs, ys = { qx }, { qy }
		for i = 2, #tp do
			table.insert(xs, tp[i][1])
			table.insert(ys, tp[i][2] - lift)
		end
		if #xs > 1 then
			C.polyline(c, xs, ys, 1.1, W.c1, 0.95)
			C.dot(c, xs[#xs], ys[#ys], 1.5, W.c1, 1)
		end
		K.at(c, qx, qy, 0, function()
			C.glow(c, W, W.c1, 16)
			K.orb(c, 0, 0, 5.6, W.c1, W.c0)
			C.noGlow(c)
			C.ring(c, 0, 0, 2, { 150, 30, 20 }, 0.6, 0.8)
			C.ring(c, 0, 0, 4, { 150, 30, 20 }, 0.6, 0.8)
			C.dot(c, 0, 0, 1.6, { 255, 220, 120 }, 1)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		if a < 0.25 then
			C.glowDot(c, P[1], P[2], 20, W.c1, 0.6 * (1 - a / 0.25))
		end
		K.wave(c, P, a, 0.4, 20, W.c1, 2)
		K.burst(c, P, a, I.seed, {
			n = 10,
			life = 0.9,
			spd = 18,
			even = true,
			rise = 28,
			draw = function(px, py, kk, _h, i)
				C.glowDot(
					c,
					px,
					py,
					2.8 * (1 - kk * 0.5),
					if i % 2 == 1 then W.c2 else W.c1,
					1 - kk
				)
			end,
		})
	end,
}

---------------------------------------------------------------- Cinderforge

Sets.CinderstringBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		heatTail(c, tr(I, t, 0.11, 12))
		K.shed(c, I, t, {
			rate = 40,
			life = 0.3,
			spd = 50,
			spread = 1.6,
			grav = 60,
			draw = function(px, py, k, h, _i, ang)
				local d = ang + PI + (h - 0.5) * 1.6
				K.seg(
					c,
					px,
					py,
					px - math.cos(d) * 3,
					py - math.sin(d) * 3,
					1,
					Kit.heat(k * 0.4),
					1 - k
				)
			end,
		})
		if t < I.tEnd then
			K.shade(c, p, 3)
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, W.c0, 14)
				K.arrow(c, 20, { 255, 170, 80 }, { 255, 255, 230 }, { 200, 70, 20 }, "vane", 2.2)
				C.noGlow(c)
			end)
		end
	end,
	h = function(c, P, a, _W, I, k)
		local f = 1 - clamp(a / 0.9)
		if f > 0 then
			C.ellipse(c, P[1], P[2], 5, 3.6, 0, Kit.heat(0.2 + a * 0.3), 0.7 * f)
		end
		K.burst(c, P, a, I.seed, {
			n = 14,
			life = 0.35,
			spd = 70,
			cone = 2.4,
			grav = 40,
			draw = function(px, py, kk, _h, _i, dir)
				K.seg(
					c,
					px,
					py,
					px - math.cos(dir) * 4,
					py - math.sin(dir) * 4,
					1.2,
					Kit.heat(kk * 0.4),
					1 - kk
				)
			end,
		})
		if k == "wall" then
			K.stuck(c, P, a, { 255, 140, 60 }, { 200, 70, 20 }, "vane")
		end
	end,
}

Sets.ForgeheartStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.1, 10), 6.5, 0, { 200, 60, 20 }, { 60, 20, 10 }, 0.55, 0)
		K.shed(c, I, t, {
			rate = 36,
			life = 0.55,
			spd = 8,
			rise = 24,
			draw = function(px, py, k)
				C.glowDot(c, px, py, 2.8, Kit.heat(k * 0.4), 1 - k)
			end,
		})
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.4)
		C.ring(c, p[1], p[2], 8 + math.sin(t * 20) * 0.8, W.c1, 0.25, 1)
		K.at(c, p[1], p[2], t * 4, function()
			C.glow(c, W, W.c0, 14)
			K.halo(c, 0, 0, 4.4)
			C.noGlow(c)
			K.rect(c, -4.4, -4.4, 8.8, 8.8, W.c2, 1)
			local pu = 0.6 + 0.4 * math.sin(t * 12)
			C.polyline(c, { -4.4, -1, 1 }, { -1, 0, -3 }, 1.2, W.c1, pu)
			C.polyline(c, { -1, 2, 4.4 }, { 0, 2.4, 1.4 }, 1.2, W.c1, pu)
			C.glowDot(c, 0, 0, 3, W.c0, pu * 0.8)
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.5, 20, Kit.heat(a * 0.6), 3)
		K.burst(c, P, a, I.seed, {
			n = 4,
			life = 0.5,
			spd = 30,
			even = true,
			draw = function(px, py, kk, h)
				K.at(c, px, py, kk * 5 + h * 3, function()
					K.rect(c, -2.4, -2.4, 4.8, 4.8, W.c2, 1 - kk)
					K.strokeRect(c, -2.4, -2.4, 4.8, 4.8, 0.8, W.c0, 1 - kk)
				end)
			end,
		})
		K.burst(c, P, a, I.seed + 5, {
			n = 12,
			life = 0.55,
			spd = 46,
			even = true,
			rise = 10,
			draw = function(px, py, kk)
				C.glowDot(c, px, py, 2.8, Kit.heat(kk * 0.4), 1 - kk)
			end,
		})
	end,
}

return table.freeze(Sets)
