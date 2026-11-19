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

	Starting numbers (owner to set the real words and prizes before launch).
]]

local CodeRules = require(game:GetService("ReplicatedStorage").Shared.Util.CodeRules)

local list: { [string]: CodeRules.Code } = {
	-- placeholder launch code
	LAUNCH = { prize = { coins = 500, gems = 25 }, expires = "2027-01-31" },
}

return table.freeze(list)
