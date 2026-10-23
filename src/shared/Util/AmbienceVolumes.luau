--!strict
--[[
	Where the scenery's life lives (`Fx/ForestAmbience`): strips of floor
	past the room's walls, either side and at both ends, never inside the
	room. Pure, so `tests/AmbienceVolumes.spec` can pin that.
]]

local AmbienceVolumes = {}

--[[ A box of floor: its centre at floor height, and its size (Y is 0). ]]
export type Volume = { centre: Vector3, size: Vector3 }

export type Room = { size: Vector3, wallThickness: number }
--[[ `gap` studs past the walls, `reach` studs out to the sides, `ends`
     studs past the room's ends. ]]
export type Reach = { gap: number, reach: number, ends: number }

function AmbienceVolumes.strips(room: Room, reach: Reach): { Volume }
	local halfX = room.size.X / 2 + room.wallThickness + reach.gap
	local halfZ = room.size.Z / 2 + room.wallThickness + reach.gap
	local long = (room.size.Z / 2 + reach.ends) * 2
	local wide = (halfX + reach.reach) * 2
	local out: { Volume } = {}
	for _, side in { -1, 1 } do
		table.insert(out, {
			centre = Vector3.new(side * (halfX + reach.reach / 2), 0, 0),
			size = Vector3.new(reach.reach, 0, long),
		})
		table.insert(out, {
			centre = Vector3.new(0, 0, side * (halfZ + reach.ends / 2)),
			size = Vector3.new(wide, 0, reach.ends),
		})
	end
	return out
end

return AmbienceVolumes
