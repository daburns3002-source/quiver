--!strict
--[[
	The weekly Endless tournament's rules (`Util/TournamentRules`), driven
	by a fake clock: Unix seconds handed in, never read.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)
local Tournament = require(ReplicatedStorage.Shared.Config.Tournament)
local TournamentRules = require(ReplicatedStorage.Shared.Util.TournamentRules)

local DAY = 86400
--[[ Monday 2026-11-16 00:00 UTC. ]]
local MONDAY = 1794787200

return function(t: TestRunner.Helper)
	t.test("a week runs Monday 00:00 UTC to the next Monday", function()
		local week = TournamentRules.week(MONDAY)
		t.equal(TournamentRules.startOf(week), MONDAY)
		t.equal(TournamentRules.scope(week), "2026-11-16")
		t.equal(TournamentRules.week(MONDAY - 1), week - 1, "Sunday 23:59:59 is last week")
		t.equal(
			TournamentRules.week(MONDAY + 7 * DAY - 1),
			week,
			"the next Sunday is still this week"
		)
		t.equal(TournamentRules.week(MONDAY + 7 * DAY), week + 1)
		t.equal(TournamentRules.scope(week + 1), "2026-11-23")
		t.equal(TournamentRules.scope(week + 7), "2027-01-04", "across the new year")
		t.equal(TournamentRules.scope(0), "1970-01-05")
	end)

	t.test("the countdown reads days and hours, then hours and minutes", function()
		-- Wednesday 2026-11-18 19:30 UTC
		local now = MONDAY + 2 * DAY + 19 * 3600 + 30 * 60
		t.equal(TournamentRules.resetsIn(now), 4 * DAY + 4 * 3600 + 30 * 60)
		t.equal(TournamentRules.countdown(TournamentRules.resetsIn(now)), "RESETS IN 4D 4H")
		t.equal(TournamentRules.countdown(2 * DAY + 4 * 3600 + 59), "RESETS IN 2D 4H")
		t.equal(TournamentRules.countdown(5 * 3600 + 12 * 60 + 30), "RESETS IN 5H 12M")
		t.equal(TournamentRules.countdown(12 * 60), "RESETS IN 12M")
		t.equal(TournamentRules.countdown(30), "RESETS IN 1M", "never 0M")
		t.equal(TournamentRules.countdown(-5), "RESETS IN 1M")
		t.equal(TournamentRules.resetsIn(MONDAY), 7 * DAY, "a reset starts a whole week")
	end)

	t.test("a deeper floor always wins; on one floor, the faster run", function()
		local deepSlow = TournamentRules.score(31, 5000)
		local shallowFast = TournamentRules.score(30, 60)
		t.isTrue(deepSlow > shallowFast)
		t.isTrue(TournamentRules.score(30, 600) > TournamentRules.score(30, 600.1))
		t.equal(TournamentRules.floorOf(deepSlow), 31)
		t.equal(TournamentRules.tenthsOf(deepSlow), 50000)
		t.equal(
			TournamentRules.clock(TournamentRules.tenthsOf(TournamentRules.score(12, 247.9))),
			"4:07"
		)
		t.equal(TournamentRules.clock(37800), "1:03:00")
		-- a run slower than the span still counts, as that slow
		local slowest = TournamentRules.score(5, 1e9)
		t.equal(TournamentRules.floorOf(slowest), 5)
		t.isTrue(slowest > TournamentRules.score(4, 0))
		t.isTrue(
			TournamentRules.score(200, 0) < 2 ^ 53,
			"the deepest score is still a whole number a store keeps"
		)
		t.isTrue(TournamentRules.valid(deepSlow))
		t.isFalse(TournamentRules.valid(12.5))
		t.isFalse(TournamentRules.valid(TournamentRules.score(0, 10)), "floor 0 is no run")
	end)

	t.test("ties share the better place", function()
		local s = TournamentRules.score
		local list = {
			{ userId = 1, score = s(40, 900) },
			{ userId = 2, score = s(30, 800) },
			{ userId = 3, score = s(30, 800) },
			{ userId = 4, score = s(20, 100) },
		}
		t.equal(TournamentRules.place(list, s(40, 900)), 1)
		t.equal(TournamentRules.place(list, s(30, 800)), 2)
		t.equal(TournamentRules.place(list, s(20, 100)), 4, "two second places, then fourth")
	end)

	t.test("a finished week places the player from the read, the server and the save", function()
		local s = TournamentRules.score
		local read = {
			{ userId = 10, score = s(50, 1000) },
			{ userId = 11, score = s(40, 900) },
			{ userId = 12, score = s(30, 800) },
		}
		-- a short read is everyone: last is still third
		local place, score = TournamentRules.final(read, 100, {}, 12, 0)
		t.equal(place, 3)
		t.equal(score, s(30, 800))
		-- this server's best for them, not written yet, moves them up
		place = TournamentRules.final(read, 100, { [12] = s(45, 950) }, 12, 0)
		t.equal(place, 2)
		-- the save's best counts though the store never heard of it
		place, score = TournamentRules.final(read, 100, {}, 99, s(60, 10))
		t.equal(place, 1)
		t.equal(TournamentRules.floorOf(score), 60)
		-- under a full read's last score: past the top, no place
		place, score = TournamentRules.final(read, 3, {}, 99, s(10, 10))
		t.isNil(place)
		t.equal(TournamentRules.floorOf(score), 10, "still played, for the floor's band")
		-- never played
		place, score = TournamentRules.final(read, 100, {}, 99, 0)
		t.isNil(place)
		t.equal(score, 0)
	end)

	t.test("a place's prize and the floor's band add up", function()
		local first = TournamentRules.prize(1, 52)
		local champion = Tournament.places[1]
		local deepest = Tournament.bands[#Tournament.bands]
		t.isTrue(first.champion)
		t.equal(first.placeName, champion.name)
		t.equal(first.gems, champion.gems + deepest.gems)
		t.equal(first.soulstones, champion.soulstones + deepest.soulstones)

		local tenth = TournamentRules.prize(10, 12)
		t.isFalse(tenth.champion)
		t.equal(tenth.placeName, "TOP 10")
		t.equal(tenth.coins, 1000, "floor 12 is the 10-19 band")

		local eleventh = TournamentRules.prize(11, 9)
		t.equal(eleventh.placeName, "TOP 100")
		t.equal(
			eleventh.soulstones,
			Tournament.places[3].soulstones + Tournament.bands[1].soulstones
		)

		local past = TournamentRules.prize(nil, 25)
		t.isNil(past.placeName)
		t.equal(past.gems, 0)
		t.equal(past.coins, 2500)
		t.equal(past.soulstones, 200)

		local none = TournamentRules.prize(nil, 0)
		t.equal(none.soulstones + none.coins + none.gems, 0, "no run, no prize")
	end)

	t.test("the prize table is in order", function()
		local last = 0
		for _, place in Tournament.places do
			t.isTrue(place.upTo > last, "places climb")
			last = place.upTo
		end
		t.isTrue(last <= 100, "a place past one page of the store cannot be read")
		t.equal(Tournament.places[1].upTo, 1)
		t.isTrue(Tournament.places[1].champion)
		t.equal(Tournament.bands[1].from, 1, "every floor reached is in a band")
	end)

	t.test(
		"a save keeps each week's best once, and pays it after the week and its grace",
		function()
			local weeks: { [string]: number } = {}
			local week = TournamentRules.week(MONDAY)
			t.isTrue(TournamentRules.note(weeks, week, TournamentRules.score(12, 300)))
			t.isFalse(
				TournamentRules.note(weeks, week, TournamentRules.score(11, 10)),
				"a shallower floor"
			)
			t.isTrue(
				TournamentRules.note(weeks, week, TournamentRules.score(12, 200)),
				"the same floor, faster"
			)
			t.isFalse(TournamentRules.note(weeks, week, 0))

			-- the fake clock walks the week out
			t.equal(#TournamentRules.due(weeks, MONDAY + 3 * DAY), 0, "mid-week")
			local reset = TournamentRules.startOf(week + 1)
			t.equal(
				#TournamentRules.due(weeks, reset),
				0,
				"at the reset, the week's last writes may be on the way"
			)
			t.equal(#TournamentRules.due(weeks, reset + Tournament.grace - 1), 0)
			local due = TournamentRules.due(weeks, reset + Tournament.grace)
			t.equal(#due, 1)
			t.equal(due[1], week)
			-- paying it takes it out (`Data/Wallet`), so it is not due again
			weeks[tostring(due[1])] = nil
			t.equal(#TournamentRules.due(weeks, reset + Tournament.grace + DAY), 0)
		end
	)

	t.test("a save holds at most `keep` weeks, dropping the oldest", function()
		local weeks: { [string]: number } = { junk = 5 }
		for week = 1, Tournament.keep + 2 do
			TournamentRules.note(weeks, week, TournamentRules.score(week, 10))
		end
		local count = 0
		for _ in weeks do
			count += 1
		end
		t.equal(count, Tournament.keep)
		t.isNil(weeks.junk, "a broken key goes first")
		t.isNil(weeks["1"])
		t.isNil(weeks["2"])
		t.isTrue(weeks[tostring(Tournament.keep + 2)] ~= nil)
	end)

	t.test("the top ten pick set weapons: the winner two, places to 10 one", function()
		t.equal(TournamentRules.prize(1, 40).picks, 2)
		t.equal(TournamentRules.prize(2, 40).picks, 1)
		t.equal(TournamentRules.prize(10, 40).picks, 1)
		t.equal(TournamentRules.prize(11, 40).picks, 0)
		t.equal(TournamentRules.prize(nil, 40).picks, 0)
		t.equal(TournamentRules.prize(1, 0).picks, 0, "no run, no pick")
	end)

	t.test("a pick takes a set weapon not owned, of any set and class", function()
		local catalog = {
			{ weapon = "TwigBow" },
			{ weapon = "LivewireBow", set = "NeonCircuit" },
			{ weapon = "GlitchDaggers", set = "NeonCircuit" },
			{ weapon = "WishBow", set = "Starwish" },
		}
		local left = TournamentRules.pickable(catalog, { LivewireBow = true })
		t.equal(#left, 2)
		t.equal(left[1], "GlitchDaggers")
		t.equal(left[2], "WishBow")
		t.equal(#TournamentRules.pickable(catalog, {}), 3, "an area's weapon is never a pick")
	end)

	t.test("a pick never takes a reward weapon (Endless 100, the season pass)", function()
		local catalog = {
			{ weapon = "OrbitBow", set = "Voidglass" },
			{ weapon = "NebulaBlade", set = "Voidglass", earned = true },
		}
		local left = TournamentRules.pickable(catalog, {})
		t.equal(#left, 1)
		t.equal(left[1], "OrbitBow")
		-- the real catalog: none of the three reward blades is ever a pick
		local real: { TournamentRules.Item } = {}
		for _, entry in ShopRules.catalog() do
			table.insert(real, { weapon = entry.weapon, set = entry.set, earned = entry.earned })
		end
		local picks = TournamentRules.pickable(real, {})
		for _, weapon in { "NebulaBlade", "PetalfallBlade", "WishcutterBlade" } do
			t.isNil(table.find(picks, weapon), weapon)
		end
		t.isTrue(table.find(picks, "OrbitBow") ~= nil, "the set's others still are")
	end)

	t.test("picks with too few weapons left are paid in gems", function()
		local keep, gems = TournamentRules.settlePicks(2, 5)
		t.equal(keep, 2)
		t.equal(gems, 0)
		keep, gems = TournamentRules.settlePicks(2, 1)
		t.equal(keep, 1)
		t.equal(gems, Tournament.pickGems)
		keep, gems = TournamentRules.settlePicks(1, 0)
		t.equal(keep, 0)
		t.equal(gems, Tournament.pickGems, "owns them all: 300 gems")
	end)

	t.test("the champion's title counts the wins", function()
		t.isNil(TournamentRules.title(0))
		t.equal(TournamentRules.title(1), Tournament.title)
		t.equal(TournamentRules.title(3), `{Tournament.title} x3`)
	end)
end
