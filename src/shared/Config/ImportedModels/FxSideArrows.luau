--!strict
--[[
	FxSideArrows as the owner imported it (AuxScene#75, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "core",
		meshId = "rbxassetid://131982828754711",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 3, 3, 3 },
		cframe = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "wing_L",
		meshId = "rbxassetid://131498886713890",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 9, 1, 7 },
		cframe = { 6, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
	{
		name = "wing_R",
		meshId = "rbxassetid://104518285352374",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 9, 1, 7 },
		cframe = { -6, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "fx_voxel",
	},
})
