--!strict
--[[
	The story beats' rules (`Config/StoryBeats`), pure so
	`tests/StoryBeatRules.spec` pins them: which beat is owed after a run,
	and where a still's picture sits in its window at a moment of its move.
]]

local StoryBeats = require(script.Parent.Parent.Config.StoryBeats)

local StoryBeatRules = {}

--[[ Whether `area`'s beat is owed: it has one, its boss is beaten, and the
     player has not watched it. ]]
function StoryBeatRules.due(
	area: string?,
	bossesBeaten: { [string]: boolean }?,
	storySeen: { [string]: boolean }?
): boolean
	if not area or not StoryBeats.beats[area] then
		return false
	end
	return (bossesBeaten or {})[area] == true and (storySeen or {})[area] ~= true
end

--[[ An area key `Remotes.StorySeen` may name: one with a beat. ]]
function StoryBeatRules.isArea(area: any): boolean
	return type(area) == "string" and StoryBeats.beats[area] ~= nil
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

--[[ Where a picture sits in its 16:9 window, as shares of the window:
     its top-left and its size. `k` runs 0..1 along the still's move. The
     picture always covers the window: its middle is kept far enough in
     that no edge shows. ]]
function StoryBeatRules.place(still: StoryBeats.Still, k: number): (Vector2, Vector2)
	local e = ease(k)
	local zoom = math.max(1, still.from.zoom + (still.to.zoom - still.from.zoom) * e)
	local half = 0.5 / zoom
	local x = math.clamp(still.from.x + (still.to.x - still.from.x) * e, half, 1 - half)
	local y = math.clamp(still.from.y + (still.to.y - still.from.y) * e, half, 1 - half)
	return Vector2.new(0.5 - x * zoom, 0.5 - y * zoom), Vector2.new(zoom, zoom)
end

return StoryBeatRules
