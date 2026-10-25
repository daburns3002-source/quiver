--!strict
--[[
	FxBroodWebSplat as the owner imported it (brood_AuxScene_32, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "splat_barbs",
		meshId = "rbxassetid://89402885712807",
		textureId = "",
		color = { 1, 0.9187, 0.74485 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 2.31893, 0.09421, 2.31259 },
		cframe = { -0.00394, 0.05, 0.00175, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_barb",
	},
	{
		name = "splat_centre",
		meshId = "rbxassetid://77530717193762",
		textureId = "",
		color = { 1, 0.26047, 1 },
		material = "Neon",
		transparency = 0,
		size = { 0.40305, 0.085, 0.40305 },
		cframe = { 0, 0.0425, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_core",
	},
	{
		name = "splat_centre_hot",
		meshId = "rbxassetid://137021981441163",
		textureId = "",
		color = { 1, 0.55713, 1 },
		material = "Neon",
		transparency = 0,
		size = { 0.14142, 0.1, 0.14142 },
		cframe = { 0, 0.05, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_core_hot",
	},
	{
		name = "splat_ring_inner",
		meshId = "rbxassetid://133543341753172",
		textureId = "",
		color = { 0.97194, 0.96241, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.20962, 0.075, 1.21183 },
		cframe = { -0.00082, 0.0375, 0.0009, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_silk",
	},
	{
		name = "splat_ring_outer",
		meshId = "rbxassetid://135850492213517",
		textureId = "",
		color = { 0.97194, 0.96241, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.99938, 0.075, 1.99932 },
		cframe = { -0.00075, 0.0375, -0.00102, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_silk",
	},
	{
		name = "splat_spokes",
		meshId = "rbxassetid://105048508390239",
		textureId = "",
		color = { 0.97194, 0.96241, 1 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 2.99264, 0.1, 3.00392 },
		cframe = { -0.0013, 0.05, 0.00035, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "brood_silk",
	},
})
