--!strict
--[[
	FxBroodWebStrand as the owner imported it (brood_AuxScene_33, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "strand_barbs",
		meshId = "rbxassetid://109422026767289",
		textureId = "",
		color = { 1, 0.9187, 0.74485 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.14142, 0.36071, 0.57571 },
		cframe = { 0.01801, -0.02, -0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_barb",
	},
	{
		name = "strand_silk",
		meshId = "rbxassetid://96126524376151",
		textureId = "",
		color = { 0.97194, 0.96241, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 0.24846, 0.24929, 1.01592 },
		cframe = { 0, -0.00016, -0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_silk",
	},
})
