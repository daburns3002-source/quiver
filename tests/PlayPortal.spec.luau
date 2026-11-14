--!strict
--[[
	What the lobby's PLAY button offers (`Shared/Util/PlayPortal`): the areas
	on its screen (every portal with levels, a locked one shut with what
	opens it), the one marked as next (the first open area with a level not
	yet beaten, Endless passed over, the last played once all are beaten),
	and who a start takes along. Made-up stages and portals.
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
		t.equal(PlayPortal.pick(portals, stages, {}, nil, 9), 1)
		t.equal(PlayPortal.pick(portals, stages, nil, nil, 9), 1)
	end)
	t.test("the area being played until all of it is beaten", function()
		t.equal(PlayPortal.pick(portals, stages, { ["1-1"] = true }, nil, 9), 1)
	end)
	t.test("then the next area", function()
		t.equal(PlayPortal.pick(portals, stages, { ["1-1"] = true, ["1-2"] = true }, nil, 9), 2)
	end)
	t.test("never Endless; the last area once all are beaten", function()
		local all = { ["1-1"] = true, ["1-2"] = true, ["2-1"] = true }
		t.equal(PlayPortal.pick(portals, stages, all, nil, 9), 2)
	end)
	t.test("a closed portal is passed over", function()
		local gated: { PlayPortal.Portal } =
			{ { levels = { 3 }, requires = "1-2" }, { levels = { 1 } } }
		t.equal(PlayPortal.pick(gated, stages, {}, nil, nil), 2)
	end)
	t.test("an area that saves no level is behind you once its boss is", function()
		local single: { [number]: LevelUnlocks.Stage } = {
			[1] = { name = "A", mode = "Rooms", rooms = { 1 }, area = "First" },
			[2] = { name = "B", mode = "Rooms", rooms = { 1 }, area = "Second" },
		}
		local two: { PlayPortal.Portal } = { { levels = { 1 } }, { levels = { 2 } } }
		t.equal(PlayPortal.pick(two, single, {}, {}, nil), 1)
		t.equal(PlayPortal.pick(two, single, {}, { First = true }, nil), 2)
	end)
	t.test("at launch a locked area waits its turn", function()
		local locked: { PlayPortal.Portal } = {
			{ levels = { 1, 2 } },
			{ levels = { 3 }, atLaunch = { boss = "First" } },
		}
		local all = { ["1-1"] = true, ["1-2"] = true }
		-- locks on: the second area is shut until the first's boss falls
		t.equal(PlayPortal.pick(locked, stages, all, {}, nil, true), 1)
		t.equal(PlayPortal.pick(locked, stages, all, { First = true }, nil, true), 2)
		-- locks off: as open as it is in playtest
		t.equal(PlayPortal.pick(locked, stages, all, {}, nil, false), 2)
	end)
	t.test("the screen lists every portal with levels, in order", function()
		local list = PlayPortal.areas(portals, stages, { ["1-1"] = true }, nil, 9)
		t.equal(#list, 3)
		t.equal(list[1].index, 1)
		t.equal(list[2].index, 2)
		-- the arch with no levels is not an area to choose
		t.equal(list[3].index, 4)
		t.equal(list[1].levels, 2)
		t.equal(list[1].beaten, 1)
		t.isTrue(list[1].open and list[2].open and list[3].open, "an ungated area was shut")
		t.isTrue(not list[1].mode and list[3].mode, "only Endless is a mode")
	end)
	t.test("exactly one area is marked, the frontier", function()
		for _, beaten in { {}, { ["1-1"] = true }, { ["1-1"] = true, ["1-2"] = true } } do
			local marked = 0
			for _, area in PlayPortal.areas(portals, stages, beaten, nil, 9) do
				if area.suggested then
					marked += 1
					t.equal(area.index, PlayPortal.pick(portals, stages, beaten, nil, 9))
				end
			end
			t.equal(marked, 1)
		end
	end)
	t.test("a locked area is listed shut, with what opens it", function()
		local locked: { PlayPortal.Portal } = {
			{ name = "First", levels = { 1, 2 } },
			{ name = "Second", levels = { 3 }, atLaunch = { requires = "1-2" } },
			{ name = "Third", levels = { 9 }, atLaunch = { boss = "Second" } },
		}
		local list = PlayPortal.areas(locked, stages, { ["1-1"] = true }, {}, nil, true)
		t.isTrue(list[1].open, "the first area was shut")
		t.equal(list[1].words, "")
		t.isTrue(not list[2].open, "an area opened before its level was beaten")
		t.equal(list[2].words, "BEAT 1-2")
		t.isTrue(not list[3].open, "an area opened before its boss was beaten")
		t.equal(list[3].words, "BEAT SECOND")
		t.isTrue(not list[2].suggested and not list[3].suggested, "a shut area was marked")
		-- and the screen goes on to an open one only
		t.equal((PlayPortal.enter(list, 1) :: PlayPortal.Area).name, "First")
		t.isTrue(PlayPortal.enter(list, 2) == nil, "went on into a shut area")
		t.isTrue(PlayPortal.enter(list, 7) == nil, "went on into an area not listed")
		-- beaten, they open
		local later = PlayPortal.areas(
			locked,
			stages,
			{ ["1-1"] = true, ["1-2"] = true },
			{ Second = true },
			nil,
			true
		)
		t.isTrue(later[2].open and later[3].open, "a beaten gate stayed shut")
		-- and with the launch switch off, as in playtest, nothing waits
		local playtest = PlayPortal.areas(locked, stages, {}, {}, nil, false)
		t.isTrue(playtest[2].open and playtest[3].open, "playtest locked an area")
	end)
	t.test("a player with no profile sees the gated areas shut", function()
		local gated: { PlayPortal.Portal } =
			{ { levels = { 1 } }, { levels = { 3 }, requires = "1-2" } }
		local list = PlayPortal.areas(gated, stages, nil, nil, nil)
		t.isTrue(list[1].open and not list[2].open, "a gate opened with no profile")
		t.equal(list[2].words, "BEAT 1-2")
	end)
	t.test("a start from the screen goes alone; one at the portal takes the portal", function()
		t.isTrue(PlayPortal.alone(nil, 2), "a start from across the lobby took a party")
		t.isTrue(PlayPortal.alone(1, 2), "a start took the players of another portal")
		t.isTrue(not PlayPortal.alone(2, 2), "a start at the portal left its party behind")
	end)
end
