--!strict
--[[
	Which frame of the story cutscene shows at a moment (`Config/Story`): pure,
	so `UI/StoryCutscene` shows everything from one clock and
	`tests/StoryTimeline.spec` pins its order and its end.

	One frame at a time (owner, 2026-10-25): black for `lead`, then every
	shot's frames in order, each once for its `hold`, then black for
	`blackHold` before the run is let go. SKIP cuts to black at once. No zoom,
	pan, shake, fade or looping.

	`t` is seconds since the cutscene started; `skippedAt` is when SKIP was
	pressed, on the same clock, or nil.
]]

local StoryTimeline = {}

export type Frame = { picture: string, hold: number }

export type Shot = { name: string, frames: { Frame } }

export type Config = {
	lead: number,
	shots: { Shot },
	blackHold: number,
}

export type Pose = {
	--[[ The shot showing (its index) and its frame; nil on black. ]]
	shot: number?,
	picture: string?,
	--[[ The black has held: let the run go and tear down. ]]
	done: boolean,
}

--[[ How long a shot lasts: its frames' holds. ]]
function StoryTimeline.lengthOf(shot: Shot): number
	local total = 0
	for _, frame in shot.frames do
		total += frame.hold
	end
	return total
end

--[[ When each shot starts, and when the last one ends. ]]
function StoryTimeline.starts(c: Config): ({ number }, number)
	local starts = {}
	local at = c.lead
	for i, shot in c.shots do
		starts[i] = at
		at += StoryTimeline.lengthOf(shot)
	end
	return starts, at
end

--[[ When the screen goes black at the end: after the last frame, or on SKIP. ]]
function StoryTimeline.blackAt(c: Config, skippedAt: number?): number
	local _, ends = StoryTimeline.starts(c)
	if skippedAt and skippedAt < ends then
		return skippedAt
	end
	return ends
end

--[[ How long the whole cutscene lasts, the black at the end included. ]]
function StoryTimeline.length(c: Config, skippedAt: number?): number
	return StoryTimeline.blackAt(c, skippedAt) + c.blackHold
end

function StoryTimeline.pose(c: Config, t: number, skippedAt: number?): Pose
	local starts = StoryTimeline.starts(c)
	local blackAt = StoryTimeline.blackAt(c, skippedAt)
	local done = t >= blackAt + c.blackHold
	if t < c.lead or t >= blackAt then
		return { shot = nil, picture = nil, done = done }
	end
	for i = #c.shots, 1, -1 do
		if t >= starts[i] then
			local at = t - starts[i]
			local frames = c.shots[i].frames
			for _, frame in frames do
				if at < frame.hold then
					return { shot = i, picture = frame.picture, done = done }
				end
				at -= frame.hold
			end
			return { shot = i, picture = frames[#frames].picture, done = done }
		end
	end
	return { shot = nil, picture = nil, done = done }
end

return StoryTimeline
