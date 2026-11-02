--!strict
--[[
	The pet rarity ladder (owner, 2026-11-02, asked for this one first).

	It had inverted without anyone noticing, because no two pets in
	`Config/PetCombat` are described in the same terms: in both eggs the
	Epic was the hardest hitter, the Mythic did less than the Common, and
	the Rare about a third of it (`docs/BALANCE-REPORT.md`, 2026-11-01).
	`Util/PetPower` puts them all on one number so this can be held.

	The rule is not that a pet matches its band to the decimal — a hold, a
	heal, a revive or a haste is paid for out of the damage, and should be.
	It is that the ladder never goes backwards, and that no pet is so far
	off its band that its rarity stops meaning anything.

	Benched pets are not checked here, since nothing can hatch them and
	they belong to no egg; `Config/PetCombat` holds them to their old egg's
	bands by hand so that putting an `egg` field back is safe.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetPower = require(ReplicatedStorage.Shared.Util.PetPower)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TestRunner = require(script.Parent.TestRunner)

--[[ Which `WeaponStats.areaScale` an egg's pets are scaled by. `Config/Eggs`
     names its area ("MossyGlade") and nothing in the game maps those names
     to the indexes `areaScale` is a list of, so it is written out here. ]]
local AREA: { [string]: number } = {
	MossyEgg = 1,
	ThornwoodEgg = 2,
}

--[[ How far off its band a pet may sit. A fifth either way: enough room for
     the utility a pet carries instead of damage, little enough that a
     rarity still means something. ]]
local SLACK = 0.2

return function(t: TestRunner.Helper)
	t.test("a pet that does no damage of its own scores nothing", function()
		--[[ Not a flaw: the guards block a hit outright, and three of the
		     Drowned Village's five are defensive on purpose. What matters
		     is that they are off the scale rather than at its bottom. ]]
		t.equal(PetPower.dps(PetCombat.pets.MossbackSnail), 0)
		t.equal(PetPower.dps(PetCombat.pets.ThistleMole), 0)
		t.equal(PetPower.dps(PetCombat.pets.SlateTurtle), 0)
		t.isTrue(PetPower.dps(PetCombat.pets.Mosslet) > 0, "a pet that fights scores")
	end)

	t.test("every hatchable pet that fights climbs with its rarity", function()
		for _, egg in Eggs.list do
			--[[ The best any lower rarity in this egg manages. ]]
			local under = 0
			local tier = 0
			local pool = EggRules.pool(egg.key)
			table.sort(pool, function(a, b)
				return Rarities.byName[a.rarity].tier < Rarities.byName[b.rarity].tier
			end)
			local most = 0
			for _, entry in pool do
				local rank = Rarities.byName[entry.rarity].tier
				if rank > tier then
					under = math.max(under, most)
					tier, most = rank, 0
				end
				local spec = PetCombat.pets[entry.pet]
				local dps = if spec then PetPower.dps(spec) else 0
				if dps > 0 then
					t.isTrue(
						dps > under,
						`{egg.key}: {entry.name} ({entry.rarity}) does {dps} a second, under the {under} a rarer pet should beat`
					)
					most = math.max(most, dps)
				end
			end
		end
	end)

	t.test("every hatchable pet that fights is near its rarity's band", function()
		for _, egg in Eggs.list do
			local area = AREA[egg.key]
			t.notNil(area, `{egg.key} has no area to scale its pets by`)
			for _, entry in EggRules.pool(egg.key) do
				local spec = PetCombat.pets[entry.pet]
				local dps = if spec then PetPower.dps(spec) else 0
				local band = PetPower.band(entry.rarity, area or 1)
				if dps > 0 and band then
					t.near(dps, band, band * SLACK, `{entry.name} ({entry.rarity})`)
				end
			end
		end
	end)

	--[[ The bands themselves, so a hand-edit to one cannot quietly flatten
	     the ladder it is there to describe. ]]
	t.test("the bands climb, and climb again by area", function()
		local order = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
		for area = 1, 3 do
			local last = 0
			for _, rarity in order do
				local band = PetPower.band(rarity, area)
				t.notNil(band, `{rarity} has no band in area {area}`)
				if band then
					t.isTrue(band > last, `{rarity} in area {area}`)
					last = band
				end
			end
		end
		local common1 = PetPower.band("Common", 1)
		local common2 = PetPower.band("Common", 2)
		t.isTrue(
			common1 ~= nil and common2 ~= nil and common2 > common1,
			"area 2 asks more of a Common than area 1"
		)
		t.isNil(PetPower.band("Uncommon", 1), "Uncommon has no band")
	end)
end
