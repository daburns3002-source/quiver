--!strict
--[[
	The card design's data against the abilities it draws.

	A card with no icon, a rarity with no frame, or a stat line missing for a
	level all build without complaint and show up as a blank medallion or an
	empty pill, in front of the player, mid-run. These catch them first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local CardFrames = require(ReplicatedStorage.Shared.Config.CardFrames)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every ability has an uploaded icon", function()
		for _, ability in Abilities.all do
			local icon = CardAssets.icons[ability.icon]
			t.notNil(icon, `{ability.id} has no icon "{ability.icon}"`)
			t.isTrue(
				icon ~= nil and string.match(icon, "^rbxassetid://%d+$") ~= nil,
				`{ability.id}'s icon is not an asset id`
			)
		end
	end)

	t.test("every rarity has a frame, and every ability a real rarity", function()
		for _, rarity in Rarities.list do
			t.notNil(CardFrames.tiers[rarity.name], `{rarity.name} has no frame`)
		end
		for _, ability in Abilities.all do
			t.notNil(Rarities.byName[ability.rarity], `{ability.id} has rarity "{ability.rarity}"`)
		end
	end)

	t.test("rarer means less likely", function()
		for index = 2, #Rarities.list do
			t.isTrue(
				Rarities.list[index].weight < Rarities.list[index - 1].weight,
				`{Rarities.list[index].name} is dealt as often as {Rarities.list[index - 1].name}`
			)
		end
	end)

	t.test("the card's images are uploaded", function()
		for _, key in { "shard", "shardFacet", "glow", "rays" } do
			local asset = (CardAssets :: any)[key]
			t.isTrue(
				type(asset) == "string" and string.match(asset, "^rbxassetid://%d+$") ~= nil,
				`{key} is not an asset id`
			)
		end
	end)
end
