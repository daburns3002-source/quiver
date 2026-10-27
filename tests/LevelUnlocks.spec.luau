--!strict
--[[
	Which levels are open (`Shared/Util/LevelUnlocks`): the first always,
	every other once the one before is beaten; where NEXT LEVEL goes; and the
	tutorial owed until 1-1 is beaten (owner, 2026-10-26). Made-up stages, so
	retuning the game's own never fails it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local LevelUnlocks = require(ReplicatedStorage.Shared.Util.LevelUnlocks)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local TestRunner = require(script.Parent.TestRunner)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local function stage(level: string?): LevelUnlocks.Stage
	return { name = level or "Old", mode = "Rooms", rooms = { 1 }, level = level }
end

-- three levels at 11, 12, 13; 20 has no level key
local stages: { [number]: LevelUnlocks.Stage } = {
	[11] = stage("1-1"),
	[12] = stage("1-2"),
	[13] = stage("1-3"),
	[20] = stage(nil),
}
local levels = { 11, 12, 13 }

return function(t: TestRunner.Helper)
	t.test("with nothing beaten only the first is open", function()
		local none: { LevelUnlocks.Beaten? } = { {}, nil }
		for i = 1, 2 do
			local beaten = none[i]
			t.isTrue(LevelUnlocks.isUnlocked(levels, stages, beaten, 1))
			t.isFalse(LevelUnlocks.isUnlocked(levels, stages, beaten, 2))
			t.isFalse(LevelUnlocks.isUnlocked(levels, stages, beaten, 3))
		end
	end)

	t.test("beating a level opens the next, and only the next", function()
		local beaten = { ["1-1"] = true }
		t.isTrue(LevelUnlocks.isUnlocked(levels, stages, beaten, 2))
		t.isFalse(LevelUnlocks.isUnlocked(levels, stages, beaten, 3))
		beaten["1-2"] = true
		t.isTrue(LevelUnlocks.isUnlocked(levels, stages, beaten, 3))
	end)

	t.test("a later level beaten does not open one whose predecessor is not", function()
		local beaten = { ["1-2"] = true }
		t.isFalse(LevelUnlocks.isUnlocked(levels, stages, beaten, 2))
		t.isTrue(LevelUnlocks.isUnlocked(levels, stages, beaten, 3))
	end)

	t.test("positions outside the list, or not whole, are never open", function()
		local beaten = { ["1-1"] = true, ["1-2"] = true, ["1-3"] = true }
		for _, position in { 0, -1, 4, 1.5, 0 / 0 } do
			t.isFalse(LevelUnlocks.isUnlocked(levels, stages, beaten, position), `{position}`)
		end
		t.isFalse(LevelUnlocks.isUnlocked({ 99 }, stages, beaten, 1), "a missing stage")
	end)

	t.test("a stage with no level key gates nothing", function()
		t.isTrue(LevelUnlocks.isUnlocked({ 20, 11 }, stages, {}, 2))
		t.isFalse(LevelUnlocks.isBeaten(stages[20], { Old = true }))
	end)

	t.test("the screen picks the first open level not beaten", function()
		t.equal(LevelUnlocks.suggested(levels, stages, {}), 1)
		t.equal(LevelUnlocks.suggested(levels, stages, { ["1-1"] = true }), 2)
		local all = { ["1-1"] = true, ["1-2"] = true, ["1-3"] = true }
		t.equal(LevelUnlocks.suggested(levels, stages, all), 3)
	end)

	t.test("NEXT LEVEL is the next in the list, the lobby after the last", function()
		local after, found = LevelUnlocks.nextAfter(levels, 11)
		t.equal(after, 12)
		t.isTrue(found)
		after, found = LevelUnlocks.nextAfter(levels, 13)
		t.isNil(after)
		t.isTrue(found)
		after, found = LevelUnlocks.nextAfter(levels, 20)
		t.isNil(after)
		t.isFalse(found)
	end)

	t.test("the tutorial is owed until its level is beaten", function()
		t.isTrue(LevelUnlocks.tutorialOwed(nil, "1-1"), "a profile not loaded")
		t.isTrue(LevelUnlocks.tutorialOwed({}, "1-1"))
		t.isTrue(LevelUnlocks.tutorialOwed({ ["1-2"] = true }, "1-1"))
		t.isFalse(LevelUnlocks.tutorialOwed({ ["1-1"] = true }, "1-1"))
	end)

	t.test("the tutorial waits on the Mossy Glade portal's first level", function()
		local first = Balance.Stages[(LobbyConfig.portals[1].levels :: { number })[1]]
		t.equal(first.level, Tutorial.untilBeaten)
	end)

	t.test("every level key is unique across the game", function()
		local seen: { [string]: number } = {}
		for index, config in Balance.Stages do
			local key = config.level
			if key then
				t.isNil(seen[key], `{key} is stage {seen[key]} and {index}`)
				seen[key] = index
			end
		end
	end)
end
