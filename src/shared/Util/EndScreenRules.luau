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
local LevelUnlocks = require(script.Parent.LevelUnlocks)
local LobbyConfig = require(script.Parent.Parent.Config.Lobby)

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

--[[ Where the class level plate (`UI/ClassLevelPlate`) stands on a screen
     `viewW` by `viewH` whose end panel, centred, is `panelW` by `panelH`:
     its left, top, width and height in pixels, for a plate drawn `w` by
     `h`. Beside the panel on a wide screen, where the room is; under it on
     an upright one, as tall as the room there. Never over the panel's
     buttons, and never at the top, where Roblox's own buttons sit. ]]
local PLATE_GAP = 8
local PLATE_SMALLEST = 0.6
function EndScreenRules.levelPlate(
	viewW: number,
	viewH: number,
	panelW: number,
	panelH: number,
	w: number,
	h: number
): (number, number, number, number)
	local shape = h / w
	local side = (viewW - panelW) / 2 - 2 * PLATE_GAP
	local under = (viewH - panelH) / 2 - 2 * PLATE_GAP
	if viewW > viewH and side >= w * PLATE_SMALLEST then
		local width = math.min(w * 1.25, side)
		return (viewW + panelW) / 2 + PLATE_GAP,
			(viewH - panelH) / 2 + panelH * 0.18,
			width,
			width * shape
	end
	local height = math.clamp(under, h * PLATE_SMALLEST, h)
	local width = math.min(height / shape, viewW - 2 * PLATE_GAP)
	height = width * shape
	--[[ Under the panel when it fits there; on a screen with room nowhere
	     (nearly square, the panel filling it) it stands at the top
	     instead, over the ribbon's edge rather than over a button. ]]
	local top = if height <= under + PLATE_GAP then (viewH + panelH) / 2 + PLATE_GAP else PLATE_GAP
	return (viewW - width) / 2, top, width, height
end

--[[ Whether winning `stage` leads on to another level
     (`RoomController.requestRestart`): the next of its area, or after its
     area's last the first of the area after it (`LevelUnlocks.nextArea`).
     Not the tutorial, and not the last level of the last area built: those
     are won into the lobby. A stage behind no portal goes on along the
     campaign. ]]
function EndScreenRules.goesOn(stage: number): boolean
	if stage == Balance.tutorialStage then
		return false
	end
	for _, portal in LobbyConfig.portals do
		local levels = portal.levels
		if levels then
			local after, found = LevelUnlocks.nextAfter(levels, stage)
			if found then
				return after ~= nil
					or LevelUnlocks.nextArea(LobbyConfig.portals, Balance.Stages, stage) ~= nil
			end
		end
	end
	return true
end

--[[ What the main button says. Victory's goes on to the next level, except
     where it is won into the lobby (`goesOn`): that one says so. ]]
function EndScreenRules.buttonWords(won: boolean, stage: number): string
	if not won then
		return EndScreenTheme.defeat.buttonText
	end
	if not EndScreenRules.goesOn(stage) then
		return EndScreenTheme.victory.lobbyText
	end
	return EndScreenTheme.victory.buttonText
end

--[[ The words on the end screen's tab: TUTORIAL, or the level as the
     portal's screen names it (`UI/PortalScreen`): a level's own number
     ("LEVEL 1-3"), else its place on its portal ("LEVEL 1"). A stage on no
     portal (the sandbox's) keeps its index. Before 2026-11-13 a stage with
     no number of its own showed its index, so the Drowned Village's one
     level said "LEVEL 18" (the polish playthrough). ]]
function EndScreenRules.levelTab(stage: number): string
	if stage == Balance.tutorialStage then
		return "TUTORIAL"
	end
	local config = Balance.Stages[stage]
	if config and config.mode == "Endless" then
		return "ENDLESS"
	end
	if config and config.level then
		return `LEVEL {config.level}`
	end
	for _, portal in LobbyConfig.portals do
		local at = if portal.levels then table.find(portal.levels, stage) else nil
		if at then
			return `LEVEL {at}`
		end
	end
	return `LEVEL {stage}`
end

--[[ An Endless run as its end screen is told it (`Run/RoomController`):
     the floor it ended on, the best floor (this run's cleared floors
     counted), whether this run made that best, and the Soulstones banked. ]]
export type Endless = { floor: number, best: number, newBest: boolean, soulstones: number }

--[[ The third row's label on an Endless DEFEAT, where the campaign's says
     PROGRESS: the floor reached, with the best beside it. ]]
function EndScreenRules.floorLabel(endless: Endless): string
	if endless.newBest then
		return "FLOOR REACHED (NEW BEST!)"
	elseif endless.best > 0 then
		return `FLOOR REACHED (BEST {endless.best})`
	end
	return "FLOOR REACHED"
end

--[[ DEFEAT's one line under the title. An Endless run says what it kept,
     or the floor whose boss pays the first Soulstones; a campaign run says
     how to come back stronger, which with every pet slot full is merging,
     not one more hatch. ]]
function EndScreenRules.defeatLine(endless: Endless?, petsFull: boolean?): string
	local look = EndScreenTheme.defeat
	if endless then
		if endless.soulstones > 0 then
			return `YOU KEPT {endless.soulstones} SOULSTONES`
		end
		local every = Balance.Endless.bossEvery
		local boss = math.max(1, math.ceil(endless.floor / every)) * every
		return `BEAT FLOOR {boss} FOR SOULSTONES`
	end
	return if petsFull then look.fullText else look.subText
end

return EndScreenRules
