--!strict
--[[
	A player's own settings (the 2026-11-11 loop and UI review: "no music or
	sound volume, and no phone vibration on hit, dash or level-up, anywhere").

	`defaults` is what a new player has. A volume is a share of the game's
	own (`Config/Music.volume`, each sound's `volume` in `Config/Sounds`),
	set in `steps` equal steps from silent to full. `attributes` are the
	Player attributes the server sets from the save and the client reads
	(`Server/Data/Settings`, `client/Options`); `haptics` is whether the
	phone or gamepad shakes (`Fx/Haptics`).
]]

return table.freeze({
	defaults = { music = 1, sound = 1, haptics = true },
	steps = 4,
	attributes = { music = "MusicVolume", sound = "SoundVolume", haptics = "Haptics" },
})
