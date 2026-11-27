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
end
