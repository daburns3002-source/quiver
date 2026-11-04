--!strict
--[[
	`Fx/ShotDrift` measures how far the arrow the player sees is from the
	shot that did the damage: the client draws its own prediction and throws
	the server's copy away, so nothing else compares the two.

	Pinned here because the thing it measures cannot be reproduced in Studio
	Play — one DataModel holds both sides there, so every real number it
	reports is zero. If the arithmetic were wrong, a playtest would not say
	so; it would just keep reading zero.
]]

--[[ The client lives in StarterPlayerScripts, not ReplicatedStorage; this is
     a plain ModuleScript of arithmetic, so the server can require it. ]]
local StarterPlayer = game:GetService("StarterPlayer")

local ShotDrift = require(StarterPlayer.StarterPlayerScripts.Client.Fx.ShotDrift)
local TestRunner = require(script.Parent.TestRunner)

local FORWARD = Vector3.new(0, 0, 1)

return function(t: TestRunner.Helper)
	t.test("with nothing matched it reports no drift rather than dividing by zero", function()
		ShotDrift.reset()
		ShotDrift.predicted(Vector3.zero, FORWARD)
		local stats = ShotDrift.stats()
		t.equal(stats.shots, 1, "the prediction was counted")
		t.equal(stats.matched, 0, "nothing has been matched")
		t.equal(stats.origin, 0, "no mean origin drift")
		t.equal(stats.angle, 0, "no mean aim drift")
	end)

	t.test("a server volley that agrees exactly reads as no drift", function()
		ShotDrift.reset()
		ShotDrift.predicted(Vector3.new(4, 3, 2), FORWARD)
		ShotDrift.server(Vector3.new(4, 3, 2), FORWARD)
		local stats = ShotDrift.stats()
		t.equal(stats.matched, 1, "it matched the prediction")
		t.equal(stats.origin, 0, "the origins agree")
		t.isTrue(stats.angle < 1e-6, "the aims agree")
	end)

	t.test("it measures the distance between the origins", function()
		ShotDrift.reset()
		ShotDrift.predicted(Vector3.zero, FORWARD)
		ShotDrift.server(Vector3.new(3, 0, 4), FORWARD)
		t.isTrue(math.abs(ShotDrift.stats().origin - 5) < 1e-6, "3-4-5 reads as 5 studs")
	end)

	t.test("it measures the angle between the aims", function()
		ShotDrift.reset()
		ShotDrift.predicted(Vector3.zero, FORWARD)
		ShotDrift.server(Vector3.zero, Vector3.new(1, 0, 0))
		t.isTrue(math.abs(ShotDrift.stats().angle - 90) < 1e-6, "a right angle reads as 90 degrees")
	end)

	--[[ A dot of exactly 1 can come back a hair over it from rounding, and
	     acos of that is nan, which would poison every later mean. ]]
	t.test("an aim that agrees to rounding never poisons the mean", function()
		ShotDrift.reset()
		for _ = 1, 20 do
			ShotDrift.predicted(Vector3.zero, FORWARD)
			ShotDrift.server(Vector3.zero, FORWARD)
		end
		local angle = ShotDrift.stats().angle
		t.isTrue(angle == angle, "the mean is a number, not nan")
	end)

	t.test("volleys pair oldest first, as they are fired and arrive", function()
		ShotDrift.reset()
		ShotDrift.predicted(Vector3.zero, FORWARD)
		ShotDrift.predicted(Vector3.new(10, 0, 0), FORWARD)
		-- the server's copy of the FIRST volley, 1 stud off
		ShotDrift.server(Vector3.new(1, 0, 0), FORWARD)
		local stats = ShotDrift.stats()
		t.equal(stats.matched, 1, "one pair so far")
		t.isTrue(math.abs(stats.origin - 1) < 1e-6, "it paired with the first, not the second")
	end)

	t.test("a server volley with no prediction waiting is ignored", function()
		ShotDrift.reset()
		ShotDrift.server(Vector3.zero, FORWARD)
		t.equal(ShotDrift.stats().matched, 0, "nothing was matched")
	end)

	t.test("the report says so when nothing has been matched", function()
		ShotDrift.reset()
		t.isTrue(
			string.find(ShotDrift.report(), "none matched") ~= nil,
			"it says nothing matched rather than printing zeroes as a result"
		)
	end)
end
