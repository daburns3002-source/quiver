--!strict
--[[
	Reusable shot-pipeline stages.

	These exist so a firing pattern is a *data choice* rather than code. The
	spread below is what a Spitter fires and what Diagonal Arrows will do for
	the player in Phase 3 — same stage, different owner. That symmetry is the
	point: if enemy attacks and player abilities share one pipeline, a biome's
	roster becomes a table of stage configurations instead of a new behaviour
	module per enemy. See CLAUDE.md, non-negotiable 1.

	Stages must treat their input as immutable and return a new list.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Types = require(ReplicatedStorage.Shared.Types)

type ShotSpec = Types.ShotSpec
type ShotRequest = Types.ShotRequest
type ShotStage = Types.ShotStage

local Stages = {}

--[[
	Fans every spec into `count` evenly spaced copies, `angle` radians apart,
	centred on the direction it already had.

	An odd `count` keeps one projectile exactly on the original heading, which
	is why the Spitter uses three rather than two: a fan with nothing down the
	middle reads as "miss on purpose" instead of "walk through the gap".
]]
function Stages.spread(count: number, angle: number): ShotStage
	return {
		name = "Spread",
		order = ShotPipeline.Stage.Pattern,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			if count <= 1 then
				return specs
			end

			local fanned: { ShotSpec } = {}
			local first = -(count - 1) / 2 * angle

			for _, spec in specs do
				for index = 0, count - 1 do
					local copy = table.clone(spec)
					copy.angleOffset = spec.angleOffset + first + index * angle
					table.insert(fanned, copy)
				end
			end

			return fanned
		end,
	}
end

return Stages
