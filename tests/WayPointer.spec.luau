--!strict
--[[
	The gold "go here" pointer (`Util/WayPointer`, drawn by `Fx/GoldPointer`):
	its floor tiles run from the player toward the place and never reach or
	pass it, and the door's pointer shows only in a room whose gate is open,
	until the player stands at the door (owner, 2026-11-13).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)
local WayPointer = require(ReplicatedStorage.Shared.Util.WayPointer)

return function(t: TestRunner.Helper)
	t.test("the tiles step toward the target and stop short of it", function()
		local from = Vector3.new(0, 3, 23)
		local target = Vector3.new(0, 11, -27.6)
		local spots = WayPointer.tiles(from, target)
		t.equal(#spots, WayPointer.TILES, "a player across the room sees the whole row")
		local last = math.huge
		for i, spot in spots do
			local left = Vector2.new(target.X - spot.X, target.Z - spot.Z).Magnitude
			t.isTrue(left < last, "tile " .. i .. " is no nearer the target than the one before")
			t.isTrue(left >= WayPointer.STOP_SHORT, "tile " .. i .. " reaches the target")
			last = left
		end
	end)

	t.test("standing near the target, the row is put away", function()
		local target = Vector3.new(0, 11, -27.6)
		t.equal(
			#WayPointer.tiles(Vector3.new(0, 3, -22), target),
			0,
			"a tile shows beside the target"
		)
	end)

	t.test("the door's pointer shows only while its gate is open, until the door", function()
		local radius = Balance.Run.doorRadius
		t.isTrue(WayPointer.doorWanted(false, true, radius + 20, radius))
		t.isTrue(WayPointer.doorWanted(false, true, nil, radius), "no character yet: show it")
		t.isFalse(WayPointer.doorWanted(false, false, radius + 20, radius), "a shut gate")
		t.isFalse(WayPointer.doorWanted(true, true, radius + 20, radius), "the lobby")
		t.isFalse(WayPointer.doorWanted(false, true, radius - 0.5, radius), "at the door")
	end)

	t.test("the room's spawn is far enough from the door for a row of tiles", function()
		local spawn = Balance.Arena.spawnPosition
		local door = Balance.Run.doorOffset
		local far = Vector2.new(spawn.X - door.X, spawn.Z - door.Y).Magnitude
		t.isTrue(far > WayPointer.FIRST + WayPointer.STOP_SHORT + Balance.Run.doorRadius)
	end)
end
