--!strict
--[[
	The analytics events (`Data/Analytics`): the funnel's steps in order and
	who they count for, and what each event carries, read off a capture
	instead of Roblox. Runs in its own copy of the module, so nothing here
	reaches the live game's events.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Analytics = require(ServerScriptService.Server.Data.Analytics) :: any
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

-- a stand-in player: the module only keys tables by it and reads its name
local function fakePlayer(name: string): Player
	return { Name = name, UserId = 0, Parent = nil } :: any
end

local function stageWhere(test: (Balance.StageConfig) -> boolean): number?
	for index, stage in Balance.Stages do
		if test(stage) then
			return index
		end
	end
	return nil
end

return function(t: TestRunner.Helper)
	t.test("the funnel runs join to first crate, in that order", function()
		local order = {
			"Joined",
			"Title",
			"Story",
			"Tutorial",
			"ClassSelect",
			"FirstRun",
			"Cleared1-1",
			"FirstHatch",
			"FirstCrate",
		}
		for index, name in order do
			t.equal(Analytics.stepOf(name), index, name)
		end
		t.equal(#Analytics.FUNNEL, #order)
		t.isNil(Analytics.stepOf("Nope"))
		t.isNil(Analytics.stepOf(3))
	end)
	t.test("a returning player is kept out of the funnel's first steps only", function()
		for step = 1, #Analytics.FUNNEL do
			local newcomerOnly = step <= Analytics.NEWCOMER_STEPS
			t.isTrue(Analytics.counts(step, false), `newcomer, step {step}`)
			t.equal(Analytics.counts(step, true), not newcomerOnly, `returning, step {step}`)
		end
		-- the step that ends a newcomer's run of them is the first 1-1 clear
		t.equal(Analytics.FUNNEL[Analytics.NEWCOMER_STEPS + 1], "Cleared1-1")
	end)
	t.test("a client can report only what is on its screen", function()
		local calls: { any } = {}
		Analytics.capture(calls)
		local player = fakePlayer("Client")
		for _, name in { "FirstCrate", "Cleared1-1", "Joined", 7, {} } :: { any } do
			Analytics.clientStep(player, name)
		end
		Analytics.capture(nil)
		t.equal(#calls, 0)
		t.isTrue(Analytics.CLIENT_STEPS.Title)
		t.isTrue(Analytics.CLIENT_STEPS.Story)
	end)
	t.test("custom fields are text, in order, nils left out", function()
		local fields = Analytics.fields("Ranger", nil, 12)
		t.equal(fields.CustomField01, "Ranger")
		t.isNil(fields.CustomField02)
		t.equal(fields.CustomField03, "12")
		t.isTrue(#Analytics.fields(string.rep("x", 500)).CustomField01 <= 50)
	end)
	t.test("each kind of run is its own progression path", function()
		local campaign = stageWhere(function(stage)
			return stage.level ~= nil and not stage.tutorial
		end)
		local endless = stageWhere(function(stage)
			return stage.mode == "Endless"
		end)
		local tutorial = stageWhere(function(stage)
			return stage.tutorial == true
		end)
		if campaign then
			local path, level, name = Analytics.progression(Balance.Stages[campaign], campaign, 3)
			t.equal(path, "Campaign")
			t.equal(level, campaign)
			t.equal(name, Balance.Stages[campaign].level)
		end
		if endless then
			local path, level = Analytics.progression(Balance.Stages[endless], endless, 37)
			t.equal(path, "Endless")
			t.equal(level, 37, "the floor reached")
		end
		if tutorial then
			t.equal((Analytics.progression(Balance.Stages[tutorial], tutorial, 2)), "Tutorial")
		end
		t.notNil(campaign)
	end)
	t.test("a death is sent with its room, its length and how it ended", function()
		local index = stageWhere(function(stage)
			return stage.level ~= nil and stage.mode ~= "Endless" and not stage.tutorial
		end) :: number
		local calls: { any } = {}
		Analytics.capture(calls)
		local player = fakePlayer("Dies")
		Analytics.runStarted(player, index, "Ranger")
		Analytics.reach(player, 4, "Room 4")
		Analytics.runEnded(player, "Died")
		-- a second end (the lobby after DEFEAT) sends nothing more
		Analytics.runEnded(player, "Left")
		Analytics.capture(nil)
		local methods: { string } = {}
		for _, call in calls do
			table.insert(methods, call.method)
		end
		t.equal(
			table.concat(methods, " "),
			table.concat({
				"LogProgressionStartEvent",
				"LogProgressionFailEvent",
				"LogCustomEvent",
				"LogCustomEvent",
			}, " ")
		)
		local length, death = calls[3].args, calls[4].args
		t.equal(length[1], "RunLength")
		t.isTrue(type(length[2]) == "number" and length[2] >= 0)
		t.equal(length[3].CustomField02, "Died")
		t.equal(death[1], "Death")
		t.equal(death[2], 4)
		t.equal(death[3].CustomField02, "Room 4")
		t.equal(death[3].CustomField03, "Ranger")
	end)
	t.test("a win completes the progression and sends no death", function()
		local index = stageWhere(function(stage)
			return stage.level ~= nil and not stage.tutorial
		end) :: number
		local calls: { any } = {}
		Analytics.capture(calls)
		local player = fakePlayer("Wins")
		Analytics.runStarted(player, index, "Arcanist")
		Analytics.runEnded(player, "Won")
		Analytics.capture(nil)
		t.equal(#calls, 3)
		t.equal(calls[2].method, "LogProgressionCompleteEvent")
		t.equal(calls[3].args[1], "RunLength")
	end)
	t.test("hatches send a pet each, and a bought one is the funnel's hatch", function()
		local calls: { any } = {}
		Analytics.capture(calls)
		local player = fakePlayer("Hatches")
		Analytics.hatched(player, "MossyEgg", { { pet = "Mosslet" }, { pet = "Babacorn" } }, "Free")
		t.equal(#calls, 2, "a free egg is not a hatch in the funnel")
		Analytics.hatched(player, "MossyEgg", { { pet = "Mosslet" } }, "Bought")
		Analytics.capture(nil)
		t.equal(calls[1].args[3].CustomField02, "Mosslet")
		t.equal(calls[1].args[3].CustomField03, "Free")
		-- the profile of a stand-in is never in, so only the step past the
		-- newcomer's steps is sent: FirstHatch, step 8
		t.equal(#calls, 4)
		t.equal(calls[4].method, "LogOnboardingFunnelStepEvent")
		t.equal(calls[4].args[1], Analytics.stepOf("FirstHatch"))
	end)
	t.test("a card pick carries the card, its rarity and what dealt it", function()
		local calls: { any } = {}
		Analytics.capture(calls)
		Analytics.cardPicked(fakePlayer("Picks"), "Multishot", "Epic", "Level", 3)
		Analytics.capture(nil)
		local args = calls[1].args
		t.equal(args[1], "CardPick")
		t.equal(args[2], 3)
		t.equal(args[3].CustomField01, "Multishot")
		t.equal(args[3].CustomField02, "Epic")
		t.equal(args[3].CustomField03, "Level")
	end)
end
