--!strict
--[[
	Thornwood's outer wood (`Config/ThornwoodForest`, generated from the
	owner's import) stands round the room, never in it: no tree, snag,
	spike, bush or crow over the walls or the lawn, none in the lanes out of
	the north and south gates, and none above the height its life hovers
	at. The merged ground, bramble and grass meshes span the room's hole in
	their boxes, so they are left out; their hole was checked in the design.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaModels = require(ReplicatedStorage.Shared.Config.ArenaModels)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)
local ThornwoodForest = require(ReplicatedStorage.Shared.Config.ThornwoodForest)

local STANDALONE = { "Trunk", "CanopyMesh", "Crow", "Spike", "Bush", "Berry" }
-- Studs of lane past each gate kept clear, as the design's gate zones.
local LANE = 6
local EPSILON = 0.01

local function standalone(name: string): boolean
	for _, prefix in STANDALONE do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

return function(t: TestRunner.Helper)
	t.test("Thornwood's rooms are drawn inside its own wood", function()
		for _, name in
			{ "ThornHedges", "ThornHollow", "ThornBoulders", "ThornBrambles", "ThornBoss" }
		do
			local model = (ArenaModels :: any)[name]
			t.isTrue(model.parts == ThornwoodForest, name .. " is not in Thornwood's wood")
			t.isTrue(
				Balance.Ambience[model.ambience] ~= nil,
				name .. "'s ambience has no Balance entry"
			)
		end
	end)

	t.test("the wood stays out of the room and its gate lanes", function()
		local room = Balance.Arena
		local wallX = room.size.X / 2 + room.wallThickness
		local wallZ = room.size.Z / 2 + room.wallThickness
		local gate = Balance.Run.gate.width / 2
		local hover = Balance.Ambience.Thornwood.hover
		local checked = 0
		for _, part in ThornwoodForest do
			if standalone(part.name) then
				checked += 1
				local half = part.size / 2
				local minX = math.abs(part.offset.X) - half.X
				local minZ = math.abs(part.offset.Z) - half.Z
				local top = part.offset.Y + half.Y
				t.isTrue(
					minX >= wallX - EPSILON or minZ >= wallZ - EPSILON,
					part.name .. " stands in the room"
				)
				local inLane = math.abs(part.offset.X) - half.X < gate and minZ < wallZ + LANE
				t.isTrue(not inLane or top <= 1.5, part.name .. " blocks a gate's lane")
				t.isTrue(top <= hover, part.name .. " rises above the wood's life")
			end
		end
		t.isTrue(checked > 100, "the wood's trees and pieces are missing")
	end)
end
