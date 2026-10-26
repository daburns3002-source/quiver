--!strict
--[[
	The move-or-shoot rhythm both sides keep (`Shared/Combat/FireRhythm`).

	What it must never do again: let the server's first frame after a card
	screen find the settle and cooldown already spent behind the screen and
	fire at once, before the client has drawn the shot or played its attack
	(owner, 2026-10-26). So: a resumed rhythm waits a full settle and a full
	cooldown, however long the pause, and two rhythms resumed at the same
	moment — the server's and the client's — are ready on the same frame.
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
			state.lastFiredAt = now
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
end
