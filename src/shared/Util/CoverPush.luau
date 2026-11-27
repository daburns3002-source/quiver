--!strict
--[[
	Keeps a drawn body's footprint out of the room's cover boxes, on the
	client (`Fx/SlimeHop`). The server keeps every hitbox out of cover
	(`Arena.resolveBox`), but a hopping slime's body is drawn ahead of its
	hitbox in the lurch and squashed wider as it lands: in Mossy Glade 1-10's
	rooms 5-10 it reached up to 0.76 studs into cover while every hitbox
	stayed clear (owner's checklist, `rg-cover`, 2026-11-26). Pushed out along
	the shallower axis, as `Arena.resolveBox` does. Pure, so
	`tests/CoverPush.spec` can pin it.
]]

local CoverPush = {}

--[[ A cover box seen from above: its centre and half its size, on the
     world's axes (cover is never turned). ]]
export type Box = { centre: Vector2, half: Vector2 }

--[[ The half-extents, on the world's axes, of a footprint `half` in its own
     axes turned `yaw` radians about Y. ]]
function CoverPush.turned(half: Vector2, yaw: number): Vector2
	local c, s = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
	return Vector2.new(c * half.X + s * half.Y, s * half.X + c * half.Y)
end

--[[ `point` moved the least way out of every box a footprint of `half`
     there would reach into; unchanged when it reaches into none. ]]
function CoverPush.out(point: Vector2, half: Vector2, boxes: { Box }): Vector2
	for _, box in boxes do
		local delta = point - box.centre
		local overlapX = (box.half.X + half.X) - math.abs(delta.X)
		local overlapZ = (box.half.Y + half.Y) - math.abs(delta.Y)
		if overlapX > 0 and overlapZ > 0 then
			if overlapX < overlapZ then
				local sign = if delta.X >= 0 then 1 else -1
				point = Vector2.new(box.centre.X + sign * (box.half.X + half.X), point.Y)
			else
				local sign = if delta.Y >= 0 then 1 else -1
				point = Vector2.new(point.X, box.centre.Y + sign * (box.half.Y + half.Y))
			end
		end
	end
	return point
end

return CoverPush
