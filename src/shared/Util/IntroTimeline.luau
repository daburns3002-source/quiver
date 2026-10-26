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

--[[ How the title picture sits on a screen: its scale, and where its
     top-left corner goes (pixels from the screen's). It fills the screen
     when that crops no more than `maxCrop` of the picture in either
     direction (owner, 2026-10-26: "make sure the archer legends title fits
     in a normal computer sized ratio when full screen on a pc"), cropping
     a too-tall picture `topShare` from its top and the rest from its
     bottom, so the logo stays; otherwise it shows whole, centred, with
     bars. ]]
function IntroTimeline.fit(
	artW: number,
	artH: number,
	screenW: number,
	screenH: number,
	maxCrop: number,
	topShare: number
): (number, number, number)
	local cover = math.max(screenW / artW, screenH / artH)
	local whole = math.min(screenW / artW, screenH / artH)
	local cropW = 1 - screenW / (artW * cover)
	local cropH = 1 - screenH / (artH * cover)
	local scale = if math.max(cropW, cropH) <= maxCrop then cover else whole
	local w, h = artW * scale, artH * scale
	local x = (screenW - w) / 2
	local y = if h > screenH then -(h - screenH) * topShare else (screenH - h) / 2
	return scale, x, y
end

--[[ Whether a press at `t` counts: only once the button is up. ]]
function IntroTimeline.canPress(c: Config, t: number): boolean
	return t >= c.buttonAt
end

return IntroTimeline
