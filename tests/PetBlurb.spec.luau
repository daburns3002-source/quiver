--!strict
--[[
	What the hatchery says a pet does (`Util/PetBlurb`): every line comes
	off `Config/PetCombat`, so no number is written down twice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local PetBlurb = require(ReplicatedStorage.Shared.Util.PetBlurb)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	--[[ Thornwood's pets are modelled but have no `Config/PetCombat` entry
	     yet, so they honestly say so. The Mossy Egg's eight are finished and
	     must each describe themselves. ]]
	t.test("every Mossy Egg pet says what it does", function()
		for _, entry in EggRules.pool("MossyEgg") do
			local text = PetBlurb.text(entry.pet)
			t.isTrue(text ~= PetBlurb.NONE, `{entry.pet} has no combat spec to describe`)
		end
	end)

	t.test("a hatchable pet always has something to say", function()
		for _, egg in Eggs.list do
			for _, entry in EggRules.pool(egg.key) do
				t.isTrue(#PetBlurb.text(entry.pet) > 0, entry.pet)
			end
		end
	end)

	t.test("a pet with no spec says so rather than inventing a line", function()
		t.equal(#PetBlurb.lines("NoSuchPet"), 0)
		t.equal(PetBlurb.text("NoSuchPet"), PetBlurb.NONE)
	end)

	t.test("the numbers in a line are the spec's own", function()
		for key, spec in PetCombat.pets do
			local text = PetBlurb.text(key)
			if spec.damage then
				t.isTrue(
					string.find(text, string.format("%g", spec.damage), 1, true) ~= nil,
					`{key} does not say its damage`
				)
			end
			if spec.magnet then
				t.isTrue(string.find(text, "crystals", 1, true) ~= nil, key)
			end
			if spec.guard then
				t.isTrue(string.find(text, "Shell Guard", 1, true) ~= nil, key)
			end
		end
	end)

	t.test("a healer's patch is described once, not as plain damage", function()
		for key, spec in PetCombat.pets do
			if spec.heal and not spec.damage then
				local text = PetBlurb.text(key)
				t.isTrue(string.find(text, "healing patch", 1, true) ~= nil, key)
			end
		end
	end)
end
