--!strict
--[[
	The Bogheart Caverns pets' targeting (`Shared/Util/PetCrowd`,
	`Config/PetCombat`): who is furthest, who is in a crowd, what a sneeze
	covers and where a prism's shards go.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetCrowd = require(ReplicatedStorage.Shared.Util.PetCrowd)
local TestRunner = require(script.Parent.TestRunner)

local function spot(x: number, z: number): PetCrowd.Spot
	return { model = Instance.new("Model"), position = Vector3.new(x, 0, z) }
end

return function(t: TestRunner.Helper)
	t.test("around counts the crowd round an enemy, leaving it out", function()
		local a, b, c = spot(0, 0), spot(3, 0), spot(20, 0)
		local near = PetCrowd.around({ a, b, c }, a.position, 8, a.model)
		t.equal(#near, 1)
		t.equal(near[1], b)
		-- height never decides who is in a crowd
		local high = { model = Instance.new("Model"), position = Vector3.new(2, 40, 0) }
		t.equal(#PetCrowd.around({ high }, Vector3.zero, 3, nil), 1)
	end)

	t.test("the cricket picks the furthest enemy", function()
		local a, b, c = spot(5, 0), spot(0, 30), spot(-12, 0)
		t.equal(PetCrowd.farthest({ a, b, c }, Vector3.zero), b)
		t.isNil(PetCrowd.farthest({}, Vector3.zero))
	end)

	t.test("the flop lands on the biggest crowd, the nearest on a tie", function()
		local lone = spot(2, 0)
		local p1, p2, p3 = spot(30, 0), spot(32, 0), spot(30, 2)
		t.equal(PetCrowd.densest({ lone, p1, p2, p3 }, 7), p1)
		local x, y = spot(1, 0), spot(40, 0)
		t.equal(PetCrowd.densest({ x, y }, 7), x)
	end)

	t.test("every fourth lick is the hard one, and it averages out", function()
		local combo = { every = 4, scale = 3 }
		t.equal(PetCrowd.comboScale(combo, 1), 1)
		t.equal(PetCrowd.comboScale(combo, 3), 1)
		t.equal(PetCrowd.comboScale(combo, 4), 3)
		t.equal(PetCrowd.comboScale(combo, 8), 3)
		t.equal(PetCrowd.comboAverage(combo), 1.5)
	end)

	t.test("a crowd bite grows with the crowd, up to its cap, never below plain", function()
		local crowd = { radius = 8, per = 0.25, most = 4 }
		t.equal(PetCrowd.crowdScale(crowd, 0), 1)
		t.equal(PetCrowd.crowdScale(crowd, 2), 1.5)
		t.equal(PetCrowd.crowdScale(crowd, 4), 2)
		t.equal(PetCrowd.crowdScale(crowd, 9), 2)
		t.equal(PetCrowd.crowdScale(crowd, -3), 1)
	end)

	t.test("a sneeze covers its wedge and nothing behind or past it", function()
		local origin, toward = Vector3.zero, Vector3.new(0, 0, 10)
		t.isTrue(PetCrowd.inCone(origin, toward, Vector3.new(0, 0, 8), 60, 16), "dead ahead")
		t.isTrue(PetCrowd.inCone(origin, toward, Vector3.new(4, 0, 8), 60, 16), "inside the edge")
		t.isTrue(
			not PetCrowd.inCone(origin, toward, Vector3.new(8, 0, 4), 60, 16),
			"outside the edge"
		)
		t.isTrue(not PetCrowd.inCone(origin, toward, Vector3.new(0, 0, -5), 60, 16), "behind")
		t.isTrue(not PetCrowd.inCone(origin, toward, Vector3.new(0, 0, 20), 60, 16), "too far")
	end)

	t.test("shards go to the nearest others, never back to the struck one", function()
		local split = { shards = 3, share = 0.5, radius = 12 }
		local hit = spot(0, 0)
		local a, b, c, d, far = spot(2, 0), spot(4, 0), spot(6, 0), spot(8, 0), spot(30, 0)
		local shards =
			PetCrowd.shardTargets(split, { hit, d, a, far, c, b }, hit.position, hit.model)
		t.equal(#shards, 3)
		t.equal(shards[1], a)
		t.equal(shards[2], b)
		t.equal(shards[3], c)
		t.equal(#PetCrowd.shardTargets(split, { hit }, hit.position, hit.model), 0)
	end)

	t.test("each Bogheart rule belongs to the pet it was made for", function()
		t.isTrue(PetCombat.pets.CaveCricket.farthest == true, "CaveCricket")
		t.notNil(PetCombat.pets.LichenGecko.combo, "LichenGecko")
		t.notNil(PetCombat.pets.Lanternfin.burst, "Lanternfin")
		t.notNil(PetCombat.pets.Olm.crowd, "Olm")
		t.notNil(PetCombat.pets.GlowcapWilf.cone, "GlowcapWilf")
		t.notNil(PetCombat.pets.Gulpling.flop, "Gulpling")
		t.notNil(PetCombat.pets.PrismLeviathan.split, "PrismLeviathan")
	end)
end
