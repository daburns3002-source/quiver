--!strict
--[[
	The melee swing's box (`Shared/Combat/SwingBox`), at its edges. Melee is
	new, and geometry is where this project's bugs live: a box a stud too
	short swings at slimes it never touches, one that reaches behind hits
	what the player turned away from. Asserted against the Warden's own
	numbers, so retuning them keeps the tests honest.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local SwingBox = require(ReplicatedStorage.Shared.Combat.SwingBox)
local TestRunner = require(script.Parent.TestRunner)

local swing = Classes.Warden.swing :: Classes.Swing
local W, D = swing.width, swing.depth
local FROM = Vector3.new(3, 0, -2)
local NORTH = Vector3.new(0, 0, -1)
local E = 0.05

local function at(across: number, ahead: number): Vector3
	-- Facing north (-Z), "across" is +X.
	return FROM + Vector3.new(across, 0, -ahead)
end

return function(t: TestRunner.Helper)
	t.test("a body dead ahead is struck", function()
		t.isTrue(SwingBox.contains(FROM, NORTH, W, D, at(0, D / 2), 1))
	end)

	t.test("reach ends at the box's depth plus the body's half width", function()
		local half = 1.5
		t.isTrue(SwingBox.contains(FROM, NORTH, W, D, at(0, D + half - E), half))
		t.isTrue(not SwingBox.contains(FROM, NORTH, W, D, at(0, D + half + E), half))
	end)

	t.test("the sides end at half the width plus the body's half width", function()
		local half = 1
		for _, sign in { -1, 1 } do
			t.isTrue(SwingBox.contains(FROM, NORTH, W, D, at(sign * (W / 2 + half - E), 2), half))
			t.isTrue(
				not SwingBox.contains(FROM, NORTH, W, D, at(sign * (W / 2 + half + E), 2), half)
			)
		end
	end)

	t.test("a wide body counts by its width, not its centre", function()
		local x = W / 2 + 1.5
		t.isTrue(not SwingBox.contains(FROM, NORTH, W, D, at(x, 3), 1))
		t.isTrue(SwingBox.contains(FROM, NORTH, W, D, at(x, 3), 2))
	end)

	t.test("a body pressed against the swinger is struck; one behind is not", function()
		local half = 1
		t.isTrue(SwingBox.contains(FROM, NORTH, W, D, at(0, -half + E), half))
		t.isTrue(not SwingBox.contains(FROM, NORTH, W, D, at(0, -half - E), half))
	end)

	t.test("height never decides a hit", function()
		local raised = at(0, D / 2) + Vector3.new(0, 30, 0)
		t.isTrue(SwingBox.contains(FROM + Vector3.new(0, -4, 0), NORTH, W, D, raised, 1))
	end)

	t.test("the box turns with the swing", function()
		local angle = math.rad(37)
		local direction = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local inside = FROM + direction * (D - 1)
		local behind = FROM - direction * 3
		t.isTrue(SwingBox.contains(FROM, direction, W, D, inside, 0.5))
		t.isTrue(not SwingBox.contains(FROM, direction, W, D, behind, 0.5))
		-- The same body, but the swing facing the other way.
		t.isTrue(not SwingBox.contains(FROM, -direction, W, D, inside, 0.5))
	end)

	t.test("a swing with no direction strikes nothing", function()
		t.isTrue(not SwingBox.contains(FROM, Vector3.zero, W, D, at(0, 1), 1))
	end)
end
