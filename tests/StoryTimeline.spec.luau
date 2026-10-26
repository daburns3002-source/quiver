--!strict
--[[
	The story cutscene's timeline (`Config/Story`, `Util/StoryTimeline`).

	It must open and close on black, play its shots in the storyboard's order,
	only let the run go once the black has held, and SKIP must shorten it, never
	lengthen it. Every frame it shows must have its uploaded picture.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage.Shared.Config.Story)
local StoryTimeline = require(ReplicatedStorage.Shared.Util.StoryTimeline)
local TestRunner = require(script.Parent.TestRunner)

local c = Story :: any

local function indexOf(name: string): number?
	for i, shot in Story.shots do
		if shot.name == name then
			return i
		end
	end
	return nil
end

return function(t: TestRunner.Helper)
	t.test("it opens black and ends black, held, before the run is let go", function()
		t.equal(StoryTimeline.pose(c, 0).black, 1)
		local length = StoryTimeline.length(c)
		local blackAt = StoryTimeline.blackAt(c)
		t.equal(StoryTimeline.pose(c, blackAt).black, 1)
		t.isFalse(StoryTimeline.pose(c, length - 1e-3).done)
		t.isTrue(StoryTimeline.pose(c, length).done)
		t.isTrue(Story.blackHold > 0)
	end)

	t.test("the story's beats come in the owner's order", function()
		local order =
			{ "Glade", "Chest", "Offer", "Poster", "Steam", "Roar", "Pan", "Startled", "Away" }
		local last = 0
		for _, name in order do
			local i = indexOf(name)
			t.isTrue(i ~= nil)
			t.isTrue((i :: number) > last)
			last = i :: number
		end
	end)

	t.test("every shot shows its own frames, and only while it is on", function()
		local starts = StoryTimeline.starts(c)
		for i, shot in Story.shots do
			t.isTrue(shot.length > 0)
			local pose = StoryTimeline.pose(c, starts[i] + shot.length / 2)
			t.equal(pose.shot, i)
			local own = false
			for _, frame in shot.frames do
				t.isTrue(frame.hold > 0)
				own = own or frame.picture == pose.picture
			end
			t.isTrue(own)
		end
	end)

	t.test("a shot that does not loop has frames for all of its length", function()
		for _, shot in Story.shots do
			if not shot.loop then
				local total = 0
				for _, frame in shot.frames do
					total += frame.hold
				end
				t.near(total, shot.length, 1e-6)
			end
		end
	end)

	t.test("the roar shakes the screen", function()
		local i = indexOf("Roar") :: number
		local starts = StoryTimeline.starts(c)
		local pose = StoryTimeline.pose(c, starts[i] + 0.3)
		t.isTrue(pose.shake.Magnitude > 0)
	end)

	t.test("the pan travels across the forest to the heroes", function()
		local i = indexOf("Pan") :: number
		local shot = Story.shots[i]
		local starts = StoryTimeline.starts(c)
		t.isTrue((shot.zoom :: any).from > 1)
		t.isTrue(
			StoryTimeline.pose(c, starts[i]).pan
				< StoryTimeline.pose(c, starts[i] + shot.length - 1e-3).pan
		)
	end)

	t.test("SKIP fades to black at once and never lengthens it", function()
		local at = Story.skipAt + 2
		t.isTrue(StoryTimeline.length(c, at) < StoryTimeline.length(c))
		t.equal(StoryTimeline.pose(c, at + Story.skipFade, at).black, 1)
		t.isTrue(StoryTimeline.pose(c, at + Story.skipFade + Story.blackHold, at).done)
		local late = StoryTimeline.blackAt(c) - 0.1
		t.isTrue(StoryTimeline.length(c, late) <= StoryTimeline.length(c))
	end)

	t.test("every frame shown has its uploaded picture", function()
		for _, shot in Story.shots do
			for _, frame in shot.frames do
				local halves = Story.pictures[frame.picture]
				t.isTrue(halves ~= nil)
				if halves then
					t.isTrue(halves.left:match("^rbxassetid://%d+$") ~= nil)
					t.isTrue(halves.right:match("^rbxassetid://%d+$") ~= nil)
				end
			end
		end
	end)
end
