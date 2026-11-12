--!strict
--[[
	Endless milestones pay in eggs and crates (`Balance.Endless.milestones`,
	`Util/PrizeRules`; owner, 2026-11-11: "MAKE IT MORE LIKE 5 EGGS AND 5
	CRATES ... I WANT IT TO FEEL NECESSARY TO BEAT THESE ROOMS"). Held here:
	every milestone gives something real and says so truthfully, and a
	guarantee can always be met from the pools the game has.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local PrizeRules = require(ReplicatedStorage.Shared.Util.PrizeRules)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every milestone gives at least five of something real", function()
		local last = 0
		for _, milestone in Balance.Endless.milestones do
			t.isTrue(milestone.floor > last, "milestones are in floor order")
			last = milestone.floor
			local eggs, crates = milestone.eggs or 0, milestone.crates or 0
			t.isTrue(eggs + crates >= 5, `floor {milestone.floor} gives fewer than five`)
			t.isTrue(milestone.soulstones > 0, `floor {milestone.floor} pays no Soulstones`)
			if milestone.rarity then
				t.notNil(EggRules.ORDER[milestone.rarity], `{milestone.rarity} is not a rarity`)
			end
		end
	end)

	t.test("a milestone's name says what it gives", function()
		for _, milestone in Balance.Endless.milestones do
			local name = milestone.name
			local eggs, crates = milestone.eggs or 0, milestone.crates or 0
			t.equal(string.find(name, "EGG") ~= nil, eggs > 0, `{name}: eggs`)
			t.equal(string.find(name, "CRATE") ~= nil, crates > 0, `{name}: crates`)
			if eggs > 0 then
				t.notNil(string.find(name, tostring(eggs), 1, true), `{name} hides its {eggs} eggs`)
			end
			if crates > 0 then
				t.notNil(
					string.find(name, tostring(crates), 1, true),
					`{name} hides its {crates} crates`
				)
			end
		end
	end)

	t.test("a new player has an egg and a crate to be given", function()
		local key = PrizeRules.eggKey({})
		t.notNil(key, "no egg is open to a brand-new player")
		if key then
			t.isTrue(#EggRules.pool(key) > 0, "the prize egg has pets in it")
		end
		for _, chest in Shop.chests do
			local index = PrizeRules.crateIndex(chest.class)
			t.notNil(index, `no crate has weapons for a {chest.class}`)
			if index then
				t.isTrue(#ShopRules.cratePool(index, chest.class) > 0)
			end
		end
	end)

	t.test("the prize egg is the furthest one open", function()
		local everything = {}
		for _, egg in Eggs.list do
			everything[egg.area] = true
		end
		local best = PrizeRules.eggKey(everything)
		local expected: string? = nil
		for _, egg in Eggs.list do
			if #EggRules.pool(egg.key) > 0 then
				expected = egg.key
			end
		end
		t.equal(best, expected)
	end)

	t.test("a guarantee gives the named rarity when the pool has it", function()
		local pool = {
			{ rarity = "Common" },
			{ rarity = "Rare" },
			{ rarity = "Legendary" },
			{ rarity = "Legendary" },
			{ rarity = "Mythic" },
		}
		local sure = PrizeRules.guaranteed(pool, "Legendary")
		t.equal(#sure, 2, "both Legendaries, and not the Mythic")
		for _, entry in sure do
			t.equal(entry.rarity, "Legendary")
		end
		t.equal(PrizeRules.guaranteed(pool, "Mythic")[1].rarity, "Mythic")
		t.equal(PrizeRules.guaranteed(pool, "Epic")[1].rarity, "Legendary", "the next one up")
	end)

	t.test("a guarantee the pool cannot meet gives its best, never nothing", function()
		local pool = { { rarity = "Common" }, { rarity = "Rare" } }
		local sure = PrizeRules.guaranteed(pool, "Mythic")
		t.equal(#sure, 1)
		t.equal(sure[1].rarity, "Rare")
	end)

	t.test("every milestone's guarantee can be met from the real pools", function()
		for _, milestone in Balance.Endless.milestones do
			local least = milestone.rarity
			if least then
				if (milestone.eggs or 0) > 0 then
					for _, egg in Eggs.list do
						local pool = EggRules.pool(egg.key)
						if #pool > 0 then
							t.isTrue(#PrizeRules.guaranteed(pool, least) > 0, egg.key)
						end
					end
				end
				if (milestone.crates or 0) > 0 then
					for _, chest in Shop.chests do
						local index = PrizeRules.crateIndex(chest.class)
						if index then
							local pool = ShopRules.cratePool(index, chest.class)
							t.isTrue(#PrizeRules.guaranteed(pool, least) > 0, chest.class)
						end
					end
				end
			end
		end
	end)
end
