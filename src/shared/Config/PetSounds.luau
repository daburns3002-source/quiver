--!strict
--[[
	The sound each pet's Attack makes (`Config/Sounds` names), and how many
	seconds into its Attack clip each plays, matched to its pieces in
	`Config/PetAttacks`. Played by `Fx/PetAttackFx`.

	The Slime Prince and Ember Wilf have two halves to their attack, so a
	sound each: the summon then the crown shockwave, the fire bolts then the
	howl. The Mossback Snail has no piece (its shell is the guard) but still
	sounds.

	Thornwood's, the Drowned Village's and Bogheart's came in round 35
	(2026-11-26), each on its attack's first piece; the Bramble Wilf's bolt
	and howl and the Lanternfin's mote and its burst 1.5 s later are two
	sounds each, like the Ember Wilf's. The Slate Turtle, Buoy Puffer and
	Bog Beaver sound as they shelter, puff or plaster.
]]

export type Cue = { sound: string, at: number }

local PetSounds: { [string]: { Cue } } = {
	Mosslet = { { sound = "pet_mosslet", at = 0.4 } },
	Babacorn = { { sound = "pet_babacorn", at = 0.1 } },
	FernFrog = { { sound = "pet_fern_frog", at = 0.2 } },
	ToadstoolTot = { { sound = "pet_toadstool_tot", at = 0.4 } },
	MossbackSnail = { { sound = "pet_mossback_snail", at = 0.3 } },
	FireflyBun = { { sound = "pet_firefly_bun", at = 0.5 } },
	Stumpy = { { sound = "pet_stumpy", at = 0.45 } },
	GladeFox = { { sound = "pet_glade_fox", at = 0.3 } },
	Hootmoss = { { sound = "pet_hootmoss", at = 0.25 } },
	SlimePrince = {
		{ sound = "pet_slime_prince_court", at = 0.5 },
		{ sound = "pet_slime_prince_crown", at = 1.0 },
	},
	EmberWilfPet = {
		{ sound = "pet_ember_wilf_bolt", at = 0.55 },
		{ sound = "pet_ember_wilf_howl", at = 1.1 },
	},
	Glimmerhorn = { { sound = "pet_glimmerhorn", at = 0.7 } },
	-- Thornwood
	BarkHoglet = { { sound = "pet_bark_hoglet", at = 0.3 } },
	Burrball = { { sound = "pet_burrball", at = 0.1 } },
	Budbulb = { { sound = "pet_budbulb", at = 0.35 } },
	BerryMouse = { { sound = "pet_berry_mouse", at = 0.4 } },
	ThistleMole = { { sound = "pet_thistle_mole", at = 0.1 } },
	BriarBeetle = { { sound = "pet_briar_beetle", at = 0.4 } },
	BerryBat = { { sound = "pet_berry_bat", at = 0.3 } },
	BrambleBear = { { sound = "pet_bramble_bear", at = 0.3 } },
	BriarLynx = { { sound = "pet_briar_lynx", at = 0.25 } },
	BrambleWilf = {
		{ sound = "pet_bramble_wilf_bolt", at = 0.45 },
		{ sound = "pet_bramble_wilf_howl", at = 0.8 },
	},
	ThornPrincess = { { sound = "pet_thorn_princess", at = 0.4 } },
	Thornwake = { { sound = "pet_thornwake", at = 0.2 } },
	-- the Drowned Village
	SlateTurtle = { { sound = "pet_slate_turtle", at = 0.25 } },
	BuoyPuffer = { { sound = "pet_buoy_puffer", at = 0.3 } },
	Inkpot = { { sound = "pet_inkpot", at = 0.38 } },
	TideWilf = { { sound = "pet_tide_wilf", at = 0.42 } },
	AbyssJelly = { { sound = "pet_abyss_jelly", at = 0.14 } },
	-- Bogheart Caverns
	CaveCricket = { { sound = "pet_cave_cricket", at = 0.6 } },
	LichenGecko = { { sound = "pet_lichen_gecko", at = 0.3 } },
	BogBeaver = { { sound = "pet_bog_beaver", at = 0.35 } },
	Lanternfin = {
		{ sound = "pet_lanternfin_mote", at = 0.35 },
		{ sound = "pet_lanternfin_burst", at = 1.85 },
	},
	Olm = { { sound = "pet_olm", at = 0.4 } },
	GlowcapWilf = { { sound = "pet_glowcap_wilf", at = 0.5 } },
	Gulpling = { { sound = "pet_gulpling", at = 0.55 } },
	PrismLeviathan = { { sound = "pet_prism_leviathan", at = 0.45 } },
	-- the Windswept Cliffs: stand-ins until the area's own sounds
	WhistleMarmot = { { sound = "pet_berry_mouse", at = 0.35 } },
	CliffPuffin = { { sound = "pet_hootmoss", at = 0.4 } },
	WoollyAlpaca = { { sound = "pet_bog_beaver", at = 0.45 } },
	GaleGlider = { { sound = "fx_wind_gust", at = 0.3 } },
	FlagtailPanda = { { sound = "fx_whirlwind", at = 0.4 } },
	GaleWilf = { { sound = "pet_glowcap_wilf", at = 0.5 } },
	Rocling = { { sound = "fx_chain_lightning", at = 0.4 } },
	ZephyrWhale = { { sound = "fx_wind_gust", at = 0.45 } },
}

return table.freeze(PetSounds)
