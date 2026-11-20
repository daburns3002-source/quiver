--!strict
--[[
	The CODES box (`UI/SettingsScreen`, `Data/Codes`, `Util/CodeRules`; owner,
	2026-11-18): how a typed code is read, how often a player may try one, and
	what the box answers. **The codes themselves are not here.** They live on
	the server only (`ServerScriptService.Server.Data.CodeList`), so no client
	can read them; this module is in ReplicatedStorage and holds no code word.
]]

return table.freeze({
	--[[ The longest code a player can type. A longer text is not a code. ]]
	maxLength = 24,
	--[[ Tries per player (`Util/Throttle`): `burst` at once, then one every
	     `every` seconds. A person typing never meets it; a script guessing
	     codes gets four a minute. Under it sits `Net/Inbound`'s floor. ]]
	tries = table.freeze({ burst = 4, every = 15 }),
	--[[ What the box says back, by `CodeRules` result. `Ok`'s `%s` is the
	     prize in words (`CodeRules.prizeWords`). The typed text is never
	     said back. ]]
	answers = table.freeze({
		Ok = "CODE REDEEMED! %s",
		Unknown = "THAT CODE DOES NOT EXIST",
		Expired = "THAT CODE HAS EXPIRED",
		Used = "YOU ALREADY USED THAT CODE",
		Empty = "TYPE A CODE FIRST",
		Slow = "TOO MANY TRIES! WAIT A MOMENT",
	}),
	--[[ The box's grey words before anything is typed. ]]
	hint = "TYPE A CODE",
	--[[ The like goal (`Data/LikeGoal`, owner 2026-11-20): a code in the
	     server's list with `likes` works once the game has that many. A game
	     server cannot read its own like count (Roblox's votes endpoint needs a
	     signed-in user), so the owner sets it: the ConfigService key `key` on
	     the Creator Hub (Configs), live within minutes, no republish. Missing
	     or not a number reads as 0. The words under the CODES box, and the
	     toast to everyone in the lobby when a goal is reached. ]]
	likeGoal = table.freeze({
		key = "likes",
		next = "LIKE GOAL: %s LIKES = A NEW CODE!",
		reached = "LIKE GOAL HIT! NEW CODE: %s",
		both = "NEW CODE: %s   NEXT GOAL: %s LIKES",
		toast = "LIKE GOAL HIT! NEW CODE: %s",
	}),
})
