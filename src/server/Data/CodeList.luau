--!strict
--[[
	The codes a player can type in the CODES box (`Data/Codes`). **Server
	only:** this module is in ServerScriptService, which no client receives,
	so the words cannot be read by an exploiter. Never move it, or copy a code,
	into `src/shared` (`tests/Codes.spec` fails if a CodeList replicates).

	Each code, keyed by its word in capitals and digits only (how
	`Util/CodeRules.normalise` reads what was typed: spaces and case do not
	matter):
	- `prize`: any of `coins`, `gems`, `eggs` (the best egg open to the
	  player) and `crates` (the best crate for their class), whole numbers.
	  Eggs and crates are given as a quest chest's are (`Data/QuestChest`),
	  and what cannot be given is paid in gems.
	- `expires`: optional, "YYYY-MM-DD", the last day (UTC) it works.
	Each player may use each code once (`codesUsed` in the save).

	- `likes`: optional, a like-goal code: it does not exist until the game
	  has that many likes (`Data/LikeGoal`, the count the owner sets as the
	  ConfigService key `likes`), and is then shown under the CODES box.

	The words and prizes are Claude's ideas (owner, 2026-11-20: "come up with
	some ideas"), starting numbers: a day of quests is about 45 gems and 500
	coins, a Mossy Egg 500 coins.
]]

local CodeRules = require(game:GetService("ReplicatedStorage").Shared.Util.CodeRules)

local list: { [string]: CodeRules.Code } = {
	-- to share at launch, each for a while
	ARROWBORNE = { prize = { coins = 1000, gems = 50 }, expires = "2027-02-28" },
	BULLSEYE = { prize = { crates = 1, gems = 25 }, expires = "2027-02-28" },
	WILFPACK = { prize = { eggs = 1, gems = 25 }, expires = "2027-02-28" },
	-- a story nod (the King Bloblin cutscene), no end date
	WANTED = { prize = { gems = 40 } },
	-- the like goal, in the areas' order; each shown once its goal is hit
	MOSSYGLADE = { prize = { coins = 500, gems = 25 }, likes = 100 },
	SLIMEKING = { prize = { eggs = 1, gems = 50 }, likes = 250 },
	THORNWOOD = { prize = { crates = 1, eggs = 1, gems = 75 }, likes = 500 },
	DROWNEDVILLAGE = { prize = { eggs = 2, gems = 100 }, likes = 1000 },
	BOGHEART = { prize = { crates = 2, gems = 150 }, likes = 2500 },
	WORLDTREE = { prize = { eggs = 3, crates = 1, gems = 200 }, likes = 5000 },
	BOGRISING = { prize = { eggs = 3, crates = 3, gems = 300 }, likes = 10000 },
}

return table.freeze(list)
