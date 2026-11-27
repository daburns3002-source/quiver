--!strict
--[[
	The "YOU: #N" row under each leaderboard (`Util/BoardRank`): a player's
	place in what the server knows, and the honest answer when they are
	past what it read.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardRank = require(ReplicatedStorage.Shared.Util.BoardRank)
local Leaderboard = require(ReplicatedStorage.Shared.Config.Leaderboard)
local TestRunner = require(script.Parent.TestRunner)

local function board(scores: { number }): { BoardRank.Scored }
	local list = {}
	for index, score in scores do
		table.insert(list, { userId = index, score = score })
	end
	return list
end

return function(t: TestRunner.Helper)
	t.test("a player on the list is ranked by their place in it", function()
		local list = board({ 90, 70, 50 })
		t.equal(BoardRank.place(list, 1, nil), 1)
		t.equal(BoardRank.place(list, 3, nil), 3)
		t.equal(BoardRank.words(3, 100), "YOU: #3")
	end)

	t.test("a player with no score is not ranked", function()
		local list = board({ 90, 0 })
		t.equal(BoardRank.place(list, 2, nil), BoardRank.NONE)
		t.equal(BoardRank.place(list, 99, nil), BoardRank.NONE)
		t.equal(BoardRank.words(BoardRank.NONE, 100), "YOU: ---")
	end)

	t.test("under a full read's last score, the place is past the read", function()
		local read = board({ 90, 70, 50 })
		t.isNil(BoardRank.cutoff(read, 4), "a short read is everyone there is")
		local cut = BoardRank.cutoff(read, 3)
		t.equal(cut, 50)
		-- this server's own player, folded in under the read
		local list = board({ 90, 70, 50, 20 })
		t.equal(BoardRank.place(list, 4, cut), BoardRank.BEYOND)
		t.equal(BoardRank.place(list, 3, cut), 3, "level with the last read entry is on the list")
		t.equal(BoardRank.place(list, 4, nil), 4, "with a short read, fourth is fourth")
		t.equal(BoardRank.words(BoardRank.BEYOND, 100), "YOU: #100+")
	end)

	t.test("the read is deep enough for the rows, and one page", function()
		t.isTrue(Leaderboard.rankDepth >= Leaderboard.rows)
		t.isTrue(Leaderboard.rankDepth <= 100, "an OrderedDataStore page holds 100 at most")
	end)
end
