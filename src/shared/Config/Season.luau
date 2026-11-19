--!strict
--[[
	The season pass (owner, 2026-11-18: "yes all of these create them"; the
	tier list approved the same day, "Yes, build it"). Rules in
	`Util/SeasonRules`, the server in `Server/Data/Season`, the SEASON tab
	on the REWARDS screen (`UI/SeasonTab`); `docs/SEASON.md`.

	A season is one calendar month by the server's clock (UTC), from 00:00
	on the 1st to 00:00 on the next 1st, keyed "YYYY-MM". A month with no
	entry in `seasons` has no season: the tab says when the next one
	starts. Each season takes its theme from a themed weapon set
	(`Config/Shop.sets`) and has a trail (`Config/Trails`, earned "Season")
	and a title (`titles`) that are given in that season only, never sold
	or given again.

	Season XP is the server's, from what really happens (`Data/Rewards.note`
	and the quests' claims): `xp` a thing. Every tier is `tierXp`. The
	same `tiers` serve every season; a tier's `trail` and `title` are that
	season's own.

	The free track is everyone's: coins, gems, eggs or crates every tier
	(its eggs and crates are the best open to the player, as the quests'
	are, `Data/QuestChest`). The premium track is bought once a season for
	Robux (`Config/RobuxStore` "SeasonPass", saved for that season only)
	and gives **fixed things only, never random ones**: gems, coins, the
	season's trail and its title (paid random items are restricted in some
	countries, `PolicyService.ArePaidRandomItemsRestricted`; nothing here
	needs that check).

	**At a season's end** every tier reached and not claimed is claimed for
	the player, both tracks if they bought premium (decided 2026-11-18,
	`SeasonRules.rollover`): nothing carries over, XP included, and nothing
	reached is lost.

	The arithmetic, for a player who does the three quests and wins four
	levels of about five rooms a day: 3 x 100 + 4 x (50 + 5 x 10) = 700 XP,
	so tier 30 (15,000 XP) in about three weeks of a month.

	Totals: free 90 gems, 11 eggs, 8 crates, 22,750 coins; premium 1,530
	gems, 28,000 coins, the trail and the title.
]]

export type Prize = {
	coins: number?,
	gems: number?,
	eggs: number?,
	crates: number?,
	--[[ The season's trail, and its title (premium only). ]]
	trail: boolean?,
	title: boolean?,
	--[[ The season's weapon for this track (`SeasonDef.weapons`), if it
	     has one: tier 30's. ]]
	weapon: boolean?,
}

export type Tier = { free: Prize, premium: Prize }

export type SeasonDef = {
	--[[ Shown as "SEASON 1". ]]
	number: number,
	name: string,
	--[[ The themed weapon set it takes its look from (`Config/Shop.sets`). ]]
	set: string,
	--[[ Its trail (`Config/Trails`, earn "Season") and title (`titles`). ]]
	trail: string,
	title: string,
	--[[ The earned weapon each track gives at tier 30 (`WeaponStats.earned`),
	     nil for none. ]]
	weapons: { free: string?, premium: string? }?,
	--[[ The tab's colours: its band, and the line under its words. ]]
	colour: Color3,
	accent: Color3,
}

export type Title = {
	--[[ The words over the name tag. ]]
	text: string,
	colour: Color3,
	stroke: Color3,
}

local function hex(code: string): Color3
	return Color3.fromHex(code)
end

local Season = {
	--[[ XP a tier, and XP for each thing the server sees happen: a
	     campaign room cleared, a level won, an Endless floor cleared, a
	     daily quest claimed. ]]
	tierXp = 500,
	xp = {
		rooms = 10,
		levels = 50,
		floors = 10,
		quests = 100,
	} :: { [string]: number },

	--[[ The developer product that opens the premium track
	     (`Config/RobuxStore`). ]]
	product = "SeasonPass",

	--[[ Seconds between the server's checks for a season that has ended
	     while people play. ]]
	checkEvery = 30,

	--[[ By month, "YYYY-MM" (UTC). ]]
	seasons = {
		["2026-12"] = {
			number = 1,
			name = "STARWISH",
			set = "Starwish",
			trail = "WishRibbon",
			title = "Wishkeeper",
			--[[ Owner, 2026-11-19: the Wishcutter Blade "should be the
			     legendary that goes in the free battle pass for tier 30",
			     and the Petalfall Blade, a Mythic, is premium's end. ]]
			weapons = { free = "WishcutterBlade", premium = "PetalfallBlade" },
			colour = hex("#FF9EC7"),
			accent = hex("#8FE3C4"),
		},
	} :: { [string]: SeasonDef },

	--[[ The season-only cosmetics at tier 30: a title over the name tag
	     (`UI/NameTags`), worn or not from the SEASON tab. ]]
	titles = {
		Wishkeeper = {
			text = "WISHKEEPER",
			colour = hex("#FFD45C"),
			stroke = hex("#6B2C55"),
		},
	} :: { [string]: Title },

	--[[ Tier 1 to 30. ]]
	tiers = {
		{ free = { coins = 500 }, premium = { gems = 50 } },
		{ free = { gems = 10 }, premium = { coins = 2000 } },
		{ free = { eggs = 1 }, premium = { gems = 30 } },
		{ free = { coins = 750 }, premium = { gems = 30 } },
		{ free = { crates = 1 }, premium = { gems = 75 } },
		{ free = { coins = 1000 }, premium = { coins = 3000 } },
		{ free = { gems = 10 }, premium = { gems = 30 } },
		{ free = { eggs = 1 }, premium = { gems = 40 } },
		{ free = { coins = 1250 }, premium = { gems = 40 } },
		{ free = { crates = 2 }, premium = { gems = 100 } },
		{ free = { coins = 1500 }, premium = { coins = 4000 } },
		{ free = { gems = 15 }, premium = { gems = 40 } },
		{ free = { eggs = 1 }, premium = { gems = 50 } },
		{ free = { coins = 1750 }, premium = { gems = 50 } },
		{ free = { crates = 1 }, premium = { trail = true } },
		{ free = { coins = 2000 }, premium = { coins = 5000 } },
		{ free = { gems = 15 }, premium = { gems = 50 } },
		{ free = { eggs = 1 }, premium = { gems = 60 } },
		{ free = { coins = 2250 }, premium = { gems = 60 } },
		{ free = { eggs = 2 }, premium = { gems = 100 } },
		{ free = { coins = 2500 }, premium = { coins = 6000 } },
		{ free = { gems = 20 }, premium = { gems = 60 } },
		{ free = { eggs = 1 }, premium = { gems = 70 } },
		{ free = { coins = 2750 }, premium = { gems = 70 } },
		{ free = { crates = 1 }, premium = { gems = 125 } },
		{ free = { coins = 3000 }, premium = { coins = 8000 } },
		{ free = { gems = 20 }, premium = { gems = 75 } },
		{ free = { eggs = 1 }, premium = { gems = 75 } },
		{ free = { coins = 3500 }, premium = { gems = 100 } },
		{
			free = { eggs = 3, crates = 3, weapon = true },
			premium = { title = true, gems = 150, weapon = true },
		},
	} :: { Tier },
}

return table.freeze(Season)
