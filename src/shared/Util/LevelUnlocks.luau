--!strict
--[[
	Which of an area's levels a player may play, from the levels they have
	beaten (the profile's `levelsBeaten`, keyed by each stage's `level`,
	"1-3"): the first always, every other once the one before it is beaten
	(owner, 2026-10-26: the ten Mossy Glade levels, picked on the portal's
	screen). Also where NEXT LEVEL goes after a win, and whether the
	tutorial is still owed.

	The server decides with it (`Run/Lobby.startFor`, `Run/RoomController`,
	`Main`'s IntroBegin); the portal's screen (`UI/PortalScreen`) only draws
	what it says. Pure, so `tests/LevelUnlocks.spec` pins it with made-up
	stages.
]]

-- for its types only: nothing here reads the game's own stages
local Balance = require(script.Parent.Parent.Config.Balance)

local LevelUnlocks = {}

export type Stage = Balance.StageConfig
export type Beaten = { [string]: boolean }

function LevelUnlocks.isBeaten(stage: Stage?, beaten: Beaten?): boolean
	local key = stage and stage.level
	return key ~= nil and beaten ~= nil and beaten[key] == true
end

--[[ Whether the `position`th of `levels` (stage indices, in order) is open.
     A stage with no `level` before it gates nothing (Thornwood's single
     level is always open, as it was). ]]
function LevelUnlocks.isUnlocked(
	levels: { number },
	stages: { [number]: Stage },
	beaten: Beaten?,
	position: number
): boolean
	if position ~= math.floor(position) or position < 1 or position > #levels then
		return false
	end
	if not stages[levels[position]] then
		return false
	end
	if position == 1 then
		return true
	end
	local before = stages[levels[position - 1]]
	if not before or not before.level then
		return true
	end
	return LevelUnlocks.isBeaten(before, beaten)
end

--[[ The level the screen picks first: the first open one not beaten yet,
     or the last open one when all of those are. ]]
function LevelUnlocks.suggested(
	levels: { number },
	stages: { [number]: Stage },
	beaten: Beaten?
): number
	local last = 1
	for position, index in levels do
		if not LevelUnlocks.isUnlocked(levels, stages, beaten, position) then
			break
		end
		last = position
		if not LevelUnlocks.isBeaten(stages[index], beaten) then
			return position
		end
	end
	return last
end

--[[ NEXT LEVEL after stage `current` is won, when `levels` holds it: the
     next of them, or nil after the last (back to the lobby). The second
     value says whether `current` is in `levels` at all. ]]
function LevelUnlocks.nextAfter(levels: { number }, current: number): (number?, boolean)
	for position, index in levels do
		if index == current then
			return levels[position + 1], true
		end
	end
	return nil, false
end

--[[ Whether the tutorial is still owed: until the level keyed `key` is
     beaten (owner, 2026-10-26: "the tutorial should play until they have
     beaten the first level of mossy glade"). A profile not loaded owes it. ]]
function LevelUnlocks.tutorialOwed(beaten: Beaten?, key: string): boolean
	return not (beaten ~= nil and beaten[key] == true)
end

return LevelUnlocks
