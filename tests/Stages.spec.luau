--!strict
--[[
	The spread stage.

	The Spitter's fan and, in Phase 3, the player's Diagonal Arrows. Its
	symmetry is load-bearing in a way that is easy to break silently: an odd
	count has to keep one projectile exactly on the original heading, because
	a fan with nothing down the middle reads as a deliberate miss rather than
	as a gap to walk through.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Stages = require(ReplicatedStorage.Shared.Combat.Stages)
local TestRunner = require(script.Parent.TestRunner)
local Types = require(ReplicatedStorage.Shared.Types)

local function baseSpec(): Types.ShotSpec
	return {
		angleOffset = 0,
		lateralOffset = 0,
		damageScale = 1,
		speed = 20,
		lifetime = 3,
		pierce = 0,
		critChance = 0,
		critMultiplier = 2,
		splashRadius = 0,
		splashScale = 0,
		bounces = 0,
		ricochet = 0,
		homing = 0,
		delay = 0,
		burn = 0,
		chainOnKill = 0,
	}
end

local function request(): Types.ShotRequest
	return {
		damage = 8,
		speed = 20,
		lifetime = 3,
		origin = Vector3.zero,
		direction = Vector3.new(0, 0, 1),
	}
end

return function(t: TestRunner.Helper)
	t.test("a count of one is left alone", function()
		local stage = Stages.spread(1, math.rad(20))
		local out = stage.apply({ baseSpec() }, request())

		t.equal(#out, 1)
		t.near(out[1].angleOffset, 0, 1e-9)
	end)

	t.test("a count of zero or less is left alone", function()
		local stage = Stages.spread(0, math.rad(20))
		t.equal(#stage.apply({ baseSpec() }, request()), 1)
	end)

	t.test("three shots fan symmetrically with one on centre", function()
		local angle = math.rad(18)
		local out = Stages.spread(3, angle).apply({ baseSpec() }, request())

		t.equal(#out, 3)
		t.near(out[1].angleOffset, -angle, 1e-9)
		t.near(out[2].angleOffset, 0, 1e-9, "the middle shot must stay on centre")
		t.near(out[3].angleOffset, angle, 1e-9)
	end)

	t.test("five shots stay symmetric about centre", function()
		local angle = math.rad(24)
		local out = Stages.spread(5, angle).apply({ baseSpec() }, request())

		t.equal(#out, 5)

		local sum = 0
		for _, spec in out do
			sum += spec.angleOffset
		end

		t.near(sum, 0, 1e-9, "offsets must cancel out")
		t.near(out[3].angleOffset, 0, 1e-9)
	end)

	t.test("an even count straddles the centre rather than sitting on it", function()
		local angle = math.rad(20)
		local out = Stages.spread(2, angle).apply({ baseSpec() }, request())

		t.equal(#out, 2)
		t.near(out[1].angleOffset, -angle / 2, 1e-9)
		t.near(out[2].angleOffset, angle / 2, 1e-9)
	end)

	t.test("the fan is centred on whatever offset the spec already had", function()
		local angle = math.rad(10)
		local offset = math.rad(45)

		local shifted = baseSpec()
		shifted.angleOffset = offset

		local out = Stages.spread(3, angle).apply({ shifted }, request())

		t.near(out[2].angleOffset, offset, 1e-9, "centre should follow the input")
		t.near(out[1].angleOffset, offset - angle, 1e-9)
		t.near(out[3].angleOffset, offset + angle, 1e-9)
	end)

	t.test("the input list is not mutated", function()
		local original = baseSpec()
		local input = { original }

		Stages.spread(3, math.rad(18)).apply(input, request())

		t.equal(#input, 1, "the stage must return a new list")
		t.near(original.angleOffset, 0, 1e-9, "the original spec must be untouched")
	end)

	t.test("other spec fields survive the fan", function()
		local spec = baseSpec()
		spec.damageScale = 0.75
		spec.pierce = 2

		local out = Stages.spread(3, math.rad(18)).apply({ spec }, request())

		for _, copy in out do
			t.near(copy.damageScale, 0.75, 1e-9)
			t.equal(copy.pierce, 2)
			t.near(copy.speed, spec.speed, 1e-9)
		end
	end)

	t.test("it is registered in the pattern bucket", function()
		t.equal(Stages.spread(3, 1).order, ShotPipeline.Stage.Pattern)
		t.equal(Stages.spread(3, 1).name, "Spread")
	end)

	--[[ Two spreads stacking is how Phase 3 abilities are meant to compound,
	     so the multiplication has to hold rather than the second overwriting
	     the first. ]]
	t.test("stacked spreads multiply", function()
		local pipeline = ShotPipeline.new()
		pipeline:addStage(Stages.spread(3, math.rad(18)))
		pipeline:addStage(Stages.spread(3, math.rad(6)))

		t.equal(#pipeline:build(request()), 9)
	end)
end
