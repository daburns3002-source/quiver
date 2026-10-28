--!strict
--[[
	The pet eggs (owner, 2026-10-26: "real hatching"), at the lobby's Egg
	Hatchery (`UI/EggScreen`, `Server/Data/Hatchery`): one per area, bought
	with coins (docs/PROGRESSION.md: "one egg tier per area"), each holding
	that area's twelve pets (`Config/Pets`). The server rolls every hatch
	(CLAUDE.md non-negotiable 2).

	PLACEHOLDER PRICES AND ODDS (2026-10-26) until the owner sets them: the
	Mossy Egg a little under the Mossy Glade crate, the odds giving each pet
	of a rarity the same share (three Commons at about 17.8% each, a Mythic 1%; owner, 2026-10-28: "make the odds of pulling a mythic 1%").

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
}

local Eggs = {
	list = {
		{ key = "MossyEgg", name = "MOSSY EGG", area = "MossyGlade", price = 400 },
		{
			key = "ThornwoodEgg",
			name = "THORNWOOD EGG",
			area = "Thornwood",
			price = 1000,
			-- open from the start for now (owner, 2026-10-27: "the mossy glade
			-- egg and thornwood egg should be unlocked for now"); its unlock
			-- once that ends: unlock = "MossyGlade"
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

	--[[ Pets a player can take into a run at once (the gear screen's PET 1
	     and PET 2), and the Player attributes the server sets for them. ]]
	slots = { "Pet", "Pet2" },
}

return table.freeze(Eggs)
