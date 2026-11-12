--!strict
--[[
	Where the title screen's picture sits on a screen (`Config/TitleScene`,
	drawn by `UI/TitleScene`): pure, so `tests/TitleScene.spec` can hold the
	logo, the hero and the button on screen at every phone shape without a
	phone.

	A layout is in points for one screen (390 x 844 upright, 844 x 390
	sideways). On any other it is scaled until its `safe` box fills the
	screen and centred; the sky, the ground and the ridge then run on to the
	edges, which `Fit` gives in the layout's own points.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Scene = require(ReplicatedStorage.Shared.Config.TitleScene)

local TitleLayout = {}

type Design = Scene.Design

export type Fit = {
	--[[ Screen points to a layout point, and where the layout's top-left
	     corner lands on the screen. ]]
	scale: number,
	x: number,
	y: number,
	--[[ The screen's own edges, in layout points. ]]
	left: number,
	top: number,
	right: number,
	bottom: number,
}

export type Star = { x: number, y: number, size: number, alpha: number }
export type Mote = { x: number, y: number, size: number, delay: number, loop: number }
export type Piece = { x: number, y: number, long: number, turn: number }
export type Logo = {
	left: number,
	top: number,
	width: number,
	--[[ Each line's top, how tall it is and its letters' size. ]]
	lines: { { top: number, tall: number, size: number } },
	streakTop: number,
	streakLeft: number,
	streakWide: number,
	--[[ The bottom of everything the logo draws, its arrowhead too. ]]
	bottom: number,
}
export type Button = {
	scale: number,
	width: number,
	height: number,
	gap: number,
	words: number,
}

--[[ Which layout a screen takes: the upright one when it is taller than
     wide. ]]
function TitleLayout.orientation(width: number, height: number): "portrait" | "landscape"
	return if height > width then "portrait" else "landscape"
end

function TitleLayout.design(width: number, height: number): Design
	return if TitleLayout.orientation(width, height) == "portrait"
		then Scene.portrait
		else Scene.landscape
end

function TitleLayout.fit(design: Design, width: number, height: number): Fit
	-- a screen not yet measured still gets a layout with real numbers in it
	width, height = math.max(width, 32), math.max(height, 32)
	local scale = math.min(width / design.safe.width, height / design.safe.height)
	local x = (width - design.width * scale) / 2
	local y = (height - design.height * scale) / 2
	return {
		scale = scale,
		x = x,
		y = y,
		left = -x / scale,
		top = -y / scale,
		right = (width - x) / scale,
		bottom = (height - y) / scale,
	}
end

--[[ The reference page's own number generator, so the stars and the motes
     land where the picked drawing has them: each call gives the next number
     from 0 up to 1. ]]
function TitleLayout.random(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1664525 + 1013904223) % 4294967296
		return state / 4294967296
	end
end

local function round(value: number): number
	return math.floor(value + 0.5)
end

--[[ The stars: the drawing's own, then more at the same thickness over any
     sky the screen shows beside or above the layout. ]]
function TitleLayout.stars(design: Design, fit: Fit): { Star }
	local stars: { Star } = {}
	local spec = design.stars
	--[[ `extra` ones are drawn over the wider sky and kept only where the
	     drawing's own stars are not. ]]
	local function add(
		next: () -> number,
		x0: number,
		y0: number,
		wide: number,
		tall: number,
		extra: boolean
	)
		local size = if next() < 0.25 then 3 else 2
		local x = round(x0 + next() * wide)
		local y = round(y0 + next() * tall)
		local alpha = Scene.starFaint + next() * (Scene.starBright - Scene.starFaint)
		local inside = x >= 0 and x <= design.width and y >= 0
		if not (extra and inside) then
			table.insert(stars, { x = x, y = y, size = size, alpha = alpha })
		end
	end
	local next = TitleLayout.random(spec.seed)
	for _ = 1, spec.count do
		add(next, 0, 0, design.width, spec.below, false)
	end
	local left, top = math.min(fit.left, 0), math.min(fit.top, 0)
	local right = math.max(fit.right, design.width)
	if left < 0 or top < 0 or right > design.width then
		local wide, tall = right - left, spec.below - top
		local each = spec.count / (design.width * spec.below)
		local more = TitleLayout.random(spec.seed + 1)
		for _ = 1, math.min(240, round(each * wide * tall)) do
			add(more, left, top, wide, tall, true)
		end
	end
	return stars
end

function TitleLayout.motes(design: Design): { Mote }
	local motes: { Mote } = {}
	local spec, look = design.motes, Scene.mote
	local next = TitleLayout.random(spec.seed)
	for _ = 1, spec.count do
		local size = if next() < look.largeShare then look.large else look.small
		local x = round(spec.box[1] + next() * spec.box[3])
		local y = round(spec.box[2] + next() * spec.box[4])
		local delay = next() * 8
		table.insert(motes, {
			x = x,
			y = y,
			size = size,
			delay = delay,
			loop = look.loop[1] + next() * (look.loop[2] - look.loop[1]),
		})
	end
	return motes
end

--[[ How solid a mote is `share` of the way through its loop: up to its
     peak, easing off, gone at the end. ]]
function TitleLayout.moteAlpha(share: number): number
	local look = Scene.mote
	if share < look.rise then
		return look.peak * share / look.rise
	elseif share < look.ease then
		return look.peak
			+ (look.settled - look.peak) * (share - look.rise) / (look.ease - look.rise)
	end
	return look.settled * (1 - (share - look.ease) / (1 - look.ease))
end

--[[ The logo's lines, top to bottom, and the streak under them, in layout
     points. ]]
function TitleLayout.logo(design: Design): Logo
	local spec, look = design.logo, Scene.logo
	local lines = {}
	local top = spec.y
	for _, size in look.sizes do
		local letters = size * spec.unit
		table.insert(lines, { top = top, tall = letters * look.line, size = letters })
		top += letters * look.line
	end
	local streak = look.streak
	local wide = spec.width * streak.width
	local streakTop = top + streak.gap * spec.unit
	return {
		left = (design.width - spec.width) / 2,
		top = spec.y,
		width = spec.width,
		lines = lines,
		streakTop = streakTop,
		streakLeft = (design.width - wide) / 2,
		streakWide = wide,
		bottom = streakTop + streak.thick / 2 + streak.head.tall / 2,
	}
end

--[[ BEGIN ADVENTURE on a screen, in screen points: it grows with the
     picture up to `Scene.button.most`, sits `gap` above the bottom (of the
     safe area, in the game) and is centred. ]]
function TitleLayout.button(design: Design, fit: Fit): Button
	local scale = math.min(fit.scale, Scene.button.most)
	local spec = design.button
	return {
		scale = scale,
		width = spec.width * scale,
		height = spec.height * scale,
		gap = spec.gap * scale,
		words = spec.words * scale,
	}
end

--[[ A curve from `from` to `to`, bent towards `bend`, as straight pieces:
     each one's middle, its length and its turn in degrees. ]]
function TitleLayout.curve(
	from: { number },
	bend: { number },
	to: { number },
	pieces: number
): { Piece }
	local function at(t: number): (number, number)
		local a, b, c = (1 - t) ^ 2, 2 * (1 - t) * t, t ^ 2
		return a * from[1] + b * bend[1] + c * to[1], a * from[2] + b * bend[2] + c * to[2]
	end
	local out: { Piece } = {}
	local x0, y0 = at(0)
	for n = 1, pieces do
		local x1, y1 = at(n / pieces)
		local dx, dy = x1 - x0, y1 - y0
		table.insert(out, {
			x = (x0 + x1) / 2,
			y = (y0 + y1) / 2,
			long = math.sqrt(dx * dx + dy * dy),
			turn = math.deg(math.atan2(dy, dx)),
		})
		x0, y0 = x1, y1
	end
	return out
end

--[[ The button's size as it pulses: 1 up to a little larger and back,
     easing at both ends. ]]
function TitleLayout.pulse(t: number): number
	local look = Scene.button
	return 1 + look.pulse * (0.5 - 0.5 * math.cos(2 * math.pi * t / look.pulseEvery))
end

return TitleLayout
