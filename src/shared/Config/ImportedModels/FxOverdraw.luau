--!strict
--[[
	FxOverdraw as the owner imported it (AuxScene#80, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "arrowhead",
		meshId = "rbxassetid://82529173919049",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.25, 0.75, 1 },
		cframe = { 0, 1.5, -2.875, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "crown",
		meshId = "rbxassetid://106398556827220",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.75, 1.75, 0.625 },
		cframe = { 0, 1.5, -2.5625, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "ring_large",
		meshId = "rbxassetid://72589441169170",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 2.25, 2.25, 0.25 },
		cframe = { 0, 1.5, -0.75, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "ring_medium",
		meshId = "rbxassetid://76363905623057",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.75, 1.75, 0.25 },
		cframe = { 0, 1.5, -1.375, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "ring_small",
		meshId = "rbxassetid://126694656738482",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.25, 1.25, 0.25 },
		cframe = { 0, 1.5, -1.875, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "shaft",
		meshId = "rbxassetid://140022438751549",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.5, 0.5, 3.25 },
		cframe = { 0, 1.5, -0.75, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "shockwave",
		meshId = "rbxassetid://126056937377383",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 2.75, 2.75, 0.25 },
		cframe = { 0, 1.5, -0.125, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
	{
		name = "speed_chips",
		meshId = "rbxassetid://123116782527474",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 2.25, 2.25, 1.5 },
		cframe = { 0, 1.5, -1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "AL_FX_VertexColor",
	},
})
