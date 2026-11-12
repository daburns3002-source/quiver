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

	local button = if revealed then outCubic(span(t, c.buttonAt, c.buttonIn)) else 0
	local shown = if pressedAt then 1 - span(t, pressedAt, c.leave) else 1

	return {
		presents = presents,
		presentsScale = c.presentsPop + (1 - c.presentsPop) * fadeIn,
		revealed = revealed,
		flash = if revealed then 1 - span(t, c.revealAt, c.flash) else 0,
		button = button,
		shown = shown,
		done = shown <= 0,
	}
end

--[[ Whether a press at `t` counts: only once the button is up. ]]
function IntroTimeline.canPress(c: Config, t: number): boolean
	return t >= c.buttonAt
end

return IntroTimeline
