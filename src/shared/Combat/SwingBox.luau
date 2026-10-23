--!strict
--[[
	Whether a body is inside a melee swing's box (`Config/Classes.swing`).

	The box stands on the ground in front of the swinger: `width` studs
	across, `depth` studs deep along `direction`, and as tall as anything
	gets, so height never decides a hit. A body counts when any of its
	width reaches into the box, including one standing right against the
	swinger; one wholly behind does not.

	Pure geometry, so `tests/SwingBox.spec` can pin its edges.
	`Combat/MeleeSystem` asks it for every enemy as a blow lands.
]]

local SwingBox = {}

--[[ `from` is the swinger's position, `direction` the way it swings
     (flattened here); `at` and `halfWidth` the body's centre and half its
     width. ]]
function SwingBox.contains(
	from: Vector3,
	direction: Vector3,
	width: number,
	depth: number,
	at: Vector3,
	halfWidth: number
): boolean
	local forward = Vector3.new(direction.X, 0, direction.Z)
	if forward.Magnitude < 1e-6 then
		return false
	end
	forward = forward.Unit
	local side = Vector3.new(-forward.Z, 0, forward.X)

	local offset = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
	local ahead = offset:Dot(forward)
	local across = offset:Dot(side)

	return math.abs(across) <= width / 2 + halfWidth
		and ahead >= -halfWidth
		and ahead <= depth + halfWidth
end

return SwingBox
