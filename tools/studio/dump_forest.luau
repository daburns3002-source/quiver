--!nocheck
--[[
	Run with execute_luau in the Edit datamodel after the owner imports an
	area's outer forest (File -> Import 3D, Merge Meshes off). Returns JSON
	of every MeshPart in the import: name, its node's name, mesh id, size,
	colour, and offset from the import's pivot (the GLB's origin, the lawn's
	centre). Set FOREST below, save the JSON as the file it names and run
	tools/forest_to_luau.py (with `thornwood` for Thornwood's).

	The import is found by its groups, in the Workspace or in
	ServerStorage.Imports, since every Claude Design import is "AuxScene":
	the glade's has GlowCaps, Thornwood's Snags.
]]

local HttpService = game:GetService("HttpService")

-- "GlowCaps" -> assets/models/arenas/mossy_glade_outer_ids.json
-- "Snags" -> assets/models/arenas/thornwood_outer_ids.json
local FOREST = "GlowCaps"

local function isForest(model)
	return model:IsA("Model")
		and model:FindFirstChild("Trees", true) ~= nil
		and model:FindFirstChild(FOREST, true) ~= nil
end

local candidates = workspace:GetChildren()
local stored = game:GetService("ServerStorage"):FindFirstChild("Imports")
if stored then
	for _, child in stored:GetChildren() do
		table.insert(candidates, child)
	end
end

local root
for _, child in candidates do
	if isForest(child) then
		root = child
	end
end
if not root then
	return '{"error":"no forest import found"}'
end

local function round(v)
	return math.floor(v * 1000 + 0.5) / 1000
end

local origin = root:GetPivot().Position
local rows = {}
for _, part in root:GetDescendants() do
	if part:IsA("MeshPart") then
		local offset = part.Position - origin
		table.insert(rows, {
			name = part.Name,
			group = part.Parent.Name,
			meshId = part.MeshId,
			size = { round(part.Size.X), round(part.Size.Y), round(part.Size.Z) },
			offset = { round(offset.X), round(offset.Y), round(offset.Z) },
		})
	end
end
return HttpService:JSONEncode(rows)
