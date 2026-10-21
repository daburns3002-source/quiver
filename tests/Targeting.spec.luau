--!strict
--[[
	Target selection.

	Small, but it decides what the archer shoots at, and it carries a design
	rule that is easy to "fix" by accident: it picks purely by distance and
	never checks line of sight. Cover is a damage penalty, not a safety net.
	A test that asserts the nearest-but-blocked enemy still wins is there to
	make removing that rule a visible decision rather than a tidy-up.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Targeting = require(ServerScriptService.Server.Combat.Targeting)
local TestRunner = require(script.Parent.TestRunner)

--[[ Targeting takes a Model → position map, so the keys only need identity. ]]
local function fakeEnemies(positions: { Vector3 }): { [Model]: Vector3 }
	local map: { [Model]: Vector3 } = {}

	for _, position in positions do
		map[Instance.new("Model")] = position
	end

	return map
end

return function(t: TestRunner.Helper)
	t.test("nothing in range returns nil", function()
		t.isNil(Targeting.nearest(Vector3.zero, {}, 60))
	end)

	t.test("the nearest candidate wins", function()
		local map = fakeEnemies({
			Vector3.new(0, 0, 50),
			Vector3.new(0, 0, 10),
			Vector3.new(0, 0, 30),
		})

		local target = Targeting.nearest(Vector3.zero, map, 60)

		t.notNil(target)
		t.near((target :: any).distance, 10, 1e-6)
	end)

	t.test("candidates beyond the range are ignored", function()
		local map = fakeEnemies({ Vector3.new(0, 0, 80) })
		t.isNil(Targeting.nearest(Vector3.zero, map, 60))
	end)

	t.test("a candidate exactly at the range still counts", function()
		local map = fakeEnemies({ Vector3.new(0, 0, 60) })
		t.notNil(Targeting.nearest(Vector3.zero, map, 60))
	end)

	t.test("the target carries back its own position", function()
		local map = fakeEnemies({ Vector3.new(3, 0, 4) })
		local target = Targeting.nearest(Vector3.zero, map, 60)

		t.notNil(target)
		t.near((target :: any).position.X, 3, 1e-6)
		t.near((target :: any).distance, 5, 1e-6)
	end)

	--[[
		Deliberate: `Targeting` has no notion of obstacles and must not grow
		one. If this test ever fails because someone added a line-of-sight
		check, the asymmetry in RESEARCH-archero.md §1 has been broken.
	]]
	t.test("distance decides even when something would block the shot", function()
		local map = fakeEnemies({
			-- Directly behind the centre pillar from the origin.
			Vector3.new(0, 0, -10),
			-- Further away but in the open.
			Vector3.new(40, 0, 0),
		})

		local target = Targeting.nearest(Vector3.zero, map, 60)

		t.notNil(target)
		t.near((target :: any).distance, 10, 1e-6, "the blocked but nearer enemy must win")
	end)

	t.test("flatDirection drops the vertical component", function()
		local direction = Targeting.flatDirection(Vector3.new(0, 10, 0), Vector3.new(0, -40, 20))

		t.notNil(direction)
		t.near((direction :: Vector3).Y, 0, 1e-9)
		t.near((direction :: Vector3).Z, 1, 1e-6)
	end)

	t.test("flatDirection is normalised", function()
		local direction = Targeting.flatDirection(Vector3.zero, Vector3.new(30, 0, 40))

		t.notNil(direction)
		t.near((direction :: Vector3).Magnitude, 1, 1e-6)
	end)

	t.test("flatDirection returns nil for coincident points", function()
		t.isNil(Targeting.flatDirection(Vector3.new(5, 0, 5), Vector3.new(5, 90, 5)))
	end)
end
