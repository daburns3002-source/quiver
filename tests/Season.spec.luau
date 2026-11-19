--!strict
--[[
	The season pass (`Config/Season`, `Util/SeasonRules`; owner, 2026-11-18):
	a month of 30 tiers by the server's clock, XP from what the server saw
	happen, a free track of coins, gems, eggs and crates, a premium track of
	fixed things only, and everything reached claimed for the player when
	the month ends.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local Season = require(ReplicatedStorage.Shared.Config.Season)
local SeasonRules = require(ReplicatedStorage.Shared.Util.SeasonRules)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)
local TestRunner = require(script.Parent.TestRunner)
local TrailRules = require(ReplicatedStorage.Shared.Util.TrailRules)
local Trails = require(ReplicatedStorage.Shared.Config.Trails)

-- 2026-12-01 00:00 UTC, the first season's start, and 2027-01-01
local DEC = 1796083200
local JAN = 1798761600
-- 2026-11-18 12:00 UTC, before any season
local NOV = 1795003200
local MID = DEC + 10 * 86400

local function started(xp: number?): SeasonRules.State
	local state = SeasonRules.empty("2026-12")
	state.xp = xp or 0
	return state
end

return function(t: TestRunner.Helper)
	t.test("a season is a calendar month in UTC", function()
		local key, starts, ends = SeasonRules.month(MID)
		t.equal(key, "2026-12")
		t.equal(starts, DEC)
		t.equal(ends, JAN)
		t.equal((SeasonRules.month(DEC - 1)), "2026-11", "a second before is the month before")
		t.equal((SeasonRules.month(JAN)), "2027-01")
		-- every month for years agrees with the engine's own calendar
		local at = DEC
		for _ = 1, 40 do
			local k, s, e = SeasonRules.month(at)
			local date = os.date("!*t", s) :: any
			t.equal(k, string.format("%04d-%02d", date.year, date.month))
			t.equal(date.day, 1)
			t.equal(date.hour, 0)
			t.isTrue(e - s >= 28 * 86400 and e - s <= 31 * 86400)
			at = e
		end
	end)

	t.test("the first season runs December 2026, and is waited for before", function()
		t.isNil(SeasonRules.at(NOV), "no season in November")
		local next = SeasonRules.upcoming(NOV)
		t.isTrue(next ~= nil and next.key == "2026-12" and next.starts == DEC)
		local now = SeasonRules.at(MID)
		t.isTrue(now ~= nil and now.def.number == 1 and now.ends == JAN)
	end)

	t.test("every season has its set, a Season trail that glows, and a title", function()
		local numbers = {}
		for key, def in Season.seasons do
			t.isTrue(string.match(key, "^%d%d%d%d%-%d%d$") ~= nil, key)
			t.isNil(numbers[def.number], "two seasons share a number")
			numbers[def.number] = true
			local set = false
			for _, entry in Shop.sets do
				set = set or entry.key == def.set
			end
			t.isTrue(set, def.set .. " is not a themed set")
			local trail = Trails.trails[def.trail]
			t.isTrue(trail ~= nil, def.trail .. " is not a trail")
			if trail then
				t.equal(trail.earn, "Season")
				t.isTrue(table.find(Trails.order, def.trail) ~= nil, "the TRAILS tab lists it")
				t.isNil(TrailRules.price(def.trail), "a season trail is never sold")
				t.isTrue(trail.glow, "rule 12: a Legendary trail glows")
			end
			t.isTrue(Season.titles[def.title] ~= nil, def.title .. " is not a title")
		end
	end)

	t.test("30 tiers: every free tier gives something, premium only fixed things", function()
		t.equal(#Season.tiers, 30)
		t.isTrue(#Season.tiers <= 32, "one bit a tier")
		local trails, titles, freeGems, paidGems = 0, 0, 0, 0
		for tier, row in Season.tiers do
			local free = row.free
			t.isTrue(
				(free.coins or 0) + (free.gems or 0) + (free.eggs or 0) + (free.crates or 0) > 0,
				`free tier {tier} gives nothing`
			)
			t.isNil(free.trail)
			t.isNil(free.title)
			local paid = row.premium
			-- paid random items are restricted in some countries
			t.isNil(paid.eggs, `premium tier {tier} gives an egg`)
			t.isNil(paid.crates, `premium tier {tier} gives a crate`)
			t.isTrue((paid.coins or 0) + (paid.gems or 0) > 0 or paid.trail or paid.title)
			trails += if paid.trail then 1 else 0
			titles += if paid.title then 1 else 0
			freeGems += free.gems or 0
			paidGems += paid.gems or 0
		end
		t.equal(trails, 1)
		t.equal(titles, 1)
		t.equal(SeasonRules.tierOf("title"), #Season.tiers, "the title is the last tier")
		-- the free track pays little in gems, so the store keeps its price
		t.isTrue(freeGems < 150, `free gems {freeGems}`)
		t.isTrue(paidGems > freeGems * 5, "premium is mostly gems")
	end)

	t.test("a player who plays most days reaches tier 30 within the month", function()
		local day = 3 * Season.xp.quests + 4 * (Season.xp.levels + 5 * Season.xp.rooms)
		t.isTrue(SeasonRules.maxXp() / day <= 28, "not in the shortest month")
		t.isTrue(SeasonRules.maxXp() / day >= 10, "too quick to last the month")
	end)

	t.test("XP counts only in the season the state belongs to, up to the top", function()
		local state = started()
		local added, before, after = SeasonRules.gain(state, MID, "levels", 2)
		t.equal(added, 2 * Season.xp.levels)
		t.equal(before, 0)
		t.equal(after, SeasonRules.tier(state.xp))
		t.equal((SeasonRules.gain(state, MID, "kills", 50)), 0, "kills earn no season XP")
		t.equal((SeasonRules.gain(state, NOV, "levels", 1)), 0, "no season, no XP")
		t.equal((SeasonRules.gain(state, JAN + 5, "levels", 1)), 0, "not after its month")
		local lots = started()
		SeasonRules.gain(lots, MID, "quests", 10000)
		t.equal(lots.xp, SeasonRules.maxXp())
		t.equal(SeasonRules.tier(lots.xp), #Season.tiers)
		local into, need = SeasonRules.bar(lots.xp)
		t.equal(into, need, "the top tier reads full")
	end)

	t.test("a tier is claimed once, premium only with premium", function()
		local state = started(Season.tierXp * 2)
		t.isNil(SeasonRules.claim(state, "free", 3), "not reached")
		t.isTrue(SeasonRules.claim(state, "free", 2) ~= nil)
		t.isNil(SeasonRules.claim(state, "free", 2), "a claim sent twice pays once")
		t.isNil(SeasonRules.claim(state, "premium", 1), "premium not bought")
		t.isNil(SeasonRules.claim(state, "gold", 1))
		t.isNil(SeasonRules.claim(state, "free", 0))
		t.isNil(SeasonRules.claim(state, "free", 1.5))
		state.premium = true
		t.equal(#SeasonRules.owed(state), 3, "free 1, premium 1 and 2")
		local total, n = SeasonRules.claimAll(state)
		t.equal(n, 3)
		local expect = SeasonRules.zero()
		local paid: { { track: SeasonRules.Track, tier: number } } = {
			{ track = "free", tier = 1 },
			{ track = "premium", tier = 1 },
			{ track = "premium", tier = 2 },
		}
		for _, entry in paid do
			SeasonRules.add(expect, SeasonRules.prize(entry.track, entry.tier) :: Season.Prize)
		end
		t.equal(total.gems, expect.gems)
		t.equal(total.coins, expect.coins)
		t.equal(#SeasonRules.owed(state), 0)
	end)

	t.test("the trail and the title come with their tiers, by the season's keys", function()
		local def = Season.seasons["2026-12"]
		local state = started(SeasonRules.maxXp())
		state.premium = true
		local total = SeasonRules.claimAll(state)
		t.equal(total.trail, def.trail)
		t.equal(total.title, def.title)
		t.isTrue(total.eggs > 0 and total.crates > 0)
	end)

	t.test("at the month's end everything reached is claimed for the player", function()
		local state = started(Season.tierXp * 5)
		state.premium = true
		SeasonRules.claim(state, "free", 1)
		local owed = #SeasonRules.owed(state)
		t.equal(owed, 9, "free 2-5, premium 1-5")
		t.isNil((SeasonRules.rollover(state, MID)), "nothing moves inside the month")
		local total, def = SeasonRules.rollover(state, JAN + 60)
		t.isTrue(total ~= nil, "nothing claimed for the player")
		t.isTrue(def ~= nil and def.number == 1)
		-- no season in January yet: the state waits for one, empty
		t.equal(state.key, if SeasonRules.at(JAN + 60) then "2027-01" else "")
		t.equal(state.xp, 0)
		t.isFalse(state.premium, "premium is for one season")
		t.equal(state.free + state.paid, 0)
		-- free only without premium
		local plain = started(Season.tierXp * 3)
		local got = SeasonRules.rollover(plain, JAN + 60)
		local expect = SeasonRules.zero()
		for tier = 1, 3 do
			SeasonRules.add(expect, Season.tiers[tier].free)
		end
		t.isTrue(got ~= nil and got.coins == expect.coins and got.gems == expect.gems)
	end)

	t.test(
		"a state from before any season joins the first one; premium bought then is kept",
		function()
			local state = SeasonRules.empty()
			t.isNil((SeasonRules.rollover(state, NOV)))
			t.isFalse(SeasonRules.canBuy(state, NOV), "nothing to buy before the season")
			state.premium = true
			SeasonRules.rollover(state, MID)
			t.equal(state.key, "2026-12")
			t.isTrue(state.premium)
		end
	)

	t.test("premium is bought once a season", function()
		local state = started()
		t.isTrue(SeasonRules.canBuy(state, MID))
		state.premium = true
		t.isFalse(SeasonRules.canBuy(state, MID))
		t.isFalse(SeasonRules.canBuy(started(), JAN + 5), "not for a season that has ended")
		local product = StoreRules.product(Season.product)
		t.isTrue(product ~= nil and product.season == true, "the pass is a developer product")
		t.isFalse(StoreRules.canPrompt(Season.product, nil, {}), "never prompted from the STORE")
		t.isTrue(RobuxStore ~= nil)
	end)

	t.test("a stored state is read safely", function()
		local state = SeasonRules.read({
			key = "2026-12",
			xp = 1e12,
			free = -1,
			paid = 2 ^ 40,
			premium = "yes",
		})
		t.equal(state.xp, SeasonRules.maxXp())
		t.equal(state.free, 0)
		t.isTrue(state.paid < 2 ^ #Season.tiers)
		t.isFalse(state.premium)
		t.equal(SeasonRules.read("junk").key, "")
	end)

	t.test("the countdown reads in days, hours or minutes", function()
		t.equal(SeasonRules.left(12 * 86400 + 4 * 3600 + 59), "12D 4H")
		t.equal(SeasonRules.left(3 * 3600 + 20 * 60), "3H 20M")
		t.equal(SeasonRules.left(45 * 60), "45M")
		t.equal(SeasonRules.left(20), "1M")
		t.equal(SeasonRules.left(-5), "0M")
	end)
end
