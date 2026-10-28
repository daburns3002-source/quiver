--!strict
--[[
	The eggs (`Config/Eggs`, `Config/Pets`, `Util/EggRules`): every pet has a
	rarity the eggs roll and an egg that exists, an egg's chances add up to
	one with the Mythic rarest, a roll covers every pet in proportion, the
	Mossy Egg holds all twelve forest pets, and the Thornwood Egg waits for
	King Bloblin.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every pet has a rarity the eggs roll and an egg that exists", function()
		for pet, info in Pets do
			t.notNil(Eggs.odds[info.rarity], pet)
			t.notNil(EggRules.find(info.egg), pet)
		end
	end)

	t.test("the Mossy Egg holds the twelve forest pets, chances adding to one", function()
		local pool = EggRules.pool("MossyEgg")
		t.equal(#pool, 12)
		local total = 0
		local mythic = math.huge
		for _, entry in pool do
			total += entry.chance
			if entry.rarity == "Mythic" then
				mythic = entry.chance
			end
		end
		t.isTrue(math.abs(total - 1) < 1e-9, `chances add to {total}`)
		for _, entry in pool do
			t.isTrue(entry.chance >= mythic, entry.pet)
		end
	end)

	t.test("rolls follow the chances across the whole range", function()
		local pool = EggRules.pool("MossyEgg")
		local counts: { [string]: number } = {}
		local steps = 2000
		for i = 0, steps - 1 do
			local entry = EggRules.roll(pool, (i + 0.5) / steps)
			t.notNil(entry)
			if entry then
				counts[entry.pet] = (counts[entry.pet] or 0) + 1
			end
		end
		for _, entry in pool do
			local share = (counts[entry.pet] or 0) / steps
			t.isTrue(math.abs(share - entry.chance) <= 1 / steps + 1e-9, entry.pet)
		end
	end)

	t.test("the Thornwood Egg opens once King Bloblin is beaten", function()
		local egg = EggRules.find("ThornwoodEgg")
		t.notNil(egg)
		if egg then
			t.isFalse(EggRules.open(egg, {}))
			t.isTrue(EggRules.open(egg, { MossyGlade = true }))
		end
		local first = EggRules.find("MossyEgg")
		t.isTrue(first ~= nil and EggRules.open(first, {}))
	end)

	t.test("two pet slots, matching the save", function()
		t.equal(#Eggs.slots, 2)
	end)
end
