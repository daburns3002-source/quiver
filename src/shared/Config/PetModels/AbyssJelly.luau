--!strict
--[[
	Abyss Jelly as the owner imported it (`jellyfish mythic arena 3`), the Drowned Village's
	Mythic (docs/PETS-DROWNED.md). One textured Tripo mesh, not a Claude
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
		meshId = "rbxassetid://129495191489707",
		textureId = "rbxassetid://93191474112516",
		color = { 0.63922, 0.63529, 0.64706 },
		material = "Plastic",
		transparency = 0,
		size = { 0.99951, 0.95459, 0.85791 },
		cframe = { 0, 0.4773, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	},
})
