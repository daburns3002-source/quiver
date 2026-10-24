--!strict
--[[
	FxSwiftArrows as the owner imported it (AuxScene#77, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "slabs",
		meshId = "rbxassetid://76970535951063",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 5, 1, 10 },
		cframe = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "streak_L",
		meshId = "rbxassetid://88307811947275",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1, 1, 9 },
		cframe = { 4, 0, -0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "streak_R",
		meshId = "rbxassetid://104320892521030",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1, 1, 9 },
		cframe = { -4, 0, -0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
})
