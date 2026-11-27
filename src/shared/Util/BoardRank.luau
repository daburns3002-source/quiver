--!strict
--[[
	Where one player stands on a leaderboard, for the "YOU: #N" row under
	each board (the loop review's item 13). Pure; `tests/BoardRank.spec`.

	The server knows a board as the store's top `depth` entries with its own
	players' bests folded in, best first. A player inside that is ranked by
	their place in it. A player whose best is below the last entry the store
	gave, when the store gave a full read, is somewhere past `depth`: the
	honest answer is "#100+", not the place they would have among only the
	people this server happens to know.
]]

local BoardRank = {}

export type Scored = { userId: number, score: number }

--[[ Not on the board at all (no score yet). ]]
BoardRank.NONE = 0
--[[ On it, but past what the server read. ]]
BoardRank.BEYOND = -1

--[[ `userId`'s place in `sorted` (best first): 1 and up, `NONE` with no
     score, `BEYOND` when their score is under `cutoff` -- the lowest score
     of a full read of the store, or nil when the read was not full (then
     the list is everyone there is). ]]
function BoardRank.place(sorted: { Scored }, userId: number, cutoff: number?): number
	for index, entry in sorted do
		if entry.userId == userId then
			if entry.score <= 0 then
				return BoardRank.NONE
			end
			if cutoff and entry.score < cutoff then
				return BoardRank.BEYOND
			end
			return index
		end
	end
	return BoardRank.NONE
end

--[[ The lowest score of a full read (`count` entries asked for), or nil
     when the store had fewer: then nobody is past the list. ]]
function BoardRank.cutoff(fetched: { Scored }, depth: number): number?
	if #fetched < depth then
		return nil
	end
	return fetched[#fetched].score
end

--[[ What the row says: "YOU: #7", "YOU: #100+", "YOU: ---". ]]
function BoardRank.words(place: number, depth: number): string
	if place == BoardRank.BEYOND then
		return `YOU: #{depth}+`
	elseif place <= 0 then
		return "YOU: ---"
	end
	return `YOU: #{place}`
end

return BoardRank
