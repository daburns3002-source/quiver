--!strict
--[[
	The Abyss Jelly's Deep Accord (`Shared/Util/DeepAccord`,
	`Config/PetCombat`): a blow spread over a canopy, and never made bigger
	by it. The invariant this file exists for is the total.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeepAccord = require(ReplicatedStorage.Shared.Util.DeepAccord)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a blow is shared evenly between those under the canopy", function()
		t.equal(DeepAccord.share(300, 3), 100)
		t.equal(DeepAccord.share(300, 2), 150)
	end)

	t.test("one enemy alone takes the whole blow", function()
		t.equal(DeepAccord.share(300, 1), 300)
		t.equal(DeepAccord.share(300, 0), 300)
	end)

	--[[ The one rule that matters. A canopy that multiplied damage would
	     make this Mythic the strongest thing in the game without anybody
	     being able to see why. ]]
	t.test("the canopy never adds damage, whatever it holds", function()
		for _, amount in { 1, 37.5, 300, 10000 } do
			for living = 1, 8 do
				local total = DeepAccord.total(amount, living)
				t.isTrue(math.abs(total - amount) < 1e-9, `{amount} over {living} became {total}`)
			end
		end
	end)

	--[[ A canopy of one is a canopy that does nothing; it has to reach
	     past the enemy that was struck to be worth a Mythic slot. ]]
	t.test("every pet's canopy holds more than the enemy it was cast on", function()
		for key, spec in PetCombat.pets do
			local accord = spec.accord
			if accord then
				t.isTrue(accord.targets >= 2, key)
				t.isTrue(accord.duration > 0, key)
				--[[ And it adds nothing itself: a canopy that also hit
				     would be doing the multiplying by the back door. ]]
				t.isNil(spec.damage, key)
			end
		end
	end)
end
