--!strict
--[[
	Where a melee blow lands (`Shared/Combat/SwingBox`), at its edges: an arc
	for the side-to-side blows, a circle in front for the slam. Geometry is
	where this project's bugs live: a shape a stud too short swings at
	slimes it never touches, one that reaches behind hits what the player
	turned away from. Asserted against the Warden's own numbers, so
	retuning them keeps the tests honest.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local SwingBox = require(ReplicatedStorage.Shared.Combat.SwingBox)
local TestRunner = require(script.Parent.TestRunner)

local swing = Classes.Warden.swing :: Classes.Swing
local BLOWS = #swing.damage
local ARC = SwingBox.shape(swing, 1, BLOWS, 1, 0)
local SLAM = SwingBox.shape(swing, BLOWS, BLOWS, 1, 0)
local FROM = Vector3.new(3, 0, -2)
local NORTH = Vector3.new(0, 0, -1)
local E = 0.05

--[[ A point `distance` out at `degrees` right of north. ]]
local function out(distance: number, degrees: number): Vector3
	local r = math.rad(degrees)
	return FROM + Vector3.new(math.sin(r), 0, -math.cos(r)) * distance
end

return function(t: TestRunner.Helper)
	t.test("the side-to-side blows are arcs and the last is a circle", function()
		t.equal(ARC.kind, "Arc")
		t.equal(SwingBox.shape(swing, 2, BLOWS, 1, 0).kind, "Arc")
		t.equal(SLAM.kind, "Circle")
	end)

	t.test("an arc's reach ends at its radius plus the body's half width", function()
		local half = 1.5
		t.isTrue(SwingBox.hits(ARC, FROM, NORTH, out(ARC.reach + half - E, 0), half))
		t.isTrue(not SwingBox.hits(ARC, FROM, NORTH, out(ARC.reach + half + E, 0), half))
	end)

	t.test("an arc's sides end at its angle", function()
		local edge = ARC.arc / 2
		for _, sign in { -1, 1 } do
			t.isTrue(SwingBox.hits(ARC, FROM, NORTH, out(6, sign * (edge - 1)), 0.01))
			t.isTrue(not SwingBox.hits(ARC, FROM, NORTH, out(6, sign * (edge + 3)), 0.01))
		end
	end)

	t.test("a body pressed against the swinger is struck; one behind is not", function()
		t.isTrue(SwingBox.hits(ARC, FROM, NORTH, out(0.5, 180), 1))
		t.isTrue(not SwingBox.hits(ARC, FROM, NORTH, out(4, 180), 1))
	end)

	t.test("the slam's circle is in front, and ends at its edge", function()
		local half = 1
		local centre = SLAM.ahead
		t.isTrue(SwingBox.hits(SLAM, FROM, NORTH, out(centre, 0), half))
		t.isTrue(SwingBox.hits(SLAM, FROM, NORTH, out(centre + SLAM.radius + half - E, 0), half))
		t.isTrue(
			not SwingBox.hits(SLAM, FROM, NORTH, out(centre + SLAM.radius + half + E, 0), half)
		)
		t.isTrue(not SwingBox.hits(SLAM, FROM, NORTH, out(3, 180), half))
	end)

	t.test("Cleave widens both and Long Reach carries both further", function()
		local arc = SwingBox.shape(swing, 1, BLOWS, 1.45, 4.5)
		local slam = SwingBox.shape(swing, BLOWS, BLOWS, 1.45, 4.5)
		t.isTrue(arc.arc > ARC.arc, "Cleave did not widen the arc")
		t.isTrue(arc.reach > ARC.reach, "Long Reach did not lengthen the arc")
		t.isTrue(slam.radius > SLAM.radius, "Cleave did not grow the slam")
		t.isTrue(slam.ahead > SLAM.ahead, "Long Reach did not carry the slam further")
		t.isTrue(
			SwingBox.shape(swing, 1, BLOWS, 50, 0).arc <= 360,
			"an arc wrapped past a full turn"
		)
	end)

	t.test("height never decides a hit", function()
		local raised = out(4, 0) + Vector3.new(0, 30, 0)
		t.isTrue(SwingBox.hits(ARC, FROM + Vector3.new(0, -4, 0), NORTH, raised, 1))
		t.isTrue(SwingBox.hits(SLAM, FROM, NORTH, out(SLAM.ahead, 0) + Vector3.new(0, 30, 0), 1))
	end)

	t.test("the shapes turn with the swing", function()
		local angle = math.rad(37)
		local direction = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local inside = FROM + direction * (ARC.reach - 1)
		t.isTrue(SwingBox.hits(ARC, FROM, direction, inside, 0.5))
		t.isTrue(not SwingBox.hits(ARC, FROM, -direction, inside, 0.5))
		local slamAt = FROM + direction * SLAM.ahead
		t.isTrue(SwingBox.hits(SLAM, FROM, direction, slamAt, 0.5))
		t.isTrue(not SwingBox.hits(SLAM, FROM, -direction, slamAt, 0.5))
	end)

	t.test("a swing with no direction strikes nothing", function()
		t.isTrue(not SwingBox.hits(ARC, FROM, Vector3.zero, out(1, 0), 1))
	end)
end
