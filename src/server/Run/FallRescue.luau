--!strict
--[[
	A player's body that has gone through a room's floor.

	2026-11-26, live 1155: in room 1 of a run server the player's body stood
	on the lobby's lawn, 18 studs under the arena, and only its ring showed
	above. A body is moved by its own player's client: it was put on the
	start as the room was built, and fell through a floor that client had
	not been sent yet. Every room's floor has its top at y = 0
	(`Arena/Arena`), so a root well below that has gone through, and
	`RoomController.step` puts it back on the start.
]]
local FallRescue = {}

--[[ The height a root has gone through the floor at. A root standing on
     the floor is about 3 studs above it; the lobby's lawn under the
     arena is at y -18. ]]
FallRescue.BELOW = -6

function FallRescue.fallen(y: number): boolean
	return y < FallRescue.BELOW
end

return FallRescue
