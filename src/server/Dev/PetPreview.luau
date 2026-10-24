--!strict
--[[
	Studio only: builds the pets the owner imported (`Config/PetModels`, from
	tools/imports_to_luau.py) as models in ReplicatedStorage.PetPreview, so
	`Fx/PetPreview` can set them following the player. Nothing here runs in
	a live game, and nothing here touches a run: the pets are a look, not a
	system. The real pet system is Phase 6 (docs/ROADMAP.md).

	Each part is rebuilt from its mesh id the way enemy meshes are
	(`Util/MeshTemplates`), at the size and place the import gave it, so
	`Fx/ModelAnimator` can play the model's own clips on it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)

local log = Log.forTag("PetPreview")

local PetPreview = {}

local FOLDER = "PetPreview"

type PartSpec = {
	name: string,
	meshId: string,
	textureId: string,
	color: { number },
	material: string,
	transparency: number,
	size: { number },
	cframe: { number },
}

local built = false

local function specs(): { [string]: { PartSpec } }
	local out: { [string]: { PartSpec } } = {}
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("PetModels")
	if folder then
		for _, module in folder:GetChildren() do
			if module:IsA("ModuleScript") then
				out[module.Name] = (require :: any)(module)
			end
		end
	end
	return out
end

--[[ Builds every imported pet once; later calls do nothing. Returns how
     many pets the folder holds. ]]
function PetPreview.build(): number
	local folder = ReplicatedStorage:FindFirstChild(FOLDER)
	if built and folder then
		return #folder:GetChildren()
	end
	if not RunService:IsStudio() then
		return 0
	end
	built = true
	local all = specs()
	local ids: { string } = {}
	for _, parts in all do
		for _, p in parts do
			table.insert(ids, p.meshId)
		end
	end
	local templates = MeshTemplates.load(ids)

	local out = Instance.new("Folder")
	out.Name = FOLDER
	local count = 0
	for key, parts in all do
		local model = Instance.new("Model")
		model.Name = key
		model:SetAttribute("ModelClips", key)
		for _, p in parts do
			local template = templates[p.meshId]
			if not template then
				continue
			end
			local part = template:Clone()
			part.Name = p.name
			part.Size = Vector3.new(p.size[1], p.size[2], p.size[3])
			local c = p.cframe
			part.CFrame = CFrame.new(
				c[1],
				c[2],
				c[3],
				c[4],
				c[5],
				c[6],
				c[7],
				c[8],
				c[9],
				c[10],
				c[11],
				c[12]
			)
			part.Color = Color3.new(p.color[1], p.color[2], p.color[3])
			part.Material = (Enum.Material :: any)[p.material] or Enum.Material.SmoothPlastic
			part.Transparency = p.transparency
			if p.textureId ~= "" then
				part.TextureID = p.textureId
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = true
			part.Parent = model
		end
		if #model:GetChildren() > 0 then
			-- built at its pivot's place: the origin
			model.WorldPivot = CFrame.new()
			-- how many parts a client must have before it copies the pet:
			-- a model this size replicates over several frames
			model:SetAttribute("Parts", #model:GetChildren())
			model.Parent = out
			count += 1
		end
	end
	out:SetAttribute("Pets", count)
	out.Parent = ReplicatedStorage
	log.info("built %d preview pets (Studio)", count)
	return count
end

return PetPreview
