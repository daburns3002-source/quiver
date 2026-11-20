--!strict
--[[
	The season pass's rules (`Config/Season`). Pure: the server keeps the
	season by them (`Server/Data/Season`), the SEASON tab draws by them
	(`UI/SeasonTab`), and `tests/Season.spec` pins them.

	Times are Unix seconds, always the server's (a Studio shift included,
	`Data/Season`). A season is a calendar month in UTC; the dates are
	worked out here from the seconds (days from 1970), so nothing hangs on
	the machine's time zone.

	A player's season state is saved (`SaveSchema` version 28): the month
	it belongs to, the XP, which tiers of each track are claimed (one bit a
	tier) and whether premium was bought for it. When the month moves on,
	`rollover` claims for the player everything reached and not claimed,
	and starts the state over for the new month.
]]

local Season = require(script.Parent.Parent.Config.Season)

local SeasonRules = {}

local DAY = 86400

export type Track = "free" | "premium"

export type State = {
	--[[ "YYYY-MM", the month this state belongs to; "" for none (no
	     season was running when it was last looked at). ]]
	key: string,
	xp: number,
	--[[ Tiers claimed on each track, one bit a tier (tier 1 is 1). ]]
	free: number,
	paid: number,
	premium: boolean,
}

--[[ A season running, with its dates. ]]
export type Window = {
	key: string,
	def: Season.SeasonDef,
	starts: number,
	ends: number,
}

--[[ What several tiers come to together, the trail and title by key. ]]
export type Total = {
	coins: number,
	gems: number,
	eggs: number,
	crates: number,
	trail: string?,
	title: string?,
	--[[ The season's earned weapons won (`SeasonDef.weapons`), nil for none. ]]
	weapons: { string }?,
	--[[ The set picks won (`SeasonDef.picks`), nil for none. ]]
	picks: { Pick }?,
}

--[[ A set pick won: the set's key, and the season and track that gave it
     (its reward id, `RewardPickRules.seasonId`). ]]
export type Pick = { set: string, season: number, track: Track }

local TRACKS: { Track } = { "free", "premium" }
SeasonRules.TRACKS = TRACKS

--[[ Days since 1970-01-01 of a date (Howard Hinnant's days_from_civil). ]]
local function daysFrom(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = y // 400
	local yoe = y - era * 400
	local doy = (153 * (if month > 2 then month - 3 else month + 9) + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

--[[ The year and month of a day since 1970 (civil_from_days). ]]
local function civil(days: number): (number, number)
	local z = days + 719468
	local era = z // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local month = if mp < 10 then mp + 3 else mp - 9
	return yoe + era * 400 + (if month <= 2 then 1 else 0), month
end

--[[ The month `time` falls in: its key, and the seconds it starts and
     ends at. ]]
function SeasonRules.month(time: number): (string, number, number)
	local year, month = civil(math.floor(time) // DAY)
	local nextYear, nextMonth =
		if month == 12 then year + 1 else year, if month == 12 then 1 else month + 1
	return string.format("%04d-%02d", year, month),
		daysFrom(year, month, 1) * DAY,
		daysFrom(nextYear, nextMonth, 1) * DAY
end

--[[ The season running at `time`, nil in a month with none. ]]
function SeasonRules.at(time: number): Window?
	local key, starts, ends = SeasonRules.month(time)
	local def = Season.seasons[key]
	if not def then
		return nil
	end
	return { key = key, def = def, starts = starts, ends = ends }
end

--[[ The next season to start after `time` (within two years), nil for
     none planned. ]]
function SeasonRules.upcoming(time: number): Window?
	local _, _, ends = SeasonRules.month(time)
	for _ = 1, 24 do
		local window = SeasonRules.at(ends)
		if window then
			return window
		end
		local _, _, later = SeasonRules.month(ends)
		ends = later
	end
	return nil
end

function SeasonRules.empty(key: string?): State
	return { key = key or "", xp = 0, free = 0, paid = 0, premium = false }
end

local function whole(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return 0
	end
	return math.max(0, math.floor(value))
end

--[[ The XP that fills every tier: more counts for nothing. ]]
function SeasonRules.maxXp(): number
	return #Season.tiers * Season.tierXp
end

local ALL = bit32.lshift(1, #Season.tiers) - 1

--[[ A stored state, field by field (nothing for a new player). ]]
function SeasonRules.read(raw: unknown): State
	local state = SeasonRules.empty()
	if type(raw) ~= "table" then
		return state
	end
	local data = raw :: any
	if
		type(data.key) == "string"
		and (data.key == "" or string.match(data.key, "^%d%d%d%d%-%d%d$"))
	then
		state.key = data.key
	end
	state.xp = math.min(whole(data.xp), SeasonRules.maxXp())
	state.free = bit32.band(whole(data.free), ALL)
	state.paid = bit32.band(whole(data.paid), ALL)
	state.premium = data.premium == true
	return state
end

--[[ The tier `xp` has reached, 0 to the last. ]]
function SeasonRules.tier(xp: number): number
	return math.min(#Season.tiers, xp // Season.tierXp)
end

--[[ XP into the tier being worked on, and what it needs; the last tier
     reached reads full. ]]
function SeasonRules.bar(xp: number): (number, number)
	if SeasonRules.tier(xp) >= #Season.tiers then
		return Season.tierXp, Season.tierXp
	end
	return xp % Season.tierXp, Season.tierXp
end

--[[ The season the state belongs to, if it is the one running at `time`. ]]
function SeasonRules.live(state: State, time: number): Window?
	local window = SeasonRules.at(time)
	return if window and window.key == state.key then window else nil
end

--[[ `amount` of `kind` really happened (`Config/Season.xp`): its XP, if
     the state belongs to the season running. Returns the XP added and the
     tier before and after. ]]
function SeasonRules.gain(
	state: State,
	time: number,
	kind: string,
	amount: number
): (number, number, number)
	local each = Season.xp[kind]
	local before = SeasonRules.tier(state.xp)
	local n = whole(amount)
	if not each or n == 0 or not SeasonRules.live(state, time) then
		return 0, before, before
	end
	local xp = math.min(state.xp + each * n, SeasonRules.maxXp())
	local added = xp - state.xp
	state.xp = xp
	return added, before, SeasonRules.tier(xp)
end

local function bit(tier: number): number
	return bit32.lshift(1, tier - 1)
end

local function mask(state: State, track: Track): number
	return if track == "free" then state.free else state.paid
end

function SeasonRules.prize(track: Track, tier: number): Season.Prize?
	local row = Season.tiers[tier]
	return if row then (if track == "free" then row.free else row.premium) else nil
end

function SeasonRules.claimed(state: State, track: Track, tier: number): boolean
	return bit32.band(mask(state, track), bit(tier)) ~= 0
end

--[[ Whether a tier of a track can be claimed now: a season's state, the
     tier reached and not claimed, and premium bought for the premium one. ]]
function SeasonRules.ready(state: State, track: Track, tier: number): boolean
	return Season.seasons[state.key] ~= nil
		and SeasonRules.prize(track, tier) ~= nil
		and tier >= 1
		and tier == math.floor(tier)
		and SeasonRules.tier(state.xp) >= tier
		and (track == "free" or state.premium)
		and not SeasonRules.claimed(state, track, tier)
end

--[[ Marks a tier claimed and returns what it gives; nil if it is not
     owed. One step with no yield, so a claim sent twice pays once. ]]
function SeasonRules.claim(state: State, track: unknown, tier: unknown): Season.Prize?
	if (track ~= "free" and track ~= "premium") or type(tier) ~= "number" then
		return nil
	end
	local which: Track = if track == "free" then "free" else "premium"
	if not SeasonRules.ready(state, which, tier) then
		return nil
	end
	if which == "free" then
		state.free = bit32.bor(state.free, bit(tier))
	else
		state.paid = bit32.bor(state.paid, bit(tier))
	end
	return SeasonRules.prize(which, tier)
end

--[[ Every tier of every track owed now, free first, in order. ]]
function SeasonRules.owed(state: State): { { track: Track, tier: number } }
	local out: { { track: Track, tier: number } } = {}
	for _, track: Track in TRACKS do
		for tier = 1, #Season.tiers do
			if SeasonRules.ready(state, track, tier) then
				table.insert(out, { track = track :: Track, tier = tier })
			end
		end
	end
	return out
end

function SeasonRules.zero(): Total
	return { coins = 0, gems = 0, eggs = 0, crates = 0 }
end

--[[ The earned weapon `track` gives at its weapon tier this season, nil for
     none. ]]
function SeasonRules.weapon(def: Season.SeasonDef?, track: Track): string?
	local weapons = def and def.weapons
	if not weapons then
		return nil
	end
	return if track == "free" then weapons.free else weapons.premium
end

--[[ The themed set `track` gives a pick of at its weapon tier this season,
     nil for none. ]]
function SeasonRules.pick(def: Season.SeasonDef?, track: Track): string?
	local picks = def and def.picks
	if not picks then
		return nil
	end
	return if track == "free" then picks.free else picks.premium
end

--[[ Adds a tier's prize on `track` to `total`, its trail, title and weapon
     as the season `def` names them. ]]
function SeasonRules.add(total: Total, prize: Season.Prize, def: Season.SeasonDef?, track: Track)
	total.coins += prize.coins or 0
	total.gems += prize.gems or 0
	total.eggs += prize.eggs or 0
	total.crates += prize.crates or 0
	if prize.trail and def then
		total.trail = def.trail
	end
	if prize.title and def then
		total.title = def.title
	end
	local weapon = if prize.weapon then SeasonRules.weapon(def, track) else nil
	if weapon then
		local list = total.weapons or {}
		table.insert(list, weapon)
		total.weapons = list
	end
	local pick = if prize.weapon and def then SeasonRules.pick(def, track) else nil
	if def and pick then
		local list = total.picks or {}
		table.insert(list, { set = pick, season = def.number, track = track })
		total.picks = list
	end
end

--[[ Claims everything owed, marked in one step. Returns what it comes to
     and how many tiers. ]]
function SeasonRules.claimAll(state: State): (Total, number)
	local total = SeasonRules.zero()
	local def = Season.seasons[state.key]
	local owed = SeasonRules.owed(state)
	for _, entry in owed do
		local prize = SeasonRules.claim(state, entry.track, entry.tier)
		if prize then
			SeasonRules.add(total, prize, def, entry.track)
		end
	end
	return total, #owed
end

--[[ The month has moved on from the one the state belongs to: everything
     reached and not claimed is claimed for the player (both tracks if
     premium was bought), and the state starts over for the season running
     now ("" if none). XP and premium do not carry over, except premium
     bought while no season ran, which is kept for the next one. Returns
     what was claimed and the season it was from, nil if nothing moved. ]]
function SeasonRules.rollover(state: State, time: number): (Total?, Season.SeasonDef?)
	local window = SeasonRules.at(time)
	local key = if window then window.key else ""
	if state.key == key then
		return nil, nil
	end
	local def = Season.seasons[state.key]
	local total, n = SeasonRules.claimAll(state)
	local keep = state.key == "" and state.premium
	state.key = key
	state.xp = 0
	state.free = 0
	state.paid = 0
	state.premium = keep
	return if n > 0 then total else nil, def
end

--[[ Whether premium can be bought now: a season running, the state its
     own, and premium not yet bought for it. ]]
function SeasonRules.canBuy(state: State, time: number): boolean
	return SeasonRules.live(state, time) ~= nil and not state.premium
end

--[[ "12D 4H", "3H 20M", "45M": what is left of `seconds`, as the tab's
     countdown says it. ]]
function SeasonRules.left(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local days, hours, minutes = s // DAY, (s % DAY) // 3600, (s % 3600) // 60
	if days > 0 then
		return string.format("%dD %dH", days, hours)
	elseif hours > 0 then
		return string.format("%dH %dM", hours, minutes)
	end
	return string.format("%dM", math.max(minutes, if s > 0 then 1 else 0))
end

--[[ The season whose trail is `key`, for the trail's card. ]]
function SeasonRules.ofTrail(key: string): Season.SeasonDef?
	for _, def in Season.seasons do
		if def.trail == key then
			return def
		end
	end
	return nil
end

--[[ The tier a premium thing (`trail` or `title`) is on. ]]
function SeasonRules.tierOf(what: "trail" | "title"): number?
	for tier, row in Season.tiers do
		if (row.premium :: any)[what] then
			return tier
		end
	end
	return nil
end

return SeasonRules
