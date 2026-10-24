--!strict
--[[
	FxCleave as the owner imported it (AuxScene#76, a baked import). Generated
	by tools/imports_to_luau.py from tools/studio/dump_models.luau's output
	and the GLB; regenerate after a re-import, never hand-edit.

	Each part: its GLB node's name (which Config/ModelClips keys on), mesh
	and texture ids, colour, material, transparency, size, and its rest
	place relative to the model's pivot (12 CFrame components), and the name of its GLB material (`surface`).
]]

return table.freeze({
	{
		name = "cleave_arc_shell",
		meshId = "rbxassetid://98424241458342",
		textureId = "",
		color = { 1, 0.70196, 0.76863 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.7, 0.045, 0.6 },
		cframe = { 0, 0.0225, 0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "blade_pink",
	},
	{
		name = "cleave_arc_shell",
		meshId = "rbxassetid://85147210170972",
		textureId = "",
		color = { 0.82353, 0.12157, 0.23529 },
		material = "SmoothPlastic",
		transparency = 0,
		size = { 1.7, 0.065, 0.7 },
		cframe = { 0, 0.0325, -0.05, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
		surface = "blade_crimson",
	},
})
