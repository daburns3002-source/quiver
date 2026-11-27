--!strict
--[[
	The shape of a lightning bolt between two points: a jagged main line and
	the small forks that split off it (Chain Lightning, `Fx/Upgrades/LightningFx`).

	Pure, with the randomness passed in, so `tests/ChainSoulFx.spec` can hold
	the shape to what the top-down camera can read. Every kink and every fork
	lies in the ground plane: an effect that stands upright is seen edge-on from
	above (docs/FIXES.md, "Howl Aura arrows invisible from above"). The bolt
	starts and ends exactly on its two points, and a bolt of one length always
	has the same number of pieces, so the drawing can re-kink it every few
	hundredths of a second without building or dropping a part.
]]

export type Range = { min: number, max: number }

export type Shape = {
	--[[ Studs of bolt to a segment, and the fewest and most segments. ]]
	segmentLength: number,
	minSegments: number,
	maxSegments: number,
	--[[ How far a joint is thrown off the line, as a share of one segment. ]]
	kink: number,
	--[[ Most forks on a bolt; each one this share of the bolt long, no longer
	     than `forkReach` studs, this far off the bolt's own heading
	     (radians), in this many pieces. ]]
	forks: number,
	forkShare: Range,
	forkReach: number,
	forkAngle: Range,
	forkSegments: number,
}

export type Bolt = {
	--[[ The main line's joints, first to last: one more than its segments. ]]
	main: { Vector3 },
	--[[ Each fork's joints, starting on a joint of the main line. ]]
	forks: { { Vector3 } },
}

local BoltPath = {}

local function between(random: Random, range: Range): number
	return range.min + (range.max - range.min) * random:NextNumber()
end

--[[ How many segments a bolt of `length` studs is cut into. ]]
function BoltPath.segments(length: number, shape: Shape): number
	return math.clamp(
		math.ceil(length / math.max(shape.segmentLength, 1e-3)),
		shape.minSegments,
		shape.maxSegments
	)
end

--[[ How many forks a bolt of `length` studs carries: never more than it has
     joints to hang them on. ]]
function BoltPath.forkCount(length: number, shape: Shape): number
	return math.clamp(shape.forks, 0, BoltPath.segments(length, shape) - 1)
end

function BoltPath.build(from: Vector3, to: Vector3, shape: Shape, random: Random): Bolt
	local span = to - from
	local flat = Vector3.new(span.X, 0, span.Z)
	local length = span.Magnitude
	local count = BoltPath.segments(length, shape)

	--[[ Straight up or no length at all has no side to kink to. ]]
	if flat.Magnitude < 1e-3 then
		local main: { Vector3 } = {}
		for i = 0, count do
			table.insert(main, from + span * (i / count))
		end
		return { main = main, forks = {} }
	end

	local along = flat.Unit
	local side = Vector3.new(-along.Z, 0, along.X)
	local reach = length / count * shape.kink

	local main: { Vector3 } = { from }
	--[[ Mostly alternating sides, which is what makes it a zig-zag, not a
	     wobble; the size of each throw is the random part. ]]
	local sign = if random:NextNumber() < 0.5 then -1 else 1
	for i = 1, count - 1 do
		local u = (i + (random:NextNumber() - 0.5) * 0.5) / count
		local push = sign * (0.35 + 0.65 * random:NextNumber()) * reach
		table.insert(main, from + span * u + side * push)
		if random:NextNumber() < 0.8 then
			sign = -sign
		end
	end
	table.insert(main, to)

	local forks: { { Vector3 } } = {}
	local wanted = BoltPath.forkCount(length, shape)
	--[[ Spread along the bolt, one to each stretch of it, so two forks never
	     sprout from one joint. ]]
	for f = 1, wanted do
		local low = math.floor((f - 1) * (count - 1) / wanted) + 1
		local high = math.max(low, math.floor(f * (count - 1) / wanted))
		local joint = random:NextInteger(low, high)
		local start = main[joint + 1]
		local turn = between(random, shape.forkAngle)
			* (if random:NextNumber() < 0.5 then -1 else 1)
		local heading = along * math.cos(turn) + side * math.sin(turn)
		local forkLength = math.min(between(random, shape.forkShare) * length, shape.forkReach)
		local points: { Vector3 } = { start }
		for s = 1, shape.forkSegments do
			local out = forkLength * s / shape.forkSegments
			local jitter = (random:NextNumber() - 0.5) * forkLength / shape.forkSegments * 0.6
			local across = Vector3.new(-heading.Z, 0, heading.X)
			table.insert(points, start + heading * out + across * jitter)
		end
		table.insert(forks, points)
	end

	return { main = main, forks = forks }
end

return BoltPath
