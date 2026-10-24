--!strict
--[[
	FxDiagonalArrows as the owner imported it (AuxScene#67, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "arm_LB",
		meshId = "rbxassetid://122445035403858",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 10, 2, 10 },
		cframe = { 6.5, 0, -6.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "arm_LF",
		meshId = "rbxassetid://80712053192179",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 10, 2, 10 },
		cframe = { 6.5, 0, 6.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "arm_RB",
		meshId = "rbxassetid://106772891454324",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 10, 2, 10 },
		cframe = { -6.5, 0, -6.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "arm_RF",
		meshId = "rbxassetid://101472296241679",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 10, 2, 10 },
		cframe = { -6.5, 0, 6.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "core",
		meshId = "rbxassetid://92897282913428",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 3, 4, 3 },
		cframe = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
})
