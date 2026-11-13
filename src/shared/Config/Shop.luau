--!strict
--[[
	The weapon crates and the weapon store (owner, 2026-10-25), at the
	lobby's Blacksmith (`UI/ShopScreen`, `Server/Data/Shop`).

	- **Crates**, one per area, for coins ("start at 500 for mossy glade",
	  then 1,000, 2,000, 4,000, 10,000, 20,000): each opens one of that
	  area's weapons, rolled on the server by rarity ("uncommon, rare, epic,
	  and a small mythic chance"). A weapon already owned is one more C
	  copy to merge (`Util/MergeRules`, owner 2026-10-28). An area with no weapons yet shows its
	  crate as a black silhouette.
	- **The store** sells an area's weapons for gems, by rarity; its
	  Legendaries ("the legendary weapon will cost coins and a certain item
	  that will only drop from the boss from that area") for coins and
	  `legendaryItems` of the area's boss item (`Config/Economy`). Mythics
	  only come out of crates.

	Weapons belong to areas by `Config/WeaponStats.area`.
]]

export type Chest = { class: string, name: string, tab: string }

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

	     **The Drowned Village and Bogheart Caverns are stocked since
	     2026-11-13** (owner, approving balance review item 5: after the
	     glade there was nothing to buy). Their boss items are drawn
	     (Codex, `assets/concepts/blocky/ui/shop/items34_raw.png`), and
	     each crate waits at launch on what its area's portal waits on
	     (`atLaunch`), so gear a quarter or a half stronger than the
	     glade's (`WeaponStats.areaScale`) is not sold to a glade-only
	     player.

	     `Util/ShopRules.catalog` is the one gate, so the store, the
	     crates and the gear screen all agree about what exists. ]]
	stocked: boolean?,
	--[[ The area whose boss must be beaten before this crate opens, and
	     its area's store with it, once the game is locked for launch
	     (`Config/Launch.locks`, read through `Util/LaunchLocks`): the boss
	     its area's portal waits on. Not read while the switch is off. ]]
	atLaunch: string?,
}

local Shop = {
	--[[ Areas in order: area 1 is the Mossy Glade (`WeaponStats.area`). ]]
	crates = {
		{ area = "MossyGlade", name = "MOSSY GLADE", price = 500, stocked = true },
		{ area = "Thornwood", name = "THORNWOOD", price = 1000 },
		{
			area = "DrownedVillage",
			name = "DROWNED VILLAGE",
			price = 2000,
			stocked = true,
			atLaunch = "Thornwood",
		},
		{
			area = "BogheartCaverns",
			name = "BOGHEART CAVERNS",
			price = 4000,
			stocked = true,
			atLaunch = "DrownedVillage",
		},
		{ area = "WindsweptCliffs", name = "WINDSWEPT CLIFFS", price = 10000 },
		{ area = "FrostpeakPass", name = "FROSTPEAK PASS", price = 20000 },
	} :: { Crate },

	counts = { 1, 3 },

	--[[ An area's crate is three chests, one a class (owner, 2026-11-01:
	     "It should be 3 separate chests"), as Codex drew them: his chest
	     is titled BOW CHEST and switched by Bows / Wands / Swords along
	     its top. `class` is the class that holds the weapons
	     (`Config/Sandbox`), `name` goes in the title and `tab` on the
	     button. Each costs its area's price, whichever is chosen. ]]
	chests = {
		{ class = "Ranger", name = "BOW", tab = "BOWS" },
		{ class = "Arcanist", name = "WAND", tab = "WANDS" },
		{ class = "Warden", name = "SWORD", tab = "SWORDS" },
	} :: { Chest },

	--[[ A chest's odds, by rarity (weights, not percentages). A chest
	     holds one class, so one weapon of each rarity, and Mythic 1 keeps
	     a Mythic at about 1% an open (owner, 2026-10-28: "make the odds of
	     pulling a mythic 1%") now that choosing a class no longer means
	     choosing between three Mythics. ]]
	crateOdds = {
		Uncommon = 58,
		Rare = 28,
		Epic = 11,
		Mythic = 1,
	} :: { [string]: number },

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
