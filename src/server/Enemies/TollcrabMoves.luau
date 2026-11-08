--!strict
--[[
	The Old Tollcrab's own moves (docs/BOSSES.md §3; owner, 2026-11-07:
	"give me unique moves"), run like every boss move (`BossMoves`): a
	timeline stepped once a frame that returns the pose his body takes and
	the events that happened, touching nothing itself. `EnemyManager`
	resolves the events, and asks `TollcrabMoves.touch` each step who his
	rolling rings and his scuttling body are on.

	- **Toll** (`EnemyBoss.toll`): the bell raised, then planted and rung.
	  A ring rolls out from him to `reach` through cover, with one gap lit
	  on the floor from the wind-up, set round from the player so they must
	  move to it. Enraged, a second ring follows, its gap turned back the
	  other way. The bell then sticks in the floor until the rings are done.
	- **Echo** (`EnemyBoss.echo`): raps at the player; each drops a glowing
	  ring under their feet that strikes a beat later. Enraged, a second
	  mark lands where they are heading.
	- **Scuttle** (`EnemyBoss.scuttle`): into the bell, side-on, then a
	  zigzag of short sideways dashes (owner, 2026-11-08: it was one long
	  charge, too like Grandmother Gulp's Belly Slide). Each dash has its
	  own lane marked at where the player is then, and the last ends in a
	  crash that leaves him stunned.

	Enraged is decided when a move starts (`EnemyBoss.enrageAt`), so a move
	never changes its rules halfway.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossMoves = require(script.Parent.BossMoves)

type EnemyBoss = Balance.EnemyBoss
type Move = BossMoves.Move
type Pose = BossMoves.Pose
type Event = BossMoves.Event

local TollcrabMoves = {}

export type Ring = { at: Vector3, gap: Vector3, startAt: number }
export type Mark = { at: Vector3, strikeAt: number }

--[[ What a move of his keeps beside `BossMoves.Move`. ]]
type State = {
	enraged: boolean,
	rings: { Ring },
	marks: { Mark },
	--[[ Who each ring, or each dash, has already hit: once each. ]]
	struck: { [any]: { [any]: boolean } },
	--[[ The target's last position and its smoothed velocity, for the
	     enraged mark that lands where they are heading. ]]
	seen: Vector3?,
	seenAt: number,
	velocity: Vector3,
	--[[ The scuttle's current dash: its lane. ]]
	from: Vector3,
	to: Vector3,
	along: Vector3,
	length: number,
}

local states: { [Move]: State } = setmetatable({} :: any, { __mode = "k" })

local random = Random.new()

local KINDS = { Toll = true, Echo = true, Scuttle = true }

local SHAKE_TIME = 0.3
local SHAKE_TOLL = 0.7
local SHAKE_ECHO = 0.25
local SHAKE_CRASH = 0.6
--[[ The crash's cube shock, as the chest bump's. ]]
local CRASH_SHOCK = 5
--[[ Studs between samples as the scuttle's lane is run out to a wall. ]]
local LANE_STEP = 1

function TollcrabMoves.owns(kind: string): boolean
	return KINDS[kind] == true
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function yawOf(direction: Vector3, fallback: number): number
	if direction.Magnitude < 1e-3 then
		return fallback
	end
	return math.atan2(-direction.X, -direction.Z)
end

local function lerpAngle(a: number, b: number, t: number): number
	local delta = ((b - a + math.pi) % (2 * math.pi)) - math.pi
	return a + delta * t
end

--[[ `direction` turned `degrees` round the vertical. ]]
local function turned(direction: Vector3, degrees: number): Vector3
	local r = math.rad(degrees)
	local c, s = math.cos(r), math.sin(r)
	return Vector3.new(direction.X * c - direction.Z * s, 0, direction.X * s + direction.Z * c)
end

local function event(kind: string): Event
	return {
		kind = kind,
		at = Vector3.zero,
		direction = Vector3.zAxis,
		radius = 0,
		length = 0,
		width = 0,
		duration = 0,
	}
end

local function shake(magnitude: number): Event
	local e = event("Shake")
	e.radius = magnitude
	e.duration = SHAKE_TIME
	return e
end

local function toll(boss: EnemyBoss): Balance.BossToll
	return boss.toll :: Balance.BossToll
end
local function echo(boss: EnemyBoss): Balance.BossEcho
	return boss.echo :: Balance.BossEcho
end
local function scuttle(boss: EnemyBoss): Balance.BossScuttle
	return boss.scuttle :: Balance.BossScuttle
end

--[[ Seconds a ring takes to roll out to its reach. ]]
function TollcrabMoves.ringTime(t: Balance.BossToll): number
	return t.reach / t.speed
end

--[[
	Whether a ring that began rolling `age` seconds ago, gap along `gap`,
	is on a body `pad` studs across its middle at `point`. Pure, for the
	spec: the band is where the ring is now, the gap is safe, and past
	`reach` the ring is gone. Cover does not stop it.
]]
function TollcrabMoves.ringHit(
	t: Balance.BossToll,
	centre: Vector3,
	gap: Vector3,
	age: number,
	point: Vector3,
	pad: number
): boolean
	if age < 0 or age > TollcrabMoves.ringTime(t) then
		return false
	end
	local offset = flat(point) - flat(centre)
	local distance = offset.Magnitude
	local radius = age * t.speed
	if math.abs(distance - radius) > t.band / 2 + pad then
		return false
	end
	if distance < 1e-3 then
		return true
	end
	local cosine = offset.Unit:Dot(gap.Unit)
	return cosine < math.cos(math.rad(t.gap / 2))
end

function TollcrabMoves.start(
	kind: string,
	now: number,
	feet: Vector3,
	yaw: number,
	enraged: boolean
): Move
	local move = BossMoves.start(kind :: any, now, feet, yaw)
	states[move] = {
		enraged = enraged,
		rings = {},
		marks = {},
		struck = {},
		seen = nil,
		seenAt = now,
		velocity = Vector3.zero,
		from = flat(feet),
		to = flat(feet),
		along = move.direction,
		length = 0,
	}
	return move
end

function TollcrabMoves.enraged(move: Move): boolean
	local state = states[move]
	return state ~= nil and state.enraged
end

function TollcrabMoves.rings(move: Move): { Ring }
	local state = states[move]
	return if state then state.rings else {}
end

local function duration(move: Move, boss: EnemyBoss, state: State): number
	local phase = move.phase
	if move.kind == "Toll" then
		local t = toll(boss)
		if phase == "windup" then
			return t.windup
		elseif phase == "ring" then
			return if state.enraged then t.pairDelay else 0
		elseif phase == "ring2" then
			return 0
		elseif phase == "stuck" then
			local last = state.rings[#state.rings]
			local rolling = if last
				then last.startAt + TollcrabMoves.ringTime(t) - move.phaseAt
				else 0
			return math.max(t.stuck, rolling)
		end
		return t.recover
	elseif move.kind == "Echo" then
		local e = echo(boss)
		if phase == "windup" then
			return e.windup
		elseif phase == "rap" then
			return e.every
		elseif phase == "wait" then
			return math.max(0, e.delay - e.every)
		end
		return e.recover
	end
	local s = scuttle(boss)
	if phase == "windup" then
		return s.windup
	elseif phase == "aim" then
		return s.between
	elseif phase == "charge" then
		return state.length / s.speed
	elseif phase == "crash" then
		return s.stunned
	end
	return s.recover
end

local function nextPhase(move: Move, boss: EnemyBoss, state: State): string
	local phase = move.phase
	if move.kind == "Toll" then
		if phase == "windup" then
			return "ring"
		elseif phase == "ring" then
			return if state.enraged then "ring2" else "stuck"
		elseif phase == "ring2" then
			return "stuck"
		elseif phase == "stuck" then
			return "recover"
		end
		return ""
	elseif move.kind == "Echo" then
		if phase == "windup" then
			return "rap"
		elseif phase == "rap" then
			return if move.index < echo(boss).marks then "rap" else "wait"
		elseif phase == "wait" then
			return "recover"
		end
		return ""
	end
	if phase == "windup" or phase == "aim" then
		return "charge"
	elseif phase == "charge" then
		return if move.index < scuttle(boss).dashes then "aim" else "crash"
	elseif phase == "crash" then
		return "recover"
	end
	return ""
end

local function ringEvent(
	kind: string,
	t: Balance.BossToll,
	at: Vector3,
	gap: Vector3,
	seconds: number
): Event
	local e = event(kind)
	e.at = at
	e.direction = gap
	e.radius = t.reach
	e.width = t.gap
	e.duration = seconds
	return e
end

local function markEvent(at: Vector3, e: Balance.BossEcho): Event
	local tell = event("EchoTell")
	tell.at = at
	tell.radius = e.radius
	tell.duration = e.delay
	return tell
end

--[[
	Marks the next dash from his feet for `warning` seconds: at the player
	and `overshoot` on past them, at most `range`, stopped by the first
	wall or house at the last spot his body fits.
]]
local function planDash(
	move: Move,
	s: Balance.BossScuttle,
	state: State,
	warning: number,
	target: Vector3,
	clamp: (Vector3) -> Vector3
): Event
	local toward = flat(target) - move.feet
	local along = if toward.Magnitude > 0.1 then toward.Unit else move.direction
	local wanted = math.min(toward.Magnitude + s.overshoot, s.range)
	local to = move.feet
	local d = LANE_STEP
	while d <= wanted do
		local probe = move.feet + along * d
		if (flat(clamp(probe)) - probe).Magnitude > 0.3 then
			break
		end
		to = probe
		d += LANE_STEP
	end
	state.from = move.feet
	state.to = to
	state.along = along
	state.length = (to - move.feet).Magnitude
	move.index += 1
	move.direction = along
	move.length = state.length
	move.fromYaw = move.yaw
	--[[ Side-on, whichever side is nearer: a crab never turns round to
	     run back the way it came. ]]
	local side = yawOf(along, move.yaw) + math.pi / 2
	local delta = math.abs(((side - move.yaw + math.pi) % (2 * math.pi)) - math.pi)
	move.toYaw = if delta <= math.pi / 2 then side else side + math.pi
	local lane = event("Lane")
	lane.at = move.feet
	lane.direction = along
	lane.length = math.max(state.length, 1)
	lane.width = s.width
	lane.duration = warning + state.length / s.speed
	return lane
end

local function enter(
	move: Move,
	boss: EnemyBoss,
	state: State,
	phase: string,
	at: number,
	target: Vector3,
	clamp: (Vector3) -> Vector3
): { Event }
	move.phase = phase
	move.phaseAt = at
	local events: { Event } = {}

	if move.kind == "Toll" then
		local t = toll(boss)
		if phase == "windup" then
			--[[ The gap is set round from where the player stands, so they
			     must move to it; enraged, the second ring's gap turns back
			     the other way, near where they started. ]]
			local toward = flat(target) - move.feet
			local bearing = if toward.Magnitude > 0.1 then toward.Unit else move.direction
			local side = if random:NextNumber() < 0.5 then -1 else 1
			local gap = turned(bearing, side * random:NextNumber(t.gapFrom, t.gapTo))
			move.direction = gap
			move.fromYaw = move.yaw
			move.toYaw = yawOf(bearing, move.yaw)
			table.insert(events, ringEvent("TollTell", t, move.feet, gap, t.windup))
			if state.enraged then
				local second = turned(gap, -side * t.pairTurn)
				state.rings = {
					{ at = move.feet, gap = gap, startAt = 0 },
					{ at = move.feet, gap = second, startAt = 0 },
				}
				table.insert(
					events,
					ringEvent("TollTell", t, move.feet, second, t.windup + t.pairDelay)
				)
			else
				state.rings = { { at = move.feet, gap = gap, startAt = 0 } }
			end
		elseif phase == "ring" or phase == "ring2" then
			move.yaw = move.toYaw
			local ring = state.rings[if phase == "ring" then 1 else 2]
			ring.startAt = at
			table.insert(
				events,
				ringEvent("TollRing", t, ring.at, ring.gap, TollcrabMoves.ringTime(t))
			)
			table.insert(events, shake(SHAKE_TOLL))
		end
		return events
	end

	if move.kind == "Echo" then
		local e = echo(boss)
		if phase == "windup" then
			move.fromYaw = move.yaw
			move.toYaw = yawOf(flat(target) - move.feet, move.yaw)
		elseif phase == "rap" then
			move.index += 1
			move.fromYaw = move.yaw
			move.toYaw = yawOf(flat(target) - move.feet, move.yaw)
			local spots = { flat(clamp(flat(target))) }
			if state.enraged then
				local ahead = flat(clamp(flat(target) + state.velocity * e.lead))
				--[[ Standing still, both marks would be one: the second goes
				     a step out from him instead, still where they would run. ]]
				if (ahead - spots[1]).Magnitude < e.radius then
					local away = spots[1] - move.feet
					local out = if away.Magnitude > 0.1 then away.Unit else move.direction
					ahead = flat(clamp(spots[1] + out * e.radius * 1.6))
				end
				table.insert(spots, ahead)
			end
			for _, spot in spots do
				table.insert(state.marks, { at = spot, strikeAt = at + e.delay })
				table.insert(events, markEvent(spot, e))
			end
			table.insert(events, shake(SHAKE_ECHO))
		end
		return events
	end

	local s = scuttle(boss)
	if phase == "windup" then
		table.insert(events, planDash(move, s, state, s.windup, target, clamp))
	elseif phase == "aim" then
		move.feet = state.to
		table.insert(events, planDash(move, s, state, s.between, target, clamp))
	elseif phase == "charge" then
		move.yaw = move.toYaw
	elseif phase == "crash" then
		move.feet = state.to
		local bump = event("BumpShock")
		bump.at = state.to + state.along * (s.width / 2)
		bump.direction = state.along
		bump.radius = CRASH_SHOCK
		table.insert(events, bump)
		table.insert(events, shake(SHAKE_CRASH))
	end
	return events
end

local function pose(move: Move, state: State, t: number, now: number): Pose
	local p = BossMoves.idle(move.feet, move.yaw, now)
	p.direction = move.direction
	p.length = move.length
	local phase = move.phase

	if move.kind == "Toll" then
		if phase == "windup" then
			--[[ The bell hauled up and back, trembling as it tops out. ]]
			local e = ease(t)
			p.yaw = lerpAngle(move.fromYaw, move.toYaw, math.min(1, t * 3))
			p.lift = 1.6 * e
			p.pitch = -0.22 * e
			p.squash = 1 + 0.12 * e
			p.spread = 1 - 0.05 * e
			p.twist = 0.04 * e * math.sin(now * 40)
		elseif phase == "ring" or phase == "ring2" or phase == "stuck" then
			--[[ Planted: squashed into the floor, ringing, then still. ]]
			local seconds = (now - move.phaseAt)
			local w = math.exp(-seconds * 3) * math.cos(seconds * 30)
			p.squash = 0.82 + 0.06 * w
			p.spread = 1.08 - 0.04 * w
			p.pitch = 0.08
		elseif phase == "recover" then
			local e = ease(t)
			p.squash = 0.82 + 0.18 * e
			p.spread = 1.08 - 0.08 * e
			p.pitch = 0.08 * (1 - e)
		end
		return p
	end

	if move.kind == "Echo" then
		p.yaw = lerpAngle(move.fromYaw, move.toYaw, math.min(1, t * 2))
		if phase == "windup" then
			p.pitch = -0.18 * ease(t)
			p.armsLift = 1.2 * ease(t)
		elseif phase == "rap" then
			--[[ A sharp rap forward, then back up for the next. ]]
			local hit = if t < 0.25 then t / 0.25 else 1 - (t - 0.25) / 0.75
			p.pitch = -0.18 + 0.36 * ease(math.clamp(hit, 0, 1))
			p.squash = 1 - 0.08 * hit
			p.armsLift = 1.2 * (1 - hit)
		elseif phase == "recover" then
			p.pitch = 0
		end
		return p
	end

	if phase == "windup" then
		--[[ Down into the bell, turning side-on, legs drumming. ]]
		local e = ease(t)
		p.yaw = lerpAngle(move.fromYaw, move.toYaw, math.min(1, t * 2.5))
		p.squash = 1 - 0.22 * e
		p.spread = 1 + 0.06 * e
		p.twist = 0.05 * e * math.sin(now * 35)
	elseif phase == "aim" then
		--[[ A beat low in the bell, legs drumming, before the next dart. ]]
		p.yaw = lerpAngle(move.fromYaw, move.toYaw, math.min(1, t * 3))
		p.squash = 0.78 + 0.04 * math.sin(now * 40)
		p.spread = 1.06
		p.twist = 0.05 * math.sin(now * 35)
	elseif phase == "charge" then
		p.feet = state.from:Lerp(state.to, t)
		move.feet = p.feet
		p.squash = 0.78 + 0.04 * math.sin(now * 40)
		p.spread = 1.06
		p.lift = 0.3 * math.abs(math.sin(now * 25))
	elseif phase == "crash" then
		--[[ Rocked back off the wall and reeling: the shell is open. ]]
		local seconds = now - move.phaseAt
		local w = math.exp(-seconds * 2.5)
		p.pitch = -0.25 * w * math.cos(seconds * 9) - 0.1
		p.twist = 0.18 * math.sin(seconds * 4.5) * (1 - 0.5 * t)
		p.squash = 0.9 + 0.1 * (1 - w)
		p.armsLift = 0.6 * math.abs(math.sin(seconds * 3))
	elseif phase == "recover" then
		p.pitch = -0.1 * (1 - ease(t))
	end
	return p
end

--[[ Strikes due by `now`, in order. ]]
local function strikes(state: State, boss: EnemyBoss, now: number, events: { Event })
	local e = echo(boss)
	local i = 1
	while i <= #state.marks do
		local mark = state.marks[i]
		if mark.strikeAt <= now then
			local strike = event("EchoStrike")
			strike.at = mark.at
			strike.radius = e.radius
			table.insert(events, strike)
			table.remove(state.marks, i)
		else
			i += 1
		end
	end
end

--[[ `BossMoves.step` for his moves. ]]
function TollcrabMoves.step(
	move: Move,
	boss: EnemyBoss,
	now: number,
	target: Vector3,
	clamp: (Vector3) -> Vector3
): (Pose, { Event }, boolean)
	local state = states[move]
	assert(state, "a Tollcrab move")
	local events: { Event } = {}

	--[[ Where the target is heading, smoothed. ]]
	local seen = state.seen
	if seen and now > state.seenAt then
		local v = (flat(target) - seen) / (now - state.seenAt)
		state.velocity = state.velocity:Lerp(v, 0.3)
	end
	state.seen = flat(target)
	state.seenAt = now

	if move.phase == "" then
		for _, e in enter(move, boss, state, "windup", move.phaseAt, target, clamp) do
			table.insert(events, e)
		end
	end

	while true do
		local endsAt = move.phaseAt + duration(move, boss, state)
		if now < endsAt then
			break
		end
		local following = nextPhase(move, boss, state)
		if following == "" then
			strikes(state, boss, math.huge, events)
			local p = pose(move, state, 1, now)
			return p, events, true
		end
		for _, e in enter(move, boss, state, following, endsAt, target, clamp) do
			table.insert(events, e)
		end
	end
	strikes(state, boss, now, events)

	local length = duration(move, boss, state)
	local t = if length > 0 then math.clamp((now - move.phaseAt) / length, 0, 1) else 1
	local p = pose(move, state, t, now)
	move.yaw = p.yaw
	return p, events, false
end

--[[
	What of his move touches a body `pad` studs across its middle at
	`point` now: the damage, the way it is pushed and how far, or nil.
	`who` is hit at most once by each ring, and once by each dash.
]]
function TollcrabMoves.touch(
	move: Move,
	boss: EnemyBoss,
	now: number,
	who: any,
	point: Vector3,
	pad: number
): (number?, Vector3, number)
	local state = states[move]
	if not state then
		return nil, Vector3.zero, 0
	end
	local function first(key: any): boolean
		local hit = state.struck[key]
		if not hit then
			hit = {}
			state.struck[key] = hit
		end
		if hit[who] then
			return false
		end
		hit[who] = true
		return true
	end

	if move.kind == "Toll" then
		local t = toll(boss)
		for _, ring in state.rings do
			if
				ring.startAt > 0
				and TollcrabMoves.ringHit(t, ring.at, ring.gap, now - ring.startAt, point, pad)
				and first(ring)
			then
				local away = flat(point) - ring.at
				return t.damage, if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis, t.shove
			end
		end
	elseif move.kind == "Scuttle" and move.phase == "charge" then
		local s = scuttle(boss)
		local offset = flat(point) - move.feet
		if offset.Magnitude <= s.width / 2 + pad and first(move.index) then
			--[[ Knocked out of his path, to whichever side they were on. ]]
			local side = Vector3.new(-state.along.Z, 0, state.along.X)
			local push = if offset:Dot(side) >= 0 then side else -side
			return s.damage, push, s.shove
		end
	end
	return nil, Vector3.zero, 0
end

return TollcrabMoves
