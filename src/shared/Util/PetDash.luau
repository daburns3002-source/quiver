--!strict
--[[
	A pet that dashes to its enemies (owner, 2026-10-25: "glade fox needs to
	actually dash to the enemies when it attacks"): the Glade Fox's Leaf
	Dash runs to up to three enemies in turn, slashing each as it lands, and
	runs back to its owner.

	Pure, shared by the server (`Combat/PetCombat`: the route round cover,
	and the blow landing on arrival) and the client (`Fx/PetPreview`: where
	the fox is drawn and which frame of its Attack clip it shows), so the
	fox is seen arriving when the damage lands.

	A plan is a list of stops, one per enemy and the last back home. Each
	stop's route is the straight legs to it (from `Enemies/Pathing`, which
	keeps the fox out of walls and cover), after the previous stop. The fox
	crouches for `windup`, runs each route at `speed` (no faster than
	`shortest` and no slower than `longest` a route, so a near enemy is
	still a dash and a far one is reached in time), and stays `slash`
	seconds at each enemy.
]]

local PetDash = {}

export type Clip = {
	--[[ The pet's Attack clip and the joint its own lunge moves. ]]
	name: string,
	root: string,
	--[[ Seconds into the clip: the lunge leaves, lands, turns back, and is
	     home again. ]]
	out: number,
	hit: number,
	back: number,
	home: number,
}

export type Dash = {
	speed: number,
	windup: number,
	slash: number,
	shortest: number,
	longest: number,
	--[[ The fox's body radius, the gap it lands from an enemy's side, and
	     how far a route may end from where it was asked to (a stop it
	     cannot reach is skipped). ]]
	radius: number,
	gap: number,
	reach: number,
	clip: Clip,
}

export type Stop = {
	route: { Vector3 },
	leave: number,
	arrive: number,
	--[[ The enemy's place when it was planned; nil for the run home. ]]
	aim: Vector3?,
}

export type Plan = { start: Vector3, stops: { Stop }, length: number }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function lengthOf(from: Vector3, route: { Vector3 }): number
	local total, last = 0, from
	for _, point in route do
		total += (flat(point) - flat(last)).Magnitude
		last = point
	end
	return total
end

--[[ Where `t` (0..1 of its length) falls along `route` from `from`. ]]
local function along(from: Vector3, route: { Vector3 }, t: number): (Vector3, Vector3?)
	local total = lengthOf(from, route)
	local want = total * math.clamp(t, 0, 1)
	local last = flat(from)
	local heading: Vector3? = nil
	for _, point in route do
		local p = flat(point)
		local leg = (p - last).Magnitude
		if leg > 1e-4 then
			heading = (p - last).Unit
			if want <= leg then
				return last:Lerp(p, want / leg), heading
			end
			want -= leg
		end
		last = p
	end
	return last, heading
end

--[[ The fast-out, slowing-in curve of a dash. ]]
function PetDash.ease(u: number): number
	local v = 1 - math.clamp(u, 0, 1)
	return 1 - v * v
end

--[[ Where the fox lands to strike an enemy at `target` coming from
     `from`: on the near side, `gap` from its centre. ]]
function PetDash.landing(from: Vector3, target: Vector3, gap: number): Vector3
	local offset = flat(from) - flat(target)
	if offset.Magnitude <= gap then
		return flat(from)
	end
	return flat(target) + offset.Unit * gap
end

--[[ Seconds a route of `distance` studs takes. ]]
function PetDash.travel(distance: number, dash: Dash): number
	return math.clamp(distance / dash.speed, dash.shortest, dash.longest)
end

--[[ The timeline of routes from `start`: one per enemy (each with its
     `aims` place), then the last one home. ]]
function PetDash.plan(start: Vector3, routes: { { Vector3 } }, aims: { Vector3 }, dash: Dash): Plan
	local stops: { Stop } = {}
	local t = dash.windup
	local from = start
	for i, route in routes do
		local leave = t
		local arrive = leave + PetDash.travel(lengthOf(from, route), dash)
		local aim = aims[i]
		table.insert(stops, { route = route, leave = leave, arrive = arrive, aim = aim })
		t = arrive + (if aim then dash.slash else 0)
		from = if #route > 0 then route[#route] else from
	end
	return { start = flat(start), stops = stops, length = t }
end

--[[ The seconds into the plan each blow lands: the arrivals at enemies. ]]
function PetDash.hits(plan: Plan): { number }
	local out = {}
	for _, stop in plan.stops do
		if stop.aim then
			table.insert(out, stop.arrive)
		end
	end
	return out
end

--[[ Where a stop's route starts: the previous stop, or the plan's start. ]]
local function fromOf(plan: Plan, i: number): Vector3
	local before = plan.stops[i - 1]
	if before and #before.route > 0 then
		return flat(before.route[#before.route])
	end
	return if i == 1 then plan.start else fromOf(plan, i - 1)
end

--[[
	Where the fox is `t` seconds into `plan`, on the floor, and which way it
	faces (nil: keep facing as before); and the stop it is on or running to
	with how far through that run it is (0 before leaving, 1 once there; the
	stop is past the last one after the plan).
]]
function PetDash.at(plan: Plan, t: number): (Vector3, Vector3?, number, number)
	local stops = plan.stops
	for i, stop in stops do
		local from = fromOf(plan, i)
		if t < stop.leave then
			-- crouched, or slashing at the stop before
			local before = stops[i - 1]
			local facing = if before and before.aim
				then flat(before.aim) - from
				else (if #stop.route > 0 then flat(stop.route[1]) - from else nil)
			return from, if facing and facing.Magnitude > 1e-3 then facing.Unit else nil, i, 0
		end
		if t < stop.arrive then
			local u = (t - stop.leave) / math.max(stop.arrive - stop.leave, 1e-3)
			local p, heading = along(from, stop.route, PetDash.ease(u))
			return p, heading, i, PetDash.ease(u)
		end
	end
	local last = #stops
	local finish = if last > 0 then fromOf(plan, last + 1) else plan.start
	return finish, nil, last + 1, 1
end

--[[
	Which frame of the Attack clip the fox shows `t` seconds into `plan`:
	its crouch over the windup, its lunge over each run to an enemy, its
	slash held there, and its lunge back over the run home.
]]
function PetDash.clipTime(plan: Plan, t: number, clip: Clip): number
	local stops = plan.stops
	local first = stops[1]
	if not first or t < first.leave then
		return clip.out * math.clamp(t / math.max(first and first.leave or 1, 1e-3), 0, 1)
	end
	for i, stop in stops do
		local home = stop.aim == nil
		local span = math.max(stop.arrive - stop.leave, 1e-3)
		if t < stop.leave then
			-- slashing at the stop before: the lunge's held pose
			local before = stops[i - 1]
			local dwell = math.max(stop.leave - before.arrive, 1e-3)
			return clip.hit + (clip.back - clip.hit) * (t - before.arrive) / dwell
		end
		if t < stop.arrive then
			local u = (t - stop.leave) / span
			if home then
				return clip.back + (clip.home - clip.back) * u
			end
			return clip.out + (clip.hit - clip.out) * u
		end
	end
	return clip.home
end

return PetDash
