--!strict
--[[
	How far a player has come through the story (`Balance.campaign`), as one
	number the leaderboard can sort on (`Run/StoryLeaderboard`): every room of
	the campaign's earlier stages, plus the rooms cleared in this one. Mossy
	Glade's twenty then Thornwood's twenty, so 32 is Thornwood, 12 of 20.

	`describe` turns a score back into what the board prints: the area, and
	the room out of its stage's rooms. A score that lands exactly on a
	stage's end reads as that stage, finished (Mossy Glade 20/20), not as
	the next one at nought.

	Pure: the campaign, the stages and the area names are passed in, so
	`tests/StoryProgress.spec` pins it with made-up ones.
]]

-- for its types only: nothing here reads the game's own stages
local Balance = require(script.Parent.Parent.Config.Balance)

local StoryProgress = {}

--[[ A stage: this reads its `name` and how many rooms (or waves) it has. ]]
export type Stage = Balance.StageConfig

export type Description = {
	area: string,
	room: number,
	total: number,
	--[[ The whole campaign is through. ]]
	complete: boolean,
}

local function size(stage: Stage?): number
	if not stage then
		return 0
	end
	if stage.rooms then
		return #stage.rooms
	end
	return stage.waves or 0
end

--[[ The score for having cleared `roomsCleared` rooms of stage
     `stageIndex`, or nil when that stage is not in the campaign. ]]
function StoryProgress.score(
	campaign: { number },
	stages: { [number]: Stage },
	stageIndex: number,
	roomsCleared: number
): number?
	local before = 0
	for _, index in campaign do
		local rooms = size(stages[index])
		if index == stageIndex then
			return before + math.clamp(math.floor(roomsCleared), 0, rooms)
		end
		before += rooms
	end
	return nil
end

--[[ Every room of the campaign: the score of a player who has won it all. ]]
function StoryProgress.best(campaign: { number }, stages: { [number]: Stage }): number
	local sum = 0
	for _, index in campaign do
		sum += size(stages[index])
	end
	return sum
end

--[[ A score as the board prints it. `names` maps a stage index to its
     area's name; a stage without one shows its own `name`. ]]
function StoryProgress.describe(
	score: number,
	campaign: { number },
	stages: { [number]: Stage },
	names: { [number]: string }
): Description
	local left = math.max(math.floor(score), 0)
	local complete = left >= StoryProgress.best(campaign, stages)
	local last: Description = { area = "", room = 0, total = 0, complete = complete }
	for _, index in campaign do
		local stage = stages[index]
		local rooms = size(stage)
		local area = names[index] or (if stage then stage.name else "")
		if left <= rooms then
			return { area = area, room = left, total = rooms, complete = complete }
		end
		left -= rooms
		last = { area = area, room = rooms, total = rooms, complete = complete }
	end
	return last
end

return StoryProgress
