--!strict
--[[
	What the lobby's PLAY button offers (owner, 2026-11-14: "when the player
	clicks play it shouldnt just tp them instantly to the last portal they
	went to, there should be a screen where they can choose the area and
	then the level"): the areas to choose from (`areas`), which of them is
	marked as the one to play next (`pick`), and who a start from that
	screen takes along (`alone`).

	**The areas** are every portal that has levels, in the arches' order:
	the built areas, then Endless. One still locked (`Util/LaunchLocks`, as
	the portal's own screen checks) is listed shut, with the words for what
	opens it.

	**The one marked** is the player's frontier, the first area in that
	order that is open to them and still has a level they have not beaten;
	with every one beaten, the last they have played. A new player's is
	Mossy Glade, someone who has beaten 1-10 gets Thornwood. Portals holding
	`except` (Endless, a mode and not a step of the campaign) and any still
	locked are passed over.

	Nothing here starts a run. The screens draw what this says
	(`UI/AreaScreen`, then the area's own `UI/PortalScreen`), and the server
	checks the area and level asked for again (`Run/Lobby.levelOpen`,
	`Remotes.PortalStart`). Pure, so `tests/PlayPortal.spec` pins it with
	made-up stages and portals.
]]

local LaunchLocks = require(script.Parent.LaunchLocks)
local LevelUnlocks = require(script.Parent.LevelUnlocks)
local LobbyConfig = require(script.Parent.Parent.Config.Lobby)

local PlayPortal = {}

-- for its type only: nothing here reads the game's own portals
export type Portal = LobbyConfig.Portal

--[[ One area on PLAY's screen. ]]
export type Area = {
	--[[ Its place in the portals given, which is what a start asks for. ]]
	index: number,
	name: string,
	--[[ Whether the player may go on to its levels, and if not, what opens
	     it ("BEAT 1-10"; "" for an open one). ]]
	open: boolean,
	words: string,
	--[[ How many levels it has and how many are behind the player. ]]
	levels: number,
	beaten: number,
	--[[ A mode rather than a step of the campaign (Endless): it has no
	     levels to count. ]]
	mode: boolean,
	--[[ The one marked as next to play (`pick`). ]]
	suggested: boolean,
}

local function holds(levels: { number }, stage: number?): boolean
	return stage ~= nil and table.find(levels, stage) ~= nil
end

--[[ Whether a stage is behind the player: its level saved as beaten, or,
     for an area's single stage that saves no level, that area's boss
     beaten. ]]
local function done(
	stage: LevelUnlocks.Stage?,
	beaten: LevelUnlocks.Beaten?,
	bosses: { [string]: boolean }?
): boolean
	if LevelUnlocks.isBeaten(stage, beaten) then
		return true
	end
	if not stage or stage.level ~= nil or not bosses then
		return false
	end
	local area = stage.area
	return area ~= nil and bosses[area] == true
end

local function open(
	portal: Portal,
	beaten: LevelUnlocks.Beaten?,
	bosses: { [string]: boolean }?,
	locks: boolean?
): boolean
	return LevelUnlocks.portalOpen(portal.requires, beaten)
		and LaunchLocks.portalOpen(portal, beaten, bosses, locks)
end

function PlayPortal.pick(
	portals: { Portal },
	stages: { [number]: LevelUnlocks.Stage },
	beaten: LevelUnlocks.Beaten?,
	bosses: { [string]: boolean }?,
	except: number?,
	locks: boolean?
): number?
	local first, played = nil, nil
	for index, portal in portals do
		local levels = portal.levels
		if levels and not holds(levels, except) and open(portal, beaten, bosses, locks) then
			first = first or index
			--[[ The first unbeaten level of a portal is always open (the
			     first always is, every other once the one before is
			     beaten), so a portal with any is the frontier. ]]
			for _, stage in levels do
				if done(stages[stage], beaten, bosses) then
					played = index
				else
					return index
				end
			end
		end
	end
	return played or first
end

--[[ The areas PLAY's screen lists, in the portals' order. `except` is the
     stage that makes a portal a mode (Endless), as in `pick`. ]]
function PlayPortal.areas(
	portals: { Portal },
	stages: { [number]: LevelUnlocks.Stage },
	beaten: LevelUnlocks.Beaten?,
	bosses: { [string]: boolean }?,
	except: number?,
	locks: boolean?
): { Area }
	local suggested = PlayPortal.pick(portals, stages, beaten, bosses, except, locks)
	local list: { Area } = {}
	for index, portal in portals do
		local levels = portal.levels
		if levels then
			local isOpen = open(portal, beaten, bosses, locks)
			local behind = 0
			for _, stage in levels do
				if done(stages[stage], beaten, bosses) then
					behind += 1
				end
			end
			table.insert(list, {
				index = index,
				name = portal.name or "",
				open = isOpen,
				words = if isOpen then "" else LaunchLocks.portalWords(portal, locks),
				levels = #levels,
				beaten = behind,
				mode = holds(levels, except),
				suggested = index == suggested,
			})
		end
	end
	return list
end

--[[ The area listed for portal `index`, if PLAY's screen may go on to its
     levels: one of `areas`, and open. A shut or unknown one is refused. ]]
function PlayPortal.enter(areas: { Area }, index: number): Area?
	for _, area in areas do
		if area.index == index then
			return if area.open then area else nil
		end
	end
	return nil
end

export type Next = {
	--[[ The portal and the level's place in it: what a start asks for. ]]
	index: number,
	level: number,
	--[[ The level as it is printed ("1-2"), "" for one with no name. ]]
	words: string,
}

--[[ The level PLAY's screen offers in one press (CONTINUE): in the area
     marked next to play, the level its own screen would pick first. Nil
     when no campaign area is open, so never a mode (Endless). ]]
function PlayPortal.next(
	areas: { Area },
	portals: { Portal },
	stages: { [number]: LevelUnlocks.Stage },
	beaten: LevelUnlocks.Beaten?
): Next?
	for _, area in areas do
		local levels = portals[area.index] and portals[area.index].levels
		if area.suggested and area.open and not area.mode and levels then
			local level = LevelUnlocks.suggested(levels, stages, beaten)
			local stage = stages[levels[level]]
			return {
				index = area.index,
				level = level,
				words = if stage and stage.level then stage.level else "",
			}
		end
	end
	return nil
end

--[[ Whether a start of portal `index` takes nobody from the portal's mouth.
     A player who stands in that mouth (`standing`, the portal they stand
     at, if any) starts it with whoever stands there too, as ever
     (`Run/Party`); one who started it from PLAY's screen, anywhere else in
     the lobby, takes nobody from it, so nobody waiting at a portal is taken
     on a run by a stranger across the lobby. Either way a party's leader
     takes their lobby party (`Util/PartyRules.plan`). ]]
function PlayPortal.alone(standing: number?, index: number): boolean
	return standing ~= index
end

return table.freeze(PlayPortal)
