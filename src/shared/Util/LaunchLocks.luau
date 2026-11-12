--!strict
--[[
	What a portal or an egg waits on, with the launch switch taken into
	account (`Config/Launch.locks`).

	A portal may carry a `requires` of its own, which always holds, and an
	`atLaunch`, which holds only once the switch is on (`Config/Lobby`); an
	egg its `unlock` and its `atLaunch` likewise (`Config/Eggs`). The server
	asks here before it starts a level or sells an egg, and the screens ask
	here before they offer one, so the two can never disagree.

	Every function takes `locks` last, to say which way the switch is; left
	out, it is `Config/Launch.locks`. Pure: `tests/LaunchLocks.spec` runs
	both states without touching the config.
]]

local Eggs = require(script.Parent.Parent.Config.Eggs)
local Launch = require(script.Parent.Parent.Config.Launch)
local Lobby = require(script.Parent.Parent.Config.Lobby)

local LaunchLocks = {}

export type Gate = {
	--[[ A level that must be beaten ("1-10"). ]]
	requires: string?,
	--[[ An area whose boss must be beaten ("Thornwood"). ]]
	boss: string?,
}

local function on(locks: boolean?): boolean
	if locks == nil then
		return Launch.locks
	end
	return locks
end

--[[ What `portal` waits on. Its own `requires` wins over the launch one. ]]
function LaunchLocks.portalGate(portal: Lobby.Portal, locks: boolean?): Gate
	local late = if on(locks) then portal.atLaunch else nil
	return {
		requires = portal.requires or (if late then late.requires else nil),
		boss = if late then late.boss else nil,
	}
end

--[[ Whether `portal` is open to a player who has beaten these levels and
     these bosses, beyond its own levels' unlocking (`Util/LevelUnlocks`).
     A gated portal is shut to a player with no profile. ]]
function LaunchLocks.portalOpen(
	portal: Lobby.Portal,
	levelsBeaten: { [string]: boolean }?,
	bossesBeaten: { [string]: boolean }?,
	locks: boolean?
): boolean
	local gate = LaunchLocks.portalGate(portal, locks)
	if gate.requires and not (levelsBeaten and levelsBeaten[gate.requires] == true) then
		return false
	end
	if gate.boss and not (bossesBeaten and bossesBeaten[gate.boss] == true) then
		return false
	end
	return true
end

--[[ "DrownedVillage" as "DROWNED VILLAGE". ]]
local function spoken(key: string): string
	return string.upper((string.gsub(key, "(%l)(%u)", "%1 %2")))
end

--[[ What a shut portal says opens it: "BEAT 1-10", "BEAT THORNWOOD". ]]
function LaunchLocks.portalWords(portal: Lobby.Portal, locks: boolean?): string
	local gate = LaunchLocks.portalGate(portal, locks)
	if gate.requires then
		return `BEAT {gate.requires}`
	elseif gate.boss then
		return `BEAT {spoken(gate.boss)}`
	end
	return ""
end

--[[ The area whose boss must be beaten before `egg` can be bought, or nil
     for one that is open to everybody. ]]
function LaunchLocks.eggUnlock(egg: Eggs.Egg, locks: boolean?): string?
	return egg.unlock or (if on(locks) then egg.atLaunch else nil)
end

return LaunchLocks
