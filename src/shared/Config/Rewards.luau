--!strict
--[[
	Reasons to come back (Fable's loop review, item 4 and 13, approved by the
	owner 2026-11-11): a 7-day login calendar, three daily quests, a one-time
	starter list, and gems for every new Dex entry. Paid by the server only
	(`Data/Rewards`, rules in `Util/RewardRules`); the client only asks to
	claim, and the server checks the claim against the saved profile.

	**Why mostly gems.** Before this, gems came only from bosses: 50 the first
	time an area's boss falls and 10 every time after (`Config/Economy`). The
	store asks 58 / 180 / 450 for an Uncommon / Rare / Epic (`Config/Shop`,
	times the area's number), so a player farming Mossy Glade's boss needed
	45 boss kills for one Epic -- weeks. The target is **an Epic in days**.

	The arithmetic, for a player who plays every day and finishes the quests:

	    calendar   10+10+15+15+20+25+60 = 155 gems a week  ~ 22 a day
	    quests     3 x 15                                   = 45 a day
	    boss       one Mossy Glade repeat kill              = 10 a day
	                                                        ---------
	                                                          ~ 77 a day

	    Uncommon  58 gems  -> day 1
	    Rare     180 gems  -> day 3
	    Epic     450 gems  -> day 6 (about a week of play, not six)

	The first week pays more on top: the starter list (4 x 30 = 120), the
	first boss of each area (50, 80, ...) and the Dex (5 a new entry, about
	35 entries in Acts 1-3 = ~175), which brings the first Epic to about day
	3 for a new player. Coins ride along on most of it so the quests feel
	like a haul, but coins are not the point here: kills already pay them.
]]

export type Gift = { gems: number, coins: number }

export type Quest = {
	--[[ What counts towards it (`Data/Rewards.note`): "kills", "coins",
	     "levels", "bosses", "hatches", "crates". ]]
	kind: string,
	goal: number,
	--[[ What the screen says, the goal as %d. ]]
	words: string,
	--[[ One quest is dealt from each group a day, so a day never asks for
	     three fights or three purchases. ]]
	group: string,
	gems: number,
	coins: number,
}

export type Starter = {
	key: string,
	words: string,
	gems: number,
	coins: number,
}

local Rewards = {
	--[[ Day 1..7, then round again. A missed day does not reset the
	     calendar: the next login takes the next day's gift (kind to people
	     who play twice a week, and nothing to exploit, since the server
	     allows one claim per day). ]]
	calendar = {
		{ gems = 10, coins = 250 },
		{ gems = 10, coins = 0 },
		{ gems = 15, coins = 500 },
		{ gems = 15, coins = 0 },
		{ gems = 20, coins = 750 },
		{ gems = 25, coins = 0 },
		{ gems = 60, coins = 1500 },
	} :: { Gift },

	--[[ Three a day, one per group, the same three for everyone that day
	     (`RewardRules.questsFor`). ]]
	quests = {
		kills50 = {
			kind = "kills",
			goal = 50,
			words = "DEFEAT %d ENEMIES",
			group = "fight",
			gems = 15,
			coins = 150,
		},
		kills120 = {
			kind = "kills",
			goal = 120,
			words = "DEFEAT %d ENEMIES",
			group = "fight",
			gems = 15,
			coins = 300,
		},
		coins800 = {
			kind = "coins",
			goal = 800,
			words = "EARN %d COINS IN RUNS",
			group = "fight",
			gems = 15,
			coins = 200,
		},
		levels2 = {
			kind = "levels",
			goal = 2,
			words = "WIN %d LEVELS",
			group = "win",
			gems = 15,
			coins = 200,
		},
		boss1 = {
			kind = "bosses",
			goal = 1,
			words = "BEAT %d BOSS",
			group = "win",
			gems = 15,
			coins = 200,
		},
		hatch3 = {
			kind = "hatches",
			goal = 3,
			words = "HATCH %d EGGS",
			group = "spend",
			gems = 15,
			coins = 0,
		},
		crate1 = {
			kind = "crates",
			goal = 1,
			words = "OPEN %d WEAPON CRATE",
			group = "spend",
			gems = 15,
			coins = 0,
		},
	} :: { [string]: Quest },

	--[[ The groups, in the order the screen lists them. ]]
	groups = { "fight", "win", "spend" },

	--[[ Once per account, in this order. Each is judged from the saved
	     profile (`RewardRules.starterDone`), never from anything a client
	     says. ]]
	starter = {
		{ key = "beat11", words = "BEAT MOSSY GLADE 1-1", gems = 30, coins = 500 },
		{ key = "hatch", words = "HATCH AN EGG", gems = 30, coins = 0 },
		{ key = "equipPet", words = "EQUIP A PET", gems = 30, coins = 0 },
		{ key = "crate", words = "OPEN A WEAPON CRATE", gems = 30, coins = 0 },
	} :: { Starter },

	--[[ Gems for each new entry in any of the Dex Hall's books (item 13),
	     once per entry ever, so losing and regaining a thing pays nothing. ]]
	dexGems = 5,

	--[[ Seconds in a reward day, and where it starts: midnight UTC. ]]
	dayLength = 86400,
}

return table.freeze(Rewards)
