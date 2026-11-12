--!strict
--[[
	What runs pay out, and the boss items (owner, 2026-10-25). Coins are
	spent on weapon crates and, with boss items, on Legendaries; gems on
	the store's other weapons (`Config/Shop`).

	Paid by the server only (`Data/Wallet`): coins for every kill, a bonus
	for clearing an area, and when an area's boss is beaten, one of its
	item ("the boss drop is guaranteed every time") and gems, more the
	first time. Keyed by a stage's `area` (`Balance.Stages`).
]]

export type Area = {
	--[[ Coins for each kill. ]]
	killCoins: number,
	--[[ Coins for finishing the area (its Victory). ]]
	clearCoins: number,
	--[[ The boss's item, one every time it is beaten. ]]
	bossItem: string,
	--[[ Gems for beating the boss: the first time, and every time after. ]]
	firstBossGems: number,
	bossGems: number,
	--[[ The egg (`Config/Eggs` key) the first clear of each of the area's
	     levels gives free, hatched on Victory (review item 5, owner
	     2026-11-11). Nil for an area with no egg yet. ]]
	firstClearEgg: string?,
}

export type Item = {
	name: string,
	--[[ Who drops it. ]]
	boss: string,
	area: string,
}

local Economy = {
	areas = {
		MossyGlade = {
			killCoins = 5,
			clearCoins = 250,
			bossItem = "RoyalJelly",
			firstBossGems = 50,
			bossGems = 10,
			firstClearEgg = "MossyEgg",
		},
		Thornwood = {
			killCoins = 8,
			clearCoins = 400,
			bossItem = "BroodSilk",
			firstBossGems = 80,
			bossGems = 15,
			firstClearEgg = "ThornwoodEgg",
		},
		--[[ Areas 3 and 4 (2026-11-07), so their kills, clears and bosses
		     pay. A step up each, on Thornwood's curve. The two boss items'
		     names are placeholders until the owner names them, and they have
		     no icons yet: `ShopAssets.items` only has to carry one once the
		     area's crate is stocked (`tests/ConfigConsistency.spec`). ]]
		DrownedVillage = {
			killCoins = 11,
			clearCoins = 600,
			bossItem = "TollBronze",
			firstBossGems = 110,
			bossGems = 20,
		},
		BogheartCaverns = {
			killCoins = 14,
			clearCoins = 800,
			bossItem = "BogPearl",
			firstBossGems = 140,
			bossGems = 25,
			firstClearEgg = "BogheartEgg",
		},
	} :: { [string]: Area },

	items = {
		RoyalJelly = { name = "ROYAL JELLY", boss = "King Bloblin", area = "MossyGlade" },
		BroodSilk = { name = "BROOD SILK", boss = "The Broodmother", area = "Thornwood" },
		TollBronze = { name = "TOLL BRONZE", boss = "Old Tollcrab", area = "DrownedVillage" },
		BogPearl = { name = "BOG PEARL", boss = "Grandmother Gulp", area = "BogheartCaverns" },
	} :: { [string]: Item },
}

return table.freeze(Economy)
