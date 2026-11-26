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
	--[[ For a sound cut from a sprite (several sounds in one upload, made by
	     `assets/audio/sprite.py`): its start and length in seconds there. ]]
	region: { number }?,
}

--[[ The bosses' round 18 sprite (`assets/audio/final/boss_sprite_r18.mp3`):
     uploaded 2026-10-25 (Roblox shows its name as #s). ]]
--[[ The shops' round 22-25 picks in one upload
     (`assets/audio/final/shop_sprite_r25.mp3`): uploaded 2026-10-26. ]]
--[[ The class select screen's two sounds in one upload
     (`final/class_sprite_r27.mp3`, uploaded 2026-10-27). ]]
local CLASS_SPRITE = "rbxassetid://94430209523341"
local SHOP_SPRITE = "rbxassetid://89103453757006"

local BOSS_SPRITE = "rbxassetid://73447077207928"

--[[ The Warden's new cards' round 19 picks in one upload
     (`assets/audio/final/warden_sprite_r19.mp3`; owner, 2026-10-25: one
     file per batch, for Roblox's audio upload limits). Uploaded 2026-10-25. ]]
local WARDEN_SPRITE = "rbxassetid://123411253404004"

--[[ The class upgrades' fourteen sounds (`Fx/Upgrades/*BuildFx`, `ClassCardFx`),
     picked over audition rounds 28-32 and joined into one sprite
     (`assets/audio/final/class_cards_sprite_r32.mp3`, regions in its .json).
     Uploaded 2026-11-13. ]]
local CLASS_CARDS_SPRITE = "rbxassetid://117855777207537"

--[[ The Assassin's nine sounds (its three strikes, the Shadow Dash's cut and
     its cards' five), the owner's picks of audition round 33 (2026-11-17)
     joined into one sprite (`assets/audio/final/assassin_sprite_r33.mp3`,
     regions in its .json). Uploaded 2026-11-17. ]]
local ASSASSIN_SPRITE = "rbxassetid://113750353487297"
--[[ The themed daggers' eight sounds and Thornwood's two, the owner's picks
     of audition round 34 (2026-11-19) joined into one sprite
     (`assets/audio/final/dagger_sprite_r34.mp3`, regions in its .json;
     made by `assets/audio/daggers_synth.py`). Uploaded 2026-11-19. ]]
local DAGGER_SPRITE = "rbxassetid://110974097332957"

--[[ The Drowned Village's water footsteps (`final/water_step_sprite.mp3`):
     not uploaded yet, so "" and silent. ]]
local WATER_SPRITE = ""

--[[ Round 35's attack sounds for the pets and enemies that had none, the
     owner's picks joined into one sprite: not uploaded yet, so "" and
     silent. ]]
local ATTACK_SPRITE = ""

local Sounds: { [string]: Sound } = {
	--[[ Footsteps in the Drowned Village's shallow water (`Fx/WaterSteps`;
	     owner, 2026-11-05: "the footsteps in the shallow water need to be
	     emphasized"): three takes from `assets/audio/water_step_synth.py`,
	     one sprite (`final/water_step_sprite.mp3`, one upload), played in
	     turn at random. Silent until it is uploaded and `WATER_SPRITE` set. ]]
	water_step_1 = {
		id = WATER_SPRITE,
		volume = 0.55,
		pitchJitter = 0.1,
		minGap = 0.1,
		region = { 0, 0.48 },
	},
	water_step_2 = {
		id = WATER_SPRITE,
		volume = 0.55,
		pitchJitter = 0.1,
		minGap = 0.1,
		region = { 0.92, 0.48 },
	},
	water_step_3 = {
		id = WATER_SPRITE,
		volume = 0.55,
		pitchJitter = 0.1,
		minGap = 0.1,
		region = { 1.84, 0.48 },
	},
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
	--[[ The Assassin's three strikes (`Config/Weapons.SplinterDaggers.comboSounds`):
	     about two a second, so thin and quiet, a little steel on each; the
	     stab is two thrusts and a small thud. ]]
	dagger_slash = {
		id = ASSASSIN_SPRITE,
		region = { 0, 0.17 },
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.05,
	},
	dagger_slash_2 = {
		id = ASSASSIN_SPRITE,
		region = { 0.61, 0.17 },
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.05,
	},
	dagger_stab = {
		id = ASSASSIN_SPRITE,
		region = { 1.22, 0.21 },
		volume = 0.65,
		pitchJitter = 0.04,
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
	--[[ The shops' and the gear screen's big moments (rounds 22-25, owner's
	     picks 2026-10-26), timed to `Config/Reveal`, in one sprite
	     (`assets/audio/final/shop_sprite_r25.mp3`). ]]
	crate_open = {
		id = SHOP_SPRITE,
		volume = 0.8,
		pitchJitter = 0,
		minGap = 0.5,
		region = { 0, 3.81 },
	},
	egg_hatch = {
		id = SHOP_SPRITE,
		volume = 0.8,
		pitchJitter = 0,
		minGap = 0.5,
		region = { 4.25, 3.794 },
	},
	reveal_rare = {
		id = SHOP_SPRITE,
		volume = 0.7,
		pitchJitter = 0,
		minGap = 0.5,
		region = { 8.484, 2.871 },
	},
	equip_weapon = {
		id = SHOP_SPRITE,
		volume = 0.6,
		pitchJitter = 0.03,
		minGap = 0.1,
		region = { 11.795, 0.89 },
	},
	equip_pet = {
		id = SHOP_SPRITE,
		volume = 0.6,
		pitchJitter = 0.03,
		minGap = 0.1,
		region = { 13.125, 0.65 },
	},
	new_item = {
		id = SHOP_SPRITE,
		volume = 0.6,
		pitchJitter = 0,
		minGap = 0.2,
		region = { 14.215, 1.05 },
	},
	--[[ A purchase going through (`UI/PurchaseFx`; owner, 2026-11-14): no
	     new upload, the shops' new_item chime played a little faster and
	     higher so it reads as its own sound. ]]
	purchase = {
		id = SHOP_SPRITE,
		volume = 0.75,
		speed = 1.18,
		pitchJitter = 0.02,
		minGap = 0.25,
		region = { 14.215, 1.05 },
	},
	--[[ A Mythic pulled from a crate or egg, as it appears, in place of
	     reveal_rare (owner, 2026-10-26: "super over the top"; round 26).
	     `assets/audio/final/mythic_reveal_r26.mp3`, uploaded 2026-10-26. ]]
	--[[ The class select screen (owner, 2026-10-27: "there should be sounds
	     when selecting and choosing"): a hero panel clicked (round 27 B, a
	     blade shing and a bell) and CHOOSE (round 27 A, the heroic lock-in),
	     both in `CLASS_SPRITE` (`assets/audio/final/class_sprite_r27.mp3`). ]]
	class_select = {
		id = CLASS_SPRITE,
		volume = 0.6,
		pitchJitter = 0,
		minGap = 0.08,
		region = { 0, 0.579 },
	},
	class_choose = {
		id = CLASS_SPRITE,
		volume = 0.8,
		pitchJitter = 0,
		minGap = 1,
		region = { 1.019, 2.063 },
	},
	mythic_reveal = {
		id = "rbxassetid://109234973944698",
		volume = 0.85,
		pitchJitter = 0,
		minGap = 1,
	},
	--[[ The soft glitter looping under a pulled prize until its screen is
	     closed (owner, 2026-10-26: "at a much lower volume"); exactly its
	     four-second loop. ]]
	reveal_glitter = {
		id = SHOP_SPRITE,
		volume = 0.18,
		pitchJitter = 0,
		minGap = 0,
		region = { 15.705, 4.0 },
	},
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
	--[[ The Warden's new cards (2026-10-25): the owner's picks from round 19
	     (Whirlwind B, Shockwave C, Battle Cry B; `assets/audio/warden_card_synth.py`),
	     each a region of `WARDEN_SPRITE`. ]]
	fx_whirlwind = {
		id = WARDEN_SPRITE,
		region = { 0.0, 0.475 },
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	fx_shockwave = {
		id = WARDEN_SPRITE,
		region = { 0.915, 0.57 },
		volume = 0.8,
		pitchJitter = 0.03,
		minGap = 0.3,
	},
	fx_battle_cry = {
		id = WARDEN_SPRITE,
		region = { 1.925, 0.759 },
		volume = 0.6,
		pitchJitter = 0.08,
		minGap = 0.15,
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
	     `assets/audio/final/`, uploaded 2026-10-24. ]]
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
		id = "rbxassetid://110647736120385",
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
	--[[ Round 18 (owner's picks, 2026-10-25; `assets/audio/boss_synth.py`,
	     `assets/audio/final/`), played by `Fx/EnemySounds`: the bosses' moves
	     and Thornwood's enemies. The enemies' are uploaded one file each; the
	     bosses' 13 share one upload, `boss_sprite_r18.mp3` (`BOSS_SPRITE`),
	     each its own `region` of it. ]]
	boss_king_bounce_windup = {
		id = BOSS_SPRITE,
		region = { 0.0, 0.737 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_king_bounce_launch = {
		id = BOSS_SPRITE,
		region = { 1.177, 0.599 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_king_bounce_slam = {
		id = BOSS_SPRITE,
		region = { 2.216, 1.019 },
		volume = 0.9,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_king_lash = {
		id = BOSS_SPRITE,
		region = { 3.675, 0.86 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_king_grab = {
		id = BOSS_SPRITE,
		region = { 4.975, 0.718 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_king_chest_bump = {
		id = BOSS_SPRITE,
		region = { 6.133, 0.561 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_king_goo = {
		id = BOSS_SPRITE,
		region = { 7.134, 0.71 },
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_brood_web_windup = {
		id = BOSS_SPRITE,
		region = { 8.284, 1.21 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_brood_web_spin = {
		id = BOSS_SPRITE,
		region = { 9.934, 2.212 },
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_brood_web_break = {
		id = BOSS_SPRITE,
		region = { 12.586, 0.62 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_brood_web_shot = {
		id = BOSS_SPRITE,
		region = { 13.646, 0.618 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_brood_web_pull = {
		id = BOSS_SPRITE,
		region = { 14.704, 0.614 },
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	boss_brood_summon = {
		id = BOSS_SPRITE,
		region = { 15.759, 1.22 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.25,
	},
	enemy_boar_charge = {
		id = "rbxassetid://88842850634924",
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_boar_gore = {
		id = "rbxassetid://101142695837972",
		volume = 0.55,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_thistle_spit = {
		id = "rbxassetid://106207560426472",
		volume = 0.5,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_sow_attack = {
		id = "rbxassetid://98246095575745",
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_sow_drop = {
		id = "rbxassetid://107072575980213",
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_boarlet_bite = {
		id = "rbxassetid://96832416396999",
		volume = 0.45,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_lurker_dive = {
		id = "rbxassetid://83564847913669",
		volume = 0.55,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_lurker_emerge = {
		id = "rbxassetid://133444661789119",
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_lurker_spray = {
		id = "rbxassetid://91409492527437",
		volume = 0.5,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_thornling_bite = {
		id = "rbxassetid://91009780551750",
		volume = 0.45,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_thornling_hatch = {
		id = "rbxassetid://83251645017802",
		volume = 0.45,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	--[[ The class upgrades of 2026-10-27 (`Fx/Upgrades/*BuildFx`): picked by the
	     owner and joined into one sprite (`CLASS_CARDS_SPRITE`). ]]
	-- the phoenix's cry as it leaves the bow
	fx_phoenix = {
		id = CLASS_CARDS_SPRITE,
		region = { 9.114, 1.069 },
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.5,
	},
	-- the arrow going up, and the rain's patter
	fx_arrow_rain = {
		id = CLASS_CARDS_SPRITE,
		region = { 0.91, 1.078 },
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.5,
	},
	-- the hole opening and its hum
	fx_black_hole = {
		id = CLASS_CARDS_SPRITE,
		region = { 2.428, 1.313 },
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.6,
	},
	-- the implosion
	fx_black_hole_implode = {
		id = CLASS_CARDS_SPRITE,
		region = { 4.181, 0.859 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.4,
	},
	-- the crystal appearing
	fx_turret = {
		id = CLASS_CARDS_SPRITE,
		region = { 14.144, 0.871 },
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.5,
	},
	-- the giant sword's slam
	fx_titan_slam = {
		id = CLASS_CARDS_SPRITE,
		region = { 12.844, 0.86 },
		volume = 0.85,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	-- the charged blow
	fx_counter_strike = {
		id = CLASS_CARDS_SPRITE,
		region = { 6.898, 0.57 },
		volume = 0.8,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	--[[ The class cards of 2026-11-13 (`Fx/Upgrades/ClassCardFx`): picked by the
	     owner and joined into one sprite (`CLASS_CARDS_SPRITE`). ]]
	-- the sniper arrow leaving the bow
	fx_sniper = {
		id = CLASS_CARDS_SPRITE,
		region = { 11.513, 0.23 },
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	-- an arrow splitting at a kill
	fx_split_shot = {
		id = CLASS_CARDS_SPRITE,
		region = { 12.183, 0.221 },
		volume = 0.5,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	-- an enemy shot blown away
	fx_wind_gust = {
		id = CLASS_CARDS_SPRITE,
		region = { 15.455, 0.22 },
		volume = 0.5,
		pitchJitter = 0.05,
		minGap = 0.15,
	},
	-- a kill charging the staff
	fx_mana_surge = {
		id = CLASS_CARDS_SPRITE,
		region = { 7.908, 0.766 },
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	-- the shield taking a hit and shattering
	fx_arcane_shield = {
		id = CLASS_CARDS_SPRITE,
		region = { 0.0, 0.47 },
		volume = 0.75,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	-- the shield thrown
	fx_shield_throw = {
		id = CLASS_CARDS_SPRITE,
		region = { 10.623, 0.45 },
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	-- the sword thrown spinning
	fx_blade_storm = {
		id = CLASS_CARDS_SPRITE,
		region = { 5.48, 0.978 },
		volume = 0.75,
		pitchJitter = 0.05,
		minGap = 0.3,
	},
	--[[ The Assassin's cards (`Fx/Upgrades/AssassinFx`): silent hooks until
	     their sounds are picked and uploaded as one sprite with the daggers'
	     own (`docs/PIPELINES.md` section 7). ]]
	--[[ The Shadow Dash's cut through whatever it passed (`AssassinFx`). ]]
	fx_shadow_dash = {
		id = ASSASSIN_SPRITE,
		region = { 1.87, 0.28 },
		volume = 0.6,
		pitchJitter = 0.04,
		minGap = 0.2,
	},
	fx_backstab = {
		id = ASSASSIN_SPRITE,
		region = { 2.59, 0.164 },
		volume = 0.6,
		pitchJitter = 0.06,
		minGap = 0.15,
	},
	fx_poison_trail = {
		id = ASSASSIN_SPRITE,
		region = { 3.193, 0.56 },
		volume = 0.6,
		pitchJitter = 0.04,
		minGap = 0.3,
	},
	fx_fan_of_knives = {
		id = ASSASSIN_SPRITE,
		region = { 4.193, 0.22 },
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	fx_death_mark = {
		id = ASSASSIN_SPRITE,
		region = { 4.853, 0.86 },
		volume = 0.7,
		pitchJitter = 0.03,
		minGap = 0.3,
	},
	fx_thousand_cuts = {
		id = ASSASSIN_SPRITE,
		region = { 6.153, 0.78 },
		volume = 0.8,
		pitchJitter = 0.02,
		minGap = 0.5,
	},
	--[[ Thornwood's cards (2026-11-18), the owner's picks of round 34: a
	     woody crack with thorns flying out; a snort and a heavy shove. ]]
	fx_thorn_burst = {
		id = DAGGER_SPRITE,
		region = { 10.2, 0.28 },
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.15,
	},
	fx_boar_rush = {
		id = DAGGER_SPRITE,
		region = { 10.92, 0.49 },
		volume = 0.7,
		pitchJitter = 0.04,
		minGap = 0.2,
	},
	--[[ The themed daggers' own effects (2026-11-18, `Fx/Upgrades/DaggerFx`),
	     the owner's picks of round 34. Wishing Star: two soft pings, then a
	     magic "pom" as the star lands (0.35 s in). Spur Rowel: three bright
	     "ching"s. Splash Wave: a splash and droplets. Combo Counter: a tiny
	     two-note blip on every strike, and four 8-bit notes falling when a
	     hit empties it. Comet Crash: a hum swelling to a deep "thoom" as the
	     comet lands (1.5 s in); one at a time at most every half second, as
	     a room full of comets would drown everything else. Bell Chime: a
	     bright hand bell, "ding-ding". Lava Burst: a rumble, five blorps
	     along the line and a sizzle. ]]
	fx_wishing_star = {
		id = DAGGER_SPRITE,
		region = { 0, 1.06 },
		volume = 0.7,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	fx_spur_rowel = {
		id = DAGGER_SPRITE,
		region = { 1.5, 0.551 },
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	fx_splash_wave = {
		id = DAGGER_SPRITE,
		region = { 2.49, 0.5 },
		volume = 0.6,
		pitchJitter = 0.06,
		minGap = 0.2,
	},
	fx_combo_counter = {
		id = DAGGER_SPRITE,
		region = { 3.431, 0.136 },
		volume = 0.4,
		pitchJitter = 0.03,
		minGap = 0.08,
	},
	fx_combo_break = {
		id = DAGGER_SPRITE,
		region = { 4.006, 0.325 },
		volume = 0.6,
		pitchJitter = 0.03,
		minGap = 0.3,
	},
	fx_comet_crash = {
		id = DAGGER_SPRITE,
		region = { 4.771, 2.475 },
		volume = 0.7,
		pitchJitter = 0.03,
		minGap = 0.5,
	},
	fx_bell_chime = {
		id = DAGGER_SPRITE,
		region = { 7.687, 0.923 },
		volume = 0.7,
		pitchJitter = 0.03,
		minGap = 0.3,
	},
	fx_lava_burst = {
		id = DAGGER_SPRITE,
		region = { 9.05, 0.71 },
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	--[[ Round 35 (2026-11-26): an attack sound for every pet and enemy that
	     had none, `assets/audio/attack_synth.py`. Pets cue from
	     `Config/PetSounds`, enemies and the two new bosses from
	     `Config/EnemySounds`. ]]
	pet_bark_hoglet = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_burrball = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_budbulb = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_berry_mouse = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_thistle_mole = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_briar_beetle = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_berry_bat = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_bramble_bear = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_briar_lynx = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_bramble_wilf_bolt = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_bramble_wilf_howl = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_thorn_princess = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_thornwake = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_slate_turtle = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_buoy_puffer = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_inkpot = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_tide_wilf = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_abyss_jelly = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_cave_cricket = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_lichen_gecko = {
		id = ATTACK_SPRITE,
		volume = 0.45,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_bog_beaver = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_lanternfin_mote = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_lanternfin_burst = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_olm = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_glowcap_wilf = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_gulpling = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	pet_prism_leviathan = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.06,
		minGap = 0.1,
	},
	enemy_charger_bite = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_bulwark_bash = {
		id = ATTACK_SPRITE,
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.15,
	},
	enemy_spitter_spit = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	enemy_baby_slime_bite = {
		id = ATTACK_SPRITE,
		volume = 0.4,
		pitchJitter = 0.06,
		minGap = 0.15,
	},
	enemy_brood_slime_bite = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_burrower_clods = {
		id = ATTACK_SPRITE,
		volume = 0.55,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	enemy_lancer_lance = {
		id = ATTACK_SPRITE,
		volume = 0.55,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	enemy_glowcap_spores = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	enemy_spore_puff_bite = {
		id = ATTACK_SPRITE,
		volume = 0.5,
		pitchJitter = 0.05,
		minGap = 0.12,
	},
	enemy_shellback_bash = {
		id = ATTACK_SPRITE,
		volume = 0.6,
		pitchJitter = 0.05,
		minGap = 0.15,
	},
	enemy_fisherman_cast = {
		id = ATTACK_SPRITE,
		volume = 0.55,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	boss_toll_raise = {
		id = ATTACK_SPRITE,
		volume = 0.7,
		pitchJitter = 0.03,
		minGap = 0.3,
	},
	boss_toll_ring = {
		id = ATTACK_SPRITE,
		volume = 0.85,
		pitchJitter = 0.03,
		minGap = 0.4,
	},
	boss_toll_rap = {
		id = ATTACK_SPRITE,
		volume = 0.7,
		pitchJitter = 0.04,
		minGap = 0.2,
	},
	boss_toll_echo = {
		id = ATTACK_SPRITE,
		volume = 0.75,
		pitchJitter = 0.04,
		minGap = 0.2,
	},
	boss_toll_scuttle = {
		id = ATTACK_SPRITE,
		volume = 0.75,
		pitchJitter = 0.05,
		minGap = 0.2,
	},
	boss_gulp_spit = {
		id = ATTACK_SPRITE,
		volume = 0.8,
		pitchJitter = 0.04,
		minGap = 0.3,
	},
	boss_gulp_slide = {
		id = ATTACK_SPRITE,
		volume = 0.8,
		pitchJitter = 0.03,
		minGap = 0.5,
	},
	boss_gulp_inhale = {
		id = ATTACK_SPRITE,
		volume = 0.8,
		pitchJitter = 0.02,
		minGap = 1.0,
	},
}

return table.freeze(Sounds)
