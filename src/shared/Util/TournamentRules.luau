--!strict
--[[
	The weekly Endless tournament's rules (`Config/Tournament`,
	`docs/LEADERBOARD.md`). Pure: every rule takes the time as a number of
	Unix seconds (UTC) rather than reading a clock, so `tests/TournamentRules`
	drives a whole week, and its rollover, with a fake one.

	- **The week.** Monday 00:00 UTC to the next Monday. `week` numbers them
	  from the first Monday after 1970-01-01 (a Thursday); `scope` names one
	  by its Monday's date, which is the store's scope.
	- **The score.** One whole number, because an OrderedDataStore keeps only
	  those: the floor, times `timeSpan`, plus how much under `timeSpan`
	  tenths of a second the run took to clear it. A deeper floor always
	  wins; on the same floor, the faster run. Two runs level to the tenth
	  of a second share the better place (`place`), so a tie never costs a
	  prize.
	- **The prize.** A place's prize (top 1, 10, 100) and the floor's band,
	  added together (`prize`). A week pays once: the save keeps each week
	  still owed (`note`), and paying it takes it out (`Data/Wallet`).
]]

local BoardRank = require(script.Parent.BoardRank)
local Tournament = require(script.Parent.Parent.Config.Tournament)

local TournamentRules = {}

TournamentRules.DAY = 86400
TournamentRules.WEEK = 7 * TournamentRules.DAY
--[[ 1970-01-05 00:00 UTC, the first Monday of Unix time. ]]
TournamentRules.MONDAY = 4 * TournamentRules.DAY

export type Prize = {
	--[[ The place on the week's board, nil past the read (101st or more). ]]
	place: number?,
	--[[ The place's prize's name ("TOP 10"), nil with none. ]]
	placeName: string?,
	floor: number,
	gems: number,
	coins: number,
	soulstones: number,
	--[[ First place: a win, and the title. ]]
	champion: boolean,
	--[[ Themed set weapons to pick (`Tournament.pickGems`). ]]
	picks: number,
}

--[[ What `pickable` needs of a catalog entry (`ShopRules.Entry`). ]]
export type Item = { weapon: string, set: string?, earned: boolean? }

--[[ The week `now` falls in. ]]
function TournamentRules.week(now: number): number
	return (math.floor(now) - TournamentRules.MONDAY) // TournamentRules.WEEK
end

--[[ The Unix second week `week` starts. ]]
function TournamentRules.startOf(week: number): number
	return TournamentRules.MONDAY + week * TournamentRules.WEEK
end

--[[ Seconds from `now` to the next reset. ]]
function TournamentRules.resetsIn(now: number): number
	return TournamentRules.startOf(TournamentRules.week(now) + 1) - now
end

--[[ "RESETS IN 2D 4H", "RESETS IN 5H 12M", "RESETS IN 12M". Never "0M":
     under a minute is "1M". ]]
function TournamentRules.countdown(seconds: number): string
	local s = math.max(math.floor(seconds), 0)
	local days = s // TournamentRules.DAY
	local hours = (s % TournamentRules.DAY) // 3600
	if days >= 1 then
		return `RESETS IN {days}D {hours}H`
	end
	local minutes = (s % 3600) // 60
	if hours >= 1 then
		return `RESETS IN {hours}H {minutes}M`
	end
	return `RESETS IN {math.max(math.ceil(s / 60), 1)}M`
end

--[[ Year, month and day of the `days`th day after 1970-01-01 (Howard
     Hinnant's civil-from-days, so nothing here needs `os.date`). ]]
local function civil(days: number): (number, number, number)
	local z = days + 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local day = doy - (153 * mp + 2) // 5 + 1
	local month = if mp < 10 then mp + 3 else mp - 9
	local year = yoe + era * 400 + (if month <= 2 then 1 else 0)
	return year, month, day
end

--[[ The store's scope for week `week`: its Monday, "2026-11-16". ]]
function TournamentRules.scope(week: number): string
	local year, month, day = civil(TournamentRules.startOf(week) // TournamentRules.DAY)
	return string.format("%04d-%02d-%02d", year, month, day)
end

--[[ The score of clearing `floor` `seconds` into the run. ]]
function TournamentRules.score(floor: number, seconds: number): number
	local span = Tournament.timeSpan
	local tenths = math.clamp(math.floor(math.max(seconds, 0) * 10), 0, span - 1)
	return math.floor(floor) * span + (span - 1 - tenths)
end

function TournamentRules.floorOf(score: number): number
	return math.floor(score) // Tournament.timeSpan
end

--[[ The tenths of a second the score's run took to its floor. ]]
function TournamentRules.tenthsOf(score: number): number
	local span = Tournament.timeSpan
	return span - 1 - math.floor(score) % span
end

--[[ A run's time as the board writes it: "4:07", "1:02:30". ]]
function TournamentRules.clock(tenths: number): string
	local s = math.max(tenths, 0) // 10
	local hours = s // 3600
	local minutes = (s % 3600) // 60
	local seconds = s % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds)
	end
	return string.format("%d:%02d", minutes, seconds)
end

--[[ Whether a stored value is a score at all: a whole number with a
     floor of at least 1. ]]
function TournamentRules.valid(score: unknown): boolean
	return type(score) == "number"
		and score == math.floor(score)
		and TournamentRules.floorOf(score) >= 1
end

--[[ The place `score` takes in `list`: one more than the scores strictly
     above it, so a tie shares the better place. ]]
function TournamentRules.place(list: { BoardRank.Scored }, score: number): number
	local above = 0
	for _, entry in list do
		if entry.score > score then
			above += 1
		end
	end
	return above + 1
end

--[[
	Where `userId` finished a week that is over. `read` is the store's top
	`depth` for that week, best first; `known` is what this server holds of
	it (its own players' bests, perhaps not yet written); `saved` is the
	player's own best as their save has it. Returns the place (nil past a
	full read) and the score it is for (0 if they have none).
]]
function TournamentRules.final(
	read: { BoardRank.Scored },
	depth: number,
	known: { [number]: number },
	userId: number,
	saved: number
): (number?, number)
	local best: { [number]: number } = {}
	for _, entry in read do
		best[entry.userId] = math.max(best[entry.userId] or 0, entry.score)
	end
	for id, score in known do
		best[id] = math.max(best[id] or 0, score)
	end
	local own = math.max(best[userId] or 0, saved)
	if own <= 0 then
		return nil, 0
	end
	local cutoff = BoardRank.cutoff(read, depth)
	if cutoff and own < cutoff then
		return nil, own
	end
	local others: { BoardRank.Scored } = {}
	for id, score in best do
		if id ~= userId then
			table.insert(others, { userId = id, score = score })
		end
	end
	return TournamentRules.place(others, own), own
end

--[[ What a week pays for finishing at `place` (nil: past the top 100)
     with `floor` as the deepest. Nothing for a week not played. ]]
function TournamentRules.prize(place: number?, floor: number): Prize
	local out: Prize = {
		place = place,
		placeName = nil,
		floor = floor,
		gems = 0,
		coins = 0,
		soulstones = 0,
		champion = false,
		picks = 0,
	}
	if floor < 1 then
		out.place = nil
		return out
	end
	if place then
		for _, entry in Tournament.places do
			if place <= entry.upTo then
				out.placeName = entry.name
				out.gems += entry.gems
				out.soulstones += entry.soulstones
				out.champion = entry.champion
				out.picks = entry.picks
				break
			end
		end
	end
	local band: Tournament.Band? = nil
	for _, entry in Tournament.bands do
		if floor >= entry.from and (band == nil or entry.from > band.from) then
			band = entry
		end
	end
	if band then
		out.gems += band.gems
		out.coins += band.coins
		out.soulstones += band.soulstones
	end
	return out
end

--[[ Records `score` for `week` in a save's still-owed weeks if it beats
     what is there; returns whether it did. Past `Tournament.keep` weeks
     the oldest is dropped, so a save never grows without bound. ]]
function TournamentRules.note(weeks: { [string]: number }, week: number, score: number): boolean
	local key = tostring(week)
	if not TournamentRules.valid(score) or score <= (weeks[key] or 0) then
		return false
	end
	weeks[key] = score
	while true do
		local count, oldest, oldestKey = 0, math.huge, nil :: string?
		for stored in weeks do
			count += 1
			-- a key that is not a week number goes first
			local number = tonumber(stored) or -math.huge
			if number < oldest or oldestKey == nil then
				oldest, oldestKey = number, stored
			end
		end
		if count <= Tournament.keep or oldestKey == nil then
			break
		end
		weeks[oldestKey] = nil
	end
	return true
end

--[[ The weeks in `weeks` that are over and past their grace at `now`,
     oldest first: the ones to pay. ]]
function TournamentRules.due(weeks: { [string]: number }, now: number): { number }
	local out: { number } = {}
	for key in weeks do
		local week = tonumber(key)
		if week and now >= TournamentRules.startOf(week + 1) + Tournament.grace then
			table.insert(out, week)
		end
	end
	table.sort(out)
	return out
end

--[[ The weapons a pick may take: the themed sets' (`set`) in `catalog`
     (`ShopRules.catalog`: every stocked set, on sale this week or not) that
     `owned` does not hold, in the catalog's order. Never an earned one
     (`WeaponStats.earned`: the Nebula Blade, the Petalfall Blade, the
     Wishcutter Blade): those are Endless room 100's and the season pass's
     to give (owner, 2026-11-19, "yes, close it"). ]]
function TournamentRules.pickable(catalog: { Item }, owned: { [string]: boolean }): { string }
	local out: { string } = {}
	for _, entry in catalog do
		if entry.set ~= nil and not entry.earned and not owned[entry.weapon] then
			table.insert(out, entry.weapon)
		end
	end
	return out
end

--[[ `picks` owed with `left` weapons still to pick from: how many stay
     picks, and the gems paid for the rest (`Tournament.pickGems` each). ]]
function TournamentRules.settlePicks(picks: number, left: number): (number, number)
	local keep = math.clamp(math.floor(picks), 0, math.max(math.floor(left), 0))
	return keep, (math.max(math.floor(picks), 0) - keep) * Tournament.pickGems
end

--[[ The name tag's title for `wins` wins, nil for none. ]]
function TournamentRules.title(wins: number): string?
	if wins < 1 then
		return nil
	elseif wins == 1 then
		return Tournament.title
	end
	return `{Tournament.title} x{wins}`
end

return TournamentRules
