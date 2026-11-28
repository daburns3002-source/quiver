--!nocheck
--[[
	Run with execute_luau (Edit or Server datamodel): loads each uploaded
	Model asset in ASSETS (InsertService, never parented) and returns its
	MeshParts in the shape tools/studio/dump_models.luau gives, as compact
	lines `key|name|meshId|textureId|transparency|sx,sy,sz|12 cframe numbers`
	(cframe relative to the model's pivot), for an Open Cloud upload in place
	of a File > Import 3D. tools/assets_to_imports.py folds the lines into
	assets/models/model_imports.json under "OC#<key>".
]]
local ASSETS = {} -- { Name = assetId }, from assets/models/merged_model_assets.json

local InsertService = game:GetService("InsertService")
local function r(v)
	return string.format("%.5f", v):gsub("%.?0+$", "")
end
local lines = {}
for key, id in ASSETS do
	local ok, root = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if not ok then
		table.insert(lines, key .. "|ERROR|" .. tostring(root))
		continue
	end
	local model = root:FindFirstChildWhichIsA("Model") or root
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			local c = { pivot:ToObjectSpace(d.CFrame):GetComponents() }
			for i, v in c do
				c[i] = r(v)
			end
			table.insert(lines, table.concat({ key, d.Name, d.MeshId, d.TextureID, r(d.Transparency), r(d.Size.X) .. "," .. r(d.Size.Y) .. "," .. r(d.Size.Z), table.concat(c, ",") }, "|"))
		end
	end
	root:Destroy()
end
return table.concat(lines, "\n")
