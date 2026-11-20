--!strict
--[[
	The golden pair's shots, cards 32 and 33 of the Projectile Shots page,
	line for line (`Fx/Shots/Kit`). The bow's second arrow (Multishot) and
	the staff's homing (Tracking Eye) are the game's own flights, each drawn
	as a shot of its own.
]]

local Canvas = require(script.Parent.Parent.Cleaves.Canvas)
local Kit = require(script.Parent.Kit)

local C = Canvas
local K = Kit
local hd, tr = Kit.hd, Kit.tr
local PI, TAU, WHITE = Kit.PI, Kit.TAU, Kit.WHITE

local Golden: { [string]: Kit.Drawer } = {}

Golden.GoldenBow = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.06, 8), 4.6, 0, W.c1, W.c0, 0.75, 0)
		K.shed(c, I, t, {
			rate = 18,
			life = 0.4,
			spd = 8,
			draw = function(px, py, k, h)
				C.spark(c, px, py, 2.4 * math.sin(PI * k), h, W.c2, 1)
			end,
		})
		if t < I.tEnd then
			K.shade(c, p, 3)
			K.at(c, p[1], p[2], p[3], function()
				C.glow(c, W, W.c0, 14)
				K.arrow(c, 20, W.c0, W.c1, W.c0, "vane", 2.2)
				C.noGlow(c)
				C.glowDot(c, ((t * 5) % 1) * 18 - 9, 0, 3.4, WHITE, 0.9)
			end)
		end
	end,
	h = function(c, P, a, W, I, k)
		if a < 0.3 then
			C.spark(c, P[1], P[2], 10 * (1 - a / 0.3), a * 4, W.c1, 1)
		end
		K.burst(c, P, a, I.seed, {
			n = 8,
			life = 0.45,
			spd = 42,
			even = true,
			draw = function(px, py, kk)
				C.dot(c, px, py, 1.8 * (1 - kk * 0.4), W.c0, 1 - kk)
				K.speck(c, px - 0.5, py - 0.5, 0.6, WHITE, 1 - kk)
			end,
		})
		K.burst(c, P, a, I.seed + 2, {
			n = 2,
			life = 0.4,
			spd = 30,
			draw = function(px, py, kk, h)
				C.spark(c, px, py, 2.6 * (1 - kk), h, W.c2, 1)
			end,
		})
		if k == "wall" then
			K.stuck(c, P, a, W.c0, W.c0, "vane")
		end
	end,
}

Golden.GoldenStaff = {
	f = function(c, I, t, W)
		local p = hd(I, t)
		K.lamp(c, p, W.c0, 30, 0.3 * K.fade(I, t))
		K.ribbon(c, tr(I, t, 0.1, 10), 7, 0, W.c0, W.c2, 0.55, 0)
		if t >= I.tEnd then
			return
		end
		K.shade(c, p, 4.4)
		K.at(c, p[1], p[2], 0, function()
			C.glow(c, W, W.c0, 14)
			K.orb(c, 0, 0, 5, W.c2, W.c0)
			C.noGlow(c)
			K.at(c, 0, 0, t * 4, function()
				K.rect(c, -1.8, -1.8, 3.6, 3.6, W.c1, 1)
			end)
			for j = 0, 2 do
				local an = t * 7 + j * TAU / 3
				K.seg(
					c,
					math.cos(an) * 6,
					math.sin(an) * 6,
					math.cos(an) * 8.6,
					math.sin(an) * 8.6,
					1.6,
					W.c0,
					1
				)
			end
		end)
	end,
	h = function(c, P, a, W, I, _k)
		K.wave(c, P, a, 0.35, 20, W.c0, 3)
		K.burst(c, P, a, I.seed, {
			n = 8,
			life = 0.4,
			spd = 44,
			even = true,
			draw = function(px, py, kk, h)
				C.spark(c, px, py, 3 * (1 - kk), h, W.c1, 1)
			end,
		})
		if a < 0.2 then
			C.spark(c, P[1], P[2], 8 * (1 - a / 0.2), 0, WHITE, 1)
		end
	end,
}

return table.freeze(Golden)
