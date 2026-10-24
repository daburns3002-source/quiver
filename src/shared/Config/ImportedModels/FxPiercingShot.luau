--!strict
--[[
	FxPiercingShot as the owner imported it (AuxScene#62, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "core",
		meshId = "rbxassetid://82175486893409",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 5, 5, 5 },
		cframe = { 0, 0, -2.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "ring",
		meshId = "rbxassetid://128739269657115",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 11, 11, 3 },
		cframe = { 0, 0, -3.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "ring_corners",
		meshId = "rbxassetid://115848804154299",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 13, 13, 2 },
		cframe = { 0, 0, -5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "shards",
		meshId = "rbxassetid://123589447502634",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 25, 25, 6 },
		cframe = { 0, 0, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
})
