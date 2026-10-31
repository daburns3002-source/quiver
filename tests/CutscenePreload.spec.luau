--!strict
--[[
	What the two cutscenes wait for before they start, and what they load
	behind themselves once they have (`UI/IntroCutscene`, `UI/StoryCutscene`,
	`client/Preload`).

	Both used to ask for every asset they could ever draw before showing
	anything: the title fetched its picture in both orientations and timed its
	cut off the music alone, and the story fetched all forty frames in both
	orientations and waited for the lot. On a phone neither finished in time,
	so the title cut to black and the story skipped its way through
	(owner, 2026-10-27).

	The fix is a split — a small set that is waited for, and a large set that
	is not — so what these pin is that the split stays a split: that the lead
	is genuinely small, that it buys more running time than it costs, and that
	one orientation's assets are always a complete picture on their own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local DeviceTiers = require(ReplicatedStorage.Shared.Config.DeviceTiers)
local Intro = require(ReplicatedStorage.Shared.Config.Intro)
local Story = require(ReplicatedStorage.Shared.Config.Story)
local TestRunner = require(script.Parent.TestRunner)

local Preload = require(StarterPlayer.StarterPlayerScripts.Client.Preload) :: any

--[[ Every frame the story shows, once each, in order — the same walk
     `StoryCutscene` makes. ]]
local function frames(): { string }
	local seen, out = {}, {}
	for _, shot in Story.shots do
		for _, frame in shot.frames do
			if not seen[frame.picture] then
				seen[frame.picture] = true
				table.insert(out, frame.picture)
			end
		end
	end
	return out
end

--[[ The frames of the first `Story.leadShots` shots, and the seconds of
     cutscene they cover. ]]
local function lead(): ({ string }, number)
	local seen, out, seconds = {}, {}, 0
	for index, shot in Story.shots do
		if index > Story.leadShots then
			break
		end
		for _, frame in shot.frames do
			seconds += frame.hold
			if not seen[frame.picture] then
				seen[frame.picture] = true
				table.insert(out, frame.picture)
			end
		end
	end
	return out, seconds
end

return function(t: TestRunner.Helper)
	local all = frames()
	local leadFrames, leadSeconds = lead()

	t.test("the story waits for an opening, not for the whole cutscene", function()
		t.isTrue(Story.leadShots >= 1, "at least one shot is waited for")
		t.isTrue(Story.leadShots < #Story.shots, "and not all of them")
		t.isTrue(#leadFrames < #all // 2, `{#leadFrames} lead frames of {#all}`)
	end)

	--[[ The point of the lead is to buy time for everything behind it, so it
	     has to be worth more seconds of screen than it is frames of loading.
	     Each remaining frame is two halves, and a phone that manages even one
	     half a second has the rest in hand before the lead runs out — this
	     holds the lead long enough for that to be true. ]]
	t.test("the lead buys more time than it costs", function()
		t.isTrue(leadSeconds >= Story.loadWait, "the lead outlasts the black screen's cap")
		t.isTrue(leadSeconds >= #leadFrames, `{leadSeconds}s over {#leadFrames} frames`)
	end)

	--[[ Only one orientation is fetched now, so each set has to be able to
	     draw the whole cutscene by itself. `StoryTimeline.spec` pins that
	     every frame has a portrait; this pins that neither set is short of a
	     half, which is what would make a frame fetch as "in" and then draw
	     with a hole in it. ]]
	t.test("either orientation alone is a complete set of frames", function()
		for _, name in all do
			local wide = Story.pictures[name]
			t.notNil(wide, `{name} has landscape halves`)
			if wide then
				t.isTrue(wide.left ~= "" and wide.right ~= "", `{name}'s landscape halves`)
			end
			local tall = Story.portraits[name]
			if tall then
				t.isTrue(tall.top ~= "" and tall.bottom ~= "", `{name}'s portrait halves`)
			end
		end
	end)

	--[[ The window that keeps frames in video memory slides with the
	     cutscene, so it may be small, but a window of nothing would decode
	     every frame on its own turn — the stutter this is here to stop. ]]
	t.test("every tier holds at least the next frame or two warm", function()
		local last = 0
		for _, name in { "Low", "Medium", "High" } do
			local tier = (DeviceTiers :: any)[name]
			t.isTrue(tier.warmStoryFrames >= 2, `{name} holds more than the frame on screen`)
			t.isTrue(tier.warmStoryFrames >= last, `{name} holds no fewer than the tier below`)
			last = tier.warmStoryFrames
		end
		t.isTrue(
			DeviceTiers.High.warmStoryFrames >= #all,
			"the top tier can hold the whole cutscene"
		)
	end)

	--[[ The title's cut is timed from the clock, which is held until the
	     tiles are in, so the cap has to leave room for a picture to arrive
	     before the cut lands on it. ]]
	t.test("the title screen waits for its tiles before it cuts to them", function()
		t.isTrue(Intro.tilesWait > 0, "there is a wait at all")
		t.isTrue(Intro.tilesWait >= Intro.musicWait, "at least as long as the music is given")
	end)

	--[[ One orientation is fetched, so each has to be a whole picture: a grid
	     with a tile for every cell, and the water the motion draws on it. ]]
	t.test("either title picture alone covers its own grid", function()
		local count = 0
		for key, art in Intro.pictures :: { [string]: any } do
			count += 1
			t.equal(#art.tiles, art.cols * art.rows, `{key} has a tile per cell`)
			t.isTrue(art.water.image ~= "", `{key} has its water`)
		end
		t.equal(count, 2, "a landscape and a portrait picture")
		t.notNil((Intro.pictures :: any).landscape, "landscape")
		t.notNil((Intro.pictures :: any).portrait, "portrait")
	end)

	--[[ `Preload.idsIn` is what walks a config table for things to fetch.
	     Handing `PreloadAsync` a string that is not an asset id is an error,
	     not a no-op, so it has to pick out ids and nothing else. ]]
	t.test("the config walk finds asset ids and only asset ids", function()
		local found = Preload.idsIn({
			name = "King Bloblin",
			icon = "rbxassetid://123",
			nested = { also = "rbxassetid://456", words = "SKIP" },
			again = "rbxassetid://123",
			empty = "",
		})
		table.sort(found)
		t.equal(#found, 2, "two ids, deduplicated")
		t.equal(found[1], "rbxassetid://123")
		t.equal(found[2], "rbxassetid://456")
	end)

	t.test("the config walk can be told to skip a branch", function()
		local icons = { one = "rbxassetid://999" }
		local found = Preload.idsIn({ frame = "rbxassetid://111", icons = icons }, icons)
		t.equal(#found, 1, "the skipped branch is left out")
		t.equal(found[1], "rbxassetid://111")
	end)
end
