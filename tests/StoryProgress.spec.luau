--!strict
--[[
	The leaderboard's score (`Shared/Util/StoryProgress`): earlier stages'
	rooms plus this stage's cleared ones, nothing for a stage outside the
	campaign, and back again into the area and room the board prints.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local StoryProgress = require(ReplicatedStorage.Shared.Util.StoryProgress)
local TestRunner = require(script.Parent.TestRunner)

local function rooms(count: number): { number }
	local list = {}
	for index = 1, count do
		table.insert(list, index)
	end
	return list
end

-- stage 5 then stage 4, twenty rooms each, as the game has it; 2 is outside
local stages: { [number]: StoryProgress.Stage } = {
	[2] = { name = "Waves", mode = "Waves", waves = 30 },
	[4] = { name = "Level 2", mode = "Rooms", rooms = rooms(20) },
	[5] = { name = "Mossy Glade Run", mode = "Rooms", rooms = rooms(20) },
}
local campaign = { 5, 4 }
local names = { [5] = "Mossy Glade", [4] = "Thornwood" }

return function(t: TestRunner.Helper)
	t.test("the first stage's rooms count from nought", function()
		t.equal(StoryProgress.score(campaign, stages, 5, 0), 0)
		t.equal(StoryProgress.score(campaign, stages, 5, 7), 7)
		t.equal(StoryProgress.score(campaign, stages, 5, 20), 20)
	end)

	t.test("a later stage adds every room before it", function()
		t.equal(StoryProgress.score(campaign, stages, 4, 1), 21)
		t.equal(StoryProgress.score(campaign, stages, 4, 12), 32)
		t.equal(StoryProgress.score(campaign, stages, 4, 20), 40)
	end)

	t.test("rooms cleared are held within the stage", function()
		t.equal(StoryProgress.score(campaign, stages, 4, 99), 40)
		t.equal(StoryProgress.score(campaign, stages, 4, -3), 20)
	end)

	t.test("a stage outside the campaign scores nothing", function()
		t.isNil(StoryProgress.score(campaign, stages, 2, 10))
		t.isNil(StoryProgress.score(campaign, stages, 9, 1))
	end)

	t.test("a score reads back as its area and room", function()
		local d = StoryProgress.describe(32, campaign, stages, names)
		t.equal(d.area, "Thornwood")
		t.equal(d.room, 12)
		t.equal(d.total, 20)
		t.isFalse(d.complete)

		d = StoryProgress.describe(7, campaign, stages, names)
		t.equal(d.area, "Mossy Glade")
		t.equal(d.room, 7)
	end)

	t.test("a stage's end reads as that stage finished", function()
		local d = StoryProgress.describe(20, campaign, stages, names)
		t.equal(d.area, "Mossy Glade")
		t.equal(d.room, 20)
		t.equal(d.total, 20)
		t.isFalse(d.complete)
	end)

	t.test("the whole campaign reads as complete, past it too", function()
		for _, score in { 40, 55 } do
			local d = StoryProgress.describe(score, campaign, stages, names)
			t.equal(d.area, "Thornwood")
			t.equal(d.room, 20)
			t.isTrue(d.complete)
		end
	end)

	t.test("a stage without an area name shows its own", function()
		local d = StoryProgress.describe(3, campaign, stages, {})
		t.equal(d.area, "Mossy Glade Run")
	end)

	t.test("every score of the game's own campaign round-trips", function()
		local best = StoryProgress.best(Balance.campaign, Balance.Stages)
		t.isTrue(best > 0, "the campaign has rooms")
		for position, index in Balance.campaign do
			local stage = Balance.Stages[index]
			local count = if stage.rooms then #stage.rooms else stage.waves or 0
			for cleared = 1, count do
				local score = StoryProgress.score(Balance.campaign, Balance.Stages, index, cleared)
				t.notNil(score, `stage {index}`)
				local d =
					StoryProgress.describe(score :: number, Balance.campaign, Balance.Stages, {})
				t.equal(d.area, stage.name, `stage {index} room {cleared}`)
				t.equal(d.room, cleared, `stage {index} room {cleared}`)
				t.equal(d.complete, position == #Balance.campaign and cleared == count)
			end
		end
	end)
end
