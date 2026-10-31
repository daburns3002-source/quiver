--!strict
--[[
	Every pet a player can own (owner, 2026-10-26: real hatching, two pets
	equipped), keyed by its `Config/PetModels` name: its name on screen, its
	rarity (docs/PETS-FOREST.md), and the egg it hatches from (`Config/Eggs`),
	or no egg at all for one benched to keep an egg down to eight.

	A pet is only hatchable once its model is in the game: `Util/EggRules`
	leaves out any pet with no `Config/PetModels` entry, so an egg whose pets
	are not imported yet shows as a silhouette.
]]

export type Pet = {
	name: string,
	rarity: string,
	--[[ The egg it comes out of, or nil for a pet no egg holds: still
	     modelled and animated, simply not hatchable. ]]
	egg: string?,
}

local Pets: { [string]: Pet } = {
	Mosslet = { name = "MOSSLET", rarity = "Common", egg = "MossyEgg" },
	Babacorn = { name = "BABACORN", rarity = "Common", egg = "MossyEgg" },
	--[[ Eight pets to an egg, not twelve (owner, 2026-10-31: "the eggs from
	     now on will only have 8 pets each, 12 is too much"): a dozen made
	     each one's share too thin to feel and the hatchery's odds a wall of
	     numbers. The four benched from each egg are the second of its
	     doubled-up Common, Uncommon, Rare and Epic; both Legendaries and the
	     Mythic stay, so the top of the ladder is untouched.

	     They are benched, not deleted -- every one is still modelled and
	     animated, and comes back by putting its `egg` field back. ]]
	FernFrog = { name = "FERN FROG", rarity = "Common" },
	ToadstoolTot = { name = "TOADSTOOL TOT", rarity = "Uncommon" },
	MossbackSnail = { name = "MOSSBACK SNAIL", rarity = "Uncommon", egg = "MossyEgg" },
	FireflyBun = { name = "FIREFLY BUN", rarity = "Rare" },
	Stumpy = { name = "STUMPY", rarity = "Rare", egg = "MossyEgg" },
	GladeFox = { name = "GLADE FOX", rarity = "Epic", egg = "MossyEgg" },
	Hootmoss = { name = "HOOTMOSS", rarity = "Epic" },
	SlimePrince = { name = "SLIME PRINCE", rarity = "Legendary", egg = "MossyEgg" },
	EmberWilfPet = { name = "EMBER WILF", rarity = "Legendary", egg = "MossyEgg" },
	Glimmerhorn = { name = "GLIMMERHORN", rarity = "Mythic", egg = "MossyEgg" },
	-- Thornwood (docs/PETS-THORNWOOD.md): hatchable once imported
	BarkHoglet = { name = "BARK HOGLET", rarity = "Common", egg = "ThornwoodEgg" },
	Burrball = { name = "BURRBALL", rarity = "Common", egg = "ThornwoodEgg" },
	Budbulb = { name = "BUDBULB", rarity = "Common" },
	BerryMouse = { name = "BERRY MOUSE", rarity = "Uncommon", egg = "ThornwoodEgg" },
	ThistleMole = { name = "THISTLE MOLE", rarity = "Uncommon" },
	BriarBeetle = { name = "BRIAR BEETLE", rarity = "Rare", egg = "ThornwoodEgg" },
	BerryBat = { name = "BERRY BAT", rarity = "Rare" },
	BrambleBear = { name = "BRAMBLE BEAR", rarity = "Epic", egg = "ThornwoodEgg" },
	BriarLynx = { name = "BRIAR LYNX", rarity = "Epic" },
	BrambleWilf = { name = "BRAMBLE WILF", rarity = "Legendary", egg = "ThornwoodEgg" },
	ThornPrincess = { name = "THORN PRINCESS", rarity = "Legendary", egg = "ThornwoodEgg" },
	Thornwake = { name = "THORNWAKE", rarity = "Mythic", egg = "ThornwoodEgg" },
}

return table.freeze(Pets)
