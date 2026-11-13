--!strict
--[[
	The UI's colours stay readable (`Config/UiPalette`, `Util/UiContrast`; owner, 2026-11-12:
	"make it have nice soft colors but still have everything be readable").

	Rules, not hexes: any colour may be changed, but every words-on-ground
	pair the kit draws keeps its contrast (4.5:1 for small words, 3:1 for
	big ones), on every shade a lit, striped face shows; a colour that is
	not the kit's own still gets words that read; and the tips' two
	highlights stay two different hues.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassSelect = require(ReplicatedStorage.Shared.Config.ClassSelect)
local EndScreenTheme = require(ReplicatedStorage.Shared.Config.EndScreenTheme)
local MergeRules = require(ReplicatedStorage.Shared.Util.MergeRules)
local TestRunner = require(script.Parent.TestRunner)
local UiContrast = require(ReplicatedStorage.Shared.Util.UiContrast)
local UiPalette = require(ReplicatedStorage.Shared.Config.UiPalette)

local WHITE = Color3.new(1, 1, 1)

local function hue(colour: Color3): number
	local h = colour:ToHSV()
	return h
end

return function(t: TestRunner.Helper)
	t.test("every words-on-ground pair keeps its contrast", function()
		local pairs = UiContrast.pairs()
		t.isTrue(#pairs >= 20, "the list of pairs has been cut")
		for _, pair in pairs do
			local got = UiContrast.worst(pair.text, pair.grounds)
			t.isTrue(
				got >= pair.need,
				string.format("%s: %.2f, needs %.1f", pair.what, got, pair.need)
			)
		end
	end)

	t.test("a face is never lit towards white, and its stripes are a dark wash", function()
		t.isTrue(UiContrast.luminance(UiPalette.stripe) < 0.1, "a pale stripe lightens the face")
		for _, name in { "header", "go", "secondary", "action", "danger", "gems", "off" } do
			local face = (UiPalette :: any)[name] :: UiPalette.Face
			t.isTrue(
				UiContrast.luminance(face.top) >= UiContrast.luminance(face.bottom),
				name .. " is lit from below"
			)
			t.equal(face.text, WHITE, name .. " has white words")
			t.notNil(face.stroke, name .. "'s white words have no outline")
		end
		-- the sunny button is the one with dark, unstroked words
		t.equal(UiPalette.primary.text, UiPalette.ink)
		t.isNil(UiPalette.primary.stroke)
	end)

	t.test("the kit's own colours are found, and any other still reads", function()
		t.equal(UiContrast.faceOf(UiPalette.go.top), UiPalette.go)
		t.equal(UiContrast.faceOf(UiPalette.primary.top), UiPalette.primary)
		for _, colour in
			{
				Color3.fromRGB(255, 240, 150),
				Color3.fromRGB(120, 200, 255),
				Color3.fromRGB(40, 60, 160),
				Color3.fromRGB(200, 40, 60),
				Color3.fromRGB(128, 128, 128),
			}
		do
			local face = UiContrast.faceOf(colour)
			local got = UiContrast.worst(face.text, UiContrast.shades(face.top, face.bottom))
			t.isTrue(got >= 3, string.format("words on %s: %.2f", tostring(colour), got))
			t.equal(face.stroke == nil, face.text ~= WHITE, "only white words are outlined")
		end
	end)

	t.test("a colour deepens only as far as small white words need", function()
		for _, card in ClassSelect do
			local deep = UiContrast.deepFor(card.colour, 4.5)
			t.isTrue(UiContrast.contrast(WHITE, deep) >= 4.5, card.class .. "'s pitch")
		end
		local dark = Color3.fromRGB(20, 40, 60)
		t.equal(UiContrast.deepFor(dark, 4.5), dark)
	end)

	--[[ The merge tier's letter (owner, 2026-11-12: "a letter at the bottom
	     left that is colored as well"): a colour for every tier, no two
	     alike, and none a rarity's frame, or the letter reads as the rarity. ]]
	t.test("every merge tier has a badge colour of its own", function()
		local seen: { Color3 } = {}
		for _, tier in MergeRules.TIERS do
			local look = UiPalette.tier[tier]
			t.notNil(look, "tier " .. tier .. " has no badge colour")
			for _, other in seen do
				t.isTrue(other ~= look.top, "two tiers share a badge colour")
			end
			table.insert(seen, look.top)
			for name, tile in UiPalette.rarity do
				t.isTrue(tile.frame ~= look.top, tier .. " wears " .. name .. "'s colour")
			end
		end
		local count = 0
		for _ in UiPalette.tier do
			count += 1
		end
		t.equal(count, #MergeRules.TIERS, "a badge colour for a tier that does not exist")
	end)

	t.test("the tips' two highlights differ by hue", function()
		local apart = math.abs(hue(UiPalette.tipControl) - hue(UiPalette.tipAction))
		apart = math.min(apart, 1 - apart)
		t.isTrue(apart >= 0.2, "the thing to press and what it does look alike")
	end)

	t.test("the end screens' words read on their blocks", function()
		for _, name in { "victory", "defeat" } do
			local look = (EndScreenTheme :: any)[name]
			for _, block in { "sub", "tab", "row", "rewards", "lobbyButton" } do
				local got = UiContrast.contrast(WHITE, look[block].fill)
				t.isTrue(got >= 3, string.format("%s %s: %.2f", name, block, got))
			end
			local got = UiContrast.contrast(look.buttonWords, look.button.fill)
			t.isTrue(got >= 3, string.format("%s button: %.2f", name, got))
		end
	end)
end
