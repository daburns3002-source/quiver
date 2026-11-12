--!strict
--[[
	Chain Lightning's bolt and Soul Chain's fireball (owner, 2026-11-11:
	"chain lightning should be like the stattik shiv effect ... soul link
	should be like brand ult"), held to what makes them read:

	- the bolt is jagged, forked and flat on the ground plane, so the camera
	  above sees its whole width (docs/FIXES.md, "Howl Aura arrows invisible
	  from above"), and it joins the two bodies it runs between;
	- each hop of the lightning lands a few hundredths of a second after the
	  last, and the bolt is gone in a fraction of a second;
	- the fireball visits every linked enemy once, the nearest next, in leaps
	  that rise, and the server's landings and the client's leaps are one
	  timetable.

	Relationships, not values: retuning a number must not fail these.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BoltPath = require(ReplicatedStorage.Shared.Util.BoltPath)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local SoulBounce = require(ReplicatedStorage.Shared.Combat.SoulBounce)
local Types = require(ReplicatedStorage.Shared.Types)

local TestRunner = require(script.Parent.TestRunner)

local Bolt = Balance.UpgradeFx.bolt
local Soul = Balance.UpgradeFx.soul
local Projectile = Balance.Projectile

local SHAPE: BoltPath.Shape = {
	segmentLength = Bolt.segmentLength,
	minSegments = Bolt.minSegments,
	maxSegments = Bolt.maxSegments,
	kink = Bolt.kink,
	forks = Bolt.forks,
	forkShare = Bolt.forkShare,
	forkReach = Bolt.forkReach,
	forkAngle = Bolt.forkAngle,
	forkSegments = Bolt.forkSegments,
}

local function volley(counts: { [string]: number }): { Types.ShotSpec }
	local pipeline = ShotPipeline.new()
	for _, stage in AbilityEffects.stages(counts) do
		pipeline:addStage(stage)
	end
	return pipeline:build({
		damage = Balance.Player.baseDamage,
		speed = Projectile.speed,
		lifetime = Projectile.lifetime,
		origin = Vector3.zero,
		direction = Vector3.new(0, 0, -1),
	})
end

--[[ How far `point` is from the line through `a` and `b`, along the ground. ]]
local function offLine(point: Vector3, a: Vector3, b: Vector3): number
	local span = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local to = Vector3.new(point.X - a.X, 0, point.Z - a.Z)
	return math.abs(span.Unit:Cross(to).Y)
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

return function(t: TestRunner.Helper)
	local from = Vector3.new(-3, 1.8, 4)
	local reaches = { 2, 6, Projectile.ricochetRange, Projectile.ricochetRange * 2 }

	t.test("a bolt joins its two bodies and lies flat for the camera above", function()
		for seed, reach in reaches do
			local to = from + Vector3.new(reach * 0.6, 0, -reach * 0.8)
			local bolt = BoltPath.build(from, to, SHAPE, Random.new(seed))
			t.near(
				(bolt.main[1] - from).Magnitude,
				0,
				1e-6,
				"it does not start on the enemy struck"
			)
			t.near((bolt.main[#bolt.main] - to).Magnitude, 0, 1e-6, "it does not end on the next")
			for _, joint in bolt.main do
				t.near(joint.Y, from.Y, 1e-6, "a kink stands up, where the camera cannot see it")
			end
			for _, fork in bolt.forks do
				for _, joint in fork do
					t.near(joint.Y, from.Y, 1e-6, "a fork stands up")
				end
			end
		end
	end)

	t.test("it is jagged, and no kink is thrown far enough to read as two bolts", function()
		for seed, reach in reaches do
			local to = from + Vector3.new(0, 0, -reach)
			local bolt = BoltPath.build(from, to, SHAPE, Random.new(seed + 10))
			local segments = #bolt.main - 1
			t.equal(segments, BoltPath.segments(reach, SHAPE))
			t.isTrue(segments >= 3, "too few pieces to zig-zag")
			local widest = 0
			for index = 2, #bolt.main - 1 do
				widest = math.max(widest, offLine(bolt.main[index], from, to))
			end
			t.isTrue(widest > 0, `a {reach} stud bolt is a straight line`)
			t.isTrue(
				widest <= reach / segments * SHAPE.kink + 1e-6,
				`a kink is {widest} studs off a {reach} stud bolt`
			)
		end
	end)

	t.test("it forks, each fork sprouting from the bolt and shorter than it", function()
		t.isTrue(SHAPE.forks >= 1, "no forks")
		t.isTrue(SHAPE.forkAngle.min > 0, "a fork may lie along the bolt, where it cannot be seen")
		t.isTrue(SHAPE.forkAngle.max < math.pi / 2, "a fork may point back the way it came")
		t.isTrue(SHAPE.forkShare.max < 0.5, "a fork may be as long as the bolt")
		for seed, reach in reaches do
			local to = from + Vector3.new(reach, 0, 0)
			local bolt = BoltPath.build(from, to, SHAPE, Random.new(seed + 20))
			t.equal(#bolt.forks, BoltPath.forkCount(reach, SHAPE))
			t.isTrue(#bolt.forks >= 1, `a {reach} stud bolt has no fork`)
			local used: { [number]: boolean } = {}
			for _, fork in bolt.forks do
				t.equal(#fork, SHAPE.forkSegments + 1)
				local onBolt = 0
				for index = 2, #bolt.main - 1 do
					if (bolt.main[index] - fork[1]).Magnitude < 1e-6 then
						onBolt = index
					end
				end
				t.isTrue(onBolt > 0, "a fork starts off the bolt")
				t.isNil(used[onBolt], "two forks sprout from one joint")
				used[onBolt] = true
				local length = (fork[#fork] - fork[1]).Magnitude
				t.isTrue(length > 0, "a fork has no length")
				t.isTrue(length <= SHAPE.forkReach * 1.2, `a fork is {length} studs long`)
			end
		end
	end)

	t.test("a bolt of one length is always the same pieces, so a re-kink builds nothing", function()
		for _, reach in reaches do
			local to = from + Vector3.new(0, 0, reach)
			local a = BoltPath.build(from, to, SHAPE, Random.new(1))
			local b = BoltPath.build(from, to, SHAPE, Random.new(2))
			t.equal(#a.main, #b.main)
			t.equal(#a.forks, #b.forks)
			t.isTrue((a.main[2] - b.main[2]).Magnitude > 0, "a re-kink changes nothing")
		end
	end)

	t.test("Chain Lightning's arcs leave as lightning, Ricochet's arrows as arrows", function()
		local max = #Abilities.byId.ChainLightning.levels
		local arced = volley({ ChainLightning = max })[1]
		t.isTrue(arced.ricochet > 0, "Chain Lightning arcs to nothing")
		t.equal(arced.arcSpeed, Projectile.arcSpeed)
		t.isNil(volley({ Ricochet = 1 })[1].arcSpeed, "Ricochet's arrow leaves as lightning")
		t.isNil(volley({})[1].arcSpeed, "a plain shot arcs")
		-- the two together: every bounce is an arc, and none is lost
		local both = volley({ ChainLightning = 1, Ricochet = 1 })[1]
		t.equal(both.arcSpeed, Projectile.arcSpeed)
		t.isTrue(both.ricochet > volley({ ChainLightning = 1 })[1].ricochet, "a bounce was lost")
	end)

	t.test(
		"Elemental Orbs' lightning arcs as Chain Lightning does, and only its lightning",
		function()
			-- required here, not at the top: it is the one test that needs the server
			local ServerScriptService = game:GetService("ServerScriptService")
			local ClassUpgrades = (require :: any)(ServerScriptService.Server.Combat.ClassUpgrades)
			local function orb(): any
				return { ricochet = 0 }
			end
			local lightning = orb()
			ClassUpgrades.dressAs("Lightning", lightning)
			t.isTrue(lightning.ricochet > 0, "lightning chains on to nothing")
			t.equal(lightning.arcSpeed, Projectile.arcSpeed)
			for _, element in { "Fire", "Ice" } do
				local dressed = orb()
				ClassUpgrades.dressAs(element, dressed)
				t.isNil(dressed.arcSpeed, `{element} arcs`)
				t.equal(dressed.ricochet, 0)
			end
		end
	)

	t.test("each hop lands a few hundredths of a second after the last", function()
		local longest = Projectile.ricochetRange / Projectile.arcSpeed
		t.isTrue(longest <= 0.06, `the longest hop takes {longest} s`)
		t.isTrue(Projectile.arcSpeed > Projectile.speed, "an arc is slower than an arrow")
		--[[ A projectile moves only on a server step and not at all once its
		     life is over, so an arc's life is counted in steps: it must still
		     cross its whole reach on a server running at 30 steps a second,
		     and die sooner than an arrow when it finds nothing. ]]
		local slowStep = 1 / 30
		local steps = math.floor(Projectile.arcLife / slowStep + 1e-6)
		t.isTrue(
			steps * slowStep * Projectile.arcSpeed >= Projectile.ricochetRange,
			"on a slow server an arc dies before the edge of its reach"
		)
		t.isTrue(Projectile.arcLife < Projectile.lifetime, "a missed arc outlives an arrow")
	end)

	t.test("the bolt crackles and is gone in a fraction of a second", function()
		t.isTrue(Bolt.life <= 0.25, `the bolt hangs for {Bolt.life} s`)
		t.isTrue(Bolt.life / Bolt.crackle >= 3, "it does not re-kink while it shows")
		t.isTrue(Bolt.fade > 0 and Bolt.fade < 1, "it does not thin away")
		t.isTrue(Bolt.flashLife < Bolt.life, "the flash outlasts the bolt")
		t.isTrue(Bolt.core < Bolt.glow, "the white-hot core is wider than its glow")
		t.isTrue(Bolt.glowClear > 0 and Bolt.glowClear < 1, "the glow is solid or invisible")
		-- a chain's hops all show at once: the bolt outlives the hops after it
		local chain = #Abilities.byId.ChainLightning.levels + 1
		t.isTrue(Bolt.cap >= chain, "one chain is more bolts than may be drawn")
	end)

	t.test("the fireball visits every linked enemy once, the nearest next", function()
		local centre = Vector3.new(2, 0, -1)
		local stops = {
			Vector3.new(9, 0, -1),
			Vector3.new(2, 0, 3),
			Vector3.new(-6, 0, -3),
			Vector3.new(3, 0, 5),
		}
		local order = SoulBounce.route(centre, stops)
		t.equal(#order, #stops)
		local seen: { [number]: boolean } = {}
		local at = centre
		for _, index in order do
			t.isNil(seen[index], "an enemy is visited twice")
			seen[index] = true
			for other, stop in stops do
				if not seen[other] then
					t.isTrue(
						flat(at, stops[index]) <= flat(at, stop) + 1e-6,
						"it leapt past a nearer enemy"
					)
				end
			end
			at = stops[index]
		end
		t.equal(#SoulBounce.route(centre, {}), 0)
	end)

	t.test("it lands on each a moment after the last, and is done inside a second", function()
		local hop = Projectile.linkHop
		t.isTrue(hop.min > 0 and hop.min <= hop.max, "a leap takes no time, or less than none")
		local centre = Vector3.zero
		local stops = {
			Vector3.new(0.5, 0, 0),
			Vector3.new(Projectile.linkRange, 0, 0),
			Vector3.new(-Projectile.linkRange, 0, 0),
		}
		local times = SoulBounce.times(centre, stops)
		t.equal(#times, #stops)
		local last = 0
		for index, at in times do
			local leap = at - last
			t.isTrue(leap >= hop.min - 1e-9, `leap {index} takes {leap} s: too quick to see`)
			t.isTrue(leap <= hop.max + 1e-9, `leap {index} takes {leap} s`)
			last = at
		end
		-- a longer leap is never quicker than a shorter one
		t.isTrue(SoulBounce.hopTime(10) >= SoulBounce.hopTime(2), "a long leap is quicker")
		-- the most a card links, each leap the longest there is
		local levels = Abilities.byId.SoulChain.levels
		local most = levels[#levels] - 1
		t.isTrue(most * hop.max < 1, `a full link takes {most * hop.max} s`)
		-- and it burns a moment, not as long as Blaze's burn does
		t.isTrue(Soul.burn > 0, "the enemy it lands on does not burn")
		t.isTrue(Soul.burn < 2, "it burns as long as a real burn")
	end)

	t.test("a leap is an arc from one enemy to the next", function()
		for _, reach in { 1, 5, Projectile.linkRange, Projectile.linkRange * 2 } do
			local a = Vector3.new(1, Soul.height, 2)
			local b = a + Vector3.new(reach * 0.8, 0, reach * 0.6)
			t.near((SoulBounce.at(a, b, 0) - a).Magnitude, 0, 1e-6, "it does not leave the enemy")
			t.near((SoulBounce.at(a, b, 1) - b).Magnitude, 0, 1e-6, "it does not land on the next")
			local apex = SoulBounce.apex(reach)
			t.isTrue(apex >= Soul.leap.min and apex <= Soul.leap.max, `a leap rises {apex} studs`)
			local middle = SoulBounce.at(a, b, 0.5)
			t.near(middle.Y, a.Y + apex, 1e-6, "the middle of the leap is not its top")
			t.isTrue(
				SoulBounce.at(a, b, 0.25).Y < middle.Y and SoulBounce.at(a, b, 0.75).Y < middle.Y,
				"the leap does not rise and fall"
			)
			-- over the ground it is a straight line at an even pace
			t.near(flat(middle, a), reach / 2, 1e-6, "it does not cross the ground evenly")
		end
		t.isTrue(Soul.leap.min > 0, "a short leap is flat")
	end)

	t.test("both are built in code and budgeted for a phone", function()
		local clips = ReplicatedStorage.Shared.Config.ModelClips
		local imports = ReplicatedStorage.Shared.Config.ImportedModels
		for _, key in { "FxChainLightning", "FxSoulChain" } do
			t.isNil(clips:FindFirstChild(key), `{key} still has clip data`)
			t.isNil(imports:FindFirstChild(key), `{key} is still built from an import`)
		end
		t.isTrue(Bolt.cap >= 2 and Soul.cap >= 1, "nothing may be drawn")
		t.isTrue(Bolt.sparks > 0 and Soul.burst > 0 and Soul.embers > 0, "no sparks or flames")
		t.isTrue(Soul.core < Soul.shell, "the heart is wider than the fire round it")
		t.isTrue(Soul.trailLife > 0 and Soul.trailWidth > 0, "no flame trail")
		t.isTrue(Soul.trailGlow > 0 and Soul.trailGlow < 1, "the trail burns out to a white band")
		t.isTrue(Soul.flameGlow > 0 and Soul.flameGlow < 1, "the flames burn out to white light")
	end)
end
