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
type StageConfig = Balance.StageConfig

--[[ `Elite`: a boss-position wave in a stage that keeps its boss for the
     last (`StageConfig.elite`), fought like a boss wave, without one. ]]
export type Kind = "Fight" | "Valkyrie" | "Angel" | "Boss" | "Elite"

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

--[[ What wave `wave` of `total` is in `stage`: the schedule (`kind`), but
     the stage's `finale` makes its last wave the boss, whatever the
     schedule says (1-10's 25th would be a Valkyrie), and its `elite` makes
     its other boss-position waves elite fights. ]]
function Waves.kindIn(stage: StageConfig?, wave: number, total: number): Kind
	if stage and stage.finale and wave == total then
		return "Boss"
	end
	local kind: Kind = Waves.kind(wave)
	if kind == "Boss" and stage and stage.elite then
		return "Elite"
	end
	return kind
end

--[[ Which of `count` fights wave `wave` of `total` takes: spread evenly, the
     first wave the first, the last wave the last, never stepping back. ]]
function Waves.fightIndex(wave: number, total: number, count: number): number
	return math.clamp(math.ceil(wave / total * count), 1, count)
end

--[[ Wave `wave` of `total`, for `stage` when it brings its own fights
     (`fights`, `elite`, `finale`); without one, the rooms' and
     `Balance.Waves.bossRoster`, as before. ]]
function Waves.describe(wave: number, total: number, stage: StageConfig?): Wave
	local kind = Waves.kindIn(stage, wave, total)

	if kind == "Valkyrie" or kind == "Angel" then
		return { kind = kind :: Kind, roster = {}, count = 0 }
	end

	if kind == "Boss" then
		local finale = stage and stage.finale
		if finale then
			return { kind = kind :: Kind, roster = finale.roster, count = finale.enemyCount }
		end
		local roster = Balance.Waves.bossRoster
		return { kind = kind :: Kind, roster = roster, count = #roster }
	end

	if kind == "Elite" then
		local elite = (stage :: StageConfig).elite :: Balance.WaveFight
		return { kind = kind :: Kind, roster = elite.roster, count = elite.enemyCount }
	end

	local fights = stage and stage.fights
	if fights and #fights > 0 then
		local fight = fights[Waves.fightIndex(wave, total, #fights)]
		return { kind = kind :: Kind, roster = fight.roster, count = fight.enemyCount }
	end

	local room = Balance.Rooms[Waves.tier(wave, total)]
	return { kind = kind :: Kind, roster = room.roster, count = room.enemyCount }
end

return Waves
