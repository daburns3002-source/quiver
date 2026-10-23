--!strict
--[[
	What each wave of a Waves-mode stage is.

	Pure: a wave number in, a description out. Kept apart from the controller
	that runs the stage so the schedule — which waves are Valkyries, Angels or
	bosses, and what each fight contains — can be tested without a running
	game, the way `Loadout` is.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

type EnemyConfig = Balance.EnemyConfig

export type Kind = "Fight" | "Valkyrie" | "Angel" | "Boss"

export type Wave = {
	kind: Kind,
	--[[ Empty for a Valkyrie or an Angel, which are encounters, not fights. ]]
	roster: { EnemyConfig },
	count: number,
}

local Waves = {}

--[[ Where `wave` sits in its block of ten, as Archero 2 numbers it: 1–10,
     never 0, so wave 10 is the 10th of its block rather than the 0th. ]]
local function positionInBlock(wave: number): number
	local size = Balance.Waves.blockSize
	return (wave - 1) % size + 1
end

function Waves.kind(wave: number): Kind
	local position = positionInBlock(wave)
	local schedule = Balance.Waves

	if position == schedule.bossAt then
		return "Boss"
	elseif position == schedule.valkyrieAt then
		return "Valkyrie"
	elseif position == schedule.angelAt then
		return "Angel"
	end

	return "Fight"
end

--[[
	The room whose roster a fight wave borrows: the stage's waves spread
	evenly across the first `Balance.Waves.rooms` of the Rooms list, so wave 1 fights room one's tutorial pair
	and the last wave fights the last room.
]]
function Waves.tier(wave: number, total: number): number
	local rooms = math.min(Balance.Waves.rooms, #Balance.Rooms)
	return math.clamp(math.ceil(wave / total * rooms), 1, rooms)
end

function Waves.describe(wave: number, total: number): Wave
	local kind = Waves.kind(wave)

	if kind == "Valkyrie" or kind == "Angel" then
		return { kind = kind :: Kind, roster = {}, count = 0 }
	end

	if kind == "Boss" then
		local roster = Balance.Waves.bossRoster
		return { kind = kind :: Kind, roster = roster, count = #roster }
	end

	local room = Balance.Rooms[Waves.tier(wave, total)]
	return { kind = kind :: Kind, roster = room.roster, count = room.enemyCount }
end

return Waves
