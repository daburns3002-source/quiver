--!strict
--[[
	Every room has a clear walk from the player's start to the exit for a
	body as wide as the player (owner, 2026-10-25: "make sure there is a
	clear path to the exit every time"), searched over the floor in half-stud
	cells against the room's cover boxes, the way `tools/thornwood_rooms.py`
	checks the rooms it writes. And no room is more cover than floor
	(owner: "make the obstacles way less of the room").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

local RADIUS = 1.5
local CELL = 0.5

type Box = { offset: Vector2, size: Vector3 }

local function walkable(obstacles: { Box }): boolean
	local hx, hz = Balance.Arena.size.X / 2, Balance.Arena.size.Z / 2
	local nx, nz = math.floor(2 * hx / CELL), math.floor(2 * hz / CELL)
	local function free(i: number, j: number): boolean
		local x = -hx + (i + 0.5) * CELL
		local z = -hz + (j + 0.5) * CELL
		if math.abs(x) > hx - RADIUS or math.abs(z) > hz - RADIUS then
			return false
		end
		for _, box in obstacles do
			if
				math.abs(x - box.offset.X) < box.size.X / 2 + RADIUS
				and math.abs(z - box.offset.Y) < box.size.Z / 2 + RADIUS
			then
				return false
			end
		end
		return true
	end
	local function cell(x: number, z: number): (number, number)
		return math.floor((x + hx) / CELL), math.floor((z + hz) / CELL)
	end
	local start = Balance.Arena.spawnPosition
	local door = Balance.Run.doorOffset
	local si, sj = cell(start.X, start.Z)
	local gi, gj = cell(door.X, door.Y)
	local seen: { [number]: boolean } = { [si * 1000 + sj] = true }
	local queue = { { si, sj } }
	local head = 1
	while head <= #queue do
		local c = queue[head]
		head += 1
		if c[1] == gi and c[2] == gj then
			return true
		end
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local i, j = c[1] + d[1], c[2] + d[2]
			local key = i * 1000 + j
			if i >= 0 and i < nx and j >= 0 and j < nz and not seen[key] and free(i, j) then
				seen[key] = true
				table.insert(queue, { i, j })
			end
		end
	end
	return false
end

return function(t: TestRunner.Helper)
	t.test("every room has a clear path from the start to the exit", function()
		for index, room in Balance.Rooms do
			t.isTrue(walkable(room.obstacles), `room {index} ({room.name}) has no way to the exit`)
		end
	end)

	t.test("Level 2 is forty rooms of thin cover", function()
		local rooms: { number } = Balance.Stages[4].rooms or {}
		t.equal(#rooms, 40)
		local floor = Balance.Arena.size.X * Balance.Arena.size.Z
		for _, index in rooms do
			local room = Balance.Rooms[index]
			local cover = 0
			for _, box in room.obstacles do
				cover += box.size.X * box.size.Z
			end
			t.isTrue(#room.obstacles <= 30, `{room.name} has {#room.obstacles} pieces of cover`)
			t.isTrue(
				cover <= floor * 0.1,
				`{room.name} is {math.floor(cover / floor * 100)}% cover`
			)
		end
	end)
end
