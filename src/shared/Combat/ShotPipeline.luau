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
			damageScale = 1,
			speed = request.speed,
			lifetime = request.lifetime,
			pierce = 0,
		},
	}

	for _, entry in self._stages do
		specs = entry.stage.apply(specs, request)
	end

	return specs
end

export type ShotPipeline = typeof(setmetatable({} :: Fields, ShotPipeline))

return ShotPipeline
