--!strict
--[[
	First-time tips (`Config/Tips`, `Util/TipRules`; owner, 2026-11-13: "if
	they have already seen that certain tutorial tip then dont play it
	anymore"): a tip shows once ever, the save keeps which, every tip the
	game asks for exists, each is short and well marked, its words can be
	read on its plate, and it stands on screen at every shape.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PromptText = require(ReplicatedStorage.Shared.Util.PromptText)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)
local TipRules = require(ReplicatedStorage.Shared.Util.TipRules)
local Tips = require(ReplicatedStorage.Shared.Config.Tips)
local UiPalette = require(ReplicatedStorage.Shared.Config.UiPalette)

--[[ Every key the game asks `UI/FirstTips` for. `ClassSelect` waits on
     the class select rebuild to be hooked in. ]]
local ASKED = {
	"Blacksmith",
	"EggHatchery",
	"GearStation",
	"DexHall",
	"Rewards",
	"Badges",
	"Portal",
	"SoulstoneShop",
	"FirstPet",
	"NewWeapon",
	"Merge",
	"Gems",
	"BossItem",
	"Boss",
	"Reroll",
	"NewArea",
	"Defeat",
	"EndlessCheckpoint",
}

return function(t: TestRunner.Helper)
	t.test("a tip shows once: due until it is seen, never after", function()
		local seen: { [string]: boolean } = {}
		t.isTrue(TipRules.due("Blacksmith", seen, {}))
		t.isTrue(TipRules.mark(seen, "Blacksmith"), "the first time is news")
		t.isFalse(TipRules.due("Blacksmith", seen, {}), "seen, so never again")
		t.isFalse(TipRules.mark(seen, "Blacksmith"), "a second mark changes nothing")
		t.isTrue(TipRules.due("EggHatchery", seen, {}), "one tip seen leaves the others")
	end)

	t.test("a tip shown this visit waits for nothing from the server", function()
		t.isFalse(TipRules.due("Boss", {}, { Boss = true }))
		t.isFalse(TipRules.due("Boss", nil, { Boss = true }), "before the profile has come")
		t.isTrue(TipRules.due("Boss", nil, nil))
	end)

	t.test("only a tip may be kept: nothing else a client sends", function()
		local seen: { [string]: boolean } = {}
		local bads: { any } = { "NotATip", 3, true, { "Boss" } }
		for _, bad in bads do
			t.isFalse(TipRules.isTip(bad))
			t.isFalse(TipRules.due(bad, seen, {}))
			t.isFalse(TipRules.mark(seen, bad))
		end
		t.isFalse(TipRules.mark(seen, nil), "nothing at all")
		t.isNil((next(seen)), "nothing was written")
	end)

	t.test("the save keeps what was seen, so it holds across joins", function()
		local profile = SaveSchema.migrate(nil)
		t.isNil((next(profile.tipsSeen)), "a new player has seen none")
		TipRules.mark(profile.tipsSeen, "Merge")
		local again = SaveSchema.migrate(profile)
		t.isTrue(again.tipsSeen.Merge)
		t.isFalse(TipRules.due("Merge", again.tipsSeen, {}), "not after a rejoin either")
	end)

	t.test("every tip the game asks for exists", function()
		for _, key in ASKED do
			t.isTrue(TipRules.isTip(key), `no tip {key}`)
		end
	end)

	t.test("every tip is short and its marks are whole", function()
		for key, tip in Tips.tips do
			t.isTrue(PromptText.valid(tip.text), `{key}: a mark is not closed`)
			local plain = TipRules.plain(key)
			t.isTrue(#plain > 0, `{key}: no words`)
			t.isTrue(#plain <= Tips.maxLength, `{key}: {#plain} letters, over {Tips.maxLength}`)
		end
	end)

	t.test("a tip's words can be read on its plate", function()
		local palette = PromptText.palette(UiPalette.card)
		local colours: { { name: string, colour: Color3 } } = {
			{ name = "words", colour = palette.words },
			{ name = "control", colour = palette.control },
			{ name = "action", colour = palette.action },
		}
		for _, pair in colours do
			local ratio = PromptText.contrast(pair.colour, UiPalette.card)
			t.isTrue(ratio >= 4.5, `{pair.name} stands {ratio}:1 on the plate`)
		end
	end)

	t.test("a tip stands on screen at every shape, a phone's gutters clear", function()
		for _, shape in { { 390, 844, 47 }, { 844, 390, 0 }, { 1920, 1080, 58 }, { 320, 568, 20 } } do
			local w, h, inset = shape[1], shape[2], shape[3]
			local box = TipRules.place(w, h, inset)
			local where = `{w} x {h}`
			t.isTrue(box.x >= TipRules.layout.gutter, `{where}: off the left`)
			t.isTrue(box.x + box.w <= w - TipRules.layout.gutter, `{where}: off the right`)
			t.isTrue(box.y >= inset, `{where}: under the top bar`)
			t.isTrue(box.y + box.h <= h, `{where}: off the bottom`)
			t.isTrue(box.w <= TipRules.layout.maxWidth, `{where}: too wide`)
		end
	end)
end
