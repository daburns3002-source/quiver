--!strict
--[[
	Every pet a player can own (owner, 2026-10-26: real hatching, two pets
	equipped), keyed by its `Config/PetModels` name: its name on screen, its
	rarity (docs/PETS-FOREST.md), and the egg it hatches from (`Config/Eggs`).

	A pet is only hatchable once its model is in the game: `Util/EggRules`
	leaves out any pet with no `Config/PetModels` entry, so an egg whose pets
	are not imported yet shows as a silhouette.
]]

export type Pet = {
	name: string,
	rarity: string,
	egg: string,
}

local Pets: { [string]: Pet } = {
	Mosslet = { name = "MOSSLET", rarity = "Common", egg = "MossyEgg" },
	Babacorn = { name = "BABACORN", rarity = "Common", egg = "MossyEgg" },
	FernFrog = { name = "FERN FROG", rarity = "Common", egg = "MossyEgg" },
	ToadstoolTot = { name = "TOADSTOOL TOT", rarity = "Uncommon", egg = "MossyEgg" },
	MossbackSnail = { name = "MOSSBACK SNAIL", rarity = "Uncommon", egg = "MossyEgg" },
	FireflyBun = { name = "FIREFLY BUN", rarity = "Rare", egg = "MossyEgg" },
	Stumpy = { name = "STUMPY", rarity = "Rare", egg = "MossyEgg" },
	GladeFox = { name = "GLADE FOX", rarity = "Epic", egg = "MossyEgg" },
	Hootmoss = { name = "HOOTMOSS", rarity = "Epic", egg = "MossyEgg" },
	SlimePrince = { name = "SLIME PRINCE", rarity = "Legendary", egg = "MossyEgg" },
	EmberWilfPet = { name = "EMBER WILF", rarity = "Legendary", egg = "MossyEgg" },
	Glimmerhorn = { name = "GLIMMERHORN", rarity = "Mythic", egg = "MossyEgg" },
	-- Thornwood (docs/PETS-THORNWOOD.md): hatchable once imported
	BarkHoglet = { name = "BARK HOGLET", rarity = "Common", egg = "ThornwoodEgg" },
	Burrball = { name = "BURRBALL", rarity = "Common", egg = "ThornwoodEgg" },
	Budbulb = { name = "BUDBULB", rarity = "Common", egg = "ThornwoodEgg" },
	BerryMouse = { name = "BERRY MOUSE", rarity = "Uncommon", egg = "ThornwoodEgg" },
	ThistleMole = { name = "THISTLE MOLE", rarity = "Uncommon", egg = "ThornwoodEgg" },
	BriarBeetle = { name = "BRIAR BEETLE", rarity = "Rare", egg = "ThornwoodEgg" },
	BerryBat = { name = "BERRY BAT", rarity = "Rare", egg = "ThornwoodEgg" },
	BrambleBear = { name = "BRAMBLE BEAR", rarity = "Epic", egg = "ThornwoodEgg" },
	BriarLynx = { name = "BRIAR LYNX", rarity = "Epic", egg = "ThornwoodEgg" },
	BrambleWilf = { name = "BRAMBLE WILF", rarity = "Legendary", egg = "ThornwoodEgg" },
	ThornPrincess = { name = "THORN PRINCESS", rarity = "Legendary", egg = "ThornwoodEgg" },
	Thornwake = { name = "THORNWAKE", rarity = "Mythic", egg = "ThornwoodEgg" },
}

return table.freeze(Pets)
