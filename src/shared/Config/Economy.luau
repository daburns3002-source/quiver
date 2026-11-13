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

--[[ **A later area pays more a minute** (owner, 2026-11-13, approving
     balance review item 2). Played in Studio, every area paid about 200
     coins a minute while its egg and crate cost double the last area's, so
     a Bogheart Egg was 20 minutes of Bogheart. Kill coins rose to aim at
     about 200 / 300 / 520 / 800 a minute (measured kills a minute: 13, 12
     and 10 in the three later areas), so each area's egg is about two to
     five minutes of its own play, and old eggs come quicker with new coins
     (CLAUDE.md rule 8). Was: kills 8 / 11 / 14, clears 400 / 600 / 800. ]]
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
			killCoins = 18,
			clearCoins = 500,
			bossItem = "BroodSilk",
			firstBossGems = 80,
			bossGems = 15,
			firstClearEgg = "ThornwoodEgg",
		},
		--[[ Areas 3 and 4 (2026-11-07), so their kills, clears and bosses
		     pay. A step up each, on Thornwood's curve. Their boss items are
		     drawn since their crates were stocked (2026-11-13,
		     `ShopAssets.items`); the names are still the placeholders the
		     owner has not changed. ]]
		DrownedVillage = {
			killCoins = 30,
			clearCoins = 750,
			bossItem = "TollBronze",
			firstBossGems = 110,
			bossGems = 20,
		},
		BogheartCaverns = {
			killCoins = 70,
			clearCoins = 1500,
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
