--!strict
--[[
	The rules behind the launch's recurring funnels and economy events
	(`Util/AnalyticsRules`): Roblox's limits kept, the screens a client may
	report, which step a repeat is, and what an economy event carries.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsRules = require(ReplicatedStorage.Shared.Util.AnalyticsRules)
local TestRunner = require(script.Parent.TestRunner)

local NONE = { coins = 0, gems = 0, soulstones = 0 }

return function(t: TestRunner.Helper)
	t.test("the funnels fit Roblox's limits, the onboarding one among them", function()
		local funnels = 0
		for name, steps in AnalyticsRules.FUNNELS :: { [string]: { string } } do
			funnels += 1
			t.isTrue(#steps >= 2 and #steps <= 100, name)
			local seen: { [string]: boolean } = {}
			for index, step in steps do
				t.isNil(seen[step], `{name} has {step} once`)
				seen[step] = true
				t.equal(AnalyticsRules.stepOf(name, step), index, `{name} {step}`)
			end
		end
		t.isTrue(funnels + 1 <= 10, "10 funnels a game, onboarding's included")
		t.isNil(AnalyticsRules.stepOf("RobuxStore", "Nope"))
		t.isNil(AnalyticsRules.stepOf("Nope", "Opened"))
	end)
	t.test("a client reports only known screens, a funnel's opening its first step", function()
		for name, funnel in AnalyticsRules.SCREENS do
			local known, opens = AnalyticsRules.screen(name)
			t.isTrue(known, name)
			if funnel then
				t.equal(opens, funnel)
				t.equal(AnalyticsRules.FUNNELS[funnel][1], "Opened", name)
			else
				t.isNil(opens, name)
			end
		end
		for _, name in { "Nope", 7, {}, "" } :: { any } do
			t.isFalse((AnalyticsRules.screen(name)), tostring(name))
		end
		-- every funnel but the offers' starts on a screen
		t.equal(AnalyticsRules.SCREENS.Store, "RobuxStore")
		t.equal(AnalyticsRules.SCREENS.EggHatchery, "EggHatch")
		t.equal(AnalyticsRules.SCREENS.Blacksmith, "CratePull")
	end)
	t.test("a prompt from the STORE is its funnel's; any other is an offer", function()
		t.equal(AnalyticsRules.promptFunnel("Store"), "RobuxStore")
		t.equal(AnalyticsRules.promptFunnel(nil), "RobuxStore")
		for _, where in { "Defeat", "Starter", "GearSlot", "Season", "Eggs" } do
			t.equal(AnalyticsRules.promptFunnel(where), "RobuxOffer", where)
		end
	end)
	t.test("a repeat is the again step once the first is done", function()
		t.equal(AnalyticsRules.repeatStep(nil, "EggHatch", "Hatched", "HatchedAgain"), "Hatched")
		t.equal(
			AnalyticsRules.repeatStep({ [1] = true }, "EggHatch", "Hatched", "HatchedAgain"),
			"Hatched"
		)
		t.equal(
			AnalyticsRules.repeatStep(
				{ [1] = true, [2] = true },
				"EggHatch",
				"Hatched",
				"HatchedAgain"
			),
			"HatchedAgain"
		)
		t.equal(
			AnalyticsRules.repeatStep({ [2] = true }, "CratePull", "Pulled", "PulledAgain"),
			"PulledAgain"
		)
	end)
	t.test("an economy event per currency moved, with the balance after it", function()
		local entries = AnalyticsRules.economy(
			"Source",
			"Robux",
			"Gems500",
			{ coins = 1200.7, gems = 500 },
			{ coins = 3000, gems = 650, soulstones = 9 }
		)
		t.equal(#entries, 2)
		t.equal(entries[1].currency, "Coins")
		t.equal(entries[1].amount, 1200)
		t.equal(entries[1].balance, 3000)
		t.equal(entries[1].transaction, "IAP")
		t.equal(entries[1].sku, "Gems500")
		t.equal(entries[2].currency, "Gems")
		t.equal(entries[2].balance, 650)
		local sink = AnalyticsRules.economy("Sink", "Egg", "MossyEgg", { coins = 300 }, NONE)
		t.equal(#sink, 1)
		t.equal(sink[1].flow, "Sink")
		t.equal(sink[1].amount, 300, "a sink's amount is positive too")
		t.equal(sink[1].transaction, "Shop")
		t.equal(
			AnalyticsRules.economy("Source", "Code", nil, { soulstones = 5 }, NONE)[1].sku,
			"Code"
		)
		local long =
			AnalyticsRules.economy("Source", "Code", string.rep("x", 90), { coins = 1 }, NONE)
		t.isTrue(#long[1].sku <= 40)
	end)
	t.test("nothing is sent for no amount, a bad one, or an unknown why", function()
		local nan = 0 / 0
		t.equal(#AnalyticsRules.economy("Source", "Run", nil, { coins = 0, gems = -5 }, NONE), 0)
		t.equal(
			#AnalyticsRules.economy("Source", "Run", nil, { coins = nan, gems = math.huge }, NONE),
			0
		)
		t.equal(#AnalyticsRules.economy("Source", "Nope", nil, { coins = 5 }, NONE), 0)
		t.equal(
			#AnalyticsRules.economy("Sink", "Run", nil, { coins = 5 }, NONE),
			0,
			"Run is no sink"
		)
		t.equal(#AnalyticsRules.economy("Sideways", "Egg", nil, { coins = 5 }, NONE), 0)
		local floor = AnalyticsRules.economy(
			"Source",
			"Run",
			nil,
			{ coins = 5 },
			{ coins = -3, gems = 0, soulstones = 0 }
		)
		t.equal(floor[1].balance, 0)
	end)
	t.test("the economy fits the dashboard: few currencies and transaction types", function()
		t.isTrue(#AnalyticsRules.CURRENCIES <= 10)
		local types: { [string]: boolean } = {}
		local count = 0
		for _, list in { AnalyticsRules.SOURCES, AnalyticsRules.SINKS } :: { { [string]: string } } do
			for why, transaction in list do
				t.isTrue(type(transaction) == "string" and transaction ~= "", why)
				if not types[transaction] then
					types[transaction] = true
					count += 1
				end
			end
		end
		t.isTrue(count <= 20, "the dashboard shows 20 transaction types")
		for why in AnalyticsRules.BATCHED do
			t.notNil((AnalyticsRules.SOURCES :: any)[why], `batched {why} is a source`)
		end
		for kind, why in AnalyticsRules.CLAIMS do
			t.notNil((AnalyticsRules.SOURCES :: any)[why], `claim {kind} pays as a source`)
		end
	end)
	t.test("a batch sums currency by currency", function()
		local into = AnalyticsRules.add({}, { coins = 3 })
		AnalyticsRules.add(into, { coins = 4, soulstones = 2 })
		AnalyticsRules.add(into, { gems = -9 })
		t.equal(into.coins, 7)
		t.equal(into.soulstones, 2)
		t.isNil(into.gems)
	end)
	t.test("a code try names the code only once it is redeemed", function()
		t.equal(AnalyticsRules.codeWord("Ok", "LAUNCH"), "LAUNCH")
		t.isNil(AnalyticsRules.codeWord("Unknown", "what i typed"))
		t.isNil(AnalyticsRules.codeWord("Used", "LAUNCH"))
		t.isNil(AnalyticsRules.codeWord("Ok", nil))
	end)
end
