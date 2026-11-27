--!strict
--[[
	Playtime gifts (`Util/PlaytimeRules`, `Config/Rewards.playtime`; owner,
	2026-11-18): six gifts that open as a session goes on, each bigger than
	the last, on the server's clock; a session crosses the run servers and
	starts over after a break; CLAIM ALL takes the ones that wait.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaytimeRules = require(ReplicatedStorage.Shared.Util.PlaytimeRules)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

local T0 = 1_800_000_000

--[[ What a prize is worth in coins, roughly, to put the six in order: a
     gem is the scarce currency (Robux buy them) and an egg or a crate is
     worth a few levels' coins. ]]
local GEM_COINS = 100
local THING_COINS = 2000
local function worth(prize: Rewards.Prize): number
	return (prize.coins or 0)
		+ (prize.gems or 0) * GEM_COINS
		+ ((prize.eggs or 0) + (prize.crates or 0)) * THING_COINS
end

return function(t: TestRunner.Helper)
	t.test(
		"the gifts open at 5, 10, 20, 30, 45 and 60 minutes, each bigger than the last",
		function()
			local gifts = Rewards.playtime.gifts
			t.equal(#gifts, 6)
			t.equal(PlaytimeRules.COUNT, #gifts)
			local minutes = {}
			for index, gift in gifts do
				table.insert(minutes, gift.minutes)
				if index > 1 then
					t.isTrue(gift.minutes > gifts[index - 1].minutes, "in order")
					t.isTrue(
						worth(gift.prize) > worth(gifts[index - 1].prize),
						`gift {index} is bigger`
					)
				end
			end
			t.equal(table.concat(minutes, ","), "5,10,20,30,45,60")
			-- coins first, then gems, then an egg or crate; the hour's has the most
			t.isTrue((gifts[1].prize.coins or 0) > 0 and gifts[1].prize.gems == nil)
			t.isTrue((gifts[3].prize.gems or 0) > 0)
			local last = gifts[#gifts].prize
			t.isTrue((last.eggs or 0) + (last.crates or 0) >= 2, "the hour's gift is the best")
		end
	)

	t.test("a whole hour pays few gems, so the store keeps its price", function()
		local gems = 0
		for _, gift in Rewards.playtime.gifts do
			gems += gift.prize.gems or 0
		end
		-- the daily rewards pay about 77 a day (`Config/Rewards`)
		t.isTrue(gems > 0 and gems <= 40, `{gems} gems an hour`)
	end)

	t.test("a new session starts with every gift shut, and opens them on the clock", function()
		local clock = SaveSchema.default().playtime
		t.isTrue(PlaytimeRules.join(clock, T0), "a first join starts a session")
		t.equal(PlaytimeRules.ready(clock, T0), 0)
		t.isNil(PlaytimeRules.claim(clock, T0, nil), "nothing open yet")
		local first = PlaytimeRules.opensAt(1)
		t.equal(PlaytimeRules.state(clock, T0 + first - 1, 1), "waiting")
		t.equal(PlaytimeRules.state(clock, T0 + first, 1), "ready")
		local index, left = PlaytimeRules.upcoming(clock, T0 + 60)
		t.equal(index, 1)
		t.equal(left, first - 60)
		t.near(PlaytimeRules.progress(clock, T0 + first / 2, 1), 0.5, 1e-9)
		-- twelve minutes in: two are open
		t.equal(PlaytimeRules.ready(clock, T0 + 12 * 60), 2)
		t.equal((PlaytimeRules.upcoming(clock, T0 + 12 * 60)), 3)
	end)

	t.test(
		"a gift is claimed once, only once it is open, and any key a client sends is checked",
		function()
			local clock = SaveSchema.default().playtime
			PlaytimeRules.join(clock, T0)
			local now = T0 + 11 * 60
			t.isNil(PlaytimeRules.claim(clock, now, 3), "not open yet")
			t.isNil(PlaytimeRules.claim(clock, now, 99))
			t.isNil(PlaytimeRules.claim(clock, now, "1"))
			t.isNil(PlaytimeRules.claim(clock, now, 0 / 0))
			local prize = PlaytimeRules.claim(clock, now, 2)
			t.equal(prize, Rewards.playtime.gifts[2].prize)
			t.isNil(PlaytimeRules.claim(clock, now, 2), "a gift claimed twice pays once")
			t.equal(PlaytimeRules.state(clock, now, 2), "claimed")
			t.equal(PlaytimeRules.ready(clock, now), 1)
			local rest = PlaytimeRules.claimAll(clock, T0 + 3600)
			t.equal(#rest, 5)
			t.isTrue(PlaytimeRules.finished(clock))
			t.equal(#PlaytimeRules.claimAll(clock, T0 + 7200), 0)
			t.isNil((PlaytimeRules.upcoming(clock, T0 + 7200)))
		end
	)

	t.test("the session goes on across a server hop and starts over after a break", function()
		local clock = SaveSchema.default().playtime
		PlaytimeRules.join(clock, T0)
		PlaytimeRules.claim(clock, T0 + 300, 1)
		-- the lobby server stamps it, the run server takes it up a little later
		PlaytimeRules.stamp(clock, T0 + 600)
		t.isFalse(PlaytimeRules.join(clock, T0 + 630), "a teleport is not a new session")
		t.equal(clock.start, T0)
		t.equal(PlaytimeRules.state(clock, T0 + 630, 1), "claimed", "a claimed gift stays claimed")
		-- a break longer than the gap starts again
		local back = T0 + 630 + Rewards.playtime.gap + 1
		t.isTrue(PlaytimeRules.join(clock, back))
		t.equal(clock.start, back)
		t.equal(clock.claimed, 0)
		-- a clock from the future (another server's skew, or a broken save) restarts
		local odd = PlaytimeRules.read({ start = T0 + 9999, seen = T0, claimed = 1 })
		t.isTrue(PlaytimeRules.join(odd, T0 + 10))
	end)

	t.test("a stored clock reads back whole, with no gift past the six", function()
		local clock = PlaytimeRules.read({ start = 12.7, seen = -4, claimed = 2 ^ 20 + 3 })
		t.equal(clock.start, 12)
		t.equal(clock.seen, 0)
		t.equal(clock.claimed, 3)
		local empty = PlaytimeRules.read("nonsense")
		t.equal(empty.start, 0)
		t.equal(PlaytimeRules.clockText(65), "1:05")
		t.equal(PlaytimeRules.clockText(0.2), "0:01", "never 0:00 while waiting")
		t.equal(PlaytimeRules.clockText(3600), "60:00")
	end)

	t.test("the badge, the GIFTS tab and CLAIM ALL count the open gifts alike", function()
		local profile = SaveSchema.default()
		local day = RewardRules.day(T0)
		-- the calendar's first square aside, nothing waits
		RewardRules.claimLogin(profile.rewards, day)
		PlaytimeRules.join(profile.playtime, T0)
		local now = T0 + 25 * 60
		t.equal(RewardRules.readyBy(profile, day, now).gifts, 3)
		t.equal(RewardRules.readyBy(profile, day).gifts, 0, "no clock given, none counted")
		local before = RewardRules.ready(profile, day, now)
		t.equal(RewardRules.owedAll(profile, day, now), before)
		local total, n, _, items = RewardRules.claimAll(profile, day, now)
		t.isTrue(n >= 3, "the three gifts are among what CLAIM ALL took")
		local coins = 0
		for index = 1, 3 do
			coins += Rewards.playtime.gifts[index].prize.coins or 0
		end
		t.isTrue(total.coins >= coins, "their coins are paid")
		t.equal(items.eggs, 0)
		t.equal(RewardRules.readyBy(profile, day, now).gifts, 0)
		t.equal(PlaytimeRules.ready(profile.playtime, now), 0)
	end)
end
