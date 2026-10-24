--!strict
--[[
	The forest's life past the walls (`Shared/Util/AmbienceVolumes`, the
	owner's design_handoff_forest_ambience) must never reach into the
	room, where it would read as something in the fight, and must reach
	out to the screen's edges on both sides.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbienceVolumes = require(ReplicatedStorage.Shared.Util.AmbienceVolumes)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the forest's life stays out of the room", function()
		local room = Balance.Arena
		local wallX = room.size.X / 2 + room.wallThickness
		local wallZ = room.size.Z / 2 + room.wallThickness
		for name, reach in (Balance.Ambience :: any) :: { [string]: AmbienceVolumes.Reach } do
			local strips = AmbienceVolumes.strips(room, reach)
			t.isTrue(#strips > 0, name .. " has nowhere to live")
			for _, v in strips do
				local minX = math.abs(v.centre.X) - v.size.X / 2
				local minZ = math.abs(v.centre.Z) - v.size.Z / 2
				--[[ Outside the walls along X, or outside them along Z. ]]
				t.isTrue(minX >= wallX or minZ >= wallZ, name .. "'s life reaches into the room")
			end
		end
	end)
end
