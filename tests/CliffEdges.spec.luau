--!strict
--[[
	The Windswept Cliffs' edges (`Shared/Util/CliffEdges`; owner,
	2026-11-26: "Fall: 12% health"). A push that carries a player over a wall
	line or into a void strip is a fall, landed back on the floor they came
	from; a push that stays on the floor, presses them against an edge, or
	meets cover first is not.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CliffEdges = require(ReplicatedStorage.Shared.Util.CliffEdges)
local TestRunner = require(script.Parent.TestRunner)

local HALF = Vector2.new(17.5, 29)
--[[ A gap across the middle, as Twin Peaks has, with a bridge 4 wide left
     out of it on the centre line. ]]
local GAP: { CliffEdges.Void } = {
	{ centre = Vector2.new(-10.75, 0), halfExtents = Vector2.new(6.75, 2) },
	{ centre = Vector2.new(10.75, 0), halfExtents = Vector2.new(6.75, 2) },
}

return function(t: TestRunner.Helper)
	t.test("a push over the wall line is a fall, landed back on the floor", function()
		local at, landing = CliffEdges.crossing(Vector2.new(14, 10), Vector2.xAxis, 8, HALF, {}, 1)
		t.notNil(at, "over the east edge")
		if landing then
			t.isTrue(landing.X < HALF.X, "landed inside the room")
			t.isTrue(landing.X >= 14 - 1e-6, "no further back than it started")
		end
	end)

	t.test("a push that stays on the floor, or only presses on an edge, is not", function()
		t.isNil((CliffEdges.crossing(Vector2.new(0, 10), Vector2.xAxis, 8, HALF, {}, 1)))
		t.isNil((CliffEdges.crossing(Vector2.new(15, 10), Vector2.xAxis, 3, HALF, {}, 1)))
	end)

	t.test("into the gap is a fall; along the bridge is not", function()
		t.notNil((CliffEdges.crossing(Vector2.new(-10, 5), -Vector2.yAxis, 8, HALF, GAP, 1)))
		t.isNil((CliffEdges.crossing(Vector2.new(0, 5), -Vector2.yAxis, 10, HALF, GAP, 1)))
	end)

	t.test("cover in the way stops the push before the edge", function()
		local rock = function(point: Vector2): boolean
			return math.abs(point.X - 16) < 1 and math.abs(point.Y - 10) < 1
		end
		t.isNil((CliffEdges.crossing(Vector2.new(13, 10), Vector2.xAxis, 8, HALF, {}, 1, rock)))
	end)

	t.test("a fall costs a modest share and a moment's grace", function()
		t.isTrue(CliffEdges.share > 0.05 and CliffEdges.share <= 0.15)
		t.isTrue(CliffEdges.grace >= 0.5 and CliffEdges.grace <= 2)
	end)
end
