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
	--[[ Drawn matte. The glades' ground needs it: as plastic, its dark outer
	     grass caught the light and read pale grey (owner, 2026-10-22). Its
	     bright lawn keeps its own colour either way. ]]
	matte: boolean?,
}

export type ArenaModel = {
	parts: { ArenaPart },
	--[[
		What fills the screen past the model's edges, so the camera never
		sees the grey void (owner, 2026-10-22). The model is about 81 studs
		wide and a desktop screen sees about 124: `surround` names parts
		(trees, bushes, grass) drawn again `surroundSpacing` studs to either side,
		and `outsideColor` is a forest floor laid under everything, the
		model's own outer ground colour.
	]]
	surround: { string }?,
	surroundSpacing: number?,
	--[[ Draw the surround from another model's parts (an `ArenaModels`
	     key) instead of this one's, when this one's forest is too narrow
	     to tile without gaps. ]]
	surroundFrom: string?,
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

--[[ A glade variant: its parts, with its forest and grass drawn again
     either side, one ground's width (`spacing`) away. ]]
local function glade(spacing: number, parts: { ArenaPart }, surroundFrom: string?): ArenaModel
	return {
		surround = { "Trees", "Bushes", "Grass" },
		surroundSpacing = spacing,
		surroundFrom = surroundFrom,
		outsideColor = GLADE_FLOOR,
		parts = parts,
	}
end

--[[ The fallen log and three stumps. ]]
local gladeLogs = glade(81.0, {
	{
		name = "Ground",
		meshId = "rbxassetid://79573309014324",
		size = Vector3.new(81.000, 1.809, 116.100),
		offset = Vector3.new(-0.000, 0.784, -6.750),
		matte = true,
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
local gladePond = glade(81.1, {
	{
		name = "Ground",
		meshId = "rbxassetid://86065768773594",
		size = Vector3.new(81.109, 2.662, 116.019),
		offset = Vector3.new(-0.000, 0.359, -6.745),
		matte = true,
	},
	{
		name = "Grass",
		meshId = "rbxassetid://130358106087501",
		size = Vector3.new(80.922, 1.792, 115.974),
		offset = Vector3.new(-0.321, 0.869, -6.572),
	},
	{
		name = "Groundcover",
		meshId = "rbxassetid://82949599281315",
		size = Vector3.new(36.878, 4.742, 58.064),
		offset = Vector3.new(0.104, 1.395, -0.300),
	},
	{
		name = "Walls",
		meshId = "rbxassetid://93312987524489",
		size = Vector3.new(39.100, 4.546, 60.717),
		offset = Vector3.new(0.003, 1.555, 0.004),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://99608952937586",
		size = Vector3.new(78.463, 4.799, 117.129),
		offset = Vector3.new(0.546, 1.840, -7.223),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://91393123108553",
		size = Vector3.new(95.161, 15.601, 127.173),
		offset = Vector3.new(-0.045, 8.231, -7.072),
	},
	{
		name = "Props",
		meshId = "rbxassetid://82449654213912",
		size = Vector3.new(55.330, 2.251, 77.322),
		offset = Vector3.new(-2.438, 0.923, -1.022),
	},
	{
		name = "Water",
		meshId = "rbxassetid://95763915370445",
		size = Vector3.new(16.352, 0.003, 11.656),
		offset = Vector3.new(-4.055, -0.243, -4.317),
	},
	{
		name = "Glow",
		meshId = "rbxassetid://86601335318185",
		size = Vector3.new(55.610, 1.621, 77.590),
		offset = Vector3.new(-2.433, 1.436, -1.002),
		glow = true,
	},
})

--[[ Mossy boulders. ]]
local gladeBoulders = glade(81.1, {
	{
		name = "Ground",
		meshId = "rbxassetid://87544021234113",
		size = Vector3.new(81.067, 1.799, 116.066),
		offset = Vector3.new(-0.000, 0.789, -6.748),
		matte = true,
	},
	{
		name = "Grass",
		meshId = "rbxassetid://113840117651977",
		size = Vector3.new(81.411, 1.954, 116.200),
		offset = Vector3.new(-0.042, 0.950, -6.458),
	},
	{
		name = "Groundcover",
		meshId = "rbxassetid://113228258479441",
		size = Vector3.new(36.776, 4.376, 57.644),
		offset = Vector3.new(-0.048, 2.187, -0.053),
	},
	{
		name = "Walls",
		meshId = "rbxassetid://110460403370872",
		size = Vector3.new(39.100, 4.424, 60.717),
		offset = Vector3.new(0.003, 1.770, -0.008),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://76535628294148",
		size = Vector3.new(82.548, 4.900, 117.935),
		offset = Vector3.new(0.589, 1.976, -6.992),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://105250776230127",
		size = Vector3.new(95.633, 15.577, 126.525),
		offset = Vector3.new(0.029, 8.295, -4.552),
	},
	{
		name = "Props",
		meshId = "rbxassetid://76425193248274",
		size = Vector3.new(57.281, 2.170, 79.593),
		offset = Vector3.new(-1.335, 0.969, -1.084),
	},
	{
		name = "Glow",
		meshId = "rbxassetid://131374221665137",
		size = Vector3.new(57.630, 1.534, 79.842),
		offset = Vector3.new(-1.306, 1.512, -1.095),
		glow = true,
	},
})

--[[ Two bramble patches, which block walking but not arrows. ]]
local gladeThorns = glade(81.0, {
	{
		name = "Ground",
		meshId = "rbxassetid://131721094417580",
		size = Vector3.new(81.030, 1.803, 116.125),
		offset = Vector3.new(-0.000, 0.788, -6.751),
		matte = true,
	},
	{
		name = "Grass",
		meshId = "rbxassetid://108458228629189",
		size = Vector3.new(81.318, 1.840, 115.738),
		offset = Vector3.new(-0.217, 0.893, -7.027),
	},
	{
		name = "Groundcover",
		meshId = "rbxassetid://75131274432252",
		size = Vector3.new(36.043, 4.541, 58.347),
		offset = Vector3.new(0.163, 2.271, -0.177),
	},
	{
		name = "Walls",
		meshId = "rbxassetid://111288317610393",
		size = Vector3.new(39.100, 4.158, 60.717),
		offset = Vector3.new(0.014, 1.754, -0.014),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://99333281352844",
		size = Vector3.new(81.221, 5.146, 113.969),
		offset = Vector3.new(0.979, 2.007, -5.561),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://117634822354120",
		size = Vector3.new(94.112, 15.115, 126.373),
		offset = Vector3.new(-0.294, 7.843, -7.078),
	},
	{
		name = "Props",
		meshId = "rbxassetid://93578772158527",
		size = Vector3.new(59.035, 2.049, 79.785),
		offset = Vector3.new(-0.117, 0.878, -1.153),
	},
	{
		name = "Thorns",
		meshId = "rbxassetid://137637361947532",
		size = Vector3.new(23.977, 2.088, 24.976),
		offset = Vector3.new(0.583, 0.736, -2.639),
	},
	{
		name = "Glow",
		meshId = "rbxassetid://125636517497323",
		size = Vector3.new(59.307, 1.569, 80.080),
		offset = Vector3.new(-0.100, 1.322, -1.175),
		glow = true,
	},
})

--[[ A stone circle ringed by four mushroom-topped pillars. Its walls are drawn
     bigger than the other glades', so it is scaled to the same footprint
     (×2.11 across, ×2.38 deep) rather than ×2.7. Squeezed, its own forest
     is too narrow to tile, so the log glade's stands either side of it. ]]
local gladeBoss = glade(81, {
	{
		name = "Ground",
		meshId = "rbxassetid://122682985654357",
		size = Vector3.new(63.420, 1.500, 102.331),
		offset = Vector3.new(-0.000, 0.655, -5.949),
		matte = true,
	},
	{
		name = "Grass",
		meshId = "rbxassetid://115451081705936",
		size = Vector3.new(63.822, 1.524, 102.015),
		offset = Vector3.new(0.118, 0.739, -6.267),
	},
	{
		name = "Groundcover",
		meshId = "rbxassetid://108614926673905",
		size = Vector3.new(36.826, 2.705, 58.271),
		offset = Vector3.new(-0.137, 1.352, -0.116),
	},
	{
		name = "Walls",
		meshId = "rbxassetid://97689327959182",
		size = Vector3.new(39.100, 5.855, 60.717),
		offset = Vector3.new(0.008, 2.669, 0.025),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://80762864267370",
		size = Vector3.new(65.941, 4.088, 101.221),
		offset = Vector3.new(-0.031, 1.658, -7.685),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://82996110055874",
		size = Vector3.new(74.834, 13.063, 114.270),
		offset = Vector3.new(-0.561, 6.966, -6.824),
	},
	{
		name = "Props",
		meshId = "rbxassetid://104156248621067",
		size = Vector3.new(53.197, 4.053, 73.999),
		offset = Vector3.new(1.554, 1.914, 1.749),
	},
	{
		name = "Thorns",
		meshId = "rbxassetid://93915321681512",
		size = Vector3.new(6.450, 1.866, 0.382),
		offset = Vector3.new(0.001, 1.846, -27.771),
	},
	{
		name = "Glow",
		meshId = "rbxassetid://72506264648190",
		size = Vector3.new(53.496, 2.889, 74.271),
		offset = Vector3.new(1.558, 1.674, 1.781),
		glow = true,
	},
}, "GladeLogs")

local ArenaModels = {
	GladeLogs = gladeLogs,
	GladePond = gladePond,
	GladeBoulders = gladeBoulders,
	GladeThorns = gladeThorns,
	GladeBoss = gladeBoss,
}

return table.freeze(ArenaModels)
