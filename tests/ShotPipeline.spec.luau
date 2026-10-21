--!strict
--[[
	The shot pipeline and its stages.

	This is the abstraction CLAUDE.md calls the core of the whole game, and
	the one every ability in Phase 3 and every enemy attack already depends on.
	It is also pure — no instances, no state outside the pipeline object — so
	it is the cheapest thing in the project to pin down properly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Stages = require(ReplicatedStorage.Shared.Combat.Stages)
local TestRunner = require(script.Parent.TestRunner)
local Types = require(ReplicatedStorage.Shared.Types)

local function request(): Types.ShotRequest
	return {
		damage = 10,
		speed = 70,
		lifetime = 2.5,
		origin = Vector3.zero,
		direction = Vector3.new(0, 0, 1),
	}
end

return function(t: TestRunner.Helper)
	t.test("an empty pipeline produces exactly one shot", function()
		local pipeline = ShotPipeline.new()
		local specs = pipeline:build(request())

		t.equal(#specs, 1)
		t.near(specs[1].angleOffset, 0, 1e-9)
		t.near(specs[1].damageScale, 1, 1e-9)
		t.equal(specs[1].pierce, 0)
	end)

	t.test("the base shot inherits speed and lifetime from the request", function()
		local pipeline = ShotPipeline.new()
		local req = request()
		local specs = pipeline:build(req)

		t.near(specs[1].speed, req.speed, 1e-9)
		t.near(specs[1].lifetime, req.lifetime, 1e-9)
	end)

	t.test("stages run in bucket order regardless of insertion order", function()
		local pipeline = ShotPipeline.new()
		local order: { string } = {}

		local function marker(name: string, bucket: number): Types.ShotStage
			return {
				name = name,
				order = bucket,
				apply = function(specs)
					table.insert(order, name)
					return specs
				end,
			}
		end

		-- Added back to front on purpose.
		pipeline:addStage(marker("onHit", ShotPipeline.Stage.OnHit))
		pipeline:addStage(marker("count", ShotPipeline.Stage.Count))
		pipeline:addStage(marker("flight", ShotPipeline.Stage.Flight))

		pipeline:build(request())

		t.equal(table.concat(order, ","), "count,flight,onHit")
	end)

	t.test("stages in one bucket keep insertion order", function()
		local pipeline = ShotPipeline.new()
		local order: { string } = {}

		local function marker(name: string): Types.ShotStage
			return {
				name = name,
				order = ShotPipeline.Stage.Count,
				apply = function(specs)
					table.insert(order, name)
					return specs
				end,
			}
		end

		pipeline:addStage(marker("first"))
		pipeline:addStage(marker("second"))
		pipeline:addStage(marker("third"))

		pipeline:build(request())

		t.equal(table.concat(order, ","), "first,second,third")
	end)

	--[[ Front Arrow +1 stacks by being present twice rather than by carrying
	     a level, so duplicate names have to be allowed and counted. ]]
	t.test("the same stage can be added more than once", function()
		local pipeline = ShotPipeline.new()
		local stage = Stages.spread(2, math.rad(10))

		pipeline:addStage(stage)
		pipeline:addStage(stage)

		t.equal(pipeline:countStage("Spread"), 2)
		t.equal(#pipeline:build(request()), 4)
	end)

	t.test("removeStage drops one instance and reports it", function()
		local pipeline = ShotPipeline.new()
		pipeline:addStage(Stages.spread(3, math.rad(10)))
		pipeline:addStage(Stages.spread(3, math.rad(10)))

		t.isTrue(pipeline:removeStage("Spread"))
		t.equal(pipeline:countStage("Spread"), 1)
		t.isFalse(pipeline:removeStage("NotThere"))
	end)

	t.test("clear empties the pipeline", function()
		local pipeline = ShotPipeline.new()
		pipeline:addStage(Stages.spread(3, math.rad(10)))
		pipeline:clear()

		t.equal(pipeline:countStage("Spread"), 0)
		t.equal(#pipeline:build(request()), 1)
	end)

	t.test("two pipelines never share stages", function()
		local a = ShotPipeline.new()
		local b = ShotPipeline.new()

		a:addStage(Stages.spread(5, math.rad(10)))

		t.equal(#a:build(request()), 5)
		t.equal(#b:build(request()), 1, "a second pipeline must be unaffected")
	end)

	t.test("aim returns the direction unchanged at zero offset", function()
		local direction = Vector3.new(0, 0, 1)
		local aimed = ShotPipeline.aim(direction, {
			angleOffset = 0,
			lateralOffset = 0,
			damageScale = 1,
			speed = 1,
			lifetime = 1,
			pierce = 0,
			critChance = 0,
			critMultiplier = 2,
			splashRadius = 0,
			splashScale = 0,
			bounces = 0,
			chainOnKill = 0,
		})

		t.near((aimed - direction).Magnitude, 0, 1e-9)
	end)

	--[[ The helper every consumer of a volley uses to place an arrow. Three
	     hand-rolled copies of this perpendicular would be three chances to
	     disagree about which way is left. ]]
	t.test("spawnPoint leaves an arrow alone when it has no offset", function()
		local origin = Vector3.new(5, 3, -2)
		local moved = ShotPipeline.spawnPoint(origin, Vector3.new(0, 0, -1), {
			angleOffset = 0,
			lateralOffset = 0,
			damageScale = 1,
			speed = 1,
			lifetime = 1,
			pierce = 0,
			critChance = 0,
			critMultiplier = 2,
			splashRadius = 0,
			splashScale = 0,
			bounces = 0,
			chainOnKill = 0,
		})

		t.near((moved - origin).Magnitude, 0, 1e-9)
	end)

	t.test("spawnPoint steps sideways, never along the aim", function()
		local origin = Vector3.zero
		local aim = Vector3.new(0, 0, -1)
		local moved = ShotPipeline.spawnPoint(origin, aim, {
			angleOffset = 0,
			lateralOffset = 2,
			damageScale = 1,
			speed = 1,
			lifetime = 1,
			pierce = 0,
			critChance = 0,
			critMultiplier = 2,
			splashRadius = 0,
			splashScale = 0,
			bounces = 0,
			chainOnKill = 0,
		})

		--[[ Exactly the offset, and none of it forwards: an arrow that
		     started ahead of the others would reach the target first and the
		     volley would stop reading as one shot. ]]
		t.near(moved.Magnitude, 2, 1e-6, "the arrow did not move the distance asked for")
		t.near(moved:Dot(aim), 0, 1e-9, "the offset leaked into the aim direction")
		t.near(moved.Y, 0, 1e-9, "the offset left the floor plane")
	end)

	t.test("aim rotates in the plane and preserves length", function()
		local aimed = ShotPipeline.aim(Vector3.new(0, 0, 1), {
			angleOffset = math.rad(90),
			lateralOffset = 0,
			damageScale = 1,
			speed = 1,
			lifetime = 1,
			pierce = 0,
			critChance = 0,
			critMultiplier = 2,
			splashRadius = 0,
			splashScale = 0,
			bounces = 0,
			chainOnKill = 0,
		})

		t.near(aimed.Magnitude, 1, 1e-6, "rotation must not change length")
		t.near(aimed.Y, 0, 1e-9, "aim stays flat")
		t.near(math.abs(aimed.X), 1, 1e-6, "a quarter turn from +Z lands on X")
	end)
end
