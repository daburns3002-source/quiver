--!strict
--[[
	The background music (owner, 2026-10-24: "i need music playing in the
	background now"), played by `Fx/MusicFx`: one playlist for an ordinary
	room and one for a boss fight, each looping through its tracks.

	Every track is from APMOfficial, the music library Roblox licenses for
	any experience, so nothing needs uploading. Tracks from other uploaders
	are left out: some are music ripped from other games, which this project
	never uses (CLAUDE.md, Sounds). Swap ids here to change the music; the
	audition page saves the owner's picks for Claude to put here.
]]

export type Track = { id: string, name: string }

local Music = {
	--[[ Loudness under the sound effects, which carry the fight. ]]
	volume = 0.3,
	--[[ Seconds one playlist takes to fade into another. ]]
	fade = 1.5,
	playlists = {
		-- Our own Mossy Glade theme goes here alone once uploaded (`assets/audio/music`), so it loops
		Rooms = {
			-- children's adventure bed, 116 s
			{ id = "rbxassetid://1842185080", name = "Explore OL (a)" },
			{ id = "rbxassetid://1838928331", name = "Nature Discovery" },
			-- fantastical action adventure orchestral, 60 s
			{ id = "rbxassetid://9043602056", name = "Ghost Ship (a 60)" },
		} :: { Track },
		Boss = {
			{ id = "rbxassetid://1848107874", name = "Fight For A Tomorrow" },
			-- heroic orchestral, 110 s
			{ id = "rbxassetid://9046503137", name = "Imminent Closure" },
		} :: { Track },
	},
}

return table.freeze(Music)
