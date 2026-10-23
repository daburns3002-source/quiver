--!strict
--[[
	The red of a melee swing, drawn on its hitbox (owner, 2026-10-23: "the
	red slash should still look like its slashing ... an arc for the first
	two swings and a circle in front of the player for the last slam").

	A ribbon (`Fx/SwingTrail`) runs between two points this moves over the
	swing, so by its end the ribbon has painted exactly the blow's shape
	(`SwingBox.shape`) and nothing outside it:

	- an arc: a line from the swinger out to the arc's rim, swept across
	  its angle like a blade, right to left or left to right;
	- the slam's circle: a line from its centre to its edge, spun once round.

	Pure geometry in the swing's own space (forward is -Z, from the
	swinger), so `tests/SwingSweep.spec` can pin it to the shape.
]]

local SwingBox = require(script.Parent.SwingBox)

local SwingSweep = {}

export type Sweep = "LeftToRight" | "RightToLeft" | "Spin"

--[[ Which way a blow sweeps: the combo's last blow is the slam, spun
     round its circle; the others alternate side to side. ]]
function SwingSweep.forBlow(blow: number, blows: number): Sweep
	local sweep: Sweep = if blow >= blows
		then "Spin"
		elseif blow % 2 == 1 then "RightToLeft"
		else "LeftToRight"
	return sweep
end

--[[ A direction `degrees` round from forward (-Z), clockwise seen from
     above, so positive is to the right (+X). ]]
local function heading(degrees: number): Vector3
	local r = math.rad(degrees)
	return Vector3.new(math.sin(r), 0, -math.cos(r))
end

--[[ The ribbon's two ends `progress` (0 to 1) through the swing. ]]
function SwingSweep.edge(shape: SwingBox.Shape, sweep: Sweep, progress: number): (Vector3, Vector3)
	local p = math.clamp(progress, 0, 1)
	if shape.kind == "Circle" then
		local centre = Vector3.new(0, 0, -shape.ahead)
		return centre, centre + heading(360 * p) * shape.radius
	end
	local half = shape.arc / 2
	local degrees = if sweep == "RightToLeft" then half - shape.arc * p else -half + shape.arc * p
	return Vector3.zero, heading(degrees) * shape.reach
end

return SwingSweep
