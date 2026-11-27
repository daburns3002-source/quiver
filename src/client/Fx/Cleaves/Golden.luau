--!strict
--[[
	The golden pair's cleaves (`Config/ClassLevels`), cards #38 and #39 of
	the Blade Cleaves page. Each is its card's `ST` code, line for line, in
	`Fx/Cleaves/Canvas`'s port of the page's helpers. The daggers' cuts
	stay long enough for the two slashes to cross into an X (`linger`).
]]

local Canvas = require(script.Parent.Canvas)

type Ctx = Canvas.Ctx
type Inst = Canvas.Inst
type Look = Canvas.Look

local C = Canvas
local clamp, mix = C.clamp, C.mix
local WHITE = C.WHITE
local PI = math.pi

local Golden = {}

-- #38 (Legendary, glows): a solid gold crescent with a shine that runs
-- along it; thins to a gold line and ends in a glint at the tip.
function Golden.GoldenBlade(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "hold")
	local e = s.e
	local F = C.frame(I, 0, s.h, { w = 0.55 * (1 - e * 0.92) })
	C.glow(c, W, W.c0, 16)
	local ok = C.fillBand(c, F, W.c0, mix(W.c0, { 180, 110, 10 }, 0.5), 1 - e * 0.3, 0, 1, 0.75)
	C.noGlow(c)
	local sw = (t - I.T * 0.6) / 0.35
	if ok and sw > 0 and sw < 1.3 then
		C.fillBandStops(c, F, {
			{ u = clamp(sw - 0.25), c = WHITE, a = 0 },
			{ u = clamp(sw), c = W.c1, a = 0.95 },
			{ u = clamp(sw + 0.12), c = WHITE, a = 0 },
		})
	end
	if ok then
		C.strokeLine(c, F, 0, 0, 1, nil, 1.3, W.c1, 0.95)
	end
	local gk = (t - I.T - I.H - I.F * 0.4) / (I.F * 0.6)
	if gk > 0 and gk < 1 then
		local p, q = C.pt(I, 1, I.R - 4)
		C.spark(c, p, q, 13 * math.sin(PI * gk), gk, WHITE, 1)
	end
	C.motes(c, I, t, {
		n = 10,
		life = 0.55,
		spd = 12,
		rise = 16,
		f0 = 0,
		f1 = 0.5,
		draw = function(p, q, k, hh)
			C.cross(c, p, q, 3 * math.sin(PI * k), 0, if hh > 0.5 then W.c2 else W.c1, 1)
		end,
	})
end

-- #39 (Legendary, glows): thin gold cuts that stay long enough for the two
-- slashes to cross into an X, with a red-gold glint; glints and fades.
function Golden.GoldenDaggers(c: Ctx, I: Inst, t: number, W: Look)
	local s = C.span(I, t, "fade")
	local K = C.KK(I)
	local F = C.frame(I, 0, s.h, { w = 0.13, rOut = I.R - K * 0.08 })
	C.glow(c, W, W.c0, 12)
	local ok = C.fillBand(c, F, W.c0, W.c0, s.a, 0, 1, 0.6)
	C.noGlow(c)
	if ok then
		C.strokeLine(c, F, 0.5, 0.05, 0.95, nil, 1, W.c1, s.a)
	end
	local gk = (t - I.T) / 0.35
	if gk > 0 and gk < 1 then
		local p, q = C.pt(I, 1, I.R - K * 0.08)
		C.spark(c, p, q, 10 * math.sin(PI * gk), gk, WHITE, 1)
		C.cross(c, p, q, 4 * math.sin(PI * gk), 0.4, W.c2, 1)
	end
	C.motes(c, I, t, {
		n = 8,
		life = 0.5,
		spd = 10,
		rise = 12,
		f0 = 0,
		f1 = 0.3,
		draw = function(p, q, k)
			C.cross(c, p, q, 2.4 * math.sin(PI * k), 0, W.c0, 1)
		end,
	})
end

return table.freeze(Golden)
