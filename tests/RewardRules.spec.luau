--!strict
--[[
	The login calendar, the daily quests, the starter list and the Dex
	payouts (`Config/Rewards`, `Util/RewardRules`): what is owed, when, and
	that nothing can be claimed twice or early.

	The numbers are the owner's to retune; what is pinned is their shape --
	a claim pays once, a day rolls, and the gems add up to an Epic in days.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local TestRunner = require(script.Parent.TestRunner)

local DAY = 20000

--[[ A quest of `kind` that is dealt on some day at or after `from`, and
     that day. ]]
local function dayWith(kind: string, from: number): (number, string)
	for day = from, from + 400 do
		for _, key in RewardRules.questsFor(day) do
			if Rewards.quests[key].kind == kind then
				return day, key
			end
		end
	end
	error(`no day deals a {kind} quest`)
end

return function(t: TestRunner.Helper)
	t.test("a reward day is a whole UTC day", function()
		t.equal(RewardRules.day(0), 0)
		t.equal(RewardRules.day(Rewards.dayLength - 1), 0)
		t.equal(RewardRules.day(Rewards.dayLength), 1)
	end)

	t.test("the calendar pays once a day, square after square, and comes round", function()
		local r = SaveSchema.default().rewards
		t.isTrue(RewardRules.loginReady(r, DAY))
		local gems = 0
		for index = 1, #Rewards.calendar do
			t.equal(RewardRules.loginSlot(r), index)
			local gift = RewardRules.claimLogin(r, DAY + index)
			t.isTrue(gift ~= nil, "a new day pays")
			gems += (gift :: RewardRules.Gift).gems
			t.isNil(RewardRules.claimLogin(r, DAY + index), "the same day never pays twice")
		end
		local week = 0
		for _, gift in Rewards.calendar do
			week += gift.gems
		end
		t.equal(gems, week)
		t.equal(RewardRules.loginSlot(r), 1, "after the last square comes the first")
	end)

	t.test("a missed day does not reset the calendar, and an earlier day pays nothing", function()
		local r = SaveSchema.default().rewards
		RewardRules.claimLogin(r, DAY)
		t.isNil(RewardRules.claimLogin(r, DAY - 3), "a clock set back claims nothing")
		t.isTrue(RewardRules.claimLogin(r, DAY + 5) ~= nil)
		t.equal(RewardRules.loginSlot(r), 3)
	end)

	t.test("every day deals one quest per group, the same for everyone", function()
		for day = DAY, DAY + 60 do
			local keys = RewardRules.questsFor(day)
			t.equal(#keys, #Rewards.groups)
			local again = RewardRules.questsFor(day)
			for index, key in keys do
				t.equal(again[index], key, "the deal depends only on the day")
				t.equal(Rewards.quests[key].group, Rewards.groups[index])
			end
		end
	end)

	t.test("every quest is dealt on some day", function()
		local seen: { [string]: boolean } = {}
		for day = DAY, DAY + 400 do
			for _, key in RewardRules.questsFor(day) do
				seen[key] = true
			end
		end
		for key in Rewards.quests do
			t.isTrue(seen[key] == true, `{key} is never dealt`)
		end
	end)

	t.test("a quest counts only its own kind, stops at its goal and pays once", function()
		local day, key = dayWith("kills", DAY)
		local quest = Rewards.quests[key]
		local r = SaveSchema.default().rewards
		t.isNil(RewardRules.claimQuest(r, day, key), "nothing done, nothing owed")
		RewardRules.note(r, day, "no such kind", 999)
		t.equal(RewardRules.progress(r, day, key), 0)
		RewardRules.note(r, day, "kills", quest.goal - 1)
		t.isFalse(RewardRules.questReady(r, day, key), "one short is not done")
		RewardRules.note(r, day, "kills", 500)
		t.equal(RewardRules.progress(r, day, key), quest.goal, "progress stops at the goal")
		local gift = RewardRules.claimQuest(r, day, key)
		t.isTrue(gift ~= nil and gift.gems == quest.gems)
		t.isNil(RewardRules.claimQuest(r, day, key), "a quest pays once")
		RewardRules.note(r, day, "kills", 500)
		t.isNil(RewardRules.claimQuest(r, day, key), "and more of it does not reopen it")
	end)

	t.test("a quest not dealt today cannot be claimed, whatever its progress says", function()
		local r = SaveSchema.default().rewards
		local today = RewardRules.questsFor(DAY)
		for key, quest in Rewards.quests do
			if not table.find(today, key) then
				r.questDay = DAY
				r.questProgress[key] = quest.goal
				t.isNil(RewardRules.claimQuest(r, DAY, key))
			end
		end
		t.isNil(RewardRules.claimQuest(r, DAY, "no such quest"))
	end)

	t.test("a new day wipes yesterday's quests, done or not", function()
		local day, key = dayWith("kills", DAY)
		local r = SaveSchema.default().rewards
		RewardRules.note(r, day, "kills", 9999)
		t.isTrue(RewardRules.questReady(r, day, key))
		t.equal(RewardRules.progress(r, day + 1, key), 0, "yesterday's kills are not today's")
		t.isFalse(RewardRules.questReady(r, day + 1, key))
		RewardRules.note(r, day + 1, "coins", 1)
		t.equal(r.questDay, day + 1)
		t.isNil(r.questProgress[key])
		t.isNil((next(r.questClaimed)))
	end)

	--[[ Owner, 2026-11-14: "there should be more rewards for players and
	     the quests need to be clearer". ]]
	t.test("a quest says so when it is half done and when it is done, once each", function()
		local day, key = dayWith("kills", DAY)
		local quest = Rewards.quests[key]
		local r = SaveSchema.default().rewards
		local half = math.ceil(quest.goal / 2)
		local _, none = RewardRules.note(r, day, "kills", half - 1)
		t.equal(#none, 0, "nothing to say before half")
		local _, atHalf = RewardRules.note(r, day, "kills", 1)
		t.equal(#atHalf, 1)
		t.equal(atHalf[1].key, key)
		t.equal(atHalf[1].have, half)
		t.isFalse(atHalf[1].done)
		local _, quiet = RewardRules.note(r, day, "kills", 1)
		t.equal(#quiet, 0, "half is said once")
		local _, atEnd = RewardRules.note(r, day, "kills", quest.goal)
		t.equal(#atEnd, 1)
		t.isTrue(atEnd[1].done)
		local _, after = RewardRules.note(r, day, "kills", 5)
		t.equal(#after, 0, "done is said once")
		-- a jump straight past both says only that it is done
		local fresh = SaveSchema.default().rewards
		local _, jump = RewardRules.note(fresh, day, "kills", quest.goal * 2)
		t.equal(#jump, 1)
		t.isTrue(jump[1].done)
	end)

	t.test("a short quest only says that it is done", function()
		local day, key = dayWith("bosses", DAY)
		local quest = Rewards.quests[key]
		t.isTrue(quest.goal < Rewards.stepGoal)
		local r = SaveSchema.default().rewards
		local _, steps = RewardRules.note(r, day, "bosses", quest.goal)
		t.equal(#steps, 1)
		t.isTrue(steps[1].done)
	end)

	t.test("the bonus chest opens once all three quests are claimed, once a day", function()
		local day = DAY
		local r = SaveSchema.default().rewards
		local keys = RewardRules.questsFor(day)
		t.equal(#keys, 3)
		t.isFalse(RewardRules.bonusReady(r, day), "nothing done")
		t.isNil(RewardRules.claimBonus(r, day))
		for index, key in keys do
			local quest = Rewards.quests[key]
			RewardRules.note(r, day, quest.kind, quest.goal)
			t.isFalse(RewardRules.bonusReady(r, day), "done is not claimed")
			t.notNil(RewardRules.claimQuest(r, day, key))
			t.equal(RewardRules.questsClaimed(r, day), index)
			t.equal(RewardRules.bonusReady(r, day), index == #keys)
		end
		t.equal(RewardRules.claimBonus(r, day), RewardRules.bonusKind(day))
		t.isTrue(RewardRules.bonusClaimed(r, day))
		t.isNil(RewardRules.claimBonus(r, day), "one chest a day")
		t.isFalse(RewardRules.bonusReady(r, day))
		-- the next day starts again
		t.isFalse(RewardRules.bonusClaimed(r, day + 1))
		t.isFalse(RewardRules.bonusReady(r, day + 1), "tomorrow's quests are not done")
	end)

	t.test("the bonus chest holds an egg one day and a crate the next", function()
		t.isTrue(RewardRules.bonusKind(DAY) ~= RewardRules.bonusKind(DAY + 1))
		t.equal(RewardRules.bonusKind(DAY), RewardRules.bonusKind(DAY + 2))
		t.isTrue(Rewards.bonus.gems > 0, "a player with nothing to open is still paid")
	end)

	t.test("CLAIM ALL pays everything owed once, and not the chest", function()
		local day = DAY
		local profile = SaveSchema.default()
		local r = profile.rewards
		local gems, coins, owed = Rewards.calendar[1].gems, Rewards.calendar[1].coins, 1
		for _, key in RewardRules.questsFor(day) do
			local quest = Rewards.quests[key]
			RewardRules.note(r, day, quest.kind, quest.goal)
			gems += quest.gems
			coins += quest.coins
			owed += 1
		end
		profile.levelsBeaten["1-1"] = true
		gems += Rewards.starter[1].gems
		coins += Rewards.starter[1].coins
		owed += 1
		t.equal(RewardRules.ready(profile, day), owed)
		local gift, n = RewardRules.claimAll(profile, day)
		t.equal(n, owed)
		t.equal(gift.gems, gems)
		t.equal(gift.coins, coins)
		t.isTrue(RewardRules.bonusReady(r, day), "the chest is left for its own opening")
		local again, none = RewardRules.claimAll(profile, day)
		t.equal(none, 0)
		t.equal(again.gems + again.coins, 0)
	end)

	t.test("each tab counts its own rewards, and the badge is their sum", function()
		local day = DAY
		local profile = SaveSchema.default()
		local by = RewardRules.readyBy(profile, day)
		t.equal(by.daily, 1)
		t.equal(by.quests, 0)
		t.equal(by.goals, 0)
		local key = RewardRules.questsFor(day)[1]
		RewardRules.note(profile.rewards, day, Rewards.quests[key].kind, Rewards.quests[key].goal)
		profile.levelsBeaten["1-1"] = true
		by = RewardRules.readyBy(profile, day)
		t.equal(by.quests, 1)
		t.equal(by.goals, 1)
		t.equal(RewardRules.ready(profile, day), 3)
	end)

	t.test("every kind of quest has a place to go and do it", function()
		for key, quest in Rewards.quests do
			t.notNil(Rewards.places[quest.kind], key .. " has nowhere to GO")
			t.isTrue(#string.format(quest.words, quest.goal) <= 22, key .. " reads long")
		end
	end)

	t.test("the starter list is read from the profile and pays each step once", function()
		local p = SaveSchema.default()
		for _, entry in Rewards.starter do
			t.isFalse(RewardRules.starterDone(p, entry.key), `{entry.key} starts undone`)
			t.isNil(RewardRules.claimStarter(p, entry.key), "an undone step pays nothing")
		end
		p.levelsBeaten["1-1"] = true
		p.pets.EmberWilf = 1
		p.equippedPets[1] = "EmberWilf"
		p.rewards.cratesOpened = 1
		local gems = 0
		for _, entry in Rewards.starter do
			t.isTrue(RewardRules.starterDone(p, entry.key), `{entry.key} is done`)
			local gift = RewardRules.claimStarter(p, entry.key)
			t.isTrue(gift ~= nil)
			gems += (gift :: RewardRules.Gift).gems
			t.isNil(RewardRules.claimStarter(p, entry.key), "a step pays once")
		end
		t.isTrue(gems > 0)
		t.isTrue(RewardRules.starterFinished(p))
		t.isNil(RewardRules.claimStarter(p, "no such step"))
	end)

	t.test("a Dex entry pays once ever", function()
		local r = SaveSchema.default().rewards
		t.isTrue(RewardRules.payDex(r, "Pets", "EmberWilf"))
		t.isFalse(RewardRules.payDex(r, "Pets", "EmberWilf"))
		t.isTrue(RewardRules.payDex(r, "Enemies", "EmberWilf"), "books are apart")
	end)

	t.test("the badge counts what waits to be claimed", function()
		local p = SaveSchema.default()
		t.equal(RewardRules.ready(p, DAY), 1, "a new player has the calendar's first square")
		RewardRules.claimLogin(p.rewards, DAY)
		t.equal(RewardRules.ready(p, DAY), 0)
		p.levelsBeaten["1-1"] = true
		t.equal(RewardRules.ready(p, DAY), 1)
	end)

	t.test("the gems add up: an Epic is days of play, not weeks", function()
		local week = 0
		for _, gift in Rewards.calendar do
			t.isTrue(gift.gems > 0, "every square pays gems")
			week += gift.gems
		end
		-- the least a day's three quests pay
		local leastByGroup: { [string]: number } = {}
		for _, quest in Rewards.quests do
			t.isTrue(quest.goal >= 1 and quest.gems > 0)
			t.isTrue(table.find(Rewards.groups, quest.group) ~= nil, "a quest's group is dealt")
			leastByGroup[quest.group] = math.min(leastByGroup[quest.group] or math.huge, quest.gems)
		end
		local quests = 0
		for _, group in Rewards.groups do
			quests += leastByGroup[group]
		end
		local daily = week / #Rewards.calendar + quests + Economy.areas.MossyGlade.bossGems
		local days = Shop.gemPrices.Epic / daily
		t.isTrue(days <= 7, `an Epic takes {days} days of daily play`)
		t.isTrue(days >= 2, "and is not handed out in a day either")
		t.isTrue(Rewards.dexGems > 0)
	end)
end
