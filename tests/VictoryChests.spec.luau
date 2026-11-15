--!strict
--[[
	Victory's three chests (`Util/VictoryChestRules`; owner, 2026-11-14:
	"there should be more rewards for players"): rolled by the server before
	they are shown, mostly coins, sometimes gems, rarely an egg or a crate,
	and never enough gems to move the store's prices.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local TestRunner = require(script.Parent.TestRunner)
local VictoryChestRules = require(ReplicatedStorage.Shared.Util.VictoryChestRules)

--[[ Rolls that walk evenly from 0 to 1, the same every time. ]]
local function walker(steps: number): () -> number
	local n = 0
	return function()
		n += 1
		return ((n * 7919) % steps) / steps
	end
end

--[[ Rolls read from a list, in turn. ]]
local function fixed(values: { number }): () -> number
	local n = 0
	return function()
		n += 1
		return values[(n - 1) % #values + 1]
	end
end

return function(t: TestRunner.Helper)
	t.test("three chests, each one of the four kinds", function()
		local kinds = { coins = true, gems = true, egg = true, crate = true }
		local chests = VictoryChestRules.three(250, walker(997))
		t.equal(#chests, 3)
		t.equal(VictoryChestRules.COUNT, 3)
		for _, prize in chests do
			t.isTrue(kinds[prize.kind] == true, prize.kind)
			t.isTrue(prize.amount >= 1)
		end
	end)

	t.test("the table's ends: the first roll picks the kind, the second the size", function()
		local low = VictoryChestRules.one(250, fixed({ 0, 0 }))
		t.equal(low.kind, "coins")
		t.equal(low.amount, 125, "half the clear bonus")
		local high = VictoryChestRules.one(250, fixed({ 0, 1 }))
		t.equal(high.amount, 375, "one and a half")
		local last = VictoryChestRules.one(250, fixed({ 0.9999, 0.5 }))
		t.equal(last.kind, "crate")
		t.equal(last.amount, 1)
		-- a roll of exactly 1, or a broken one, still gives a chest
		t.notNil(VictoryChestRules.one(250, fixed({ 1, 1 })).kind)
		t.isTrue(VictoryChestRules.one(0, fixed({ 0, 0 })).amount >= 5, "never an empty chest")
	end)

	t.test("mostly coins, some gems, and an egg or crate is rare", function()
		local seen: { [string]: number } = { coins = 0, gems = 0, egg = 0, crate = 0 }
		local gems = 0
		local roll = walker(100003)
		local n = 6000
		for _ = 1, n do
			local prize = VictoryChestRules.one(250, roll)
			seen[prize.kind] += 1
			if prize.kind == "gems" then
				gems += prize.amount
				t.isTrue(prize.amount >= 2 and prize.amount <= 4)
			elseif prize.kind == "coins" then
				t.isTrue(prize.amount >= 125 and prize.amount <= 375)
				t.equal(prize.amount % 5, 0)
			end
		end
		t.isTrue(seen.coins / n > 0.5, "coins are the usual chest")
		t.isTrue(seen.gems / n > 0.1 and seen.gems / n < 0.3)
		t.isTrue((seen.egg + seen.crate) / n < 0.25, "an egg or crate is the rare one")
		t.isTrue(seen.egg > 0 and seen.crate > 0)
		--[[ The store's price: 20 wins a day must stay well under the 77
		     gems a day the daily rewards pay (`Config/Rewards`). ]]
		t.isTrue(gems / n * 20 < 20, string.format("%.2f gems a win", gems / n))
	end)

	t.test("only chest 1, 2 or 3 can be picked", function()
		t.equal(VictoryChestRules.pick(1), 1)
		t.equal(VictoryChestRules.pick(3), 3)
		t.isNil(VictoryChestRules.pick(0))
		t.isNil(VictoryChestRules.pick(4))
		t.isNil(VictoryChestRules.pick(1.5))
		t.isNil(VictoryChestRules.pick(0 / 0))
		t.isNil(VictoryChestRules.pick("2"))
		t.isNil(VictoryChestRules.pick(nil))
		t.isNil(VictoryChestRules.pick({ 1 }))
	end)

	t.test("an egg or crate that cannot be given is paid in coins", function()
		local prize = VictoryChestRules.instead(250)
		t.equal(prize.kind, "coins")
		t.equal(prize.amount, 375)
	end)

	t.test("a crate is the area's own, when it has a weapon for the class", function()
		local index = VictoryChestRules.crate("MossyGlade", "Ranger")
		t.notNil(index)
		t.equal(Shop.crates[index :: number].area, "MossyGlade")
		t.isNil(VictoryChestRules.crate("Nowhere", "Ranger"))
		t.isNil(VictoryChestRules.crate(nil, "Ranger"))
		t.isNil(VictoryChestRules.crate("MossyGlade", "NoSuchClass"))
	end)

	t.test("the table adds up and reads in the screen's order", function()
		local total = 0
		for _, entry in Rewards.victory.prizes do
			t.isTrue(entry.weight > 0 and entry.high >= entry.low, entry.kind)
			total += entry.weight
		end
		t.equal(total, 100)
		t.equal(Rewards.victory.prizes[1].kind, "coins")
	end)
end
