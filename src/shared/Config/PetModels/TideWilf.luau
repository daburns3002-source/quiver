--!strict
--[[
	Tide Wilf as the owner imported it (`tide wilf arena 3`), the Drowned Village's
	Legendary (docs/PETS-DROWNED.md). One textured Tripo mesh, not a Claude
	Design build, so there is no GLB here and no part names for
	`Config/ModelClips` to key on: the mesh and texture ids, the size and
	the place over the pivot are read out of the Studio import by hand
	(tools/imports_to_luau.py matches a GLB, and there is none). Read them
	again after a re-import.

	It stands on its pivot facing -Z, the front `Fx/PetPreview` turns
	toward the player, so nothing here turns it.
]]

return table.freeze({
	{
		name = "Body",
		meshId = "rbxassetid://84655829333808",
		textureId = "rbxassetid://78333028280307",
		color = { 0.63922, 0.63529, 0.64706 },
		material = "Plastic",
		transparency = 0,
		size = { 0.48584, 0.77783, 0.99951 },
		cframe = { 0, 0.38892, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	},
})
