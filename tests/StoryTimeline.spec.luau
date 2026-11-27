--!strict
--[[
	The story cutscene's timeline (`Config/Story`, `Util/StoryTimeline`).

	One frame at a time: it opens and closes on black, shows every frame once
	in the storyboard's order, only lets the run go once the black has held,
	and SKIP cuts to black, never lengthening it. Every frame it shows must have
	its uploaded picture.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Music = require(ReplicatedStorage.Shared.Config.Music)
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
	t.test("every shot comes in on the music's own cue", function()
		--[[ The music is one uploaded track and cannot move, so the pictures
		     keep to it (owner, 2026-11-12). A hold changed without the other
		     holds giving the time back fails here, by shot. ]]
		local cues: { [string]: number } = Music.story.cues or {}
		local starts, ends = StoryTimeline.starts(c)
		local checked = 0
		for name, at in cues do
			local index = indexOf(name)
			t.notNil(index, `the music cues unknown shot {name}`)
			if index then
				checked += 1
				t.isTrue(
					math.abs(starts[index] - at) <= 0.05,
					`{name} comes in at {starts[index]}, off its cue at {at}`
				)
			end
		end
		t.isTrue(checked >= 15, "most shots are held to a cue")
		--[[ And the music (45.6 s) outlasts the pictures and their black. ]]
		t.isTrue(ends + Story.blackHold <= 45.6, "the cutscene outlasts its music")
	end)

	t.test("the ding rings as the King's small eyes and raised brow come in", function()
		--[[ The Eyes shot is two pictures: reading, then the small pupils and
		     the lifted eyebrow (f12b, drawn with the ding's marks). The ding
		     is in the music. ]]
		local index = indexOf("Eyes")
		t.notNil(index, "the story has no Eyes shot")
		local ding = Music.story.ding
		t.notNil(ding, "the story's music has no ding")
		if index and ding then
			local starts = StoryTimeline.starts(c)
			local frames = Story.shots[index].frames
			t.equal(#frames, 2, "the Eyes shot's pictures")
			t.equal(frames[2].picture, "f12b")
			t.isTrue(
				math.abs(starts[index] + frames[1].hold - ding) <= 0.05,
				"the small eyes come in off the ding"
			)
		end
	end)

	t.test("every sound cue is a real sound, on a real shot's own time", function()
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
