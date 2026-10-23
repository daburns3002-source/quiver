--!strict
--[[
	The game's sound effects, by name, as `Fx/SoundFx` plays them.

	Every sound is made in `assets/audio/synth.py` and chosen by the owner in
	the audition (https://claude.ai/artifact/E53Pu8d5UbwLKnyKYEDo2K). The
	owner uploads the chosen file to Roblox and its id goes in `id`; until
	then `id` is empty and the sound is silent, so the game runs the same
	with or without its audio.

	Chosen and uploaded so far (2026-10-23, `assets/audio/final/`): player
	hurt, XP crystal, heart, level up, enemy hit, dash, card pick, arrow
	fire, staff cast and enemy death; the Warden's swing and slam are
	Roblox's own. Still to upload: the gate opening.

	`volume` is 0–1 on top of the file's own level (the audition levels each
	sound for its job already). `pitchJitter` varies each play by up to that
	share either way, so a sound heard many times in a row does not
	machine-gun. `minGap` is the fewest seconds between two plays, for the
	sounds that can fire many times in one frame.
]]

export type Sound = {
	id: string,
	volume: number,
	--[[ Playback speed, when not 1: above it plays faster and higher. ]]
	speed: number?,
	pitchJitter: number,
	minGap: number,
}

local Sounds: { [string]: Sound } = {
	--[[ The Ranger's every arrow (`Config/Weapons.LeafBow.fireSound`). ]]
	arrow_fire = {
		id = "rbxassetid://87054967937419",
		volume = 0.6,
		pitchJitter = 0.06,
		minGap = 0.03,
	},
	--[[ The Warden's three blows (`Config/Weapons.RubyGreatsword.comboSounds`):
	     CC0 recordings from Freesound picked by the owner (2026-10-23;
	     rounds 10 C, 10 D and 11 D, `assets/audio/freesound.py`), already
	     10% quicker in the files themselves, so they play at speed 1. ]]
	sword_swing = {
		id = "rbxassetid://87235506154920",
		volume = 0.7,
		pitchJitter = 0.04,
		minGap = 0.05,
	},
	sword_swing_2 = {
		id = "rbxassetid://83559699463378",
		volume = 0.7,
		pitchJitter = 0.04,
		minGap = 0.05,
	},
	sword_slam = {
		id = "rbxassetid://79504183116158",
		volume = 0.8,
		pitchJitter = 0.02,
		minGap = 0.05,
	},
	--[[ The Arcanist's every bolt (`Config/Weapons.ArcaneStaff.fireSound`). ]]
	staff_cast = {
		id = "rbxassetid://94842415130560",
		volume = 0.6,
		pitchJitter = 0.04,
		minGap = 0.03,
	},
	enemy_hit = {
		id = "rbxassetid://119984023706957",
		volume = 0.6,
		pitchJitter = 0.08,
		minGap = 0.04,
	},
	enemy_death = {
		id = "rbxassetid://79343537900984",
		volume = 0.7,
		pitchJitter = 0.06,
		minGap = 0.05,
	},
	player_hurt = {
		id = "rbxassetid://108553026094545",
		volume = 0.8,
		pitchJitter = 0.03,
		minGap = 0.1,
	},
	dash = { id = "rbxassetid://71620593977891", volume = 0.6, pitchJitter = 0.05, minGap = 0.1 },
	--[[ A cleared room draws every crystal in at once: one ping per gap. ]]
	xp_pickup = {
		id = "rbxassetid://74242296300145",
		volume = 0.5,
		pitchJitter = 0.1,
		minGap = 0.05,
	},
	heart_pickup = {
		id = "rbxassetid://113510944899483",
		volume = 0.7,
		pitchJitter = 0,
		minGap = 0.1,
	},
	level_up = { id = "rbxassetid://118857075181229", volume = 0.7, pitchJitter = 0, minGap = 0.2 },
	card_pick = { id = "rbxassetid://96268156590681", volume = 0.7, pitchJitter = 0, minGap = 0.1 },
	gate_open = { id = "rbxassetid://120317924961388", volume = 0.7, pitchJitter = 0, minGap = 0.5 },
}

return table.freeze(Sounds)
