--!strict
--[[
	FxBloodthirst as the owner imported it (AuxScene#82, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "droplet_mesh_drop_crimson",
		meshId = "rbxassetid://85169283367088",
		textureId = "",
		color = { 0.94522, 0.07517, 0.27699 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.75, 2.75, 1.75 },
		cframe = { 0, 1.375, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "drop_crimson",
	},
	{
		name = "droplet_mesh_drop_light",
		meshId = "rbxassetid://137012614723535",
		textureId = "",
		color = { 1, 0.43041, 0.59522 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.5, 1, 0.5 },
		cframe = { 0.375, 1.5, -0.375, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "drop_light",
	},
	{
		name = "plus_flash_mesh_flash_white",
		meshId = "rbxassetid://115391724285306",
		textureId = "",
		color = { 1, 1, 1 },
		material = "Neon",
		transparency = 0,
		size = { 0.0018, 0.0018, 0.001 },
		cframe = { -1.75, 2.125, 0.125, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "flash_white",
	},
	{
		name = "plus_mesh_plus_green",
		meshId = "rbxassetid://119797443385627",
		textureId = "",
		color = { 0.16487, 1, 0.37089 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.25, 1.25, 0.5 },
		cframe = { -1.75, 2.125, 0.125, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "plus_green",
	},
})
