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

--[[
	Copies every spec to each of the given angle offsets, keeping the originals.

	One stage serves Rear, Side and Diagonal Arrows, because all three are the
	same idea with different numbers — which is the test of whether the
	pipeline is pulling its weight. It runs in the Pattern bucket, after Count,
	so a player holding Front Arrow fires the whole widened fan backwards too
	rather than a single arrow.
]]
function Stages.mirror(name: string, offsets: { number }): ShotStage
	return {
		name = name,
		order = ShotPipeline.Stage.Pattern,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			if #offsets == 0 then
				return specs
			end

			local out: { ShotSpec } = {}

			for _, spec in specs do
				table.insert(out, spec)

				for _, offset in offsets do
					local copy = table.clone(spec)
					copy.angleOffset = spec.angleOffset + offset
					table.insert(out, copy)
				end
			end

			return out
		end,
	}
end

--[[ Raises how many enemies an arrow passes through. Additive, because the
     interesting number to a player is "how many", not "how much more". ]]
function Stages.pierce(extra: number): ShotStage
	return {
		name = "Pierce",
		order = ShotPipeline.Stage.Flight,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy.pierce = spec.pierce + extra
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[
	Scales a numeric field on every spec.

	Speed, lifetime and damage are the same operation on different fields, and
	writing three near-identical stages is how they drift apart. `scale` is the
	multiplier applied to whatever the spec already carries, so stacking
	compounds rather than overwriting — which is also what stops a second copy
	of an ability being worth nothing.
]]
function Stages.scale(
	name: string,
	field: "speed" | "lifetime" | "damageScale",
	by: number
): ShotStage
	return {
		name = name,
		order = ShotPipeline.Stage.Flight,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy[field] = (spec :: any)[field] * by
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[
	Sets the crit chance and multiplier the server will roll against on
	contact.

	Set rather than accumulated: the caller already knows the total from the
	player's whole loadout, and a stage that added to whatever was there would
	make the result depend on how many times the pipeline had been rebuilt.
]]
function Stages.crit(chance: number, multiplier: number): ShotStage
	return {
		name = "Crit",
		order = ShotPipeline.Stage.OnHit,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy.critChance = math.clamp(chance, 0, 1)
				copy.critMultiplier = multiplier
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[
	Gives every arrow an explosion on contact.

	Radius and scale together, because a splash with no radius and a splash
	for no damage are both just a slower way of writing "off", and splitting
	them across two stages would let a loadout produce either.
]]
function Stages.splash(radius: number, scale: number): ShotStage
	return {
		name = "Splash",
		order = ShotPipeline.Stage.OnHit,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy.splashRadius = radius
				copy.splashScale = scale
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[ Lets arrows reflect off the arena instead of stopping at it. Flight
     rather than OnHit: it changes where the arrow goes, not what it does when
     it arrives. ]]
function Stages.bounce(count: number): ShotStage
	return {
		name = "Bounce",
		order = ShotPipeline.Stage.Flight,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy.bounces = spec.bounces + count
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[ Lets arrows curve towards the nearest enemy ahead of them, at `rate`
     radians a second. Flight: it changes where an arrow goes, and the
     turning itself happens in ProjectileFlight on both sides. ]]
function Stages.homing(rate: number): ShotStage
	return {
		name = "Homing",
		order = ShotPipeline.Stage.Flight,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy.homing = spec.homing + rate
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[ Sends an arrow on to the nearest other enemy after each hit. OnHit
     rather than Flight: where it goes next is decided by what it struck,
     which is only known at the moment of contact. ]]
function Stages.ricochet(count: number): ShotStage
	return {
		name = "Ricochet",
		order = ShotPipeline.Stage.OnHit,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy.ricochet = spec.ricochet + count
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[ Sets every arrow to burn what it hits for `fraction` of its damage a
     second, for `duration` seconds. Set rather than accumulated, like crit:
     the caller passes the loadout's total. OnHit, because only contact
     decides what burns. ]]
function Stages.burn(fraction: number, duration: number): ShotStage
	return {
		name = "Burn",
		order = ShotPipeline.Stage.OnHit,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy.burn = fraction
				copy.burnDuration = duration
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[ Sets the extra damage a hit earns for distance flown. OnHit: how far
     the arrow went is only known when it arrives. ]]
function Stages.farDamage(bonus: number): ShotStage
	return {
		name = "FarDamage",
		order = ShotPipeline.Stage.OnHit,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy.farBonus = bonus
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[ Links up to `others` enemies near whatever an arrow hits, to share in
     the hit. OnHit, because who is nearby is only known on contact. ]]
function Stages.link(others: number): ShotStage
	return {
		name = "Link",
		order = ShotPipeline.Stage.OnHit,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			local out: { ShotSpec } = {}

			for _, spec in specs do
				local copy = table.clone(spec)
				copy.link = others
				table.insert(out, copy)
			end

			return out
		end,
	}
end

--[[
	Fires the whole volley again `extra` more times, `interval` seconds apart.

	Count rather than Pattern: it makes more arrows. But where `parallel`
	puts them beside each other, this puts them *behind* — same aim, same
	lane, a moment later — so a target that sidestepped the first volley
	walks into the second. Copies keep every other field, so a lane of Front
	Arrows is repeated as a lane.
]]
function Stages.repeatVolley(extra: number, interval: number): ShotStage
	return {
		name = "RepeatVolley",
		order = ShotPipeline.Stage.Count,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			if extra <= 0 then
				return specs
			end

			local out: { ShotSpec } = {}

			for _, spec in specs do
				table.insert(out, spec)
			end

			for round = 1, extra do
				for _, spec in specs do
					local copy = table.clone(spec)
					copy.delay = spec.delay + round * interval
					table.insert(out, copy)
				end
			end

			return out
		end,
	}
end

--[[
	Widens a volley into `count` arrows flying side by side.

	The Count-bucket counterpart to `spread`. Both make more arrows; this one
	keeps them on the same heading and offsets them sideways instead, so they
	stay a lane all the way to the target rather than separating with
	distance. That is what an extra-arrow upgrade should do — more damage into
	the thing you aimed at, not a wider miss.

	Centred, so an odd count keeps one arrow exactly on the line the player
	aimed along and an even one straddles it evenly.
]]
function Stages.parallel(count: number, spacing: number): ShotStage
	return {
		name = "Parallel",
		order = ShotPipeline.Stage.Count,

		apply = function(specs: { ShotSpec }, _request: ShotRequest): { ShotSpec }
			if count <= 1 then
				return specs
			end

			local out: { ShotSpec } = {}
			local first = -(count - 1) / 2 * spacing

			for _, spec in specs do
				for index = 0, count - 1 do
					local copy = table.clone(spec)
					copy.lateralOffset = spec.lateralOffset + first + index * spacing
					table.insert(out, copy)
				end
			end

			return out
		end,
	}
end

return Stages
