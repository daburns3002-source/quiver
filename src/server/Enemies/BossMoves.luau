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

	The motion is the design's own (`source/Slime King Attacks.html`): the
	squash and stretch of each phase, the arms lifting for a bounce, the arm
	pulled back before a lash and the fist arcing down onto the lane, the
	pull, the chest bump and its wobble. The design draws the king at his
	model's own size, 4.9 studs tall; here he is twice that, so its small
	offsets are doubled (`SIZE`). Its timings, ranges and the slam's circle
	are the handoff's numbers in studs, from `Balance`.

	Poses are about the feet: `squash` scales height, `spread` the width,
	`lift` raises the body off the floor, `lean` pushes it forward and
	`pitch` tips it.

	A boss whose body carries its own clips (`EnemyBoss.clips`, King
	Bloblin's imported rig) is not posed from these: each phase names the
	clip it plays (`BossMoves.clip`), and the client plays it on the beat.
	The pose's feet, lift and yaw still place his hitbox; the rest of it is
	only read for a body the server poses (`BossBody`).

	The Broodmother's Web Walker (`Spin`, `EnemyBoss.spin`) is a third
	move: a web spun round her where she stands (`Shared/Util/WebWheel`).
	Its phases only warn, spin and break; who it touches each step is
	asked of `BossMoves.wheelHit` by `EnemyManager`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local WebWheel = require(ReplicatedStorage.Shared.Util.WebWheel)

type EnemyBoss = Balance.EnemyBoss

local BossMoves = {}

export type Kind = "Bounce" | "Lash" | "Spin"

--[[ The order the moves loop in, unless the boss names its own. ]]
BossMoves.LOOP = { "Bounce", "Lash" } :: { Kind }

--[[ The order `boss`'s moves loop in. ]]
function BossMoves.loopOf(boss: EnemyBoss): { Kind }
	local own = boss.loop
	if own then
		return own :: { any }
	end
	return BossMoves.LOOP
end

export type Pose = {
	feet: Vector3,
	yaw: number,
	lift: number,
	squash: number,
	spread: number,
	--[[ Studs the body is pushed forward, and radians it tips forward. ]]
	lean: number,
	pitch: number,
	--[[ Radians the body is twisted round from `yaw`, as a lash winds up
	     and whips through; never part of the way it faces. ]]
	twist: number,
	--[[ Studs both arms are raised (a bounce's wind-up and flight). ]]
	armsLift: number,
	--[[ The arm a lash is throwing; where it is balled up behind the
	     shoulder before the throw (studs, in the body's frame: +Z is
	     behind) and how it swells there; how far along the lane its fist
	     is (0 at the shoulder, 1 at the lane's end, a little past it as it
	     overshoots), how high the fist sits at the lane's end and how high
	     it arcs on the way, and how big it is, then squashed or stretched
	     along its own axes (Z along the lane). ]]
	arm: string?,
	armOffset: Vector3,
	armSwell: Vector3,
	armReach: number,
	fistLift: number,
	fistArc: number,
	fistScale: number,
	fistShape: Vector3,
	--[[ The thrown arm's jelly tube: studs it arcs up between shoulder
	     and fist, studs it ripples sideways and the ripple's phase, and
	     where along it (0 to 1) a lump of goo rides, or below 0 for none. ]]
	tubeArc: number,
	tubeWave: number,
	tubePhase: number,
	tubeBulge: number,
	--[[ Where the fist is held, when it has grabbed someone. ]]
	held: Vector3?,
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
	- `LaneAim` — the lane a lash is tracking along, pale, for `duration`;
	  sent again as it follows the target.
	- `Lane` — the lane has locked; the hit lands `duration` later.
	- `LaneHit` — the fist landed at `at` + `direction` × `length`: hit
	  everyone in the lane, and grab the first (`BossMoves.grab`).
	- `Bump` — the chest bump: release whoever is held, pushed along
	  `direction`.
	- `Splat` — the fist slapping the floor at `at`, `radius` across.
	- `BumpShock` — the chest bump's shock, out from `at` (the belly).
	- `Shake` — shake the camera by `radius` for `duration`.
	- `Goo` — droplets flung off a fist that splatted at `at`.
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
	--[[ A lash's lane, from the feet, and when its tracking lane was last
	     sent. ]]
	direction: Vector3,
	length: number,
	aimSentAt: number,
	--[[ A grab: where the held player stands, and where the boss is pulled
	     to. ]]
	held: Vector3?,
	pullTo: Vector3?,
	--[[ The clip the body is playing (`EnemyBoss.clips`), "" for none, and
	     when it began: a clip shared by two phases runs from the first. ]]
	clip: string,
	clipAt: number,
	--[[ A spin: the angle spoke one starts at (`WebWheel`), set as the
	     web is raised. ]]
	angle: number,
}

--[[ The design's king is 4.9 studs tall; this one is twice that. ]]
local SIZE = 2

--[[ The landing squash, from the design: down to 32% tall and 48% wider at
     its peak, then a damped wobble back. ]]
local LAND_SQUASH = 0.68
local LAND_SPREAD = 0.48

--[[ A bump releases its hold this far into the lean, at the lean's peak. ]]
local BUMP_RELEASE = 0.45

--[[ How high the fist sits on the floor at the lane's end. ]]
local FIST_REST = 0.9 * SIZE

--[[ A lash winds up for this share of its wind, then coils tighter for
     the rest, the signal that it is about to throw. ]]
local COIL_AT = 0.85

--[[ How often a tracking lane is redrawn as it follows the target. ]]
local AIM_REFRESH = 0.1

--[[ The small shockwave of a fist slapping the floor and of a chest bump. ]]
local SHOCK_RADIUS = 5

--[[ Camera shakes, from the design (slam 0.5, slap 0.25, bump 0.45),
     on the sword slam's scale (`Config/Weapons`, 0.35). ]]
local SHAKE_SLAM = 0.6
local SHAKE_SLAP = 0.3
local SHAKE_BUMP = 0.5
local SHAKE_TIME = 0.3

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

local function shake(magnitude: number): Event
	local e = event("Shake")
	e.radius = magnitude
	e.duration = SHAKE_TIME
	return e
end

local function shock(kind: string, at: Vector3): Event
	local e = event(kind)
	e.at = at
	e.radius = SHOCK_RADIUS
	return e
end

local function rest(move: Move): Pose
	return {
		feet = move.feet,
		yaw = move.yaw,
		lift = 0,
		squash = 1,
		spread = 1,
		lean = 0,
		pitch = 0,
		twist = 0,
		armsLift = 0,
		arm = nil,
		armOffset = Vector3.zero,
		armSwell = Vector3.one,
		armReach = 0,
		fistLift = 0,
		fistArc = 0,
		fistScale = 1,
		fistShape = Vector3.one,
		tubeArc = 0,
		tubeWave = 0,
		tubePhase = 0,
		tubeBulge = -1,
		held = nil,
		direction = move.direction,
		length = move.length,
		airborne = false,
	}
end

--[[ How long each phase lasts. ]]
local function duration(move: Move, boss: EnemyBoss): number
	local b, l = boss.bounce, boss.lash
	local phase = move.phase
	if move.kind == "Spin" then
		local s = boss.spin :: Balance.BossSpin
		return if phase == "windup"
			then s.windup
			elseif phase == "spin" then s.spin
			elseif phase == "broken" then s.broken
			else s.recover
	end
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
		aimSentAt = -math.huge,
		held = nil,
		pullTo = nil,
		clip = "",
		clipAt = now,
		angle = 0,
	}
end

--[[ The clip `boss`'s body plays in `phase` of a move of `kind`, the
     `index`th (which bounce, or which arm), or "" when it plays none. ]]
function BossMoves.clipName(boss: EnemyBoss, kind: Kind, phase: string, index: number): string
	local clips = boss.clips
	if not clips then
		return ""
	end
	if kind == "Bounce" then
		return clips.Bounce[phase] or ""
	elseif kind == "Spin" then
		local spin = clips.Spin
		return if spin then spin[phase] or "" else ""
	end
	local arms = boss.lash.arms
	local arm = arms[math.clamp(index, 1, #arms)]
	local byPhase = clips.Lash[arm]
	return if byPhase then byPhase[phase] or "" else ""
end

--[[
	How far a lash's chain is stretched along its lane, as a share of how
	the clips draw it (at `lash.reach`): from its root, so the fist lands as
	near the lane's end as it does at full reach. 1 for a body without a
	chain.
]]
function BossMoves.chainScale(length: number, lash: Balance.BossLash): number
	local root, reach = lash.chainRoot, lash.chainReach
	if not root or not reach then
		return 1
	end
	return math.max(0.05, (length - root) / (lash.reach - root))
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

local function laneEvent(kind: string, move: Move, lash: Balance.BossLash, seconds: number): Event
	local e = event(kind)
	e.at = move.feet
	e.direction = move.direction
	e.length = move.length
	e.width = lash.width
	e.duration = seconds
	return e
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
	if phase == "track" or phase == "windup" then
		-- the index this phase will carry (it is counted below)
		move.index += 1
	end
	local clip = BossMoves.clipName(boss, move.kind, phase, move.index)
	if clip ~= move.clip then
		move.clip = clip
		move.clipAt = at
	end
	local events: { Event } = {}

	if move.kind == "Spin" then
		local s = boss.spin :: Balance.BossSpin
		--[[ The web as one event: centred on her, spoke one along
		     `direction`, `radius` and `length` its web and its arms. ]]
		local function wheel(kind: string, angle: number, seconds: number): Event
			local e = event(kind)
			e.at = move.feet
			e.direction = WebWheel.spoke(angle, 1, s.spokes)
			e.radius = s.radius
			e.length = s.reach
			e.width = s.width
			e.duration = seconds
			return e
		end
		if phase == "windup" then
			--[[ Spoke one starts on the target, so an arm is on them the
			     moment it turns: they have the wind-up to step clear. ]]
			move.angle = WebWheel.angleOf(flat(target) - move.feet)
			table.insert(events, wheel("WheelTell", move.angle, s.windup))
		elseif phase == "spin" then
			table.insert(events, wheel("WheelSpin", move.angle, s.spin))
		elseif phase == "broken" then
			local stopped = WebWheel.angle(move.angle, s.period, s.spin)
			table.insert(events, wheel("WheelBreak", stopped, s.broken))
			table.insert(events, shake(SHAKE_SLAP))
		end
		return events
	end

	if move.kind == "Bounce" then
		local b = boss.bounce
		if phase == "windup" then
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
			table.insert(events, shake(SHAKE_SLAM))
		end
		return events
	end

	local l = boss.lash
	if phase == "track" then
		move.fromYaw = move.yaw
		aimLane(move, l, target)
		move.aimSentAt = at
		table.insert(events, laneEvent("LaneAim", move, l, AIM_REFRESH * 1.5))
	elseif phase == "aimed" then
		--[[ Locks: the lane brightens and the hit lands where it points. ]]
		aimLane(move, l, target)
		move.yaw = move.toYaw
		table.insert(events, laneEvent("Lane", move, l, (l.wind - l.track) + l.strike))
	elseif phase == "slap" then
		table.insert(events, laneEvent("LaneHit", move, l, 0))
		local splat = move.feet + move.direction * move.length
		table.insert(events, shock("Splat", splat))
		local goo = event("Goo")
		goo.at = splat + Vector3.new(0, FIST_REST, 0)
		goo.direction = move.direction
		table.insert(events, goo)
		table.insert(events, shake(SHAKE_SLAP))
	elseif phase == "release" then
		local bump = event("Bump")
		bump.at = move.feet
		bump.direction = move.direction
		table.insert(events, bump)
		table.insert(events, shock("BumpShock", move.held or move.feet))
		table.insert(events, shake(SHAKE_BUMP))
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
	if move.kind == "Spin" then
		return if phase == "windup"
			then "spin"
			elseif phase == "spin" then "broken"
			elseif phase == "broken" then "recover"
			else ""
	end
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
	move.clip = BossMoves.clipName(boss, move.kind, "pull", move.index)
	move.clipAt = now
end

--[[ The pose partway (`t`, 0 to 1) through the current phase. ]]
local function pose(move: Move, boss: EnemyBoss, t: number): Pose
	local p = rest(move)
	local phase = move.phase

	--[[ A spin keeps her where she stands; her clips do the moving. ]]
	if move.kind == "Spin" then
		return p
	end

	if move.kind == "Bounce" then
		local b = boss.bounce
		if phase == "windup" then
			local e = ease(t)
			p.yaw = lerpAngle(move.fromYaw, move.toYaw, e)
			p.squash = 1 - 0.3 * e
			p.spread = 1 + 0.18 * e
			p.armsLift = 0.35 * SIZE * e
		elseif phase == "launch" then
			p.lift = b.height * 0.08 * t
			p.squash = 0.7 + 0.55 * t
			p.spread = 1.18 - 0.3 * t
			p.armsLift = 0.35 * SIZE
		elseif phase == "air" then
			p.feet = move.from:Lerp(move.land, t)
			p.lift = b.height * 4 * t * (1 - t) + b.height * 0.08 * (1 - t)
			local s = if t < 0.5 then 1.25 - 0.5 * t else 1 + 0.3 * (t - 0.5)
			p.squash = s
			p.spread = 1 / math.sqrt(s)
			p.armsLift = 0.35 * SIZE * (1 - t)
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

	--[[ The design's Zac-Q lash (design_handoff_slime_king's update): the
	     body twists away from the throwing arm and leans back while the
	     fist balls up behind the shoulder, then whips through as the arm
	     flies out as a rippling jelly tube, overshoots, splats and reels
	     back in. The design's numbers are studs on its king, so the
	     offsets are doubled (`SIZE`); angles are as they are. ]]
	local l = boss.lash
	local arm = l.arms[math.clamp(move.index, 1, #l.arms)]
	p.arm = arm
	--[[ Which side throws: the right arm twists the body clockwise first. ]]
	local side = if string.find(arm, "_R") then 1 else -1
	if phase == "track" or phase == "aimed" then
		local into = (if phase == "track" then t * l.track else l.track + t * (l.wind - l.track))
			/ l.wind
		local seconds = into * l.wind
		local back = ease(math.min(1, into / COIL_AT))
		local coil = if into > COIL_AT then ease((into - COIL_AT) / (1 - COIL_AT)) else 0
		p.yaw = lerpAngle(move.fromYaw, move.toYaw, math.min(1, seconds * 8))
		p.twist = -side * (0.38 * back + 0.08 * coil)
		p.pitch = -(0.13 * back + 0.05 * coil)
		local swell = 1 + 0.45 * back + 0.15 * coil + math.sin(seconds * 28) * 0.05 * back
		p.armSwell =
			Vector3.new(swell * 1.05, swell * (0.95 - 0.12 * coil), swell * (1.05 + 0.1 * coil))
		p.armOffset = Vector3.new(
			0.15 * side * back,
			0.45 * back + 0.1 * coil,
			1.15 * back + 0.25 * coil
		) * SIZE
		p.squash = 1 - 0.06 * back
		p.spread = 1 + 0.04 * back
	elseif phase == "strike" then
		--[[ Out past the lane's end by 8%, then back onto it. ]]
		local extension = if t < 0.72
			then 1.08 * (1 - (1 - t / 0.72) ^ 3)
			else 1.08 - 0.08 * ease((t - 0.72) / 0.28)
		local whip = ease(t)
		local stretch = 0.25 * math.sin(math.pi * t)
		p.twist = -side * (0.46 - 0.66 * whip)
		p.pitch = -(0.18 - 0.36 * whip)
		p.armReach = extension
		p.fistLift = FIST_REST
		p.fistArc = 1.6 * SIZE * math.sin(math.pi * math.min(1, extension)) * (1 - t * 0.6)
		p.fistScale = 1 + 0.7 * math.min(1, extension)
		p.fistShape = Vector3.new(1 - 0.1 * stretch, 1 - 0.1 * stretch, 1 + stretch)
		p.tubeArc = 1.2 * SIZE * math.sin(math.pi * t)
		p.tubeWave = 0.55 * SIZE * math.sin(math.pi * t)
		p.tubePhase = t * 2.2
		p.tubeBulge = 0.1 + 0.9 * t
		p.squash = 1 + 0.05 * extension
		p.spread = 1 - 0.03 * extension
	elseif phase == "slap" then
		--[[ The fist splats flat and wobbles back; the tube sags as its
		     ripples die. ]]
		local seconds = t * l.hold
		local settle = 1 - ease(t)
		local splat = math.exp(-seconds * 9) * math.cos(seconds * 26)
		p.twist = side * 0.2 * settle
		p.pitch = 0.18 * settle
		p.armReach = 1
		p.fistLift = FIST_REST
		p.fistScale = 1.7
		p.fistShape = Vector3.new(1 + 0.35 * splat, 1 - 0.45 * splat, 1 + 0.3 * splat)
		p.tubeArc = (-0.35 * (1 - math.min(1, seconds / 0.18)) + 0.25 * splat) * SIZE
		p.tubeWave = 0.3 * SIZE * math.exp(-seconds * 7)
		p.tubePhase = seconds * 5
		p.squash = 1.05
		p.spread = 0.97
	elseif phase == "retract" then
		--[[ Reeled in with a whip, a little elastic overshoot, and the body
		     bulging as it slurps the arm back in. ]]
		local extension = math.max(
			0,
			1 - ease(math.min(1, t / 0.8)) - 0.06 * math.sin(math.pi * math.max(0, (t - 0.8) / 0.2))
		)
		local absorb = if t > 0.78 then math.sin(math.pi * (t - 0.78) / 0.22) else 0
		p.twist = -side * 0.06 * math.sin(math.pi * t) * (1 - t)
		p.pitch = -0.06 * math.sin(math.pi * t)
		p.armReach = extension
		p.fistLift = FIST_REST
		p.fistArc = (0.9 * math.sin(math.pi * extension) + math.sin(t * 20) * (1 - t) * 0.15) * SIZE
		p.fistScale = 1 + 0.7 * extension
		p.fistShape = Vector3.new(1 + 0.1 * absorb, 1 - 0.1 * absorb, 1)
		p.tubeArc = 0.8 * SIZE * math.sin(math.pi * t)
		p.tubeWave = 0.65 * SIZE * math.sin(math.pi * t) * (1 - t * 0.5)
		p.tubePhase = -t * 3
		p.tubeBulge = 1 - t
		p.squash = 1 + 0.05 * extension - 0.04 * absorb
		p.spread = 1 - 0.03 * extension + 0.06 * absorb
	elseif phase == "pull" then
		local to = move.pullTo or move.feet
		local hop = math.sin(math.pi * t)
		p.feet = move.from:Lerp(to, ease(t))
		p.lift = 1.6 * SIZE * hop
		local s = 1 + 0.35 * hop
		p.squash = s * 0.85 + 0.15
		p.spread = 1 / math.sqrt(s)
		--[[ The fist stays on the held player while the arm contracts and
		     the body is hauled in after it. ]]
		p.held = move.held
		p.fistLift = 1.6 * SIZE
		p.fistScale = 1.7 - 0.7 * t
		p.tubeArc = 0.5 * SIZE * hop
		p.tubeWave = 0.12 * SIZE * (1 - t)
		p.tubePhase = t * 3
		p.tubeBulge = 1 - t
	elseif phase == "lean" or phase == "release" then
		local u = if phase == "lean"
			then t * BUMP_RELEASE
			else BUMP_RELEASE + t * (1 - BUMP_RELEASE)
		local lean = math.sin(math.pi * math.min(1, u * 1.6))
		p.feet = move.pullTo or move.feet
		p.lean = 1.4 * SIZE * lean
		p.pitch = 0.28 * lean
		p.squash = 1 + 0.08 * lean
		p.spread = 1 + 0.12 * lean
	elseif phase == "settle" then
		local w = math.exp(-t * 5) * math.cos(t * 12)
		p.pitch = 0.28 * (1 - ease(t)) * math.cos(t * 9)
		p.squash = 1 - 0.12 * w
		p.spread = 1 + 0.08 * w
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
		local first: string = if move.kind == "Lash" then "track" else "windup"
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

	--[[ The lane follows the target until it locks, redrawn as it goes. ]]
	if move.kind == "Lash" and move.phase == "track" then
		aimLane(move, boss.lash, target)
		if now - move.aimSentAt >= AIM_REFRESH then
			move.aimSentAt = now
			table.insert(events, laneEvent("LaneAim", move, boss.lash, AIM_REFRESH * 1.5))
		end
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
		pitch = 0,
		twist = 0,
		armsLift = 0,
		arm = nil,
		armOffset = Vector3.zero,
		armSwell = Vector3.one,
		armReach = 0,
		fistLift = 0,
		fistArc = 0,
		fistScale = 1,
		fistShape = Vector3.one,
		tubeArc = 0,
		tubeWave = 0,
		tubePhase = 0,
		tubeBulge = -1,
		held = nil,
		direction = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)),
		length = 0,
		airborne = false,
	}
end

--[[
	The clip the body plays now, when it began, and how many seconds it
	is to last: the phases that share it, played through as they will be
	(a lash that has not hit plays on to its retract). "" with no move, or
	for a body without clips.
]]
function BossMoves.clip(move: Move, boss: EnemyBoss): (string, number, number)
	if move.clip == "" then
		return "", move.clipAt, 0
	end
	--[[ The clip held while a web spins loops at its own pace. ]]
	if move.kind == "Spin" and move.phase == "spin" then
		return move.clip, move.clipAt, (boss.spin :: Balance.BossSpin).holdSpan
	end
	--[[ From the clip's first phase, through this one, and on through each
	     phase after it that shares the clip. ]]
	local probe = table.clone(move)
	local span = (move.phaseAt - move.clipAt) + duration(probe, boss)
	for _ = 1, 16 do
		local following = nextPhase(probe, boss)
		if
			following == ""
			or BossMoves.clipName(boss, probe.kind, following, probe.index) ~= move.clip
		then
			break
		end
		probe.phase = following
		span += duration(probe, boss)
	end
	return move.clip, move.clipAt, span
end

--[[ The seconds a boss rests after a move. ]]
function BossMoves.restAfter(kind: Kind, boss: EnemyBoss): number
	if kind == "Spin" then
		return boss.restAfterSpin or boss.restAfterLash
	end
	return if kind == "Bounce" then boss.restAfterBounce else boss.restAfterLash
end

--[[
	What of a spinning web touches a body `pad` studs across its middle at
	`point` (`WebWheel.hit`: "web", "arm" or nil). Only while it spins: the
	wind-up only warns, and a broken web hurts nobody.
]]
function BossMoves.wheelHit(
	move: Move,
	boss: EnemyBoss,
	now: number,
	point: Vector3,
	pad: number
): string?
	local s = boss.spin
	if move.kind ~= "Spin" or move.phase ~= "spin" or not s then
		return nil
	end
	local angle = WebWheel.angle(move.angle, s.period, now - move.phaseAt)
	return WebWheel.hit(s, move.feet, angle, point, pad)
end

return BossMoves
