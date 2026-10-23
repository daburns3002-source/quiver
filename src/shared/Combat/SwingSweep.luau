--!strict
--[[
	The red of a melee swing, drawn on its hitbox (owner, 2026-10-23: "the
	red on the swing should be exactly the hitbox of the sword", and grow
	with the cards that grow it).

	The swing's box (`SwingBox`) stands in front of the swinger: `width`
	across, `depth` deep. A ribbon (`Fx/SwingTrail`) is drawn between two
	points that this sweeps over the swing, so by its end the ribbon has
	painted exactly that box and nothing outside it: a side-to-side blow
	sweeps a line the box's depth long across its width, the slam sweeps a
	line its width wide from the swinger out to its far edge.

	Pure geometry in the swing's own space (forward is -Z, from the
	swinger), so `tests/SwingSweep.spec` can pin it to the box.
]]

local SwingSweep = {}

export type Sweep = "LeftToRight" | "RightToLeft" | "Outward"

--[[ Which way a blow sweeps: the combo's last blow is the slam, coming
     down and out; the others alternate side to side. ]]
function SwingSweep.forBlow(blow: number, blows: number): Sweep
	if blow >= blows then
		return "Outward"
	end
	return if blow % 2 == 1 then "RightToLeft" else "LeftToRight"
end

--[[ The ribbon's two ends `progress` (0 to 1) through the swing. ]]
function SwingSweep.edge(
	width: number,
	depth: number,
	sweep: Sweep,
	progress: number
): (Vector3, Vector3)
	local p = math.clamp(progress, 0, 1)
	local half = width / 2
	if sweep == "Outward" then
		local z = -depth * p
		return Vector3.new(-half, 0, z), Vector3.new(half, 0, z)
	end
	local x = if sweep == "RightToLeft" then half - width * p else -half + width * p
	return Vector3.new(x, 0, 0), Vector3.new(x, 0, -depth)
end

return SwingSweep
