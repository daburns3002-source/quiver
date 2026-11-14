--!strict
--[[
	Everything the game sells for Robux (owner, 2026-11-13: "Yes, build them").
	The prices are starting numbers, to tune after launch. The rules are
	`Util/StoreRules`; the server grants through `Server/Data/Purchases` (each
	receipt once, by `MarketplaceService.ProcessReceipt`) and checks passes in
	`Server/Data/Passes`; the STORE screen is `UI/RobuxStore`, opened by the +
	on the lobby's gem pill.

	**Developer products** can be bought again and again: the gem packs, the
	starter pack (once a player, offered once after the first 1-1 clear) and
	the revive (DEFEAT only). **Game passes** are permanent.

	**The revive is Robux only, never gems** (owner: "the revive should only be
	robux not diamonds and it should be 15"). The free revive is gone
	(`Balance.Revive.perStage` 0), so this is the only way back: once a run, on
	the DEFEAT screen, and the room the player fell in starts over with their
	build kept. In co-op it stands up only the buyer; the others sit that room
	out, as a teammate who bled out does, and are back for the next one.
	A revive bought when it can no longer be used (the run was restarted under
	the prompt) is kept in the save and spent on the next DEFEAT for free.

	**Never sold:** Mythics, boss items, Starfall, boss badges. No energy and no
	timers. A product gives only gems, coins, eggs or a revive
	(`tests/RobuxStore.spec` holds that).

	`id` is the Creator Dashboard's number (universe 10772468005, "Archer Legends
	[TEST]", created 2026-11-14 with managed pricing off so these prices hold);
	a product or pass at 0 is shown but cannot be bought. What to create there:
	`docs/ROBUX-STORE.md`.
]]

export type Egg = { key: string, count: number }

export type Product = {
	--[[ The grant's name, saved nowhere: receipts are matched by `id`. ]]
	key: string,
	id: number,
	name: string,
	robux: number,
	description: string,
	gems: number?,
	coins: number?,
	eggs: { Egg }?,
	--[[ Once a player (the starter pack). ]]
	once: boolean?,
	--[[ The DEFEAT screen's revive: never on the STORE's shelves. ]]
	revive: boolean?,
	--[[ What the STORE draws on its tile: "gem", "starter" or "revive". ]]
	art: string,
	--[[ Its own 2D icon (Codex), "" until uploaded; a gem pack is always the
	     one diamond (CLAUDE.md rule 15). ]]
	icon: string?,
	--[[ A word over the tile, for the packs worth the most. ]]
	flag: string?,
}

export type Pass = {
	key: string,
	id: number,
	name: string,
	robux: number,
	description: string,
	--[[ The 2D icon (Codex, `assets/concepts/blocky/ui/robux/`, cut by
	     `assets/ui/robux/cutout.py`; owner-approved 2026-11-13). ]]
	icon: string,
	--[[ What owning it does, as numbers the rules read. ]]
	coinBonus: number?,
	petSlots: number?,
	dailyGems: number?,
	nameTag: boolean?,
}

local products: { Product } = {
	{
		key = "Gems120",
		id = 3731091948,
		name = "Handful of Gems",
		robux = 49,
		description = "120 gems.",
		gems = 120,
		art = "gem",
	},
	{
		key = "Gems325",
		id = 3731092230,
		name = "Pouch of Gems",
		robux = 99,
		description = "325 gems.",
		gems = 325,
		art = "gem",
	},
	{
		key = "Gems750",
		id = 3731092299,
		name = "Bag of Gems",
		robux = 199,
		description = "750 gems.",
		gems = 750,
		art = "gem",
		flag = "POPULAR",
	},
	{
		key = "Gems2300",
		id = 3731092363,
		name = "Chest of Gems",
		robux = 499,
		description = "2,300 gems.",
		gems = 2300,
		art = "gem",
	},
	{
		key = "Gems5500",
		id = 3731092429,
		name = "Vault of Gems",
		robux = 999,
		description = "5,500 gems.",
		gems = 5500,
		art = "gem",
		flag = "BEST VALUE",
	},
	{
		key = "StarterPack",
		id = 3731092480,
		name = "Starter Pack",
		robux = 99,
		description = "500 gems, 3 Mossy Eggs and 2,000 coins. Once per player.",
		gems = 500,
		coins = 2000,
		eggs = { { key = "MossyEgg", count = 3 } },
		once = true,
		art = "starter",
		icon = "rbxassetid://127186255327342",
	},
	{
		key = "Revive",
		id = 3731092534,
		name = "Revive",
		robux = 15,
		description = "Back into the room you fell in, with your build. Once per run.",
		revive = true,
		art = "revive",
		icon = "rbxassetid://79041273355190",
	},
}

local passes: { Pass } = {
	{
		key = "DoubleCoins",
		id = 2089910820,
		name = "2x Coins",
		robux = 199,
		description = "Double the coins from every kill and every clear.",
		icon = "rbxassetid://71089485757551",
		coinBonus = 1,
	},
	{
		key = "PetSlot",
		id = 2089742794,
		name = "Extra Pet Slot",
		robux = 249,
		description = "A third pet slot: take three pets into every run.",
		icon = "rbxassetid://86275051898179",
		petSlots = 1,
	},
	{
		key = "VIP",
		id = 2089826773,
		name = "VIP",
		robux = 399,
		description = "A gold name tag, 10% more coins and 25 gems every day.",
		icon = "rbxassetid://81851812963940",
		coinBonus = 0.1,
		dailyGems = 25,
		nameTag = true,
	},
}

return table.freeze({
	products = table.freeze(products),
	passes = table.freeze(passes),
	--[[ Pet slots without the Extra Pet Slot pass (`Config/Eggs.slots` has
	     room for the pass's one more). ]]
	petSlots = 2,
	--[[ Seconds the run holds TRY AGAIN for a revive's prompt to be answered
	     (co-op: a teammate's press must not restart the run under it). ]]
	reviveHold = 30,
	--[[ The receipts a save keeps, newest last: a retry of anything older is
	     long past (Roblox retries a receipt until it is granted). ]]
	receiptsKept = 100,
	--[[ The Player attribute a pass's ownership is shown on, for the screens
	     (`"Pass" .. key`); the server reads its own table, never this. ]]
	passAttribute = "Pass",
	--[[ The VIP name tag's gold. ]]
	vipGold = Color3.fromRGB(255, 205, 64),
})
