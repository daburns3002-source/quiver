--!strict
--[[
	Where the story cutscene stands at a moment (`Config/Story`): pure, so
	`UI/StoryCutscene` poses everything from one clock and
	`tests/StoryTimeline.spec` pins its order and its end.

	The cutscene is a run of shots. Each shows one picture at a time from its
	frames (frame by frame, each held for its own time, looping or holding
	the last), and may pan across a picture wider than the screen, push in,
	or shake. It opens from black, fades through black where a shot asks to,
	and ends on black, held, before the run is let go.

	`t` is seconds since the cutscene started; `skippedAt` is when SKIP was
	pressed, on the same clock, or nil.
]]

local StoryTimeline = {}

export type Frame = { picture: string, hold: number }

export type Shot = {
	name: string,
	length: number,
	frames: { Frame },
	--[[ Plays its frames round again instead of holding the last. ]]
	loop: boolean?,
	--[[ Across a picture pushed in wider than the screen: 0 its left edge,
	     1 its right, from the shot's start to its end (centred without). ]]
	pan: { from: number, to: number }?,
	--[[ A push in: the picture's scale at the start and at the end. ]]
	zoom: { from: number, to: number }?,
	--[[ The screen shakes by up to this share of its height, from `at`
	     seconds into the shot for `time` seconds, dying away. ]]
	shake: { at: number, time: number, size: number }?,
	--[[ Fades up from black over this long as the shot starts. ]]
	fadeIn: number?,
}

export type Config = {
	--[[ Black before the first shot, under the title fading away. ]]
	lead: number,
	shots: { Shot },
	--[[ The last shot fades to black over this long, at its end ... ]]
	fadeOut: number,
	--[[ ... and the black holds this long before the run is let go. ]]
	blackHold: number,
	--[[ SKIP fades to black over this long, then the black holds. ]]
	skipFade: number,
}

export type Pose = {
	--[[ The shot showing (its index), and its picture; nil on black. ]]
	shot: number?,
	picture: string?,
	--[[ 0 the picture's left edge on the screen's, 1 its right; 0.5 centred. ]]
	pan: number,
	zoom: number,
	--[[ The screen's offset, as shares of its height. ]]
	shake: Vector2,
	--[[ The black cover's opacity, 1 fully black. ]]
	black: number,
	--[[ The black has held: let the run go and tear down. ]]
	done: boolean,
}

local function span(t: number, from: number, length: number): number
	if length <= 0 then
		return if t >= from then 1 else 0
	end
	return math.clamp((t - from) / length, 0, 1)
end

local function inOutSine(x: number): number
	return -(math.cos(math.pi * x) - 1) / 2
end

--[[ When each shot starts, and when the last one ends. ]]
function StoryTimeline.starts(c: Config): ({ number }, number)
	local starts = {}
	local at = c.lead
	for i, shot in c.shots do
		starts[i] = at
		at += shot.length
	end
	return starts, at
end

--[[ When the black has fully come down (and SKIP can no longer shorten it). ]]
function StoryTimeline.blackAt(c: Config, skippedAt: number?): number
	local _, ends = StoryTimeline.starts(c)
	local natural = ends
	if skippedAt and skippedAt + c.skipFade < natural then
		return skippedAt + c.skipFade
	end
	return natural
end

--[[ How long the whole cutscene lasts, black hold included. ]]
function StoryTimeline.length(c: Config, skippedAt: number?): number
	return StoryTimeline.blackAt(c, skippedAt) + c.blackHold
end

--[[ The frame showing `into` seconds into a shot. ]]
function StoryTimeline.frameAt(shot: Shot, into: number): string
	local frames = shot.frames
	local total = 0
	for _, frame in frames do
		total += frame.hold
	end
	local at = into
	if shot.loop and total > 0 then
		at = at % total
	end
	for _, frame in frames do
		if at < frame.hold then
			return frame.picture
		end
		at -= frame.hold
	end
	return frames[#frames].picture
end

function StoryTimeline.pose(c: Config, t: number, skippedAt: number?): Pose
	local starts, ends = StoryTimeline.starts(c)
	local blackAt = StoryTimeline.blackAt(c, skippedAt)

	local index: number? = nil
	for i = #c.shots, 1, -1 do
		if t >= starts[i] then
			index = i
			break
		end
	end
	if t >= ends then
		index = nil
	end

	local black = 0
	if t < c.lead then
		black = 1
	end
	-- the natural fade at the end, or SKIP's, whichever comes first
	local naturalFade = span(t, ends - c.fadeOut, c.fadeOut)
	local skipFade = if skippedAt then span(t, skippedAt, c.skipFade) else 0
	black = math.max(black, naturalFade, skipFade)
	if t >= blackAt then
		black = 1
		index = nil
	end

	local pan, zoom, shake = 0.5, 1, Vector2.zero
	local picture: string? = nil
	if index then
		local shot = c.shots[index]
		local into = t - starts[index]
		local progress = inOutSine(span(into, 0, shot.length))
		picture = StoryTimeline.frameAt(shot, into)
		if shot.pan then
			pan = shot.pan.from + (shot.pan.to - shot.pan.from) * progress
		end
		if shot.zoom then
			zoom = shot.zoom.from + (shot.zoom.to - shot.zoom.from) * progress
		end
		if shot.fadeIn then
			black = math.max(black, 1 - span(into, 0, shot.fadeIn))
		end
		local s = shot.shake
		if s and into >= s.at and into < s.at + s.time then
			local left = 1 - (into - s.at) / s.time
			-- a fast, deterministic wobble, so a held capture is repeatable
			local x = math.sin(into * 71) + math.sin(into * 43) * 0.5
			local y = math.cos(into * 59) + math.sin(into * 37) * 0.5
			shake = Vector2.new(x, y) * (s.size * left / 1.5)
		end
	end

	return {
		shot = index,
		picture = picture,
		pan = pan,
		zoom = zoom,
		shake = shake,
		black = black,
		done = t >= blackAt + c.blackHold,
	}
end

return StoryTimeline
