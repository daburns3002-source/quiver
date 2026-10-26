--!strict
--[[
	The order the stages are played in (`Balance.campaign`,
	`Util/CurrentStage.nextAfter`): the Mossy Glade run first, Thornwood
	after its Victory, and the last one again once the campaign is through.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the first run is the campaign's first stage", function()
		t.equal(Balance.stage, Balance.campaign[1])
	end)

	t.test("every campaign stage exists and is a Rooms stage ending in a boss alone", function()
		for _, index in Balance.campaign do
			local stage = Balance.Stages[index]
			t.notNil(stage, `stage {index}`)
			local rooms = stage.rooms or {}
			t.isTrue(#rooms > 0, `{stage.name} has rooms`)
			local last = Balance.Rooms[rooms[#rooms]]
			t.isTrue(last.roster[1].boss ~= nil, `{stage.name} ends in its boss`)
		end
	end)

	t.test("winning moves along the campaign, and the last is played again", function()
		local campaign = { 5, 4 }
		t.equal(CurrentStage.nextAfter(campaign, 5), 4)
		t.equal(CurrentStage.nextAfter(campaign, 4), 4)
		-- a stage outside it is played again
		t.equal(CurrentStage.nextAfter(campaign, 3), 3)
	end)

	t.test("Mossy Glade, then Thornwood", function()
		t.equal(Balance.Stages[Balance.campaign[1]].area, "MossyGlade")
		t.equal(Balance.Stages[Balance.campaign[2]].area, "Thornwood")
	end)
end
