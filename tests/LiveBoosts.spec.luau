--!strict
--[[
	The boosts (`Util/LiveBoosts`, `Config/LiveEvents`; owner, 2026-11-18):
	the weekend's from Friday 00:00 to Monday 00:00 UTC, Luck and Coins
	weekend about; the owner's live event; the Server Luck bought for
	Robux. They add, never multiply, and stop at their caps; luck raises the
	Legendary and Mythic odds and every egg's odds still add up.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local LiveBoosts = require(ReplicatedStorage.Shared.Util.LiveBoosts)
local LiveEvents = require(ReplicatedStorage.Shared.Config.LiveEvents)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local RunBonus = require(ReplicatedStorage.Shared.Util.RunBonus)
local SetRotation = require(ReplicatedStorage.Shared.Util.SetRotation)
local TestRunner = require(script.Parent.TestRunner)

local DAY = 86400

local function boost(kind: string, source: string, endsAt: number): LiveBoosts.Boost
	return { kind = kind, source = source, endsAt = endsAt }
end

local function sum(odds: { [string]: number }): number
	local total = 0
	for _, weight in odds do
		total += weight
	end
	return total
end

return function(t: TestRunner.Helper)
	t.test("the weekend runs Friday 00:00 to Monday 00:00 UTC", function()
		local monday = SetRotation.weekStart(4)
		t.isNil(LiveBoosts.weekend(monday), "Monday")
		t.isNil(LiveBoosts.weekend(monday + 4 * DAY - 1), "Thursday 23:59:59")
		local friday = LiveBoosts.weekend(monday + 4 * DAY)
		t.notNil(friday, "Friday 00:00")
		local sunday = LiveBoosts.weekend(monday + 7 * DAY - 1)
		t.notNil(sunday, "Sunday 23:59:59")
		t.isNil(LiveBoosts.weekend(monday + 7 * DAY), "the next Monday")
		if friday then
			t.equal(friday.endsAt, SetRotation.weekStart(5), "it ends as the week does")
			t.equal(friday.source, "Weekend")
		end
		local kind, startsAt = LiveBoosts.nextWeekend(monday + DAY)
		t.equal(startsAt, monday + 4 * DAY)
		t.equal(kind, if friday then friday.kind else "")
	end)

	t.test("weekends take turns between luck and coins", function()
		local kinds: { string } = {}
		for week = 0, 3 do
			local weekend = LiveBoosts.weekend(SetRotation.weekStart(week) + 5 * DAY)
			t.notNil(weekend)
			table.insert(kinds, if weekend then weekend.kind else "")
		end
		t.isTrue(kinds[1] ~= kinds[2], "two weekends running differ")
		t.equal(kinds[1], kinds[3])
		t.equal(kinds[2], kinds[4])
		for _, kind in kinds do
			t.notNil(table.find(LiveEvents.weekendKinds, kind))
		end
		t.equal(kinds[1], LiveEvents.weekendKinds[1], "the first weekend is the first kind")
	end)

	t.test("a boost runs until its end and not after", function()
		local boosts = { boost("Luck", "Server", 100) }
		t.equal(LiveBoosts.luck(boosts, 99), 2)
		t.equal(LiveBoosts.luck(boosts, 100), 1, "over at its end")
		t.equal(LiveBoosts.luck({}, 0), 1, "no boost: no luck")
		t.equal(LiveBoosts.coinShare({}, 0), 0)
	end)

	t.test("boosts add and stop at their caps", function()
		local now = 50
		local weekend = boost("Luck", "Weekend", 1000)
		local live = boost("Luck", "Live", 1000)
		local server = boost("Luck", "Server", 1000)
		t.equal(LiveBoosts.luck({ weekend }, now), 2, "one is 2x")
		t.equal(LiveBoosts.luck({ weekend, server }, now), 3, "two add: 3x, not 4x")
		t.equal(LiveBoosts.luck({ weekend, live, server }, now), LiveEvents.caps.luck, "the cap")
		t.isTrue(LiveEvents.caps.luck <= 3, "luck never runs away")
		-- coins: two coin events are still one more scale
		local coins = { boost("Coins", "Weekend", 1000), boost("Coins", "Live", 1000) }
		t.equal(LiveBoosts.coinShare({ coins[1] }, now), 1)
		t.equal(LiveBoosts.coinShare(coins, now), LiveEvents.caps.coins)
		t.isTrue(LiveEvents.caps.coins <= 1, "events add at most 2x coins")
		-- luck pays no coins and coins bring no luck
		t.equal(LiveBoosts.coinShare({ weekend, server }, now), 0)
		t.equal(LiveBoosts.luck(coins, now), 1)
	end)

	t.test("event coins add to the passes, streak and friend, never multiply", function()
		local passes = 1
		for _, pass in RobuxStore.passes do
			passes += pass.coinBonus or 0
		end
		-- 2x Coins and VIP, a full streak, a friend and a 2x Coins weekend
		local most = RunBonus.scale(passes + LiveEvents.caps.coins, 99, 2)
		t.near(
			most,
			passes + LiveEvents.caps.coins + RunBonus.streak(99) + RunBonus.friend(2),
			1e-9
		)
		t.isTrue(most < 4, "every coin bonus at once stays under 4x")
		for _, pass in RobuxStore.passes do
			t.isNil((pass :: any).luck, pass.key .. " brings no luck")
		end
	end)

	t.test("luck multiplies the Legendary and Mythic odds and the rest pay", function()
		for _, luck in { 2, 3 } do
			local odds = LiveBoosts.odds(Eggs.odds, luck)
			t.near(sum(odds), sum(Eggs.odds), 1e-9, "the total is kept")
			for rarity, weight in Eggs.odds do
				if table.find(LiveEvents.luckRarities, rarity) then
					t.near(odds[rarity], weight * luck, 1e-9, rarity .. " times the luck")
				else
					t.isTrue(odds[rarity] < weight, rarity .. " gives some up")
					t.isTrue(odds[rarity] > 0, rarity .. " still hatches")
				end
			end
			-- every other rarity shrinks by the one factor
			t.near(odds.Common / Eggs.odds.Common, odds.Epic / Eggs.odds.Epic, 1e-9)
		end
		t.near(LiveBoosts.odds(Eggs.odds, 1).Mythic, Eggs.odds.Mythic, 1e-12, "no luck: unchanged")
		t.near(LiveBoosts.odds(Eggs.odds, 0.5).Mythic, Eggs.odds.Mythic, 1e-12, "never below")
	end)

	t.test("luck has a ceiling and does nothing to an egg of only one kind", function()
		local odds = LiveBoosts.odds(Eggs.odds, 1e6)
		local lucky = 0
		for _, rarity in LiveEvents.luckRarities do
			lucky += odds[rarity] or 0
		end
		t.near(lucky / sum(odds), LiveEvents.luckShareCap, 1e-9, "however lucky")
		local only = LiveBoosts.odds({ Legendary = 3, Mythic = 1 }, 2)
		t.equal(only.Legendary, 3, "nothing to take from")
		local none = LiveBoosts.odds({ Common = 3, Rare = 1 }, 2)
		t.equal(none.Common, 3, "nothing lucky")
	end)

	t.test("an egg's pool shows its boosted odds, adding up to one", function()
		for _, egg in Eggs.list do
			local plain = EggRules.pool(egg.key)
			if #plain == 0 then
				continue
			end
			local lucky = EggRules.pool(egg.key, 2)
			local total, mythicPlain, mythicLucky = 0, 0, 0
			for i, entry in lucky do
				total += entry.chance
				t.equal(entry.pet, plain[i].pet, "the same pets in the same order")
				if entry.rarity == "Mythic" then
					mythicPlain += plain[i].chance
					mythicLucky += entry.chance
				end
			end
			t.near(total, 1, 1e-9, egg.key)
			if mythicPlain > 0 then
				t.near(mythicLucky, mythicPlain * 2, 1e-9, egg.key .. "'s Mythic doubles")
			end
		end
	end)

	t.test("buying again adds time", function()
		t.equal(LiveBoosts.extend(nil, 100, 900), 1000, "a first one runs from now")
		t.equal(LiveBoosts.extend(500, 100, 900), 1400, "a second adds to what is left")
		t.equal(LiveBoosts.extend(50, 100, 900), 1000, "an old one is over")
	end)

	t.test("countdowns and banner words", function()
		t.equal(LiveBoosts.clock(3 * DAY + 4 * 3600 + 59), "3D 4H")
		t.equal(LiveBoosts.clock(4 * 3600 + 12 * 60 + 5), "4H 12M")
		t.equal(LiveBoosts.clock(899.6), "14:59")
		t.equal(LiveBoosts.clock(5), "0:05")
		t.equal(LiveBoosts.clock(-3), "0:00")
		t.equal(LiveBoosts.clock(0 / 0), "0:00")
		t.equal(LiveBoosts.times(2), "2x")
		t.equal(LiveBoosts.times(1.5), "1.5x")
		local thanks: LiveBoosts.Boost =
			{ kind = "Luck", source = "Server", endsAt = 1, by = "Name" }
		t.equal(LiveBoosts.words(thanks), "THANKS NAME! 2x LUCK")
		t.equal(LiveBoosts.words(boost("Coins", "Weekend", 1)), "2x COINS WEEKEND")
		t.equal(LiveBoosts.words(boost("Luck", "Live", 1)), "LIVE EVENT! 2x LUCK")
		local long: LiveBoosts.Boost =
			{ kind = "Luck", source = "Server", endsAt = 1, by = string.rep("a", 40) }
		t.isTrue(#LiveBoosts.words(long) < 40, "a long name is cut")
	end)
end
