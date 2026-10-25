--!strict
--[[
	The Broodmother's Web Walker (owner, 2026-10-25): a web as wide as
	nearly the whole room, centred on her and spinning clockwise like a
	horse walker. Under the web is the danger; outside it the player walks
	round with the spokes, whose arms reach on across the floor to the
	walls and sweep whoever stops.

	Pure, shared by the server (`Enemies/BossMoves`, who gets hit) and the
	client (`Fx/BroodWheelFx`, what is drawn), so the spokes drawn are the
	spokes that hit. Angles are about +Y on the floor, measured from +X
	toward +Z, so a growing angle turns clockwise seen from the top-down
	camera (north, -Z, at the top of the screen).
]]

local WebWheel = {}

export type Spec = {
	spokes: number,
	radius: number,
	reach: number,
	width: number,
	period: number,
}

--[[ The angle of spoke one `t` seconds into the spin. ]]
function WebWheel.angle(start: number, period: number, t: number): number
	return start + 2 * math.pi * t / period
end

--[[ The start angle that points spoke one along `direction`. ]]
function WebWheel.angleOf(direction: Vector3): number
	return math.atan2(direction.Z, direction.X)
end

--[[ The floor direction of spoke `k` (1-based) when spoke one is at `angle`. ]]
function WebWheel.spoke(angle: number, k: number, spokes: number): Vector3
	local a = angle + (k - 1) * 2 * math.pi / spokes
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

--[[
	What of the web touches a body `pad` studs across its middle at `point`,
	with the web centred on `centre` and spoke one at `angle`: "web" under
	the web itself, "arm" against a spoke's arm out past it, or nil.
]]
function WebWheel.hit(
	spec: Spec,
	centre: Vector3,
	angle: number,
	point: Vector3,
	pad: number
): string?
	local offset = Vector3.new(point.X - centre.X, 0, point.Z - centre.Z)
	local distance = offset.Magnitude
	if distance <= spec.radius + pad then
		return "web"
	end
	if distance > spec.reach + pad then
		return nil
	end
	for k = 1, spec.spokes do
		local along = WebWheel.spoke(angle, k, spec.spokes)
		local ahead = offset:Dot(along)
		local across = math.abs(offset.X * along.Z - offset.Z * along.X)
		if ahead > 0 and across <= spec.width / 2 + pad then
			return "arm"
		end
	end
	return nil
end

--[[ The way the web sweeps a point it is passing (clockwise, round its
     centre), for the push an arm gives. ]]
function WebWheel.sweep(centre: Vector3, point: Vector3): Vector3
	local offset = Vector3.new(point.X - centre.X, 0, point.Z - centre.Z)
	if offset.Magnitude < 1e-3 then
		return Vector3.xAxis
	end
	return Vector3.new(-offset.Z, 0, offset.X).Unit
end

return WebWheel
