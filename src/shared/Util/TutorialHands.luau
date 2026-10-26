--!strict
--[[
	Which fixed hand the tutorial deals (`Config/Tutorial`): pure, so
	`Run/RunSession` asks it on every level-up and `tests/Tutorial.spec` pins
	the owner's rules (a Common, an Uncommon and a Rare first; Multishot in the
	middle on room 3's level-up; nothing Legendary or Mythic otherwise).

	`progress` is what this player has been dealt so far this stage: how many
	hands, how many of them from `hands`, and the rooms whose own hand was
	dealt. A nil hand means the list has run out; the caller rolls one from the
	ordinary pool, with the tutorial's banned rarities kept out.
]]

local TutorialHands = {}

export type Config = {
	firstHand: { string },
	roomHands: { [number]: { string } },
	hands: { { string } },
	levelUpIn: { number },
}

export type Progress = {
	dealt: number,
	ordinary: number,
	rooms: { [number]: boolean },
}

export type Kind = "First" | "Room" | "Ordinary"

function TutorialHands.newProgress(): Progress
	return { dealt = 0, ordinary = 0, rooms = {} }
end

--[[ The hand for the next level-up in `room`, and which kind it is. ]]
function TutorialHands.handFor(c: Config, progress: Progress, room: number): ({ string }?, Kind)
	if progress.dealt == 0 then
		return c.firstHand, "First"
	end
	local own = c.roomHands[room]
	if own and not progress.rooms[room] then
		return own, "Room"
	end
	return c.hands[progress.ordinary + 1], "Ordinary"
end

--[[ Records that the hand `handFor` gave was dealt. ]]
function TutorialHands.dealt(progress: Progress, kind: Kind, room: number)
	progress.dealt += 1
	if kind == "Room" then
		progress.rooms[room] = true
	elseif kind == "Ordinary" then
		progress.ordinary += 1
	end
end

--[[ Whether `room` must level up before its gate opens, and has not yet:
     its own hand is still to come. ]]
function TutorialHands.owesLevel(c: Config, progress: Progress, room: number): boolean
	return table.find(c.levelUpIn, room) ~= nil
		and c.roomHands[room] ~= nil
		and not progress.rooms[room]
end

return TutorialHands
