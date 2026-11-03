--!strict
--[[
	The move-or-shoot rhythm, kept by both sides: the server's
	(`RunSession.isStationary`, `Combat/FiringSystem`) and the client's
	prediction (`Combat/LocalFiring`). One rule in one place, so the two keep
	time with each other.

	A rhythm is when the player last stood still (`stationarySince`, nil
	while moving), when they started moving (`movingSince`), how long the
	last move lasted (`movedFor`, for Momentum) and when they last attacked
	(`lastFiredAt`). All times are `os.clock()`.

	`resume` starts it over after the world has stood still — a card screen,
	a boss's banner, a NEW ENEMY! screen. The clock kept going behind the
	screen, so without it the server's first frame back found a long settle
	and an expired cooldown and fired at once, while the client, which starts
	over on resume, had not yet drawn the shot or played its attack: the hit
	landed before its animation (owner, 2026-10-26).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local FireRhythm = {}

export type State = {
	stationarySince: number?,
	movingSince: number?,
	movedFor: number,
	lastFiredAt: number,
}

--[[ Counts the player moving or standing this frame. Returns whether they
     have stood long enough to shoot. Call it every frame, before any
     cooldown check: it is what advances the settle timer. ]]
function FireRhythm.settle(state: State, moving: boolean, now: number): boolean
	if moving then
		state.stationarySince = nil
		state.movingSince = state.movingSince or now
		return false
	end

	local since = state.stationarySince
	if not since then
		state.stationarySince = now
		-- how long the stretch of moving that just ended lasted, for Momentum
		state.movedFor = if state.movingSince then now - state.movingSince else 0
		state.movingSince = nil
		return false
	end

	return now - since >= Balance.Player.stationaryDelay
end

--[[
	Books a volley that has just gone out, `cooldown` after the last one.

	Booked at the time it was *due*, not at `now`. A volley can only go on a
	frame boundary, so it is always a little late; setting `lastFiredAt = now`
	carried that lateness into the next interval, and since the two sides keep
	this rhythm on their own clocks at their own frame rates, the error
	compounded and the cadences crept apart for as long as the player stood
	still -- 220 ms, 18 studs of arrow, after five volleys with the client at
	15 fps (2026-11-03). Whichever side was behind then applied its damage
	nowhere near its own arrow: the enemy took the hit and the arrow was
	already past it, or the spark was somewhere else entirely.

	Advancing by exactly `cooldown` keeps each volley within one frame of its
	due time however long the player stands there, so the two sides stay as
	close as their frame rates allow and no closer than that costs.
]]
function FireRhythm.fired(state: State, now: number, cooldown: number)
	local due = state.lastFiredAt + cooldown

	--[[ More than a whole interval late -- nothing asked for a volley for a
	     while (no target in range, a melee class moving through its combo) --
	     so there is no rounding left to carry and a backlog must not be
	     bankable into a burst. Start the cadence again from here. ]]
	if now - due >= cooldown then
		state.lastFiredAt = now
		return
	end

	state.lastFiredAt = due
end

--[[ The world moves again at `now`: the next attack waits a full settle and
     a full cooldown from here, as if the player had just stopped and just
     attacked, and no Momentum carries over from before the pause. ]]
function FireRhythm.resume(state: State, now: number)
	state.stationarySince = nil
	state.movingSince = nil
	state.movedFor = 0
	state.lastFiredAt = now
end

return FireRhythm
