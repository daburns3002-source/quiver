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
	Act 1, area 1: the Mossy Glade, in five variants for Level 1's rooms
	(owner, 2026-10-22), each from `assets/models/arenas/mossy_glade_<variant>_roblox.glb`.
	Scaled ×2.7, so the walled lawn (about 13 × 21 inside) fills the room's
	35 × 58 floor and its walls stand where the room's do; the gap in the
	north wall is the exit. Each variant's cover is listed as obstacle boxes
	in Level 1's rooms in `Balance`, at the model's own positions.
]]

--[[ Every glade's outer ground (53, 89, 41 in its vertex colours), darkened
     to match it as seen in the trees' shade rather than in full sun. ]]
local GLADE_FLOOR = Color3.fromRGB(34, 62, 30)

--[[ A glade variant: its parts, with the forest drawn again either side. ]]
local function glade(parts: { ArenaPart }): ArenaModel
	return {
		surround = { "Trees", "Bushes" },
		surroundSpacing = 81,
		outsideColor = GLADE_FLOOR,
		parts = parts,
	}
end

--[[ The fallen log and three stumps. ]]
local gladeLogs = glade({
	{
		name = "Ground",
		meshId = "rbxassetid://79573309014324",
		size = Vector3.new(81.000, 1.809, 116.100),
		offset = Vector3.new(-0.000, 0.784, -6.750),
	},
	{
		name = "Grass",
		meshId = "rbxassetid://114418367398398",
		size = Vector3.new(80.737, 1.773, 115.843),
		offset = Vector3.new(-0.200, 0.859, -7.078),
	},
	{
		name = "Groundcover",
		meshId = "rbxassetid://100913845054287",
		size = Vector3.new(36.394, 3.775, 58.573),
		offset = Vector3.new(-0.117, 1.888, 0.063),
	},
	{
		name = "Walls",
		meshId = "rbxassetid://81275874761423",
		size = Vector3.new(39.100, 4.184, 60.717),
		offset = Vector3.new(0.022, 1.772, 0.005),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://129899405699443",
		size = Vector3.new(81.689, 4.153, 115.584),
		offset = Vector3.new(1.126, 1.498, -5.756),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://104769390455997",
		size = Vector3.new(96.184, 15.779, 128.239),
		offset = Vector3.new(0.250, 8.306, -6.803),
	},
	{
		name = "Props",
		meshId = "rbxassetid://81904816103162",
		size = Vector3.new(52.382, 3.304, 79.496),
		offset = Vector3.new(-4.033, 1.421, 0.649),
	},
	{
		name = "Glow",
		meshId = "rbxassetid://124730172189661",
		size = Vector3.new(52.661, 1.539, 79.860),
		offset = Vector3.new(-4.000, 1.532, 0.647),
		glow = true,
	},
})

--[[ A pond with lily pads, which blocks walking but not arrows. ]]
local gladePond = glade({
	{
		name = "Ground",
		meshId = "rbxassetid://86065768773594",
		size = Vector3.new(81.000, 2.661, 116.100),
		offset = Vector3.new(-0.000, 0.358, -6.750),
	},
	{
		name = "Grass",
		meshId = "rbxassetid://130358106087501",
		size = Vector3.new(80.813, 1.792, 116.055),
		offset = Vector3.new(-0.321, 0.869, -6.576),
	},
	{
		name = "Groundcover",
		meshId = "rbxassetid://82949599281315",
		size = Vector3.new(36.829, 4.741, 58.105),
		offset = Vector3.new(0.104, 1.394, -0.300),
	},
	{
		name = "Walls",
		meshId = "rbxassetid://93312987524489",
		size = Vector3.new(39.047, 4.545, 60.759),
		offset = Vector3.new(0.003, 1.555, 0.004),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://99608952937586",
		size = Vector3.new(78.358, 4.798, 117.211),
		offset = Vector3.new(0.546, 1.839, -7.228),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://91393123108553",
		size = Vector3.new(95.034, 15.596, 127.262),
		offset = Vector3.new(-0.045, 8.228, -7.077),
	},
	{
		name = "Props",
		meshId = "rbxassetid://82449654213912",
		size = Vector3.new(55.256, 2.250, 77.376),
		offset = Vector3.new(-2.434, 0.922, -1.023),
	},
	{
		name = "Water",
		meshId = "rbxassetid://95763915370445",
		size = Vector3.new(16.330, 0.003, 11.664),
		offset = Vector3.new(-4.050, -0.243, -4.320),
	},
	{
		name = "Glow",
		meshId = "rbxassetid://86601335318185",
		size = Vector3.new(55.535, 1.620, 77.644),
		offset = Vector3.new(-2.429, 1.436, -1.003),
		glow = true,
	},
})

--[[ Mossy boulders. ]]
local gladeBoulders = glade({
	{
		name = "Ground",
		meshId = "rbxassetid://87544021234113",
		size = Vector3.new(81.000, 1.799, 116.100),
		offset = Vector3.new(-0.000, 0.789, -6.750),
	},
	{
		name = "Grass",
		meshId = "rbxassetid://113840117651977",
		size = Vector3.new(81.343, 1.954, 116.234),
		offset = Vector3.new(-0.042, 0.949, -6.460),
	},
	{
		name = "Groundcover",
		meshId = "rbxassetid://113228258479441",
		size = Vector3.new(36.745, 4.375, 57.661),
		offset = Vector3.new(-0.048, 2.187, -0.053),
	},
	{
		name = "Walls",
		meshId = "rbxassetid://110460403370872",
		size = Vector3.new(39.067, 4.423, 60.735),
		offset = Vector3.new(0.003, 1.769, -0.008),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://76535628294148",
		size = Vector3.new(82.480, 4.899, 117.969),
		offset = Vector3.new(0.589, 1.975, -6.994),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://105250776230127",
		size = Vector3.new(95.554, 15.573, 126.562),
		offset = Vector3.new(0.029, 8.293, -4.554),
	},
	{
		name = "Props",
		meshId = "rbxassetid://76425193248274",
		size = Vector3.new(57.233, 2.170, 79.617),
		offset = Vector3.new(-1.334, 0.969, -1.085),
	},
	{
		name = "Glow",
		meshId = "rbxassetid://131374221665137",
		size = Vector3.new(57.582, 1.534, 79.865),
		offset = Vector3.new(-1.305, 1.511, -1.095),
		glow = true,
	},
})

--[[ Two bramble patches, which block walking but not arrows. ]]
local gladeThorns = glade({
	{
		name = "Ground",
		meshId = "rbxassetid://131721094417580",
		size = Vector3.new(81.000, 1.803, 116.100),
		offset = Vector3.new(-0.000, 0.788, -6.750),
	},
	{
		name = "Grass",
		meshId = "rbxassetid://108458228629189",
		size = Vector3.new(81.288, 1.840, 115.713),
		offset = Vector3.new(-0.217, 0.893, -7.025),
	},
	{
		name = "Groundcover",
		meshId = "rbxassetid://75131274432252",
		size = Vector3.new(36.029, 4.540, 58.335),
		offset = Vector3.new(0.163, 2.270, -0.177),
	},
	{
		name = "Walls",
		meshId = "rbxassetid://111288317610393",
		size = Vector3.new(39.085, 4.157, 60.704),
		offset = Vector3.new(0.014, 1.753, -0.014),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://99333281352844",
		size = Vector3.new(81.191, 5.144, 113.944),
		offset = Vector3.new(0.979, 2.006, -5.560),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://117634822354120",
		size = Vector3.new(94.077, 15.111, 126.346),
		offset = Vector3.new(-0.294, 7.841, -7.076),
	},
	{
		name = "Props",
		meshId = "rbxassetid://93578772158527",
		size = Vector3.new(59.013, 2.048, 79.767),
		offset = Vector3.new(-0.117, 0.878, -1.153),
	},
	{
		name = "Thorns",
		meshId = "rbxassetid://137637361947532",
		size = Vector3.new(23.968, 2.087, 24.970),
		offset = Vector3.new(0.583, 0.735, -2.638),
	},
	{
		name = "Glow",
		meshId = "rbxassetid://125636517497323",
		size = Vector3.new(59.285, 1.569, 80.062),
		offset = Vector3.new(-0.100, 1.322, -1.175),
		glow = true,
	},
})

--[[ A stone circle ringed by four mushroom-topped pillars. ]]
local gladeBoss = glade({
	{
		name = "Ground",
		meshId = "rbxassetid://122682985654357",
		size = Vector3.new(81.000, 1.802, 116.100),
		offset = Vector3.new(-0.000, 0.788, -6.750),
	},
	{
		name = "Grass",
		meshId = "rbxassetid://115451081705936",
		size = Vector3.new(81.513, 1.831, 115.742),
		offset = Vector3.new(0.151, 0.889, -7.110),
	},
	{
		name = "Groundcover",
		meshId = "rbxassetid://108614926673905",
		size = Vector3.new(47.034, 3.250, 66.112),
		offset = Vector3.new(-0.175, 1.625, -0.131),
	},
	{
		name = "Walls",
		meshId = "rbxassetid://97689327959182",
		size = Vector3.new(49.938, 7.036, 68.887),
		offset = Vector3.new(0.010, 3.207, 0.029),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://80762864267370",
		size = Vector3.new(84.220, 4.912, 114.840),
		offset = Vector3.new(-0.039, 1.993, -8.719),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://82996110055874",
		size = Vector3.new(95.578, 15.698, 129.645),
		offset = Vector3.new(-0.717, 8.371, -7.742),
	},
	{
		name = "Props",
		meshId = "rbxassetid://104156248621067",
		size = Vector3.new(67.944, 4.870, 83.956),
		offset = Vector3.new(1.985, 2.300, 1.985),
	},
	{
		name = "Thorns",
		meshId = "rbxassetid://93915321681512",
		size = Vector3.new(8.238, 2.243, 0.434),
		offset = Vector3.new(0.001, 2.218, -31.508),
	},
	{
		name = "Glow",
		meshId = "rbxassetid://72506264648190",
		size = Vector3.new(68.325, 3.472, 84.265),
		offset = Vector3.new(1.990, 2.011, 2.020),
		glow = true,
	},
})

local ArenaModels = {
	GladeLogs = gladeLogs,
	GladePond = gladePond,
	GladeBoulders = gladeBoulders,
	GladeThorns = gladeThorns,
	GladeBoss = gladeBoss,
}

return table.freeze(ArenaModels)
