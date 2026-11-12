--!strict
--[[
	What the end screens show, decided apart from the screen that draws it
	(`UI/EndScreen`) so it can be tested without one (`tests/EndScreenRules.spec`).

	Both rules are from the first-five-minutes playtest of 2026-11-12: the
	tutorial's Victory showed a dimmed "CHEST x0" row, which read as "you got
	nothing", and a NEXT LEVEL button that went to the lobby.

	Presentation only: nothing here is told to the server.
]]

local Balance = require(script.Parent.Parent.Config.Balance)
local EndScreenTheme = require(script.Parent.Parent.Config.EndScreenTheme)

local EndScreenRules = {}

--[[ What a run paid beyond coins and gems (`UI/EndScreen` `Summary`). ]]
export type Paid = {
	chests: number?,
	egg: any?,
	item: string?,
}

--[[ Whether Victory draws its chest row: only when the run paid something
     to put in it, a chest, a first clear's free egg or a boss's item. A run
     that paid none has no row, and its coins and gems take the box. ]]
function EndScreenRules.chestRow(paid: Paid): boolean
	return paid.egg ~= nil or paid.item ~= nil or (paid.chests or 0) > 0
end

--[[ What the main button says. Victory's goes on to the next level, except
     the tutorial's, which is won into the lobby
     (`RoomController.requestRestart`): that one says so. ]]
function EndScreenRules.buttonWords(won: boolean, stage: number): string
	if not won then
		return EndScreenTheme.defeat.buttonText
	end
	if stage == Balance.tutorialStage then
		return EndScreenTheme.victory.lobbyText
	end
	return EndScreenTheme.victory.buttonText
end

return EndScreenRules
