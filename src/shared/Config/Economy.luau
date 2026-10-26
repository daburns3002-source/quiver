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
		},
		Thornwood = {
			killCoins = 8,
			clearCoins = 400,
			bossItem = "BroodSilk",
			firstBossGems = 80,
			bossGems = 15,
		},
	} :: { [string]: Area },

	items = {
		RoyalJelly = { name = "ROYAL JELLY", boss = "King Bloblin", area = "MossyGlade" },
		BroodSilk = { name = "BROOD SILK", boss = "The Broodmother", area = "Thornwood" },
	} :: { [string]: Item },
}

return table.freeze(Economy)
