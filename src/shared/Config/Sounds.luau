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
	--[[ The Ranger's every arrow (`Config/Weapons.TwigBow.fireSound`). ]]
	arrow_fire = {
		id = "rbxassetid://87054967937419",
		volume = 0.6,
		pitchJitter = 0.06,
		minGap = 0.03,
	},
	--[[ The Warden's three blows (`Config/Weapons.TimberBlade.comboSounds`):
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
	--[[ The Arcanist's every bolt (`Config/Weapons.BranchStaff.fireSound`). ]]
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

	--[[ The card screen (`UI/Cards/DraftScreen`), Roblox's own free UI
	     sounds the owner picked on the Card Screen Sounds page
	     (2026-10-24): a card hovered or focused, a card taken up, the hand
	     redealt, and Choose! pressed. ]]
	card_hover = {
		id = "rbxassetid://10066931761",
		volume = 0.35,
		pitchJitter = 0.03,
		minGap = 0.05,
	},
	card_click = { id = "rbxassetid://10128760939", volume = 0.6, pitchJitter = 0, minGap = 0.05 },
	card_reroll = { id = "rbxassetid://10128766965", volume = 0.6, pitchJitter = 0, minGap = 0.2 },
	card_choose = { id = "rbxassetid://10066947742", volume = 0.7, pitchJitter = 0, minGap = 0.2 },
	--[[ The card screen's big moments, auditioned as round 15
	     (assets/audio/reveal_synth.py): a Mythic's reveal, one file timed to
	     its shake, flip, flash and title, and a hand with a Legendary in it
	     being dealt. Uploaded 2026-10-24. ]]
	card_mythic = { id = "rbxassetid://121583656262732", volume = 0.8, pitchJitter = 0, minGap = 1 },
	card_legendary = {
		id = "rbxassetid://98255881300623",
		volume = 0.7,
		pitchJitter = 0,
		minGap = 0.5,
	},
	--[[ The upgrade effects' sounds (owner, 2026-10-24), auditioned in rounds
	     12–14 (assets/audio/effect_sounds.py, effect_synth.py) and uploaded
	     the same day. Played by `Fx/Upgrades/*` where each effect fires; the frequent ones are spaced by `minGap`. ]]
	fx_blaze = {
		id = "rbxassetid://119600535751276",
		volume = 0.5,
		pitchJitter = 0.08,
		minGap = 0.25,
	},
	-- quieter and lower than the take (owner, 2026-10-24: "make the heal
	-- a quieter and lower pitch")
	fx_heal = {
		id = "rbxassetid://81111733501863",
		volume = 0.45,
		speed = 0.85,
		pitchJitter = 0,
		minGap = 0.2,
	},
	fx_overdraw = {
		id = "rbxassetid://107624021541458",
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	fx_blast_arrows = {
		id = "rbxassetid://112654308146555",
		volume = 0.5,
		pitchJitter = 0.1,
		minGap = 0.12,
	},
	fx_soul_chain = {
		id = "rbxassetid://110377398425919",
		volume = 0.5,
		pitchJitter = 0.08,
		minGap = 0.2,
	},
	fx_heavy_blade = {
		id = "rbxassetid://104659872920100",
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	fx_bloodletting = {
		id = "rbxassetid://108155913281096",
		volume = 0.4,
		pitchJitter = 0.1,
		minGap = 0.25,
	},
	fx_earthbreaker = {
		id = "rbxassetid://94234601764209",
		volume = 0.8,
		pitchJitter = 0,
		minGap = 0.5,
	},
	fx_chain_lightning = {
		id = "rbxassetid://126506552291541",
		volume = 0.5,
		pitchJitter = 0.12,
		minGap = 0.1,
	},
	fx_meteor = {
		id = "rbxassetid://70958519805781",
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	--[[ Each pet's attack (`Config/PetSounds`), from `assets/audio/pet_synth.py`,
	     picked by the owner in round 17 (2026-10-24; two each for the Slime
	     Prince and Ember Wilf, one per half of their attack). Files are in
	     `assets/audio/final/`, uploaded 2026-10-24; the Mossback Snail's
	     is not in the inventory yet, so it is silent. ]]
	pet_mosslet = {
		id = "rbxassetid://83032506635339",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_babacorn = {
		id = "rbxassetid://97271291476186",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_fern_frog = {
		id = "rbxassetid://127120888285484",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_toadstool_tot = {
		id = "rbxassetid://123748512490271",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_mossback_snail = {
		id = "",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_firefly_bun = {
		id = "rbxassetid://102081050805219",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_stumpy = {
		id = "rbxassetid://80852567296311",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_glade_fox = {
		id = "rbxassetid://102425189669283",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_hootmoss = {
		id = "rbxassetid://125040369200406",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_slime_prince_court = {
		id = "rbxassetid://123150969598499",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_slime_prince_crown = {
		id = "rbxassetid://92028953792865",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_ember_wilf_bolt = {
		id = "rbxassetid://109971968071899",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_ember_wilf_howl = {
		id = "rbxassetid://119539070818650",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_glimmerhorn = {
		id = "rbxassetid://112402396655765",
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
}

return table.freeze(Sounds)
