--!strict
--[[
	The Bog Beaver's Mud Plaster (`Shared/Util/MudCoat`, `Config/PetCombat`):
	a pool that soaks hits until it is spent, never a whole-hit block and
	never a heal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MudCoat = require(ReplicatedStorage.Shared.Util.MudCoat)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetPower = require(ReplicatedStorage.Shared.Util.PetPower)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("small hits vanish into the coat until it is spent", function()
		local through, left = MudCoat.soak(60, 25)
		t.equal(through, 0)
		t.equal(left, 35)
		through, left = MudCoat.soak(left, 25)
		t.equal(through, 0)
		t.equal(left, 10)
		through, left = MudCoat.soak(left, 25)
		t.equal(through, 15)
		t.equal(left, 0)
	end)

	t.test("a big hit breaks through with what the mud could not hold", function()
		local through, left = MudCoat.soak(60, 100)
		t.equal(through, 40)
		t.equal(left, 0)
	end)

	t.test("a spent coat does nothing, and nothing goes below zero", function()
		local through, left = MudCoat.soak(0, 30)
		t.equal(through, 30)
		t.equal(left, 0)
		through, left = MudCoat.soak(-5, 30)
		t.equal(through, 30)
		t.equal(left, 0)
		through, left = MudCoat.soak(20, -4)
		t.equal(through, 0)
		t.equal(left, 20)
	end)

	t.test("the Bog Beaver shelters and is off the damage scale", function()
		local spec = PetCombat.pets.BogBeaver
		t.notNil(spec.coat, "the beaver plasters")
		t.isNil(spec.damage, "the beaver does no damage of its own")
		t.equal(PetPower.dps(spec), 0)
		if spec.coat then
			t.isTrue(MudCoat.perSecond(spec.coat, spec.every) > 0, "it saves something")
		end
	end)
end
