--!strict
--[[
	Level stars (`Util/StarRules`; owner, 2026-11-14: "there should be more
	rewards for players"): three stars a campaign level, for the win, for
	health left and for time, kept once earned, and an area's stars opening
	chests at 10, 20 and 30.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local StarRules = require(ReplicatedStorage.Shared.Util.StarRules)
local TestRunner = require(script.Parent.TestRunner)

local function stageOf(level: string): Balance.StageConfig
	for _, stage in Balance.Stages do
		if stage.level == level then
			return stage
		end
	end
	error("no level " .. level)
end

return function(t: TestRunner.Helper)
	t.test("a win always earns the first star; health and time earn the others", function()
		local stage = stageOf("1-1")
		local par = StarRules.par(stage)
		t.isTrue(par > 0)
		t.equal(StarRules.earned(stage, 10, par + 1), StarRules.WIN)
		t.equal(StarRules.earned(stage, 51, par + 1), StarRules.WIN + StarRules.HEALTH)
		t.equal(StarRules.earned(stage, 50, par + 1), StarRules.WIN, "half is not more than half")
		t.equal(StarRules.earned(stage, 10, par), StarRules.WIN + StarRules.TIME)
		t.equal(StarRules.earned(stage, 100, 1), 7)
		t.equal(
			StarRules.earned(stage, 0 / 0, 0 / 0),
			StarRules.WIN,
			"a broken number earns no more"
		)
		t.equal(StarRules.earned(stage, 100, -5), StarRules.WIN + StarRules.HEALTH)
	end)

	t.test("a level's time is so many seconds a room or a wave", function()
		local rooms = stageOf("1-1")
		t.equal(StarRules.par(rooms), #(rooms.rooms or {}) * Rewards.stars.secondsPerRoom)
		for _, stage in Balance.Stages do
			if stage.level and stage.mode == "Waves" then
				t.equal(StarRules.par(stage), (stage.waves or 1) * Rewards.stars.secondsPerWave)
				break
			end
		end
		t.equal(StarRules.clock(250), "4:10")
		t.equal(StarRules.clock(59.9), "0:59")
		t.equal(#StarRules.words(250), #StarRules.ALL)
		t.equal(StarRules.words(250)[3], "UNDER 4:10")
	end)

	t.test("stars are kept: two wins' stars make three", function()
		local stars: { [string]: number } = {}
		local had, now = StarRules.add(stars, "1-1", StarRules.WIN + StarRules.HEALTH)
		t.equal(had, 0)
		t.equal(StarRules.count(now), 2)
		had, now = StarRules.add(stars, "1-1", StarRules.WIN + StarRules.TIME)
		t.equal(StarRules.count(had), 2)
		t.equal(now, 7)
		had, now = StarRules.add(stars, "1-1", StarRules.WIN)
		t.equal(now, 7, "a worse win takes nothing away")
		t.equal(StarRules.count(nil), 0)
		t.equal(StarRules.count(7), 3)
		t.isTrue(StarRules.has(5, StarRules.TIME))
		t.isFalse(StarRules.has(5, StarRules.HEALTH))
		StarRules.add(stars, "1-2", 99)
		t.equal(stars["1-2"], 3, "only the three stars' bits are kept")
	end)

	t.test("an area's stars are its levels' stars, three a level", function()
		local levels = StarRules.levels("MossyGlade")
		t.equal(#levels, 10)
		t.equal(levels[1], "1-1")
		t.equal(#StarRules.levels("Nowhere"), 0)
		local stars: { [string]: number } = { ["1-1"] = 7, ["1-2"] = 1, ["2-1"] = 7 }
		local have, most = StarRules.area(stars, "MossyGlade")
		t.equal(have, 4)
		t.equal(most, 30)
		for _, stage in Balance.Stages do
			if stage.tutorial then
				t.isNil(
					stage.level and table.find(levels, stage.level),
					"the tutorial has no stars"
				)
			end
		end
	end)

	t.test("star chests open at 10, 20 and 30, once each, where an area has that many", function()
		local profile = SaveSchema.default()
		local chests = StarRules.chests(profile)
		local seen: { [string]: boolean } = {}
		for _, chest in chests do
			t.isNil(seen[chest.key], chest.key .. " is listed twice")
			seen[chest.key] = true
			local _, most = StarRules.area(profile.levelStars, chest.area)
			t.isTrue(chest.need <= most, chest.key .. " can never be reached")
			t.isTrue(#chest.words <= 30, chest.words .. " reads long")
			t.isFalse(chest.claimed)
		end
		t.notNil(seen["MossyGlade:10"])
		t.notNil(seen["MossyGlade:30"])
		t.equal(chests[1].key, "MossyGlade:10", "the first area first, its smallest chest first")
		t.equal(StarRules.tally(profile), 0)
		t.isNil(StarRules.claim(profile, "MossyGlade:10"), "no stars, no chest")
		for index, level in StarRules.levels("MossyGlade") do
			profile.levelStars[level] = if index <= 3 then 7 else 1
		end
		-- 3 x 3 + 7 x 1 = 16 stars
		t.equal(StarRules.tally(profile), 1)
		t.isNil(StarRules.claim(profile, "MossyGlade:20"), "twenty is not reached")
		t.isNil(StarRules.claim(profile, "MossyGlade:15"), "no such chest")
		t.isNil(StarRules.claim(profile, "Nowhere:10"))
		t.isNil(StarRules.claim(profile, 10))
		t.isNil(StarRules.claim(profile, nil))
		t.equal(StarRules.claim(profile, "MossyGlade:10"), Rewards.stars.chests[1].prize)
		t.isNil(StarRules.claim(profile, "MossyGlade:10"), "a chest opens once")
		t.equal(StarRules.tally(profile), 0)
	end)

	t.test("the chests pay eggs and crates, and only a little gems", function()
		local gems = 0
		for _, chest in StarRules.chests(SaveSchema.default()) do
			gems += chest.prize.gems or 0
			t.isTrue((chest.prize.eggs or 0) + (chest.prize.crates or 0) > 0, chest.key)
		end
		t.isTrue(gems <= 400, gems .. " gems for every star chest there is")
		local last = 0
		for _, chest in Rewards.stars.chests do
			t.isTrue(chest.stars > last, "the chests rise")
			last = chest.stars
		end
	end)

	t.test(
		"version 21: a level beaten holds its first star; stored stars are kept whole",
		function()
			local old = SaveSchema.migrate({
				version = 20,
				levelsBeaten = { ["1-1"] = true, ["1-2"] = true },
			})
			t.equal(old.levelStars["1-1"], 1, "it was won, whenever that was")
			t.equal(old.levelStars["1-2"], 1)
			t.isNil(old.levelStars["1-3"], "and nothing else is invented")
			t.isNil((next(old.starChests)))
			local p = SaveSchema.migrate({
				version = 21,
				levelsBeaten = { ["1-1"] = true },
				levelStars = { ["1-1"] = 6, ["1-2"] = 99, ["1-3"] = -1, ["1-4"] = "x" },
				starChests = { ["MossyGlade:10"] = true, Bad = 1 },
			})
			t.equal(p.levelStars["1-1"], 7, "a beaten level has its first star")
			t.equal(p.levelStars["1-2"], 7, "never more than three bits")
			t.isNil(p.levelStars["1-3"])
			t.isNil(p.levelStars["1-4"])
			t.isTrue(p.starChests["MossyGlade:10"])
			t.isNil(p.starChests.Bad)
			local again = SaveSchema.migrate(p)
			t.equal(again.levelStars["1-1"], 7, "a saved copy reads back the same")
		end
	)
end
