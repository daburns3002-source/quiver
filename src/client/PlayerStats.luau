--!strict
--[[
	The handful of stats the client has to know in order to predict correctly.

	Not "the player's stats". Health, damage and everything else that decides
	an outcome stays on the server and is never mirrored here, because a
	mirror is a thing that can disagree. These two are different: the client
	pins `WalkSpeed` every frame and runs the dash cooldown locally, so if it
	did not know about Agility and Lightfoot it would spend every frame
	undoing them.

	Starts at the configured defaults rather than at zero, so a client that
	has not yet heard from the server moves at the right speed instead of
	standing still.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

export type Stats = {
	moveSpeed: number,
	dashCooldown: number,
}

local PlayerStats = {}

local current: Stats = {
	moveSpeed = Balance.Player.moveSpeed,
	dashCooldown = Balance.Player.dash.cooldown,
}

function PlayerStats.get(): Stats
	return current
end

--[[ Replaces the whole block rather than merging. The server computes these
     together from one loadout, so accepting half of an update would produce a
     combination that no loadout could actually produce. ]]
function PlayerStats.set(stats: Stats)
	if typeof(stats) ~= "table" then
		return
	end

	local moveSpeed = tonumber(stats.moveSpeed)
	local dashCooldown = tonumber(stats.dashCooldown)

	if not moveSpeed or not dashCooldown then
		return
	end

	current = {
		moveSpeed = moveSpeed,
		dashCooldown = math.max(dashCooldown, 0),
	}
end

--[[ Back to the configured defaults, for a fresh run. ]]
function PlayerStats.reset()
	current = {
		moveSpeed = Balance.Player.moveSpeed,
		dashCooldown = Balance.Player.dash.cooldown,
	}
end

return PlayerStats
