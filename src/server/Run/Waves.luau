--!strict
--[[
	What each wave of a Waves-mode stage is, and what each floor of an
	Endless run is (`docs/ENDLESS.md`).

	Pure: a wave or floor number in, a description out. Kept apart from the
	controller that runs the stage so the schedule — which waves are
	Valkyries, Angels or bosses, which floors are mini-bosses, bosses and
	drafts, and what each fight contains — can be tested without a running
	game, the way `Loadout` is.

	The two schedules share nothing but this file. `Balance.Waves`'s
	positions are the story's pacing; Endless reads `Balance.Endless` alone,
	so retuning one never moves the other.
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

--[[
	=== Endless (`docs/ENDLESS.md`, `Balance.Endless`) ===

	A floor is one wave, and the mode has no last one. Everything below is
	pure too — a floor number in, a description out — so the schedule, the
	curve, the ramp and the rotation are all pinned by `tests/Waves.spec`
	without a running game. `Run/RoomController` does nothing with a floor
	but play what these say it is.

	**Floor kind and the draft are orthogonal**, which is the whole reason
	there is no precedence table here to get wrong: `floorKind` answers what
	is fought and `floorDrafts` answers whether a card is dealt on clearing
	it, and neither reads the other. Floor 15 is a mini-boss that drafts and
	floor 30 a boss that drafts.

	A mini-boss is an `Elite` — a boss-position fight with no boss in it,
	the same word a Waves stage's `StageConfig.elite` uses — so the HUD, the
	summary and the pause all keep one vocabulary.
]]

--[[ The deepest floor there is. The run stops here so nothing overflows
     and the board stays bounded. ]]
function Waves.floorsTotal(): number
	return Balance.Endless.maxFloor
end

--[[ What is fought on `floor`: its boss every 10th, an elite ("mini-boss")
     every 5th that is not a 10th, a fight otherwise. ]]
function Waves.floorKind(floor: number): Kind
	local schedule = Balance.Endless
	if floor % schedule.bossEvery == 0 then
		return "Boss"
	elseif floor % schedule.miniBossEvery == 0 then
		return "Elite"
	end
	return "Fight"
end

--[[ Whether clearing `floor` deals a card. Independent of `floorKind`: a
     draft is never displaced by a fight and never has to be deferred. ]]
function Waves.floorDrafts(floor: number): boolean
	return floor % Balance.Endless.draftEvery == 0
end

--[[ The curve at `floor`, as multipliers on the area's own values,
     compounding from floor 1 (so floor 1 is 1 and 1). Health grows faster
     than damage on purpose — see `Balance.Endless`. ]]
function Waves.floorCurve(floor: number): { health: number, damage: number }
	local schedule = Balance.Endless
	local steps = floor - 1
	return {
		health = schedule.health ^ steps,
		damage = schedule.damage ^ steps,
	}
end

--[[ Which block of ten `floor` is in, counting from 1: floors 1-10 are
     block 1, 11-20 block 2. A boss floor closes its own block. ]]
function Waves.floorBlock(floor: number): number
	return math.ceil(floor / Balance.Endless.bossEvery)
end

--[[ Which `Balance.Endless.areas` entry `floor` is fought in: ten floors
     each, then round again. ]]
function Waves.floorArea(floor: number): number
	local areas = Balance.Endless.areas
	return (Waves.floorBlock(floor) - 1) % #areas + 1
end

--[[ Which time round the rotation `floor` is, counting from 1. With two
     areas built a lap is twenty floors, so lap 2 starts at floor 21. ]]
function Waves.floorLap(floor: number): number
	local areas = Balance.Endless.areas
	return (Waves.floorBlock(floor) - 1) // #areas + 1
end

--[[
	How many of its area's boss `floor` fights: the area's `bossByLap` entry
	for this lap, its last entry for every deeper lap, and the boss fight's
	own `enemyCount` for an area that does not ramp.

	Mossy Glade ramps `{ 1, 2 }`: one King Bloblin at floor 10, two at 30,
	50, 70 and deeper (owner, 2026-10-28). By lap and not by floor, so the
	ramp still means "the second time this area comes round" when a third
	area joins the rotation and a lap stops being twenty floors.
]]
function Waves.floorBossCount(floor: number): number
	local area = Balance.Endless.areas[Waves.floorArea(floor)]
	local byLap = area.bossByLap
	if not byLap or #byLap == 0 then
		return area.boss.enemyCount
	end
	return byLap[math.min(Waves.floorLap(floor), #byLap)]
end

--[[ The modifiers in force on `floor`: one more for each lap past the
     first, drawn in order so a run is reproducible, and no more once the
     list is spent (the curve carries it from there). ]]
function Waves.floorModifiers(floor: number): { Balance.EndlessModifier }
	local all = Balance.Endless.modifiers
	local count = math.clamp(Waves.floorLap(floor) - 1, 0, #all)
	local out: { Balance.EndlessModifier } = {}
	for index = 1, count do
		table.insert(out, all[index])
	end
	return out
end

--[[ Whether modifier `key` is in force on `floor`. ]]
function Waves.floorHasModifier(floor: number, key: string): boolean
	for _, modifier in Waves.floorModifiers(floor) do
		if modifier.key == key then
			return true
		end
	end
	return false
end

--[[ How fast enemies fire on `floor`, as a multiplier on their rate (above
     1 is faster), from the modifiers in force. ]]
function Waves.floorFireRate(floor: number): number
	local rate = 1
	for _, modifier in Waves.floorModifiers(floor) do
		rate *= modifier.fireRate or 1
	end
	return rate
end

--[[ How many enemies a fight on `floor` holds, off the area's own `base`:
     one more every `countEvery` floors, at most `countBonus` more, and
     never past `countCap`. The bonus is spent by floor 30; past there the
     curve's multipliers carry the difficulty. ]]
function Waves.floorCount(base: number, floor: number): number
	local schedule = Balance.Endless
	local bonus = math.min(floor // schedule.countEvery, schedule.countBonus)
	return math.min(base + bonus, schedule.countCap)
end

--[[
	What floor `floor` of an Endless run is: its kind, its roster and how
	many. Fight floors spread their area's `fights` evenly across the ten,
	a mini-boss floor takes the area's `miniBoss` and a boss floor its
	`boss`.

	The boss floor takes no count bonus and no depth ramp, because a second
	King Bloblin is not a harder boss fight, it is a different one. The only
	thing that changes how many there are is the area's own `bossByLap`
	(`floorBossCount`), which the glade uses to put two kings on floors 30
	and deeper. The curve still applies to them, through `floorCurve`.

	The `Pairs` modifier (lap 3 on) puts a second elite in every mini-boss
	fight: its roster leads with two of its heaviest body, and the fight's
	own count rises by one so nothing else is dropped from the cycle. That
	one goes in before the ramp, so the count cap still holds — a modifier
	must never put more bodies in the arena than the budget allows.
]]
function Waves.describeFloor(floor: number): Wave
	local area = Balance.Endless.areas[Waves.floorArea(floor)]
	local kind: Kind = Waves.floorKind(floor)

	if kind == "Boss" then
		return { kind = kind, roster = area.boss.roster, count = Waves.floorBossCount(floor) }
	end

	if kind == "Elite" then
		local fight = area.miniBoss
		if not Waves.floorHasModifier(floor, "Pairs") then
			return {
				kind = kind,
				roster = fight.roster,
				count = Waves.floorCount(fight.enemyCount, floor),
			}
		end
		local roster = table.clone(fight.roster)
		table.insert(roster, 1, fight.roster[1])
		--[[ The second elite joins the fight's own count *before* the ramp,
		     so `floorCount`'s cap still holds: the cap is the arena's room
		     and the device tiers' projectile budget, and a modifier must not
		     be able to step over it. ]]
		return {
			kind = kind,
			roster = roster,
			count = Waves.floorCount(fight.enemyCount + 1, floor),
		}
	end

	--[[ Within its block of ten, so each area walks its own fights in order
	     however deep the run is. ]]
	local within = (floor - 1) % Balance.Endless.bossEvery + 1
	local fight = area.fights[Waves.fightIndex(within, Balance.Endless.bossEvery, #area.fights)]
	return { kind = kind, roster = fight.roster, count = Waves.floorCount(fight.enemyCount, floor) }
end

--[[ The milestones `floor` has reached, shallowest first: every entry of
     `Balance.Endless.milestones` at or below it. Claiming is the server's
     (`Data/Wallet.claimEndlessMilestones`), which skips the ones already
     in the profile. ]]
function Waves.floorMilestones(floor: number): { Balance.EndlessMilestone }
	local out: { Balance.EndlessMilestone } = {}
	for _, milestone in Balance.Endless.milestones do
		if milestone.floor <= floor then
			table.insert(out, milestone)
		end
	end
	return out
end

--[[ The Soulstones a boss floor pays: block `n` pays `blockPay * n`,
     growing with the depth, and nothing on a floor that is not a boss
     floor. The per-run cap is applied where it is paid (`Run/RoomController`),
     not here, because it depends on what the run has already banked. ]]
function Waves.floorPay(floor: number): number
	if Waves.floorKind(floor) ~= "Boss" then
		return 0
	end
	return Balance.Endless.blockPay * Waves.floorBlock(floor)
end

return Waves
