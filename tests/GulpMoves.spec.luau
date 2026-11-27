--!strict
--[[
	Grandmother Gulp's own moves (`Enemies/BossMoves`: Spit, Slide, Gulp;
	owner, 2026-11-07), run start to finish without a game. What is pinned
	is what makes them fair: every hit is marked before it lands, for at
	least an enemy's wind-up; each ends in its punish window; and none of
	them is one of King Bloblin's.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossMoves = require(ServerScriptService.Server.Enemies.BossMoves)
local TestRunner = require(script.Parent.TestRunner)

local boss = Balance.Enemies.GrandmotherGulp.boss :: Balance.EnemyBoss
local spit = boss.spit :: Balance.BossSpit
local slide = boss.slide :: Balance.BossSlide
local gulp = boss.gulp :: Balance.BossGulp

local FRAME = 1 / 60

--[[ A room 35 x 58 with nothing in it, for a boss ~5 across: where a
     slide stops. ]]
local function room(point: Vector3): Vector3
	return Vector3.new(math.clamp(point.X, -12.5, 12.5), 0, math.clamp(point.Z, -24, 24))
end

type Timed = { at: number, event: BossMoves.Event }

local function play(
	kind: BossMoves.Kind,
	target: Vector3,
	onStep: ((BossMoves.Move, number) -> ())?
): ({ Timed }, { BossMoves.Pose }, number)
	local move = BossMoves.start(kind, 0, Vector3.new(0, 0, -10), 0)
	local timed: { Timed } = {}
	local poses: { BossMoves.Pose } = {}
	local now = 0
	for _ = 1, 100000 do
		now += FRAME
		local pose, events, done = BossMoves.step(move, boss, now, target, room)
		table.insert(poses, pose)
		for _, e in events do
			table.insert(timed, { at = now, event = e })
		end
		if done then
			return timed, poses, now
		end
		if onStep then
			onStep(move, now)
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

return function(t: TestRunner.Helper)
	t.test("her loop is her own moves, none of King Bloblin's", function()
		for _, kind in boss.loop :: { string } do
			t.isTrue(kind == "Spit" or kind == "Slide" or kind == "Gulp", `{kind} in her loop`)
		end
		t.isNil(boss.summon, "no Spore Puff summon")
	end)

	t.test("Spore Spit marks every glob where it lands, for the swell and the flight", function()
		local timed = play("Spit", Vector3.new(4, 0, 8))
		local tells = only(timed, "SlamTell")
		local lands = only(timed, "GlobLand")
		t.equal(#tells, spit.globs)
		t.equal(#lands, spit.globs)
		t.near((tells[1].event.at - Vector3.new(4, 0, 8)).Magnitude, 0, 1e-6)
		for index, land in lands do
			t.near((land.event.at - tells[index].event.at).Magnitude, 0, 1e-6)
			t.near(land.at - tells[index].at, spit.swell + spit.flight, FRAME * 2)
			t.isTrue(spit.swell + spit.flight >= Balance.Telegraph.shockDuration, "long enough")
		end
	end)

	t.test("Belly Slide shows its whole lane before she goes, and stops at the wall", function()
		local timed, poses = play("Slide", Vector3.new(0, 0, 10))
		local lanes = only(timed, "Lane")
		local trails = only(timed, "Trail")
		t.equal(#lanes, 1)
		t.equal(#trails, 1)
		t.near(trails[1].at - lanes[1].at, slide.brace, FRAME * 2)
		t.near(lanes[1].event.width, slide.width, 1e-6)
		--[[ From z = -10 to the far wall at z = 24. ]]
		t.near(lanes[1].event.length, 34, 0.51)
		local last = poses[#poses]
		t.isTrue(last.feet.Z > 23, "she slid to the wall")
		t.equal(#only(timed, "SlideEnd"), 1)
	end)

	t.test("Big Gulp marks its cone before the inhale, and a swallow ends it", function()
		local swallowed = false
		local timed = play("Gulp", Vector3.new(0, 0, 0), function(move, now)
			if not swallowed and BossMoves.inhaling(move) and now - move.phaseAt > 0.5 then
				swallowed = true
				BossMoves.swallow(move, now)
			end
		end)
		local cones = only(timed, "ConeTell")
		local inhales = only(timed, "Inhale")
		t.equal(#cones, 1)
		t.equal(#inhales, 1)
		t.near(inhales[1].at - cones[1].at, gulp.open, FRAME * 2)
		t.isTrue(swallowed, "never inhaled")
	end)

	t.test("the cone holds what is in front of her mouth and not what is beside it", function()
		local move = BossMoves.start("Gulp", 0, Vector3.zero, 0)
		move.direction = Vector3.new(0, 0, 1)
		local mouth = BossMoves.mouth(move)
		t.isTrue(BossMoves.inCone(move, gulp, mouth + Vector3.new(0, 0, 10)), "ahead")
		t.isFalse(BossMoves.inCone(move, gulp, mouth + Vector3.new(10, 0, 2)), "beside")
		t.isFalse(BossMoves.inCone(move, gulp, mouth + Vector3.new(0, 0, gulp.reach + 1)), "past")
		t.isTrue(gulp.pull < Balance.Player.moveSpeed, "a player can walk out of it")
	end)

	t.test("each move ends in a punish window she does not attack from", function()
		local function check(kind: BossMoves.Kind)
			local timed, _, ended = play(kind, Vector3.new(0, 0, 8))
			local lastHit = 0
			for _, entry in timed do
				local k = entry.event.kind
				if k == "GlobLand" or k == "Trail" or k == "InhaleEnd" then
					lastHit = entry.at
				end
			end
			t.isTrue(ended - lastHit >= 1.5 - 1e-6, `{kind} punish window`)
		end
		check("Spit")
		check("Slide")
		check("Gulp")
	end)
end
