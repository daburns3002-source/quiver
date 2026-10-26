--!strict
--[[
	The intro cutscene's timeline (`Config/Intro`, `Util/IntroTimeline`).

	The picture must land on the intro music's hit, which the music session
	built to the contract's 5.0 s; the words must be gone by then, the
	button must not be pressable before it is there, and the press must
	take the cutscene away.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Intro = require(ReplicatedStorage.Shared.Config.Intro)
local IntroTimeline = require(ReplicatedStorage.Shared.Util.IntroTimeline)
local TestRunner = require(script.Parent.TestRunner)

local c = Intro :: any

return function(t: TestRunner.Helper)
	t.test("the cut lands on the music's hit, the contract's 5.0 s", function()
		t.equal(Intro.revealAt, 5.0)
		t.isFalse(IntroTimeline.pose(c, Intro.revealAt - 1e-3).revealed)
		t.isTrue(IntroTimeline.pose(c, Intro.revealAt).revealed)
	end)

	t.test("the screen is black and empty at the start", function()
		local pose = IntroTimeline.pose(c, 0)
		t.equal(pose.presents, 0)
		t.isFalse(pose.revealed)
		t.equal(pose.button, 0)
		t.equal(pose.shown, 1)
	end)

	t.test("the words are fully up between fading in and out, and gone before the cut", function()
		t.isTrue(Intro.presentsIn + Intro.presentsFadeIn <= Intro.presentsOut)
		t.isTrue(Intro.presentsOut + Intro.presentsFadeOut <= Intro.revealAt)
		local held = IntroTimeline.pose(c, Intro.presentsIn + Intro.presentsFadeIn)
		t.near(held.presents, 1, 1e-6)
		t.near(held.presentsScale, 1, 1e-6)
		t.near(IntroTimeline.pose(c, Intro.presentsOut + Intro.presentsFadeOut).presents, 0, 1e-9)
	end)

	t.test("the cut flashes and the flash fades", function()
		t.near(IntroTimeline.pose(c, Intro.revealAt).flash, 1, 1e-6)
		t.near(IntroTimeline.pose(c, Intro.revealAt + Intro.flash).flash, 0, 1e-9)
	end)

	t.test("the button comes after the cut and only counts once it is there", function()
		t.isTrue(Intro.buttonAt >= Intro.revealAt)
		t.isFalse(IntroTimeline.canPress(c, Intro.buttonAt - 1e-3))
		t.isTrue(IntroTimeline.canPress(c, Intro.buttonAt))
		t.near(IntroTimeline.pose(c, Intro.buttonAt + Intro.buttonIn).button, 1, 1e-6)
	end)

	t.test("once the title is fully up, nothing on it changes", function()
		local up = Intro.buttonAt + Intro.buttonIn
		local a = IntroTimeline.pose(c, up)
		for s = 0, 120, 0.7 do
			local b = IntroTimeline.pose(c, up + s)
			t.equal(b.flash, a.flash)
			t.equal(b.button, a.button)
			t.equal(b.shown, a.shown)
		end
	end)

	t.test("pressing fades it all away and then it is done", function()
		local pressed = Intro.buttonAt + 2
		t.equal(IntroTimeline.pose(c, pressed, pressed).shown, 1)
		t.isFalse(IntroTimeline.pose(c, pressed, pressed).done)
		t.isTrue(IntroTimeline.pose(c, pressed + Intro.leave, pressed).done)
	end)

	t.test("each title picture is a full grid of tiles, its water and leaves on the art", function()
		for key, art in Intro.pictures :: { [string]: any } do
			t.equal(#art.tiles, art.cols * art.rows, key)
			-- a tile of the 2x enlargement stays inside Roblox's 1024 px limit
			t.isTrue(art.width * 2 / art.cols <= 1024 and art.height * 2 / art.rows <= 1024, key)
			local box = art.water.box
			t.isTrue(box.x >= 0 and box.y >= 0, key)
			t.isTrue(box.x + box.w <= art.width and box.y + box.h <= art.height, key)
			local from = art.leavesFrom
			t.isTrue(from.x + from.w <= art.width and from.y + from.h <= art.height, key)
		end
		t.isTrue(Intro.pictures.portrait.height > Intro.pictures.portrait.width)
		t.isTrue(Intro.pictures.landscape.width > Intro.pictures.landscape.height)
	end)

	t.test(
		"on a full-screen computer the title fills the screen; on an ultrawide it shows whole",
		function()
			local art = Intro.pictures.landscape
			local function fills(w: number, h: number): boolean
				local scale, x, y =
					IntroTimeline.fit(art.width, art.height, w, h, Intro.maxCrop, Intro.cropTop)
				return x <= 0.5
					and y <= 0.5
					and art.width * scale + x >= w - 0.5
					and art.height * scale + y >= h - 0.5
			end
			for _, screen in
				{ { 1920, 1080 }, { 2560, 1440 }, { 1366, 768 }, { 1920, 1200 }, { 1440, 900 } }
			do
				t.isTrue(fills(screen[1], screen[2]), `{screen[1]}x{screen[2]}`)
			end
			-- 21:9: filling would crop a quarter of the picture, so it stays whole
			local scale =
				IntroTimeline.fit(art.width, art.height, 2560, 1080, Intro.maxCrop, Intro.cropTop)
			t.near(scale, 1080 / art.height, 1e-6)
			-- a crop of its height comes mostly off the bottom, so the logo stays
			local _, _, y =
				IntroTimeline.fit(art.width, art.height, 2000, 1000, Intro.maxCrop, Intro.cropTop)
			t.isTrue(y <= 0 and -y < 0.05 * 1000)
		end
	)
end
