--!strict
--[[
	The background music (owner, 2026-10-24: "i need music playing in the
	background now"), played by `Fx/MusicFx`: one playlist for an ordinary
	room and one for a boss fight, each looping through its tracks.

	Rooms play our own Mossy Glade theme (made from scratch by
	`assets/audio/music/glade_theme.py`, take B, picked 2026-10-24), alone
	so it loops seamlessly. The Boss tracks are from APMOfficial, the music
	library Roblox licenses for any experience. Tracks from other uploaders
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
		Rooms = {
			-- ours, 92 s, made to loop: a lone track loops in the engine
			{ id = "rbxassetid://74156980070396", name = "Mossy Glade (B)" },
		} :: { Track },
		Boss = {
			{ id = "rbxassetid://1848107874", name = "Fight For A Tomorrow" },
			-- heroic orchestral, 110 s
			{ id = "rbxassetid://9046503137", name = "Imminent Closure" },
		} :: { Track },
	},
}

return table.freeze(Music)
