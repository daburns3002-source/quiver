--!strict
--[[
	A boss's moves, as timelines (the Slime King's: the owner's
	design_handoff_slime_king, 2026-10-23).

	The handoff's modules yield through each phase and touch the world as
	they go. Here a move is a state machine stepped once a frame by
	`EnemyManager`, like every other enemy, and it touches nothing: each step
	returns the pose the body should take and the events that happened
	(a warning to draw, a slam that lands), and `EnemyManager` resolves those
	against the players. So the whole of a move can be run in a spec, and
	who gets hit is decided where every other hit is.

	Poses are about the feet, as the handoff's are: `squash` scales height,
	`spread` the width, `lift` raises the body off the floor, `lean` tips it
	forward for the chest bump, and an arm reaching down a lane says how far
	along it the fist is.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

type EnemyBoss = Balance.EnemyBoss

local BossMoves = {}

export type Kind = "Bounce" | "Lash"

--[[ The order the moves loop in. ]]
BossMoves.LOOP = { "Bounce", "Lash" } :: { Kind }

export type Pose = {
	feet: Vector3,
	yaw: number,
	lift: number,
	squash: number,
	spread: number,
	lean: number,
	--[[ The arm thrown down a lane, and how far along it the fist is (0 at
	     the shoulder, 1 at the lane's end). ]]
	arm: string?,
	armReach: number,
	direction: Vector3,
	length: number,
	--[[ In the air, where nothing on the floor can reach it. ]]
	airborne: boolean,
}

--[[
	Something that happened this step. `kind` is one of:

	- `SlamTell` — the circle a slam will land in (`at`, `radius`), for
	  `duration` seconds before it does.
	- `Slam` — it landed: hit everyone within `radius` of `at`.
	- `LaneAim` — the lane a lash is tracking along, pale, for `duration`.
	- `Lane` — the lane has locked; the hit lands `duration` later.
	- `LaneHit` — the fist landed: hit everyone in the lane, and grab the
	  first (`BossMoves.grab`).
	- `Bump` — the chest bump: release whoever is held, pushed along
	  `direction`.
]]
export type Event = {
	kind: string,
	at: Vector3,
	direction: Vector3,
	radius: number,
	length: number,
	width: number,
	duration: number,
}

export type Move = {
	kind: Kind,
	phase: string,
	phaseAt: number,
	--[[ Which bounce, or which arm. ]]
	index: number,
	feet: Vector3,
	yaw: number,
	--[[ The yaw a wind-up turns from, and the one it turns to. ]]
	fromYaw: number,
	toYaw: number,
	--[[ A bounce's takeoff and landing. ]]
	from: Vector3,
	land: Vector3,
	--[[ A lash's lane, from the feet. ]]
	direction: Vector3,
	length: number,
	--[[ A grab: where the held player stands, and where the boss is pulled
	     to. ]]
	held: Vector3?,
	pullTo: Vector3?,
}

--[[ The landing squash, from the handoff: down to 32% tall and 48% wider at
     its peak, then a damped wobble back. ]]
local LAND_SQUASH = 0.68
local LAND_SPREAD = 0.48

--[[ A bump releases its hold this far into the lean, at the lean's peak. ]]
local BUMP_RELEASE = 0.45

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--[[ The yaw at which a body faces `direction` (its LookVector along it). ]]
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

local function rest(move: Move): Pose
	return {
		feet = move.feet,
		yaw = move.yaw,
		lift = 0,
		squash = 1,
		spread = 1,
		lean = 0,
		arm = nil,
		armReach = 0,
		direction = move.direction,
		length = move.length,
		airborne = false,
	}
end

--[[ How long each phase lasts. ]]
local function duration(move: Move, boss: EnemyBoss): number
	local b, l = boss.bounce, boss.lash
	local phase = move.phase
	if move.kind == "Bounce" then
		return if phase == "windup"
			then b.windup
			elseif phase == "launch" then b.launch
			elseif phase == "air" then b.air
			elseif phase == "recover" then b.recover
			else b.winded
	end
	return if phase == "track"
		then l.track
		elseif phase == "aimed" then l.wind - l.track
		elseif phase == "strike" then l.strike
		elseif phase == "slap" then l.hold
		elseif phase == "retract" then l.retract
		elseif phase == "pull" then l.pull
		elseif phase == "lean" then l.bump * BUMP_RELEASE
		elseif phase == "release" then l.bump * (1 - BUMP_RELEASE)
		else l.recover
end

--[[ A new move, from where the boss stands. ]]
function BossMoves.start(kind: Kind, now: number, feet: Vector3, yaw: number): Move
	return {
		kind = kind,
		phase = "",
		phaseAt = now,
		index = 0,
		feet = flat(feet),
		yaw = yaw,
		fromYaw = yaw,
		toYaw = yaw,
		from = flat(feet),
		land = flat(feet),
		direction = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)),
		length = 0,
		held = nil,
		pullTo = nil,
	}
end

--[[ Aims a lash's lane at the target from where the boss stands. ]]
local function aimLane(move: Move, lash: Balance.BossLash, target: Vector3)
	local toward = flat(target) - move.feet
	if toward.Magnitude > 0.1 then
		move.direction = toward.Unit
	end
	move.length = math.clamp(toward.Magnitude + 2, lash.minReach, lash.reach)
	move.toYaw = yawOf(move.direction, move.yaw)
end

--[[
	Enters a phase, doing what happens at its start, and returns the events.
	`target` is where the boss's target stands; `clamp` keeps a landing or a
	pull inside the room.
]]
local function enter(
	move: Move,
	boss: EnemyBoss,
	phase: string,
	at: number,
	target: Vector3,
	clamp: (Vector3) -> Vector3
): { Event }
	move.phase = phase
	move.phaseAt = at
	local events: { Event } = {}

	if move.kind == "Bounce" then
		local b = boss.bounce
		if phase == "windup" then
			move.index += 1
			move.from = move.feet
			--[[ Locked here: the landing is where the target stood at the
			     start of the wind-up, and the circle shows it from now. ]]
			local offset = flat(target) - move.feet
			if offset.Magnitude > b.maxRange then
				offset = offset.Unit * b.maxRange
			end
			move.land = flat(clamp(move.feet + offset))
			move.fromYaw = move.yaw
			move.toYaw = yawOf(move.land - move.feet, move.yaw)

			local tell = event("SlamTell")
			tell.at = move.land
			tell.radius = b.radius
			tell.duration = b.windup + b.launch + b.air
			table.insert(events, tell)
		elseif phase == "launch" then
			move.yaw = move.toYaw
		elseif phase == "recover" then
			move.feet = move.land
			local slam = event("Slam")
			slam.at = move.land
			slam.radius = b.radius
			table.insert(events, slam)
		end
		return events
	end

	local l = boss.lash
	if phase == "track" then
		move.index += 1
		move.fromYaw = move.yaw
		aimLane(move, l, target)
		local aim = event("LaneAim")
		aim.at = move.feet
		aim.direction = move.direction
		aim.length = move.length
		aim.width = l.width
		aim.duration = l.track
		table.insert(events, aim)
	elseif phase == "aimed" then
		--[[ Locks: the lane brightens and the hit lands where it points. ]]
		aimLane(move, l, target)
		move.yaw = move.toYaw
		local lane = event("Lane")
		lane.at = move.feet
		lane.direction = move.direction
		lane.length = move.length
		lane.width = l.width
		lane.duration = (l.wind - l.track) + l.strike
		table.insert(events, lane)
	elseif phase == "slap" then
		local hit = event("LaneHit")
		hit.at = move.feet
		hit.direction = move.direction
		hit.length = move.length
		hit.width = l.width
		table.insert(events, hit)
	elseif phase == "release" then
		local bump = event("Bump")
		bump.at = move.feet
		bump.direction = move.direction
		table.insert(events, bump)
	elseif phase == "settle" then
		local to = move.pullTo
		if to then
			move.feet = to
		end
	end
	return events
end

--[[ The phase after this one, or "" when the move is over. ]]
local function nextPhase(move: Move, boss: EnemyBoss): string
	local phase = move.phase
	if move.kind == "Bounce" then
		if phase == "windup" then
			return "launch"
		elseif phase == "launch" then
			return "air"
		elseif phase == "air" then
			return "recover"
		elseif phase == "recover" then
			return if move.index < boss.bounce.bounces then "windup" else "winded"
		end
		return ""
	end
	local another = move.index < #boss.lash.arms
	if phase == "track" then
		return "aimed"
	elseif phase == "aimed" then
		return "strike"
	elseif phase == "strike" then
		return "slap"
	elseif phase == "slap" then
		return "retract"
	elseif phase == "pull" then
		return "lean"
	elseif phase == "lean" then
		return "release"
	elseif phase == "release" then
		return "settle"
	end
	-- retract or settle: the next arm, or done.
	return if another then "track" else ""
end

--[[
	A lash connected: the fist holds the player at `held`, and the boss is
	pulled to stand `stopDistance` short of them, inside the room. Called by
	`EnemyManager` straight after resolving a `LaneHit` that caught someone.
]]
function BossMoves.grab(
	move: Move,
	boss: EnemyBoss,
	now: number,
	held: Vector3,
	clamp: (Vector3) -> Vector3
)
	move.from = move.feet
	move.held = flat(held)
	move.pullTo = flat(clamp(flat(held) - move.direction * boss.lash.stopDistance))
	move.phase = "pull"
	move.phaseAt = now
end

--[[ The pose partway (`t`, 0 to 1) through the current phase. ]]
local function pose(move: Move, boss: EnemyBoss, t: number): Pose
	local p = rest(move)
	local phase = move.phase

	if move.kind == "Bounce" then
		local b = boss.bounce
		if phase == "windup" then
			local e = ease(t)
			p.yaw = lerpAngle(move.fromYaw, move.toYaw, e)
			p.squash = 1 - 0.3 * e
			p.spread = 1 + 0.18 * e
		elseif phase == "launch" then
			p.lift = b.height * 0.08 * t
			p.squash = 0.7 + 0.55 * t
			p.spread = 1.18 - 0.3 * t
		elseif phase == "air" then
			p.feet = move.from:Lerp(move.land, t)
			p.lift = b.height * 4 * t * (1 - t) + b.height * 0.08 * (1 - t)
			local s = if t < 0.5 then 1.25 - 0.5 * t else 1 + 0.3 * (t - 0.5)
			p.squash = s
			p.spread = 1 / math.sqrt(s)
			p.airborne = true
		elseif phase == "recover" then
			local w = math.exp(-t * 4.2) * math.cos(t * 13)
			p.squash = math.max(0.3, 1 - LAND_SQUASH * w)
			p.spread = 1 + LAND_SPREAD * w
		elseif phase == "winded" then
			local breath = 0.06 * math.sin(t * math.pi * 3)
			p.squash = 0.88 + breath
			p.spread = 1.06 - breath * 0.5
		end
		return p
	end

	local l = boss.lash
	p.arm = l.arms[math.clamp(move.index, 1, #l.arms)]
	if phase == "track" or phase == "aimed" then
		local into = (if phase == "track" then t * l.track else l.track + t * (l.wind - l.track))
			/ l.wind
		p.yaw = lerpAngle(move.fromYaw, move.toYaw, math.min(1, into * 6))
		p.armReach = -0.08 * ease(into)
	elseif phase == "strike" then
		p.armReach = 1 - (1 - t) ^ 3
	elseif phase == "slap" then
		p.armReach = 1
	elseif phase == "retract" then
		p.armReach = 1 - ease(t)
	elseif phase == "pull" then
		local to = move.pullTo or move.feet
		p.feet = move.from:Lerp(to, ease(t))
		p.lift = 1.6 * math.sin(math.pi * t)
		--[[ The fist stays on the held player while the arm contracts and
		     the body is hauled in after it. ]]
		local held = move.held or to
		p.length = (held - p.feet).Magnitude
		p.armReach = 1
	elseif phase == "lean" or phase == "release" then
		p.feet = move.pullTo or move.feet
		local u = if phase == "lean"
			then t * BUMP_RELEASE
			else BUMP_RELEASE + t * (1 - BUMP_RELEASE)
		p.lean = math.sin(math.pi * math.min(1, u * 1.6))
	elseif phase == "settle" then
		p.lean = math.exp(-t * 5) * math.cos(t * 9) * (1 - t)
	end
	return p
end

--[[
	Advances a move to `now` and returns the pose, the events since the last
	step (in order), and whether the move is over. Phases that ended during a
	long frame are passed through in turn, so a hitch never skips a slam.
]]
function BossMoves.step(
	move: Move,
	boss: EnemyBoss,
	now: number,
	target: Vector3,
	clamp: (Vector3) -> Vector3
): (Pose, { Event }, boolean)
	local events: { Event } = {}

	if move.phase == "" then
		local first: string = if move.kind == "Bounce" then "windup" else "track"
		for _, e in enter(move, boss, first, move.phaseAt, target, clamp) do
			table.insert(events, e)
		end
	end

	while true do
		local length = duration(move, boss)
		local endsAt = move.phaseAt + length
		if now < endsAt then
			break
		end
		local following = nextPhase(move, boss)
		if following == "" then
			return rest(move), events, true
		end
		for _, e in enter(move, boss, following, endsAt, target, clamp) do
			table.insert(events, e)
		end
	end

	--[[ The lane follows the target until it locks. ]]
	if move.kind == "Lash" and move.phase == "track" then
		aimLane(move, boss.lash, target)
	end

	local length = duration(move, boss)
	local t = if length > 0 then math.clamp((now - move.phaseAt) / length, 0, 1) else 1
	local p = pose(move, boss, t)
	move.yaw = p.yaw
	return p, events, false
end

--[[ Standing between moves: a slow breath. ]]
function BossMoves.idle(feet: Vector3, yaw: number, now: number): Pose
	local breath = 0.03 * math.sin(now * 2.4)
	return {
		feet = flat(feet),
		yaw = yaw,
		lift = 0,
		squash = 1 + breath,
		spread = 1 - breath * 0.5,
		lean = 0,
		arm = nil,
		armReach = 0,
		direction = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)),
		length = 0,
		airborne = false,
	}
end

--[[ The seconds a boss rests after a move. ]]
function BossMoves.restAfter(kind: Kind, boss: EnemyBoss): number
	return if kind == "Bounce" then boss.restAfterBounce else boss.restAfterLash
end

return BossMoves
