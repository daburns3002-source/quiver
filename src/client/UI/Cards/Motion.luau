--!strict
--[[
	The card design's motion helpers (design_handoff_upgrade_cards, README
	"Motion spec").

	Springs are the design's own: each frame at 60 fps,
	`v = (v + (target − x)·k)·d; x += v`. Run here per frame scaled by the
	real frame time, so a 30 fps phone settles in the same wall-clock time
	as a 144 Hz desktop.
]]

local Motion = {}

export type Spring = {
	x: number,
	v: number,
	target: number,
	k: number,
	d: number,
}

function Motion.spring(start: number, k: number, d: number): Spring
	return { x = start, v = 0, target = start, k = k, d = d }
end

--[[ Advances a spring by `deltaTime` seconds, in 60 fps steps. ]]
function Motion.step(spring: Spring, deltaTime: number)
	local frames = math.clamp(deltaTime * 60, 0, 4)
	local whole = math.floor(frames)
	for _ = 1, whole do
		spring.v = (spring.v + (spring.target - spring.x) * spring.k) * spring.d
		spring.x += spring.v
	end

	local part = frames - whole
	if part > 0 then
		local v = (spring.v + (spring.target - spring.x) * spring.k) * spring.d
		spring.x += v * part
		spring.v = spring.v + (v - spring.v) * part
	end
end

--[[ Easing curves for the timed tweens, `t` from 0 to 1. ]]
function Motion.backOut(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

function Motion.quadIn(t: number): number
	return t * t
end

function Motion.quadInOut(t: number): number
	return if t < 0.5 then 2 * t * t else 1 - (-2 * t + 2) ^ 2 / 2
end

function Motion.cubicInOut(t: number): number
	return if t < 0.5 then 4 * t * t * t else 1 - (-2 * t + 2) ^ 3 / 2
end

return Motion
