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
	attackCooldown: number,
	--[[ Momentum's extra attack speed, for predicting when the archer
	     fires. ]]
	momentumBonus: number,
	--[[ Stack counts, not stages. Stages are functions and do not replicate;
	     `AbilityEffects.stages` rebuilds the identical pipeline from these. ]]
	abilities: { [string]: number },
}

local PlayerStats = {}

local function defaults(): Stats
	return {
		moveSpeed = Balance.Player.moveSpeed,
		dashCooldown = Balance.Player.dash.cooldown,
		attackCooldown = Balance.Player.attackCooldown,
		momentumBonus = 0,
		abilities = {},
	}
end

local current: Stats = defaults()

--[[ Fired whenever the block is replaced, so the firing prediction can
     rebuild its pipeline instead of polling a table every frame. ]]
local changed = Instance.new("BindableEvent")

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
	local attackCooldown = tonumber(stats.attackCooldown)

	if not moveSpeed or not dashCooldown or not attackCooldown then
		return
	end

	current = {
		moveSpeed = moveSpeed,
		dashCooldown = math.max(dashCooldown, 0),
		attackCooldown = math.max(attackCooldown, 1 / 60),
		momentumBonus = math.max(tonumber(stats.momentumBonus) or 0, 0),
		abilities = if typeof(stats.abilities) == "table" then stats.abilities else {},
	}

	changed:Fire()
end

--[[ Subscribe to rebuilds. Returns the connection so a caller can drop it. ]]
function PlayerStats.onChanged(callback: () -> ()): RBXScriptConnection
	return changed.Event:Connect(callback)
end

--[[ Back to the configured defaults, for a fresh run. ]]
function PlayerStats.reset()
	current = defaults()
	changed:Fire()
end

return PlayerStats
