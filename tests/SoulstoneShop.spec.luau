--!strict
--[[
	The Soulstone shop (`Config/SoulstoneShop`, `Util/SoulstoneShopRules`,
	paid through `Util/Purse`): Soulstones buy eggs and crates (owner,
	2026-11-11). Held here: what is for sale is exactly what the player may
	have, a purchase the rules do not offer is refused, and Soulstones are
	taken whole or not at all.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Config = require(ReplicatedStorage.Shared.Config.SoulstoneShop)
local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Purse = require(ReplicatedStorage.Shared.Util.Purse)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local SoulstoneShopRules = require(ReplicatedStorage.Shared.Util.SoulstoneShopRules)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a new player has something to buy, and a full run can afford it", function()
		for _, chest in Shop.chests do
			local offers = SoulstoneShopRules.offers({}, chest.class)
			t.isTrue(#offers >= 2, `a {chest.class} is offered an egg and a crate`)
			local cheapest = math.huge
			for _, offer in offers do
				cheapest = math.min(cheapest, offer.price)
				t.isTrue(offer.price > 0, `{offer.name} is free`)
			end
			t.isTrue(
				cheapest <= Balance.Endless.runCap,
				"the cheapest thing costs more than a whole run can pay"
			)
		end
	end)

	t.test("everything offered is something the player may have", function()
		for _, chest in Shop.chests do
			for _, offer in SoulstoneShopRules.offers({}, chest.class) do
				if offer.kind == "Egg" then
					local egg = EggRules.find(offer.key)
					t.notNil(egg, `{offer.key} is not an egg`)
					if egg then
						t.isTrue(EggRules.open(egg, {}), `{offer.key} is not open to them`)
						t.isTrue(#EggRules.pool(offer.key) > 0, `{offer.key} is empty`)
					end
				else
					local index = tonumber(offer.key)
					t.notNil(index, "a crate's key is its place")
					if index then
						t.isTrue(#ShopRules.cratePool(index, chest.class) > 0, "an empty crate")
					end
				end
			end
		end
	end)

	t.test("each area costs double the one before it", function()
		t.equal(SoulstoneShopRules.price(1), Config.base)
		t.equal(SoulstoneShopRules.price(2), Config.base * 2)
		t.equal(SoulstoneShopRules.price(4), Config.base * 8)
		t.equal(SoulstoneShopRules.price(0), Config.base, "never under the base")
	end)

	t.test("only a listed offer and a listed count can be bought", function()
		local offers = SoulstoneShopRules.offers({}, "Ranger")
		local first = offers[1]
		t.notNil(SoulstoneShopRules.find({}, "Ranger", first.kind, first.key))
		t.isNil(SoulstoneShopRules.find({}, "Ranger", "Egg", "NoSuchEgg"))
		t.isNil(SoulstoneShopRules.find({}, "Ranger", "Gems", first.key))
		t.isNil(SoulstoneShopRules.find({}, "Ranger", first.kind, 1), "a number is not a key")
		t.isNil(SoulstoneShopRules.find({}, "Ranger", nil, nil))
		for _, count in Config.counts do
			t.isTrue(SoulstoneShopRules.countAllowed(count))
		end
		t.isFalse(SoulstoneShopRules.countAllowed(0))
		t.isFalse(SoulstoneShopRules.countAllowed(-5))
		t.isFalse(SoulstoneShopRules.countAllowed(1.5))
		t.isFalse(SoulstoneShopRules.countAllowed(1e9))
		t.isFalse(SoulstoneShopRules.countAllowed("5"))
		t.isFalse(SoulstoneShopRules.countAllowed(0 / 0))
	end)

	t.test("Soulstones are paid whole or not at all", function()
		local p = SaveSchema.default()
		p.soulstones = 250
		p.coins = 40
		t.isFalse(Purse.pay(p, { soulstones = 251 }), "paid more than is held")
		t.equal(p.soulstones, 250, "a refused price took something")
		t.isFalse(Purse.pay(p, { soulstones = 100, coins = 50 }), "paid with coins it has not")
		t.equal(p.soulstones, 250)
		t.equal(p.coins, 40)
		t.isTrue(Purse.pay(p, { soulstones = 100 }))
		t.equal(p.soulstones, 150)
		t.isTrue(Purse.pay(p, { coins = 40 }), "a price with no Soulstones still pays")
		t.equal(p.soulstones, 150, "coins took Soulstones")
	end)
end
