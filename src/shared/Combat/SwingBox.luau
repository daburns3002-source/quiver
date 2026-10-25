--!strict
--[[
	Where a melee blow lands (`Config/Classes.swing`; owner, 2026-10-23: "the
	hitbox and slash should both be an arc for the first two swings and a
	circle in front of the player for the last slam and they should all
	still scale with the upgrades").

	- **An arc** for the side-to-side blows: a slice of a circle round the
	  swinger, `reach` studs out and `arc` degrees wide, centred on the
	  swing's direction.
	- **A circle** for the combo's last blow, the slam: `slamRadius` across,
	  centred `slamAhead` studs in front.

	Cleave widens both (the arc's angle, the circle's size) and Long Reach
	carries both further (`shape`). A body counts when any of its width
	reaches into the shape, including one pressed against the swinger; one
	wholly behind does not. Height never decides a hit.

	Pure geometry, so `tests/SwingBox.spec` can pin its edges; the server
	asks `hits` for every enemy as a blow lands (`Combat/MeleeSystem`), and
	the client draws the red of the swing over exactly the same shape
	(`Shared/Combat/SwingSweep`).
]]

local SwingBox = {}

export type Kind = "Arc" | "Circle"

export type Shape = {
	kind: Kind,
	--[[ The arc's: how far out, and how wide in degrees. ]]
	reach: number,
	arc: number,
	--[[ The circle's: its radius, and how far in front its centre is. ]]
	radius: number,
	ahead: number,
}

--[[ The parts of a class's `swing` this needs. ]]
export type SwingConfig = {
	reach: number,
	arc: number,
	slamRadius: number,
	slamAhead: number,
}

--[[ An arc never wraps past a full turn, however much Cleave is held. ]]
local FULL_TURN = 360

--[[ The shape of blow `blow` of `blows`, grown by Cleave's `widthScale`
     and Long Reach's `reachBonus`. ]]
function SwingBox.shape(
	swing: SwingConfig,
	blow: number,
	blows: number,
	widthScale: number,
	reachBonus: number
): Shape
	if blow >= blows then
		return {
			kind = "Circle",
			reach = 0,
			arc = 0,
			radius = swing.slamRadius * widthScale,
			ahead = swing.slamAhead + reachBonus,
		}
	end
	return {
		kind = "Arc",
		reach = swing.reach + reachBonus,
		arc = math.min(swing.arc * widthScale, FULL_TURN),
		radius = 0,
		ahead = 0,
	}
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--[[ Whether a body at `at`, `halfWidth` across, is in the blow: `from` is
     the swinger's position, `direction` the way it swings. ]]
function SwingBox.hits(
	shape: Shape,
	from: Vector3,
	direction: Vector3,
	at: Vector3,
	halfWidth: number
): boolean
	local forward = flat(direction)
	if forward.Magnitude < 1e-6 then
		return false
	end
	forward = forward.Unit

	if shape.kind == "Circle" then
		local centre = flat(from) + forward * shape.ahead
		return (flat(at) - centre).Magnitude <= shape.radius + halfWidth
	end

	local offset = flat(at) - flat(from)
	local distance = offset.Magnitude
	-- Pressed against the swinger: struck, whichever way it faces.
	if distance <= halfWidth then
		return true
	end
	if distance > shape.reach + halfWidth then
		return false
	end
	local cosine = math.clamp(offset.Unit:Dot(forward), -1, 1)
	local angle = math.deg(math.acos(cosine))
	--[[ The body's own width lets it reach in past the arc's edge. ]]
	local allowance = math.deg(math.asin(math.min(1, halfWidth / distance)))
	return angle <= shape.arc / 2 + allowance
end

--[[ Whirlwind's spin: a circle `radius` across round the swinger itself,
     grown by Cleave as the slam's circle is. ]]
function SwingBox.spin(radius: number, widthScale: number): Shape
	return { kind = "Circle", reach = 0, arc = 0, radius = radius * widthScale, ahead = 0 }
end

--[[ Shockwave: whether a body at `at`, `halfWidth` across, is in the lane a
     slam's wave rolls down — from `ahead` studs in front of `from`, `length`
     studs on along `direction`, `width` wide — and if so how far along the
     lane it stands (nil when outside), so the wave can reach it on time. ]]
function SwingBox.waveAlong(
	from: Vector3,
	direction: Vector3,
	ahead: number,
	length: number,
	width: number,
	at: Vector3,
	halfWidth: number
): number?
	local forward = flat(direction)
	if forward.Magnitude < 1e-6 or length <= 0 then
		return nil
	end
	forward = forward.Unit
	local offset = flat(at) - (flat(from) + forward * ahead)
	local along = offset:Dot(forward)
	local across = (offset - forward * along).Magnitude
	if along < -halfWidth or along > length + halfWidth or across > width / 2 + halfWidth then
		return nil
	end
	return math.max(along, 0)
end

return SwingBox
