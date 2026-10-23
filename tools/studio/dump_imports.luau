--!nocheck
--[[
	Run with execute_luau in the Edit datamodel after the owner imports a
	model (File -> Import 3D). Returns JSON of every MeshPart under the
	Workspace models named in NAMES (or under every top-level model when
	NAMES is empty), keyed by MeshPart name:

	  { meshId, textureId, size = {x, y, z}, bones = { {name, parent, cframe} } }

	`bones` lists a skinned mesh's bones, parents first, with their rest
	CFrames (as `rig.json` wants for `Config/EnemyRigs`). Save the output to
	the pipeline's ids file (docs/PIPELINES.md says which), e.g.
	assets/models/arenas/tree_ids.json, then run its generator.

	A name seen twice (two imports of the same file) keeps the newest
	mesh id and is flagged under `_duplicates`.
]]

local NAMES = {} -- e.g. { "mossy_glade_trees_roblox" }

local HttpService = game:GetService("HttpService")

local function round(v)
	return math.floor(v * 1e5 + 0.5) / 1e5
end

local function bones(part)
	local out = {}
	local function walk(parent)
		for _, b in parent:GetChildren() do
			if b:IsA("Bone") then
				local c = { b.CFrame:GetComponents() }
				for i, v in c do
					c[i] = round(v)
				end
				table.insert(out, {
					name = b.Name,
					parent = if parent:IsA("Bone") then parent.Name else "",
					cframe = c,
				})
				walk(b)
			end
		end
	end
	walk(part)
	return out
end

local roots = {}
if #NAMES == 0 then
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") then
			table.insert(roots, child)
		end
	end
else
	for _, name in NAMES do
		for _, child in workspace:GetChildren() do
			if child.Name == name then
				table.insert(roots, child)
			end
		end
	end
end

local result, duplicates = {}, {}
for _, root in roots do
	for _, part in root:GetDescendants() do
		if part:IsA("MeshPart") then
			if result[part.Name] then
				table.insert(duplicates, part.Name)
			end
			result[part.Name] = {
				meshId = part.MeshId,
				textureId = part.TextureID,
				size = { round(part.Size.X), round(part.Size.Y), round(part.Size.Z) },
				bones = bones(part),
			}
		end
	end
end
if #duplicates > 0 then
	result._duplicates = duplicates
end
return HttpService:JSONEncode(result)
