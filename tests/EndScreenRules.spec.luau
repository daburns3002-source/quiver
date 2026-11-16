--!strict
--[[
	What the end screens show (`Util/EndScreenRules`), from the
	first-five-minutes playtest of 2026-11-12: the tutorial's Victory showed
	a "CHEST x0" row for a run that paid no chest, and a NEXT LEVEL button
	that went to the lobby. A row is only there for something to put in it,
	and a button says where it goes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EndScreenRules = require(ReplicatedStorage.Shared.Util.EndScreenRules)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the chest row is only there for something to put in it", function()
		t.isFalse(EndScreenRules.chestRow({}), "a run that paid coins alone has no row")
		t.isFalse(EndScreenRules.chestRow({ chests = 0 }), "nor does a count of none")
		t.isTrue(EndScreenRules.chestRow({ chests = 1 }), "a chest has its row")
		t.isTrue(
			EndScreenRules.chestRow({ egg = { key = "MossyEgg", pet = "Wilf", new = true } }),
			"a first clear's free egg has its row"
		)
		t.isTrue(EndScreenRules.chestRow({ item = "SlimeCrown" }), "a boss's item has its row")
	end)

	t.test("the tutorial's Victory does not promise a next level", function()
		local tutorial = EndScreenRules.buttonWords(true, Balance.tutorialStage)
		t.isTrue(tutorial ~= "", "the button says something")
		--[[ Every level's Victory goes on to a level, but the last level of
		     the last area built: that one is won into the lobby and says so
		     too (the every-class run-through, 2026-11-16). ]]
		local last: number? = nil
		for _, portal in LobbyConfig.portals do
			local levels = portal.levels
			if levels and Balance.Stages[levels[1]].level then
				last = levels[#levels]
			end
		end
		t.notNil(last, "an area is built")
		for index, stage in Balance.Stages do
			if index ~= Balance.tutorialStage and stage.level then
				t.equal(
					EndScreenRules.buttonWords(true, index) ~= tutorial,
					index ~= last,
					`{stage.name}: the button says where it leads`
				)
				t.equal(EndScreenRules.goesOn(index), index ~= last, stage.name)
			end
		end
		t.isTrue(
			EndScreenRules.buttonWords(false, Balance.tutorialStage) ~= tutorial,
			"a Defeat in the tutorial still tries again"
		)
	end)

	t.test("the end screen names a level as its portal does, never by its index", function()
		t.equal(EndScreenRules.levelTab(Balance.tutorialStage), "TUTORIAL")
		for _, portal in LobbyConfig.portals do
			local levels: { number } = portal.levels or {}
			for _, stage in levels do
				local config = Balance.Stages[stage]
				local name = (portal.name or "?") .. " " .. stage
				if config and config.mode == "Endless" then
					-- no levels to name: the mode itself
					t.equal(EndScreenRules.levelTab(stage), "ENDLESS", name)
					continue
				end
				local tail = EndScreenRules.levelTab(stage):match("^LEVEL (.+)$")
				t.isTrue(tail ~= nil, name)
				if config and config.level then
					t.equal(tail, config.level, name)
				else
					local n = tonumber(tail)
					t.isTrue(
						n ~= nil and n >= 1 and n <= #levels,
						name .. " shows " .. tostring(tail)
					)
				end
			end
		end
	end)

	--[[ The class level plate (`UI/ClassLevelPlate`, 360 by 84) stands clear
	     of the end panel and on the screen, at the shapes the game is
	     played at. The panel is the end screen's own: 1024 by 1684, at 85%
	     of a desktop's height and 97% of a phone's, 98% of an upright
	     phone's width. ]]
	t.test("the class level plate stands beside or under the end panel, never over it", function()
		local W, H = 360, 84
		local shapes = {
			{ name = "desktop", view = Vector2.new(1920, 1080), share = 0.85, beside = true },
			{ name = "small window", view = Vector2.new(1280, 720), share = 0.85, beside = true },
			{
				name = "phone on its side",
				view = Vector2.new(844, 390),
				share = 0.97,
				beside = true,
			},
			{
				name = "tablet on its side",
				view = Vector2.new(1180, 820),
				share = 0.85,
				beside = true,
			},
			{ name = "phone upright", view = Vector2.new(390, 844), share = 0.97, beside = false },
			{
				name = "tablet upright",
				view = Vector2.new(820, 1180),
				share = 0.85,
				beside = false,
			},
		}
		for _, shape in shapes do
			local view = shape.view
			local scale = math.min(view.Y * shape.share / 1684, view.X * 0.98 / 1024)
			local panelW, panelH = 1024 * scale, 1684 * scale
			local x, y, w, h = EndScreenRules.levelPlate(view.X, view.Y, panelW, panelH, W, H)
			t.near(h / w, H / W, 1e-6, shape.name .. " keeps the plate's shape")
			t.isTrue(w >= W * 0.6 - 1e-6, shape.name .. ": the plate is " .. w .. " wide")
			t.isTrue(x >= 0 and x + w <= view.X + 1e-6, shape.name .. " is on screen across")
			t.isTrue(y >= 0 and y + h <= view.Y + 1e-6, shape.name .. " is on screen down")
			local right, bottom = (view.X + panelW) / 2, (view.Y + panelH) / 2
			if shape.beside then
				t.isTrue(x >= right, shape.name .. ": beside the panel")
			else
				t.isTrue(y >= bottom, shape.name .. ": under the panel")
			end
		end
	end)

	t.test("an Endless run's end screen names the mode, the floor and what was kept", function()
		local endless: number? = nil
		for index, stage in Balance.Stages do
			if stage.mode == "Endless" then
				endless = index
			end
		end
		t.notNil(endless, "there is an Endless stage")
		t.equal(EndScreenRules.levelTab(endless :: number), "ENDLESS")

		local first = { floor = 6, best = 5, newBest = true, soulstones = 0 }
		t.isTrue(string.find(EndScreenRules.floorLabel(first), "NEW BEST", 1, true) ~= nil)
		local every = Balance.Endless.bossEvery
		t.isTrue(
			string.find(EndScreenRules.defeatLine(first, nil), tostring(every), 1, true) ~= nil,
			"with nothing banked it names the first boss floor"
		)
		local later = { floor = every + 3, best = 40, newBest = false, soulstones = 25 }
		t.isTrue(string.find(EndScreenRules.floorLabel(later), "BEST 40", 1, true) ~= nil)
		t.isTrue(
			string.find(EndScreenRules.defeatLine(later, nil), "25", 1, true) ~= nil,
			"what the run banked is said"
		)
		local never = { floor = 1, best = 0, newBest = false, soulstones = 0 }
		t.equal(EndScreenRules.floorLabel(never), "FLOOR REACHED")
		t.isTrue(
			string.find(EndScreenRules.defeatLine(never, nil), tostring(every), 1, true) ~= nil,
			"floor 1 points at the first boss floor, not floor 0"
		)
	end)

	t.test("DEFEAT says to hatch, or to merge when every pet slot is full", function()
		local hatch = EndScreenRules.defeatLine(nil, false)
		local merge = EndScreenRules.defeatLine(nil, true)
		t.isTrue(string.find(hatch, "HATCH", 1, true) ~= nil)
		t.isTrue(string.find(merge, "HATCH", 1, true) == nil, "no hatch with the slots full")
		t.equal(EndScreenRules.defeatLine(nil, nil), hatch)
	end)
end
