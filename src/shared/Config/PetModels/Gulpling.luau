--!strict
--[[
	Gulpling as the owner imported it (Tripo, low poly, 2026-11-06), a Bogheart
	Caverns Legendary (docs/PETS-BOGHEART.md). One textured Tripo mesh like the
	Drowned Village pets (`TideWilf`): the mesh id, the colour map as its
	texture, the size and the place over the pivot are read out of the
	Studio import (`Workspace/TripoImports/Pets/Gulpling`). Read them again
	after a re-import.

	It stands on its pivot facing -Z, the front `Fx/PetPreview` turns
	toward the player, so nothing here turns it.
]]

return table.freeze({
	{
		name = "Body",
		meshId = "rbxassetid://71911006423670",
		textureId = "rbxassetid://130984585186201",
		color = { 0.63922, 0.63529, 0.64706 },
		material = "Plastic",
		transparency = 0,
		size = { 0.984, 0.884, 0.782 },
		cframe = { 0, 0.442, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	},
})
