--!strict
--[[
	The purchase burst's rules (`Util/PurchaseRules`, `Config/PurchaseFx`):
	what a price paid becomes, how big its burst is, and where it comes
	from on the screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PurchaseFx)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local PurchaseRules = require(ReplicatedStorage.Shared.Util.PurchaseRules)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a price paid becomes a receipt in what it was paid in", function()
		local coins = PurchaseRules.fromCost({ coins = 500 })
		t.equal(coins and coins.paid, "coins")
		t.equal(coins and coins.amount, 500)
		local gems = PurchaseRules.fromCost({ gems = 180 }, "Rare")
		t.equal(gems and gems.paid, "gems")
		t.equal(gems and gems.rarity, "Rare")
		local stones = PurchaseRules.fromCost({ soulstones = 100 })
		t.equal(stones and stones.paid, "soulstones")
		-- a Legendary's price is coins and boss items: the coins lead
		local both = PurchaseRules.fromCost({ coins = 3000, items = { Crown = 3 } }, "Legendary")
		t.equal(both and both.paid, "coins")
		t.equal(both and both.amount, 3000)
	end)

	t.test("a price of nothing is no purchase", function()
		t.isNil(PurchaseRules.fromCost({}))
		t.isNil(PurchaseRules.fromCost({ coins = 0, gems = 0 }))
		t.isNil(PurchaseRules.fromCost({ coins = -5 }))
		t.isNil(PurchaseRules.fromCost({ coins = 0 / 0 }))
	end)

	t.test("the cheapest egg is a small burst and a costly one a big one", function()
		local cheapest = math.huge
		for _, egg in Eggs.list do
			cheapest = math.min(cheapest, egg.price)
		end
		t.equal(PurchaseRules.size({ paid = "coins", amount = cheapest }), "small")
		t.equal(PurchaseRules.size({ paid = "coins", amount = Config.big.coins - 1 }), "small")
		t.equal(PurchaseRules.size({ paid = "coins", amount = Config.big.coins }), "big")
		t.equal(PurchaseRules.size({ paid = "gems", amount = Config.big.gems }), "big")
		t.equal(PurchaseRules.size({ paid = "soulstones", amount = Config.big.soulstones }), "big")
		t.equal(PurchaseRules.size({ paid = "gems", amount = 58 }), "small")
	end)

	t.test("Robux and a Legendary bought outright are the biggest", function()
		for _, product in RobuxStore.products do
			t.equal(PurchaseRules.size(PurchaseRules.robux(product.robux)), "huge", product.key)
		end
		for _, pass in RobuxStore.passes do
			t.equal(PurchaseRules.size(PurchaseRules.robux(pass.robux)), "huge", pass.key)
		end
		t.equal(PurchaseRules.size({ paid = "coins", amount = 1, rarity = "Legendary" }), "huge")
		t.equal(PurchaseRules.size({ paid = "gems", amount = 1, rarity = "Mythic" }), "huge")
		t.equal(PurchaseRules.size({ paid = "gems", amount = 1, rarity = "Epic" }), "small")
	end)

	t.test("each size is bigger than the one under it", function()
		local small, big, huge = Config.sizes.small, Config.sizes.big, Config.sizes.huge
		for _, field in { "pieces", "sparks", "reach", "piece", "wordHeight", "length" } do
			local a, b, c = (small :: any)[field], (big :: any)[field], (huge :: any)[field]
			t.isTrue(a < b and b < c, field)
		end
		t.isTrue(small.rings <= big.rings and big.rings <= huge.rings)
		-- about a second, and never a long wait
		t.isTrue(small.length >= 0.6 and huge.length <= 1.5)
		-- a wash, never a white-out
		t.isTrue(huge.flash <= 0.3)
		t.equal(PurchaseRules.look({ paid = "coins", amount = 1 }), small)
		t.equal(PurchaseRules.look(PurchaseRules.robux(99)), huge)
	end)

	t.test("the sound is one the game has", function()
		local sound = Sounds[Config.sound]
		t.notNil(sound)
		t.isTrue(sound.id ~= "")
	end)

	t.test("only a receipt is read as one", function()
		t.isNil(PurchaseRules.read(nil))
		t.isNil(PurchaseRules.read("coins"))
		t.isNil(PurchaseRules.read({ paid = "robots", amount = 5 }))
		t.isNil(PurchaseRules.read({ paid = "coins" }))
		t.isNil(PurchaseRules.read({ paid = "coins", amount = "many" }))
		t.isNil(PurchaseRules.read({ paid = "coins", amount = -3 }))
		local read = PurchaseRules.read({ paid = "gems", amount = 450.9, rarity = 7 })
		t.equal(read and read.paid, "gems")
		t.equal(read and read.amount, 450)
		t.isNil(read and read.rarity)
		t.notNil(PurchaseRules.read(PurchaseRules.robux(0)))
	end)

	t.test("the price leaves the wallet with its commas, and Robux has none", function()
		t.equal(PurchaseRules.tag({ paid = "coins", amount = 500 }), "-500")
		t.equal(PurchaseRules.tag({ paid = "coins", amount = 12000 }), "-12,000")
		t.equal(PurchaseRules.tag({ paid = "gems", amount = 1234567 }), "-1,234,567")
		t.isNil(PurchaseRules.tag(PurchaseRules.robux(99)))
	end)

	t.test("the burst comes from a fresh press, else the middle", function()
		local coins: PurchaseRules.Receipt = { paid = "coins", amount = 500 }
		local x, y = PurchaseRules.origin(coins, 1920, 1080, 300, 900, 0.2)
		t.equal(x, 300)
		t.equal(y, 900)
		local cx, cy = 1920 * Config.centre[1], 1080 * Config.centre[2]
		-- a stale press
		x, y = PurchaseRules.origin(coins, 1920, 1080, 300, 900, Config.pressAge + 1)
		t.equal(x, cx)
		t.equal(y, cy)
		-- no press at all (a gamepad)
		x, y = PurchaseRules.origin(coins, 1920, 1080, nil, nil, nil)
		t.equal(x, cx)
		-- a press off the screen
		x, y = PurchaseRules.origin(coins, 1920, 1080, 2500, 900, 0.2)
		t.equal(x, cx)
		-- Robux: the last press was on Roblox's prompt
		x, y = PurchaseRules.origin(PurchaseRules.robux(99), 1920, 1080, 300, 900, 0.2)
		t.equal(x, cx)
		t.equal(y, cy)
	end)

	t.test("a sheet pixel is the same share of either layout", function()
		t.equal(PurchaseRules.unit(1920, 1080), 1)
		t.equal(PurchaseRules.unit(1080, 1920), 1)
		t.equal(PurchaseRules.unit(960, 540), 0.5)
		t.near(PurchaseRules.unit(390, 844), 390 / 1080, 1e-6)
		t.isTrue(PurchaseRules.unit(0, 0) > 0)
	end)

	t.test("the word is kept on the screen", function()
		local x, y = PurchaseRules.keepIn(40, 30, 400, 100, 1080, 1920, 20)
		t.equal(x, 220)
		t.equal(y, 70)
		x, y = PurchaseRules.keepIn(1060, 1900, 400, 100, 1080, 1920, 20)
		t.equal(x, 860)
		t.equal(y, 1850)
		x, y = PurchaseRules.keepIn(500, 600, 400, 100, 1080, 1920, 20)
		t.equal(x, 500)
		t.equal(y, 600)
		-- wider than the screen: centred
		x = PurchaseRules.keepIn(10, 600, 2000, 100, 1080, 1920, 20)
		t.equal(x, 540)
	end)
end
