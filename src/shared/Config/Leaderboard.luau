--!strict
--[[
	The FARTHEST ADVENTURERS board in the lobby (owner, 2026-10-25: "add a
	leaderboard for farthest story completion"; the look is
	`assets/concepts/blocky/lobby/lobby_v3.png`): the players who have come
	furthest through `Balance.campaign`, scored by `Util/StoryProgress`,
	kept by `Run/StoryLeaderboard`. The store is described in
	`docs/LEADERBOARD.md`.
]]

local Leaderboard = {
	--[[ The OrderedDataStore. Versioned: a change to what the score means
	     (a new area before Thornwood, say) gets a new name and a fresh
	     board, never a rewrite of this one. ]]
	storeName = "FarthestStory_v1",
	--[[ Seconds: the least time between two writes of one player's best,
	     and between two reads of the top. ]]
	flushEvery = 30,
	refreshEvery = 60,
	--[[ Seconds the server's close waits for the last writes (Roblox
	     allows 30 in all). ]]
	closeWait = 25,
	--[[ Whether a Studio playtest writes the store. Off: its debug keys
	     (room jumps, granted cards) make runs that are not real, so Studio
	     reads the board but keeps its own scores in memory. ]]
	writeFromStudio = false,
	--[[ Rows on the board, and so how many are read. ]]
	rows = 10,
	--[[ The SurfaceGui's pixels per stud of the part's face. ]]
	pixelsPerStud = 50,
	--[[ Shares of a row's width: rank, name, area, room. ]]
	columns = { rank = 0.1, name = 0.36, area = 0.36, room = 0.18 },
	--[[ Shares of the board's height round the rows, and between them. ]]
	padding = 0.04,
	gap = 0.012,
	--[[ What an empty row shows. ]]
	emptyName = "---",
	colors = {
		board = Color3.fromRGB(22, 24, 38),
		row = Color3.fromRGB(34, 38, 58),
		rowOutline = Color3.fromRGB(12, 12, 20),
		text = Color3.fromRGB(240, 236, 220),
		area = Color3.fromRGB(232, 214, 140),
		room = Color3.fromRGB(240, 236, 220),
		--[[ The top three's rank and name. ]]
		gold = Color3.fromRGB(255, 204, 64),
		silver = Color3.fromRGB(204, 212, 224),
		bronze = Color3.fromRGB(222, 136, 64),
		empty = Color3.fromRGB(110, 112, 130),
	},
}

return table.freeze(Leaderboard)
