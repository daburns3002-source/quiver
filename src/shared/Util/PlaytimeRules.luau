--!strict
--[[
	Playtime gifts (`Config/Rewards.playtime`; owner, 2026-11-18): six gifts
	that open 5, 10, 20, 30, 45 and 60 minutes into a session, each bigger
	than the last. Pure, so the server decides with it (`Data/Playtime`,
	`Data/Rewards`' claims) and the lobby button and REWARDS > GIFTS draw
	with the same answers; `tests/Playtime.spec` pins it.

	**The server's clock decides.** `now` is the server's `os.time()` when
	it judges, and the client draws with `Workspace:GetServerTimeNow()`.
	Nothing a client says moves the clock.

	**A session crosses servers.** Every run is played on a server of its
	own (`Run/Party`), so a clock kept in one server's memory would start
	again at every level. The clock is saved (`SaveSchema.playtime`): when
	the session began, when a server last held the player, and which gifts
	are claimed. A server that loads the player goes on with the session if
	they were held within `gap` seconds, and starts a new one otherwise.
]]

local Rewards = require(script.Parent.Parent.Config.Rewards)

local PlaytimeRules = {}

export type Prize = Rewards.Prize

--[[ What the save keeps (`os.time()` seconds; 0 for never). ]]
export type Clock = { start: number, seen: number, claimed: number }

export type State = "claimed" | "ready" | "waiting"

local GIFTS = Rewards.playtime.gifts
local ALL = 2 ^ #GIFTS - 1

local function whole(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return 0
	end
	return math.max(0, math.floor(value))
end

--[[ How many gifts a session has. ]]
PlaytimeRules.COUNT = #GIFTS

--[[ A stored clock read back, whatever was stored. ]]
function PlaytimeRules.read(value: unknown): Clock
	local stored: { [any]: any } = if type(value) == "table" then value :: any else {}
	return {
		start = whole(stored.start),
		seen = whole(stored.seen),
		claimed = bit32.band(whole(stored.claimed), ALL),
	}
end

--[[ A server takes the player at `now`: the session goes on if a server
     held them within `gap` seconds, or a new one starts with every gift
     shut. Returns whether a new session began. ]]
function PlaytimeRules.join(clock: Clock, now: number): boolean
	local away = now - clock.seen
	if clock.start <= 0 or clock.start > now or away < 0 or away > Rewards.playtime.gap then
		clock.start, clock.seen, clock.claimed = now, now, 0
		return true
	end
	clock.seen = now
	return false
end

--[[ The server still holds the player at `now`. ]]
function PlaytimeRules.stamp(clock: Clock, now: number)
	clock.seen = math.max(clock.seen, now)
end

--[[ Seconds played this session. ]]
function PlaytimeRules.played(clock: Clock, now: number): number
	if clock.start <= 0 then
		return 0
	end
	return math.max(0, now - clock.start)
end

--[[ Seconds into a session gift `index` opens. ]]
function PlaytimeRules.opensAt(index: number): number
	return GIFTS[index].minutes * 60
end

--[[ What gift `index` holds. ]]
function PlaytimeRules.prize(index: number): Prize
	return GIFTS[index].prize
end

function PlaytimeRules.isClaimed(clock: Clock, index: number): boolean
	return bit32.btest(clock.claimed, 2 ^ (index - 1))
end

function PlaytimeRules.state(clock: Clock, now: number, index: number): State
	if PlaytimeRules.isClaimed(clock, index) then
		return "claimed"
	end
	return if PlaytimeRules.played(clock, now) >= PlaytimeRules.opensAt(index)
		then "ready"
		else "waiting"
end

--[[ How many gifts wait to be claimed. ]]
function PlaytimeRules.ready(clock: Clock, now: number): number
	local n = 0
	for index = 1, #GIFTS do
		if PlaytimeRules.state(clock, now, index) == "ready" then
			n += 1
		end
	end
	return n
end

--[[ The next gift still to open, and the seconds until it does; nil once
     every gift has opened (claimed or not). ]]
function PlaytimeRules.upcoming(clock: Clock, now: number): (number?, number)
	local played = PlaytimeRules.played(clock, now)
	for index = 1, #GIFTS do
		if PlaytimeRules.state(clock, now, index) == "waiting" then
			return index, PlaytimeRules.opensAt(index) - played
		end
	end
	return nil, 0
end

--[[ Share of the way from the gift before (or the session's start) to
     gift `index`, 0 to 1: the lobby button's ring. ]]
function PlaytimeRules.progress(clock: Clock, now: number, index: number): number
	local from = if index > 1 then PlaytimeRules.opensAt(index - 1) else 0
	local to = PlaytimeRules.opensAt(index)
	return math.clamp((PlaytimeRules.played(clock, now) - from) / (to - from), 0, 1)
end

--[[ Whether every gift of the session is claimed. ]]
function PlaytimeRules.finished(clock: Clock): boolean
	return clock.claimed == ALL
end

--[[ Claims gift `index` (any value a client sent), or the first that waits
     when `index` is nil: marked claimed and its prize returned for the
     server to pay. Nil when it is not ready. ]]
function PlaytimeRules.claim(clock: Clock, now: number, index: unknown): Prize?
	local pick: number? = nil
	if index == nil then
		for i = 1, #GIFTS do
			if PlaytimeRules.state(clock, now, i) == "ready" then
				pick = i
				break
			end
		end
	elseif type(index) == "number" and GIFTS[index] then
		pick = index
	end
	if not pick or PlaytimeRules.state(clock, now, pick) ~= "ready" then
		return nil
	end
	clock.claimed = bit32.bor(clock.claimed, 2 ^ (pick - 1))
	return GIFTS[pick].prize
end

--[[ Every gift that waits, marked claimed: their prizes. ]]
function PlaytimeRules.claimAll(clock: Clock, now: number): { Prize }
	local out = {}
	while true do
		local prize = PlaytimeRules.claim(clock, now, nil)
		if not prize then
			return out
		end
		table.insert(out, prize)
	end
end

--[[ Seconds as the button says them: "4:05", and "12:00". ]]
function PlaytimeRules.clockText(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return PlaytimeRules
