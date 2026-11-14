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

--[[ Every key the game asks `UI/FirstTips` for. ]]
local ASKED = {
	"ClassSelect",
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

	local function inside(box: TipRules.Box, w: number, h: number, where: string)
		local g = TipRules.layout.gutter
		t.isTrue(box.x >= g - 1e-6, `{where}: off the left`)
		t.isTrue(box.x + box.w <= w - g + 1e-6, `{where}: off the right`)
		t.isTrue(box.y >= 0 and box.y + box.h <= h + 1e-6, `{where}: off the top or bottom`)
	end

	local function apart(a: TipRules.Box, b: TipRules.Box): boolean
		return a.x + a.w <= b.x + 1e-6
			or b.x + b.w <= a.x + 1e-6
			or a.y + a.h <= b.y + 1e-6
			or b.y + b.h <= a.y + 1e-6
	end

	t.test("with no arena (the lobby) a tip stands centred under the top HUD", function()
		for _, shape in { { 390, 844, 47 }, { 844, 390, 0 }, { 1920, 1080, 58 }, { 320, 568, 20 } } do
			local w, h, inset = shape[1], shape[2], shape[3]
			local placed = TipRules.place(w, h, inset, nil)
			inside(placed.box, w, h, `{w} x {h}`)
			t.isFalse(placed.side)
			t.isTrue(placed.box.y >= inset, `{w} x {h}: under the top bar`)
		end
	end)

	t.test("in a run a tip stands beside the arena, never on it", function()
		local shapes = {
			-- a computer: the room in the middle, forest either side
			{
				w = 1920,
				h = 1080,
				inset = 58,
				arena = { x = 600, y = 0, w = 720, h = 1080 },
				side = true,
			},
			-- a phone on its side
			{
				w = 844,
				h = 390,
				inset = 0,
				arena = { x = 260, y = 0, w = 324, h = 390 },
				side = true,
			},
			-- an upright phone: the room across the width, forest above and below
			{
				w = 390,
				h = 844,
				inset = 47,
				arena = { x = 0, y = 210, w = 390, h = 440 },
				side = false,
			},
			{
				w = 390,
				h = 844,
				inset = 47,
				arena = { x = 0, y = 380, w = 390, h = 280 },
				side = false,
			},
		}
		for _, shape in shapes do
			local where = `{shape.w} x {shape.h}`
			local placed = TipRules.place(shape.w, shape.h, shape.inset, shape.arena)
			inside(placed.box, shape.w, shape.h, where)
			t.equal(placed.side, shape.side, `{where}: which margin`)
			t.isTrue(apart(placed.box, shape.arena), `{where}: on the arena`)
		end
	end)

	t.test("with the margins alike a tip takes the right one, away from MENU", function()
		local arena = { x = 600, y = 0, w = 720, h = 1080 }
		local placed = TipRules.place(1920, 1080, 58, arena)
		t.isTrue(placed.box.x >= arena.x + arena.w, "on the left, over MENU")
		local leftWide = TipRules.place(1920, 1080, 58, { x = 900, y = 0, w = 720, h = 1080 })
		t.isTrue(leftWide.box.x + leftWide.box.w <= 900, "the left margin, clearly wider, is taken")
	end)

	t.test("with no margin wide enough a tip is still whole on the screen", function()
		local placed = TipRules.place(390, 844, 47, { x = 0, y = 100, w = 390, h = 700 })
		inside(placed.box, 390, 844, "an arena filling the screen")
	end)
end
