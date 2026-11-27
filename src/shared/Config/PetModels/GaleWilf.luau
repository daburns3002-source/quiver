--!strict
--[[
	Gale Wilf as Claude imported it (Tripo, low poly, 2026-11-27), the Windswept
	Cliffs' Legendary (docs/WINDSWEPT-CLIFFS.md): the Glowcap Wilf recoloured
	sky-blue and cloud-white, with the family's longer front-right sock. One
	textured Tripo mesh like `GlowcapWilf`: the mesh id, the colour map as its
	texture, the size and the place over the pivot are read out of the Studio
	import (`ServerStorage.Imports.GaleWilf`). Read them again after a re-import.

	It stands on its pivot facing -Z, the front `Fx/PetPreview` turns
	toward the player, so nothing here turns it.
]]

return table.freeze({
	{
		name = "Body",
		meshId = "rbxassetid://122735152260215",
		textureId = "rbxassetid://123214782998937",
		color = { 0.63922, 0.63529, 0.64706 },
		material = "Plastic",
		transparency = 0,
		size = { 0.693, 0.877, 1 },
		cframe = { 0, 0.4385, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	},
})
