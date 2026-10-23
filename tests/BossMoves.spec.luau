--!strict
--[[
	A boss's moves as timelines (`Enemies/BossMoves`), run start to finish
	without a game. What is pinned is what makes them fair: every hit is
	warned of where it lands and long enough before, a slam never lands
	further than it may, and a hitch never skips one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossMoves = require(ServerScriptService.Server.Enemies.BossMoves)
local TestRunner = require(script.Parent.TestRunner)

local boss = Balance.Enemies.SlimeKing.boss :: Balance.EnemyBoss

local function identity(point: Vector3): Vector3
	return point
end

type Timed = { at: number, event: BossMoves.Event }

--[[ Plays a move to its end at `step` seconds a frame. `target` gives where
     the target stands at a time. `onHit` may grab on a lane hit. ]]
local function play(
	kind: BossMoves.Kind,
	target: (number) -> Vector3,
	step: number,
	onHit: ((BossMoves.Move, BossMoves.Event, number) -> ())?
): ({ Timed }, { BossMoves.Pose }, number, BossMoves.Move)
	local move = BossMoves.start(kind, 0, Vector3.zero, 0)
	local timed: { Timed } = {}
	local poses: { BossMoves.Pose } = {}
	local now = 0
	for _ = 1, 100000 do
		now += step
		local pose, events, done = BossMoves.step(move, boss, now, target(now), identity)
		table.insert(poses, pose)
		for _, e in events do
			table.insert(timed, { at = now, event = e })
			if onHit and e.kind == "LaneHit" then
				onHit(move, e, now)
			end
		end
		if done then
			return timed, poses, now, move
		end
	end
	error("the move never ended")
end

local function only(timed: { Timed }, kind: string): { Timed }
	local out = {}
	for _, entry in timed do
		if entry.event.kind == kind then
			table.insert(out, entry)
		end
	end
	return out
end

local FRAME = 1 / 60

return function(t: TestRunner.Helper)
	local b = boss.bounce
	local l = boss.lash

	t.test("a Royal Bounce slams once per bounce, each inside its circle", function()
		local timed = play("Bounce", function()
			return Vector3.new(10, 0, 0)
		end, FRAME)
		local tells = only(timed, "SlamTell")
		local slams = only(timed, "Slam")
		t.equal(#tells, b.bounces)
		t.equal(#slams, b.bounces)
		for index, slam in slams do
			t.near((slam.event.at - tells[index].event.at).Magnitude, 0, 1e-6)
		end
	end)

	--[[ The circle is the whole counterplay: it has to be up for the wind-up,
	     the launch and the flight before the hit. ]]
	t.test("each slam is warned of for its whole wind-up and flight", function()
		local timed = play("Bounce", function()
			return Vector3.new(10, 0, 0)
		end, FRAME)
		local tells = only(timed, "SlamTell")
		local slams = only(timed, "Slam")
		local warning = b.windup + b.launch + b.air
		for index, slam in slams do
			t.near(slam.at - tells[index].at, warning, FRAME * 2)
			t.near(tells[index].event.duration, warning, 1e-6)
		end
	end)

	t.test("no bounce lands further than its range", function()
		local timed = play("Bounce", function()
			return Vector3.new(200, 0, 0)
		end, FRAME)
		local from = Vector3.zero
		for _, slam in only(timed, "Slam") do
			t.isTrue((slam.event.at - from).Magnitude <= b.maxRange + 1e-6, "landed out of range")
			from = slam.event.at
		end
	end)

	--[[ No homing: a player who moves after the circle appears is not
	     followed. ]]
	t.test("a bounce lands where the target stood at the wind-up", function()
		local timed = play("Bounce", function(now)
			return if now < 0.1 then Vector3.new(8, 0, 0) else Vector3.new(-8, 0, 0)
		end, FRAME)
		t.near((only(timed, "Slam")[1].event.at - Vector3.new(8, 0, 0)).Magnitude, 0, 1e-6)
	end)

	t.test("a slam lands where the room allows", function()
		local move = BossMoves.start("Bounce", 0, Vector3.zero, 0)
		local wall = function(point: Vector3): Vector3
			return Vector3.new(math.clamp(point.X, -5, 5), 0, point.Z)
		end
		local _, events = BossMoves.step(move, boss, FRAME, Vector3.new(15, 0, 0), wall)
		t.near(events[1].at.X, 5, 1e-6)
	end)

	t.test("the boss is airborne in flight and grounded when it lands", function()
		local timed, poses = play("Bounce", function()
			return Vector3.new(10, 0, 0)
		end, FRAME)
		local flew = false
		for _, pose in poses do
			flew = flew or pose.airborne
		end
		t.isTrue(flew, "never left the floor")
		t.isTrue(not poses[#poses].airborne, "ended in the air")
		t.isTrue(#only(timed, "Slam") > 0, "never slammed")
	end)

	--[[ A frame of a whole second must still land every slam, in order. ]]
	t.test("a long frame skips no slam", function()
		local timed = play("Bounce", function()
			return Vector3.new(10, 0, 0)
		end, 1)
		t.equal(#only(timed, "Slam"), b.bounces)
	end)

	t.test("a Royal Bounce lasts its bounces and the winded pause", function()
		local _, _, ended = play("Bounce", function()
			return Vector3.new(10, 0, 0)
		end, FRAME)
		local expected = b.bounces * (b.windup + b.launch + b.air + b.recover) + b.winded
		t.near(ended, expected, FRAME * 2)
	end)

	t.test("each lash tracks, locks, then hits, once per arm", function()
		local timed = play("Lash", function()
			return Vector3.new(0, 0, -10)
		end, FRAME)
		local aims = only(timed, "LaneAim")
		local lanes = only(timed, "Lane")
		local hits = only(timed, "LaneHit")
		t.equal(#lanes, #l.arms)
		t.equal(#hits, #l.arms)
		for index, hit in hits do
			--[[ The lane is redrawn as it follows the target: this arm's
			     tracking began with the first one after the last arm locked. ]]
			local after = if index > 1 then lanes[index - 1].at else -1
			local first: Timed? = nil
			for _, aim in aims do
				if aim.at > after then
					first = aim
					break
				end
			end
			t.notNil(first, "an arm never tracked")
			t.near(lanes[index].at - (first :: Timed).at, l.track, FRAME * 2)
			t.near(hit.at - lanes[index].at, (l.wind - l.track) + l.strike, FRAME * 2)
		end
	end)

	t.test("a lash's lane stays within its reach", function()
		for _, distance in { 1, 10, 60 } do
			local timed = play("Lash", function()
				return Vector3.new(distance, 0, 0)
			end, FRAME)
			for _, hit in only(timed, "LaneHit") do
				t.isTrue(hit.event.length >= l.minReach - 1e-6, "lane shorter than its minimum")
				t.isTrue(hit.event.length <= l.reach + 1e-6, "lane longer than its reach")
			end
		end
	end)

	--[[ The lane locks: stepping off it after the lock is the dodge. ]]
	t.test("a lash hits where the lane locked, not where the target went", function()
		local timed = play("Lash", function(now)
			return if now < l.track + 0.05 then Vector3.new(0, 0, -10) else Vector3.new(10, 0, 0)
		end, FRAME)
		local hit = only(timed, "LaneHit")[1].event
		t.near(hit.direction.Z, -1, 1e-3)
	end)

	t.test("a grab pulls the boss in and ends in a chest bump", function()
		local held = Vector3.new(0, 0, -12)
		local grabbed = false
		local timed, poses = play(
			"Lash",
			function()
				return held
			end,
			FRAME,
			function(move, _event, now)
				if not grabbed then
					grabbed = true
					BossMoves.grab(move, boss, now, held, identity)
				end
			end
		)
		t.isTrue(grabbed, "never hit")
		t.equal(#only(timed, "Bump"), 1)
		--[[ After the first arm's pull it stands its stop distance short of
		     the one it held. ]]
		local settled = false
		for _, pose in poses do
			if math.abs((held - pose.feet).Magnitude - l.stopDistance) < 1e-3 then
				settled = true
			end
		end
		t.isTrue(settled, "never stood its stop distance from the held player")
	end)
end
