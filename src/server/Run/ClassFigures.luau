--!strict
--[[
	Loads the class select cards' figures (`Config/ClassFigures`) into
	`ReplicatedStorage.ClassFigures/<Class>`, one anchored MeshPart a class,
	for the client to draw on its cards (`GearScreen.figure`). A figure with
	no mesh yet, or one that fails to load, is left out and its card draws
	the player's own character.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassFigures = require(ReplicatedStorage.Shared.Config.ClassFigures)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)

local Figures = {}

function Figures.build()
	local ids: { string } = {}
	for _, figure in ClassFigures.figures do
		if figure.meshId ~= "" then
			table.insert(ids, figure.meshId)
		end
	end
	local templates = MeshTemplates.load(ids)
	local folder = Instance.new("Folder")
	folder.Name = ClassFigures.folder
	for class, figure in ClassFigures.figures do
		local template = if figure.meshId ~= "" then templates[figure.meshId] else nil
		if template then
			local part = template:Clone()
			part.Name = class
			part.Size = figure.size
			-- white, so the mesh's own vertex colours show
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

return Figures
