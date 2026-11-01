--!strict
--[[
	The eggs (`Config/Eggs`, `Config/Pets`, `Util/EggRules`): every pet has a
	rarity the eggs roll and an egg that exists, an egg's chances add up to
	one with the Mythic rarest, a roll covers every pet in proportion, the
	Mossy Egg holds eight of the forest pets, and both eggs are open from the
	start for now. Also the models: every one has a pet behind it, and every
	Legendary and Mythic among them wears its aura.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local PetAuras = require(ReplicatedStorage.Shared.Config.PetAuras)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	--[[ A pet with no egg is benched, not broken (eight to an egg): what
	     must hold is that nobody points at an egg that is not there. ]]
	t.test("every pet has a rarity the eggs roll, and any egg it names exists", function()
		for pet, info in Pets do
			t.notNil(Eggs.odds[info.rarity], pet)
			if info.egg then
				t.notNil(EggRules.find(info.egg), pet)
			end
		end
	end)

	--[[ A model with no `Config/Pets` row would never hatch and never show
	     a name: `Util/EggRules` reads the pool from `Pets`, not from the
	     models folder. ]]
	t.test("every pet model has a pet behind it", function()
		for _, model in ReplicatedStorage.Shared.Config.PetModels:GetChildren() do
			t.notNil(Pets[model.Name], model.Name)
		end
	end)

	--[[ Owner's standing rule: every Legendary and Mythic glows, and a
	     Mythic's glow is the rainbow (`Config/PetAuras`). ]]
	t.test("every modelled Legendary and Mythic wears an aura", function()
		for _, model in ReplicatedStorage.Shared.Config.PetModels:GetChildren() do
			local info = Pets[model.Name]
			if not info or (info.rarity ~= "Legendary" and info.rarity ~= "Mythic") then
				continue
			end
			local look = PetAuras.looks[PetAuras.pets[model.Name]]
			t.notNil(look, model.Name)
			if look and info.rarity == "Mythic" then
				t.notNil(look.rainbow, model.Name)
			end
		end
	end)

	--[[ Drowned Village (docs/PETS-DROWNED.md): five imported, benched
	     until the egg has its eight and its hatch art. ]]
	t.test("the Drowned Village's five are modelled and benched", function()
		for _, pet in { "SlateTurtle", "BuoyPuffer", "Inkpot", "TideWilf", "AbyssJelly" } do
			t.notNil(Pets[pet], pet)
			t.notNil(ReplicatedStorage.Shared.Config.PetModels:FindFirstChild(pet), pet)
			if Pets[pet] then
				t.isNil(Pets[pet].egg, pet)
			end
		end
	end)

	t.test("every egg holds eight pets, chances adding to one", function()
		for _, egg in Eggs.list do
			t.equal(#EggRules.pool(egg.key), 8, egg.key)
		end
		local pool = EggRules.pool("MossyEgg")
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

	--[[ Both eggs are open from the start for now (owner, 2026-10-27: "the
	     mossy glade egg and thornwood egg should be unlocked for now"), so
	     what is pinned here is that neither asks for a boss, and that the
	     gate still works for the egg that takes one up when `unlock` comes
	     back. ]]
	t.test("both eggs are open from the start", function()
		for _, key in { "MossyEgg", "ThornwoodEgg" } do
			local egg = EggRules.find(key)
			t.notNil(egg, key)
			if egg then
				t.isTrue(EggRules.open(egg, {}), key)
			end
		end
	end)

	t.test("an egg with an unlock stays shut until its boss is beaten", function()
		local gated =
			{ key = "x", name = "X", area = "Thornwood", price = 1, unlock = "MossyGlade" }
		t.isFalse(EggRules.open(gated :: any, {}))
		t.isTrue(EggRules.open(gated :: any, { MossyGlade = true }))
	end)

	t.test("two pet slots, matching the save", function()
		t.equal(#Eggs.slots, 2)
	end)
end
