--!strict
--[[
	How long MENU's panel may hold the run (`Remotes.RunMenu`).

	The world holds still while a player has the panel open, and that is a
	client's say-so, so it is a budget: `cap` seconds of holding at most,
	spent while held and earned back at `refill` seconds a second while not.
	A hold lasts until the panel shuts or the budget runs out, and asking
	again while holding changes nothing.

	Before this, a hold was `cap` seconds from the latest "open", so a client
	that sent "open" once a minute held everyone's run for ever (the audit,
	`docs/FIXES.md`, 2026-11-13). Now such a client holds it for a fifth of
	the time at most, and a player who opens the menu now and then never
	notices.
]]

local MenuHold = {}

export type State = {
	-- seconds of holding left, as of `at`
	budget: number,
	at: number,
	-- when the current hold ends; at or before `at` when none is running
	untilAt: number,
}

function MenuHold.new(cap: number): State
	return { budget = cap, at = 0, untilAt = 0 }
end

--[[ Brings the budget up to `now`: the held part of the time since `at`
     spends it, the rest earns it back. ]]
local function settle(state: State, now: number, cap: number, refill: number)
	local since = now - state.at
	if since <= 0 then
		return
	end
	local held = math.clamp(state.untilAt - state.at, 0, since)
	state.budget = math.clamp(state.budget - held + (since - held) * refill, 0, cap)
	state.at = now
end

--[[ The panel opened. True if the run is held for it. ]]
function MenuHold.open(state: State, now: number, cap: number, refill: number): boolean
	settle(state, now, cap, refill)
	if state.untilAt > now then
		return true
	end
	if state.budget <= 0 then
		return false
	end
	state.untilAt = now + state.budget
	return true
end

--[[ The panel shut: the hold, if any, ends now. ]]
function MenuHold.close(state: State, now: number, cap: number, refill: number)
	settle(state, now, cap, refill)
	state.untilAt = math.min(state.untilAt, now)
end

function MenuHold.holding(state: State, now: number): boolean
	return state.untilAt > now
end

return MenuHold
