--!strict
--[[
	The move-or-shoot rhythm both sides keep (`Shared/Combat/FireRhythm`).

	What it must never do again: let the server's first frame after a card
	screen find the settle and cooldown already spent behind the screen and
	fire at once, before the client has drawn the shot or played its attack
	(owner, 2026-10-26). So: a resumed rhythm waits a full settle and a full
	cooldown, however long the pause, and two rhythms resumed at the same
	moment — the server's and the client's — are ready on the same frame.

	And what it must never do again either: drift. Both sides keep this rhythm
	on their own clock at their own frame rate, and a volley can only go on a
	frame boundary. Booking it at the frame it went out rather than at the time
	it was due carried each frame's rounding into the next interval, so the two
	cadences crept apart for as long as the player stood still — 59 studs of
	arrow over 30 s with the client at 15 fps against a 60 Hz server. The side
	that was behind applied its damage nowhere near its own arrow, which is what
	the owner saw (2026-11-03, `docs/FIXES.md`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FireRhythm = require(ReplicatedStorage.Shared.Combat.FireRhythm)
local TestRunner = require(script.Parent.TestRunner)

local FRAME = 1 / 60

local function fresh(): FireRhythm.State
	return { stationarySince = nil, movingSince = nil, movedFor = 0, lastFiredAt = 0 }
end

--[[ Steps a standing player frame by frame from `from`, firing whenever
     settled and off `cooldown`, and returns when the first shot goes. ]]
local function firstShot(state: FireRhythm.State, from: number, cooldown: number): number
	local now = from
	for _ = 1, 60 * 30 do
		local settled = FireRhythm.settle(state, false, now)
		if settled and now - state.lastFiredAt >= cooldown then
			FireRhythm.fired(state, now, cooldown)
			return now
		end
		now += FRAME
	end
	return math.huge
end

return function(t: TestRunner.Helper)
	local cooldown = Balance.Player.attackCooldown
	local wait = math.max(Balance.Player.stationaryDelay, cooldown)

	t.test("standing still shoots only once settled", function()
		local state = fresh()
		local at = firstShot(state, 100, cooldown)
		t.isTrue(at - 100 >= Balance.Player.stationaryDelay, "fired before settling")
	end)

	t.test("moving clears the settle and starts counting the move", function()
		local state = fresh()
		FireRhythm.settle(state, false, 10)
		FireRhythm.settle(state, true, 11)
		t.isNil(state.stationarySince)
		t.equal(state.movingSince, 11)
		FireRhythm.settle(state, false, 13)
		t.near(state.movedFor, 2, 1e-9)
	end)

	t.test("after a long pause, the first shot waits a full settle and cooldown", function()
		local state = fresh()
		-- standing and shooting, then a card screen held for a minute
		firstShot(state, 100, cooldown)
		local resumedAt = 100 + 60
		FireRhythm.resume(state, resumedAt)
		local at = firstShot(state, resumedAt, cooldown)
		t.isTrue(at - resumedAt >= wait - 1e-9, "fired the moment the world moved again")
		t.isTrue(at - resumedAt <= wait + 2 * FRAME, "waited longer than a settle and a cooldown")
	end)

	t.test("no Momentum carries over a pause", function()
		local state = fresh()
		FireRhythm.settle(state, true, 0)
		FireRhythm.settle(state, false, 5)
		t.isTrue(state.movedFor > 0, "the move was counted")
		FireRhythm.resume(state, 6)
		t.equal(state.movedFor, 0)
		t.isNil(state.movingSince)
	end)

	t.test("the server's rhythm and the client's, resumed together, shoot together", function()
		local server, client = fresh(), fresh()
		-- the server had stood longer, the client had just moved
		FireRhythm.settle(server, false, 50)
		FireRhythm.settle(client, true, 70)
		FireRhythm.resume(server, 80)
		FireRhythm.resume(client, 80)
		t.near(firstShot(server, 80, cooldown), firstShot(client, 80, cooldown), 1e-9)
	end)
	--[[ Both sides, stepped at their own frame rate over the same stretch of
	     standing still, must stay in step. Each fires on a frame boundary, so
	     each volley may be up to one of its own frames late -- but that
	     lateness must not be carried into the next interval. ]]
	local function volleys(
		state: FireRhythm.State,
		from: number,
		dt: number,
		span: number
	): { number }
		local fired: { number } = {}
		local now = from
		while now - from < span do
			local settled = FireRhythm.settle(state, false, now)
			if settled and now - state.lastFiredAt >= cooldown then
				FireRhythm.fired(state, now, cooldown)
				table.insert(fired, now)
			end
			now += dt
		end
		return fired
	end

	t.test("a rhythm's cadence does not drift from the cooldown", function()
		local slow = 1 / 15
		local fired = volleys(fresh(), 100, slow, 30)
		t.isTrue(#fired > 10, "too few volleys to tell")
		--[[ Measured against the first, so an error that compounds shows up
		     however small each step of it is. ]]
		for index = 2, #fired do
			local drift = (fired[index] - fired[1]) - (index - 1) * cooldown
			t.isTrue(
				math.abs(drift) <= slow + 1e-9,
				`volley {index} drifted {math.floor(1000 * drift)} ms from its due time`
			)
		end
	end)

	t.test("the server's cadence and the client's stay in step at any frame rate", function()
		local server, client = fresh(), fresh()
		local serverFired = volleys(server, 100, 1 / 60, 30)
		local clientFired = volleys(client, 100, 1 / 15, 30)
		t.equal(#serverFired, #clientFired)
		--[[ One client frame apart at most, and no worse at the end of the
		     stretch than at the start: a constant offset is a prediction
		     working, a growing one is the bug. ]]
		for index = 1, #serverFired do
			t.isTrue(
				math.abs(clientFired[index] - serverFired[index]) <= 1 / 15 + 1e-9,
				`volley {index} is {math.floor(1000 * (clientFired[index] - serverFired[index]))} ms apart`
			)
		end
	end)

	t.test("a rhythm idle for a long time fires once, not a burst to catch up", function()
		local state = fresh()
		FireRhythm.settle(state, false, 100)
		FireRhythm.fired(state, 100, cooldown)
		--[[ Nothing asked it to fire for a minute (out of range, say). The
		     backlog must not be bankable. ]]
		FireRhythm.fired(state, 160, cooldown)
		t.near(state.lastFiredAt, 160, 1e-9)
	end)
	t.test("a volley that waited for a target does not bank the wait", function()
		--[[ Standing with nothing in line, then a target: the shot goes when
		     it can, and the next one a whole cooldown after it, not sooner.
		     Banking the wait made a double shot after every stop. ]]
		for _, late in { 0.2, cooldown * 0.5, cooldown * 0.95 } do
			local state = fresh()
			FireRhythm.fired(state, 100, cooldown)
			local shotAt = 100 + cooldown + late
			FireRhythm.fired(state, shotAt, cooldown)
			t.isTrue(
				state.lastFiredAt >= shotAt - FireRhythm.CARRY - 1e-9,
				`{math.floor(1000 * late)} ms late banked {math.floor(
					1000 * (shotAt - state.lastFiredAt)
				)} ms`
			)
		end
	end)

	t.test("stopping after a move never gives two volleys inside one cooldown", function()
		local state = fresh()
		local fired: { number } = {}
		local now = 100
		-- stand and shoot, walk for a while, stop and shoot again, repeat
		for _, walk in { 0.35, 0.6, 0.9, 1.3, 0.2 } do
			for _ = 1, 120 do
				local settled = FireRhythm.settle(state, false, now)
				if settled and now - state.lastFiredAt >= cooldown then
					FireRhythm.fired(state, now, cooldown)
					table.insert(fired, now)
				end
				now += FRAME
			end
			local stop = now + walk
			while now < stop do
				FireRhythm.settle(state, true, now)
				now += FRAME
			end
		end
		for index = 2, #fired do
			t.isTrue(
				fired[index] - fired[index - 1] >= cooldown - FRAME - 1e-9,
				`volleys {index - 1} and {index} {math.floor(
					1000 * (fired[index] - fired[index - 1])
				)} ms apart`
			)
		end
	end)
end
