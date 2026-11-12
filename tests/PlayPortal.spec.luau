--!strict
--[[
	Where the lobby's PLAY button goes (`Shared/Util/PlayPortal`): the first
	open portal with a level not yet beaten, Endless passed over, the last
	played once all are beaten. Made-up stages and portals.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelUnlocks = require(ReplicatedStorage.Shared.Util.LevelUnlocks)
local PlayPortal = require(ReplicatedStorage.Shared.Util.PlayPortal)
local TestRunner = require(script.Parent.TestRunner)

local function stage(level: string): LevelUnlocks.Stage
	return { name = level, mode = "Rooms", rooms = { 1 }, level = level }
end

local stages: { [number]: LevelUnlocks.Stage } = {
	[1] = stage("1-1"),
	[2] = stage("1-2"),
	[3] = stage("2-1"),
	[9] = stage("E"),
}
local portals: { PlayPortal.Portal } = {
	{ levels = { 1, 2 } },
	{ levels = { 3 } },
	{},
	{ levels = { 9 } },
}

return function(t: TestRunner.Helper)
	t.test("a new player goes to the first area", function()
		t.equal(PlayPortal.pick(portals, stages, {}, 9), 1)
		t.equal(PlayPortal.pick(portals, stages, nil, 9), 1)
	end)
	t.test("the area being played until all of it is beaten", function()
		t.equal(PlayPortal.pick(portals, stages, { ["1-1"] = true }, 9), 1)
	end)
	t.test("then the next area", function()
		t.equal(PlayPortal.pick(portals, stages, { ["1-1"] = true, ["1-2"] = true }, 9), 2)
	end)
	t.test("never Endless; the last area once all are beaten", function()
		local all = { ["1-1"] = true, ["1-2"] = true, ["2-1"] = true }
		t.equal(PlayPortal.pick(portals, stages, all, 9), 2)
	end)
	t.test("a closed portal is passed over", function()
		local gated: { PlayPortal.Portal } =
			{ { levels = { 3 }, requires = "1-2" }, { levels = { 1 } } }
		t.equal(PlayPortal.pick(gated, stages, {}, nil), 2)
	end)
end
