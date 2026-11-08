--!strict
--[[
	The Old Tollcrab's own fight (`Enemies/TollcrabMoves`, `Balance`
	`oldTollcrab`; owner, 2026-11-07: "give me unique moves"): Toll Wave,
	Echo Mark and Crab Scuttle, enraged from half health.

	Pinned: none of King Bloblin's moves are in his loop; the ring's gap is
	safe, its band is not, it goes through cover and dies at its reach; the
	gap is always reachable at the player's pace; the paired ring's gap is
	reachable from the first's; each ring and each charge hits once; marks
	land under the player and strike a beat later; the scuttle is a
	zigzag of dashes, each marked at the player and hitting once, a lane
	can be stepped out of in the beat before it, it stops at a wall, and
	it leaves him stunned long enough to punish.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossMoves = require(ServerScriptService.Server.Enemies.BossMoves)
local TestRunner = require(script.Parent.TestRunner)
local TollcrabMoves = require(ServerScriptService.Server.Enemies.TollcrabMoves)

local config = Balance.Enemies.OldTollcrab :: Balance.EnemyConfig
local boss = config.boss :: Balance.EnemyBoss
local toll = boss.toll :: Balance.BossToll
local echo = boss.echo :: Balance.BossEcho
local scuttle = boss.scuttle :: Balance.BossScuttle

local FRAME = 1 / 60
local PAD = 1

local function identity(point: Vector3): Vector3
	return point
end

--[[ A move run frame by frame to its end, `target` asked each frame;
     returns every event in order and the seconds it took. ]]
local function run(
	move: BossMoves.Move,
	target: (number) -> Vector3,
	clamp: (Vector3) -> Vector3,
	each: ((number) -> ())?
): ({ BossMoves.Event }, number)
	local all = {}
	local now = move.phaseAt
	for _ = 1, 3000 do
		local _, events, done = TollcrabMoves.step(move, boss, now, target(now), clamp)
		for _, e in events do
			table.insert(all, e)
		end
		if each then
			each(now)
		end
		if done then
			return all, now - move.phaseAt
		end
		now += FRAME
	end
	error("the move never ended")
end

local function ofKind(events: { BossMoves.Event }, kind: string): { BossMoves.Event }
	local found = {}
	for _, e in events do
		if e.kind == kind then
			table.insert(found, e)
		end
	end
	return found
end

local function degreesBetween(a: Vector3, b: Vector3): number
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

return function(t: TestRunner.Helper)
	t.test("his loop is his own moves, none of King Bloblin's", function()
		local loop = BossMoves.loopOf(boss)
		t.equal(table.concat(loop, " "), "Toll Echo Scuttle Echo")
		for _, kind in loop do
			t.isTrue(TollcrabMoves.owns(kind), kind)
		end
		t.isFalse(TollcrabMoves.owns("Bounce"))
		t.isFalse(TollcrabMoves.owns("Lash"))
		t.near(boss.enrageAt :: number, 0.5, 1e-9)
		local summon = boss.summon :: Balance.BossSummon
		t.equal(#(summon.atFractions :: { number }), 1, "the Drowned Rise once, at half")
	end)

	t.test("the ring's band hits, its gap is safe, past its reach it is gone", function()
		local gap = Vector3.xAxis
		local age = 0.5
		local radius = age * toll.speed
		t.isTrue(
			TollcrabMoves.ringHit(toll, Vector3.zero, gap, age, Vector3.new(0, 0, radius), PAD)
		)
		t.isTrue(
			TollcrabMoves.ringHit(toll, Vector3.zero, gap, age, Vector3.new(-radius, 0, 0), PAD)
		)
		t.isFalse(
			TollcrabMoves.ringHit(toll, Vector3.zero, gap, age, Vector3.new(radius, 0, 0), PAD),
			"in the gap"
		)
		t.isFalse(
			TollcrabMoves.ringHit(toll, Vector3.zero, gap, age, Vector3.new(0, 0, radius + 4), PAD),
			"not reached yet"
		)
		local gone = TollcrabMoves.ringTime(toll) + 0.01
		t.isFalse(
			TollcrabMoves.ringHit(toll, Vector3.zero, gap, gone, Vector3.new(0, 0, toll.reach), PAD),
			"done at its reach"
		)
	end)

	t.test("the gap can always be reached at the player's pace", function()
		local pace = Balance.Player.moveSpeed
		-- the furthest the gap's edge is set round from the player
		local worst = math.rad(toll.gapTo - toll.gap / 2)
		for r = 3, toll.reach do
			local walk = r * worst
			local time = toll.windup + r / toll.speed
			t.isTrue(walk <= pace * time * 0.85, `at {r} studs: {walk} to walk in {time}s`)
		end
		-- and from the first ring's gap to the paired ring's
		local turn = math.rad(toll.pairTurn - toll.gap)
		t.isTrue(turn > 0, "the gaps differ")
		t.isTrue(
			toll.reach * turn <= pace * toll.pairDelay * 0.85,
			"the second gap is in reach from the first"
		)
	end)

	t.test("a toll: gap set round from the player, one ring, hits once, through cover", function()
		local player = Vector3.new(0, 0, 10)
		local move = TollcrabMoves.start("Toll", 100, Vector3.zero, 0, false)
		local hits = 0
		local events = run(
			move,
			function()
				return player
			end,
			identity,
			function(now)
				if TollcrabMoves.touch(move, boss, now, "p", player, PAD) then
					hits += 1
				end
			end
		)
		local tells = ofKind(events, "TollTell")
		local rings = ofKind(events, "TollRing")
		t.equal(#tells, 1)
		t.equal(#rings, 1)
		local off = degreesBetween(tells[1].direction, player)
		t.isTrue(off >= toll.gapFrom - 0.01 and off <= toll.gapTo + 0.01, `gap {off} degrees round`)
		t.equal(hits, 1, "standing outside the gap, hit once")
		t.isFalse(TollcrabMoves.enraged(move))
	end)

	t.test("standing in the gap, the toll misses", function()
		local move = TollcrabMoves.start("Toll", 100, Vector3.zero, 0, false)
		local spot: Vector3? = nil
		local hits = 0
		run(
			move,
			function()
				return Vector3.new(0, 0, 10)
			end,
			identity,
			function(now)
				local rings = TollcrabMoves.rings(move)
				if not spot and rings[1] then
					spot = rings[1].gap.Unit * 10
				end
				if spot and TollcrabMoves.touch(move, boss, now, "p", spot, PAD) then
					hits += 1
				end
			end
		)
		t.equal(hits, 0)
	end)

	t.test("enraged, the rings come in pairs, the second gap turned from the first", function()
		local move = TollcrabMoves.start("Toll", 100, Vector3.zero, 0, true)
		local events, seconds = run(move, function()
			return Vector3.new(0, 0, 10)
		end, identity)
		local rings = ofKind(events, "TollRing")
		t.equal(#rings, 2)
		t.near(degreesBetween(rings[1].direction, rings[2].direction), toll.pairTurn, 0.01)
		t.isTrue(
			seconds >= toll.windup + toll.pairDelay + TollcrabMoves.ringTime(toll),
			"he stays planted until both rings are done"
		)
	end)

	t.test("echo marks land under the player and strike a beat later", function()
		local player = Vector3.new(6, 0, 4)
		local move = TollcrabMoves.start("Echo", 100, Vector3.zero, 0, false)
		local tellAt: { number } = {}
		local strikeAt: { number } = {}
		local events = run(move, function()
			return player
		end, identity)
		-- times, from a second pass that records when each event arrived
		local again = TollcrabMoves.start("Echo", 100, Vector3.zero, 0, false)
		local clock = 100
		for _ = 1, 3000 do
			local _, es, done = TollcrabMoves.step(again, boss, clock, player, identity)
			for _, e in es do
				if e.kind == "EchoTell" then
					table.insert(tellAt, clock)
				elseif e.kind == "EchoStrike" then
					table.insert(strikeAt, clock)
				end
			end
			if done then
				break
			end
			clock += FRAME
		end
		local tells = ofKind(events, "EchoTell")
		t.equal(#tells, echo.marks)
		t.equal(#ofKind(events, "EchoStrike"), echo.marks)
		for _, e in tells do
			t.near((e.at - player).Magnitude, 0, 1e-6, "under their feet")
		end
		t.equal(#strikeAt, echo.marks)
		for i = 1, echo.marks do
			t.near(strikeAt[i] - tellAt[i], echo.delay, FRAME * 1.5, "a beat later")
		end
	end)

	t.test("enraged, each rap drops two marks, the second where they are heading", function()
		local move = TollcrabMoves.start("Echo", 100, Vector3.zero, 0, true)
		local events = run(move, function(now)
			return Vector3.new(5 + (now - 100) * 10, 0, 8)
		end, identity)
		local tells = ofKind(events, "EchoTell")
		t.equal(#tells, echo.marks * 2)
		t.isTrue(tells[2].at.X > tells[1].at.X + 2, "the second leads the runner")
	end)

	t.test("the scuttle zigzags: a lane at the player for each dash, then stunned", function()
		local move = TollcrabMoves.start("Scuttle", 100, Vector3.zero, 0, false)
		local player = Vector3.new(8, 0, 0)
		local hits = 0
		local stunnedFor = 0
		local events = run(
			move,
			function()
				return player
			end,
			identity,
			function(now)
				if TollcrabMoves.touch(move, boss, now, "p", player, PAD) then
					hits += 1
				end
				if move.phase == "crash" then
					stunnedFor += FRAME
				end
			end
		)
		local lanes = ofKind(events, "Lane")
		t.equal(#lanes, scuttle.dashes)
		t.near(lanes[1].direction.X, 1, 1e-6, "aimed at the player")
		t.near(lanes[2].direction.X, -1, 1e-6, "and back at them from past them")
		t.near(lanes[3].direction.X, 1, 1e-6, "and back again")
		t.near(lanes[1].length, 8 + scuttle.overshoot, 1e-6, "on past them")
		t.near(lanes[2].at.X, lanes[1].at.X + lanes[1].length, 1e-6, "from where the last ended")
		t.near(lanes[1].width, scuttle.width, 1e-9)
		t.equal(hits, scuttle.dashes, "standing still, once by each dash")
		t.isTrue(stunnedFor >= scuttle.stunned - FRAME * 2, "the punish window")
		t.equal(#ofKind(events, "BumpShock"), 1, "one crash, at the end")
	end)

	t.test("each dash aims at where the player is then, and a lane can be left in time", function()
		local move = TollcrabMoves.start("Scuttle", 100, Vector3.zero, 0, false)
		local events = run(move, function(now)
			return Vector3.new(10, 0, -12 + (now - 100) * 8)
		end, identity)
		local lanes = ofKind(events, "Lane")
		t.isTrue(
			degreesBetween(lanes[1].direction, lanes[2].direction) > 10,
			"a new line each dash"
		)
		local leave = scuttle.width / 2 + PAD
		t.isTrue(
			leave <= Balance.Player.moveSpeed * scuttle.between * 0.85,
			"out of the lane in the beat before the dash"
		)
	end)

	t.test("a dash stops at the wall, and is short", function()
		local wall = 12
		local function clamp(point: Vector3): Vector3
			return Vector3.new(math.clamp(point.X, -wall, wall), 0, point.Z)
		end
		local move = TollcrabMoves.start("Scuttle", 100, Vector3.zero, 0, false)
		local events = run(move, function()
			return Vector3.new(10, 0, 0)
		end, clamp)
		local lanes = ofKind(events, "Lane")
		t.near(lanes[1].length, wall, 1e-6, "stopped short of its overshoot by the wall")

		local far = TollcrabMoves.start("Scuttle", 100, Vector3.zero, 0, false)
		local farEvents = run(far, function()
			return Vector3.new(0, 0, 50)
		end, identity)
		for _, lane in ofKind(farEvents, "Lane") do
			t.isTrue(lane.length <= scuttle.range, "never a long run")
		end
	end)
end
