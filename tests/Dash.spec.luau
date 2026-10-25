--!strict
--[[
	The dash state machine.

	Windows and cooldowns are exactly the kind of state that looks correct and
	behaves wrong — off by a frame, or by the duration of the thing itself —
	and none of it is visible to the type checker. `Dash` takes `now` on every
	call precisely so this can drive time by hand instead of sleeping.

	Relationships, not values. Retuning the dash must not fail a test; tuning
	it into a shape that cannot work should.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Dash = require(StarterPlayer.StarterPlayerScripts.Client.Input.Dash)
local TestRunner = require(script.Parent.TestRunner)

local EAST = Vector3.new(1, 0, 0)
local NORTH = Vector3.new(0, 0, -1)

return function(t: TestRunner.Helper)
	local config = Balance.Player.dash

	--[[ Module state is shared across every call, so each test starts from a
	     known resting state rather than from whatever the last one left. ]]
	local function fresh(): number
		Dash.reset()
		return 1000
	end

	t.test("a dash is available from rest", function()
		local now = fresh()
		t.isTrue(Dash.request(now, EAST, NORTH), "the first dash was refused")
		t.isTrue(Dash.isDashing(now), "a dash was granted but is not running")
	end)

	t.test("a dash refuses a direction it cannot derive", function()
		local now = fresh()
		t.isFalse(Dash.request(now, Vector3.zero, Vector3.zero), "dashed with no heading at all")
		--[[ And having refused, it must not have spent the cooldown. ]]
		t.isTrue(Dash.request(now, EAST, NORTH), "a refused dash still burned the cooldown")
	end)

	t.test("a standing player dashes where they are facing", function()
		local now = fresh()
		t.isTrue(Dash.request(now, Vector3.zero, NORTH), "a standing dash was refused")

		local heading = Dash.current(now)
		t.notNil(heading, "no heading while dashing")
		t.near((heading :: Vector3).Z, -1, 1e-6, "did not dash along the facing")
	end)

	t.test("movement input wins over facing", function()
		local now = fresh()
		Dash.request(now, EAST, NORTH)

		local heading = Dash.current(now)
		t.near((heading :: Vector3).X, 1, 1e-6, "did not dash along the input")
	end)

	--[[ The thing that makes a dash a decision rather than a speed boost. ]]
	t.test("a heading is committed and cannot be steered", function()
		local now = fresh()
		Dash.request(now, EAST, EAST)

		local later = Dash.current(now + config.duration / 2)
		t.notNil(later, "the dash ended early")
		t.near((later :: Vector3).X, 1, 1e-6, "the heading moved after the dash began")
	end)

	t.test("a dash ends after its own duration", function()
		local now = fresh()
		Dash.request(now, EAST, EAST)

		t.isTrue(Dash.isDashing(now + config.duration * 0.9), "ended before its duration")
		t.isFalse(Dash.isDashing(now + config.duration), "outlived its duration")
	end)

	t.test("a dash cannot be chained", function()
		local now = fresh()
		Dash.request(now, EAST, EAST)
		t.isFalse(Dash.request(now + config.duration / 2, EAST, EAST), "dashed while dashing")
		t.isFalse(
			Dash.request(now + config.cooldown * 0.9, EAST, EAST),
			"dashed before the cooldown elapsed"
		)
		t.isTrue(Dash.request(now + config.cooldown, EAST, EAST), "never became available again")
	end)

	--[[ The cooldown runs from the start of the dash, not its end, so what the
	     player waits is the number in the config and not that plus the
	     duration. ]]
	t.test("the cooldown is measured from the start of the dash", function()
		local now = fresh()
		Dash.request(now, EAST, EAST)
		t.near(Dash.readiness(now + config.cooldown), 1, 1e-6, "not ready after exactly a cooldown")
	end)

	t.test("readiness fills from nothing to ready", function()
		local now = fresh()
		Dash.request(now, EAST, EAST)

		t.near(Dash.readiness(now), 0, 1e-6, "readiness did not reset on dashing")
		t.isTrue(Dash.readiness(now + config.cooldown / 2) > 0.4, "readiness filled too slowly")
		t.isTrue(Dash.readiness(now + config.cooldown / 2) < 0.6, "readiness filled too fast")
		t.near(Dash.readiness(now + config.cooldown * 2), 1, 1e-6, "never reached ready")
	end)

	t.test("a reset clears a dash in flight and its cooldown", function()
		local now = fresh()
		Dash.request(now, EAST, EAST)
		Dash.reset()

		t.isFalse(Dash.isDashing(now), "a dash survived a reset")
		t.isTrue(Dash.request(now, EAST, EAST), "a cooldown survived a reset")
	end)

	--[[ Relationships between the balance numbers. Each of these is a shape
	     the dash cannot work in, whatever the values are tuned to. ]]
	t.test("a dash outruns walking by enough to be an escape", function()
		local speed = config.distance / config.duration
		t.isTrue(
			speed > Balance.Player.moveSpeed * 2,
			`a dash at {speed} studs/s barely beats walking at {Balance.Player.moveSpeed}`
		)
	end)

	--[[ The walk to an open gate is quicker (`exitRush`), but a dash is
	     still the faster thing, or the cleared room makes it pointless. ]]
	t.test("the walk to an open gate is faster, and a dash faster still", function()
		local rush = Balance.Player.exitRush
		local speed = config.distance / config.duration
		t.isTrue(rush > 1, `exitRush {rush} does not speed the walk up`)
		t.isTrue(
			speed > Balance.Player.moveSpeed * rush,
			`a dash at {speed} studs/s is slower than the walk to an open gate`
		)
	end)

	--[[ A dash drives the Humanoid, so walls and cover stop it as they stop
	     walking, as long as one frame's travel cannot step over the
	     thinnest of them. Measured against a 60 fps frame, coarser than
	     the physics step, to leave a margin. ]]
	t.test("one frame of dash cannot step through a wall or cover", function()
		local step = config.distance / config.duration / 60
		local thinnest = Balance.Arena.wallThickness
		for _, room in Balance.Rooms do
			for _, obstacle in room.obstacles do
				thinnest = math.min(thinnest, obstacle.size.X, obstacle.size.Z)
			end
		end
		t.isTrue(
			step < thinnest,
			`a dash moves {step} studs a frame, past the thinnest cover ({thinnest})`
		)
	end)

	t.test("a dash cannot cross the arena", function()
		t.isTrue(
			config.distance < Balance.Arena.size.X / 2,
			"one dash covers half the arena or more"
		)
	end)

	t.test("a dash is a decision rather than a second movement speed", function()
		t.isTrue(
			config.cooldown > config.duration * 4,
			"the cooldown is short enough to dash almost continuously"
		)
	end)
end
