--!strict
--[[
	Every upgrade card is drawn from the owner's Glow Toy set
	(`Config/CardAssets`, 2026-10-24): a card without its icon, or a rarity
	without its name banner or its body, would draw a blank where the art
	should be. A new card must bring its art; so must the draft's buttons and
	the skill bar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every card has its icon, and its rarity a name banner", function()
		for _, ability in Abilities.all do
			local icon = CardAssets.icons[ability.icon]
			local banner = (CardAssets.banners :: any)[ability.rarity]
			t.isTrue(icon ~= nil and icon ~= "", `{ability.name} has no icon`)
			t.isTrue(banner ~= nil and banner ~= "", `{ability.rarity} has no banner`)
		end
	end)

	t.test("every rarity has its card body, and the Mythic its back", function()
		for name in Rarities.byName do
			local body = (CardAssets.bodies :: any)[name]
			t.isTrue(body ~= nil and body ~= "", `{name} has no card body`)
		end
		t.isTrue(CardAssets.mythicBack ~= "", "the Mythic has no back")
	end)

	t.test("Choose! and Reroll have every state, and the skill bar its art", function()
		for _, state in
			{
				"choose",
				"choosePressed",
				"chooseDisabled",
				"reroll",
				"rerollPressed",
				"rerollDisabled",
			}
		do
			local id = (CardAssets.buttons :: any)[state]
			t.isTrue(
				type(id) == "string" and string.find(id, "^rbxassetid://%d+$") ~= nil,
				`button {state} has no art`
			)
		end
		local bar = CardAssets.skillBar
		t.isTrue(string.find(bar.frame, "^rbxassetid://%d+$") ~= nil, "the skill bar has no frame")
		t.isTrue(
			string.find(bar.slotEmpty, "^rbxassetid://%d+$") ~= nil,
			"the skill bar has no empty slot"
		)
		-- a badge for every level a card can reach
		local top = 0
		for _, ability in Abilities.all do
			top = math.max(top, #ability.levels)
		end
		t.isTrue(
			#bar.levels >= top,
			`the skill bar has {#bar.levels} level badges; cards reach {top}`
		)
	end)
end
