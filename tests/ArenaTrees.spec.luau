--!strict
--[[
	The glades' forests as single trees (`Config/ArenaTrees`, split from
	their merged meshes so each sways in the gusts). Pinned: every forest a
	model names exists; no tree round the room reaches into it, which is
	how a wrong sign in the placement showed itself (ten trees did); and
	every tree sways from the foot of its own trunk, on the floor under it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaModels = require(ReplicatedStorage.Shared.Config.ArenaModels)
local ArenaTrees = require(ReplicatedStorage.Shared.Config.ArenaTrees)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("every forest a model names has its trees", function()
		for name, model in ArenaModels :: { [string]: ArenaModels.ArenaModel } do
			local surround: { ArenaModels.ArenaPart } = model.surround or {}
			for _, list in { model.parts, surround } do
				for _, spec in list do
					local forest = spec.trees
					if forest then
						t.isTrue(
							ArenaTrees[forest] ~= nil,
							`{name} names a missing forest {forest}`
						)
						t.isTrue(#ArenaTrees[forest] > 0, `{forest} has no trees`)
					end
				end
			end
		end
	end)

	t.test("no tree round the room reaches into it", function()
		local room = Balance.Arena.size
		for _, model in ArenaModels :: { [string]: ArenaModels.ArenaModel } do
			for _, spec in model.parts do
				local forest: { ArenaTrees.Tree } = if spec.trees
					then ArenaTrees[spec.trees] or {}
					else {}
				for _, tree in forest do
					local reach = math.max(tree.size.X, tree.size.Z) / 2
					local clearX = math.abs(tree.offset.X) - reach >= room.X / 2
					local clearZ = math.abs(tree.offset.Z) - reach >= room.Z / 2
					t.isTrue(clearX or clearZ, `{tree.name} reaches into the room`)
				end
			end
		end
	end)

	t.test("every tree sways from the foot of its own trunk", function()
		for _, forest in ArenaTrees do
			for _, tree in forest do
				local under = math.abs(tree.base.X - tree.offset.X) <= tree.size.X / 2
					and math.abs(tree.base.Z - tree.offset.Z) <= tree.size.Z / 2
				t.isTrue(under, `{tree.name} sways from outside itself`)
				local foot = tree.offset.Y - tree.size.Y / 2
				t.isTrue(math.abs(tree.base.Y - foot) < 1, `{tree.name} sways from mid-air`)
			end
		end
	end)
end
