--!strict
--[[
	Plays a `Config/PetGaits` entry: where a pet is on its way to its place,
	and how its whole body is posed there. Pure, so it can be tested, and a few
	sums a pet a frame, so it costs a phone nothing next to the clips.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetGaits = require(ReplicatedStorage.Shared.Config.PetGaits)

local PetGait = {}

export type State = {
	--[[ Where it is: on the floor, none of the body's sway in it. ]]
	at: Vector3,
	--[[ Whether it is on its way, and how far into it. ]]
	going: boolean,
	time: number,
	--[[ `Steps`: the beat under way and where that beat set off from. ]]
	beat: number,
	from: Vector3,
	--[[ Studs covered, which `stride` layers keep time with. ]]
	stride: number,
	--[[ How far through the change from standing (0) to moving (1). ]]
	moving: number,
	--[[ 1, or fading to 0 while its Attack clip has the body. ]]
	free: number,
	facing: Vector3,
}

--[[ Further off than this it is not walking: it has been left in another
     room, so it appears at its place. ]]
local LEASH = 40
--[[ It sets off this far from its place and is there at the second. ]]
local SET_OFF = 0.6
local ARRIVED = 0.25
--[[ How quickly it changes between standing, moving and acting. ]]
local BLEND_RATE = 8

local TAU = 2 * math.pi

function PetGait.new(at: Vector3, facing: Vector3): State
	return {
		at = at,
		going = false,
		time = 0,
		beat = 0,
		from = at,
		stride = 0,
		moving = 0,
		free = 1,
		facing = facing,
	}
end

--[[ The pace a pet has, or the plain chase of one with no entry. ]]
local PLAIN: PetGaits.Gait = table.freeze({
	pace = { kind = "Chase", rate = 6 } :: PetGaits.Pace,
	turn = 10,
	moving = {},
	idle = {},
})

function PetGait.of(key: string): PetGaits.Gait
	return PetGaits[key] or PLAIN
end

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

--[[ Moves `state.at` towards `goal` for `dt` seconds, as its pace does.
     Returns whether it is travelling, which is true through a `Steps`
     pet's standing part of the beat as well. ]]
function PetGait.advance(state: State, pace: PetGaits.Pace, goal: Vector3, dt: number): boolean
	local away = goal - state.at
	local distance = Vector3.new(away.X, 0, away.Z).Magnitude
	if distance > LEASH then
		state.at, state.from = goal, goal
		state.going, state.time, state.beat = false, 0, 0
		return false
	end
	local before = state.at
	if pace.kind == "Steps" then
		local trigger = pace.reach * 0.5
		if not state.going then
			if distance <= trigger then
				state.at = Vector3.new(before.X, goal.Y, before.Z)
				return false
			end
			state.going, state.time, state.beat, state.from = true, 0, 0, before
		end
		state.time += dt
		local beats = state.time / pace.period
		local beat = math.floor(beats)
		if beat > state.beat then
			state.beat, state.from = beat, state.at
			if distance <= trigger then
				state.going, state.time, state.beat = false, 0, 0
				return false
			end
		end
		local through = math.clamp((beats - beat - pace.from) / (pace.to - pace.from), 0, 1)
		local fromAway = goal - state.from
		local flat = Vector3.new(fromAway.X, 0, fromAway.Z)
		local length = math.min(flat.Magnitude, pace.reach)
		local landing = state.from
			+ (if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero) * length
		landing = Vector3.new(landing.X, goal.Y, landing.Z)
		state.at = state.from:Lerp(landing, smooth(through))
	else
		if not state.going and distance > SET_OFF then
			state.going, state.time = true, 0
		elseif state.going and distance < ARRIVED then
			state.going = false
		end
		if state.going then
			state.time += dt
		end
		if pace.kind == "Chase" then
			state.at = before:Lerp(goal, 1 - math.exp(-pace.rate * dt))
		elseif pace.kind == "Surge" then
			local push = ((math.sin(TAU * pace.beat * state.time) + 1) / 2) ^ 2
			local rate = pace.rate * (0.12 + 0.88 * push)
			state.at = before:Lerp(goal, 1 - math.exp(-rate * dt))
		else
			local ahead = Vector3.new(away.X, 0, away.Z)
			local left = distance
			if left > pace.leash then
				state.at += ahead.Unit * (left - pace.leash)
				left = pace.leash
			end
			local step = math.min(left, pace.speed * dt)
			if left > 1e-3 then
				state.at += ahead.Unit * step
			end
			state.at = Vector3.new(state.at.X, goal.Y, state.at.Z)
		end
	end
	local moved = state.at - before
	state.stride += Vector3.new(moved.X, 0, moved.Z).Magnitude
	return state.going
end

--[[ Eases the blends towards this frame's truth. ]]
function PetGait.blend(state: State, travelling: boolean, acting: boolean, dt: number)
	local alpha = 1 - math.exp(-BLEND_RATE * dt)
	state.moving += ((if travelling then 1 else 0) - state.moving) * alpha
	state.free += ((if acting then 0 else 1) - state.free) * alpha
end

local function value(wave: string, p: number): number
	if wave == "Sine" then
		return math.sin(TAU * p)
	elseif wave == "Wander" then
		return 0.6 * math.sin(TAU * p) + 0.4 * math.sin(TAU * p * 1.37 + 1.7)
	elseif wave == "Bounce" then
		return math.abs(math.sin(math.pi * p))
	elseif wave == "Saw" then
		return 2 * (p % 1) - 1
	elseif wave == "Snap" then
		return math.clamp(math.sin(TAU * p) * 5, -1, 1)
	elseif wave == "Pulse" then
		return ((math.sin(TAU * p) + 1) / 2) ^ 6
	elseif wave == "Turn" then
		return (p + 0.5) % 1 - 0.5
	end
	return 1 -- Hold
end

local sum = { Y = 0, Side = 0, Ahead = 0, Pitch = 0, Yaw = 0, Roll = 0 }

local function add(layers: { PetGaits.Layer }, clock: number, stride: number, weight: number)
	if weight < 1e-3 then
		return
	end
	for _, layer in layers do
		local p = (if layer.stride then stride else clock) * (layer.rate or 0) + (layer.phase or 0)
		sum[layer.axis] += value(layer.wave, p) * layer.amount * weight
	end
end

--[[ The body's pose against its place on the floor, in the pet's own space.
     `axis` is how far above its pivot it turns about, and `size` scales the
     studs, for a model drawn at another size than the pet at heel. ]]
function PetGait.pose(
	gait: PetGaits.Gait,
	clock: number,
	stride: number,
	moving: number,
	free: number,
	axis: number,
	size: number
): CFrame
	sum.Y, sum.Side, sum.Ahead, sum.Pitch, sum.Yaw, sum.Roll = 0, 0, 0, 0, 0, 0
	add(gait.moving, clock, stride, moving * free)
	add(gait.idle, clock, stride, (1 - moving) * free)
	local turned = CFrame.Angles(math.rad(sum.Pitch), math.rad(sum.Yaw), math.rad(sum.Roll))
	return CFrame.new(sum.Side * size, (sum.Y + (gait.float or 0)) * size, -sum.Ahead * size)
		* CFrame.new(0, axis, 0)
		* turned
		* CFrame.new(0, -axis, 0)
end

--[[ Swings `state.facing` towards `wanted` at the pet's own turn. ]]
function PetGait.face(state: State, wanted: Vector3, turn: number, dt: number): Vector3
	local eased = state.facing:Lerp(wanted, 1 - math.exp(-turn * dt))
	state.facing = if eased.Magnitude > 1e-3 then eased.Unit else wanted
	return state.facing
end

return PetGait
