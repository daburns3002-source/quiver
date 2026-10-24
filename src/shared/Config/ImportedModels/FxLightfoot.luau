--!strict
--[[
	FxLightfoot as the owner imported it (fx_lightfoot, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "lightfoot_chevron_back_Mesh1",
		meshId = "rbxassetid://95607042157848",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.75, 2.25, 0.75 },
		cframe = { 1.25, 1.625, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "",
	},
	{
		name = "lightfoot_chevron_front_Mesh1",
		meshId = "rbxassetid://124047207172761",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 2, 2.75, 0.75 },
		cframe = { -0.375, 1.625, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "",
	},
	{
		name = "lightfoot_wing_Mesh1",
		meshId = "rbxassetid://104997643745313",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 2.25, 1, 0.25 },
		cframe = { 0.25, 3.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "",
	},
})
