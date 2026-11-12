--!strict
--[[
	The class armour sets' imported meshes (`Config/ClassOutfits`), loaded
	once into `ReplicatedStorage.ClassOutfitMeshes/<Class>/<Piece>` so both
	sides dress from the same templates (`Util/ClassOutfit`): the server a
	character for its run, the client the copies on the class select cards
	and the Gear portrait. A piece with no mesh yet, or one that fails to
	load, has no template and is worn as its blocks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassOutfit = require(ReplicatedStorage.Shared.Util.ClassOutfit)
local ClassOutfits = require(ReplicatedStorage.Shared.Config.ClassOutfits)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)

local OutfitMeshes = {}

function OutfitMeshes.build()
	local ids: { string } = {}
	for _, set in ClassOutfits.sets do
		for _, piece in set.pieces do
			local id = piece.meshId
			if id and id ~= "" and not table.find(ids, id) then
				table.insert(ids, id)
			end
		end
	end
	local templates = MeshTemplates.load(ids)
	local folder = Instance.new("Folder")
	folder.Name = ClassOutfit.MESHES
	for class, set in ClassOutfits.sets do
		local group = Instance.new("Folder")
		group.Name = class
		for _, piece in set.pieces do
			local template = if piece.meshId then templates[piece.meshId] else nil
			if template then
				local part = template:Clone()
				part.Name = piece.name
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Parent = group
			end
		end
		group.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

return OutfitMeshes
