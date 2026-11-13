--!strict
--[[
	The boss badges (`Config/BossBadges`, `UI/BadgeCase`): one for every
	area boss, each named for an area the economy and the Dex both know, and
	each with its own uploaded picture.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossBadges = require(ReplicatedStorage.Shared.Config.BossBadges)
local Dex = require(ReplicatedStorage.Shared.Config.Dex)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every area with a boss has a badge", function()
		local has: { [string]: boolean } = {}
		for _, badge in BossBadges.order do
			has[badge.area] = true
		end
		for area, config in Economy.areas do
			if config.bossItem then
				t.isTrue(has[area] == true, `{area}'s boss has no badge`)
			end
		end
	end)

	t.test("each badge is a known area's, once, with its own picture", function()
		local seenArea: { [string]: boolean } = {}
		local seenImage: { [string]: boolean } = {}
		for _, badge in BossBadges.order do
			t.isTrue(Economy.areas[badge.area] ~= nil, `{badge.area} is not an economy area`)
			t.isTrue(
				Economy.items[Economy.areas[badge.area].bossItem] ~= nil,
				`{badge.area} has no boss item`
			)
			t.isTrue(Dex.areas[badge.area] ~= nil, `{badge.area} has no Dex name`)
			t.isTrue(
				string.match(badge.image, "^rbxassetid://%d+$") ~= nil,
				`{badge.area}'s badge is not uploaded`
			)
			t.isTrue(not seenArea[badge.area], `{badge.area} has two badges`)
			t.isTrue(not seenImage[badge.image], `{badge.area} shares a picture`)
			seenArea[badge.area] = true
			seenImage[badge.image] = true
		end
	end)
end
