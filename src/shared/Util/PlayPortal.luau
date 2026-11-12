--!strict
--[[
	Which portal the lobby's PLAY button goes to (Fable's loop review item 3,
	owner-approved 2026-11-11): the player's frontier, the first portal in
	the arches' order that is open to them and still has an open level they
	have not beaten; with every one beaten, the last they have played. A new
	player goes to Mossy Glade, someone who has beaten 1-10 to Thornwood.
	Portals with no levels, and any holding `except` (Endless, a mode and
	not a step of the campaign), are passed over.

	The server decides with it (`Remotes.LobbyPlay` walks the player to that
	portal's mouth, where its screen opens as any portal's does). Pure, so
	`tests/PlayPortal.spec` pins it with made-up stages and portals.
]]

local LevelUnlocks = require(script.Parent.LevelUnlocks)
local LobbyConfig = require(script.Parent.Parent.Config.Lobby)

local PlayPortal = {}

-- for its type only: nothing here reads the game's own portals
export type Portal = LobbyConfig.Portal

local function holds(levels: { number }, stage: number?): boolean
	return stage ~= nil and table.find(levels, stage) ~= nil
end

function PlayPortal.pick(
	portals: { Portal },
	stages: { [number]: LevelUnlocks.Stage },
	beaten: LevelUnlocks.Beaten?,
	except: number?
): number?
	local first, played = nil, nil
	for index, portal in portals do
		local levels = portal.levels
		if
			levels
			and not holds(levels, except)
			and LevelUnlocks.portalOpen(portal.requires, beaten)
		then
			first = first or index
			--[[ The first unbeaten level of a portal is always open (the
			     first always is, every other once the one before is
			     beaten), so a portal with any is the frontier. ]]
			for _, stage in levels do
				if LevelUnlocks.isBeaten(stages[stage], beaten) then
					played = index
				else
					return index
				end
			end
		end
	end
	return played or first
end

return table.freeze(PlayPortal)
