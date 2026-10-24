--!strict
--[[
	The maths behind playing a Claude Design model's clips
	(`Config/ModelClips/<Model>`) on the parts the owner imported. Pure, so
	`tests/ModelClip.spec` can pin it; `Fx/ModelAnimator` draws it.

	A model's joints move in its GLB's space. What a part needs is how its
	joint has moved from rest, `delta = world(t) * world(rest)^-1`, carried
	into the imported model's space by `fit`: the importer scales the model
	(by `scale`) and may turn it about Y (by `turn`), and both are read off
	the parts' rest positions rather than assumed.

	An affine is { m = 3x3 row-major, t = translation }, so a joint that
	scales carries its children's positions and sizes with it.
]]

local ModelClip = {}

export type Affine = { m: { number }, t: Vector3 }
export type Track = { times: { number }, values: { number } }
export type JointTracks = { pos: Track?, rot: Track?, scale: Track? }
export type Clip = { length: number, joints: { [string]: JointTracks } }
export type Joint = { name: string, parent: string, rest: { number } }
export type Part = { joint: string, cframe: { number }, size: { number } }
export type Model = { joints: { Joint }, parts: { [string]: Part }, clips: { [string]: Clip } }
--[[ How the import placed the model: a part at `p` in GLB space sits at
     `origin + turn * (p * scale)` in the imported model's pivot space. ]]
export type Fit = { turn: CFrame, scale: number, origin: Vector3, error: number, spread: number }

local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function mul(a: { number }, b: { number }): { number }
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7],
		a[1] * b[2] + a[2] * b[5] + a[3] * b[8],
		a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7],
		a[4] * b[2] + a[5] * b[5] + a[6] * b[8],
		a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7],
		a[7] * b[2] + a[8] * b[5] + a[9] * b[8],
		a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end

local function apply(m: { number }, v: Vector3): Vector3
	return Vector3.new(
		m[1] * v.X + m[2] * v.Y + m[3] * v.Z,
		m[4] * v.X + m[5] * v.Y + m[6] * v.Z,
		m[7] * v.X + m[8] * v.Y + m[9] * v.Z
	)
end

local function inverse(m: { number }): { number }
	local a, b, c, d, e, f, g, h, i = m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
	local A, B, C = e * i - f * h, -(d * i - f * g), d * h - e * g
	local det = a * A + b * B + c * C
	if math.abs(det) < 1e-12 then
		return table.clone(IDENTITY)
	end
	local k = 1 / det
	return {
		A * k,
		-(b * i - c * h) * k,
		(b * f - c * e) * k,
		B * k,
		(a * i - c * g) * k,
		-(a * f - c * d) * k,
		C * k,
		-(a * h - b * g) * k,
		(a * e - b * d) * k,
	}
end

--[[ A rotation quaternion and a scale as one 3x3: rotation * diag(scale). ]]
function ModelClip.trs(
	qx: number,
	qy: number,
	qz: number,
	qw: number,
	sx: number,
	sy: number,
	sz: number
): { number }
	local n = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
	if n > 0 then
		qx, qy, qz, qw = qx / n, qy / n, qz / n, qw / n
	end
	return {
		(1 - 2 * (qy * qy + qz * qz)) * sx,
		2 * (qx * qy - qz * qw) * sy,
		2 * (qx * qz + qy * qw) * sz,
		2 * (qx * qy + qz * qw) * sx,
		(1 - 2 * (qx * qx + qz * qz)) * sy,
		2 * (qy * qz - qx * qw) * sz,
		2 * (qx * qz - qy * qw) * sx,
		2 * (qy * qz + qx * qw) * sy,
		(1 - 2 * (qx * qx + qy * qy)) * sz,
	}
end

function ModelClip.compose(a: Affine, b: Affine): Affine
	return { m = mul(a.m, b.m), t = a.t + apply(a.m, b.t) }
end

function ModelClip.invert(a: Affine): Affine
	local m = inverse(a.m)
	return { m = m, t = -apply(m, a.t) }
end

function ModelClip.transform(a: Affine, p: Vector3): Vector3
	return a.t + apply(a.m, p)
end

--[[ A track's value `time` seconds in: Linear between keys (rotations
     normalised, the nearer way round), held at its ends. ]]
function ModelClip.sample(track: Track, width: number, time: number): { number }
	local times, values = track.times, track.values
	local n = #times
	local function at(k: number): { number }
		return table.move(values, (k - 1) * width + 1, k * width, 1, {})
	end
	if n == 1 or time <= times[1] then
		return at(1)
	end
	if time >= times[n] then
		return at(n)
	end
	local i = 1
	while i < n - 1 and time > times[i + 1] do
		i += 1
	end
	local u = (time - times[i]) / math.max(times[i + 1] - times[i], 1e-9)
	local a, b = at(i), at(i + 1)
	local sign = 1
	if width == 4 and a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4] < 0 then
		sign = -1
	end
	local out = {}
	for k = 1, width do
		out[k] = a[k] + (b[k] * sign - a[k]) * u
	end
	return out
end

--[[ Every joint's transform in GLB space `time` seconds into `clip` (at
     rest where the clip leaves it, or with no clip). Loops the clip. ]]
function ModelClip.pose(model: Model, clip: Clip?, time: number): { [string]: Affine }
	local t = if clip and clip.length > 0 then time % clip.length else 0
	local world: { [string]: Affine } = {}
	for _, joint in model.joints do
		local r = joint.rest
		local px, py, pz = r[1], r[2], r[3]
		local qx, qy, qz, qw = r[4], r[5], r[6], r[7]
		local sx, sy, sz = r[8], r[9], r[10]
		local tracks = clip and clip.joints[joint.name]
		if tracks then
			if tracks.pos then
				local v = ModelClip.sample(tracks.pos, 3, t)
				px, py, pz = v[1], v[2], v[3]
			end
			if tracks.rot then
				local v = ModelClip.sample(tracks.rot, 4, t)
				qx, qy, qz, qw = v[1], v[2], v[3], v[4]
			end
			if tracks.scale then
				local v = ModelClip.sample(tracks.scale, 3, t)
				sx, sy, sz = v[1], v[2], v[3]
			end
		end
		local here: Affine =
			{ m = ModelClip.trs(qx, qy, qz, qw, sx, sy, sz), t = Vector3.new(px, py, pz) }
		local parent = world[joint.parent]
		world[joint.name] = if parent then ModelClip.compose(parent, here) else here
	end
	return world
end

--[[ How far each joint has moved from rest: world(t) * world(rest)^-1. ]]
function ModelClip.deltas(
	model: Model,
	clip: Clip?,
	time: number,
	restInverse: { [string]: Affine }
): { [string]: Affine }
	local now = ModelClip.pose(model, clip, time)
	local out: { [string]: Affine } = {}
	for name, w in now do
		out[name] = ModelClip.compose(w, restInverse[name])
	end
	return out
end

function ModelClip.restInverse(model: Model): { [string]: Affine }
	local out: { [string]: Affine } = {}
	for name, w in ModelClip.pose(model, nil, 0) do
		out[name] = ModelClip.invert(w)
	end
	return out
end

--[[ The candidate turns an importer may give a Y-up model. ]]
local TURNS = {
	CFrame.new(),
	CFrame.Angles(0, math.pi, 0),
	CFrame.Angles(0, math.pi / 2, 0),
	CFrame.Angles(0, -math.pi / 2, 0),
}

--[[
	How the import placed the model, from where its parts sit at rest.
	`observed` maps part names to their rest centre in the imported model's
	pivot space and their size. The scale is the median ratio of sizes (by
	length, so a turn that swaps axes does not matter); the turn is the
	candidate that best matches the parts' layout about their centroid.
]]
function ModelClip.fit(
	model: Model,
	observed: { [string]: { position: Vector3, size: Vector3 } }
): Fit?
	local names = {}
	for name in observed do
		if model.parts[name] then
			table.insert(names, name)
		end
	end
	if #names == 0 then
		return nil
	end
	table.sort(names)
	local ratios = {}
	local dataCentroid, seenCentroid = Vector3.zero, Vector3.zero
	for _, name in names do
		local part = model.parts[name]
		local size = Vector3.new(part.size[1], part.size[2], part.size[3])
		if size.Magnitude > 1e-6 then
			table.insert(ratios, observed[name].size.Magnitude / size.Magnitude)
		end
		dataCentroid += Vector3.new(part.cframe[1], part.cframe[2], part.cframe[3])
		seenCentroid += observed[name].position
	end
	dataCentroid /= #names
	seenCentroid /= #names
	table.sort(ratios)
	local scale = if #ratios > 0 then ratios[math.ceil(#ratios / 2)] else 1
	-- how far, on average, the parts sit from their centroid: what `error` is judged against
	local spread = 0
	for _, name in names do
		spread += (observed[name].position - seenCentroid).Magnitude
	end
	spread = math.max(spread / #names, 1e-3)
	local best: Fit? = nil
	for _, turn in TURNS do
		local err = 0
		for _, name in names do
			local c = model.parts[name].cframe
			local p = (Vector3.new(c[1], c[2], c[3]) - dataCentroid) * scale
			err += ((turn * p) - (observed[name].position - seenCentroid)).Magnitude
		end
		err /= #names
		if not best or err < best.error then
			best = {
				turn = turn,
				scale = scale,
				origin = seenCentroid - turn * (dataCentroid * scale),
				error = err,
				spread = spread,
			}
		end
	end
	return best
end

--[[
	A part moved by its joint's `delta`, in the imported model's pivot
	space: its new CFrame and how its size scales along its own axes.
	`rest` is the part's rest CFrame in that space.
]]
function ModelClip.place(rest: CFrame, delta: Affine, fit: Fit): (CFrame, Vector3)
	local turn = fit.turn
	local function toGlb(v: Vector3): Vector3
		return turn:VectorToObjectSpace(v)
	end
	local function toModel(v: Vector3): Vector3
		return turn:VectorToWorldSpace(v)
	end
	-- the joint's move in model space: q' = origin + T M T^-1 (q - origin) + s T d
	local q = rest.Position - fit.origin
	local moved = fit.origin + toModel(apply(delta.m, toGlb(q))) + toModel(delta.t) * fit.scale
	local function axis(v: Vector3): Vector3
		return toModel(apply(delta.m, toGlb(v)))
	end
	local x, y, z = axis(rest.RightVector), axis(rest.UpVector), axis(-rest.LookVector)
	local lx, ly, lz = x.Magnitude, y.Magnitude, z.Magnitude
	if lx < 1e-6 or ly < 1e-6 then
		return CFrame.new(moved) * rest.Rotation, Vector3.new(lx, ly, lz)
	end
	return CFrame.fromMatrix(moved, x / lx, y / ly), Vector3.new(lx, ly, lz)
end

return ModelClip
