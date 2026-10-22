--!strict
--[[
	Target selection.

	Plain nearest-by-distance, for what has no line of fire to worry about:
	a ricochet or a chain picking its next enemy. The archer's own aim is
	`Shared/Combat/Aim`, which prefers an enemy it can actually hit — the
	owner changed that rule after playtest footage of arrows striking a pillar
	beside a plainly visible enemy (2026-10-22).
]]

export type Target = {
	model: Model,
	position: Vector3,
	distance: number,
}

local Targeting = {}

--[[
	Nearest candidate to `origin` within `maxDistance`, or nil.

	`candidates` maps a Model to its current world position, which the enemy
	manager already tracks — re-reading PrimaryPart.Position per query would cost
	a property read per enemy per shot.
]]
function Targeting.nearest(
	origin: Vector3,
	candidates: { [Model]: Vector3 },
	maxDistance: number
): Target?
	local bestModel: Model? = nil
	local bestPosition = Vector3.zero
	local bestDistance = maxDistance

	for model, position in candidates do
		local distance = (position - origin).Magnitude

		if distance <= bestDistance then
			bestModel = model
			bestPosition = position
			bestDistance = distance
		end
	end

	if not bestModel then
		return nil
	end

	return {
		model = bestModel :: Model,
		position = bestPosition,
		distance = bestDistance,
	}
end

--[[ Flattens a direction onto the XZ plane. Returns nil if there is none. ]]
function Targeting.flatDirection(from: Vector3, to: Vector3): Vector3?
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)

	if delta.Magnitude < 1e-4 then
		return nil
	end

	return delta.Unit
end

return Targeting
