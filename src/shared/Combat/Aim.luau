--!strict
--[[
	Where the archer aims: at the nearest enemy it can actually hit.

	The rule used to be "nearest, cover be damned" — an arrow into a pillar
	was the price of letting an enemy shelter. Playtest footage (2026-10-22)
	showed what that costs: a beetle half out from behind a pillar, in plain
	view, and every arrow for three seconds landing in the stone beside it.
	The owner asked for the arrows to hit what the player can see.

	So, for each enemy in range, nearest first:
	1. the line to its centre, if that is clear;
	2. otherwise the line to either edge of it, so a half-hidden enemy is shot
	   in the half that shows;
	and the first clear line wins. Only when no enemy has a clear line does
	the archer aim at the nearest anyway — into cover, as before.

	One rule for both sides. The server decides what is fired; the client
	predicts it and draws the target ring, and both ask this with the same
	geometry. `isClear` is supplied by each side, since each casts against
	its own copy of the arena.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local Aim = {}

--[[ Where a player's arrows leave from: under the archer, at the arrow
     height (`Balance.Projectile.height`) rather than at the body's chest.
     The server fires from here and the client predicts from here, so the
     drawn volley and the counted one fly the same line. ]]
function Aim.shotOrigin(rootPosition: Vector3): Vector3
	return Vector3.new(rootPosition.X, Balance.Projectile.height, rootPosition.Z)
end

export type Candidate = {
	model: Model,
	position: Vector3,
	--[[ Half the enemy's width across the line of fire. ]]
	halfWidth: number,
}

export type Choice = {
	model: Model,
	--[[ The enemy's centre, for distance and for anything that wants it. ]]
	position: Vector3,
	--[[ The point to fire at: the centre, or the edge that can be hit. ]]
	aimPoint: Vector3,
	distance: number,
	clear: boolean,
}

--[[ How far toward its edge an enemy is aimed at when its centre is
     hidden, as a share of its half-width. Inside the edge, so the arrow
     strikes the body rather than grazing past it. ]]
Aim.EDGE_SHARE = 0.7

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--[[
	The points worth trying on `candidate` from `origin`: its centre, then
	each edge across the line of fire.
]]
function Aim.points(origin: Vector3, candidate: Candidate): { Vector3 }
	local centre = candidate.position
	local line = flat(centre - origin)
	if line.Magnitude < 1e-4 then
		return { centre }
	end

	local across = Vector3.new(-line.Z, 0, line.X).Unit * candidate.halfWidth * Aim.EDGE_SHARE
	return { centre, centre + across, centre - across }
end

--[[
	The enemy to shoot and where, or nil when none is within `range`.
	`isClear(from, to)` says whether an arrow from `from` reaches `to`
	without striking the arena.
]]
function Aim.choose(
	origin: Vector3,
	candidates: { Candidate },
	range: number,
	isClear: (from: Vector3, to: Vector3) -> boolean
): Choice?
	local inRange: { { candidate: Candidate, distance: number } } = {}
	for _, candidate in candidates do
		local distance = flat(candidate.position - origin).Magnitude
		if distance <= range then
			table.insert(inRange, { candidate = candidate, distance = distance })
		end
	end

	if #inRange == 0 then
		return nil
	end

	table.sort(inRange, function(a, b)
		return a.distance < b.distance
	end)

	for _, entry in inRange do
		for _, point in Aim.points(origin, entry.candidate) do
			if isClear(origin, point) then
				return {
					model = entry.candidate.model,
					position = entry.candidate.position,
					aimPoint = point,
					distance = entry.distance,
					clear = true,
				}
			end
		end
	end

	-- Nothing in the open: the nearest, into its cover.
	local nearest = inRange[1]
	return {
		model = nearest.candidate.model,
		position = nearest.candidate.position,
		aimPoint = nearest.candidate.position,
		distance = nearest.distance,
		clear = false,
	}
end

--[[
	A clear-line test against the arena's blockers, shared by both sides: a
	box the arrow's width swept from `from` to `to` at the arrow's height.
	Returns a function for `Aim.choose`.
]]
function Aim.clearTest(blockers: Instance?, arrowRadius: number): (Vector3, Vector3) -> boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = if blockers then { blockers } else {}

	return function(from: Vector3, to: Vector3): boolean
		if not blockers then
			return true
		end
		local target = Vector3.new(to.X, from.Y, to.Z)
		local delta = target - from
		if delta.Magnitude < 1e-3 then
			return true
		end
		local size = Vector3.new(arrowRadius * 2, arrowRadius * 2, 0.1)
		local hit = Workspace:Blockcast(CFrame.lookAt(from, target), size, delta, params)
		return hit == nil
	end
end

return Aim
