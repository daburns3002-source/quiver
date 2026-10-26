--!strict
--[[
	The story cutscene's timeline (`Config/Story`, `Util/StoryTimeline`).

	One frame at a time: it opens and closes on black, shows every frame once
	in the storyboard's order, only lets the run go once the black has held,
	and SKIP cuts to black, never lengthening it. Every frame it shows must have
	its uploaded picture.
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
		t.isTrue(StoryTimeline.pose(c, 0).picture == nil)
		local length = StoryTimeline.length(c)
		local blackAt = StoryTimeline.blackAt(c)
		t.isTrue(StoryTimeline.pose(c, blackAt).picture == nil)
		t.isFalse(StoryTimeline.pose(c, length - 1e-3).done)
		t.isTrue(StoryTimeline.pose(c, length).done)
		t.isTrue(Story.blackHold > 0)
	end)

	t.test("the story's beats come in the owner's order", function()
		local order =
			{ "Glade", "Chest", "Lounge", "Yawn", "Offer", "Steam", "Roar", "Pan", "Faces", "Away" }
		local last = 0
		for _, name in order do
			local i = indexOf(name)
			t.isTrue(i ~= nil)
			t.isTrue((i :: number) > last)
			last = i :: number
		end
	end)

	t.test("every frame shows once, in order, for its hold", function()
		local starts = StoryTimeline.starts(c)
		local seen = {}
		for i, shot in Story.shots do
			local at = starts[i]
			for _, frame in shot.frames do
				t.isTrue(frame.hold > 0)
				t.isTrue(seen[frame.picture] == nil)
				seen[frame.picture] = true
				local pose = StoryTimeline.pose(c, at + frame.hold / 2)
				t.equal(pose.shot, i)
				t.equal(pose.picture, frame.picture)
				at += frame.hold
			end
		end
	end)

	t.test("SKIP cuts to black and never lengthens it", function()
		local at = Story.skipAt + 2
		t.isTrue(StoryTimeline.length(c, at) < StoryTimeline.length(c))
		t.isTrue(StoryTimeline.pose(c, at, at).picture == nil)
		t.isTrue(StoryTimeline.pose(c, at + Story.blackHold, at).done)
		local late = StoryTimeline.blackAt(c) + 0.1
		t.equal(StoryTimeline.length(c, late), StoryTimeline.length(c))
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

	t.test(
		"the portrait frames cover every frame or none, each with its uploaded halves",
		function()
			local any = next(Story.portraits) ~= nil
			for _, shot in Story.shots do
				for _, frame in shot.frames do
					local tall = Story.portraits[frame.picture]
					t.equal(tall ~= nil, any)
					if tall then
						t.isTrue(tall.top:match("^rbxassetid://%d+$") ~= nil)
						t.isTrue(tall.bottom:match("^rbxassetid://%d+$") ~= nil)
					end
				end
			end
		end
	)
end
