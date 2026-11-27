--!strict
--[[
	Ember Wilf as the owner imported it (Tripo, low poly, 2026-11-11), a Mossy Glade Legendary.
	The Glowcap Wilf's shape recoloured (owner: "the wilf should look like
	the glowcap wilf but recolored"). One textured Tripo mesh like
	`GlowcapWilf`: the mesh id, the colour map as its texture, the size and
	the place over the pivot are read out of the Studio import
	(`Workspace/TripoImports/Pets/EmberWilfPet`). Read them again after a re-import.
	Its glow is `Config/PetAuras` (Legendary).

	It stands on its pivot facing -Z, the front `Fx/PetPreview` turns
	toward the player, so nothing here turns it.
]]

return table.freeze({
	{
		name = "Body",
		meshId = "rbxassetid://95746547103985",
		textureId = "rbxassetid://86309515905882",
		color = { 0.63922, 0.63529, 0.64706 },
		material = "Plastic",
		transparency = 0,
		size = { 0.60275, 0.79773, 0.98041 },
		cframe = { 0, 0.39887, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	},
})
