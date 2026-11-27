--!strict
--[[
	The Tempest Roc's own moves (`Enemies/RocMoves`; docs/WINDSWEPT-
	CLIFFS.md), run start to finish without a game. What is pinned is what
	makes them fair: every hit is marked before it lands, the dive stops at
	the room's wall, a dive crosses each player once, the storm's bolts all
	land after their rings, and every move ends in a window to hit him.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossMoves = require(ServerScriptService.Server.Enemies.BossMoves)
local RocMoves = require(ServerScriptService.Server.Enemies.RocMoves)
local TestRunner = require(script.Parent.TestRunner)

local boss = Balance.Benched.TempestRoc.boss :: Balance.EnemyBoss
local roc = boss.roc :: Balance.BossRoc

local FRAME = 1 / 60

--[[ A room 35 x 58 with nothing in it. ]]
local function room(point: Vector3): Vector3
	return Vector3.new(math.clamp(point.X, -12.5, 12.5), 0, math.clamp(point.Z, -24, 24))
end

type Timed = { at: number, event: BossMoves.Event }

local function play(
	kind: string,
	target: Vector3,
	onStep: ((BossMoves.Move, BossMoves.Pose, number) -> ())?
): ({ Timed }, number, BossMoves.Move)
	local move = RocMoves.start(kind, 0, Vector3.new(0, 0, -10), 0, true)
	local timed: { Timed } = {}
	local now = 0
	for _ = 1, 60 * 40 do
		local pose, events, done = RocMoves.step(move, boss, now, target, room)
		for _, e in events do
			table.insert(timed, { at = now, event = e })
		end
		if onStep then
			onStep(move, pose, now)
		end
		if done then
			return timed, now, move
		end
		now += FRAME
	end
	error(`{kind} never ended`)
end

local function first(timed: { Timed }, kind: string): Timed?
	for _, t in timed do
		if t.event.kind == kind then
			return t
		end
	end
	return nil
end

return function(t: TestRunner.Helper)
	t.test("every move ends, and the storm only comes enraged", function()
		for _, kind in { "Dive", "Gust", "Swipe", "Storm" } do
			t.isTrue(RocMoves.owns(kind), kind)
			local _, ended = play(kind, Vector3.new(0, 0, 10))
			t.isTrue(ended > 0.5, kind)
		end
		t.isFalse(RocMoves.owns("Bounce"), "a King Bloblin move")
		t.equal(boss.enrageAt, 0.5)
		t.isTrue(table.find(boss.loop or {}, "Storm") ~= nil, "the storm is in his loop")
	end)

	t.test("the dive's lane is drawn for its wind-up and stops at the wall", function()
		local timed, _, move = play("Dive", Vector3.new(0, 0, 10))
		local lane = first(timed, "Lane")
		t.notNil(lane, "a lane")
		if lane then
			t.near(lane.event.duration, roc.dive.windup, 1e-6)
			t.equal(lane.event.width, roc.dive.width)
		end
		local from, along, length = RocMoves.lane(move)
		local finish = from + along * length
		t.isTrue(finish.Z <= 24 + 1e-3, "inside the far wall")
		t.isTrue(length >= 20, "it crosses most of the room")
	end)

	t.test("a dive crosses a player in its lane once, and nobody beside it", function()
		local hits, missed = 0, 0
		play("Dive", Vector3.new(0, 0, 10), function(move, _pose, now)
			local damage = RocMoves.touch(move, boss, now, "inLane", Vector3.new(0.5, 0, 4), 1)
			if damage then
				hits += 1
			end
			local wide = RocMoves.touch(move, boss, now, "aside", Vector3.new(9, 0, 4), 1)
			if wide then
				missed += 1
			end
		end)
		t.equal(hits, 1, "hit once")
		t.equal(missed, 0, "nobody beside the lane")
	end)

	t.test("the gust and the swipe are marked before they land", function()
		for _, pair in { { "Gust", "GustTell", "Gust" }, { "Swipe", "SwipeTell", "Swipe" } } do
			local timed = play(pair[1], Vector3.new(0, 0, 0))
			local tell, blow = first(timed, pair[2]), first(timed, pair[3])
			t.notNil(tell, pair[2])
			t.notNil(blow, pair[3])
			if tell and blow then
				t.isTrue(blow.at - tell.at >= 0.5, `{pair[1]} warns long enough`)
			end
		end
	end)

	t.test("every bolt strikes after its ring, and he is out of reach meanwhile", function()
		--[[ Rings told at each spot, oldest first: several bolts can share
		     one (the chasing bolts on a player who stands still). ]]
		local told: { [string]: { number } } = {}
		local early = 0
		local airborneDuringStorm = true
		local timed = play("Storm", Vector3.new(0, 0, 0), function(move, pose)
			if move.phase == "storm" and not pose.airborne then
				airborneDuringStorm = false
			end
		end)
		local bolts = 0
		for _, entry in timed do
			local key = tostring(entry.event.at)
			if entry.event.kind == "BoltTell" then
				local queue = told[key] or {}
				table.insert(queue, entry.at)
				told[key] = queue
			elseif entry.event.kind == "Bolt" then
				bolts += 1
				local queue = told[key]
				local at = if queue then table.remove(queue, 1) else nil
				if not at or entry.at - at < roc.storm.warn - 1e-3 then
					early += 1
				end
			end
		end
		local s = roc.storm
		t.equal(bolts, s.line + s.ring + s.chase, "every bolt falls")
		t.equal(early, 0, "no bolt without its full warning")
		t.isTrue(airborneDuringStorm, "out of reach while the storm falls")
	end)

	t.test("the storm's chasing bolts land where the player stands", function()
		local s = roc.storm
		local bolts = RocMoves.planStorm(s, 0, Vector3.new(3, 0, 4), Vector3.xAxis)
		local chasing = 0
		for _, bolt in bolts do
			if bolt.at == nil then
				chasing += 1
			end
		end
		t.equal(chasing, s.chase)
		t.equal(#bolts, s.line + s.ring + s.chase)
	end)
end
