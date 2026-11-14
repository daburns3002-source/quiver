--!strict
--[[
	The pet eggs (owner, 2026-10-26: "real hatching"), at the lobby's Egg
	Hatchery (`UI/EggScreen`, `Server/Data/Hatchery`): one per area, bought
	with coins (docs/PROGRESSION.md: "one egg tier per area"), each holding
	that area's twelve pets (`Config/Pets`). The server rolls every hatch
	(CLAUDE.md non-negotiable 2).

	PLACEHOLDER PRICES AND ODDS (2026-10-26) until the owner sets them: the
	Mossy Egg at the Mossy Glade crate's price, the odds giving each pet of a
	rarity the same share. With eight pets to an egg that is two Commons at
	26.75% each, the lone Uncommon 24%, the Rare 12%, the Epic 6%, each of the
	two Legendaries 1.75% and the Mythic 1% (owner, 2026-10-28: "make the odds
	of pulling a mythic 1%").

	An egg opens once its area does: `unlock` names the area whose boss must
	be beaten first (Thornwood after King Bloblin), nil for the first.
]]

export type Egg = {
	key: string,
	name: string,
	--[[ The `Config/Economy` area it belongs to, for its look. ]]
	area: string,
	price: number,
	unlock: string?,
	--[[ The area whose boss must be beaten before this egg can be bought
	     once the game is locked for launch (`Config/Launch.locks`, read
	     through `Util/LaunchLocks`). Not read while the switch is off. ]]
	atLaunch: string?,
}

local Eggs = {
	list = {
		-- 500 gold (owner, 2026-10-31: "a good amount" for the first egg)
		{ key = "MossyEgg", name = "MOSSY EGG", area = "MossyGlade", price = 500 },
		{
			key = "ThornwoodEgg",
			name = "THORNWOOD EGG",
			area = "Thornwood",
			price = 1000,
			-- open from the start for now (owner, 2026-10-27: "the mossy glade
			-- egg and thornwood egg should be unlocked for now"); at launch
			-- it waits on King Bloblin
			atLaunch = "MossyGlade",
		},
		--[[ Bogheart Caverns, area 4 (2026-11-06): its eight Tripo pets
		     imported. Priced off the area's crate (`Config/Shop`, 4000), a
		     placeholder like the others. Open from the start while the game
		     is in playtest, as Thornwood's is. At launch it waits on the
		     Drowned Village's boss. ]]
		{
			key = "BogheartEgg",
			name = "BOGHEART EGG",
			area = "BogheartCaverns",
			price = 4000,
			atLaunch = "DrownedVillage",
		},
	} :: { Egg },

	--[[ An egg's odds, by rarity (weights out of 100, shared evenly by the
	     pets of that rarity in it). ]]
	odds = {
		Common = 53.5,
		Uncommon = 24,
		Rare = 12,
		Epic = 6,
		Legendary = 3.5,
		Mythic = 1,
	} :: { [string]: number },

	--[[ How many eggs one press can hatch: HATCH 1 and HATCH 3. ]]
	counts = { 1, 3 },

	--[[ Pets a player can take into a run at once (the gear screen's PET 1,
	     PET 2 and, with the Extra Pet Slot pass, PET 3), and the Player
	     attributes the server sets for them; the third stays empty without
	     the pass (`Data/Hatchery.apply`, `Util/StoreRules.petSlots`). ]]
	slots = { "Pet", "Pet2", "Pet3" },
}

return table.freeze(Eggs)
