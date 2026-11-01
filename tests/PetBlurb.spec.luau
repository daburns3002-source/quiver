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
	--[[ Drowned Village: each of the five has a spec, and each says
	     something. A pet that fought but said nothing would show the
	     hatchery's "no combat behaviour yet" beside an attack that works. ]]
	t.test("the Drowned Village five each fight and each say so", function()
		for _, key in { "SlateTurtle", "BuoyPuffer", "Inkpot", "TideWilf", "AbyssJelly" } do
			t.notNil(PetCombat.pets[key], key)
			local lines = PetBlurb.lines(key)
			t.isTrue(#lines > 0, key)
			t.isTrue(PetBlurb.text(key) ~= PetBlurb.NONE, key)
		end
	end)

	--[[ Three of the five do no damage at all, which is the point of them;
	     what must not happen is one that does nothing whatsoever. ]]
	t.test("every pet that fights does something a line can describe", function()
		for key in PetCombat.pets do
			t.isTrue(#PetBlurb.lines(key) > 0, key)
		end
	end)

	--[[ Both areas' pets are finished now (Thornwood's got their combat in
	     2026-10-31), so nothing a player can hatch may shrug. ]]
	t.test("every pet a player can hatch says what it does", function()
		for _, egg in Eggs.list do
			for _, entry in EggRules.pool(egg.key) do
				local text = PetBlurb.text(entry.pet)
				t.isTrue(text ~= PetBlurb.NONE, `{entry.pet} has no combat spec to describe`)
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

	--[[ A pet whose only damage comes off a block or out of a ring says so:
	     the damage branch reads `spec.damage`, which neither of them has, so
	     without their own lines they would describe themselves as doing
	     nothing (the Thistle Mole and Thornwake, owner 2026-10-31). ]]
	t.test("a pet that hits without a `damage` number still says what it hits for", function()
		for key, spec in PetCombat.pets do
			local text = PetBlurb.text(key)
			local reflect = spec.reflect
			if reflect then
				t.isTrue(
					string.find(text, string.format("%g", reflect.damage), 1, true) ~= nil,
					`{key} bursts thorns without saying for how much`
				)
			end
			local aura = spec.aura
			if aura then
				t.isTrue(
					string.find(text, string.format("%g", aura.damage), 1, true) ~= nil,
					`{key}'s ring does not say its damage`
				)
			end
		end
	end)

	t.test("a cage says a boss can be held, and a plain hold says it cannot", function()
		for key, spec in PetCombat.pets do
			local hold = spec.root
			if not hold then
				continue
			end
			local text = PetBlurb.text(key)
			local cages = string.find(text, "Even a boss", 1, true) ~= nil
			t.equal(cages, hold.boss > 0, `{key}: what it says about bosses is not what it does`)
		end
	end)

	t.test("thorns that stack say the stack, the rate and what it comes to", function()
		for key, spec in PetCombat.pets do
			local bleed = spec.bleed
			if not bleed then
				continue
			end
			local text = PetBlurb.text(key)
			for _, number in { bleed.stacks, bleed.rate, bleed.rate * bleed.stacks } do
				t.isTrue(
					string.find(text, string.format("%g", number), 1, true) ~= nil,
					`{key}'s thorns do not say {number}`
				)
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
