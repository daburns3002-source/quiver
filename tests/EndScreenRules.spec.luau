--!strict
--[[
	What the end screens show (`Util/EndScreenRules`), from the
	first-five-minutes playtest of 2026-11-12: the tutorial's Victory showed
	a "CHEST x0" row for a run that paid no chest, and a NEXT LEVEL button
	that went to the lobby. A row is only there for something to put in it,
	and a button says where it goes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EndScreenRules = require(ReplicatedStorage.Shared.Util.EndScreenRules)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the chest row is only there for something to put in it", function()
		t.isFalse(EndScreenRules.chestRow({}), "a run that paid coins alone has no row")
		t.isFalse(EndScreenRules.chestRow({ chests = 0 }), "nor does a count of none")
		t.isTrue(EndScreenRules.chestRow({ chests = 1 }), "a chest has its row")
		t.isTrue(
			EndScreenRules.chestRow({ egg = { key = "MossyEgg", pet = "Wilf", new = true } }),
			"a first clear's free egg has its row"
		)
		t.isTrue(EndScreenRules.chestRow({ item = "SlimeCrown" }), "a boss's item has its row")
	end)

	t.test("the tutorial's Victory does not promise a next level", function()
		local tutorial = EndScreenRules.buttonWords(true, Balance.tutorialStage)
		t.isTrue(tutorial ~= "", "the button says something")
		for index, stage in Balance.Stages do
			if index ~= Balance.tutorialStage and stage.level then
				t.isTrue(
					EndScreenRules.buttonWords(true, index) ~= tutorial,
					`{stage.name}: a level's Victory goes on to a level`
				)
			end
		end
		t.isTrue(
			EndScreenRules.buttonWords(false, Balance.tutorialStage) ~= tutorial,
			"a Defeat in the tutorial still tries again"
		)
	end)

	t.test("the end screen names a level as its portal does, never by its index", function()
		t.equal(EndScreenRules.levelTab(Balance.tutorialStage), "TUTORIAL")
		for _, portal in LobbyConfig.portals do
			local levels: { number } = portal.levels or {}
			for _, stage in levels do
				local config = Balance.Stages[stage]
				local tail = EndScreenRules.levelTab(stage):match("^LEVEL (.+)$")
				local name = (portal.name or "?") .. " " .. stage
				t.isTrue(tail ~= nil, name)
				if config and config.level then
					t.equal(tail, config.level, name)
				else
					local n = tonumber(tail)
					t.isTrue(
						n ~= nil and n >= 1 and n <= #levels,
						name .. " shows " .. tostring(tail)
					)
				end
			end
		end
	end)
end
