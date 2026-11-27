--!strict
--[[
	The Tempest Roc's own moves (docs/WINDSWEPT-CLIFFS.md, docs/BOSSES.md
	§5), run like every boss move (`BossMoves`): a timeline stepped once a
	frame that returns the pose his body takes and the events that happened,
	touching nothing itself. `EnemyManager` resolves the events, and asks
	`RocMoves.touch` each step whom his dive is crossing.

	- **Dive Line** (`dive`): he rises behind a lane drawn through the player
	  to the wall, then crosses the room down it; whoever he crosses is hurt
	  and thrown out of the lane sideways. He stands where he lands.
	- **Wing Gust** (`gust`): feet planted, a marked cone, then two beats of
	  his wings blow everyone in it away from him. No damage of its own: on
	  the cliffs the edge does the damage.
	- **Talon Swipe** (`swipe`): a short marked arc in front of him.
	- **Storm** (`storm`), only once enraged (`EnemyBoss.enrageAt`): he
	  climbs out of reach and circles while lightning strikes marked rings in
	  a pattern -- a line through the player, a ring round them, then bolts
	  that chase them -- and drops back down, winded: the phase's punish
	  window.

	His body is a Claude Design model playing its own clips; each phase
	names the clip it shows (`RocMoves.clip`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossMoves = require(script.Parent.BossMoves)

type EnemyBoss = Balance.EnemyBoss
type Move = BossMoves.Move
type Pose = BossMoves.Pose
type Event = BossMoves.Event

local RocMoves = {}

export type Bolt = {
	--[[ Nil until it is told: a chasing bolt lands where the player is
	     when its ring is drawn. ]]
	at: Vector3?,
	tellAt: number,
	strikeAt: number,
	told: boolean,
	struck: boolean,
}

type State = {
	enraged: boolean,
	--[[ The dive's lane, and the storm's spot. ]]
	from: Vector3,
	to: Vector3,
	along: Vector3,
	length: number,
	--[[ Which way a gust or a swipe faces. ]]
	aim: Vector3,
	bolts: { Bolt },
	--[[ Who the dive has already crossed: once each. ]]
	struck: { [any]: boolean },
}

local states: { [Move]: State } = setmetatable({} :: any, { __mode = "k" })

local KINDS = { Dive = true, Gust = true, Swipe = true, Storm = true }

local SHAKE_TIME = 0.3
--[[ Studs between samples as the dive's lane is run out to a wall. ]]
local LANE_STEP = 1
--[[ The longest lane he will fly, and the shortest worth flying. ]]
local LANE_MAX = 60
local LANE_MIN = 6
--[[ How high his dive arcs off the floor in the middle, and how far he
     circles round his spot in the storm. ]]
local DIVE_ARC = 1.5
local CIRCLE = 5
local SWIPE_STRIKE = 0.15
--[[ Studs of his body behind the point of the dive that still strike. ]]
local DIVE_BODY = 4

function RocMoves.owns(kind: string): boolean
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

local function roc(boss: EnemyBoss): Balance.BossRoc
	return boss.roc :: Balance.BossRoc
end

--[[ The flat unit direction from `from` to `to`, or `fallback`. ]]
local function toward(from: Vector3, to: Vector3, fallback: Vector3): Vector3
	local d = flat(to) - flat(from)
	return if d.Magnitude > 1e-3 then d.Unit else fallback
end

function RocMoves.start(
	kind: string,
	now: number,
	feet: Vector3,
	yaw: number,
	enraged: boolean
): Move
	local move = BossMoves.start(kind :: any, now, feet, yaw)
	states[move] = {
		enraged = enraged,
		from = flat(feet),
		to = flat(feet),
		along = move.direction,
		length = 0,
		aim = move.direction,
		bolts = {},
		struck = {},
	}
	return move
end

--[[ The storm's bolts, for the spec. ]]
function RocMoves.bolts(move: Move): { Bolt }
	local state = states[move]
	return if state then state.bolts else {}
end

--[[ The dive's lane: from, along, length. ]]
function RocMoves.lane(move: Move): (Vector3, Vector3, number)
	local state = states[move]
	assert(state, "a Roc move")
	return state.from, state.along, state.length
end

--[[ When the last bolt of a storm planned at `start` strikes. ]]
local function stormEnds(s: Balance.BossRocStorm, start: number): number
	local lineEnds = start + (s.line - 1) * s.every * 0.5
	local ringAt = lineEnds + s.every
	local chaseEnds = ringAt + s.every * 1.5 + (s.chase - 1) * s.every
	return chaseEnds + s.warn
end

--[[
	The storm's bolts from `start`, round the player at `target` (pure, for
	the spec): a line of `line` through them along `across`, told one after
	another; then a ring of `ring` round where they were; then `chase`
	bolts, each told on wherever they stand at its turn (no `at` yet).
]]
function RocMoves.planStorm(
	s: Balance.BossRocStorm,
	start: number,
	target: Vector3,
	across: Vector3
): { Bolt }
	local bolts: { Bolt } = {}
	local centre = flat(target)
	local middle = (s.line + 1) / 2
	for i = 1, s.line do
		local tellAt = start + (i - 1) * s.every * 0.5
		table.insert(bolts, {
			at = centre + across * (i - middle) * s.spacing,
			tellAt = tellAt,
			strikeAt = tellAt + s.warn,
			told = false,
			struck = false,
		})
	end
	local ringAt = start + (s.line - 1) * s.every * 0.5 + s.every
	for i = 1, s.ring do
		local angle = (i - 1) / s.ring * 2 * math.pi
		table.insert(bolts, {
			at = centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * s.ringRadius,
			tellAt = ringAt,
			strikeAt = ringAt + s.warn,
			told = false,
			struck = false,
		})
	end
	for i = 1, s.chase do
		local tellAt = ringAt + s.every * 1.5 + (i - 1) * s.every
		table.insert(bolts, {
			at = nil,
			tellAt = tellAt,
			strikeAt = tellAt + s.warn,
			told = false,
			struck = false,
		})
	end
	return bolts
end

local function duration(move: Move, boss: EnemyBoss, state: State): number
	local r = roc(boss)
	local phase = move.phase
	if move.kind == "Dive" then
		if phase == "windup" then
			return r.dive.windup
		elseif phase == "dive" then
			return state.length / r.dive.speed
		elseif phase == "land" then
			return r.dive.landed
		end
	elseif move.kind == "Gust" then
		if phase == "windup" then
			return r.gust.windup
		elseif phase == "blow" then
			return r.gust.blow
		elseif phase == "recover" then
			return r.gust.recover
		end
	elseif move.kind == "Swipe" then
		if phase == "windup" then
			return r.swipe.windup
		elseif phase == "strike" then
			return SWIPE_STRIKE
		elseif phase == "recover" then
			return r.swipe.recover
		end
	elseif move.kind == "Storm" then
		if phase == "rise" then
			return r.storm.rise
		elseif phase == "storm" then
			return stormEnds(r.storm, 0) + 0.3
		elseif phase == "drop" then
			return r.storm.drop
		elseif phase == "recover" then
			return r.storm.recover
		end
	end
	return 0
end

local function nextPhase(move: Move): string
	local phase = move.phase
	if move.kind == "Dive" then
		return if phase == "windup" then "dive" elseif phase == "dive" then "land" else ""
	elseif move.kind == "Gust" then
		return if phase == "windup" then "blow" elseif phase == "blow" then "recover" else ""
	elseif move.kind == "Swipe" then
		return if phase == "windup" then "strike" elseif phase == "strike" then "recover" else ""
	elseif move.kind == "Storm" then
		return if phase == "rise"
			then "storm"
			elseif phase == "storm" then "drop"
			elseif phase == "drop" then "recover"
			else ""
	end
	return ""
end

--[[ The clip each phase shows. ]]
local CLIPS: { [string]: { [string]: string } } = {
	Dive = { windup = "Dive_Windup", dive = "Dive", land = "Land" },
	Gust = { windup = "Gust", blow = "Gust", recover = "Idle" },
	Swipe = { windup = "Swipe", strike = "Swipe", recover = "Idle" },
	Storm = { rise = "Rise", storm = "Fly", drop = "Land", recover = "Idle" },
}

local function enter(
	move: Move,
	boss: EnemyBoss,
	state: State,
	phase: string,
	at: number,
	target: Vector3,
	clamp: (Vector3) -> Vector3
): { Event }
	local r = roc(boss)
	move.phase = phase
	move.phaseAt = at
	local clip = CLIPS[move.kind][phase] or "Idle"
	if clip ~= move.clip then
		move.clip = clip
		move.clipAt = at
	end
	local events: { Event } = {}
	local feet = flat(move.feet)

	if move.kind == "Dive" and phase == "windup" then
		--[[ Through the player, on to the wall or cover: sampled out until
		     the room would push the point back. ]]
		local along = toward(feet, target, move.direction)
		local length = 0
		local d = LANE_STEP
		while d <= LANE_MAX do
			local point = feet + along * d
			if (flat(clamp(point)) - point).Magnitude > 0.5 then
				break
			end
			length = d
			d += LANE_STEP
		end
		if length < LANE_MIN then
			--[[ Backed against a wall: fly the other way instead. ]]
			along = -along
			length = 0
			d = LANE_STEP
			while d <= LANE_MAX do
				local point = feet + along * d
				if (flat(clamp(point)) - point).Magnitude > 0.5 then
					break
				end
				length = d
				d += LANE_STEP
			end
		end
		state.from = feet
		state.along = along
		state.length = length
		state.to = feet + along * length
		state.struck = {}
		move.direction = along
		local e = event("Lane")
		e.at = feet
		e.direction = along
		e.length = length
		e.width = r.dive.width
		e.duration = r.dive.windup
		table.insert(events, e)
	elseif move.kind == "Dive" and phase == "land" then
		move.feet = state.to
		table.insert(events, shake(0.5))
	elseif move.kind == "Gust" and phase == "windup" then
		state.aim = toward(feet, target, move.direction)
		local e = event("GustTell")
		e.at = feet
		e.direction = state.aim
		e.length = r.gust.reach
		e.width = r.gust.angle
		e.duration = r.gust.windup
		table.insert(events, e)
	elseif move.kind == "Gust" and phase == "blow" then
		local e = event("Gust")
		e.at = feet
		e.direction = state.aim
		e.length = r.gust.reach
		e.width = r.gust.angle
		e.radius = r.gust.push
		e.duration = r.gust.blow
		table.insert(events, e)
		table.insert(events, shake(0.3))
	elseif move.kind == "Swipe" and phase == "windup" then
		state.aim = toward(feet, target, move.direction)
		local e = event("SwipeTell")
		e.at = feet
		e.direction = state.aim
		e.length = r.swipe.reach
		e.width = r.swipe.angle
		e.duration = r.swipe.windup
		table.insert(events, e)
	elseif move.kind == "Swipe" and phase == "strike" then
		local e = event("Swipe")
		e.at = feet
		e.direction = state.aim
		e.length = r.swipe.reach
		e.width = r.swipe.angle
		table.insert(events, e)
	elseif move.kind == "Storm" and phase == "rise" then
		state.from = feet
		table.insert(events, event("Scream"))
	elseif move.kind == "Storm" and phase == "storm" then
		local across = toward(feet, target, move.direction)
		across = Vector3.new(-across.Z, 0, across.X)
		state.bolts = RocMoves.planStorm(r.storm, at, target, across)
	elseif move.kind == "Storm" and phase == "drop" then
		move.feet = state.from
	elseif move.kind == "Storm" and phase == "recover" then
		table.insert(events, shake(0.5))
	end
	return events
end

--[[ The storm's bolts falling due: each ring drawn, then struck. A chasing
     bolt takes the player's spot as its ring is drawn. ]]
local function strikes(
	state: State,
	boss: EnemyBoss,
	now: number,
	target: Vector3,
	events: { Event }
)
	local s = roc(boss).storm
	for _, bolt in state.bolts do
		if not bolt.told and now >= bolt.tellAt then
			bolt.told = true
			if bolt.at == nil then
				bolt.at = flat(target)
			end
			local e = event("BoltTell")
			e.at = bolt.at :: Vector3
			e.radius = s.radius
			e.duration = bolt.strikeAt - bolt.tellAt
			table.insert(events, e)
		end
		if bolt.told and not bolt.struck and now >= bolt.strikeAt then
			bolt.struck = true
			local e = event("Bolt")
			e.at = bolt.at :: Vector3
			e.radius = s.radius
			table.insert(events, e)
		end
	end
end

local function pose(move: Move, boss: EnemyBoss, state: State, t: number, now: number): Pose
	local r = roc(boss)
	local p = BossMoves.idle(move.feet, move.yaw, now)
	if move.kind == "Dive" then
		p.yaw = yawOf(state.along, move.yaw)
		if move.phase == "dive" then
			p.feet = state.from + state.along * (state.length * t)
			p.lift = DIVE_ARC * math.sin(math.pi * t)
		elseif move.phase == "land" then
			p.feet = state.to
		else
			p.feet = state.from
		end
	elseif move.kind == "Gust" or move.kind == "Swipe" then
		p.yaw = yawOf(state.aim, move.yaw)
	elseif move.kind == "Storm" then
		local height = r.storm.height
		local spot = state.from
		if move.phase == "rise" then
			p.lift = height * ease(t)
			p.airborne = t > 0.25
		elseif move.phase == "storm" then
			local angle = now * 1.3
			p.feet = spot + Vector3.new(math.cos(angle), 0, math.sin(angle)) * CIRCLE
			p.yaw = angle
			p.lift = height
			p.airborne = true
		elseif move.phase == "drop" then
			p.lift = height * (1 - ease(t))
			p.airborne = t < 0.75
		end
	end
	return p
end

function RocMoves.step(
	move: Move,
	boss: EnemyBoss,
	now: number,
	target: Vector3,
	clamp: (Vector3) -> Vector3
): (Pose, { Event }, boolean)
	local state = states[move]
	assert(state, "a Roc move")
	local events: { Event } = {}

	if move.phase == "" then
		local first = if move.kind == "Storm" then "rise" else "windup"
		for _, e in enter(move, boss, state, first, move.phaseAt, target, clamp) do
			table.insert(events, e)
		end
	end

	while true do
		local endsAt = move.phaseAt + duration(move, boss, state)
		if now < endsAt then
			break
		end
		local following = nextPhase(move)
		if following == "" then
			strikes(state, boss, math.huge, target, events)
			return pose(move, boss, state, 1, now), events, true
		end
		for _, e in enter(move, boss, state, following, endsAt, target, clamp) do
			table.insert(events, e)
		end
	end
	strikes(state, boss, now, target, events)

	local length = duration(move, boss, state)
	local t = if length > 0 then math.clamp((now - move.phaseAt) / length, 0, 1) else 1
	local p = pose(move, boss, state, t, now)
	move.yaw = p.yaw
	return p, events, false
end

--[[ The clip the body shows: the phase's, from when it began, at its own
     pace. ]]
function RocMoves.clip(move: Move): (string, number, number)
	return move.clip, move.clipAt, 0
end

--[[
	Whether the dive under way crosses `player` at `position` this step: the
	damage, the way to throw them (out of the lane, the side they are on)
	and how far, or nil. Once each a dive.
]]
function RocMoves.touch(
	move: Move,
	boss: EnemyBoss,
	now: number,
	player: any,
	position: Vector3,
	pad: number
): (number?, Vector3, number)
	local state = states[move]
	if not state or move.kind ~= "Dive" or move.phase ~= "dive" or state.struck[player] then
		return nil, Vector3.zero, 0
	end
	local d = roc(boss).dive
	local travelled = math.min((now - move.phaseAt) * d.speed, state.length)
	local offset = flat(position) - state.from
	local along = offset:Dot(state.along)
	local side = Vector3.new(-state.along.Z, 0, state.along.X)
	local across = offset:Dot(side)
	if
		along < travelled - DIVE_BODY - pad
		or along > travelled + pad
		or math.abs(across) > d.width / 2 + pad
	then
		return nil, Vector3.zero, 0
	end
	state.struck[player] = true
	return d.damage, side * (if across >= 0 then 1 else -1), d.shove
end

RocMoves.duration = duration
RocMoves.nextPhase = nextPhase

return RocMoves
