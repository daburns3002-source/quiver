--!strict
--[[
	FxBouncyWall as the owner imported it (AuxScene#47, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "chevron",
		meshId = "rbxassetid://80503470594419",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.25, 1.5, 0.375 },
		cframe = { -0.5, 0.75, -0.1875, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "core",
		meshId = "rbxassetid://106514364816979",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.5, 0.5, 0.5 },
		cframe = { 0, 0.75, -0.25, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "step_1",
		meshId = "rbxassetid://88769820954206",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.5, 0.5, 0.5 },
		cframe = { -1.5, 1, -0.625, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "step_2",
		meshId = "rbxassetid://76734726611067",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.375, 0.375, 0.375 },
		cframe = { -2.0625, 1.3125, -1.1875, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "step_3",
		meshId = "rbxassetid://93208550163332",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.25, 0.25, 0.25 },
		cframe = { -2.5, 1.625, -1.625, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
})
