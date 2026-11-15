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

--[[ A prize that can hold free eggs and crates too (a Dex page's chest;
     `Config/Goals.Prize` is the same shape). ]]
export type Prize = { coins: number?, gems: number?, eggs: number?, crates: number? }

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
	--[[ What it is about, for its picture, and where it is done, for its
	     GO (`UI/RewardsScreen`): a lobby piece, or "Portal". ]]
	kind: string,
	place: string,
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
			-- was "EARN %d COINS IN RUNS", which read as a wallet total
			words = "PICK UP %d COINS",
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

	--[[ Where each kind of quest is done, for the row's GO button: the
	     lobby piece it points the player to (`Config/Lobby.stations`), or
	     "Portal" for a run. ]]
	places = {
		kills = "Portal",
		coins = "Portal",
		levels = "Portal",
		bosses = "Portal",
		hatches = "EggHatchery",
		crates = "Blacksmith",
	} :: { [string]: string },

	--[[ The daily bonus chest (owner, 2026-11-14: "there should be more
	     rewards for players"): claim all three of the day's quests and it
	     opens, free: an egg one day and a weapon crate the next
	     (`RewardRules.bonusKind`), the best open to the player, as an
	     Endless milestone's are. `gems` is what it pays a player with
	     neither an egg nor a crate to open. ]]
	bonus = { words = "FINISH ALL 3 FOR A CHEST", gems = 25 },

	--[[ The gift box (`Util/GiftRules`; owner, 2026-11-14): every `wins`
	     campaign levels won fills a gift, an egg one time and a weapon
	     crate the next, free, the best open to the player. The box holds
	     `hold` gifts; wins past a full box are not counted. No timer. At
	     about a gift every ten minutes of winning it is one more egg or
	     crate on top of the three or so those coins already buy. ]]
	gift = { wins = 3, hold = 3, words = "WIN 3 LEVELS FOR A GIFT" },

	--[[ A chest for each finished Dex page (`Util/PageRules`; owner,
	     2026-11-14), by book: every enemy of an area met, or the collection
	     sets, all of an area's pets or all of its weapons, which pay the
	     big gifts. Once each. With four areas the gems come to 600 in all,
	     for collecting everything there is, Mythics included: years, not
	     days, so the store keeps its price. ]]
	pages = {
		Enemies = { eggs = 1, crates = 1 },
		Pets = { eggs = 5, gems = 75 },
		Weapons = { crates = 5, gems = 75 },
	} :: { [string]: Prize },

	--[[ Level stars (`Util/StarRules`; owner, 2026-11-14): a campaign
	     level has three stars, for winning it, for finishing with more
	     than `health` percent of health, and for finishing inside its time
	     (so many seconds a room, or a wave). An area's stars open `chests`,
	     once each. Two areas have ten levels today, so every chest there is
	     comes to 150 gems: the store keeps its price. The times are a first
	     guess, generous on purpose; tune them once real clears are timed. ]]
	stars = {
		health = 50,
		secondsPerRoom = 25,
		secondsPerWave = 20,
		chests = {
			{ stars = 10, prize = { eggs = 1, crates = 1 } },
			{ stars = 20, prize = { eggs = 2, crates = 2, gems = 25 } },
			{ stars = 30, prize = { eggs = 3, crates = 3, gems = 50 } },
		} :: { { stars: number, prize: Prize } },
	},

	--[[ A win streak (`Util/RunBonus`; owner, 2026-11-14): each level won
	     in a row adds `step` to the next level's kill and clear coins, up
	     to `cap`. Coins only: they already come from play, and a half more
	     of them moves no gem price. ]]
	streak = { step = 0.1, cap = 0.5 },
	--[[ Co-op: a run in a party pays this much more coins to each player. ]]
	friendCoins = 0.2,

	--[[ Victory's chests (`Util/VictoryChestRules`; owner, 2026-11-14): a
	     level won offers `chests` shut ones and the player opens one. Each
	     is rolled by itself from `prizes` by `weight` (they add to 100).
	     Coins are a share of the area's clear bonus, `low` to `high`; gems
	     are `low` to `high` of them; an egg or a crate is the area's own,
	     free. About 0.6 gems a win, so 20 wins a day add 12 to the 77 the
	     daily rewards pay: the store keeps its price. An egg or crate is
	     about one win in five and a half, each worth about a level's
	     coins (`Config/Economy`). ]]
	victory = {
		chests = 3,
		prizes = {
			{ kind = "coins", weight = 62, low = 0.5, high = 1.5 },
			{ kind = "gems", weight = 20, low = 2, high = 4 },
			{ kind = "egg", weight = 9, low = 1, high = 1 },
			{ kind = "crate", weight = 9, low = 1, high = 1 },
		},
	},

	--[[ A quest tells the player how it is going as they play: a line when
	     it passes each of these shares of its goal (`RewardRules.note`),
	     the last being done. Only a quest with a goal of `stepGoal` or more
	     says the half; a short one only says done. ]]
	steps = { 0.5, 1 },
	stepGoal = 10,

	--[[ Once per account, in this order. Each is judged from the saved
	     profile (`RewardRules.starterDone`), never from anything a client
	     says. ]]
	starter = {
		{
			key = "beat11",
			kind = "levels",
			place = "Portal",
			words = "BEAT MOSSY GLADE 1-1",
			gems = 30,
			coins = 500,
		},
		{
			key = "hatch",
			kind = "hatches",
			place = "EggHatchery",
			words = "HATCH AN EGG",
			gems = 30,
			coins = 0,
		},
		{
			key = "equipPet",
			kind = "hatches",
			place = "GearStation",
			words = "EQUIP A PET",
			gems = 30,
			coins = 0,
		},
		{
			key = "crate",
			kind = "crates",
			place = "Blacksmith",
			words = "OPEN A WEAPON CRATE",
			gems = 30,
			coins = 0,
		},
	} :: { Starter },

	--[[ Gems for each new entry in any of the Dex Hall's books (item 13),
	     once per entry ever, so losing and regaining a thing pays nothing. ]]
	dexGems = 5,

	--[[ Seconds in a reward day, and where it starts: midnight UTC. ]]
	dayLength = 86400,
}

return table.freeze(Rewards)
