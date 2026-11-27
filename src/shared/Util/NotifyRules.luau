--!strict
--[[
	The rules of the experience notifications (`Config/Notifications`,
	`docs/NOTIFICATIONS.md`): when the game asks a player to opt in, and
	what it sends them while they are away, when. Pure, so `Data/Notify`
	and `Data/NotifyQueue` decide with it and `tests/NotifyRules.spec`
	pins it. Times are Unix seconds (UTC), days whole UTC days since 1970
	(`RewardRules.day`).

	**Asking** happens just after a daily reward is claimed, never in the
	player's first session, and never nags: NOT NOW waits `retryDays` and
	only `maxAsks` are allowed; YES is never asked again.

	**Sending** is a plan made as the player leaves (`plan`): at most one
	message per `gap`, none in the first `quiet` after leaving, at most
	`perAbsence`, none past `giveUp`, each moved into the player's own
	evening. When several could go in the same slot the lowest `rank`
	goes first. `step` moves the plan on after each send.
]]

local Notifications = require(script.Parent.Parent.Config.Notifications)

local NotifyRules = {}

local HOUR = 3600
local DAY = 86400
local MAX_ZONE = 14 * 60

--[[ What the save keeps (`SaveSchema` version 25): the sessions begun,
     the day of the last answer (0 never asked), the NOT NOWs, the last
     answer ("" none, "yes", "no", "cannot": Roblox could not ask), and the
     device's offset from UTC in minutes, reported with the answer. ]]
export type State = {
	joins: number,
	asked: number,
	noes: number,
	answer: string,
	zone: number,
}

--[[ One message planned: its kind, when, and the moment after which it
     is no longer true (an event that has ended). ]]
export type Item = { kind: string, at: number, untilAt: number? }

--[[ A player's plan while they are away, as the queue keeps it: who,
     when they left, their offset, how many have been sent and when the
     last went, the tries of the next one, and what is still to send. ]]
export type Entry = {
	user: number,
	left: number,
	zone: number,
	sent: number,
	last: number,
	tries: number,
	items: { Item },
}

--[[ What `plan` is told about the player as they leave. `dailyAt` is
     when the next daily reward can be claimed; `upcoming` the events,
     seasons and set rotations known to begin, by kind. ]]
export type Leaving = {
	user: number,
	now: number,
	zone: number,
	dailyAt: number?,
	giftFull: boolean,
	upcoming: { [string]: { at: number, untilAt: number? } },
}

local ANSWERS = { yes = true, no = true, cannot = true }

local function whole(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return 0
	end
	return math.max(0, math.floor(value))
end

--[[ A device's offset from UTC in minutes, as a whole number Roblox's
     zones can have; anything else is 0. ]]
function NotifyRules.zone(value: unknown): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value + 0.5), -MAX_ZONE, MAX_ZONE)
end

function NotifyRules.default(): State
	return { joins = 0, asked = 0, noes = 0, answer = "", zone = 0 }
end

--[[ A saved state read back, whatever was stored. ]]
function NotifyRules.read(value: unknown): State
	local stored: { [any]: any } = if type(value) == "table" then value :: any else {}
	local answer = stored.answer
	return {
		joins = whole(stored.joins),
		asked = whole(stored.asked),
		noes = math.min(whole(stored.noes), Notifications.maxAsks),
		answer = if type(answer) == "string" and ANSWERS[answer] then answer else "",
		zone = NotifyRules.zone(stored.zone),
	}
end

--[[ A session began (the profile loaded). ]]
function NotifyRules.joined(state: State)
	state.joins = math.min(state.joins + 1, 1e6)
end

--[[ Whether this player may be sent anything: they said YES. Roblox
     itself delivers only to players who also accepted its own opt-in. ]]
function NotifyRules.optedIn(state: State): boolean
	return state.answer == "yes"
end

--[[ Whether to ask now, `today` being the day a daily reward was just
     claimed. ]]
function NotifyRules.shouldAsk(state: State, today: number): boolean
	if not Notifications.ask or state.joins < Notifications.joins then
		return false
	end
	if state.answer == "yes" then
		return false
	elseif state.answer == "no" then
		return state.noes < Notifications.maxAsks and today >= state.asked + Notifications.retryDays
	elseif state.answer == "cannot" then
		return today >= state.asked + Notifications.cannotDays
	end
	return true
end

--[[ The player answered on `today`. Returns whether it was an answer. ]]
function NotifyRules.answer(state: State, answer: unknown, today: number, zone: unknown): boolean
	if type(answer) ~= "string" or not ANSWERS[answer] then
		return false
	end
	state.answer = answer
	state.asked = today
	if answer == "no" then
		state.noes = math.min(state.noes + 1, Notifications.maxAsks)
	end
	if type(zone) == "number" then
		state.zone = NotifyRules.zone(zone)
	end
	return true
end

--[[ The first moment at or after `at` that is in the evening window at
     the offset `zone` (minutes). ]]
function NotifyRules.evening(at: number, zone: number): number
	local hour = ((at + zone * 60) % DAY) / HOUR
	if hour >= Notifications.fromHour and hour < Notifications.toHour then
		return at
	elseif hour < Notifications.fromHour then
		return at + (Notifications.fromHour - hour) * HOUR
	end
	return at + (24 - hour + Notifications.fromHour) * HOUR
end

local function rank(kind: string): number
	local entry = Notifications.kinds[kind]
	return if entry then entry.rank else math.huge
end

--[[ The items still to send, each given its slot: lowest slot first, the
     lowest rank on a tie, every slot `gap` after the one before, and what
     cannot be sent in time dropped. ]]
local function arrange(entry: Entry): { Item }
	local left = {}
	for _, item in entry.items do
		table.insert(left, item)
	end
	local out = {}
	local last = entry.last
	local room = Notifications.perAbsence - entry.sent
	local earliest = entry.left + Notifications.quiet
	local latest = entry.left + Notifications.giveUp
	while #left > 0 and #out < room do
		local best, bestAt = nil :: number?, math.huge
		local i = 1
		while i <= #left do
			local item = left[i]
			local at = math.max(item.at, earliest)
			if last > 0 then
				at = math.max(at, last + Notifications.gap)
			end
			at = NotifyRules.evening(at, entry.zone)
			local untilAt = item.untilAt
			if at > latest or (untilAt ~= nil and at >= untilAt) then
				-- it can never go: gone for good
				table.remove(left, i)
			else
				if
					at < bestAt
					or (at == bestAt and best and rank(item.kind) < rank(left[best].kind))
				then
					best, bestAt = i, at
				end
				i += 1
			end
		end
		if not best then
			break
		end
		local chosen = table.remove(left, best) :: Item
		table.insert(out, { kind = chosen.kind, at = bestAt, untilAt = chosen.untilAt })
		last = bestAt
	end
	return out
end

--[[ The plan for a player who is leaving, nil when there is nothing to
     send. Only a kind `Config/Notifications` knows is planned; one with no
     message yet is dropped when its turn comes (`Data/NotifySender`), and
     whether anything is sent at all is the owner's switch (`send`). ]]
function NotifyRules.plan(leaving: Leaving): Entry?
	local items: { Item } = {}
	local function add(kind: string, at: number, untilAt: number?)
		if Notifications.kinds[kind] then
			table.insert(items, { kind = kind, at = at, untilAt = untilAt })
		end
	end
	local dailyAt = leaving.dailyAt
	if dailyAt then
		add("daily", dailyAt)
		add("daily", dailyAt + Notifications.dailyAgain)
	end
	if leaving.giftFull then
		add("gift", leaving.now)
	end
	for kind, when in leaving.upcoming do
		-- only news: what is already on, the player has just seen
		if when.at > leaving.now and (when.untilAt == nil or when.untilAt > when.at) then
			add(kind, when.at, when.untilAt)
		end
	end
	local entry: Entry = {
		user = leaving.user,
		left = leaving.now,
		zone = NotifyRules.zone(leaving.zone),
		sent = 0,
		last = 0,
		tries = 0,
		items = items,
	}
	entry.items = arrange(entry)
	return if #entry.items > 0 then entry else nil
end

--[[ The first item was tried at `now`: "sent", "retry" (Roblox asked to
     slow down, or failed on its side) or "drop" (refused for good). The
     plan moves on and is returned, nil once nothing is left. ]]
function NotifyRules.step(entry: Entry, outcome: string, now: number): Entry?
	local first = entry.items[1]
	if not first then
		return nil
	end
	local items = table.clone(entry.items)
	local next = table.clone(entry)
	next.items = items
	if outcome == "sent" then
		table.remove(items, 1)
		next.sent += 1
		next.last = now
		next.tries = 0
	elseif outcome == "retry" and entry.tries < Notifications.retries then
		next.tries += 1
		items[1] = {
			kind = first.kind,
			at = now + Notifications.retry * 2 ^ (next.tries - 1),
			untilAt = first.untilAt,
		}
	else
		table.remove(items, 1)
		next.tries = 0
	end
	next.items = arrange(next)
	return if #next.items > 0 then next else nil
end

--[[ When the next daily reward can be claimed, from the calendar's last
     paid day: at once if today's is still waiting. ]]
function NotifyRules.dailyAt(loginDay: number, today: number, now: number): number
	if loginDay < today then
		return now
	end
	return (loginDay + 1) * DAY
end

return NotifyRules
