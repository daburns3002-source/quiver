--!strict
--[[
	The music table (`Config/Music`): every id is empty or an asset, and the
	intro's title theme loops only after the cut (`Config/Intro.revealAt`), so the cutscene's cut
	lands on the first pass and the loop never replays the build.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Intro = require(ReplicatedStorage.Shared.Config.Intro)
local Music = require(ReplicatedStorage.Shared.Config.Music)
local TestRunner = require(script.Parent.TestRunner)

local function isAsset(id: string): boolean
	return id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil
end

return function(t: TestRunner.Helper)
	t.test("every track is empty or a Roblox asset, its loop inside it", function()
		for name, list in Music.playlists :: { [string]: { Music.Track } } do
			for _, track in list do
				t.isTrue(
					isAsset(track.id),
					`{name}'s {track.name} id {track.id} is not an asset id`
				)
				t.isTrue(
					(track.loopStart == nil) == (track.loopEnd == nil),
					`{track.name} has half a loop`
				)
				if track.loopStart and track.loopEnd then
					t.isTrue(track.loopStart < track.loopEnd, `{track.name}'s loop runs backwards`)
				end
			end
		end
	end)

	t.test("the title theme hits on the cut, then loops past its build", function()
		local intro = Music.intro
		t.isTrue(isAsset(intro.id), `the title theme's id {intro.id} is not an asset id`)
		t.isTrue(
			intro.hitAt > 0 and intro.hitAt <= intro.loopStart,
			"the loop would replay the build"
		)
		t.isTrue(
			intro.loopEnd - intro.loopStart > 10,
			"the title screen's loop is too short to sit under"
		)
	end)
end
