--!nocheck
--[[
	Run with execute_luau in the Edit datamodel after the owner imports
	Claude Design models (File -> Import 3D, Merge Meshes off). Returns JSON
	of every top-level Workspace model named in NAMES (or every top-level
	model when NAMES is empty), keyed by model name:

	  { parts = { { name, meshId, textureId, color = {r, g, b}, material,
	                transparency, size = {x, y, z}, cframe = {12 numbers} } } }

	`cframe` is the part's place relative to the model's pivot. Save the
	output as assets/models/model_imports.json and run
	tools/imports_to_luau.py, which writes Config/PetModels.
]]

local NAMES = {} -- e.g. { "mosslet", "slime_prince", "ember_wilf" }

local HttpService = game:GetService("HttpService")

local function round(v)
	return math.floor(v * 1e5 + 0.5) / 1e5
end

local roots = {}
for _, child in workspace:GetChildren() do
	if child:IsA("Model") and (#NAMES == 0 or table.find(NAMES, child.Name)) then
		table.insert(roots, child)
	end
end

local result = {}
for _, model in roots do
	local pivot = model:GetPivot()
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			local c = { pivot:ToObjectSpace(part.CFrame):GetComponents() }
			for i, v in c do
				c[i] = round(v)
			end
			local texture = part.TextureID
			local surface = part:FindFirstChildOfClass("SurfaceAppearance")
			if surface and surface.ColorMap ~= "" then
				texture = surface.ColorMap
			end
			table.insert(parts, {
				name = part.Name,
				meshId = part.MeshId,
				textureId = texture,
				color = { round(part.Color.R), round(part.Color.G), round(part.Color.B) },
				material = part.Material.Name,
				transparency = round(part.Transparency),
				size = { round(part.Size.X), round(part.Size.Y), round(part.Size.Z) },
				cframe = c,
			})
		end
	end
	result[model.Name] = { parts = parts }
end
return HttpService:JSONEncode(result)
