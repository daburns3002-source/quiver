--!strict
--[[
	FxArcaneEcho as the owner imported it (AuxScene#61, a rigged import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "Echo_Ghost_Body",
		meshId = "rbxassetid://113628101662153",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0.5,
		size = { 0.6, 0.6, 0.6 },
		cframe = { -1.45832, -0.19791, 0.1875, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "Ghost_PaleCyan_VertexColour",
	},
	{
		name = "Echo_Ghost_Body_Outline",
		meshId = "rbxassetid://71489970658724",
		textureId = "",
		color = { 0.14902, 0.73333, 0.98824 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.636, 0.636, 0.636 },
		cframe = { -1.45832, -0.19791, 0.1875, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "Ghost_Outline_Cyan",
	},
	{
		name = "Echo_Ripple",
		meshId = "rbxassetid://130086875261857",
		textureId = "",
		color = { 0.17972, 0.85198, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.2417, 0.2298, 0.0209 },
		cframe = {
			0.00002,
			0.00001,
			0,
			0.07242,
			-0.16889,
			0.98297,
			-0.91331,
			0.3848,
			0.1334,
			-0.40078,
			-0.90742,
			-0.12638,
		},
		surface = "Cyan",
	},
	{
		name = "Echo_Ripple_Outline",
		meshId = "rbxassetid://80298083995918",
		textureId = "",
		color = { 0, 0.01569, 0.21176 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.2513, 0.2395, 0.0306 },
		cframe = {
			0.00002,
			0.00001,
			0,
			0.07242,
			-0.16889,
			0.98297,
			-0.91331,
			0.3848,
			0.1334,
			-0.40078,
			-0.90742,
			-0.12638,
		},
		surface = "Outline_Navy",
	},
})
