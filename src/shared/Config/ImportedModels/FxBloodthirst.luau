--!strict
--[[
	FxBloodthirst as the owner imported it (fx_bloodthirst, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "bloodthirst_droplet_Mesh1",
		meshId = "rbxassetid://97717090607073",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.75, 2.75, 1.75 },
		cframe = { 0, 1.375, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "",
	},
	{
		name = "bloodthirst_plus_Mesh1",
		meshId = "rbxassetid://134546804654673",
		textureId = "",
		color = { 1, 1, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.25, 1.25, 0.5 },
		cframe = { -1.75, 2.125, 0.125, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "",
	},
	{
		name = "bloodthirst_plus_flash_Glow1",
		meshId = "rbxassetid://125034594286984",
		textureId = "",
		color = { 1, 1, 1 },
		material = "Neon",
		transparency = 0,
		size = { 1.75, 1.75, 0.5 },
		cframe = { -1.75, 2.125, 0.125, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "",
	},
})
