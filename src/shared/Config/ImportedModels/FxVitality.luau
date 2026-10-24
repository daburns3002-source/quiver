--!strict
--[[
	FxVitality as the owner imported it (fx_vitality, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "vitality_cross_Mesh1",
		meshId = "rbxassetid://90295277071662",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.75, 1.75, 0.25 },
		cframe = { 0, 1.875, -0.25, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "",
	},
	{
		name = "vitality_heart_Mesh1",
		meshId = "rbxassetid://74223948386895",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 4.25, 3.75, 1.25 },
		cframe = { 0, 1.875, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "",
	},
})
