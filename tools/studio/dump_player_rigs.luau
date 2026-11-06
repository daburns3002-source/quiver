--[[
	Prints the mesh and texture ids of the split player rigs after the owner's
	Import 3D of `assets/models/players/*_r15.glb` (anywhere in Workspace or
	ServerStorage). Paste the output into `assets/models/players/mesh_ids.txt`
	and run `python tools/player_rigs/rigs_to_luau.py`.

	Run in Studio's command bar or through the Studio MCP's execute_luau.
]]

local NAMES = {
	"ranger_male", "ranger_female", "arcanist_male", "arcanist_female",
	"warden_male", "warden_female", "assassin_male", "assassin_female",
}

local function rigName(model: Instance): string?
	local node: Instance? = model
	while node and node ~= game do
		local lower = string.lower(node.Name)
		for _, name in NAMES do
			if string.find(lower, name, 1, true) or string.find(lower, (string.gsub(name, "_", "")), 1, true) then
				return name
			end
		end
		node = node.Parent
	end
	return nil
end

local lines = {}
local seen = {}
for _, root in { workspace, game:GetService("ServerStorage") } do
	for _, part in root:GetDescendants() do
		if not part:IsA("MeshPart") then
			continue
		end
		local name = rigName(part)
		if not name then
			continue
		end
		local key = name .. "/" .. part.Name
		if seen[key] then
			continue
		end
		seen[key] = true
		local texture = part.TextureID
		local surface = part:FindFirstChildOfClass("SurfaceAppearance")
		if surface and surface.ColorMap ~= "" then
			texture = surface.ColorMap
		end
		table.insert(lines, string.format("%s|%s|%s", key, part.MeshId, texture))
	end
end
table.sort(lines)
return table.concat(lines, "\n")
