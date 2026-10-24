--!strict
--[[
	FxBlastArrows as the owner imported it (AuxScene#50, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "core",
		meshId = "rbxassetid://95924351512933",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1, 1, 1 },
		cframe = { 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "red_shards",
		meshId = "rbxassetid://106283710818713",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 6.375, 1, 5.625 },
		cframe = { 0.0625, 1.125, -0.0625, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "scorch_ring",
		meshId = "rbxassetid://96296235347294",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 4.75, 0.25, 4.75 },
		cframe = { 0, 0.125, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "starburst",
		meshId = "rbxassetid://74120751263661",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 5.25, 1.5, 5.25 },
		cframe = { 0, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
})
