--!strict
--[[
	Where the intro cutscene stands at a moment (`Config/Intro`): pure, so
	`UI/IntroCutscene` poses everything from one clock and
	`tests/IntroTimeline.spec` pins the cut to the music's hit.

	`t` is seconds since the cutscene started; `pressedAt` is when BEGIN
	ADVENTURE was pressed, on the same clock, or nil.
]]

local IntroTimeline = {}

export type Config = {
	presentsIn: number,
	presentsFadeIn: number,
	presentsOut: number,
	presentsFadeOut: number,
	presentsPop: number,
	revealAt: number,
	flash: number,
	buttonAt: number,
	buttonIn: number,
	leave: number,
	zoom: { from: number, to: number, period: number, drift: number },
	shafts: { transparency: number, breathe: number, period: number },
	buttonPulse: { size: number, period: number },
}

export type Pose = {
	--[[ 0 hidden, 1 fully shown. ]]
	presents: number,
	presentsScale: number,
	--[[ The picture is up (from the cut on). ]]
	revealed: boolean,
	--[[ The white flash on the cut, 0 gone. ]]
	flash: number,
	button: number,
	--[[ The button's breathing scale, 1 at rest. ]]
	buttonScale: number,
	--[[ The picture's zoom, and its sideways drift as a share of the
	     screen, never more than the zoom leaves spare on each side. ]]
	zoom: number,
	drift: number,
	shaftTransparency: number,
	--[[ The whole cutscene's opacity: 1 until the press, then down to 0. ]]
	shown: number,
	--[[ It has gone and can be torn down. ]]
	done: boolean,
}

local function span(t: number, from: number, length: number): number
	if length <= 0 then
		return if t >= from then 1 else 0
	end
	return math.clamp((t - from) / length, 0, 1)
end

local function outCubic(x: number): number
	return 1 - (1 - x) ^ 3
end

function IntroTimeline.pose(c: Config, t: number, pressedAt: number?): Pose
	local fadeIn = outCubic(span(t, c.presentsIn, c.presentsFadeIn))
	local fadeOut = span(t, c.presentsOut, c.presentsFadeOut)
	local revealed = t >= c.revealAt
	local presents = if revealed then 0 else fadeIn * (1 - fadeOut)

	local since = math.max(t - c.revealAt, 0)
	-- the zoom swings in and out round its range, starting at `from`
	local swing = 0.5 - 0.5 * math.cos(since / c.zoom.period * 2 * math.pi)
	local zoom = c.zoom.from + (c.zoom.to - c.zoom.from) * swing
	local button = if revealed then outCubic(span(t, c.buttonAt, c.buttonIn)) else 0
	local settled = t - (c.buttonAt + c.buttonIn)
	local pulse = if settled > 0
		then 1 + c.buttonPulse.size * 0.5 * (1 - math.cos(
			settled / c.buttonPulse.period * 2 * math.pi
		))
		else 1

	local shown = if pressedAt then 1 - span(t, pressedAt, c.leave) else 1

	return {
		presents = presents,
		presentsScale = c.presentsPop + (1 - c.presentsPop) * fadeIn,
		revealed = revealed,
		flash = if revealed then 1 - span(t, c.revealAt, c.flash) else 0,
		button = button,
		buttonScale = pulse,
		zoom = zoom,
		drift = (zoom - 1) / 2 * c.zoom.drift * math.sin(since / c.zoom.period * 2 * math.pi),
		shaftTransparency = c.shafts.transparency
			+ c.shafts.breathe * math.sin(since / c.shafts.period * 2 * math.pi),
		shown = shown,
		done = shown <= 0,
	}
end

--[[ Whether a press at `t` counts: only once the button is up. ]]
function IntroTimeline.canPress(c: Config, t: number): boolean
	return t >= c.buttonAt
end

return IntroTimeline
