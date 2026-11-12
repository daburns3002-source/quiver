--!strict
--[[
	Bramble Wilf as the owner imported it (Tripo, low poly, 2026-11-11), a Thornwood Legendary.
	The Glowcap Wilf's shape recoloured (owner: "the wilf should look like
	the glowcap wilf but recolored"). One textured Tripo mesh like
	`GlowcapWilf`: the mesh id, the colour map as its texture, the size and
	the place over the pivot are read out of the Studio import
	(`Workspace/TripoImports/Pets/BrambleWilf`). Read them again after a re-import.
	Its purple glow is `Config/PetAuras` (LegendaryPurple).

	It stands on its pivot facing -Z, the front `Fx/PetPreview` turns
	toward the player, so nothing here turns it.
]]

return table.freeze({
	{
		name = "Body",
		meshId = "rbxassetid://84179344368869",
		textureId = "rbxassetid://96800224050565",
		color = { 0.63922, 0.63529, 0.64706 },
		material = "Plastic",
		transparency = 0,
		size = { 0.66638, 0.86896, 0.9794 },
		cframe = { 0, 0.43448, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	},
})
