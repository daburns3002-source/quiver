--!strict
--[[
	Paying out where the player is looking (review items 5, 9 and 10, owner
	2026-11-11): a level's first clear gives its area's egg, the end screens
	nudge, and the server tells the client of every coin.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local EndScreenTheme = require(ReplicatedStorage.Shared.Config.EndScreenTheme)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a first-clear egg is its own area's, with pets to hatch", function()
		for area, pay in Economy.areas do
			local key = pay.firstClearEgg
			if key then
				local egg = EggRules.find(key)
				t.notNil(egg, `{area}'s first-clear egg {key} is in Config/Eggs`)
				if egg then
					t.equal(egg.area, area)
				end
				t.isTrue(#EggRules.pool(key) > 0, `{key} has pets to roll`)
				local art = GearAssets.eggs[key]
				t.isTrue(
					art ~= nil or GearAssets.areaPictures.eggs[area] ~= nil,
					`{key} has a picture for Victory's slot`
				)
			end
		end
	end)

	t.test("every campaign level pays a first-clear egg", function()
		for _, index in Balance.campaign do
			local stage = Balance.Stages[index]
			local pay = stage.area and Economy.areas[stage.area]
			t.notNil(stage.level, `stage {index} has a level to save as beaten`)
			t.notNil(pay and pay.firstClearEgg, `stage {index}'s area gives an egg`)
		end
	end)

	t.test("the end screens nudge", function()
		local victory: any = EndScreenTheme.victory
		local defeat: any = EndScreenTheme.defeat
		t.isTrue(type(victory.hatchText) == "string" and #victory.hatchText > 0)
		t.isTrue(victory.hatchText ~= victory.subText)
		t.isTrue(#defeat.subText > 0)
	end)

	t.test("coins are told to the client", function()
		t.equal(Remotes.CoinsGained, "CoinsGained")
	end)
end
