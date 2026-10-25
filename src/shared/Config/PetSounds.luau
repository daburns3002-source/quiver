--!strict
--[[
	The sound each pet's Attack makes (`Config/Sounds` names), and how many
	seconds into its Attack clip each plays, matched to its pieces in
	`Config/PetAttacks`. Played by `Fx/PetAttackFx`.

	The Slime Prince and Ember Wilf have two halves to their attack, so a
	sound each: the summon then the crown shockwave, the fire bolts then the
	howl. The Mossback Snail has no piece (its shell is the guard) but still
	sounds.
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
}

return table.freeze(PetSounds)
