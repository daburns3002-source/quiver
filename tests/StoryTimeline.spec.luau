--!strict
--[[
	The story cutscene's timeline (`Config/Story`, `Util/StoryTimeline`).

	One frame at a time: it opens and closes on black, shows every frame once
	in the storyboard's order, only lets the run go once the black has held,
	and SKIP cuts to black, never lengthening it. Every frame it shows must have
	its uploaded picture.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
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
	t.test("every sound cue is a real sound, inside a real shot", function()
		for _, cue in Story.sounds do
			t.notNil(Sounds[cue.sound], `the story plays unknown sound {cue.sound}`)
			local index = indexOf(cue.shot)
			t.notNil(index, `a sound is cued on unknown shot {cue.shot}`)
			if index then
				local length = 0
				for _, frame in Story.shots[index].frames do
					length += frame.hold
				end
				t.isTrue(cue.at >= 0 and cue.at < length, `{cue.sound} is cued outside {cue.shot}`)
			end
		end
	end)

	t.test("the ding lands as the King's small eyes and raised brow come in", function()
		--[[ The Eyes shot is two pictures: reading, then the small pupils and
		     the lifted eyebrow (f12b, drawn with the ding's marks). ]]
		local index = indexOf("Eyes")
		t.notNil(index, "the story has no Eyes shot")
		local found = false
		for _, cue in Story.sounds do
			if cue.sound == "story_king_ding" then
				found = true
				t.equal(cue.shot, "Eyes")
				if index then
					local frames = Story.shots[index].frames
					t.equal(#frames, 2, "the Eyes shot's pictures")
					t.equal(frames[2].picture, "f12b")
					t.near(cue.at, frames[1].hold, 1e-6)
				end
			end
		end
		t.isTrue(found, "the story never plays the ding")
	end)

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
end
