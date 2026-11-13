--!strict
--[[
	The class models on the class select cards (owner, 2026-11-13: "scrap the
	models on the player entirely", then "keep the character select screen
	with the class models", choosing the remade figures shown whole). Each is
	one mesh: the class's outfit on a blocky body with skin, a face and hair,
	matched to the owner's picked reference sheet in Claude Design
	(`assets/models/class_figures/<class>_male_set.glb`) and made into one
	vertex-coloured mesh by `tools/class_figures/figure.py`. Nothing is worn
	by the player: in the lobby and in a run every player is their own
	avatar.

	`size`, `centre` and `hand` are the figure's, in studs, from its feet at
	the origin, facing -Z: its mesh's size and centre, and where an R15 right
	hand would be (the class weapon's grip). From `<class>_male_figure.json`.
	An empty `meshId` (not yet imported) leaves the card drawing the
	player's own character. Male figures for now; the female sheets wait on
	the owner.
]]

export type Figure = {
	--[[ The imported mesh's part name. ]]
	name: string,
	meshId: string,
	size: Vector3,
	centre: Vector3,
	hand: Vector3,
}

local ClassFigures = {
	--[[ Where the server puts the loaded meshes, one MeshPart a class. ]]
	folder = "ClassFigures",
	figures = {
		Ranger = {
			name = "RangerMale",
			meshId = "",
			size = Vector3.new(3.8691, 6.4969, 1.7945),
			centre = Vector3.new(-0.1383, 3.1793, 0.1383),
			hand = Vector3.new(1.2447, 2.7878, 0),
		},
		Arcanist = {
			name = "ArcanistMale",
			meshId = "",
			size = Vector3.new(3.1909, 7.2649, 2.8495),
			centre = Vector3.new(-0.0891, 3.558, 0.0128),
			hand = Vector3.new(0.9722, 2.1043, 0.0121),
		},
		Warden = {
			name = "WardenMale",
			meshId = "",
			size = Vector3.new(4.659, 6.92, 1.999),
			centre = Vector3.new(0, 3.3895, 0.0665),
			hand = Vector3.new(1.6625, 2.288, 0),
		},
	} :: { [string]: Figure },
}

return table.freeze(ClassFigures)
