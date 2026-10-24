--!strict
--[[
	FxDualBows as the owner imported it (AuxScene#51, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "arrow_left",
		meshId = "rbxassetid://81300268963096",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 7.125, 1.25, 7.125 },
		cframe = { -0.1875, 1.875, -0.1875, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "arrow_right",
		meshId = "rbxassetid://107885947012785",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 7.125, 1.25, 7.125 },
		cframe = { 0.1875, 2.625, -0.1875, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "core",
		meshId = "rbxassetid://124603686035870",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.75, 1.75, 1.75 },
		cframe = { 0, 2.125, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "motes",
		meshId = "rbxassetid://104982183132195",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 9.5, 2.875, 10.5 },
		cframe = { -0.125, 2.1875, -0.25, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "teal_ring",
		meshId = "rbxassetid://110273910785461",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 6.25, 0.25, 6.25 },
		cframe = { 0, 0.125, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
})
