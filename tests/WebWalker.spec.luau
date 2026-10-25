--!strict
--[[
	The Broodmother's Web Walker (`Shared/Util/WebWheel`, `BossMoves`
	"Spin", `Balance` Broodmother `spin`): a web nearly as wide as the room
	spinning round her like a horse walker, the player walking the edge.

	What is pinned is what makes it fair and what makes it hers: it turns
	clockwise as seen from the camera; it only hurts while it spins, never
	while it is warned of or once broken; there is a track to walk outside
	the web when she stands mid-room, and the arms cross it slower than the
	player walks; the arms reach every corner, so the corners are no hiding
	place; she loops it with her lash and plays her own clips for it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossMoves = require(ServerScriptService.Server.Enemies.BossMoves)
local ModelClip = require(ReplicatedStorage.Shared.Util.ModelClip)
local TestRunner = require(script.Parent.TestRunner)
local WebWheel = require(ReplicatedStorage.Shared.Util.WebWheel)

local boss = Balance.Enemies.Broodmother.boss :: Balance.EnemyBoss
local s = boss.spin :: Balance.BossSpin

local FRAME = 1 / 60
local PAD = 1

local function identity(point: Vector3): Vector3
	return point
end

return function(t: TestRunner.Helper)
	t.test("she loops Web Walker and her lash, and the jump is gone", function()
		local loop = BossMoves.loopOf(boss)
		t.equal(table.concat(loop, " "), "Spin Lash")
		t.equal(
			table.concat(BossMoves.loopOf(Balance.Enemies.SlimeKing.boss :: any), " "),
			"Bounce Lash"
		)
	end)

	t.test("spoke one turns clockwise from the camera (+X toward +Z)", function()
		local quarter = WebWheel.angle(0, s.period, s.period / 4)
		local spoke = WebWheel.spoke(quarter, 1, s.spokes)
		t.near(spoke.X, 0, 1e-6)
		t.near(spoke.Z, 1, 1e-6)
	end)

	t.test("under the web hurts, an arm hurts, between the arms is safe", function()
		local out = s.radius + 3
		t.equal(WebWheel.hit(s, Vector3.zero, 0, Vector3.new(2, 0, 1), PAD), "web")
		t.equal(WebWheel.hit(s, Vector3.zero, 0, Vector3.new(out, 0, 0), PAD), "arm")
		local between = WebWheel.spoke(math.pi / s.spokes, 1, s.spokes) * out
		t.isNil(WebWheel.hit(s, Vector3.zero, 0, between, PAD))
		t.isNil(WebWheel.hit(s, Vector3.zero, 0, Vector3.new(s.reach + 3, 0, 0), PAD))
	end)

	t.test("a player mid-room has a track to walk outside the web", function()
		local half = Balance.Arena.size.X / 2
		t.isTrue(s.radius + 2 * PAD + 1.5 < half, "a track at least 1.5 studs clear either side")
	end)

	t.test("the arms cross the track slower than the player walks", function()
		local track = s.radius + PAD + 1
		local sweep = 2 * math.pi * track / s.period
		t.isTrue(sweep < Balance.Player.moveSpeed * 0.75, `arms {sweep} studs/s`)
	end)

	t.test("the arms reach every corner of the room from mid-room", function()
		local size = Balance.Arena.size
		t.isTrue(s.reach >= math.sqrt((size.X / 2) ^ 2 + (size.Z / 2) ^ 2))
	end)

	t.test("it warns, spins, breaks, and only the spin hurts", function()
		local move = BossMoves.start("Spin", 0, Vector3.zero, 0)
		local target = Vector3.new(0, 0, -10)
		local kinds = {}
		local hurtIn: { [string]: boolean } = {}
		local now = 0
		for _ = 1, 100000 do
			now += FRAME
			local _, events, done = BossMoves.step(move, boss, now, target, identity)
			for _, e in events do
				table.insert(kinds, e.kind)
			end
			if done then
				break
			end
			if BossMoves.wheelHit(move, boss, now, Vector3.new(1, 0, 1), PAD) then
				hurtIn[move.phase] = true
			end
		end
		t.equal(table.concat(kinds, " "), "WheelTell WheelSpin WheelBreak Shake")
		t.isTrue(hurtIn.spin, "the spin hurts under the web")
		t.isNil(hurtIn.windup, "the wind-up only warns")
		t.isNil(hurtIn.broken, "a broken web hurts nobody")
		t.near(now, s.windup + s.spin + s.broken + s.recover, 2 * FRAME)
	end)

	t.test("the arm the client draws is the arm that hits", function()
		-- spoke one starts on the target, then turns with `WebWheel.angle`
		local move = BossMoves.start("Spin", 0, Vector3.zero, 0)
		local target = Vector3.new(s.radius + 3, 0, 0)
		local now = 0
		while move.phase ~= "spin" do
			now += FRAME
			BossMoves.step(move, boss, now, target, identity)
		end
		local later = now + 1.5
		BossMoves.step(move, boss, later, target, identity)
		local angle = WebWheel.angle(move.angle, s.period, later - move.phaseAt)
		local onArm = WebWheel.spoke(angle, 1, s.spokes) * (s.radius + 3)
		t.equal(BossMoves.wheelHit(move, boss, later, onArm, PAD), "arm")
	end)

	t.test("her rig has every Web Walker clip, and the hold loops", function()
		local clips = boss.clips :: Balance.BossClips
		local spin = clips.Spin :: { [string]: string }
		local data = (require :: any)(
				ReplicatedStorage.Shared.Config.ModelClips.Broodmother
			) :: ModelClip.Model
		for phase, name in spin do
			t.notNil(data.clips[name], `{phase} plays {name}`)
		end
		t.isTrue((data.clips[spin.spin] :: any).loops, "the hold loops")
		t.near((data.clips[spin.spin] :: any).length, s.holdSpan, 0.05)
	end)
end
