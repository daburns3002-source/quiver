--!strict
--[[
	Roblox Premium's perk (`Util/PremiumRules`, `Config/Rewards.premium`;
	owner, 2026-11-18): a tenth more coins added to the pay scale beside
	VIP's, never multiplied with it, and a free egg once a reward day.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveEvents = require(ReplicatedStorage.Shared.Config.LiveEvents)
local PremiumRules = require(ReplicatedStorage.Shared.Util.PremiumRules)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local RunBonus = require(ReplicatedStorage.Shared.Util.RunBonus)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("Premium adds its share to the coin scale, beside VIP's, nothing multiplied", function()
		t.equal(PremiumRules.coinShare(false), 0)
		t.equal(PremiumRules.coinShare(nil), 0)
		t.equal(PremiumRules.coinShare(true), Rewards.premium.coins)
		t.isTrue(Rewards.premium.coins > 0 and Rewards.premium.coins <= 0.25, "a small perk")
		local vip = StoreRules.coinScale({ VIP = true })
		t.near(
			RunBonus.scale(vip, 0, 1, false, true) - RunBonus.scale(vip, 0, 1, false, false),
			Rewards.premium.coins,
			1e-9
		)
		-- VIP and Premium together are their shares added: 1 + 0.1 + 0.1
		local vipShare = 0
		for _, pass in RobuxStore.passes do
			if pass.key == "VIP" then
				vipShare = pass.coinBonus or 0
			end
		end
		t.near(RunBonus.scale(vip, 0, 1, false, true), 1 + vipShare + Rewards.premium.coins, 1e-9)
		-- with a streak and a party too, still added
		t.near(
			RunBonus.scale(1, 2, 2, false, true),
			1 + RunBonus.streak(2) + RunBonus.friend(2) + Rewards.premium.coins,
			1e-9
		)
		t.equal(RunBonus.scale(1, 0, 1), 1, "no fifth argument reads as no Premium")
		-- every coin bonus at once, Premium too, stays under 5x (`tests/LiveBoosts.spec`)
		local passes = 1
		for _, pass in RobuxStore.passes do
			passes += pass.coinBonus or 0
		end
		t.isTrue(RunBonus.scale(passes + LiveEvents.caps.coins, 99, 2, true, true) < 5)
	end)

	t.test("the free egg is owed once a day, and only with Premium", function()
		local profile = SaveSchema.default()
		t.equal(profile.premiumDay, 0)
		t.isTrue(PremiumRules.eggDue(profile.premiumDay, 20400, true))
		t.isFalse(PremiumRules.eggDue(profile.premiumDay, 20400, false), "no Premium, no egg")
		profile.premiumDay = 20400
		t.isFalse(PremiumRules.eggDue(profile.premiumDay, 20400, true), "one a day")
		t.isTrue(PremiumRules.eggDue(profile.premiumDay, 20401, true), "and again tomorrow")
		t.isTrue(Rewards.premium.eggs >= 1)
		t.equal(PremiumRules.read(-3), 0)
		t.equal(PremiumRules.read("x"), 0)
		t.equal(PremiumRules.read(20400.9), 20400)
	end)
end
