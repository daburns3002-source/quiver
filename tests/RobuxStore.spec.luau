--!strict
-- The Robux store's rules (`Config/RobuxStore`, `Util/StoreRules`). Prices
-- are the owner's starting numbers: these hold what must stay true when
-- they are tuned.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every product and pass is named once, priced, and numbered", function()
		local seen: { [string]: boolean } = {}
		local ids: { [number]: string } = {}
		local all: { any } = {}
		for _, product in RobuxStore.products do
			table.insert(all, product)
		end
		for _, pass in RobuxStore.passes do
			table.insert(all, pass)
		end
		for _, item in all do
			t.isFalse(seen[item.key] == true, `{item.key} is named twice`)
			seen[item.key] = true
			t.isTrue(item.robux > 0 and item.robux == math.floor(item.robux), `{item.key}'s price`)
			t.isTrue(item.id >= 0 and item.id == math.floor(item.id), `{item.key}'s id`)
			if item.id > 0 then
				t.isNil(ids[item.id], `{item.key} shares an id with {ids[item.id]}`)
				ids[item.id] = item.key
			end
			t.isTrue(#item.name > 0 and #item.description > 0, `{item.key} needs words`)
		end
	end)

	t.test("a bigger gem pack is never worse value", function()
		local last = 0
		local lastPrice = 0
		for _, product in RobuxStore.products do
			if product.art == "gem" then
				local gems = product.gems or 0
				t.isTrue(product.robux > lastPrice, `{product.key} costs more than the pack before`)
				t.isTrue(gems / product.robux >= last, `{product.key} gives fewer gems a Robux`)
				last = gems / product.robux
				lastPrice = product.robux
			end
		end
		t.isTrue(last > 0, "there are gem packs")
	end)

	t.test("a product gives only gems, coins, eggs or a revive: nothing never sold", function()
		local allowed = {
			key = true,
			id = true,
			name = true,
			robux = true,
			description = true,
			gems = true,
			coins = true,
			eggs = true,
			once = true,
			revive = true,
			art = true,
			icon = true,
			flag = true,
		}
		for _, product in RobuxStore.products do
			for field in product :: any do
				t.isTrue(allowed[field] == true, `{product.key} gives {field}, which is not sold`)
			end
			for _, egg in product.eggs or ({} :: { RobuxStore.Egg }) do
				t.notNil(EggRules.find(egg.key), `{product.key}'s {egg.key} is an egg`)
				t.isTrue(egg.count > 0, `{product.key} gives eggs`)
			end
		end
	end)

	t.test("the revive is Robux only: 15, no gems, never on the shelves", function()
		local revive = StoreRules.product("Revive")
		t.notNil(revive)
		if not revive then
			return
		end
		t.equal(revive.robux, 15)
		t.isNil(revive.gems)
		t.isNil(revive.coins)
		t.isNil(revive.eggs)
		for _, product in StoreRules.shelf(nil) do
			t.isFalse(product.revive == true, "the STORE sells no revive")
		end
		t.isFalse(StoreRules.canPrompt("Revive", nil, {}), "only DEFEAT offers it")
	end)

	t.test("a receipt is granted once, and the oldest are let go", function()
		local purchases = StoreRules.empty()
		t.isFalse(StoreRules.granted(purchases, "a"))
		StoreRules.keep(purchases, "a", 3)
		StoreRules.keep(purchases, "a", 3)
		t.equal(#purchases.receipts, 1, "the same receipt twice is kept once")
		t.isTrue(StoreRules.granted(purchases, "a"))
		for _, id in { "b", "c", "d" } do
			StoreRules.keep(purchases, id, 3)
		end
		t.equal(#purchases.receipts, 3)
		t.isFalse(StoreRules.granted(purchases, "a"), "the oldest went")
		t.isTrue(StoreRules.granted(purchases, "d"), "the newest stays")
		t.isTrue(RobuxStore.receiptsKept >= 20, "room for a burst of retries")
	end)

	t.test("2x Coins doubles, VIP adds a tenth, and both add up", function()
		t.equal(StoreRules.coinScale({}), 1)
		local double = StoreRules.coinScale({ DoubleCoins = true })
		local vip = StoreRules.coinScale({ VIP = true })
		local both = StoreRules.coinScale({ DoubleCoins = true, VIP = true })
		t.near(double, 2, 1e-9)
		t.isTrue(vip > 1 and vip < double)
		t.near(both, double + vip - 1, 1e-9)
		t.equal(StoreRules.coinScale({ PetSlot = true }), 1, "a slot is no coins")
	end)

	t.test("a small kill's bonus is carried, never rounded away", function()
		local scale = StoreRules.coinScale({ VIP = true })
		local paid, carry = 0, 0
		for _ = 1, 10 do
			local whole
			whole, carry = StoreRules.scaleCoins(5, scale, carry)
			paid += whole
		end
		t.equal(paid, math.floor(50 * scale + 1e-9))
		t.isTrue(carry >= 0 and carry < 1)
		local none = StoreRules.scaleCoins(5, 1, 0)
		t.equal(none, 5, "no pass, no change")
		t.equal((StoreRules.scaleCoins(0, scale, 0.5)), 0, "nothing earned pays nothing")
	end)

	t.test("the third pet slot is the pass's, and the save and slots have room", function()
		local without = StoreRules.petSlots({})
		local with = StoreRules.petSlots({ PetSlot = true })
		t.equal(without, 2)
		t.equal(with, without + 1)
		t.equal(#Eggs.slots, SaveSchema.PET_SLOTS)
		t.isTrue(SaveSchema.PET_SLOTS >= with)
	end)

	t.test("VIP's gems are paid once a day, and only to a VIP", function()
		local purchases = StoreRules.empty()
		local vip = { VIP = true }
		t.isTrue(StoreRules.dailyGems(vip) > 0)
		t.equal(StoreRules.dailyGems({ DoubleCoins = true }), 0)
		t.isTrue(StoreRules.dailyDue(purchases, 20000, vip))
		t.isFalse(StoreRules.dailyDue(purchases, 20000, {}), "not without the pass")
		purchases.vipDay = 20000
		t.isFalse(StoreRules.dailyDue(purchases, 20000, vip), "not twice a day")
		t.isTrue(StoreRules.dailyDue(purchases, 20001, vip), "again tomorrow")
		t.isTrue(StoreRules.nameTag(vip))
		t.isFalse(StoreRules.nameTag({ DoubleCoins = true }))
	end)

	t.test("the starter pack is offered once, after the first 1-1 clear", function()
		local purchases = StoreRules.empty()
		t.isTrue(StoreRules.starterDue(purchases, "1-1", true, "1-1"))
		t.isFalse(
			StoreRules.starterDue(purchases, "1-1", false, "1-1"),
			"a replay is not the moment"
		)
		t.isFalse(StoreRules.starterDue(purchases, "1-2", true, "1-1"), "another level is not")
		t.isFalse(StoreRules.starterDue(purchases, nil, true, "1-1"))
		purchases.starterOffered = true
		t.isFalse(StoreRules.starterDue(purchases, "1-1", true, "1-1"), "offered once")
		local bought = StoreRules.empty()
		bought.starterBought = true
		t.isFalse(StoreRules.starterDue(bought, "1-1", true, "1-1"), "never after buying it")
	end)

	t.test("the starter pack leaves the shelf once bought, and cannot be prompted again", function()
		local purchases = StoreRules.empty()
		local function onShelf(p: StoreRules.Purchases): boolean
			for _, product in StoreRules.shelf(p) do
				if product.once then
					return true
				end
			end
			return false
		end
		t.isTrue(onShelf(purchases))
		purchases.starterBought = true
		t.isFalse(onShelf(purchases))
		t.isFalse(StoreRules.canPrompt("StarterPack", purchases, {}))
	end)

	t.test("only what exists, is live and is not owned can be prompted", function()
		t.isFalse(StoreRules.canPrompt("NotAThing", nil, {}))
		t.isFalse(StoreRules.canPrompt(42, nil, {}))
		for _, product in RobuxStore.products do
			if not product.revive and not product.once then
				t.equal(
					StoreRules.canPrompt(product.key, nil, {}),
					StoreRules.live(product),
					`{product.key} is promptable when it is live`
				)
			end
		end
		for _, pass in RobuxStore.passes do
			t.equal(StoreRules.canPrompt(pass.key, nil, {}), StoreRules.live(pass))
			t.isFalse(StoreRules.canPrompt(pass.key, nil, { [pass.key] = true }), "owned already")
		end
		t.isNil(StoreRules.productById(0), "an id not set yet names nothing")
		t.isNil(StoreRules.passById(0))
		t.isNil(StoreRules.productById("12"))
	end)

	t.test("DEFEAT offers a held revive first, a bought one if live, none when spent", function()
		local purchases = StoreRules.empty()
		t.isNil(StoreRules.reviveOffer(purchases, false), "the run cannot take one")
		local revive = StoreRules.product("Revive")
		local live = revive ~= nil and StoreRules.live(revive)
		t.equal(StoreRules.reviveOffer(purchases, true), if live then "buy" else nil)
		purchases.reviveCredits = 1
		t.equal(StoreRules.reviveOffer(purchases, true), "use")
		t.isTrue(StoreRules.reviveAllowed("Dead", false, false))
		t.isFalse(StoreRules.reviveAllowed("Dead", false, true), "once a run")
		t.isFalse(StoreRules.reviveAllowed("Dead", true, false), "not the tutorial")
		t.isFalse(StoreRules.reviveAllowed("Fighting", false, false), "only a lost run")
	end)

	t.test("a stored copy is read field by field; anything broken is its default", function()
		local clean = StoreRules.read(nil)
		t.equal(#clean.receipts, 0)
		t.isFalse(clean.starterBought)
		t.equal(clean.reviveCredits, 0)
		local broken: { any } = { "r1", 7 :: any, "", "r2" }
		local p = StoreRules.read({
			receipts = broken,
			starterBought = true,
			starterOffered = false,
			reviveCredits = 2.7,
			vipDay = -4,
		})
		t.equal(#p.receipts, 2, "only ids that are text")
		t.isTrue(p.starterBought)
		t.isTrue(p.starterOffered, "bought means it was offered")
		t.equal(p.reviveCredits, 2)
		t.equal(p.vipDay, 0)
		t.equal(StoreRules.read({ reviveCredits = 0 / 0 }).reviveCredits, 0, "NaN is none")
	end)
end
