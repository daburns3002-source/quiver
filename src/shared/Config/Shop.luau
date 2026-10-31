--!strict
--[[
	The weapon crates and the weapon store (owner, 2026-10-25), at the
	lobby's Blacksmith (`UI/ShopScreen`, `Server/Data/Shop`).

	- **Crates**, one per area, for coins ("start at 500 for mossy glade",
	  then 1,000, 2,000, 4,000, 10,000, 20,000): each opens one of that
	  area's weapons, rolled on the server by rarity ("uncommon, rare, epic,
	  and a small mythic chance"). A weapon already owned pays back
	  `duplicateRefund` of the price. An area with no weapons yet shows its
	  crate as a black silhouette.
	- **The store** sells an area's weapons for gems, by rarity; its
	  Legendaries ("the legendary weapon will cost coins and a certain item
	  that will only drop from the boss from that area") for coins and
	  `legendaryItems` of the area's boss item (`Config/Economy`). Mythics
	  only come out of crates.

	Weapons belong to areas by `Config/WeaponStats.area`.
]]

export type Crate = {
	--[[ The area's `Config/Economy` key, and its name on screen. ]]
	area: string,
	name: string,
	price: number,
	--[[ Whether the area's weapons can be owned yet. An area is stocked
	     once its weapons have their 2D icons and the area has a
	     `Config/Economy` entry to price a Legendary against -- without
	     both, a crate would pay out a weapon the shop cannot draw and the
	     store cannot cost. Unstocked areas' weapons are still held and
	     fought with in the sandbox; they are simply not for sale.

	     `Util/ShopRules.catalog` is the one gate, so the store, the
	     crates and the gear screen all agree about what exists. ]]
	stocked: boolean?,
}

local Shop = {
	--[[ Areas in order: area 1 is the Mossy Glade (`WeaponStats.area`). ]]
	crates = {
		{ area = "MossyGlade", name = "MOSSY GLADE", price = 500, stocked = true },
		{ area = "Thornwood", name = "THORNWOOD", price = 1000 },
		{ area = "DrownedVillage", name = "DROWNED VILLAGE", price = 2000 },
		{ area = "BogheartCaverns", name = "BOGHEART CAVERNS", price = 4000 },
		{ area = "WindsweptCliffs", name = "WINDSWEPT CLIFFS", price = 10000 },
		{ area = "FrostpeakPass", name = "FROSTPEAK PASS", price = 20000 },
	} :: { Crate },

	counts = { 1, 3 },

	--[[ A crate's odds, by rarity (weights, not percentages). Mythic 3: a
	     crate's three Mythics (one per class) at 1% each (owner, 2026-10-28:
	     "make the odds of pulling a mythic 1%"). ]]
	crateOdds = {
		Uncommon = 58,
		Rare = 28,
		Epic = 11,
		Mythic = 3,
	} :: { [string]: number },

	--[[ Share of a crate's price paid back for a weapon already owned. ]]
	duplicateRefund = 0.4,

	--[[ The store's gem prices, by rarity, times the area's number. ]]
	gemPrices = {
		Uncommon = 58,
		Rare = 180,
		Epic = 450,
	} :: { [string]: number },

	--[[ A Legendary's price: coins (times the area's crate price over the
	     first's) and this many of the area's boss item. ]]
	legendaryCoins = 3000,
	legendaryItems = 3,
}

return table.freeze(Shop)
