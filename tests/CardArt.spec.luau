--!strict
--[[
	Every upgrade card is drawn from the owner's Glow Toy set
	(`Config/CardAssets`, 2026-10-24): a card without its icon or its name
	banner, or a rarity without its body, would draw a blank where the art
	should be. A new card must bring its art.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every card has its icon and its name banner", function()
		for _, ability in Abilities.all do
			local icon = CardAssets.icons[ability.icon]
			local banner = CardAssets.banners[ability.icon]
			t.isTrue(icon ~= nil and icon ~= "", `{ability.name} has no icon`)
			t.isTrue(banner ~= nil and banner ~= "", `{ability.name} has no banner`)
		end
	end)

	t.test("every rarity has its card body, and the Mythic its back", function()
		for name in Rarities.byName do
			local body = (CardAssets.bodies :: any)[name]
			t.isTrue(body ~= nil and body ~= "", `{name} has no card body`)
		end
		t.isTrue(CardAssets.mythicBack ~= "", "the Mythic has no back")
	end)
end
