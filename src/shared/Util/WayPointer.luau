--!strict
--[[
	The rules of the gold "go here" pointer (`Fx/GoldPointer`): a blocky gold
	arrow bobbing over a place, and a row of gold tiles on the floor running
	from the player toward it. Two use it: the lobby's way to the first egg
	(`Fx/HatcheryPointer`) and the open exit gate after a room is cleared
	(`Fx/DoorPointer`; owner, 2026-11-13: "the same way theres an arrow in the
	lobby pointing to eggs, there should be an arrow pointing to the open
	door when a player clears a room"). Pure, so `tests/WayPointer.spec` holds
	it without a world.
]]

local WayPointer = {}

--[[ The row of tiles: how many, how far apart, how far out from the player
     the first sits, and how near the target the row stops. ]]
WayPointer.TILES = 6
WayPointer.SPACING = 4
WayPointer.FIRST = 5
WayPointer.STOP_SHORT = 6

--[[ Where the floor tiles sit, flat (Y left to the caller), nearest the
     player first: as many of the row as fit before it would reach the
     target, so a player close to it sees fewer, or none. ]]
function WayPointer.tiles(from: Vector3, target: Vector3): { Vector3 }
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local out: { Vector3 } = {}
	for i = 1, WayPointer.TILES do
		local along = WayPointer.FIRST + (i - 1) * WayPointer.SPACING
		if flat.Magnitude <= along + WayPointer.STOP_SHORT then
			break
		end
		table.insert(out, from + flat.Unit * along)
	end
	return out
end

--[[ Whether the door pointer shows: in a fight's room (not the lobby), its
     gate open, and this player not yet standing at it. `distance` is flat
     studs from the player to the door's point (`Balance.Run.doorOffset`),
     nil with no character; `radius` is the door's own reach. ]]
function WayPointer.doorWanted(
	inLobby: boolean,
	exitOpen: boolean,
	distance: number?,
	radius: number
): boolean
	if inLobby or not exitOpen then
		return false
	end
	return distance == nil or distance > radius
end

return table.freeze(WayPointer)
