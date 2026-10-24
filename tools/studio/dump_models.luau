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

	Claude Design GLBs all import as "AuxScene" (the GLB's scene name, not
	its file name), so a name that repeats is keyed "AuxScene#<n>", n being
	its place among the Workspace's children; imports_to_luau.py tells them
	apart by their part names. A large import can outgrow one call's
	return: FROM and TO limit which children are read.
]]

local NAMES = {} -- e.g. { "AuxScene" }
local FROM, TO = 1, math.huge

local HttpService = game:GetService("HttpService")

local function round(v)
	return math.floor(v * 1e5 + 0.5) / 1e5
end

--[[
	Imports are moved out of the Workspace into ServerStorage.Imports once
	their ids are dumped: left in the world, every playtest replicates and
	draws them, and 65 of them took a playtest from 60 FPS to 26 (docs/FIXES.md).
	So a dump reads both places. One that read only the Workspace after the
	move would miss every stored import, and imports_to_luau.py prunes any
	module it does not regenerate — the pets and King Bloblin with them.
	Stored imports are keyed "#S<n>" so they never collide with a Workspace one.
]]
local children, tags = {}, {}
for _, child in workspace:GetChildren() do
	table.insert(children, child)
	table.insert(tags, "")
end
local stored = game:GetService("ServerStorage"):FindFirstChild("Imports")
if stored then
	for _, child in stored:GetChildren() do
		table.insert(children, child)
		table.insert(tags, "S")
	end
end

local seen = {}
for _, child in children do
	seen[child.Name] = (seen[child.Name] or 0) + 1
end

local roots = {}
for i, child in children do
	if
		i >= FROM
		and i <= TO
		and child:IsA("Model")
		and (#NAMES == 0 or table.find(NAMES, child.Name))
	then
		local key = if seen[child.Name] > 1 then child.Name .. "#" .. tags[i] .. i else child.Name
		roots[key] = child
	end
end

local result = {}
for key, model in roots do
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
	result[key] = { parts = parts }
end
return HttpService:JSONEncode(result)
