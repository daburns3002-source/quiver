--!strict
--[[
	The Slate Turtle's Roof Huddle (`Shared/Util/Shelter`,
	`Config/PetCombat`): a cut that never heals, never blocks and is never
	always on.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local Shelter = require(ReplicatedStorage.Shared.Util.Shelter)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a shelter takes its share off, and leaves the rest", function()
		t.equal(Shelter.reduce(100, 0.2), 80)
		t.equal(Shelter.reduce(0, 0.2), 0)
		t.equal(Shelter.reduce(100, 0), 100)
	end)

	--[[ A hit under a shelter is smaller, never nothing: a wall is the
	     Snail's shell and this is deliberately not one. ]]
	t.test("a shelter never takes a whole hit, and never gives health back", function()
		for _, reduction in { -1, 0, 0.2, 0.5, 0.99, 1, 4 } do
			local left = Shelter.reduce(100, reduction)
			t.isTrue(left >= 0, `{reduction} healed`)
			t.isTrue(left <= 100, `{reduction} made it worse`)
		end
		t.equal(Shelter.reduce(100, 1), 0)
	end)

	t.test("uptime is the share of the clock it covers, capped at always", function()
		t.equal(Shelter.uptime({ reduction = 0.2, duration = 3 }, 12), 0.25)
		t.equal(Shelter.uptime({ reduction = 0.2, duration = 20 }, 12), 1)
	end)

	t.test("the average cut is the cut for as long as it is up", function()
		local shelter = { reduction = 0.5, duration = 4 }
		t.equal(Shelter.averageCut(shelter, 8), 0.25)
	end)

	--[[ A shelter that outlasted its own cooldown would be a flat damage
	     reduction with a pet drawn on it. The turtle has to tuck in and
	     come back out, or there is nothing to read. ]]
	t.test("no pet's shelter is always up", function()
		for key, spec in PetCombat.pets do
			local shelter = spec.shelter
			if shelter then
				t.isTrue(Shelter.uptime(shelter, spec.every) < 1, key)
				t.isTrue(shelter.reduction > 0 and shelter.reduction < 1, key)
			end
		end
	end)
end
