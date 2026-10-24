--!strict
--[[
	Every upgrade card's words fit on it (`Config/CardTheme` card sizes, drawn
	by `UI/Cards/CardBuilder`). The description is large, to fill the card
	(owner, 2026-10-24: "make the card description text bigger still so it
	fills more of the card"), so a long new description, or a bigger font,
	could run past its box or off the card; this measures every card's text
	the way the card lays it out, in the face's 168-wide units.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TextService = game:GetService("TextService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardBuilder = require(StarterPlayer.StarterPlayerScripts.Client.UI.Cards.CardBuilder) :: any
local CardTheme = require(ReplicatedStorage.Shared.Config.CardTheme)
local TestRunner = require(script.Parent.TestRunner)

local K = CardTheme.card
--[[ The face's width (CardBuilder's FACE_WIDTH), less its side padding. ]]
local INNER = 168 - K.paddingSide * 2
--[[ The description's line height, as the card draws it. ]]
local LINE = 1.15

local function width(text: string, size: number): number
	return TextService:GetTextSize(text, size, CardTheme.fonts.body, Vector2.new(10000, 1000)).X
end

return function(t: TestRunner.Helper)
	t.test("every description fits its box", function()
		for _, ability in Abilities.all do
			local wrapped = CardBuilder.wrap(ability.description)
			local count = 0
			for line in string.gmatch(wrapped, "[^\n]+") do
				count += 1
				t.isTrue(
					width(line, K.descText) <= K.descBox.X,
					`{ability.name}'s line "{line}" is wider than its box`
				)
			end
			t.isTrue(
				count * K.descText * LINE <= K.descBox.Y,
				`{ability.name}'s description takes {count} lines, more than its box holds`
			)
		end
	end)

	t.test("every stat pill fits across the card", function()
		for _, ability in Abilities.all do
			for _, stat in ability.stats do
				-- the pill's own padding is 10 a side
				t.isTrue(
					width(stat, K.statText) + 20 <= INNER + 2,
					`{ability.name}'s "{stat}" overflows the card`
				)
			end
		end
	end)

	t.test("the description box fits inside the card", function()
		t.isTrue(K.descBox.X <= INNER, "the description box is wider than the card's face")
	end)
end
