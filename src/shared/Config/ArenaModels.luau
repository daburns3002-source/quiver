--!strict
--[[
	Arena models: a room's look, built from the owner's Claude Design models
	in place of the grey-box dressing (`Arena.build`).

	Presentation only. A room with a model keeps the same invisible floor,
	walls and obstacle boxes as every other room — those are what collide
	and stop arrows — and draws the model over them. Cover in the model
	(a log, a stump) is cover because the room lists an obstacle box where
	it stands, not because of the mesh.

	Pipeline as for enemies: GLB from Claude Design →
	`assets/models/arenas/optimise_arena.py` → the owner imports it in Studio
	→ the mesh ids and sizes go here, scaled into the room and turned to face
	the way Claude Design shows it (the importer turns models 180°).
]]

export type ArenaPart = {
	name: string,
	meshId: string,
	--[[ Size and offset from the room's centre on the floor (y = 0), already
	     scaled and turned. ]]
	size: Vector3,
	offset: Vector3,
	--[[ Drawn Neon, for glowing mushrooms and the like. ]]
	glow: boolean?,
}

export type ArenaModel = {
	parts: { ArenaPart },
	--[[
		What fills the screen past the model's edges, so the camera never
		sees the grey void (owner, 2026-10-22). The model is about 81 studs
		wide and a desktop screen sees about 124: `surround` names parts
		(trees, bushes) drawn again `surroundSpacing` studs to either side,
		and `outsideColor` is a forest floor laid under everything, the
		model's own outer ground colour.
	]]
	surround: { string }?,
	surroundSpacing: number?,
	outsideColor: Color3?,
}

--[[
	Act 1, area 1: the Mossy Glade (`assets/models/arenas/mossy_glade_log_roblox.glb`,
	imported 2026-10-22). Scaled ×2.7, so its walled lawn (about 13 × 21
	inside) fills the room's 35 × 58 floor and its walls stand where the
	room's do; the gap in its north wall is the exit. Its log and three
	stumps are cover — see Level 1's rooms in `Balance`.
]]
--[[ Every glade's outer ground (53, 89, 41 in its vertex colours), darkened
     to match it as seen in the trees' shade rather than in full sun. ]]
local GLADE_FLOOR = Color3.fromRGB(34, 62, 30)

local gladeLogs: ArenaModel = {
	surround = { "Trees", "Bushes" },
	surroundSpacing = 81,
	outsideColor = GLADE_FLOOR,
	parts = {
		{
			name = "Ground",
			meshId = "rbxassetid://79573309014324",
			size = Vector3.new(81.000, 1.809, 116.100),
			offset = Vector3.new(-0.022, 0.904, -6.755),
		},
		{
			name = "Grass",
			meshId = "rbxassetid://114418367398398",
			size = Vector3.new(80.737, 1.773, 115.843),
			offset = Vector3.new(-0.222, 0.979, -7.083),
		},
		{
			name = "Groundcover",
			meshId = "rbxassetid://100913845054287",
			size = Vector3.new(36.394, 3.775, 58.573),
			offset = Vector3.new(-0.139, 2.007, 0.058),
		},
		{
			name = "Walls",
			meshId = "rbxassetid://81275874761423",
			size = Vector3.new(39.100, 4.184, 60.717),
			offset = Vector3.new(-0.000, 1.892, -0.000),
		},
		{
			name = "Bushes",
			meshId = "rbxassetid://129899405699443",
			size = Vector3.new(81.689, 4.153, 115.584),
			offset = Vector3.new(1.103, 1.618, -5.761),
		},
		{
			name = "Trees",
			meshId = "rbxassetid://104769390455997",
			size = Vector3.new(96.184, 15.779, 128.239),
			offset = Vector3.new(0.228, 8.426, -6.808),
		},
		{
			name = "Props",
			meshId = "rbxassetid://81904816103162",
			size = Vector3.new(52.382, 3.304, 79.496),
			offset = Vector3.new(-4.055, 1.541, 0.644),
		},
		{
			name = "Glow",
			meshId = "rbxassetid://124730172189661",
			size = Vector3.new(52.661, 1.539, 79.860),
			offset = Vector3.new(-4.022, 1.652, 0.642),
			glow = true,
		},
	},
}

local ArenaModels = {
	GladeLogs = gladeLogs,
}

return table.freeze(ArenaModels)
