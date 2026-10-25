--!strict
--[[
	The background music (owner, 2026-10-24: "i need music playing in the
	background now"), played by `Fx/MusicFx`: one playlist for an ordinary
	room and one for a boss fight, each looping through its tracks, and one
	kept for the lobby.

	Rooms play the level theme, Hilltop (`assets/audio/music/level_theme.py`,
	picked 2026-10-24: "engaging but not overpowering"), alone so it loops
	seamlessly. The Mossy Glade theme (`glade_theme.py`, take B) is the
	lobby's (owner: "the current level music will be the lobby music so keep
	it in the game so its ready"): nothing plays the Lobby playlist until a
	lobby exists (docs/LOBBY.md). Boss fights play King Bloblin's theme
	(`boss_theme.py`, take B with the Dive intro, picked 2026-10-24): a
	battle intro once as the boss appears, like a trainer battle's (owner:
	"for every boss, i want an intro part"), then the loop. Music from other
	uploaders is left out: some is ripped from other games, which this
	project never uses (CLAUDE.md, Sounds). Swap ids here to change the music; the
	audition page saves the owner's picks for Claude to put here.
]]

--[[ `loopStart`/`loopEnd` (seconds): the track plays once from the top (a
	boss's battle intro), then loops round that region (`Sound.LoopRegion`). ]]
export type Track = { id: string, name: string, loopStart: number?, loopEnd: number? }

local Music = {
	--[[ Loudness under the sound effects, which carry the fight. ]]
	volume = 0.3,
	--[[ Seconds one playlist takes to fade into another. ]]
	fade = 1.5,
	playlists = {
		Rooms = {
			-- ours, 92 s, made to loop: a lone track loops in the engine
			{ id = "rbxassetid://74156980070396", name = "Mossy Glade (B)" },
		} :: { Track },
		--[[ Ready for the lobby; `MusicFx` never makes it current yet. ]]
		Lobby = {
			{ id = "rbxassetid://74156980070396", name = "Mossy Glade (B)" },
		} :: { Track },
		Boss = {
			-- ours, 87 s: a 4.7 s intro, then the 75.8 s loop from 10.74 s (after the intro's tail)
			{
				id = "rbxassetid://127708487537452",
				name = "King Bloblin (B, Dive)",
				loopStart = 10.736848,
				loopEnd = 86.526327,
			},
		} :: { Track },
	},
}

return table.freeze(Music)
