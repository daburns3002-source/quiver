--!strict
--[[
	Goals: lifetime achievements that never reset (owner, 2026-11-14: "there
	should be more rewards for players", then "i like all of the rewards
	that you mentioned ... build these"). Each has three steps, bronze,
	silver and gold, claimed in order on the REWARDS screen's GOALS tab.

	**They pay mostly coins, eggs and crates, not gems.** The store is tuned
	so an Epic is about a week of play (`Config/Rewards`); a flood of gems
	here would make it days. A bronze step pays coins, a silver an egg or a
	crate, a gold a few of them with a little gems on top. Eggs and crates
	are the best open to the player, free, as an Endless milestone's are
	(`Util/PrizeRules`, given by `Data/QuestChest`). Never a Mythic for
	sure, a boss item, a badge or a trail: those keep their own ways.

	`stat` is what is counted (`Util/GoalRules.value`): a lifetime counter
	the server keeps as things really happen (`SaveSchema.stats`, version
	18), or something read from what the save already holds (pets owned,
	the deepest Endless floor). No client reports any of it.

	`kind` picks the row's picture and `place` its GO, as a quest's do
	(`Config/Rewards.places`).
]]

export type Prize = {
	coins: number?,
	gems: number?,
	--[[ Free hatches of the best egg open to the player, and free opens of
	     the best crate for the class they play. ]]
	eggs: number?,
	crates: number?,
}

export type Goal = {
	key: string,
	--[[ What the screen says, the step's goal as %d. ]]
	words: string,
	stat: string,
	kind: string,
	place: string?,
	--[[ Bronze, silver, gold: what to reach and what it pays. ]]
	steps: { { goal: number, prize: Prize } },
}

local function steps(
	bronze: number,
	silver: number,
	gold: number,
	pay: { Prize }
): { { goal: number, prize: Prize } }
	return {
		{ goal = bronze, prize = pay[1] },
		{ goal = silver, prize = pay[2] },
		{ goal = gold, prize = pay[3] },
	}
end

--[[ The three steps' usual pay, by what the goal is about: fighting pays in
     crates, collecting in eggs, and the rest a mix. ]]
local FIGHT: { Prize } = {
	{ coins = 500 },
	{ crates = 1, coins = 1000 },
	{ crates = 3, gems = 20 },
}
local COLLECT: { Prize } = {
	{ coins = 500 },
	{ eggs = 1, coins = 1000 },
	{ eggs = 3, gems = 20 },
}
local MIXED: { Prize } = {
	{ coins = 750 },
	{ eggs = 1, crates = 1 },
	{ eggs = 2, crates = 2, gems = 20 },
}

local Goals = {
	--[[ What the three steps are called, and the colour of each one's medal. ]]
	medals = { "BRONZE", "SILVER", "GOLD" },
	medalColours = {
		Color3.fromRGB(196, 124, 72),
		Color3.fromRGB(176, 190, 204),
		Color3.fromRGB(255, 196, 46),
	},

	--[[ The lifetime counters the server keeps (`SaveSchema.stats`): each a
	     thing `Data/Rewards.note` is told of as it happens. ]]
	counted = {
		"kills",
		"coins",
		"levels",
		"levelsRanger",
		"levelsArcanist",
		"levelsWarden",
		"bosses",
		"hatches",
		"crates",
		"merges",
		"quests",
	},

	--[[ In the order the screen lists them when nothing else sorts them. ]]
	goals = {
		{
			key = "kills",
			words = "DEFEAT %d ENEMIES",
			stat = "kills",
			kind = "kills",
			place = "Portal",
			steps = steps(500, 2500, 10000, FIGHT),
		},
		{
			key = "levels",
			words = "WIN %d LEVELS",
			stat = "levels",
			kind = "levels",
			place = "Portal",
			steps = steps(10, 40, 120, MIXED),
		},
		{
			key = "levelsRanger",
			words = "WIN %d AS THE RANGER",
			stat = "levelsRanger",
			kind = "levels",
			place = "Portal",
			steps = steps(5, 20, 50, FIGHT),
		},
		{
			key = "levelsArcanist",
			words = "WIN %d AS THE ARCANIST",
			stat = "levelsArcanist",
			kind = "levels",
			place = "Portal",
			steps = steps(5, 20, 50, FIGHT),
		},
		{
			key = "levelsWarden",
			words = "WIN %d AS THE WARDEN",
			stat = "levelsWarden",
			kind = "levels",
			place = "Portal",
			steps = steps(5, 20, 50, FIGHT),
		},
		{
			key = "bosses",
			words = "BEAT %d BOSSES",
			stat = "bosses",
			kind = "bosses",
			place = "Portal",
			steps = steps(3, 15, 50, MIXED),
		},
		{
			key = "areas",
			words = "BEAT %d AREAS' BOSSES",
			stat = "areas",
			kind = "bosses",
			place = "Portal",
			steps = steps(1, 2, 4, MIXED),
		},
		{
			key = "coins",
			words = "PICK UP %d COINS",
			stat = "coins",
			kind = "coins",
			place = "Portal",
			steps = steps(10000, 100000, 1000000, COLLECT),
		},
		{
			key = "endless",
			words = "REACH ENDLESS FLOOR %d",
			stat = "endless",
			kind = "levels",
			place = "Portal",
			steps = steps(10, 30, 60, MIXED),
		},
		{
			key = "classLevel",
			words = "REACH CLASS LEVEL %d",
			stat = "classLevel",
			kind = "levels",
			place = "Portal",
			steps = steps(3, 6, 10, FIGHT),
		},
		{
			key = "hatches",
			words = "HATCH %d EGGS",
			stat = "hatches",
			kind = "hatches",
			place = "EggHatchery",
			steps = steps(10, 50, 200, COLLECT),
		},
		{
			key = "pets",
			words = "OWN %d DIFFERENT PETS",
			stat = "pets",
			kind = "hatches",
			place = "EggHatchery",
			steps = steps(5, 15, 30, COLLECT),
		},
		{
			key = "crates",
			words = "OPEN %d WEAPON CRATES",
			stat = "crates",
			kind = "crates",
			place = "Blacksmith",
			steps = steps(5, 25, 100, FIGHT),
		},
		{
			key = "weapons",
			words = "OWN %d DIFFERENT WEAPONS",
			stat = "weapons",
			kind = "crates",
			place = "Blacksmith",
			steps = steps(6, 15, 30, FIGHT),
		},
		{
			key = "merges",
			words = "MERGE %d TIMES",
			stat = "merges",
			kind = "crates",
			place = "GearStation",
			steps = steps(3, 15, 50, MIXED),
		},
		{
			key = "topTier",
			words = "OWN %d S-TIER ITEMS",
			stat = "topTier",
			kind = "crates",
			place = "GearStation",
			steps = steps(1, 3, 8, MIXED),
		},
		{
			key = "rare",
			words = "OWN %d LEGENDARY OR MYTHIC",
			stat = "rare",
			kind = "hatches",
			place = "EggHatchery",
			steps = steps(1, 5, 12, MIXED),
		},
		{
			key = "dex",
			words = "FIND %d DEX ENTRIES",
			stat = "dex",
			kind = "kills",
			place = "DexHall",
			steps = steps(15, 40, 80, COLLECT),
		},
		{
			key = "quests",
			words = "CLAIM %d DAILY QUESTS",
			stat = "quests",
			kind = "coins",
			steps = steps(10, 50, 200, MIXED),
		},
		{
			key = "logins",
			words = "CLAIM %d DAILY GIFTS",
			stat = "logins",
			kind = "coins",
			steps = steps(3, 14, 60, COLLECT),
		},
	} :: { Goal },
}

return table.freeze(Goals)
