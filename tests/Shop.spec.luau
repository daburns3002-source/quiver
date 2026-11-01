--!strict
--[[
	The weapon shop's rules (`Config/Shop`, `Util/ShopRules`): the owner's
	crate prices, what a crate can give (Uncommon, Rare, Epic, a small Mythic
	chance; never a Legendary or a class weapon), what the store charges
	(gems; a Legendary coins and its boss's items; never a Mythic), and that
	a roll covers every rarity in proportion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the crates cost 500, 1,000, 2,000, 4,000, 10,000, 20,000", function()
		local prices = { 500, 1000, 2000, 4000, 10000, 20000 }
		t.equal(#Shop.crates, #prices)
		for i, price in prices do
			t.equal(Shop.crates[i].price, price)
		end
	end)

	t.test("the Mossy Glade crate holds Uncommon to Epic and Mythic, nothing else", function()
		local pool = ShopRules.cratePool(1)
		t.isTrue(#pool > 0)
		local seen: { [string]: boolean } = {}
		for _, entry in pool do
			t.isTrue(entry.rarity ~= "Legendary" and entry.rarity ~= "Common", entry.weapon)
			seen[entry.rarity] = true
		end
		for _, rarity in { "Uncommon", "Rare", "Epic", "Mythic" } do
			t.isTrue(seen[rarity], `no {rarity} in the crate`)
		end
	end)

	t.test("Mythic is the rarest roll", function()
		for rarity, weight in Shop.crateOdds do
			if rarity ~= "Mythic" then
				t.isTrue(Shop.crateOdds.Mythic < weight, rarity)
			end
		end
	end)

	t.test("rolls follow the odds across the whole range", function()
		local pool = ShopRules.cratePool(1)
		local counts: { [string]: number } = {}
		local steps = 1000
		for i = 0, steps - 1 do
			local entry = ShopRules.roll(pool, (i + 0.5) / steps, 0.5)
			t.notNil(entry)
			if entry then
				counts[entry.rarity] = (counts[entry.rarity] or 0) + 1
			end
		end
		local total = 0
		for _, weight in Shop.crateOdds do
			total += weight
		end
		for rarity, weight in Shop.crateOdds do
			t.near((counts[rarity] or 0) / steps, weight / total, 0.01, rarity)
		end
	end)

	--[[ Three chests to an area, one a class (owner, 2026-11-01: "It
	     should be 3 separate chests"). ]]
	t.test("each chest holds one class, and the three are the whole crate", function()
		local whole = ShopRules.cratePool(1)
		local counted = 0
		for _, chest in Shop.chests do
			local pool = ShopRules.cratePool(1, chest.class)
			t.isTrue(#pool > 0, `{chest.name}: an empty chest`)
			for _, entry in pool do
				t.equal(entry.class, chest.class, entry.weapon)
			end
			counted += #pool
		end
		t.equal(counted, #whole, "the three chests are the crate, no more and no less")
	end)

	--[[ The reason `crateOdds.Mythic` is 1 and not 3: a chest holds one
	     class, so one Mythic, and choosing a class must not treble the
	     chance of pulling one (owner, 2026-10-28: "make the odds of
	     pulling a mythic 1%"). ]]
	t.test("a Mythic is about 1% of an open, from any chest", function()
		for _, chest in Shop.chests do
			local pool = ShopRules.cratePool(1, chest.class)
			local mythic = nil
			for _, entry in pool do
				if entry.rarity == "Mythic" then
					mythic = entry
				end
			end
			t.notNil(mythic, `{chest.name}: no Mythic in the chest`)
			if mythic then
				t.near(ShopRules.chance(1, mythic, chest.class), 0.01, 0.003, chest.name)
			end
		end
	end)

	t.test("only the three chests can be opened", function()
		for _, chest in Shop.chests do
			t.notNil(ShopRules.chest(chest.class), chest.class)
		end
		t.isNil(ShopRules.chest("Assassin"), "a class with no weapons is no chest")
		t.isNil(ShopRules.chest(nil))
		t.isNil(ShopRules.chest(7))
	end)

	t.test("areas with no weapons have an empty crate (a silhouette)", function()
		for index = 2, #Shop.crates do
			local pool = ShopRules.cratePool(index)
			t.isNil(ShopRules.roll(pool, 0.5, 0.5))
		end
	end)

	t.test(
		"the store: gems by rarity, Legendaries for coins and 3 boss items, no Mythics",
		function()
			for _, entry in ShopRules.catalog() do
				local price = ShopRules.price(entry)
				if entry.rarity == "Legendary" then
					t.notNil(price, entry.weapon)
					local item = Economy.areas[Shop.crates[entry.area].area].bossItem
					t.isTrue(price ~= nil and (price.coins or 0) > 0, entry.weapon)
					t.equal(price and price.items and price.items[item], Shop.legendaryItems)
				elseif entry.rarity == "Mythic" or entry.rarity == "Common" then
					t.isNil(price, entry.weapon)
				else
					t.isTrue(price ~= nil and (price.gems or 0) > 0, entry.weapon)
				end
			end
		end
	)

	t.test("a duplicate pays back part of the crate, never all of it", function()
		t.isTrue(ShopRules.refund(1) > 0 and ShopRules.refund(1) < Shop.crates[1].price)
	end)

	t.test("every weapon a player can own has its 2D icon, and every boss item too", function()
		for _, entry in ShopRules.catalog() do
			t.notNil(ShopAssets.weapons[entry.weapon], entry.weapon)
		end
		for id in Economy.items do
			t.notNil(ShopAssets.items[id], id)
		end
	end)
end
