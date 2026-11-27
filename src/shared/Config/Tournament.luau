--!strict
--[[
	The weekly Endless tournament (owner, 2026-11-18: "yes all of these
	create them"): each player's best Endless floor this week, a board of
	this week's top ten in the lobby (`Run/WeeklyTournament`), and prizes
	paid on the next join once the week is over. `docs/LEADERBOARD.md` has
	the store; `Util/TournamentRules` the rules.

	A week runs from Monday 00:00 UTC to the next. The prize table had the
	owner's yes (2026-11-18), with the top ten's set weapon picks added.
	Starting numbers, as the shop's prices are.
]]

export type Place = {
	--[[ The last place this prize covers: 1, 10, 100. ]]
	upTo: number,
	name: string,
	gems: number,
	soulstones: number,
	--[[ Whether it carries a win, and so the CHAMPION title. ]]
	champion: boolean,
	--[[ Themed set weapons the player picks (`Config/Shop.sets`). ]]
	picks: number,
}

export type Band = {
	--[[ The least floor this band pays for. ]]
	from: number,
	soulstones: number,
	coins: number,
	gems: number,
}

return table.freeze({
	--[[ One OrderedDataStore, its scope the week's Monday ("2026-11-16"),
	     so every week is its own board and an old one is never rewritten.
	     The value is `TournamentRules.score`: the floor, with the time it
	     took breaking a tie. ]]
	storeName = "EndlessWeekly_v1",
	--[[ Seconds after a week ends before it pays, so the last floors of
	     the week (written at most `Leaderboard.flushEvery` late, or as a
	     server closes) are in the store when its places are read. ]]
	grace = 300,
	--[[ Seconds between two tries at paying one player's week when the
	     store could not be read. ]]
	retryEvery = 60,
	--[[ Unpaid weeks one save holds: past this the oldest is dropped.
	     Only a store that failed for weeks on end leaves more than one. ]]
	keep = 8,
	--[[ Tenths of a second a floor's time can hold (about 27 hours); a
	     slower run counts as this slow. ]]
	timeSpan = 1_000_000,

	--[[ By place on the week's board, best first. ]]
	places = {
		{ upTo = 1, name = "CHAMPION", gems = 300, soulstones = 1000, champion = true, picks = 2 },
		{ upTo = 10, name = "TOP 10", gems = 150, soulstones = 500, champion = false, picks = 1 },
		{ upTo = 100, name = "TOP 100", gems = 60, soulstones = 250, champion = false, picks = 0 },
	} :: { Place },
	--[[ A pick is any themed set weapon the player does not own, of any
	     set and any class (owner, 2026-11-18: the yes to this table, "and
	     include the new models that were imported today"): chosen on the
	     prize panel, granted by the server. Every stocked set counts,
	     whether or not its shelf is on sale that week. A player who owns
	     them all gets `pickGems` a pick instead. ]]
	pickGems = 300,
	--[[ For everyone who played that week, by the deepest floor, on top of
	     a place's prize. Deepest band first is not needed: the deepest
	     `from` at or under the floor is the one. ]]
	bands = {
		{ from = 1, soulstones = 50, coins = 0, gems = 0 },
		{ from = 10, soulstones = 100, coins = 1000, gems = 0 },
		{ from = 20, soulstones = 200, coins = 2500, gems = 0 },
		{ from = 30, soulstones = 300, coins = 0, gems = 10 },
		{ from = 50, soulstones = 500, coins = 0, gems = 25 },
	} :: { Band },

	--[[ Over a week's winner's name tag, for good (`UI/NameTags`); more
	     wins add "x2", "x3". ]]
	title = "ENDLESS CHAMPION",
	--[[ The Player attribute that carries the count of wins. ]]
	winsAttribute = "TournamentWins",

	--[[ The board's own words and colours; the rest is
	     `Config/Leaderboard`'s, so the three boards read as one set. ]]
	heading = "THIS WEEK'S DELVERS",
	columns = { rank = 0.11, name = 0.43, floor = 0.26, time = 0.2 },
	colors = {
		heading = Color3.fromRGB(255, 204, 64),
		countdown = Color3.fromRGB(120, 214, 220),
		time = Color3.fromRGB(170, 176, 196),
		champion = Color3.fromRGB(255, 204, 64),
		--[[ The prize panel's gold words, dark enough to read on its cream
		     (about 5:1; the bright gold is under 2:1 there). ]]
		prizeInk = Color3.fromRGB(150, 88, 0),
	},
})
