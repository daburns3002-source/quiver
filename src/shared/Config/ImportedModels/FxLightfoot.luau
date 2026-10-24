--!strict
--[[
	FxLightfoot as the owner imported it (AuxScene#66, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "chevron_back_mesh_puff_cyan",
		meshId = "rbxassetid://126836776522053",
		textureId = "",
		color = { 0.73715, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.5, 2.25, 0.75 },
		cframe = { 1.375, 1.625, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "puff_cyan",
	},
	{
		name = "chevron_back_mesh_puff_white",
		meshId = "rbxassetid://79335581558986",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.25, 2.25, 0.75 },
		cframe = { 1, 1.625, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "puff_white",
	},
	{
		name = "chevron_front_mesh_puff_cyan",
		meshId = "rbxassetid://128240589305591",
		textureId = "",
		color = { 0.73715, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.75, 2.75, 0.75 },
		cframe = { -0.25, 1.625, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "puff_cyan",
	},
	{
		name = "chevron_front_mesh_puff_white",
		meshId = "rbxassetid://70684993791024",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.5, 2.75, 0.75 },
		cframe = { -0.625, 1.625, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "puff_white",
	},
	{
		name = "wing_mesh_puff_cyan",
		meshId = "rbxassetid://110787596119936",
		textureId = "",
		color = { 0.73715, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 2.25, 0.75, 0.25 },
		cframe = { 0.25, 3.625, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "puff_cyan",
	},
	{
		name = "wing_mesh_puff_white",
		meshId = "rbxassetid://94957939011912",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 2.25, 0.75, 0.25 },
		cframe = { 0.25, 3.875, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "puff_white",
	},
})
