--!strict
--[[
	FxVitality as the owner imported it (AuxScene#68, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "cross_mesh_heart_white",
		meshId = "rbxassetid://90160348469346",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.75, 1.75, 0.25 },
		cframe = { 0, 1.875, -0.25, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "heart_white",
	},
	{
		name = "heart_mesh_heart_pink",
		meshId = "rbxassetid://77881456137684",
		textureId = "",
		color = { 1, 0.56775, 0.65932 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.5, 0.5, 0.001 },
		cframe = { 1.125, 3, -0.625, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "heart_pink",
	},
	{
		name = "heart_mesh_heart_red",
		meshId = "rbxassetid://78477371742741",
		textureId = "",
		color = { 1, 0.15265, 0.27898 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 4.25, 3.75, 1.25 },
		cframe = { 0, 1.875, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "heart_red",
	},
})
