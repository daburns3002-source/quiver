--!strict
--[[
	The run's top HUD, the phone's MENU icon and the draft's phone tray
	(`Util/RunHudRules`, `Config/Hud` `top` and `draftUpright`; the 2026-11-11
	loop and UI review). What is pinned is what the review found wrong: a
	button too small for a thumb, a HUD under the MENU, a line that says the
	run restarts by itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require(ReplicatedStorage.Shared.Config.Hud)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local TestRunner = require(script.Parent.TestRunner)

--[[ The smallest thing a thumb presses reliably, in points. ]]
local THUMB = 44
local UPRIGHT = Vector2.new(390, 844)
local SIDEWAYS = Vector2.new(844, 390)
local TOP_BAR = 58

return function(t: TestRunner.Helper)
	t.test("a phone's MENU icon is a thumb wide and under Roblox's top bar", function()
		for _, view in { UPRIGHT, SIDEWAYS } do
			local top = RunHudRules.top(view, true, TOP_BAR)
			local menu = top.menu
			t.notNil(menu, "a phone has a MENU icon")
			if menu then
				t.isTrue(menu.w >= THUMB and menu.h >= THUMB, "the icon is thumb sized")
				t.isTrue(menu.y >= TOP_BAR, "the icon is clear of Roblox's top bar")
				t.isTrue(menu.x + menu.w <= view.X / 2, "the icon is on the left")
			end
		end
	end)

	t.test("the top HUD never sits under the MENU icon or off the screen", function()
		for _, view in { UPRIGHT, SIDEWAYS, Vector2.new(320, 568) } do
			local top = RunHudRules.top(view, true, TOP_BAR)
			local menu, banner = top.menu, top.banner
			if menu then
				t.isTrue(banner.x >= menu.x + menu.w, "the HUD starts right of the icon")
			end
			t.isTrue(banner.x + banner.w <= view.X, "the HUD ends on the screen")
			t.isTrue(banner.w >= 200, "the HUD keeps a readable width")
			t.isTrue(banner.y >= TOP_BAR, "the HUD is clear of Roblox's top bar")
		end
	end)

	t.test("a computer keeps its MENU button and centres the HUD", function()
		local view = Vector2.new(1920, 1080)
		local top = RunHudRules.top(view, false, 36)
		t.isNil(top.menu, "no icon on a computer")
		t.isNil(top.panel, "the panel keeps its own size on a computer")
		t.near(top.banner.x + top.banner.w / 2, view.X / 2, 0.5, "centred")
	end)

	t.test("a phone's MENU panel fits the screen it is on", function()
		for _, view in { UPRIGHT, SIDEWAYS, Vector2.new(320, 568) } do
			local panel = RunHudRules.top(view, true, TOP_BAR).panel
			t.notNil(panel, "a phone has a panel box")
			if panel then
				t.isTrue(panel.x >= 0 and panel.x + panel.w <= view.X, "fits across")
				t.isTrue(panel.y >= 0 and panel.y + panel.h <= view.Y, "fits down")
				t.isTrue(panel.w >= 280, "wide enough to read on the narrowest phone")
			end
		end
	end)

	t.test("rooms are pips only while there are few enough to draw", function()
		local ten = RunHudRules.pips(4, 10, "Fighting")
		t.notNil(ten, "ten rooms are pips")
		if ten then
			t.equal(ten.count, 10)
			t.equal(ten.lit, 3, "three rooms behind you")
			t.equal(ten.current, 4, "the fourth is being fought")
		end
		local cleared = RunHudRules.pips(4, 10, "Cleared")
		if cleared then
			t.equal(cleared.lit, 4, "a cleared room is lit")
			t.isNil(cleared.current, "nothing is being fought between rooms")
		end
		t.isNil(RunHudRules.pips(12, 40, "Fighting"), "forty rooms keep the counter")
		t.isNil(RunHudRules.pips(0, 0, "Fighting"), "no rooms, no pips")
		t.notNil(RunHudRules.pips(1, Hud.top.maxPips, "Fighting"), "the most that is drawn")
	end)

	t.test("the counter names the unit the server sent", function()
		t.equal(RunHudRules.counter(4, 10, "Room"), "ROOM 4/10")
		t.equal(RunHudRules.counter(2, 5, "Wave"), "WAVE 2/5")
		t.equal(RunHudRules.counter(17, 100, "Floor"), "FLOOR 17/100")
		t.equal(RunHudRules.counter(1, 3, nil), "ROOM 1/3")
	end)

	t.test("the status line never promises a restart", function()
		local dead = RunHudRules.status("Dead", "Room")
		t.equal(dead.tone, "Bad")
		t.isTrue(dead.words ~= "", "a death says something")
		t.isNil(string.find(string.lower(dead.words), "restart"), "nothing restarts by itself")
		t.equal(RunHudRules.status("Fighting", "Room").words, "", "a fight needs no line")
		t.isTrue(
			RunHudRules.status("Cleared", "Wave").words
				~= RunHudRules.status("Cleared", "Room").words,
			"a wave has no exit to send the player to"
		)
		t.equal(RunHudRules.status("Complete", "Room").tone, "Good")
	end)

	t.test("the draft's phone buttons are thumb sized and fit the width", function()
		for _, width in { 320, 360, 390, 412, 430 } do
			local tray = RunHudRules.draftTray(width)
			t.isTrue(tray.width <= width, `the tray fits a {width}-point phone`)
			t.isTrue(tray.buttonHeight >= THUMB, `the buttons are thumb sized at {width}`)
		end
		t.near(RunHudRules.draftTray(390).buttonHeight, 56, 1, "56 points on a 390-point phone")
		local d = Hud.draftUpright
		t.isTrue(d.wordsHeight + d.buttonsHeight <= d.sheet.Y, "the box and buttons fit the tray")
		t.isTrue(d.rerollWidth + d.gap < d.sheet.X, "CHOOSE! has room beside REROLL")
		t.isTrue(d.wordsSize >= 16, "the card is read out in words a phone can read")
	end)
end
