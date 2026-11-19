--!strict
--[[
	The eight themed sets' cleaves, cards #40 to #55 of the Blade Cleaves
	page: each set's sword and pair of daggers, all Legendary. Each is its
	card's `ST` code, line for line, in `Fx/Cleaves/Canvas`'s port of the
	page's helpers. Where the page clips (the nebula's stars, the glitch's
	slices), the clipped shape is worked out instead.
]]

local Canvas = require(script.Parent.Canvas)

type Ctx = Canvas.Ctx
type Inst = Canvas.Inst
type Look = Canvas.Look
type RGB = Canvas.RGB
type Frame = Canvas.Frame

local C = Canvas
local clamp, lerp, mix, rnd = C.clamp, C.lerp, C.mix, C.rnd
local WHITE = C.WHITE
local PI, TAU = math.pi, C.TAU

local Sets = {}

-- Neon Circuit ------------------------------------------------------------

-- #40: three neon circuit lines with right-angle steps, magenta pulses
-- racing along them; sections switch off one by one.
function Sets.OverclockBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e = s.e
	local F = C.frame(I, 0, 1, { w = 0.7, prof = C.P.one })
	local nseg = 9
	for li, f in { 0.06, 0.4, 0.74 } do
		local row = (li - 1) * 20
		local runs: { { { number } } } = {}
		local open = 0
		local nodes: { { number } } = {}
		for j = 0, nseg - 1 do
			local v0 = j / nseg
			if v0 > s.h then
				break
			end
			local off = clamp(e * 1.8 - rnd(I.seed, row + j, 1) * 0.8)
			if off > 0.5 then
				open = 0
				continue
			end
			local fj = f + (if rnd(I.seed, row + j, 2) > 0.5 then 0.13 else 0)
			local a, b = F.p(v0, fj)
			local cx, cy = F.p(math.min((j + 1) / nseg, s.h), fj)
			if open == 0 then
				table.insert(runs, {})
				open = #runs
			end
			table.insert(runs[open], { a, b })
			table.insert(runs[open], { cx, cy })
			table.insert(nodes, { a, b })
		end
		C.glow(c, W, W.c0, 10)
		for _, points in runs do
			-- each straight piece on its own, square-capped, so the steps
			-- turn at right angles
			for k = 1, #points - 1 do
				local a, b = points[k], points[k + 1]
				local dx, dy = b[1] - a[1], b[2] - a[2]
				local len = math.sqrt(dx * dx + dy * dy)
				if len > 0.01 then
					local ux, uy = dx / len * 1.1, dy / len * 1.1
					C.polyline(
						c,
						{ a[1] - ux, b[1] + ux },
						{ a[2] - uy, b[2] + uy },
						2.2,
						W.c0,
						0.95
					)
				end
			end
		end
		C.noGlow(c)
		for _, node in nodes do
			C.rect(c, node[1], node[2], 3.2, 3.2, 0, WHITE, 0.95)
		end
		local pu = (t * 1.4 + (li - 1) * 0.33) % 1
		if pu <= s.h and e < 0.5 then
			local fj = f + (if rnd(I.seed, row + math.floor(pu * nseg), 2) > 0.5 then 0.13 else 0)
			local p, q = F.p(pu, fj)
			c.light = true
			C.glowDot(c, p, q, 6, W.c1, 1)
			c.light = false
		end
	end
end

-- #41: a magenta cut sliced into jittering strips with a cyan colour
-- split; glitches out in jumps.
function Sets.GlitchDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local e = s.e
	local F = C.frame(I, 0, s.h, { w = 0.26 })
	if not F.ok or s.a <= 0 then
		return
	end
	C.underGlow(c, I, t, 0.26, W.c0, 0.25)
	local y0, y1 = math.huge, -math.huge
	for i = 0, 10 do
		for _, f in { 0, 1 } do
			local _, q = F.p(i / 10, f)
			y0, y1 = math.min(y0, q), math.max(y1, q)
		end
	end
	-- the band's outline (and its middle half's), each corner with its v
	local function outline(f0: number, f1: number): { { number } }
		local n = 24
		local poly = {}
		for i = 0, n do
			local x, y = F.p(i / n, f0)
			table.insert(poly, { x, y, i / n })
		end
		for i = n, 0, -1 do
			local x, y = F.p(i / n, f1)
			table.insert(poly, { x, y, i / n })
		end
		return poly
	end
	local whole, middle = outline(0, 1), outline(0.25, 0.75)
	-- where the line across at y meets the outline: pairs of { x, v }
	local function crossings(poly: { { number } }, y: number): { { number } }
		local hits = {}
		for i = 1, #poly do
			local a, b = poly[i], poly[i % #poly + 1]
			if (a[2] <= y) ~= (b[2] <= y) then
				local k = (y - a[2]) / (b[2] - a[2])
				table.insert(hits, { lerp(a[1], b[1], k), lerp(a[3], b[3], k) })
			end
		end
		table.sort(hits, function(p, q)
			return p[1] < q[1]
		end)
		return hits
	end
	local function slice(
		poly: { { number } },
		y: number,
		dx: number,
		head: RGB,
		tail: RGB,
		alpha: number
	)
		local hits = crossings(poly, y + 2.5)
		for k = 1, #hits - 1, 2 do
			local l, r = hits[k], hits[k + 1]
			local xl, xr = l[1] + dx, r[1] + dx
			C.push(
				c,
				{ xl, xr },
				{ y, y },
				{ xl, xr },
				{ y + 5, y + 5 },
				{ mix(tail, head, l[2]), mix(tail, head, r[2]) },
				{ lerp(alpha * 0.5, alpha, l[2]), lerp(alpha * 0.5, alpha, r[2]) }
			)
		end
	end
	local sd = I.seed * 31 + math.floor(t * 18)
	local y = math.floor(y0 / 5) * 5 - 5
	while y < y1 + 5 do
		if not (e > 0 and rnd(sd, y, 3) < e) then
			local dx = if rnd(sd, y, 1) < 0.25 then (rnd(sd, y, 2) - 0.5) * (8 + e * 30) else 0
			slice(whole, y, dx + 2, W.c1, W.c1, 0.65 * s.a)
			slice(whole, y, dx - 2, W.c0, W.c0, 0.65 * s.a)
			slice(middle, y, dx, WHITE, W.c0, 0.9 * s.a)
		end
		y += 5
	end
end

-- Starwish ----------------------------------------------------------------

-- #42: a twisting gold-to-pink ribbon led by a spinning star; fades as
-- sparkles burst off it.
function Sets.WishcutterBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K, h = C.KK(I), s.h
	local F = C.frame(I, 0, h, {
		w = 0.5,
		mid = I.R - K * 0.28,
		prof = function(v: number): number
			return C.P.cres(v) * (0.22 + 0.78 * math.abs(math.cos(v * h * PI * 2.5 + 0.3)))
		end,
	})
	if F.ok and s.a > 0 then
		C.glow(c, W, W.c0, 16)
		C.fillBandStops(c, F, {
			{ u = 0, c = W.c1, a = 0.75 * s.a },
			{ u = h * 0.5, c = W.c0, a = s.a },
			{ u = h, c = W.c2, a = s.a },
		}, 0, 1, C.segs(c, 40))
		C.noGlow(c)
		if t < I.T + I.H + I.F * 0.5 then
			local p, q = F.p(1, 0.5)
			C.glow(c, W, W.c0, 10)
			C.star5(c, p, q, 8 * (1 - s.e), t * 6, W.c0, 1)
			C.noGlow(c)
			C.star5(c, p, q, 3.4 * (1 - s.e), t * 6, WHITE, 1)
		end
	end
	C.motes(c, I, t, {
		n = 18,
		life = 0.5,
		spd = 8,
		f0 = 0.1,
		f1 = 0.5,
		draw = function(p, q, k, hh)
			C.spark(c, p, q, 3 * math.sin(PI * k), 0, if hh > 0.5 then W.c1 else W.c0, 1)
		end,
	})
	C.motes(c, I, t, {
		n = 18,
		on = "dis",
		life = 0.6,
		spd = 40,
		f0 = 0.1,
		f1 = 0.5,
		draw = function(p, q, k, hh)
			C.spark(c, p, q, 3.6 * math.sin(PI * k), 0, if hh > 0.5 then W.c1 else W.c2, 1)
		end,
	})
end

-- #43: a row of four-point sparkles that grow toward the tip; they
-- twinkle out one at a time.
function Sets.TwinkleDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K = C.headU(I, t), C.dis(I, t), C.KK(I)
	local F = C.frame(I, 0, math.max(h, 0.003), { w = 0.2 })
	if F.ok then
		C.strokeLine(c, F, 0.5, 0, 1, nil, 1, W.c2, 0.5 * (1 - d))
	end
	for i = 0, 9 do
		local u = (i + 0.5) / 10
		if u > h then
			break
		end
		local ag = t - C.passT(I, u)
		local out = clamp((d - rnd(I.seed, i, 1) * 0.6) / 0.4)
		if out >= 1 then
			continue
		end
		local sz = (3 + u * 5) * C.sm(ag / 0.05) * (1 + math.sin(out * PI) * 0.7) * (1 - out)
		local p, q = C.pt(I, u, I.R - K * 0.1)
		local colour = if i % 2 == 1 then W.c0 else W.c1
		C.glow(c, W, colour, 8)
		if sz > 0.1 and c.glowCol then
			-- the glow under a sparkle
			local light = c.light
			c.light = true
			C.glowDot(c, p, q, sz + 4, colour, 0.4)
			c.light = light
		end
		C.noGlow(c)
		C.spark(c, p, q, sz, ag * 2, colour, 1)
		C.dot(c, p, q, sz * 0.18, WHITE, 1)
	end
end

-- Tumbleweed --------------------------------------------------------------

-- #44: a twisted rope with a loop at the tip, kicking up dust; the rope
-- whips and reels in from the tail.
function Sets.TrailbossBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "retract")
	local K, e = C.KK(I), s.e
	local mid = I.R - K * 0.3
	local function wob(u: number): number
		return e * 9 * math.sin(u * 14 - t * 38)
	end
	C.underGlow(c, I, t, 0.25, W.c0, 0.22)
	if s.u1 - s.u0 > 0.003 then
		local xs, ys = {}, {}
		local n = C.segs(c, 30)
		for i = 0, n do
			local u = lerp(s.u0, s.u1, i / n)
			xs[i + 1], ys[i + 1] = C.pt(I, u, mid + wob(u))
		end
		C.polyline(c, xs, ys, 7, { 112, 74, 34 }, 1)
		C.polyline(c, xs, ys, 4.6, W.c2, 1)
		-- the rope's twist
		local u = math.ceil(s.u0 * 44) / 44
		while u <= s.u1 do
			local th = C.ang(I, u)
			local p, q = C.pt(I, u, mid + wob(u))
			local tg = th + PI / 2
			C.polyline(c, {
				p + math.cos(th) * 2.6 - math.cos(tg) * 1.6,
				p - math.cos(th) * 2.6 + math.cos(tg) * 1.6,
			}, {
				q + math.sin(th) * 2.6 - math.sin(tg) * 1.6,
				q - math.sin(th) * 2.6 + math.sin(tg) * 1.6,
			}, 1.3, { 150, 100, 45 }, 0.95)
			u += 1 / 44
		end
		for _, at in { 0.3, 0.6 } do
			if at < s.u0 or at > s.u1 then
				continue
			end
			local p, q = C.pt(I, at, mid + wob(at))
			C.rect(c, p, q, 6, 6, PI / 4, W.c1, 1)
		end
		local p, q = C.pt(I, s.u1, mid + wob(s.u1))
		C.arcLine(c, p, q, 7.5, 0, TAU, 6.5, { 112, 74, 34 }, 1)
		C.arcLine(c, p, q, 7.5, 0, TAU, 4, W.c2, 1)
	end
	C.motes(c, I, t, {
		n = 12,
		life = 0.65,
		spd = 12,
		f0 = -0.02,
		f1 = 0.15,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 5 + k * 8, { 214, 186, 140 }, 0.5 * (1 - k))
		end,
	})
end

-- #45: a gold cut with two turquoise spur wheels rolling along it; the
-- spurs roll off ahead.
function Sets.SpurDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K, e = C.KK(I), s.e
	C.glow(c, W, W.c0, 10)
	C.fillBand(c, C.frame(I, 0, s.h, { w = 0.16 }), W.c2, W.c0, s.a, 0, 1, 0.5)
	C.noGlow(c)
	for j = 0, 1 do
		local u = clamp(s.h - j * 0.18)
		if u <= 0 then
			continue
		end
		local th = C.ang(I, u)
		local roll = e * e * 30
		local p, q = C.pt(I, u, I.R - K * (0.08 + j * 0.12))
		p += math.cos(th) * roll
		q += math.sin(th) * roll
		C.spiky(c, p, q, 7 - j, t * 14 + j, W.c1, 1 - e, 8, 0.36)
		C.dot(c, p, q, 1.6, { 60, 40, 20 }, 1 - e)
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.6,
		spd = 10,
		f0 = -0.02,
		f1 = 0.2,
		draw = function(p, q, k)
			C.glowDot(c, p, q, 4 + k * 7, { 214, 186, 140 }, 0.5 * (1 - k))
		end,
	})
end

-- Splash Day --------------------------------------------------------------

-- #46: a striped cyan, white and coral crescent, like an inflatable;
-- squeezes thin and pops into a splash.
function Sets.BreakerBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e, K = s.e, C.KK(I)
	local pal = { W.c0, WHITE, W.c1, WHITE }
	local n = 12
	local sq = 1 - C.sm(clamp(e * 1.4))
	C.underGlow(c, I, t, 0.5, W.c0, 0.25)
	for i = 0, n - 1 do
		local u0 = i / n
		if u0 >= s.h or sq <= 0 then
			break
		end
		local F = C.frame(I, u0, math.min((i + 1) / n, s.h) + 0.003, {
			w = 0.6 * sq,
			mid = I.R - K * 0.3,
			g = { 0, math.max(s.h, 0.001) },
		})
		local colour = pal[i % 4 + 1]
		C.fillBand(c, F, colour, colour, 1, 0, 1, 1)
	end
	local F = C.frame(I, 0, s.h, { w = 0.6 * sq, mid = I.R - K * 0.3 })
	if sq > 0 and F.ok then
		C.strokePath(c, F, 0, 1, nil, 1.5, { 28, 88, 118 }, 0.85)
		C.strokeLine(c, F, 0.18, 0.05, 0.95, nil, 1.3, WHITE, 0.75)
	end
	C.motes(c, I, t, {
		n = 26,
		on = "dis",
		spreadT = 0.3,
		life = 0.5,
		spd = 60,
		spread = 2.4,
		grav = 90,
		f0 = 0.1,
		f1 = 0.5,
		draw = function(p, q, k, _hh, i)
			C.dot(c, p, q, 2.4 * (1 - k * 0.5), if i % 2 == 1 then W.c0 else W.c1, 1 - k)
		end,
	})
end

-- #47: a water-gun stream of cyan drops ending in a coral splash; the
-- drops fall into little puddles.
function Sets.SquirtDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K = C.headU(I, t), C.dis(I, t), C.KK(I)
	local pa = 1 - C.after(I, t, 0.6)
	C.underGlow(c, I, t, 0.2, W.c0, 0.22)
	for i = 0, 17 do
		local u = (i + 0.5) / 18
		if u > h then
			break
		end
		local fall = clamp(d * 1.4 - rnd(I.seed, i, 1) * 0.4)
		local th = C.ang(I, u) + C.sweepSign(I) * PI / 2
		local p, q = C.pt(I, u, I.R - K * (0.08 + rnd(I.seed, i, 2) * 0.12))
		local saved = C.save(c)
		c.lift -= fall * fall * 10 / c.s
		if fall < 1 then
			C.ellipse(
				c,
				p,
				q,
				4.6 * (1 - fall * 0.6),
				1.9,
				th,
				if i % 3 ~= 0 then W.c0 else mix(W.c0, WHITE, 0.5),
				1 - fall * 0.3
			)
		elseif pa > 0 then
			C.ellipse(c, p, q, 3.4, 1.7, 0, W.c0, 0.35 * pa)
		end
		C.restore(c, saved)
	end
	local sp = (t - I.T) / 0.3
	if sp > 0 and sp < 1 then
		local p, q = C.pt(I, 1, I.R - K * 0.15)
		for j = 0, 6 do
			local an = j / 7 * TAU
			C.dot(
				c,
				p + math.cos(an) * sp * 15,
				q + math.sin(an) * sp * 15,
				2.3 * (1 - sp),
				W.c1,
				1 - sp
			)
		end
	end
end

-- Coin-Op -----------------------------------------------------------------

--[[ A plain sword arc's size on the card (reach by thickness by angle). ]]
local PIXEL_AREA = 31076

-- #48: a blocky crescent built from pixels, with red pixels on its edge;
-- the pixels blink out at random.
function Sets.PixelBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e, K = s.e, C.KK(I)
	--[[ The card's 6 pixel grid at the card's size. A swing grown by the
	     cards, or a weak device, gets bigger pixels instead of more, so a
	     blow stays a few hundred of them. ]]
	local size = I.R * K * math.abs(I.a1 - I.a0)
	local G = 6 * math.max(1, math.sqrt(size / PIXEL_AREA)) / math.sqrt(c.detail)
	local F = C.frame(I, 0, 1, { w = 0.62 })
	C.underGlow(c, I, t, 0.62, W.c0, 0.22)
	local seen: { [number]: boolean } = {}
	local nu = math.ceil(math.abs(I.a1 - I.a0) * I.R / G * 1.6)
	local nf = math.ceil(K * 0.62 / G) + 2
	for i = 0, nu do
		local u = i / nu
		if u > s.h then
			break
		end
		for j = 0, nf do
			local p, q = F.p(u, j / nf)
			local gx, gy = math.round(p / G), math.round(q / G)
			local key = gx * 4096 + gy
			if seen[key] then
				continue
			end
			seen[key] = true
			if e > 0 and rnd(gx, gy, I.seed) < C.sm(e * 1.3) then
				continue
			end
			local colour = if j == 0 then W.c1 else mix(W.c0, WHITE, (1 - j / nf) * 0.4)
			C.rect(c, gx * G - 0.5, gy * G - 0.5, G - 1, G - 1, 0, colour, 1)
		end
	end
end

-- #49: red and blue arcade pellets on a pixel grid, with a pixel burst at
-- the tip; the lights go out in a chase from the tail.
function Sets.TokenDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local h, d, K = C.headU(I, t), C.dis(I, t), C.KK(I)
	local G, n = 5, 13
	C.underGlow(c, I, t, 0.18, W.c1, 0.25)
	for i = 0, n - 1 do
		local u = (i + 0.5) / n
		if u > h then
			break
		end
		if d > 0 and i / n < C.sm(d) * 1.15 then
			continue
		end
		local p, q = C.pt(I, u, I.R - K * 0.12)
		local gx, gy = math.round(p / G) * G, math.round(q / G) * G
		local bl = (math.floor(t * 12) + i) % 2
		C.rect(c, gx, gy, 8, 8, 0, if i % 2 == 1 then W.c0 else W.c1, 1)
		C.rect(c, gx - 2.5, gy - 2.5, 3, 3, 0, WHITE, 0.65 * bl)
	end
	local sp = (t - I.T) / 0.28
	if sp > 0 and sp < 1 then
		local p, q = C.pt(I, 1, I.R - K * 0.12)
		for j = 0, 7 do
			local an = j / 8 * TAU
			local r = sp * 17
			local x = math.round((p + math.cos(an) * r) / 2) * 2
			local y = math.round((q + math.sin(an) * r) / 2) * 2
			C.rect(c, x, y, 4, 4, 0, if j % 2 == 1 then W.c0 else W.c1, 1 - sp)
		end
	end
end

-- Voidglass ---------------------------------------------------------------

-- Where a point lies in a band, 0 at its middle to 1 on its edges (above
-- 1 outside): the page clips the nebula's stars to its rift.
local function inside(F: Frame, th: number, u: number, depth: number): number
	if u < F.u0 or u > F.u1 or F.u1 <= F.u0 then
		return 2
	end
	local v = (u - F.u0) / (F.u1 - F.u0)
	local thick = th * C.P.cres(v)
	if thick <= 0 then
		return 2
	end
	return math.abs(depth / thick - 0.5) * 2
end

-- #50: a dark rift in the floor full of twinkling stars, glowing at its
-- edges; zips shut from both ends toward the middle.
function Sets.NebulaBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "close")
	local K = C.KK(I)
	local th = K * 0.6
	local F = C.frame(I, s.u0, s.u1, { w = 0.6 })
	if F.ok then
		C.glow(c, W, W.c0, 18)
		C.fillBand(c, F, { 26, 10, 50 }, { 26, 10, 50 }, 0.94, 0, 1, 1)
		C.noGlow(c)
		for i = 0, 4 do
			local u, depth = rnd(I.seed, i, 8), K * 0.3 * rnd(I.seed, i, 9)
			local where = inside(F, th, u, depth)
			if where < 1 then
				local p, q = C.pt(I, u, I.R - depth)
				local v = (u - F.u0) / (F.u1 - F.u0)
				local room = th * C.P.cres(v) * 0.5
				C.glowDot(c, p, q, math.min(16, room + 4), if i % 2 == 1 then W.c0 else W.c1, 0.35)
			end
		end
		for i = 0, 45 do
			local u, depth = rnd(I.seed, i, 1), K * 0.55 * rnd(I.seed, i, 2)
			if inside(F, th, u, depth) <= 1 then
				local p, q = C.pt(I, u, I.R - depth)
				local tw = 0.5 + 0.5 * math.sin(t * 9 + i * 2.1)
				C.dot(c, p, q, 0.6 + rnd(I.seed, i, 3) * 1.1, WHITE, 0.35 + 0.65 * tw)
			end
		end
		C.strokeLine(c, F, 0, 0, 1, nil, 1.8, W.c1, 0.95)
		C.strokeLine(c, F, 1, 0, 1, nil, 1.4, W.c0, 0.95)
	end
	local dk = (C.dis(I, t) - 0.85) / 0.15
	if dk > 0 and dk < 1 then
		local p, q = C.pt(I, 0.5, I.R - K * 0.15)
		C.spark(c, p, q, 10 * math.sin(PI * dk), 0, WHITE, 1)
	end
end

-- #51: a bright comet head with a short pink-to-purple tail; the head
-- hangs a moment, then bursts into sparkles.
function Sets.CometDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local h, K = C.headU(I, t), C.KK(I)
	local s = C.span(I, t, "streak", 0.16)
	c.light = true
	C.glow(c, W, W.c0, 14)
	C.fillBand(
		c,
		C.frame(I, s.u0, s.u1, { w = 0.24, prof = C.P.head, rOut = I.R - K * 0.02 }),
		W.c0,
		W.c1,
		1,
		0,
		1,
		0.15
	)
	C.noGlow(c)
	local ht = t - I.T
	local p, q = C.pt(I, h, I.R - K * 0.1)
	if ht < I.H + 0.05 then
		C.glowDot(c, p, q, 10, W.c0, 1)
		C.dot(c, p, q, 3.2, { 255, 236, 250 }, 1)
	else
		local k = clamp((ht - I.H - 0.05) / 0.3)
		if k < 1 then
			for j = 0, 7 do
				local an = j / 8 * TAU + 0.2
				C.spark(
					c,
					p + math.cos(an) * k * 18,
					q + math.sin(an) * k * 18,
					4.2 * (1 - k),
					an,
					if j % 2 == 1 then W.c0 else W.c1,
					1 - k
				)
			end
		end
	end
	C.motes(c, I, t, {
		n = 14,
		life = 0.4,
		spd = 6,
		f0 = 0,
		f1 = 0.3,
		draw = function(mp, mq, k, hh)
			C.spark(c, mp, mq, 2.4 * (1 - k), hh, W.c2, 1 - k)
		end,
	})
	c.light = false
end

-- Lantern Bloom -----------------------------------------------------------

-- #52: pink petals laid along a soft pink arc; the petals flutter down
-- and settle before fading.
function Sets.PetalfallBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e, K = s.e, C.KK(I)
	C.glow(c, W, W.c0, 14)
	C.fillBand(c, C.frame(I, 0, s.h, { w = 0.55 }), W.c0, W.c1, 0.3 * (1 - e), 0, 1, 0.5)
	C.noGlow(c)
	local settle = C.after(I, t, 0.7)
	for i = 0, 23 do
		local u = rnd(I.seed, i, 1)
		if u > s.h then
			continue
		end
		local g = C.sm((t - C.passT(I, u)) / 0.07)
		local fall = clamp(e * 1.5 - rnd(I.seed, i, 3) * 0.5)
		local p, q = C.pt(I, u, I.R - K * 0.55 * C.P.cres(u) * rnd(I.seed, i, 2) * 0.9)
		p += math.sin(fall * 7 + i) * 6 * fall
		local al = if fall >= 1 then (1 - settle) * 0.7 else 1
		if al <= 0 then
			continue
		end
		local saved = C.save(c)
		c.lift -= fall * 14 / c.s
		C.petal(
			c,
			p,
			q,
			4.4 * g,
			C.ang(I, u) + i + fall * 3,
			if i % 3 ~= 0 then W.c0 else mix(W.c0, WHITE, 0.45),
			al
		)
		C.dot(c, p, q, 1.1 * g, W.c1, al)
		C.restore(c, saved)
	end
end

-- #53: a thin orange cut with sound waves ringing out of it and flower
-- confetti; fades as the chimes spread.
function Sets.BellchimeDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K = C.KK(I)
	C.glow(c, W, W.c0, 10)
	C.fillBand(c, C.frame(I, 0, s.h, { w = 0.15 }), W.c0, W.c0, s.a, 0, 1, 0.5)
	C.noGlow(c)
	for i = 0, 2 do
		local u = 0.2 + i * 0.3
		if u > s.h then
			break
		end
		local ag = t - C.passT(I, u)
		local th = C.ang(I, u)
		local p, q = C.pt(I, u, I.R - K * 0.05)
		for k = 0, 2 do
			local r = (ag - k * 0.07) / 0.38
			if r >= 0 and r <= 1 then
				C.arcLine(c, p, q, 4 + r * 13, th - 0.6, th + 0.6, 1.7, W.c2, 1 - r)
			end
		end
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.6,
		spd = 30,
		grav = 50,
		f0 = 0,
		f1 = 0.3,
		draw = function(p, q, k)
			C.flower(c, p, q, 1.5, W.c1, { 255, 240, 200 }, 1 - k)
		end,
	})
end

-- Cinderforge -------------------------------------------------------------

-- The colour of metal `ag` seconds after the blade passed: white-hot,
-- orange, red, dark crust.
local function heat(ag: number): RGB
	local k = clamp(ag / 0.45)
	if k < 0.3 then
		return mix({ 255, 246, 205 }, { 255, 170, 40 }, k / 0.3)
	elseif k < 0.7 then
		return mix({ 255, 170, 40 }, { 205, 70, 22 }, (k - 0.3) / 0.4)
	end
	return mix({ 205, 70, 22 }, { 74, 36, 26 }, (k - 0.7) / 0.3)
end

-- #54: white-hot at the tip, cooling to orange then dark crust, throwing
-- anvil sparks; cools and fades out.
function Sets.MoltenBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local F = C.frame(I, 0, s.h, { w = 0.6 })
	if F.ok and s.a > 0 then
		local stops: { Canvas.Stop } = {}
		for i = 0, 8 do
			local u = i / 8 * s.h
			table.insert(stops, { u = u, c = heat(t - C.passT(I, u)), a = s.a })
		end
		C.glow(c, W, W.c0, 16)
		C.fillBandStops(c, F, stops)
		C.noGlow(c)
		for i = 0, 6 do
			local v = (i + 0.5) / 7
			local u = v * s.h
			if t - C.passT(I, u) < 0.18 then
				continue
			end
			local a, b = F.p(v, 0.1)
			local xs, ys = { a }, { b }
			for j = 1, 3 do
				local x, y = F.p(clamp(v + (rnd(I.seed, i, j) - 0.5) * 0.06), 0.1 + j * 0.25)
				table.insert(xs, x)
				table.insert(ys, y)
			end
			C.polyline(c, xs, ys, 1.3, W.c1, 0.95 * s.a)
		end
	end
	C.motes(c, I, t, {
		n = 22,
		life = 0.35,
		spd = 95,
		spread = 1.4,
		grav = 240,
		f0 = 0,
		f1 = 0.2,
		draw = function(p, q, k, hh, _i, th)
			C.shard(c, p, q, 3, th + hh, mix({ 255, 250, 200 }, W.c1, k), 1 - k)
		end,
	})
end

-- #55: an orange cut cracked into glowing pieces; the pieces fall and
-- cool to dark red.
function Sets.EmbershardDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local h, d = C.headU(I, t), C.dis(I, t)
	local n = 7
	for i = 0, n - 1 do
		local u0 = i / n
		if u0 >= h then
			break
		end
		local k = C.sm(clamp(d * 1.5 - rnd(I.seed, i, 1) * 0.5))
		if k >= 1 then
			continue
		end
		local F = C.frame(
			I,
			u0 + 0.005,
			math.min((i + 1) / n - 0.005, h),
			{ w = 0.22, g = { 0, math.max(h, 0.001) } }
		)
		if not F.ok then
			continue
		end
		local saved = C.save(c)
		c.ox += (rnd(I.seed, i, 2) - 0.5) * k * 14
		c.lift -= k * k * 16 / c.s
		local colour = if k < 0.5
			then mix(W.c0, W.c1, k * 2)
			else mix(W.c1, { 90, 30, 20 }, (k - 0.5) * 2)
		if k < 0.5 then
			C.glow(c, W, W.c1, 10)
		end
		C.fillBand(c, F, colour, colour, 1 - k * 0.7, 0, 1, 1)
		C.noGlow(c)
		C.restore(c, saved)
	end
end

return table.freeze(Sets)
