--!strict
--[[
	Builds every upgrade effect the owner imported (`Config/ImportedModels/Fx*`,
	from tools/imports_to_luau.py) once, as models in
	ReplicatedStorage.UpgradeEffects, for `Fx/Upgrades/UpgradeFx` to copy.

	Each part is rebuilt from its mesh id the way enemy meshes are
	(`Util/MeshTemplates`), at the size and place the import gave it, so
	`Fx/ModelAnimator` can play the effect's own clips on a copy. The effects
	were merged for phones before import (assets/models/effects/
	optimise_effect.py), so an effect is a handful of parts.

	Built in the background: the run does not wait on 300 mesh fetches, and an
	effect asked for before its model arrives is simply not drawn.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)

local log = Log.forTag("UpgradeEffects")

local UpgradeEffects = {}

local FOLDER = "UpgradeEffects"
--[[ The ImportedModels modules that are effects. ]]
local PREFIX = "Fx"

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

local function specs(): { [string]: { PartSpec } }
	local out: { [string]: { PartSpec } } = {}
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("ImportedModels")
	if folder then
		for _, module in folder:GetChildren() do
			if module:IsA("ModuleScript") and string.sub(module.Name, 1, #PREFIX) == PREFIX then
				out[module.Name] = (require :: any)(module)
			end
		end
	end
	return out
end

local function build()
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
		-- the clip data's name; a copy is tagged for ModelAnimator, never this
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
			-- an effect's shadow is a second dark shape for the eye to read
			part.CastShadow = false
			part.Parent = model
		end
		if #model:GetChildren() > 0 then
			model.WorldPivot = CFrame.new()
			-- how many parts a client must have before it copies the effect
			model:SetAttribute("Parts", #model:GetChildren())
			model.Parent = out
			count += 1
		end
	end
	out:SetAttribute("Effects", count)
	out.Parent = ReplicatedStorage
	log.info("built %d upgrade effects", count)
end

--[[ Starts building every effect, in the background. ]]
function UpgradeEffects.start()
	task.spawn(build)
end

return UpgradeEffects
