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
	--[[ The area it belongs to (a `Balance.Stages` `area`), egg or no egg:
	     the Dex lays its books out a page an area (`Util/DexBook`). ]]
	area: string,
	--[[ The egg it comes out of, or nil for a pet no egg holds: still
	     modelled and animated, simply not hatchable. ]]
	egg: string?,
}

local Pets: { [string]: Pet } = {
	Mosslet = { name = "MOSSLET", rarity = "Common", area = "MossyGlade", egg = "MossyEgg" },
	Babacorn = { name = "BABACORN", rarity = "Common", area = "MossyGlade", egg = "MossyEgg" },
	--[[ Eight pets to an egg, not twelve (owner, 2026-10-31: "the eggs from
	     now on will only have 8 pets each, 12 is too much"): a dozen made
	     each one's share too thin to feel and the hatchery's odds a wall of
	     numbers. The four benched from each egg are the second of its
	     doubled-up Common, Uncommon, Rare and Epic; both Legendaries and the
	     Mythic stay, so the top of the ladder is untouched.

	     They are benched, not deleted -- every one is still modelled and
	     animated, and comes back by putting its `egg` field back. ]]
	FernFrog = { name = "FERN FROG", rarity = "Common", area = "MossyGlade" },
	ToadstoolTot = { name = "TOADSTOOL TOT", rarity = "Uncommon", area = "MossyGlade" },
	MossbackSnail = {
		name = "MOSSBACK SNAIL",
		rarity = "Uncommon",
		area = "MossyGlade",
		egg = "MossyEgg",
	},
	FireflyBun = { name = "FIREFLY BUN", rarity = "Rare", area = "MossyGlade" },
	Stumpy = { name = "STUMPY", rarity = "Rare", area = "MossyGlade", egg = "MossyEgg" },
	GladeFox = { name = "GLADE FOX", rarity = "Epic", area = "MossyGlade", egg = "MossyEgg" },
	Hootmoss = { name = "HOOTMOSS", rarity = "Epic", area = "MossyGlade" },
	SlimePrince = {
		name = "SLIME PRINCE",
		rarity = "Legendary",
		area = "MossyGlade",
		egg = "MossyEgg",
	},
	EmberWilfPet = {
		name = "EMBER WILF",
		rarity = "Legendary",
		area = "MossyGlade",
		egg = "MossyEgg",
	},
	Glimmerhorn = { name = "GLIMMERHORN", rarity = "Mythic", area = "MossyGlade", egg = "MossyEgg" },
	-- Thornwood (docs/PETS-THORNWOOD.md): hatchable once imported
	BarkHoglet = {
		name = "BARK HOGLET",
		rarity = "Common",
		area = "Thornwood",
		egg = "ThornwoodEgg",
	},
	Burrball = { name = "BURRBALL", rarity = "Common", area = "Thornwood" },
	Budbulb = { name = "BUDBULB", rarity = "Common", area = "Thornwood" },
	--[[ Thornwood's Uncommon is the guard, not the healer (owner,
	     2026-10-31): the Thistle Mole's Thorn Shell is in and the Berry
	     Mouse is benched, so each egg holds one guard and a player always
	     has that option. It costs both eggs their healer, since the
	     Toadstool Tot is benched too. ]]
	BerryMouse = { name = "BERRY MOUSE", rarity = "Uncommon", area = "Thornwood" },
	ThistleMole = {
		name = "THISTLE MOLE",
		rarity = "Uncommon",
		area = "Thornwood",
		egg = "ThornwoodEgg",
	},
	BriarBeetle = {
		name = "BRIAR BEETLE",
		rarity = "Rare",
		area = "Thornwood",
		egg = "ThornwoodEgg",
	},
	--[[ The Berry Bat is a Common now, not a Rare (owner, 2026-10-31: "i
	     like the berry bat design so take the burrball out", then "make the
	     berry bat a common"). Dropping a Common for a Rare would have left
	     the egg with one Common carrying the whole 53.5% Common weight, so
	     the Bat moved rarity instead and the slots stay 2/1/1/1/2/1. The
	     Burrball is benched in its place. ]]
	BerryBat = { name = "BERRY BAT", rarity = "Common", area = "Thornwood", egg = "ThornwoodEgg" },
	BrambleBear = {
		name = "BRAMBLE BEAR",
		rarity = "Epic",
		area = "Thornwood",
		egg = "ThornwoodEgg",
	},
	BriarLynx = { name = "BRIAR LYNX", rarity = "Epic", area = "Thornwood" },
	BrambleWilf = {
		name = "BRAMBLE WILF",
		rarity = "Legendary",
		area = "Thornwood",
		egg = "ThornwoodEgg",
	},
	ThornPrincess = {
		name = "THORN PRINCESS",
		rarity = "Legendary",
		area = "Thornwood",
		egg = "ThornwoodEgg",
	},
	Thornwake = { name = "THORNWAKE", rarity = "Mythic", area = "Thornwood", egg = "ThornwoodEgg" },
	--[[ Drowned Village (docs/PETS-DROWNED.md), the five the owner has
	     imported so far. No egg yet: `Config/Eggs` holds none for the area
	     and `tests/Eggs.spec` pins an egg at eight pets, so the Drowned
	     Village Egg waits on three more models -- two of the Commons (Dock
	     Otter, Reed Duck, Foam Pup) and the Toll Prince, the boss heir that
	     shares the Legendary slot with the Tide Wilf -- and on its own
	     hatch art in `Config/GearAssets.eggs`. Until then these five are
	     benched like any other petless pet: modelled, previewable and
	     ready to be rolled the day the egg opens.

	     They are single Tripo meshes rather than blocky Claude Design
	     builds, so none of them has clips, an attack or a combat spec yet;
	     `Combat/PetCombat` simply skips a pet it has no spec for. ]]
	SlateTurtle = { name = "SLATE TURTLE", rarity = "Uncommon", area = "DrownedVillage" },
	BuoyPuffer = { name = "BUOY PUFFER", rarity = "Rare", area = "DrownedVillage" },
	Inkpot = { name = "INKPOT", rarity = "Epic", area = "DrownedVillage" },
	TideWilf = { name = "TIDE WILF", rarity = "Legendary", area = "DrownedVillage" },
	AbyssJelly = { name = "ABYSS JELLY", rarity = "Mythic", area = "DrownedVillage" },
	--[[ Bogheart Caverns (docs/PETS-BOGHEART.md), all eight, modelled on
	     Tripo and imported 2026-11-06 (`Config/PetModels`), so the Bogheart
	     Egg holds the full eight. Their attacks and clips are in. ]]
	CaveCricket = {
		name = "CAVE CRICKET",
		rarity = "Common",
		area = "BogheartCaverns",
		egg = "BogheartEgg",
	},
	LichenGecko = {
		name = "LICHEN GECKO",
		rarity = "Common",
		area = "BogheartCaverns",
		egg = "BogheartEgg",
	},
	BogBeaver = {
		name = "BOG BEAVER",
		rarity = "Uncommon",
		area = "BogheartCaverns",
		egg = "BogheartEgg",
	},
	Lanternfin = {
		name = "LANTERNFIN",
		rarity = "Rare",
		area = "BogheartCaverns",
		egg = "BogheartEgg",
	},
	Olm = { name = "OLM", rarity = "Epic", area = "BogheartCaverns", egg = "BogheartEgg" },
	GlowcapWilf = {
		name = "GLOWCAP WILF",
		rarity = "Legendary",
		area = "BogheartCaverns",
		egg = "BogheartEgg",
	},
	Gulpling = {
		name = "GULPLING",
		rarity = "Legendary",
		area = "BogheartCaverns",
		egg = "BogheartEgg",
	},
	PrismLeviathan = {
		name = "PRISM LEVIATHAN",
		rarity = "Mythic",
		area = "BogheartCaverns",
		egg = "BogheartEgg",
	},
}

return table.freeze(Pets)
