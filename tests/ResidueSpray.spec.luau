--!strict
--[[
	The slime residue (`Shared/Util/ResidueSpray`, `Balance.SlimeResidue`,
	`Fx/SlimeResidue`): a hit throws a few cubes back out of the struck face,
	a crit and a kill throw more, King Bloblin's are the biggest, only slimes
	throw any, and no device keeps more alive than its tier allows.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local DeviceTiers = require(ReplicatedStorage.Shared.Config.DeviceTiers)
local ResidueSpray = require(ReplicatedStorage.Shared.Util.ResidueSpray)
local TestRunner = require(script.Parent.TestRunner)

local settings: ResidueSpray.Settings = Balance.SlimeResidue :: any

return function(t: TestRunner.Helper)
	t.test("only slimes throw residue, and every slime does", function()
		local names: { [string]: boolean } = {}
		for _, config in Balance.Enemies :: any do
			names[config.displayName] = true
		end
		--[[ A benched enemy is a real one, waiting for its rooms. ]]
		for _, config in Balance.Benched do
			names[config.displayName] = true
		end
		for name in settings.kinds do
			t.isTrue(names[name] == true, name .. " is not an enemy")
		end
		for name in Balance.SlimeHop.kinds :: any do
			t.notNil(settings.kinds[name], name .. " hops like a slime but throws nothing")
		end
		t.notNil(settings.kinds.Spitter, "the Splitter Spitter throws nothing")
		t.notNil(settings.kinds.SlimeKing, "King Bloblin throws nothing")
	end)

	t.test("King Bloblin throws the biggest chunks", function()
		for name, kind in settings.kinds do
			if name ~= "SlimeKing" then
				t.isTrue(
					settings.kinds.SlimeKing.size > kind.size,
					"the king's are no bigger than " .. name .. "'s"
				)
			end
		end
	end)

	t.test("a crit throws more than a hit, and a kill more again", function()
		for name, kind in settings.kinds do
			local hit = ResidueSpray.count(kind, "Hit", false, settings)
			local crit = ResidueSpray.count(kind, "Crit", false, settings)
			local kill = ResidueSpray.count(kind, "Hit", true, settings)
			local critKill = ResidueSpray.count(kind, "Crit", true, settings)
			t.isTrue(hit >= 1, name .. " throws nothing on a hit")
			t.isTrue(crit > hit, name .. "'s crit throws no more than a hit")
			t.isTrue(kill > hit, name .. "'s kill throws no more than a hit")
			t.isTrue(critKill >= kill, name .. "'s critical kill throws less than a kill")
		end
	end)

	t.test("one burst fits inside the lowest tier, so a phone sees whole bursts", function()
		for name, kind in settings.kinds do
			local most = ResidueSpray.count(kind, "Crit", true, settings)
			t.isTrue(
				most <= DeviceTiers.Low.maxSlimeResidue,
				name .. "'s biggest burst is more than a phone keeps"
			)
		end
	end)

	t.test("phones keep fewer cubes than desktops", function()
		t.isTrue(DeviceTiers.Low.maxSlimeResidue > 0)
		t.isTrue(DeviceTiers.Low.maxSlimeResidue < DeviceTiers.Medium.maxSlimeResidue)
		t.isTrue(DeviceTiers.Medium.maxSlimeResidue < DeviceTiers.High.maxSlimeResidue)
	end)

	t.test("the pool goes round and never past its cap", function()
		local cap = DeviceTiers.Low.maxSlimeResidue
		local last = 0
		local seen: { [number]: boolean } = {}
		for _ = 1, cap * 3 do
			last = ResidueSpray.slot(last, cap)
			t.isTrue(last >= 1 and last <= cap, "slot " .. last .. " is outside the pool")
			seen[last] = true
		end
		local used = 0
		for _ in seen do
			used += 1
		end
		t.equal(used, cap, "the pool is not used evenly")
	end)

	t.test("a hit sprays back out of the struck face, rising, to both sides", function()
		local rng = Random.new(7)
		local centre = Vector3.new(4, 1.5, -2)
		local from = Vector3.new(-10, 1, 6)
		local back = ResidueSpray.back(centre, from, rng)
		t.isTrue(
			back:Dot((from - centre) * Vector3.new(1, 0, 1)) > 0,
			"thrown away from the shooter"
		)
		t.near(back.Y, 0, 1e-9)

		local arc = ResidueSpray.arc(false, settings)
		t.isTrue(arc < math.pi, "a hit throws all the way round")
		for _ = 1, 20 do
			local count = ResidueSpray.count(settings.kinds.Charger, "Crit", false, settings)
			local left, right = false, false
			for _, v in ResidueSpray.velocities(back, count, arc, settings, rng) do
				local flat = Vector3.new(v.X, 0, v.Z)
				t.isTrue(v.Y > 0, "a cube is thrown downwards")
				local off = math.acos(math.clamp(flat.Unit:Dot(back), -1, 1))
				t.isTrue(off <= arc / 2 + 1e-6, "a cube leaves the arc")
				local side = back:Cross(flat).Y
				left = left or side > 0
				right = right or side < 0
			end
			t.isTrue(left and right, "a burst leans to one side")
		end
	end)

	t.test("a kill throws all the way round", function()
		local rng = Random.new(11)
		local back = Vector3.xAxis
		local count = ResidueSpray.count(settings.kinds.BroodSlime, "Hit", true, settings)
		local behind = false
		for _, v in
			ResidueSpray.velocities(back, count, ResidueSpray.arc(true, settings), settings, rng)
		do
			behind = behind or v:Dot(back) < 0
		end
		t.isTrue(behind, "a kill throws only one way")
	end)

	t.test("cubes vary in size but stay cubes of the slime's scale", function()
		local rng = Random.new(3)
		for name, kind in settings.kinds do
			for _ = 1, 30 do
				local edge = ResidueSpray.size(kind, settings, rng)
				t.isTrue(edge > 0, name .. " throws a cube with no size")
				t.isTrue(edge < kind.size * 2, name .. " throws one twice its size")
			end
		end
	end)

	t.test("splats rest and shrink for about a second or two", function()
		local life = settings.rest + settings.shrink
		t.isTrue(life >= 1 and life <= 2.5, "splats last " .. life .. " s")
		t.isTrue(settings.splatFlat < 1 and settings.splatWide > 1, "a splat is not flat")
	end)

	--[[ A cube comes down on what it falls onto, not through it to y = 0
	     (`rg-slime`): the landing on a raised top is nearer, and higher,
	     than the floor's, and lies on the cube's own path. ]]
	t.test("a cube lands on a raised top before the floor", function()
		local g = settings.gravity
		local at = Vector3.new(0, 1.1, 0)
		local velocity = Vector3.new(8, 10, 0)
		local half = 0.2
		local floor = ResidueSpray.landing(at, velocity, g, 0, half)
		local log = ResidueSpray.landing(at, velocity, g, 1.5, half)
		t.notNil(floor, "a cube thrown up never comes down")
		t.notNil(log, "a cube rising over a 1.5-stud log never lands on it")
		if not floor or not log then
			return
		end
		t.near(floor.Y, 0, 1e-9)
		t.near(log.Y, 1.5, 1e-9)
		t.isTrue(
			log.X < floor.X and log.X > 0,
			"the log's landing is not on the way to the floor's"
		)
		-- where it lands, its underside touches the top
		local tFall = log.X / velocity.X
		local y = at.Y + velocity.Y * tFall - g * tFall * tFall / 2
		t.near(y - half, 1.5, 1e-4)
		-- a top above the cube's peak is never landed on
		local peak = ResidueSpray.peak(at, velocity, g)
		t.isTrue(peak > at.Y, "the peak is not above the throw")
		t.isTrue(
			ResidueSpray.landing(at, velocity, g, peak, half) == nil,
			"landed above its own peak"
		)
	end)

	--[[ One log across x 2..4, 1.5 tall: a cube that clears its side rests
	     on top; one that meets its side drops beside it, never inside. ]]
	t.test("a cube rests on cover it clears, and drops beside cover it meets", function()
		local g = settings.gravity
		local half = 0.2
		local function topAt(p: Vector3): number
			return if p.X >= 2 and p.X <= 4 then 1.5 else 0
		end
		local function sideAt(from: Vector3, along: Vector3): number?
			if along.X <= 0 or from.X >= 2 then
				return nil
			end
			return (2 - from.X) / along.Unit.X
		end
		local at = Vector3.new(0, 1.1, 0)
		local top, wall = ResidueSpray.rest(at, Vector3.new(8, 13, 0), g, half, topAt, sideAt)
		t.near(top, 1.5, 1e-9)
		t.isTrue(wall == nil, "a cube that clears the log meets its side")
		local low, stop = ResidueSpray.rest(at, Vector3.new(8, 6, 0), g, half, topAt, sideAt)
		t.near(low, 0, 1e-9)
		t.notNil(stop, "a cube thrown into the log's side flies through it")
		t.near(stop :: number, 2 - half, 1e-9)
		local short, none = ResidueSpray.rest(at, Vector3.new(3, 8, 0), g, half, topAt, sideAt)
		t.near(short, 0, 1e-9)
		t.isTrue(none == nil, "a cube that falls short meets a side")
	end)
end
