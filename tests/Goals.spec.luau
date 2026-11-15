--!strict
--[[
	Goals (`Config/Goals`, `Util/GoalRules`; owner, 2026-11-14: "there should
	be more rewards for players"): lifetime achievements in three steps,
	judged from the saved profile, claimed one step at a time in order, and
	paid mostly in coins, eggs and crates so the gem store keeps its price.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoalRules = require(ReplicatedStorage.Shared.Util.GoalRules)
local Goals = require(ReplicatedStorage.Shared.Config.Goals)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("about twenty goals, each with its own key and three rising steps", function()
		t.isTrue(#Goals.goals >= 18 and #Goals.goals <= 24, #Goals.goals .. " goals")
		local seen: { [string]: boolean } = {}
		for _, goal in Goals.goals do
			t.isNil(seen[goal.key], goal.key .. " is listed twice")
			seen[goal.key] = true
			t.equal(#goal.steps, #Goals.medals, goal.key)
			for index = 2, #goal.steps do
				t.isTrue(goal.steps[index].goal > goal.steps[index - 1].goal, goal.key)
			end
			t.isTrue(string.find(goal.words, "%%d") ~= nil, goal.key .. " names its number")
			t.isTrue(
				#string.format(goal.words, goal.steps[3].goal) <= 30,
				goal.key .. " reads long"
			)
			t.equal(GoalRules.find(goal.key), goal)
		end
		t.equal(#Goals.medals, #Goals.medalColours)
		t.isNil(GoalRules.find("nope"))
		t.isNil(GoalRules.find(7))
	end)

	t.test("every goal has a picture and, where it names one, a place", function()
		local pictures = {
			kills = true,
			coins = true,
			levels = true,
			bosses = true,
			hatches = true,
			crates = true,
		}
		local places = {
			Portal = true,
			EggHatchery = true,
			Blacksmith = true,
			GearStation = true,
			DexHall = true,
		}
		for _, goal in Goals.goals do
			t.isTrue(pictures[goal.kind] == true, goal.key .. " has no picture for " .. goal.kind)
			t.isTrue(goal.place == nil or places[goal.place] == true, goal.key)
			t.notNil(Rewards.places[goal.kind], goal.kind)
		end
	end)

	t.test("goals pay mostly coins, eggs and crates, and only a little gems", function()
		local gems, things = 0, 0
		for _, goal in Goals.goals do
			for index, step in goal.steps do
				local prize = step.prize
				local worth = (prize.coins or 0)
					+ (prize.gems or 0)
					+ (prize.eggs or 0)
					+ (prize.crates or 0)
				t.isTrue(worth > 0, goal.key .. " step " .. index .. " pays nothing")
				gems += prize.gems or 0
				things += (prize.eggs or 0) + (prize.crates or 0)
				if index < #goal.steps then
					t.equal(prize.gems or 0, 0, goal.key .. ": only a gold step pays gems")
				end
			end
		end
		-- every goal finished pays less than three weeks of the daily rewards' gems
		t.isTrue(gems <= 500, gems .. " gems in all")
		t.isTrue(things >= 60, "only " .. things .. " eggs and crates in all")
	end)

	t.test("the server's counters count only what they are for", function()
		local stats: { [string]: number } = {}
		t.isTrue(GoalRules.count(stats, "kills", 3))
		t.isTrue(GoalRules.count(stats, "kills", 2.9))
		t.equal(stats.kills, 5)
		t.isFalse(GoalRules.count(stats, "kills", 0))
		t.isFalse(GoalRules.count(stats, "kills", -4))
		t.isFalse(GoalRules.count(stats, "kills", 0 / 0))
		t.isFalse(GoalRules.count(stats, "pets", 9), "pets are read from the save, not counted")
		t.isFalse(GoalRules.count(stats, "nonsense", 9))
		t.isNil(stats.pets)
		for _, stat in Goals.counted do
			t.isTrue(GoalRules.counts(stat))
		end
		-- every goal's stat can be read
		local profile = SaveSchema.default()
		for _, goal in Goals.goals do
			t.isTrue(GoalRules.value(profile, goal.stat) >= 0, goal.key)
		end
	end)

	t.test("what the save already holds is counted for an old player", function()
		local profile = SaveSchema.default()
		t.equal(GoalRules.value(profile, "weapons"), 3, "the three starters")
		t.equal(GoalRules.value(profile, "pets"), 0)
		t.equal(GoalRules.value(profile, "classLevel"), 1)
		profile.pets = { Mosslet = 2, Babacorn = 1, Gone = 0 }
		profile.tiers.pets = { Mosslet = { S = 1 }, Babacorn = { C = 1 } }
		profile.bossesBeaten = { MossyGlade = true, Thornwood = true }
		profile.endlessBest = 34
		profile.classLevels = { Warden = { level = 7, xp = 0 }, Ranger = { level = 2, xp = 5 } }
		profile.rewards.loginCount = 9
		profile.rewards.dexPaid = { ["Pets:Mosslet"] = true, ["Enemies:MossSlime"] = true }
		profile.weapons.EmberFangBow = true
		profile.weapons.GladeSpiritBow = true
		t.equal(GoalRules.value(profile, "pets"), 2)
		t.equal(GoalRules.value(profile, "topTier"), 1)
		t.equal(GoalRules.value(profile, "areas"), 2)
		t.equal(GoalRules.value(profile, "endless"), 34)
		t.equal(GoalRules.value(profile, "classLevel"), 7)
		t.equal(GoalRules.value(profile, "logins"), 9)
		t.equal(GoalRules.value(profile, "dex"), 2)
		t.equal(GoalRules.value(profile, "weapons"), 5)
		t.equal(GoalRules.value(profile, "rare"), 2, "a Legendary and a Mythic bow")
	end)

	t.test("a goal is claimed one step at a time, in order, each once", function()
		local profile = SaveSchema.default()
		local goal = GoalRules.find("kills") :: GoalRules.Goal
		local bronze, silver, gold = goal.steps[1], goal.steps[2], goal.steps[3]
		t.isFalse(GoalRules.ready(profile, goal))
		t.isNil(GoalRules.claim(profile, "kills"), "nothing done, nothing owed")
		profile.stats.kills = bronze.goal - 1
		t.isNil(GoalRules.claim(profile, "kills"), "one short")
		profile.stats.kills = gold.goal + 5
		local index, wanted = GoalRules.step(profile, goal)
		t.equal(index, 1)
		t.equal(wanted, bronze.goal)
		t.equal(
			GoalRules.claim(profile, "kills"),
			bronze.prize,
			"bronze first, even with gold reached"
		)
		t.equal(GoalRules.claimed(profile, goal), 1)
		t.equal(GoalRules.claim(profile, "kills"), silver.prize)
		t.equal(GoalRules.claim(profile, "kills"), gold.prize)
		t.isTrue(GoalRules.finished(profile, goal))
		t.isNil(GoalRules.claim(profile, "kills"), "a finished goal pays no more")
		t.isNil((GoalRules.step(profile, goal)))
		t.isNil(GoalRules.claim(profile, "nope"))
		t.isNil(GoalRules.claim(profile, nil))
	end)

	t.test("the tally counts what waits and what is finished", function()
		local profile = SaveSchema.default()
		local waiting, done = GoalRules.tally(profile)
		t.equal(waiting, 0, "a new player is owed nothing")
		t.equal(done, 0)
		profile.stats.kills = 1e9
		profile.stats.hatches = 1e9
		waiting = GoalRules.tally(profile)
		t.equal(waiting, 2)
		for _ = 1, 3 do
			GoalRules.claim(profile, "kills")
		end
		waiting, done = GoalRules.tally(profile)
		t.equal(waiting, 1)
		t.equal(done, 1)
	end)

	t.test("claimed steps live in the save and survive a rejoin", function()
		local profile = SaveSchema.default()
		profile.stats.kills = 600
		GoalRules.claim(profile, "kills")
		local again = SaveSchema.migrate(profile)
		t.equal(again.stats.kills, 600)
		local goal = GoalRules.find("kills") :: GoalRules.Goal
		t.equal(GoalRules.claimed(again, goal), 1)
		t.isFalse(GoalRules.ready(again, goal), "silver is not reached")
	end)
end
