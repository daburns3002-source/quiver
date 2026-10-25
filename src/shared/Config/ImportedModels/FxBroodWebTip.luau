--!strict
--[[
	FxBroodWebTip as the owner imported it (brood_AuxScene_34, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "tip_core",
		meshId = "rbxassetid://125039574609339",
		textureId = "",
		color = { 1, 0.27985, 1 },
		material = "Neon",
		transparency = 0,
		size = { 0.10895, 0.10263, 0.12205 },
		cframe = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_core",
	},
	{
		name = "tip_shell",
		meshId = "rbxassetid://89982411677353",
		textureId = "",
		color = { 0.97194, 0.96241, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.52354, 0.54255, 0.38847 },
		cframe = { 0, 0.01528, 0.06, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_silk_tip",
	},
})
