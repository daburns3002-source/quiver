--!strict
--[[
	The Windswept Cliffs' edges (docs/WINDSWEPT-CLIFFS.md, "The edges";
	owner, 2026-11-26: "Fall: 12% health").

	The rooms are cliff tops: their walls and their void strips (the gap a
	bridge crosses, `Balance.Obstacle.void`) are drops. Walking never takes
	anyone off -- they are walls to feet -- but a push can: a Gust Shaman's
	gust, a Cliff Goat's charge, the Tempest Roc's wing gust. So a fall is
	read from the push itself, before the client walks it: if its line
	leaves the floor, the player falls where it does.

	Pure, so `tests/CliffEdges.spec` runs it without a room: a room is its
	half size and its void boxes, in floor coordinates (X, Z).
]]

local CliffEdges = {}

export type Void = { centre: Vector2, halfExtents: Vector2 }

--[[ A fall's cost, as a share of max health, and how long the player is
     untouchable after landing. ]]
CliffEdges.share = 0.12
CliffEdges.grace = 1
--[[ Studs back onto the floor a fall lands, from where the push left it. ]]
CliffEdges.setBack = 2.5
--[[ Studs between samples along a push. ]]
local STEP = 0.5

--[[ Whether a body `radius` across its middle at `point` is off the floor:
     past a wall's line, or over a void strip. ]]
function CliffEdges.off(point: Vector2, half: Vector2, voids: { Void }, radius: number): boolean
	if math.abs(point.X) > half.X + radius or math.abs(point.Y) > half.Y + radius then
		return true
	end
	for _, void in voids do
		local d = point - void.centre
		if
			math.abs(d.X) < void.halfExtents.X - radius
			and math.abs(d.Y) < void.halfExtents.Y - radius
		then
			return true
		end
	end
	return false
end

--[[
	Where a push from `from` along `direction` for `distance` studs leaves
	the floor: how far along it the player goes over, and where they land
	again (`setBack` studs back along the push, on the floor they were
	pushed across). Nil when the push stays on the floor.

	`radius` is how far past an edge the body's middle must be carried for
	it to count: the player's half width, so a push that only presses them
	against the edge is not a fall. `blocked` says where cover stands: a
	push that meets cover first stops there, as walking does, and nobody
	falls.
]]
function CliffEdges.crossing(
	from: Vector2,
	direction: Vector2,
	distance: number,
	half: Vector2,
	voids: { Void },
	radius: number,
	blocked: ((Vector2) -> boolean)?
): (number?, Vector2?)
	if direction.Magnitude < 1e-3 or distance <= 0 then
		return nil, nil
	end
	local along = direction.Unit
	if CliffEdges.off(from, half, voids, radius) then
		return nil, nil
	end
	local t = STEP
	while t <= distance + 1e-6 do
		local point = from + along * t
		if blocked and blocked(point) then
			return nil, nil
		end
		if CliffEdges.off(point, half, voids, radius) then
			local back = math.max(0, t - CliffEdges.setBack)
			return t, from + along * back
		end
		t += STEP
	end
	return nil, nil
end

return CliffEdges
