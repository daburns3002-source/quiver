--!strict
--[[
	A run's coin bonuses (`Util/RunBonus`; owner, 2026-11-14: "there should
	be more rewards for players"): a win streak and a friend each add a
	share to the passes' scale, and a streak is the player's saved own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local RunBonus = require(ReplicatedStorage.Shared.Util.RunBonus)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a streak adds a tenth a win, and stops at a half", function()
		t.equal(RunBonus.streak(0), 0)
		t.near(RunBonus.streak(1), 0.1, 1e-9)
		t.near(RunBonus.streak(3), 0.3, 1e-9)
		t.near(RunBonus.streak(5), 0.5, 1e-9)
		t.near(RunBonus.streak(40), 0.5, 1e-9, "no more past the cap")
		t.equal(RunBonus.streak(-3), 0)
		t.equal(RunBonus.streak(0 / 0), 0)
		t.isTrue(Rewards.streak.cap <= 0.5, "a streak never doubles a run")
	end)

	t.test("a friend adds a fifth, however many friends", function()
		t.equal(RunBonus.friend(1), 0)
		t.equal(RunBonus.friend(0), 0)
		t.near(RunBonus.friend(2), 0.2, 1e-9)
		t.near(RunBonus.friend(3), 0.2, 1e-9)
	end)

	t.test("the bonuses add to the passes' scale and never multiply", function()
		t.equal(RunBonus.scale(1, 0, 1), 1, "alone with no streak: as before")
		t.near(RunBonus.scale(1, 2, 1), 1.2, 1e-9)
		t.near(RunBonus.scale(1, 5, 2), 1.7, 1e-9)
		-- 2x Coins and VIP make 2.1 (`StoreRules.coinScale`)
		t.near(RunBonus.scale(2.1, 5, 2), 2.8, 1e-9)
	end)

	t.test("a win makes the streak one longer, up to its longest", function()
		t.equal(RunBonus.won(0), 1)
		t.equal(RunBonus.won(7), 8)
		t.equal(RunBonus.won(RunBonus.LONGEST), RunBonus.LONGEST)
		t.equal(RunBonus.won(-2), 1)
	end)

	t.test("a level's start says what the player has, and nothing with nothing", function()
		t.equal(#RunBonus.lines(0, 1), 0)
		local lines = RunBonus.lines(3, 2)
		t.equal(lines[1], "WIN STREAK 3: +30% COINS")
		t.equal(lines[2], "FRIEND BONUS: +20% COINS")
		t.equal(RunBonus.lines(9, 1)[1], "WIN STREAK 9: +50% COINS")
		t.equal(RunBonus.percent(0.5), "+50%")
	end)

	t.test("version 19: the streak is saved, and an older profile has none", function()
		t.equal(SaveSchema.default().winStreak, 0)
		t.equal(SaveSchema.migrate({ version = 18, coins = 4 }).winStreak, 0)
		t.equal(SaveSchema.migrate({ version = 19, winStreak = 6 }).winStreak, 6)
		t.equal(SaveSchema.migrate({ version = 19, winStreak = -2 }).winStreak, 0)
		t.equal(SaveSchema.migrate({ version = 19, winStreak = "x" }).winStreak, 0)
		t.equal(
			SaveSchema.migrate({ version = 19, winStreak = 1e9 }).winStreak,
			RunBonus.LONGEST,
			"never past the longest"
		)
	end)
end
