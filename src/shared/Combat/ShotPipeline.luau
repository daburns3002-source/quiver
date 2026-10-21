--!strict
--[[
	The projectile modifier pipeline.

	This is the core abstraction of the whole game. Every ability in Phase 3 is a
	stage inserted here, never an `if` branch in the firing code. Front Arrow
	adds specs; Ricochet sets a bounce count; Piercing Shot raises pierce. The
	firing system stays the same size whether there are two abilities or eighty.

	Stages run in bucket order:

		Count   → how many projectiles exist
		Pattern → where they point
		Flight  → how they travel
		OnHit   → what they do on contact
		OnKill  → what they do when the target dies

	Within a bucket, stages run in the order they were added. Phase 1 registers
	no stages at all, so a build returns exactly one projectile — but the seam is
	here and everything downstream already speaks in lists.

	Stages must treat their input as immutable and return a new list. That makes
	a stage safe to reorder, remove, or run twice while debugging a build.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

type ShotSpec = Types.ShotSpec
type ShotRequest = Types.ShotRequest
type ShotStage = Types.ShotStage

type StageEntry = {
	stage: ShotStage,
	-- Tie-breaker so stages in the same bucket keep insertion order after a
	-- sort, which `table.sort` does not guarantee on its own.
	sequence: number,
}

local ShotPipeline = {}
ShotPipeline.__index = ShotPipeline

--[[
	Bucket boundaries. Abilities pick a bucket rather than an absolute number so
	two unrelated abilities never fight over a magic ordering value.
]]
ShotPipeline.Stage = table.freeze({
	Count = 100,
	Pattern = 200,
	Flight = 300,
	OnHit = 400,
	OnKill = 500,
})

type Fields = {
	_stages: { StageEntry },
	_nextSequence: number,
	_sorted: boolean,
}

--[[
	A pipeline belongs to one shooter. Each player's run session owns its own, so
	one player's abilities can never leak into another's — the project is
	co-op-shaped from the first line.
]]
function ShotPipeline.new(): ShotPipeline
	local self = setmetatable({} :: Fields, ShotPipeline)
	self._stages = {}
	self._nextSequence = 0
	self._sorted = true
	return self
end

--[[
	Adds a stage. Adding the same name twice is allowed and intentional: Front
	Arrow +1 stacks by being present more than once, rather than by carrying a
	level counter that every stage would have to understand.
]]
function ShotPipeline.addStage(self: ShotPipeline, stage: ShotStage)
	self._nextSequence += 1
	table.insert(self._stages, { stage = stage, sequence = self._nextSequence })
	self._sorted = false
end

--[[
	Removes one instance of a named stage, the most recently added. Returns
	whether anything was removed.
]]
function ShotPipeline.removeStage(self: ShotPipeline, name: string): boolean
	for index = #self._stages, 1, -1 do
		if self._stages[index].stage.name == name then
			table.remove(self._stages, index)
			return true
		end
	end

	return false
end

--[[ How many instances of a named stage are present. ]]
function ShotPipeline.countStage(self: ShotPipeline, name: string): number
	local count = 0

	for _, entry in self._stages do
		if entry.stage.name == name then
			count += 1
		end
	end

	return count
end

function ShotPipeline.clear(self: ShotPipeline)
	table.clear(self._stages)
	self._sorted = true
end

local function compareEntries(a: StageEntry, b: StageEntry): boolean
	if a.stage.order ~= b.stage.order then
		return a.stage.order < b.stage.order
	end

	return a.sequence < b.sequence
end

--[[
	Resolves a request into the projectiles it actually produces.

	Called once per volley, not per projectile, so the cost is in stage count
	rather than shot count.
]]
function ShotPipeline.build(self: ShotPipeline, request: ShotRequest): { ShotSpec }
	if not self._sorted then
		table.sort(self._stages, compareEntries)
		self._sorted = true
	end

	local specs: { ShotSpec } = {
		{
			angleOffset = 0,
			lateralOffset = 0,
			damageScale = 1,
			speed = request.speed,
			lifetime = request.lifetime,
			pierce = 0,
			--[[ No crit until an OnHit stage says otherwise. A multiplier of
			     2 is the resting value rather than 1, so an ability that only
			     grants *chance* does not also have to remember to set the
			     payoff. ]]
			critChance = 0,
			critMultiplier = 2,
			splashRadius = 0,
			splashScale = 0,
			bounces = 0,
			chainOnKill = 0,
		},
	}

	for _, entry in self._stages do
		specs = entry.stage.apply(specs, request)
	end

	return specs
end

--[[
	Turns a spec's `angleOffset` into a world direction.

	Lives here beside the thing that produced the offsets, because every
	consumer of a built volley needs exactly this and three hand-rolled copies
	of the same rotation is three chances to disagree about the sign.
]]
function ShotPipeline.aim(direction: Vector3, spec: ShotSpec): Vector3
	local radians = spec.angleOffset

	if radians == 0 then
		return direction
	end

	local cos = math.cos(radians)
	local sin = math.sin(radians)

	return Vector3.new(
		direction.X * cos - direction.Z * sin,
		0,
		direction.X * sin + direction.Z * cos
	)
end

--[[
	Where an arrow actually starts.

	Lives beside `aim` for the same reason: every consumer of a built volley
	needs exactly this, and three hand-rolled copies of the same perpendicular
	is three chances to disagree about which way is left. The server, the
	client's prediction and the renderer all call it, which is what keeps a
	parallel volley parallel on screen *and* in the simulation.

	Perpendicular to the arrow's own aim rather than the volley's, so a
	mirrored copy fired backwards offsets along its own lane.
]]
function ShotPipeline.spawnPoint(origin: Vector3, aim: Vector3, spec: ShotSpec): Vector3
	if spec.lateralOffset == 0 then
		return origin
	end

	local right = Vector3.new(aim.Z, 0, -aim.X)
	if right.Magnitude < 1e-3 then
		return origin
	end

	return origin + right.Unit * spec.lateralOffset
end

export type ShotPipeline = typeof(setmetatable({} :: Fields, ShotPipeline))

return ShotPipeline
