--!strict
--[[
	The story through the areas (`Config/StoryBeats`, `Util/StoryBeatRules`):
	a beat is owed once per beaten boss, a still's picture always covers its
	window, and every beat is whole: one per area in the story's order, its
	boss's name as the game writes it, four stills ending on a poster, every
	sound known and every still uploaded.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossBanners = require(ReplicatedStorage.Shared.Config.BossBanners)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local StoryBeatRules = require(ReplicatedStorage.Shared.Util.StoryBeatRules)
local StoryBeats = require(ReplicatedStorage.Shared.Config.StoryBeats)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a beat is owed once its boss is beaten, until it is watched", function()
		t.isFalse(StoryBeatRules.due("Thornwood", {}, {}), "boss not beaten")
		t.isTrue(StoryBeatRules.due("Thornwood", { Thornwood = true }, {}))
		t.isFalse(StoryBeatRules.due("Thornwood", { Thornwood = true }, { Thornwood = true }))
		t.isFalse(StoryBeatRules.due(nil, { Thornwood = true }, {}), "a stage with no area")
		t.isFalse(StoryBeatRules.due("Endless", { Endless = true }, {}), "an area with no beat")
	end)

	t.test("only an area with a beat may be marked watched", function()
		t.isTrue(StoryBeatRules.isArea("MossyGlade"))
		t.isFalse(StoryBeatRules.isArea("Endless"))
		t.isFalse(StoryBeatRules.isArea(3))
		t.isFalse(StoryBeatRules.isArea(nil))
	end)

	t.test("a still's picture covers its window all along its move", function()
		for area, beat in StoryBeats.beats do
			for _, still in beat.stills do
				for _, k in { -0.5, 0, 0.25, 0.5, 0.75, 1, 1.5 } do
					local pos, size = StoryBeatRules.place(still, k)
					local where = `{area} {still.picture} at {k}`
					t.isTrue(size.X >= 1 and size.Y >= 1, `{where}: smaller than its window`)
					t.isTrue(pos.X <= 1e-6 and pos.Y <= 1e-6, `{where}: an edge shows top-left`)
					t.isTrue(pos.X + size.X >= 1 - 1e-6, `{where}: an edge shows right`)
					t.isTrue(pos.Y + size.Y >= 1 - 1e-6, `{where}: an edge shows below`)
				end
			end
		end
	end)

	t.test("a move starts at its from and ends at its to", function()
		local still = StoryBeats.beats.MossyGlade.stills[3]
		local pos, size = StoryBeatRules.place(still, 0)
		t.near(size.X, still.from.zoom, 1e-6)
		t.near(pos.X, 0.5 - still.from.x * still.from.zoom, 1e-6)
		pos, size = StoryBeatRules.place(still, 1)
		t.near(size.X, still.to.zoom, 1e-6)
		t.near(pos.X, 0.5 - still.to.x * still.to.zoom, 1e-6)
	end)

	t.test("one beat per area, in the story's order, each ending on a poster", function()
		t.equal(#StoryBeats.order, 4)
		for _, area in StoryBeats.order do
			local beat = StoryBeats.beats[area]
			t.notNil(beat, `{area} has no beat`)
			t.notNil(Economy.areas[area], `{area} is not an Economy area`)
			t.equal(#beat.stills, 4, `{area}'s beat has four stills`)
			for i, still in beat.stills do
				t.isTrue(#still.words > 0, `{area} still {i} has no words`)
				t.isTrue(
					still.hold > StoryBeats.tapAfter,
					`{area} still {i} is gone before a tap counts`
				)
				t.equal(
					still.poster == true,
					i == #beat.stills,
					`{area}: only the last still is the poster`
				)
				if still.sound then
					t.notNil(
						Sounds[still.sound],
						`{area} still {i} plays unknown sound {still.sound}`
					)
				end
			end
		end
	end)

	t.test("each beat names its boss as the game does", function()
		for area, beat in StoryBeats.beats do
			local named = false
			for _, banner in BossBanners.bosses do
				named = named or banner.name == beat.boss
			end
			t.isTrue(named, `{area}'s boss {beat.boss} is no boss banner's name`)
			local item = Economy.items[Economy.areas[area].bossItem]
			t.equal(item.boss, beat.boss, `{area}'s boss item names another boss`)
		end
	end)

	t.test("every move stays inside its picture, so none is cut short", function()
		for area, beat in StoryBeats.beats do
			for _, still in beat.stills do
				for _, m in { still.from, still.to } do
					local half = 0.5 / m.zoom
					t.isTrue(m.zoom >= 1, `{area} {still.picture}: zoomed out past the picture`)
					t.isTrue(
						m.x >= half - 1e-6
							and m.x <= 1 - half + 1e-6
							and m.y >= half - 1e-6
							and m.y <= 1 - half + 1e-6,
						`{area} {still.picture}: the middle {m.x}, {m.y} is too near an edge for zoom {m.zoom}`
					)
				end
			end
		end
	end)

	t.test("every still is uploaded", function()
		for area, beat in StoryBeats.beats do
			for _, still in beat.stills do
				local ids = StoryBeats.pictures[still.picture]
				t.notNil(ids, `{area}'s still {still.picture} has no uploaded halves`)
				if ids then
					t.isTrue(
						string.match(ids.left, "^rbxassetid://%d+$") ~= nil
							and string.match(ids.right, "^rbxassetid://%d+$") ~= nil,
						`{still.picture}'s ids are not asset ids`
					)
				end
			end
		end
	end)
end
