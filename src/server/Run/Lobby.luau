--!strict
--[[
	The lobby (`Config/Lobby`): built once at boot beside the arena, where
	players arrive after BEGIN ADVENTURE,
	and where stepping into an active portal starts that area's run.

	- `build` lays the clearing out from plain smooth parts (owner,
	  2026-10-27: "i dont want it to have the pixely texture. just make it
	  look like a normal lobby"): a lawn, sandy paths, the fountain, the
	  station cottages with their egg and crate stands, the portal ledges and
	  their arches, the two leaderboards, lamps, a ring of cliffs and trees with
	  waterfalls, a scatter of trees, bushes, boulders, flowers and
	  mushrooms, and invisible walls round the edge and round each station.
	  Round things are ellipsoids (a block with a sphere `SpecialMesh`).
	- `place` puts a character at the spawn.
	- `portalAt` says which active portal a player is standing in, if any,
	  for its screen to open (`UI/PortalScreen`); `startFor` checks a START
	  from that screen and names the stage it may start.

	Seeded, so the lobby is the same every time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local LevelUnlocks = require(ReplicatedStorage.Shared.Util.LevelUnlocks)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)

local Lobby = {}

local ORIGIN = LobbyConfig.origin
local COLOURS = LobbyConfig.colours
local folder: Folder? = nil
local leaderboardFace: Part? = nil
local endlessLeaderboardFace: Part? = nil

--[[ The lawn's top, a little above the place's Baseplate (whose top is
     y = 0): level with it, the two flicker. ]]
local LAWN = 0.1
--[[ The wood beyond the cliff ring, so the edge of the world never shows
     (owner, 2026-10-27: "the player should not see this in the lobby"):
     its rings, studs out from the clearing's edge, each tree's size range,
     and how far the floor reaches. ]]
local OUTER_RINGS = {
	{ out = 34, spacing = 16, grow = { 1.3, 1.7 } },
	{ out = 58, spacing = 20, grow = { 1.6, 2.2 } },
	{ out = 86, spacing = 24, grow = { 2.0, 2.8 } },
}
local OUTER_FLOOR = 900
--[[ How far each scatter kind keeps from everything else, studs. ]]
local REACH = { Tree = 6, Bush = 3, Boulder = 3.5, Flowers = 2, Mushroom = 1.5 }
--[[ The eggs' and crates' colours, after their 2D art
     (`assets/ui/gear/reveal/`, `GearAssets.crates`). ]]
local STAND_LOOK = {
	MossyEgg = {
		shell = Color3.fromRGB(246, 238, 216),
		spots = Color3.fromRGB(104, 184, 56),
		top = Color3.fromRGB(86, 188, 56),
	},
	ThornwoodEgg = {
		shell = Color3.fromRGB(242, 224, 200),
		spots = Color3.fromRGB(150, 70, 170),
		top = Color3.fromRGB(120, 44, 120),
	},
	MossyGlade = {
		wood = Color3.fromRGB(176, 116, 64),
		band = Color3.fromRGB(96, 178, 56),
		metal = Color3.fromRGB(240, 196, 70),
	},
	Thornwood = {
		wood = Color3.fromRGB(124, 82, 56),
		band = Color3.fromRGB(132, 56, 140),
		metal = Color3.fromRGB(210, 212, 222),
	},
}

--[[ The stations' emblems' colours. ]]
local EMBLEM = {
	eggShell = Color3.fromRGB(250, 242, 222),
	eggSpots = Color3.fromRGB(240, 120, 170),
	nestEggs = {
		Color3.fromRGB(170, 220, 255),
		Color3.fromRGB(255, 190, 210),
		Color3.fromRGB(200, 240, 160),
	},
	straw = Color3.fromRGB(222, 182, 98),
	steel = Color3.fromRGB(206, 212, 222),
	shield = Color3.fromRGB(212, 62, 62),
	gem = Color3.fromRGB(150, 110, 255),
}

local function world(at: Vector2, y: number?): Vector3
	return ORIGIN + Vector3.new(at.X, y or 0, at.Y)
end

--[[ Which row arch `index` stands in: 1 the front, 2 the back. ]]
function Lobby.rowOf(index: number): number
	return math.ceil(index / LobbyConfig.perRow)
end

--[[ The centre of row `row`'s ledge, and how high its top stands. ]]
local function rowCentre(row: number): (Vector2, number)
	return LobbyConfig.terrace - Vector2.new(0, (row - 1) * LobbyConfig.rowDepth),
		LobbyConfig.ledge + (row - 1) * LobbyConfig.rowRise
end

--[[ Where arch `index` stands: front row west to east, then the back. ]]
function Lobby.archAt(index: number): Vector2
	local perRow = LobbyConfig.perRow
	local column = (index - 1) % perRow + 1
	local offset = (column - (perRow + 1) / 2) * LobbyConfig.archSpacing
	return rowCentre(Lobby.rowOf(index)) + Vector2.new(offset, 0)
end

--[[ A smooth part, seen but never met: no collision, no queries (the
     camera and the prompts see through it). ]]
local function part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	parent: Instance,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Parent = parent
	return p
end

--[[ An ellipsoid `size` studs across. ]]
local function blob(
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	parent: Instance
): Part
	local p = part(name, size, cframe, colour, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

--[[
	The Dex Hall's three imported models (`LobbyConfig.dex`): the hall
	itself, the book astride its roof and the stand on each pad out front.
	Loaded once at boot and cloned from here.

	`MeshPart.MeshId` cannot be written -- a mesh part has to come out of
	`AssetService:CreateMeshPartAsync`, which yields while it fetches -- so
	the ids go through `Util/MeshTemplates` with everything else the server
	loads, and the lobby clones what came back.
]]
local dexTemplates: { [string]: MeshPart } = {}

export type DexPiece = {
	mesh: string,
	texture: string,
	native: Vector3,
	across: number,
}

--[[
	One of those, drawn `across` studs wide with its own proportions kept,
	its foot at `foot` in the hall's own frame.

	`native` is the import's own size, read from the config rather than off
	the asset, so the maths never waits on a fetch. Returns nil for a mesh
	that did not load, and the piece is simply left out.
]]
local function dexPiece(name: string, spec: DexPiece, foot: CFrame, parent: Instance): MeshPart?
	local template = dexTemplates[spec.mesh]
	if not template then
		return nil
	end
	local p = template:Clone()
	local size = spec.native * (spec.across / spec.native.X)
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.TextureID = spec.texture
	--[[ Both books carry their colours in their own texture, so the part
	     must not tint them. ]]
	p.Color = Color3.new(1, 1, 1)
	p.CFrame = foot * CFrame.new(0, size.Y / 2, 0)
	p.Parent = parent
	return p
end

--[[ An upright cylinder, its foot at `foot`. ]]
local function pillar(
	name: string,
	foot: Vector3,
	height: number,
	across: number,
	colour: Color3,
	parent: Instance
): Part
	return part(
		name,
		Vector3.new(height, across, across),
		CFrame.new(foot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		colour,
		parent,
		Enum.PartType.Cylinder
	)
end

--[[ A wall a player meets and nothing sees. ]]
local function wall(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

--[[ Words on a board's front, in the game's one font. ]]
local function words(board: Part, text: string, colour: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Words"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.9, 0.66)
	label.Font = Enum.Font.Arcade
	label.Text = text
	label.TextColor3 = colour
	label.TextStrokeColor3 = Color3.fromRGB(60, 36, 20)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = gui
end

--[[ A wooden sign board facing south (+Z), its centre at `centre`. ]]
--[[
	A wooden nameboard, reading out of `where`'s own front (+Z).

	It takes a frame rather than a point because the stations are turned to
	face the middle now (owner, 2026-11-01): a board that always faced south
	would have its back to the lawn on three corners out of four.
]]
local function signboard(
	text: string,
	where: CFrame,
	width: number,
	height: number,
	parent: Instance
)
	--[[ A part's face is its -Z, and a building's front is its +Z, so the
	     board turns half round to read out of the wall it hangs on. ]]
	local facing = where * CFrame.Angles(0, math.pi, 0)
	part(
		"SignFrame",
		Vector3.new(width + 0.8, height + 0.8, 0.5),
		facing * CFrame.new(0, 0, 0.3),
		COLOURS.woodDark,
		parent
	)
	local board = part("Sign", Vector3.new(width, height, 0.5), facing, COLOURS.wood, parent)
	words(board, text, COLOURS.text)
end

--[[ A tree: a trunk and a crown of three round clumps, `grow` times the
     lawn's size. ]]
local function tree(at: Vector2, grow: number, rng: Random, parent: Instance, solid: boolean)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local foot = world(at, LAWN)
	local height = 7 * grow
	local trunk = pillar("Trunk", foot, height + 2 * grow, 2.2 * grow, COLOURS.trunk, model)
	trunk.CanCollide = solid
	local leaves = COLOURS.leaves
	local crown = foot + Vector3.new(0, height + 3 * grow, 0)
	local turn = rng:NextNumber() * math.pi * 2
	blob(
		"Crown",
		Vector3.new(11, 9, 11) * grow,
		CFrame.new(crown),
		leaves[rng:NextInteger(1, #leaves)],
		model
	)
	for k = 0, 1 do
		local angle = turn + k * math.pi
		local side = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3.6 * grow
		blob(
			"Clump",
			Vector3.new(7.5, 6.5, 7.5) * grow,
			CFrame.new(crown + side + Vector3.new(0, -1.6 * grow + k * 2.4 * grow, 0)),
			leaves[rng:NextInteger(1, #leaves)],
			model
		)
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CastShadow = solid
		end
	end
	model.Parent = parent
end

--[[ A round grey boulder of two or three stones. ]]
local function boulder(at: Vector2, grow: number, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Boulder"
	local foot = world(at, LAWN)
	local main = blob(
		"Stone",
		Vector3.new(5, 3.6, 4.4) * grow,
		CFrame.new(foot + Vector3.new(0, 1.2 * grow, 0)) * CFrame.Angles(0, rng:NextNumber() * 3, 0),
		COLOURS.rock,
		model
	)
	main.CanCollide = true
	blob(
		"Shine",
		Vector3.new(3, 1.6, 2.6) * grow,
		CFrame.new(foot + Vector3.new(-0.4, 2.6, -0.2) * grow),
		COLOURS.rockLight,
		model
	)
	blob(
		"Pebble",
		Vector3.new(2.6, 2, 2.4) * grow,
		CFrame.new(foot + Vector3.new(2.6, 0.6, 1.2) * grow),
		COLOURS.rock,
		model
	)
	model.Parent = parent
end

local function bush(at: Vector2, grow: number, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Bush"
	local foot = world(at, LAWN)
	local leaves = COLOURS.leaves
	for k = 0, 2 do
		local angle = k * 2.1 + rng:NextNumber()
		local side = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 1.3 * grow
		local size = (3.6 - k * 0.5) * grow
		blob(
			"Leaves",
			Vector3.new(size, size * 0.8, size),
			CFrame.new(foot + side + Vector3.new(0, size * 0.3, 0)),
			leaves[(k % #leaves) + 1],
			model
		)
	end
	model.Parent = parent
end

local function flowers(at: Vector2, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Flowers"
	local foot = world(at, LAWN)
	local colour = COLOURS.flowers[rng:NextInteger(1, #COLOURS.flowers)]
	for _ = 1, 5 do
		local spot = foot + Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6))
		pillar("Stem", spot, 0.9, 0.2, COLOURS.leaves[1], model)
		blob(
			"Bloom",
			Vector3.new(0.9, 0.6, 0.9),
			CFrame.new(spot + Vector3.new(0, 1, 0)),
			colour,
			model
		)
		blob(
			"Heart",
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(spot + Vector3.new(0, 1.2, 0)),
			COLOURS.gold,
			model
		)
	end
	model.Parent = parent
end

local function mushroom(at: Vector2, grow: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Mushroom"
	local foot = world(at, LAWN)
	pillar("Stalk", foot, 1.4 * grow, 0.8 * grow, COLOURS.foam, model)
	local cap = foot + Vector3.new(0, 1.5 * grow, 0)
	blob("Cap", Vector3.new(2.6, 1.5, 2.6) * grow, CFrame.new(cap), COLOURS.mushroom, model)
	for k = 0, 2 do
		local angle = k * 2.1
		blob(
			"Dot",
			Vector3.new(0.45, 0.3, 0.45) * grow,
			CFrame.new(cap + Vector3.new(math.cos(angle) * 0.7, 0.6, math.sin(angle) * 0.7) * grow),
			COLOURS.foam,
			model
		)
	end
	model.Parent = parent
end

--[[ A smooth egg `size` studs, spotted, its centre at `cframe`. ]]
local function egg(cframe: CFrame, size: Vector3, shell: Color3, spots: Color3, parent: Instance)
	local middle = cframe.Position
	blob("Shell", size, cframe, shell, parent)
	for k = 0, 9 do
		local turn = k * 2.4
		local lift = math.rad(-40 + (k % 4) * 30)
		local normal = Vector3.new(
			math.cos(turn) * math.cos(lift),
			math.sin(lift),
			math.sin(turn) * math.cos(lift)
		)
		local spot = middle + normal * (size / 2) * 0.96
		local across = size.X * (0.2 + (k % 3) * 0.06)
		blob(
			"Spot",
			Vector3.new(across, across, 0.5),
			CFrame.lookAt(spot, spot + normal),
			spots,
			parent
		)
	end
end

--[[ A sword, its guard at `cframe`, the blade up, `grow` times a hand
     sword's size. ]]
local function sword(cframe: CFrame, grow: number, parent: Instance)
	local function piece(label: string, size: Vector3, y: number, colour: Color3, round: boolean?)
		if round then
			blob(label, size * grow, cframe * CFrame.new(0, y * grow, 0), colour, parent)
		else
			part(label, size * grow, cframe * CFrame.new(0, y * grow, 0), colour, parent)
		end
	end
	piece("Blade", Vector3.new(1.2, 7, 0.4), 4, EMBLEM.steel)
	piece("Tip", Vector3.new(0.85, 0.85, 0.4), 7.5, EMBLEM.steel)
	piece("Guard", Vector3.new(4, 0.8, 0.9), 0, COLOURS.gold)
	piece("Grip", Vector3.new(0.7, 2.2, 0.7), -1.4, COLOURS.woodDark)
	piece("Pommel", Vector3.new(1.1, 1.1, 1.1), -2.8, COLOURS.gold, true)
end

--[[ A round shield facing south, `across` studs, its centre at `cframe`. ]]
local function shield(cframe: CFrame, across: number, parent: Instance)
	local facing = cframe * CFrame.Angles(0, math.pi / 2, 0)
	part(
		"Rim",
		Vector3.new(0.6, across + 0.8, across + 0.8),
		facing * CFrame.new(-0.2, 0, 0),
		COLOURS.gold,
		parent,
		Enum.PartType.Cylinder
	)
	part(
		"Face",
		Vector3.new(0.6, across, across),
		facing,
		EMBLEM.shield,
		parent,
		Enum.PartType.Cylinder
	)
	part(
		"Bar",
		Vector3.new(across * 0.16, across * 0.8, 0.3),
		cframe * CFrame.new(0, 0, 0.35),
		COLOURS.foam,
		parent
	)
	part(
		"Bar",
		Vector3.new(across * 0.8, across * 0.16, 0.3),
		cframe * CFrame.new(0, 0, 0.35),
		COLOURS.foam,
		parent
	)
	blob(
		"Boss",
		Vector3.new(1, 1, 0.6) * across * 0.22,
		cframe * CFrame.new(0, 0, 0.5),
		COLOURS.gold,
		parent
	)
end

--[[ A straw nest of three small eggs, its foot at `cframe`. ]]
local function nest(cframe: CFrame, parent: Instance)
	local foot = cframe.Position
	pillar("Straw", foot, 1, 5.4, EMBLEM.straw, parent)
	pillar(
		"Hollow",
		foot + Vector3.new(0, 0.2, 0),
		0.9,
		4.2,
		EMBLEM.straw:Lerp(Color3.new(0, 0, 0), 0.25),
		parent
	)
	for k = 0, 2 do
		local turn = k * math.pi * 2 / 3
		blob(
			"Egg",
			Vector3.new(1.6, 2.1, 1.6),
			CFrame.new(foot + Vector3.new(math.cos(turn) * 1.1, 1.6, math.sin(turn) * 1.1)),
			EMBLEM.nestEggs[k + 1],
			parent
		)
	end
end

--[[ A weapon rack: two posts and a bar with the `weapons` leaning on it,
     its foot at `cframe`, facing south. ]]
local function weaponRack(cframe: CFrame, weapons: { string }, parent: Instance)
	for _, side in { -1, 1 } do
		part(
			"RackPost",
			Vector3.new(0.8, 6, 0.8),
			cframe * CFrame.new(side * 3.6, 3, 0),
			COLOURS.woodDark,
			parent
		)
	end
	part("RackBar", Vector3.new(8, 0.6, 0.6), cframe * CFrame.new(0, 5.4, 0), COLOURS.wood, parent)
	part(
		"RackFoot",
		Vector3.new(8.4, 0.6, 2.4),
		cframe * CFrame.new(0, 0.3, 0),
		COLOURS.woodDark,
		parent
	)
	for k, kind in weapons do
		local x = (k - (#weapons + 1) / 2) * 2.4
		local lean = cframe * CFrame.new(x, 0, 0.6) * CFrame.Angles(-0.12, 0, 0)
		if kind == "sword" then
			sword(lean * CFrame.new(0, 2.4, 0), 0.75, parent)
		elseif kind == "bow" then
			for _, tip in { -1, 1 } do
				part(
					"Limb",
					Vector3.new(0.5, 3.2, 0.5),
					lean * CFrame.new(-0.4, 4 + tip * 1.7, 0) * CFrame.Angles(0, 0, tip * 0.35),
					COLOURS.wood,
					parent
				)
			end
			part(
				"Grip",
				Vector3.new(0.6, 1.4, 0.6),
				lean * CFrame.new(-0.9, 4, 0),
				COLOURS.woodDark,
				parent
			)
			part(
				"String",
				Vector3.new(0.12, 6.6, 0.12),
				lean * CFrame.new(0.5, 4, 0),
				COLOURS.foam,
				parent
			)
		elseif kind == "staff" then
			part(
				"Pole",
				Vector3.new(0.6, 7, 0.6),
				lean * CFrame.new(0, 3.5, 0),
				COLOURS.wood,
				parent
			)
			local gem = blob(
				"Gem",
				Vector3.new(1.4, 1.8, 1.4),
				lean * CFrame.new(0, 7.6, 0),
				EMBLEM.gem,
				parent
			)
			gem.Material = Enum.Material.Neon
		end
	end
end

--[[ An armour stand: a post, a breastplate, pauldrons and a plumed helm,
     its foot at `cframe`. ]]
local function armourStand(cframe: CFrame, parent: Instance)
	pillar("StandBase", cframe.Position, 0.5, 3.4, COLOURS.woodDark, parent)
	part(
		"StandPost",
		Vector3.new(0.7, 5, 0.7),
		cframe * CFrame.new(0, 2.5, 0),
		COLOURS.woodDark,
		parent
	)
	blob(
		"Breastplate",
		Vector3.new(3.6, 3.6, 2.4),
		cframe * CFrame.new(0, 4.4, 0),
		EMBLEM.steel,
		parent
	)
	part("Belt", Vector3.new(3.2, 0.5, 2.2), cframe * CFrame.new(0, 3, 0), COLOURS.woodDark, parent)
	for _, side in { -1, 1 } do
		blob(
			"Pauldron",
			Vector3.new(1.6, 1.3, 1.8),
			cframe * CFrame.new(side * 1.9, 5.6, 0),
			EMBLEM.steel,
			parent
		)
	end
	blob("Helm", Vector3.new(2.2, 2.4, 2.2), cframe * CFrame.new(0, 7.2, 0), EMBLEM.steel, parent)
	part(
		"Visor",
		Vector3.new(1.6, 0.3, 0.3),
		cframe * CFrame.new(0, 7.2, 1.05),
		COLOURS.woodDark,
		parent
	)
	blob(
		"Plume",
		Vector3.new(0.7, 1.6, 1.8),
		cframe * CFrame.new(0, 8.6, -0.2),
		EMBLEM.shield,
		parent
	)
end

--[[ A station's name floating over it, which is how a player picks it
     out from across the lawn. Its own function because the Dex Hall is
     built and returned before the rest of `building` runs, and it needs
     one too (owner, 2026-11-01: "the text to be above like the rest of
     the buildings"). ]]
local function floatingTitle(spec: LobbyConfig.Building, at: CFrame, model: Model)
	local anchor = wall("Title", Vector3.one, at, model)
	anchor.CanCollide = false
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(32, 6)
	board.LightInfluence = 0
	board.MaxDistance = 320
	board.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.Text = spec.title or ""
	label.TextColor3 = spec.titleColour or COLOURS.text
	label.TextStrokeColor3 = Color3.fromRGB(40, 24, 12)
	label.TextStrokeTransparency = 0
	label.Parent = board
end

--[[ A station's cottage (`LobbyConfig.buildings`): a stone foundation,
     plastered walls framed in timber, a door and two windows, a gabled roof
     with a ridge, its sign over the door, and what its kind adds. Its door
     faces south. ]]
local function building(name: string, at: Vector2, parent: Instance): Vector3?
	local spec = LobbyConfig.buildings[name]
	if not spec then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	local size = spec.size
	local w, h, d = size.X, size.Y, size.Z
	--[[ Turned to face the middle of the clearing (owner, 2026-11-01), so
	     everything below -- walls, roof, porch, sign and props -- comes
	     round with it: they are all placed off `base`. ]]
	local base = CFrame.new(world(at, LAWN)) * CFrame.Angles(0, LobbyConfig.facing(at), 0)

	--[[
		The Dex Hall is the owner's own model, not a box with props on it
		(2026-11-01: "ok i imported the dex hall i want you to use"), so
		it is built here and nothing below runs for it: the mesh already
		carries its porch, its columns, its lanterns, its steps, its
		carpet, its shelves and the two stone pads out front.

		It was modelled facing -Z and a lobby building faces south, so the
		whole thing is placed in the hall's own frame and then turned.
		Its books ride that turn with it, which is why they are placed
		before it rather than in world space.
	]]
	--[[
		The Dex Hall is built here from parts rather than placed as a
		model (owner, 2026-11-01: "make a whole new building", "i want you
		to just use parts already in roblox"), so nothing below runs for
		it. The two books the owner modelled are still imports; everything
		they stand on is parts, in the sheet's own colours.
	]]
	if name == "DexHall" then
		local dex = LobbyConfig.dex
		local look = dex.colours
		local hall = dex.hall
		local wide, deepHall = hall.across, hall.deep
		local halfD = deepHall / 2
		--[[ Front is +Z, as every station's is, and `base` already
		     carries the turn that puts that front toward the middle. ]]
		local function spotIn(x: number, y: number, z: number): CFrame
			return base * CFrame.new(x, y, z)
		end
		local function slab(
			label: string,
			block: Vector3,
			x: number,
			y: number,
			z: number,
			colour: Color3
		): Part
			return part(label, block, spotIn(x, y, z), colour, model)
		end
		--[[ The plinth it stands on, two steps up to the porch, and the
		     carpet running over them and in through the front. ]]
		slab("Plinth", Vector3.new(wide, 1.5, deepHall), 0, 0.75, -2.5, look.stone)
		slab("Step", Vector3.new(12.8, 1, 3.1), 0, 0.5, halfD - 1.1, look.stone)
		slab("Step", Vector3.new(12.8, 0.5, 3.1), 0, 0.25, halfD + 1.9, look.stone)
		--[[ The carpet lies over the porch and the top step only; the
		     sheet leaves the lower step cream, so the red reads as a
		     runner going in rather than as a red staircase. ]]
		slab("Carpet", Vector3.new(9, 0.12, 3.1), 0, 1.06, halfD - 1.1, look.red)
		slab("Carpet", Vector3.new(9, 0.12, 11), 0, 1.56, 9, look.red)
		--[[ Its gold edging, which the sheet runs down either side. ]]
		for _, sx in { -1, 1 } do
			slab("CarpetEdge", Vector3.new(0.7, 0.14, 11), sx * 4.85, 1.57, 9, look.gold)
		end

		--[[ The timber frame: a post at each corner and either side of
		     the porch, a beam along the top and the bottom, and the cream
		     panels filling between them. ]]
		local wallY, postH = 5.5, 8
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				slab("Post", Vector3.new(2, postH, 2), sx * 18, wallY, sz * 13 - 2.5, look.timber)
			end
			slab("Post", Vector3.new(2, postH, 2), sx * 9.55, wallY, 10.5, look.timber)
			slab("PanelSide", Vector3.new(1.6, 4, 24), sx * 18, wallY, -2.5, look.panel)
			slab("BeamSide", Vector3.new(2, 2, 24), sx * 18, 2.5, -2.5, look.timber)
			slab("BeamSide", Vector3.new(2, 2, 24), sx * 18, 8.5, -2.5, look.timber)
			slab("PanelFront", Vector3.new(6.45, 4, 1.6), sx * 13.77, wallY, 10.5, look.panel)
			slab("BeamFront", Vector3.new(6.45, 2, 2), sx * 13.77, 2.5, 10.5, look.timber)
		end
		slab("PanelBack", Vector3.new(34, 4, 1.6), 0, wallY, -15.5, look.panel)

		--[[
			The window behind each book stand (owner, 2026-11-01: "the
			squares behind the book stand need to be windowd").

			It is the front wall panel, the one the stand stands against,
			which read as a plain cream square from out on the lawn. A
			first attempt put panes across the back wall and down both
			sides, inside, which was the wrong wall entirely -- those are
			reverted.

			Centred in the panel rather than set against one face, so it
			reads as a window from the lawn and from the porch alike.
		]]
		for _, sx in { -1, 1 } do
			local x = sx * 13.77
			slab("WindowFrame", Vector3.new(5.6, 3.6, 1.9), x, wallY, 10.5, look.timber)
			local pane = slab("Window", Vector3.new(4.6, 2.8, 2.1), x, wallY, 10.5, look.glass)
			pane.Material = Enum.Material.Glass
			pane.Transparency = 0.45
			slab("WindowBar", Vector3.new(0.35, 2.8, 2.2), x, wallY, 10.5, look.timber)
			slab("WindowBar", Vector3.new(4.6, 0.35, 2.2), x, wallY, 10.5, look.timber)
		end

		slab("BeamBack", Vector3.new(34, 2, 2), 0, 2.5, -15.5, look.timber)
		slab("BeamTop", Vector3.new(wide, 2, 2), 0, 8.5, -15.5, look.timber)
		slab("BeamTop", Vector3.new(wide, 2, 2), 0, 8.5, 10.5, look.timber)

		--[[ The porch columns. Square, as the sheet draws them -- they
		     were turned cylinders at first, which read as a temple rather
		     than the toy-brick building this is. A white shaft between
		     two wider blocks, banded in gold under each. ]]
		for _, sx in { -1, 1 } do
			local x = sx * 7.3
			slab("ColumnFoot", Vector3.new(3.4, 1, 3.4), x, 2, 12.5, look.column)
			slab("ColumnBand", Vector3.new(3.1, 0.8, 3.1), x, 2.9, 12.5, look.gold)
			slab("Column", Vector3.new(2.6, 5, 2.6), x, 5.8, 12.5, look.column)
			slab("ColumnBand", Vector3.new(3.1, 0.8, 3.1), x, 8.7, 12.5, look.gold)
			slab("ColumnHead", Vector3.new(3.4, 1, 3.4), x, 9.6, 12.5, look.column)
		end

		--[[
			The roof. Its pitch is shallow because the sheet's is: a slope
			of this width tilted 18.6 degrees made a steep A that read as
			a chalet, where the sheet has a long low roof whose eaves come
			down just over the wall tops (owner, 2026-11-01: "gable and
			roof").

			The flat top is where the two slopes meet, so the ridge
			follows the pitch down rather than being a number of its own,
			and the book rests on it.
		]]
		--[[
			The roof: a slope either side meeting one flat cap, all of it
			flush (owner, 2026-11-01: "make sure the roof is flush").

			It was two stacked slabs over the slopes, which left a step
			along the ridge and a wedge where each slope ran into them.
			There is one cap now, its **top surface** set to the ridge and
			the slopes' inner edges arriving at exactly that height: the
			ridge is not a free number, it is where a slope of this pitch
			gets to, which `ridgeOf` works out.

			The cap reaches a little past each slope's inner edge, so the
			join is buried rather than butted -- an overlap cannot be
			seen, a hairline gap can.
		]]
		local pitch = math.rad(hall.pitch)
		--[[ Long enough to overhang the walls by three studs. It used to
		     stop within a thirtieth of a stud of the wall at x = 18,
		     which left a slit of daylight along the eaves you could see
		     straight through from inside (owner, 2026-11-01: "i dont
		     want to see through this"). An overhang cannot leave a slit. ]]
		local slopeWide = 17.5
		--[[ The cap's half-width, where a slope's inner edge lands. ]]
		local flatHalf = 4.2
		local lift = slopeWide / 2 * math.sin(pitch)
		local reach = slopeWide / 2 * math.cos(pitch)
		local thick = 1.5
		--[[ The eaves sit a little *under* the top beam, so the roof laps
		     over the wall rather than meeting it edge to edge. ]]
		local eave = 9.3
		--[[ Where the slope's top surface arrives over the middle. ]]
		local ridge = eave + 2 * lift + (thick / 2) / math.cos(pitch)
		for _, sx in { -1, 1 } do
			--[[ `fromOrientation` and not `Angles`: a slope is turned a
			     quarter round to lie along the building and then tilted,
			     and doing the tilt about the wrong axis stood one slope
			     on its edge and laid the other flat over the lawn. ]]
			part(
				"RoofSlope",
				Vector3.new(30, thick, slopeWide),
				spotIn(sx * (flatHalf + reach), eave + lift, -2.5)
					* CFrame.fromOrientation(math.rad(sx * hall.pitch), math.pi / 2, 0),
				look.roof,
				model
			)
			--[[ A gold block at each of the roof's four corners. Square,
			     as the sheet has them, not the turned cylinders they
			     were. ]]
			for _, sz in { -1, 1 } do
				slab(
					"RoofCap",
					Vector3.new(3, 2.4, 3.4),
					sx * (flatHalf + reach * 2 - 1),
					eave - 0.3,
					sz * 13.2 - 2.5,
					look.gold
				)
			end
		end
		slab(
			"RoofTop",
			Vector3.new(flatHalf * 2 + 1.8, thick, 30),
			0,
			ridge - thick / 2,
			-2.5,
			look.roof
		)

		--[[
			The gable ends.

			The roof's ridge runs front to back, so it rises toward the
			middle while the wall tops stay level: that left a triangle
			of open sky over the back wall and over the porch, which from
			inside is a clear view out (owner, 2026-11-01: "the roof isnt
			closed"). A vertical ray never found it -- the roof is over
			your head the whole way -- because the hole is sideways.

			Filled with a run of panels stepping in toward the middle,
			each one rising to the roof's underside at the *outer* edge
			of its own band, so no step can poke through the slope above
			it.
		]]
		local wallTop = 9.4
		local outerX = flatHalf + reach * 2
		--[[ How high the roof's underside is over the middle. ]]
		local peakUnder = (eave - 0.8) + (outerX - flatHalf) * math.tan(pitch)
		--[[
			One wedge each side, rather than a run of steps: stepped
			panels showed from outside under the eaves as a cream
			staircase climbing to the gable. A wedge lies flush under the
			slope.

			A wedge's face falls along its own +Z, so a quarter turn about
			Y lays it along X; the sign of the turn picks which end is
			tall, and each side wants its tall end at the middle.
		]]
		local function gableEnd(z: number)
			for _, sx in { -1, 1 } do
				local wedge = part(
					"GableEnd",
					Vector3.new(1.5, peakUnder - wallTop, outerX),
					spotIn(-sx * outerX / 2, (wallTop + peakUnder) / 2, z)
						* CFrame.Angles(0, sx * math.pi / 2, 0),
					look.panel,
					model,
					Enum.PartType.Wedge
				)
				wedge.CanCollide = true
			end
			--[[ The flat over the middle, where the roof is level. ]]
			slab(
				"GableEnd",
				Vector3.new(flatHalf * 2, peakUnder - wallTop, 1.5),
				0,
				(wallTop + peakUnder) / 2,
				z,
				look.panel
			)
		end
		gableEnd(-15.5)
		gableEnd(10.5)

		--[[
			The gable over the porch.

			Its two arms are **timber**, not roof. The sheet frames a
			cream face with brown rafters and lets the purple show behind
			them; drawn in the roof's own purple they read as two beams
			thrown across the front rather than the edges of a gable.

			The face sits behind the rafters, the king post runs up the
			middle of it, a beam closes the bottom and a gold block caps
			the peak where the two meet.
		]]
		local gableFoot, gableApex, gableHalf = 10.1, 13.4, 7
		local gableMid = (gableApex + gableFoot) / 2
		local gableRun = math.sqrt(gableHalf ^ 2 + (gableApex - gableFoot) ^ 2)
		local gableTilt = math.atan2(gableApex - gableFoot, gableHalf)
		slab(
			"GableFace",
			Vector3.new(gableHalf * 2, gableApex - gableFoot, 0.8),
			0,
			gableMid,
			13.6,
			look.panel
		)
		slab(
			"GablePost",
			Vector3.new(1.3, gableApex - gableFoot, 1.1),
			0,
			gableMid,
			10.7,
			look.timber
		)
		--[[ Turning a part about Z by a positive angle lifts its +X end,
		     so the left arm takes the positive one: with the signs the
		     other way round they made a V hanging into the doorway
		     instead of a peak over it. ]]
		for _, sx in { -1, 1 } do
			part(
				"GableRafter",
				Vector3.new(gableRun, 1.1, 1.6),
				spotIn(sx * gableHalf / 2, gableMid, 14.1)
					* CFrame.fromOrientation(0, 0, -sx * gableTilt),
				look.timber,
				model
			)
		end
		slab(
			"GableBeam",
			Vector3.new(gableHalf * 2 + 1.4, 1.1, 1.6),
			0,
			gableFoot,
			14.1,
			look.timber
		)
		slab("GablePeak", Vector3.new(2.4, 1.3, 2.2), 0, gableApex + 0.5, 14.1, look.gold)

		--[[ Inside: the counter, and a shelf of books behind it. ]]
		--[[ Set well back. It stood at the front at first, which
		     turned the whole entrance into a letterbox slot over its
		     top: the sheet shows a doorway you see through, with the
		     counter and the shelves behind it. ]]
		slab("Counter", Vector3.new(20, 2.6, 3.4), 0, 2.8, -4, look.timber)
		slab("CounterTop", Vector3.new(21, 0.5, 4.4), 0, 4.35, -4, look.timber)
		slab("ShelfBack", Vector3.new(22.8, 6, 3), 0, 4.5, -13, look.timber)
		for row = 0, 2 do
			slab("ShelfBoard", Vector3.new(22.8, 0.4, 1), 0, 4.37 + row * 1.66, -11, look.timber)
			for col = 0, 5 do
				slab(
					"ShelfBook",
					Vector3.new(1.3, 1.6, 0.8),
					(col - 2.5) * 3.4,
					5.3 + row * 1.66,
					-11.1,
					look.books[(row * 6 + col) % #look.books + 1]
				)
			end
		end

		--[[ A lantern either side of the porch, lit. ]]
		local lantern = dex.lanterns
		for _, sx in { -1, 1 } do
			local x = sx * lantern.out
			slab(
				"LanternArm",
				Vector3.new(0.4, 0.3, 0.6),
				x,
				lantern.height + 1.15,
				lantern.forward - 0.3,
				look.iron
			)
			slab(
				"LanternCap",
				Vector3.new(1.2, 0.5, 1.2),
				x,
				lantern.height + 0.75,
				lantern.forward,
				look.iron
			)
			slab(
				"LanternFoot",
				Vector3.new(1.2, 0.3, 1.2),
				x,
				lantern.height - 0.65,
				lantern.forward,
				look.iron
			)
			local glass = slab(
				"Lantern",
				Vector3.new(0.96, 1, 0.96),
				x,
				lantern.height,
				lantern.forward,
				look.lantern
			)
			glass.Material = Enum.Material.Neon
			local light = Instance.new("PointLight")
			light.Color = look.lantern
			light.Range = lantern.range
			light.Brightness = lantern.brightness
			light.Parent = glass
		end

		--[[ The two pads out front, and the owner's stand on each. The
		     books were modelled facing -Z, so they take `turn` on top of
		     the building's own. ]]
		local pads = dex.pads
		for _, sx in { -1, 1 } do
			slab("StandPad", pads.size, sx * pads.out, pads.top / 2, pads.forward, look.stone)
			dexPiece(
				"StandBook",
				dex.standBook,
				base
					* CFrame.new(sx * pads.out, pads.top, pads.forward)
					* CFrame.Angles(0, dex.turn, 0),
				model
			)
		end

		--[[ And the open book resting on the roof. ]]
		dexPiece(
			"RoofBook",
			dex.roofBook,
			base
				* CFrame.new(0, ridge - dex.roofBook.seat, dex.roofBook.forward)
				* CFrame.Angles(0, dex.turn, 0),
			model
		)

		--[[ No wooden board on this one: at any size it covered the
		     gable it had to hang on. Its name floats over it instead,
		     as every other station's does. ]]
		if spec.title then
			floatingTitle(spec, base * CFrame.new(0, ridge + 12, 0), model)
		end
		model.Parent = parent
		return Vector3.new(wide + 2, ridge, deepHall + 2)
	end
	local function box(label: string, s: Vector3, offset: Vector3, colour: Color3): Part
		return part(label, s, base * CFrame.new(offset), colour, model)
	end
	local floor = 1.4
	local top = floor + h
	local front = d / 2
	box("Foundation", Vector3.new(w + 2, floor, d + 2), Vector3.new(0, floor / 2, 0), COLOURS.rock)
	box("Walls", Vector3.new(w, h, d), Vector3.new(0, floor + h / 2, 0), spec.walls)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(
				"Post",
				Vector3.new(1.4, h, 1.4),
				Vector3.new(sx * w / 2, floor + h / 2, sz * d / 2),
				COLOURS.woodDark
			)
		end
	end
	for _, sz in { -1, 1 } do
		box(
			"Beam",
			Vector3.new(w + 0.8, 1.2, 0.8),
			Vector3.new(0, top - 0.6, sz * (front + 0.1)),
			COLOURS.woodDark
		)
	end
	box(
		"Sill",
		Vector3.new(w + 0.6, 0.8, 0.6),
		Vector3.new(0, floor + 0.4, front + 0.2),
		COLOURS.woodDark
	)
	-- the door
	box(
		"DoorFrame",
		Vector3.new(6.4, 8.4, 0.4),
		Vector3.new(0, floor + 4.2, front + 0.1),
		COLOURS.wood
	)
	box(
		"Door",
		Vector3.new(5, 7.6, 0.4),
		Vector3.new(0, floor + 3.8, front + 0.3),
		COLOURS.woodDark
	)
	blob(
		"Knob",
		Vector3.new(0.6, 0.6, 0.6),
		base * CFrame.new(1.6, floor + 3.6, front + 0.6),
		COLOURS.gold,
		model
	)
	-- two windows, framed and crossed
	for _, sx in { -1, 1 } do
		local x = sx * w * 0.3
		local y = floor + h * 0.5
		box("WindowFrame", Vector3.new(5.4, 5, 0.4), Vector3.new(x, y, front + 0.1), COLOURS.wood)
		box("Window", Vector3.new(4.4, 4, 0.4), Vector3.new(x, y, front + 0.25), COLOURS.glass).Material =
			Enum.Material.Glass
		box("Bar", Vector3.new(0.4, 4, 0.5), Vector3.new(x, y, front + 0.3), COLOURS.woodDark)
		box("Bar", Vector3.new(4.4, 0.4, 0.5), Vector3.new(x, y, front + 0.3), COLOURS.woodDark)
		-- a flower box under it
		box("FlowerBox", Vector3.new(5.4, 1, 1.4), Vector3.new(x, y - 3, front + 0.7), COLOURS.wood)
		for k = -2, 2 do
			blob(
				"Bloom",
				Vector3.new(1, 0.9, 1),
				base * CFrame.new(x + k * 1, y - 2.2, front + 0.7),
				COLOURS.flowers[(k + 2) % #COLOURS.flowers + 1],
				model
			)
		end
	end
	-- the roof: two slopes meeting at a ridge along the front
	local over = 2
	local slope = Vector3.new(w + over * 2, spec.rise, front + over)
	local frontSlope = part(
		"Roof",
		slope,
		base * CFrame.new(0, top + spec.rise / 2, (front + over) / 2) * CFrame.Angles(0, math.pi, 0),
		spec.roof,
		model
	)
	frontSlope.Shape = Enum.PartType.Wedge
	local backSlope = part(
		"Roof",
		slope,
		base * CFrame.new(0, top + spec.rise / 2, -(front + over) / 2),
		spec.roof,
		model
	)
	backSlope.Shape = Enum.PartType.Wedge
	part(
		"Ridge",
		Vector3.new(w + over * 2 + 0.6, 1.8, 1.8),
		base * CFrame.new(0, top + spec.rise, 0),
		spec.roof:Lerp(Color3.new(0, 0, 0), 0.25),
		model,
		Enum.PartType.Cylinder
	)
	box(
		"Eave",
		Vector3.new(w + over * 2, 0.6, 0.8),
		Vector3.new(0, top, front + over),
		spec.roof:Lerp(Color3.new(0, 0, 0), 0.25)
	)
	if spec.chimney then
		box(
			"Chimney",
			Vector3.new(4, spec.rise + 5, 4),
			Vector3.new(-w * 0.28, top + (spec.rise + 5) / 2, -d * 0.2),
			COLOURS.rock
		)
		local cap = box(
			"ChimneyCap",
			Vector3.new(5, 1, 5),
			Vector3.new(-w * 0.28, top + spec.rise + 5, -d * 0.2),
			COLOURS.rockLight
		)
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(220, 220, 220)
		smoke.Opacity = 0.12
		smoke.RiseVelocity = 4
		smoke.Size = 3
		smoke.Parent = cap
	end
	if spec.columns then
		-- a porch of white pillars along the front, under a flat roof
		for k = 0, 3 do
			local x = (k - 1.5) * (w - 6) / 3
			pillar(
				"Column",
				base.Position + Vector3.new(x, floor, front + 3.4),
				h,
				2,
				COLOURS.foam,
				model
			)
		end
		box("Porch", Vector3.new(w, 1.2, 7), Vector3.new(0, top + 0.6, front + 3), spec.walls)
		box(
			"PorchFloor",
			Vector3.new(w + 2, floor, 7),
			Vector3.new(0, floor / 2, front + 3.5),
			COLOURS.rockLight
		)
	end
	signboard(
		spec.sign,
		base * CFrame.new(0, top - 2.2, front + (if spec.columns then 6.8 else 0.6)),
		math.min(w * 0.6, 20),
		3.4,
		model
	)
	-- what each station is for, out front
	if name == "Blacksmith" then
		local anvilAt = Vector3.new(-w / 2 + 3, 0, front + 5)
		box(
			"AnvilFoot",
			Vector3.new(1.6, 2.2, 1.2),
			anvilAt + Vector3.new(0, 1.1, 0),
			COLOURS.woodDark
		)
		box(
			"Anvil",
			Vector3.new(3.6, 1.2, 1.6),
			anvilAt + Vector3.new(0, 2.8, 0),
			Color3.fromRGB(70, 74, 84)
		)
		local forgeAt = Vector3.new(w / 2 - 4, 0, front + 3)
		box("Forge", Vector3.new(6, 5, 4), forgeAt + Vector3.new(0, 2.5, 0), COLOURS.rock)
		local fire = box(
			"ForgeFire",
			Vector3.new(3.4, 2, 0.4),
			forgeAt + Vector3.new(0, 2, 2.05),
			Color3.fromRGB(255, 140, 40)
		)
		fire.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 60)
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = fire
	end
	-- its trade: a giant emblem on the ridge, props out front, its title above
	local ridge = top + spec.rise
	local function spot(offset: Vector3): CFrame
		return base * CFrame.new(offset)
	end
	if spec.emblem == "egg" then
		egg(
			spot(Vector3.new(0, ridge + 4, 0)),
			Vector3.new(6, 8, 6),
			EMBLEM.eggShell,
			EMBLEM.eggSpots,
			model
		)
		for _, sx in { -1, 1 } do
			nest(spot(Vector3.new(sx * (w / 2 - 3), 0, front + 2.6)), model)
		end
	elseif spec.emblem == "sword" then
		sword(spot(Vector3.new(w * 0.12, ridge + 0.6, 0)) * CFrame.Angles(0, 0, -0.25), 1.4, model)
		local rack = spot(Vector3.new(w / 2 + 3.4, 0, 0)) * CFrame.Angles(0, -math.pi / 2, 0)
		weaponRack(rack, { "sword", "sword", "sword" }, model)
	elseif spec.emblem == "shield" then
		shield(spot(Vector3.new(0, ridge + 4.4, 0)), 9, model)
		armourStand(spot(Vector3.new(-w / 2 + 3.5, 0, front + 4)), model)
		weaponRack(spot(Vector3.new(w / 2 - 4.5, 0, front + 3)), { "bow", "staff", "sword" }, model)
	end
	if spec.title then
		floatingTitle(spec, base * CFrame.new(0, ridge + 14, 0), model)
	end
	model.Parent = parent
	return Vector3.new(w + 2, top + spec.rise, d + 2)
end

--[[ An egg or a crate out in the open (`LobbyConfig.stands`): a smooth
     model on a round wooden platform, solid, its name and price floating
     above. ]]
local function standOut(kind: string, key: string, centre: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Stand_" .. key
	local across = LobbyConfig.standSize
	pillar("Rim", centre, 0.6, across + 0.8, COLOURS.gold, model)
	pillar("Platform", centre, 1.2, across, COLOURS.wood, model)
	pillar("Pedestal", centre + Vector3.new(0, 1.2, 0), 1, across * 0.55, COLOURS.rockLight, model)
	local floor = 2.2
	local look = STAND_LOOK[key] :: any
	local height = 8
	if kind == "egg" then
		local size = Vector3.new(5.8, 7.6, 5.8)
		local middle = centre + Vector3.new(0, floor + size.Y / 2, 0)
		blob("Shell", size, CFrame.new(middle), look.shell, model)
		-- spots laid on the shell, flattened against it
		for k = 0, 9 do
			local turn = k * 2.4
			local lift = math.rad(-40 + (k % 4) * 30)
			local normal = Vector3.new(
				math.cos(turn) * math.cos(lift),
				math.sin(lift),
				math.sin(turn) * math.cos(lift)
			)
			local at = middle + normal * (size / 2) * 0.96
			local spot = 1.2 + (k % 3) * 0.35
			blob(
				"Spot",
				Vector3.new(spot, spot, 0.5),
				CFrame.lookAt(at, at + normal),
				look.spots,
				model
			)
		end
		-- a sprout on top
		local crown = middle + Vector3.new(0, size.Y / 2 - 0.2, 0)
		for k = 0, 2 do
			local turn = k * math.pi * 2 / 3
			blob(
				"Leaf",
				Vector3.new(0.8, 0.4, 2.4),
				CFrame.new(crown + Vector3.new(math.cos(turn), 0.5, math.sin(turn)) * 0.8)
					* CFrame.Angles(0, -turn + math.pi / 2, 0)
					* CFrame.Angles(0.5, 0, 0),
				look.top,
				model
			)
		end
		height = size.Y
	else
		local w = 6.4
		height = 5.6
		local box = centre + Vector3.new(0, floor + height / 2, 0)
		part("Crate", Vector3.new(w, height, w), CFrame.new(box), look.wood, model)
		part(
			"Lid",
			Vector3.new(w + 0.6, 0.7, w + 0.6),
			CFrame.new(box + Vector3.new(0, height / 2, 0)),
			look.wood:Lerp(Color3.new(0, 0, 0), 0.25),
			model
		)
		part("Band", Vector3.new(w + 0.3, 1, w + 0.3), CFrame.new(box), look.band, model)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(
					"Corner",
					Vector3.new(0.8, height + 0.3, 0.8),
					CFrame.new(box + Vector3.new(sx * w / 2, 0, sz * w / 2)),
					look.metal,
					model
				)
			end
		end
		part(
			"Lock",
			Vector3.new(1.4, 1.6, 0.5),
			CFrame.new(box + Vector3.new(0, 0.6, w / 2 + 0.3)),
			look.metal,
			model
		)
	end
	wall(
		"StandWall",
		Vector3.new(across, height + floor, across),
		CFrame.new(centre + Vector3.new(0, (height + floor) / 2, 0)),
		model
	)
	-- its name and price above it
	local item: { name: string, price: number }? = nil
	if kind == "egg" then
		for _, entry in Eggs.list do
			if entry.key == key then
				item = { name = entry.name, price = entry.price }
			end
		end
	else
		for _, crate in Shop.crates do
			if crate.area == key then
				item = { name = crate.name .. " CRATE", price = crate.price }
			end
		end
	end
	if item then
		local anchor = wall(
			"StandLabel",
			Vector3.one,
			CFrame.new(centre + Vector3.new(0, floor + height + 4, 0)),
			model
		)
		anchor.CanCollide = false
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromScale(12, 3.2)
		board.LightInfluence = 0
		board.MaxDistance = 140
		board.Parent = anchor
		for line, text in { item.name, tostring(item.price) .. " COINS" } do
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 0.5)
			label.Position = UDim2.fromScale(0, (line - 1) * 0.5)
			label.Font = Enum.Font.Arcade
			label.TextScaled = true
			label.Text = text
			label.TextColor3 = if line == 1
				then Color3.new(1, 1, 1)
				else Color3.fromRGB(255, 205, 40)
			label.TextStrokeTransparency = 0
			label.Parent = board
		end
	end
	model.Parent = parent
end

--[[ A portal: a stone ring on two legs, a swirl in its colour (or a dark
     disc and a padlock while its area is locked), and its name on a board
     above. ]]
local function portalArch(index: number, portal: LobbyConfig.Portal, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. index
	local at = Lobby.archAt(index)
	local _, ledge = rowCentre(Lobby.rowOf(index))
	local radius = LobbyConfig.archSize / 2 - 1
	local centre = world(at, LAWN + ledge + LobbyConfig.archRise)
	local active = portal.levels ~= nil
	local stone = if active then COLOURS.rockLight else COLOURS.rock
	local SEGMENTS = 18
	for k = 0, SEGMENTS - 1 do
		local angle = k / SEGMENTS * math.pi * 2
		local spot = centre + Vector3.new(math.cos(angle), math.sin(angle), 0) * radius
		local colour = if k == SEGMENTS / 4 then COLOURS.gold else stone
		part(
			"Ring",
			Vector3.new(2.4, 2.6, 2.4),
			CFrame.new(spot) * CFrame.Angles(0, 0, angle),
			colour,
			model
		)
	end
	for _, side in { -1, 1 } do
		local leg = part(
			"Leg",
			Vector3.new(2.6, LobbyConfig.archRise, 2.6),
			CFrame.new(
				world(at + Vector2.new(side * radius, 0), LAWN + ledge + LobbyConfig.archRise / 2)
			),
			stone,
			model
		)
		leg.CanCollide = true
	end
	local disc = part(
		"Swirl",
		Vector3.new(0.4, radius * 2 - 1.2, radius * 2 - 1.2),
		CFrame.new(centre) * CFrame.Angles(0, math.pi / 2, 0),
		if active then portal.tint or COLOURS.gold else Color3.fromRGB(44, 46, 60),
		model,
		Enum.PartType.Cylinder
	)
	if active then
		disc.Material = Enum.Material.Neon
		disc.Transparency = 0.15
		local core = part(
			"SwirlCore",
			Vector3.new(0.5, radius, radius),
			CFrame.new(centre) * CFrame.Angles(0, math.pi / 2, 0),
			(portal.tint or COLOURS.gold):Lerp(Color3.new(1, 1, 1), 0.5),
			model,
			Enum.PartType.Cylinder
		)
		core.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = portal.tint or COLOURS.gold
		light.Range = 18
		light.Brightness = 2
		light.Parent = disc
	else
		-- a padlock across the dark
		local lock = centre + Vector3.new(0, -1, 0.6)
		part("Lock", Vector3.new(3.2, 2.8, 1), CFrame.new(lock), COLOURS.gold, model)
		part(
			"Keyhole",
			Vector3.new(0.6, 1, 0.2),
			CFrame.new(lock + Vector3.new(0, 0, 0.55)),
			COLOURS.woodDark,
			model
		)
		for _, side in { -1, 1 } do
			part(
				"Shackle",
				Vector3.new(0.5, 2, 0.5),
				CFrame.new(lock + Vector3.new(side * 1, 2, 0)),
				COLOURS.rockLight,
				model
			)
		end
		part(
			"Shackle",
			Vector3.new(2.5, 0.5, 0.5),
			CFrame.new(lock + Vector3.new(0, 3, 0)),
			COLOURS.rockLight,
			model
		)
	end
	if portal.name then
		--[[ The arches stand in rows across the north edge and all face
		     the lawn, so theirs is the plain southward board. ]]
		signboard(
			string.upper(portal.name),
			CFrame.new(centre + Vector3.new(0, radius + 2.6, 0.4)),
			LobbyConfig.archSpacing - 4,
			2.4,
			model
		)
	end
	model.Parent = parent
end

--[[ Wide wooden steps up a ledge's front edge: from `low` to `high`,
     starting at `edge` (z) and coming south, `width` across at `x`. ]]
local function steps(
	x: number,
	edge: number,
	low: number,
	high: number,
	width: number,
	parent: Instance
)
	local count = math.max(1, math.ceil((high - low) / 0.6))
	local rise = (high - low) / count
	for k = 1, count do
		-- step k's top stands k rises above the lower floor, k steps back
		local topY = low + k * rise
		local depth = 1.4
		local z = edge + (count - k + 0.5) * depth
		local step = part(
			"Step",
			Vector3.new(width, topY, depth),
			CFrame.new(world(Vector2.new(x, z), LAWN + topY / 2 - 0.01)),
			if k % 2 == 0 then COLOURS.wood else COLOURS.woodDark:Lerp(COLOURS.wood, 0.5),
			parent
		)
		step.CanCollide = true
		step.CanQuery = true
	end
end

local function near(a: Vector2, list: { Vector2 }, reach: number): boolean
	for _, b in list do
		if (a - b).Magnitude < reach then
			return true
		end
	end
	return false
end

function Lobby.build(parent: Instance)
	--[[ The Dex Hall's two books, fetched before anything is placed: they
	     are the only meshes in the lobby, everything else being parts, so
	     this is the one wait and it is two ids. ]]
	dexTemplates =
		MeshTemplates.load({ LobbyConfig.dex.roofBook.mesh, LobbyConfig.dex.standBook.mesh })
	local rng = Random.new(20261027)
	local root = Instance.new("Folder")
	root.Name = "Lobby"
	local half = LobbyConfig.size / 2

	-- the lawn, out to the wood's edge
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	part(
		"Lawn",
		Vector3.new(OUTER_FLOOR, 1, OUTER_FLOOR),
		CFrame.new(world(Vector2.zero, LAWN - 0.5)),
		COLOURS.grass,
		root
	).CanCollide =
		true

	-- the sandy paths: an edge under each run, rounded at every bend
	local width = LobbyConfig.pathWidth
	local trail: { Vector2 } = {}
	local paths = Instance.new("Model")
	paths.Name = "Paths"
	local function lay(a: Vector2, b: Vector2, extra: number, y: number, colour: Color3)
		local length = (b - a).Magnitude
		local middle = (a + b) / 2
		local flat = CFrame.lookAt(world(middle, y), world(b, y))
		part("Path", Vector3.new(width + extra, 0.2, length), flat, colour, paths)
	end
	local function joint(at: Vector2, across: number, y: number, colour: Color3)
		part(
			"Joint",
			Vector3.new(0.2, across, across),
			CFrame.new(world(at, y)) * CFrame.Angles(0, 0, math.pi / 2),
			colour,
			paths,
			Enum.PartType.Cylinder
		)
	end
	for _, run in LobbyConfig.paths do
		for k = 1, #run do
			joint(run[k], width + 2, LAWN + 0.02, COLOURS.sandEdge)
			joint(run[k], width, LAWN + 0.08, COLOURS.sand)
			if k < #run then
				lay(run[k], run[k + 1], 2, LAWN + 0.02, COLOURS.sandEdge)
				lay(run[k], run[k + 1], 0, LAWN + 0.08, COLOURS.sand)
				local count = math.ceil((run[k + 1] - run[k]).Magnitude / 4)
				for s = 0, count do
					table.insert(trail, run[k]:Lerp(run[k + 1], s / count))
				end
			end
		end
	end
	paths.Parent = root

	--[[ Where the lawn's scatter may not go: each station and a little round
	     it, the stands, the spawn, the portals and the paths (`trail`). ]]
	local clear: { { at: Vector2, reach: number } } = { { at = LobbyConfig.spawn, reach = 8 } }
	local function keep(at: Vector2, reach: number)
		table.insert(clear, { at = at, reach = reach })
	end

	-- the fountain at the spawn, on a paved ring
	for _, station in LobbyConfig.stations do
		if station.piece == "SpawnCampfire" then
			local plaza = LobbyConfig.plaza
			local basin = LobbyConfig.fountain
			joint(station.at, plaza + 2, LAWN + 0.03, COLOURS.sandEdge)
			joint(station.at, plaza, LAWN + 0.1, COLOURS.sand)
			local fountain = Instance.new("Model")
			fountain.Name = "Fountain"
			local foot = world(station.at, LAWN)
			pillar("Basin", foot, 2.4, basin, COLOURS.rockLight, fountain)
			local pool = pillar("Pool", foot, 2.5, basin - 2, COLOURS.water, fountain)
			pool.Transparency = 0.1
			pillar("Column", foot, 7, 2.4, COLOURS.rock, fountain)
			pillar("Bowl", foot + Vector3.new(0, 6, 0), 1.2, 7, COLOURS.rockLight, fountain)
			pillar("BowlWater", foot + Vector3.new(0, 6.1, 0), 1.2, 6, COLOURS.water, fountain).Transparency =
				0.1
			blob(
				"Spout",
				Vector3.new(2, 3, 2),
				CFrame.new(foot + Vector3.new(0, 8.4, 0)),
				COLOURS.foam,
				fountain
			).Transparency =
				0.2
			for k = 0, 7 do
				local angle = k * math.pi / 4
				blob(
					"Splash",
					Vector3.new(1.6, 1, 1.6),
					CFrame.new(
						foot + Vector3.new(math.cos(angle) * 4.2, 2.6, math.sin(angle) * 4.2)
					),
					COLOURS.foam,
					fountain
				).Transparency =
					0.3
			end
			fountain.Parent = root
			local ring = wall(
				"FountainWall",
				Vector3.new(8, basin, basin),
				CFrame.new(world(station.at, 4)) * CFrame.Angles(0, 0, math.pi / 2),
				root
			)
			ring.Shape = Enum.PartType.Cylinder
			keep(station.at, plaza / 2 + 2)
		end
	end

	-- the stations, each with a wall round it, and their stands out front
	for _, station in LobbyConfig.stations do
		local size = building(station.piece, station.at, root)
		if size then
			keep(station.at, Vector2.new(size.X, size.Z).Magnitude / 2 + 3)
			--[[ The wall that keeps players out of it is turned with it,
			     or a building standing at an angle would be fenced by a
			     box squared to the lawn. ]]
			wall(
				"StationWall",
				Vector3.new(size.X, 20, size.Z),
				CFrame.new(world(station.at, 10))
					* CFrame.Angles(0, LobbyConfig.facing(station.at), 0),
				root
			)
		end
		local spots = LobbyConfig.stands[station.piece]
		if spots then
			for _, spot in spots do
				--[[ Out front of its own station, whichever corner that
				     is on: the offset turns with the building. ]]
				local at = station.at + LobbyConfig.turnedOffset(station.at, spot.at)
				standOut(spot.kind, spot.key, world(at, LAWN), root)
				keep(at, LobbyConfig.standSize / 2 + 2)
			end
		end
	end

	-- the portal ledges, back row first, with steps up each
	local rows = Lobby.rowOf(#LobbyConfig.portals)
	local across = LobbyConfig.perRow * LobbyConfig.archSpacing + 24
	for row = rows, 1, -1 do
		local centre, height = rowCentre(row)
		local depth = LobbyConfig.rowDepth + (if row == rows then 24 else 0)
		local back = centre.Y - LobbyConfig.rowDepth / 2 - (if row == rows then 24 else 0)
		local middle = Vector2.new(centre.X, back + depth / 2)
		local ledge = part(
			"Ledge",
			Vector3.new(across, height - 0.5, depth),
			CFrame.new(world(middle, LAWN + (height - 0.5) / 2)),
			COLOURS.cliff,
			root
		)
		ledge.CanCollide = true
		ledge.CanQuery = true
		local grass = part(
			"LedgeGrass",
			Vector3.new(across + 1, 0.6, depth + 1),
			CFrame.new(world(middle, LAWN + height - 0.3)),
			COLOURS.grass,
			root
		)
		grass.CanCollide = true
		grass.CanQuery = true
		part(
			"LedgeShade",
			Vector3.new(across + 0.4, 0.8, depth + 0.4),
			CFrame.new(world(middle, LAWN + 0.4)),
			COLOURS.cliffDark,
			root
		)
		local front = centre.Y + LobbyConfig.rowDepth / 2 + 0.5
		local _, below = rowCentre(row - 1)
		local low = if row == 1 then 0 else below
		if row == 1 then
			steps(0, front, low, height, 40, root)
		else
			for _, side in { -1, 1 } do
				steps(side * (across / 2 - 8), front, low, height, 12, root)
			end
		end
	end
	for index, portal in LobbyConfig.portals do
		portalArch(index, portal, root)
		keep(Lobby.archAt(index), 10)
	end
	local back = rowCentre(rows)
	wall(
		"TerraceWall",
		Vector3.new(LobbyConfig.size.X, 24, 8),
		CFrame.new(world(back + Vector2.new(0, -14), 12)),
		root
	)

	--[[ A leaderboard: a board on two posts, the names on its dark face.
	     Built twice — FARTHEST ADVENTURERS and DEEPEST DELVERS
	     (`LobbyConfig.leaderboard`, `LobbyConfig.endlessLeaderboard`) — so
	     the two boards are the same board, drawn on by different modules. ]]
	local function buildBoard(name: string, board: typeof(LobbyConfig.leaderboard)): Part
		local face = board.face
		local foot = world(board.at, LAWN)
		local model = Instance.new("Model")
		model.Name = name
		for _, side in { -1, 1 } do
			local post = part(
				"Post",
				Vector3.new(1.4, face.centre.Y + face.size.Y / 2 + 1.5, 1.4),
				CFrame.new(
					foot
						+ Vector3.new(
							side * (face.size.X / 2 + 1.3),
							(face.centre.Y + face.size.Y / 2 + 1.5) / 2,
							0
						)
				),
				COLOURS.woodDark,
				model
			)
			post.CanCollide = true
		end
		part(
			"Backing",
			Vector3.new(face.size.X + 2, face.size.Y + 2, 0.8),
			CFrame.new(foot + Vector3.new(0, face.centre.Y, face.centre.Z - 0.6)),
			COLOURS.wood,
			model
		)
		part(
			"Crest",
			Vector3.new(face.size.X + 3, 1.4, 1.2),
			CFrame.new(
				foot + Vector3.new(0, face.centre.Y + face.size.Y / 2 + 1.4, face.centre.Z - 0.6)
			),
			COLOURS.gold,
			model
		)
		model.Parent = root
		local surface = part(
			`{name}Face`,
			Vector3.new(face.size.X, face.size.Y, 0.2),
			CFrame.new(foot + face.centre) * CFrame.Angles(0, math.pi, 0),
			Color3.fromRGB(28, 24, 22),
			root
		)
		surface.CastShadow = false
		keep(board.at, 14)
		return surface
	end

	leaderboardFace = buildBoard("Leaderboard", LobbyConfig.leaderboard)
	endlessLeaderboardFace = buildBoard("EndlessLeaderboard", LobbyConfig.endlessLeaderboard)

	-- lamps along the paths, at every other bend
	for _, run in LobbyConfig.paths do
		for k = 2, #run, 2 do
			local along = (run[k] - run[k - 1]).Unit
			local side = Vector2.new(-along.Y, along.X) * (width / 2 + 2)
			local at = run[k] + side
			local lamp = Instance.new("Model")
			lamp.Name = "Lamp"
			local post = pillar("Post", world(at, LAWN), 7, 0.8, COLOURS.woodDark, lamp)
			post.CanCollide = true
			local glow = blob(
				"Lantern",
				Vector3.new(1.8, 2, 1.8),
				CFrame.new(world(at, LAWN + 7.6)),
				Color3.fromRGB(255, 222, 140),
				lamp
			)
			glow.Material = Enum.Material.Neon
			part(
				"LampCap",
				Vector3.new(2.2, 0.5, 2.2),
				CFrame.new(world(at, LAWN + 8.8)),
				COLOURS.woodDark,
				lamp
			)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 214, 150)
			light.Range = 14
			light.Brightness = 0.8
			light.Parent = glow
			lamp.Parent = root
			keep(at, 2)
		end
	end

	-- waterfalls down the corner cliffs into round pools
	for _, at in LobbyConfig.waterfalls do
		local fall = Instance.new("Model")
		fall.Name = "Waterfall"
		local facing = CFrame.lookAt(world(at, LAWN), world(Vector2.zero, LAWN))
		local function put(label: string, size: Vector3, offset: Vector3, colour: Color3): Part
			return part(label, size, facing * CFrame.new(offset), colour, fall)
		end
		put("Cliff", Vector3.new(26, 30, 14), Vector3.new(0, 15, 6), COLOURS.cliff)
		put("CliffShade", Vector3.new(26.4, 10, 14.4), Vector3.new(0, 5, 6), COLOURS.cliffDark)
		put("CliffGrass", Vector3.new(27, 1.4, 15), Vector3.new(0, 30.4, 6), COLOURS.grass)
		put("Water", Vector3.new(9, 30, 1), Vector3.new(0, 15.4, -1.2), COLOURS.water).Transparency =
			0.1
		put("Shine", Vector3.new(1.4, 30, 1.1), Vector3.new(-2.2, 15.4, -1.4), COLOURS.foam).Transparency =
			0.4
		local pool = part(
			"Pool",
			Vector3.new(0.3, 20, 20),
			facing * CFrame.new(0, 0.12, -9) * CFrame.Angles(0, 0, math.pi / 2),
			COLOURS.water,
			fall,
			Enum.PartType.Cylinder
		)
		pool.Transparency = 0.05
		for k = 0, 5 do
			blob(
				"Foam",
				Vector3.new(3.4, 2.2, 3.4),
				facing * CFrame.new(-4 + k * 1.6, 0.8, -2.4 - (k % 2) * 1.2),
				COLOURS.foam,
				fall
			).Transparency =
				0.15
		end
		for k = 0, 6 do
			local angle = k / 7 * math.pi + math.pi
			blob(
				"PoolRock",
				Vector3.new(3.4, 2.4, 3) * (0.8 + (k % 3) * 0.2),
				facing * CFrame.new(math.cos(angle) * 10.5, 0.6, -9 - math.sin(angle) * 10.5),
				COLOURS.rock,
				fall
			)
		end
		fall.Parent = root
	end

	-- the cliffs round the clearing, grass on top, trees behind
	local spacing = LobbyConfig.ringSpacing
	local function ring(at: Vector2, out: Vector2)
		if near(at, LobbyConfig.waterfalls, spacing + 6) then
			return
		end
		local tall = rng:NextNumber(14, 26)
		local deep = rng:NextNumber(12, 18)
		local facing = CFrame.lookAt(world(at, LAWN), world(at - out, LAWN))
			* CFrame.Angles(0, rng:NextNumber(-0.12, 0.12), 0)
		local cliff = Instance.new("Model")
		cliff.Name = "Cliff"
		part(
			"Rock",
			Vector3.new(spacing + 6, tall, deep),
			facing * CFrame.new(0, tall / 2, deep / 2 - 3),
			COLOURS.cliff,
			cliff
		)
		part(
			"Shade",
			Vector3.new(spacing + 6.4, tall * 0.35, deep + 0.4),
			facing * CFrame.new(0, tall * 0.175, deep / 2 - 3),
			COLOURS.cliffDark,
			cliff
		)
		part(
			"Grass",
			Vector3.new(spacing + 7, 1.4, deep + 1),
			facing * CFrame.new(0, tall + 0.5, deep / 2 - 3),
			COLOURS.grass,
			cliff
		)
		for _, p in cliff:GetChildren() do
			(p :: BasePart).CastShadow = false
		end
		cliff.Parent = root
		tree(at + out * (deep + 4), rng:NextNumber(1.1, 1.5), rng, root, false)
	end
	for x = -half.X, half.X, spacing do
		ring(Vector2.new(x, -half.Y - 6), Vector2.new(0, -1))
		ring(Vector2.new(x, half.Y + 6), Vector2.new(0, 1))
	end
	for z = -half.Y + spacing, half.Y - spacing, spacing do
		ring(Vector2.new(-half.X - 6, z), Vector2.new(-1, 0))
		ring(Vector2.new(half.X + 6, z), Vector2.new(1, 0))
	end
	for _, band in OUTER_RINGS do
		local function outer(at: Vector2)
			tree(at, rng:NextNumber(band.grow[1], band.grow[2]), rng, root, false)
		end
		local edge = half + Vector2.new(band.out, band.out)
		for x = -edge.X, edge.X, band.spacing do
			outer(Vector2.new(x + rng:NextNumber() * 6, -edge.Y + rng:NextNumber() * 6))
			outer(Vector2.new(x + rng:NextNumber() * 6, edge.Y - rng:NextNumber() * 6))
		end
		for z = -edge.Y + band.spacing, edge.Y - band.spacing, band.spacing do
			outer(Vector2.new(-edge.X + rng:NextNumber() * 6, z + rng:NextNumber() * 6))
			outer(Vector2.new(edge.X - rng:NextNumber() * 6, z + rng:NextNumber() * 6))
		end
	end

	--[[ The lawn's scatter: one jittered point in each cell of a grid, its
	     kind drawn by weight, clear of everything above and of each other. ]]
	local weights = LobbyConfig.scatter
	local kinds: { string } = {}
	local totalWeight = 0
	for name, weight in weights do
		table.insert(kinds, name)
		totalWeight += weight
	end
	table.sort(kinds)
	local cell = LobbyConfig.scatterCell
	local scattered: { { at: Vector2, reach: number } } = {}
	local function blocked(at: Vector2, reach: number): boolean
		if
			at.Y - reach < LobbyConfig.terrace.Y + LobbyConfig.rowDepth / 2 + 8
			or near(at, trail, width / 2 + 1 + reach)
		then
			return true
		end
		if math.abs(at.X) + reach > half.X - 2 or math.abs(at.Y) + reach > half.Y - 2 then
			return true
		end
		for _, area in clear do
			if (at - area.at).Magnitude < area.reach + reach then
				return true
			end
		end
		for _, other in scattered do
			if (at - other.at).Magnitude < other.reach + reach then
				return true
			end
		end
		return false
	end
	for x = -half.X + cell / 2, half.X - cell / 2, cell do
		for z = -half.Y + cell / 2, half.Y - cell / 2, cell do
			local at = Vector2.new(x, z)
				+ Vector2.new(rng:NextNumber() - 0.5, rng:NextNumber() - 0.5) * cell * 0.8
			if rng:NextNumber() > LobbyConfig.scatterFill then
				continue
			end
			local pick = rng:NextNumber() * totalWeight
			local kind = kinds[#kinds]
			for _, name in kinds do
				pick -= weights[name]
				if pick <= 0 then
					kind = name
					break
				end
			end
			local grow = rng:NextNumber(0.8, 1.2)
			local reach = (REACH :: { [string]: number })[kind] * grow
			if blocked(at, reach) then
				continue
			end
			table.insert(scattered, { at = at, reach = reach })
			if kind == "Tree" then
				tree(at, grow * 0.9, rng, root, true)
			elseif kind == "Bush" then
				bush(at, grow, rng, root)
			elseif kind == "Boulder" then
				boulder(at, grow, rng, root)
			elseif kind == "Flowers" then
				flowers(at, rng, root)
			else
				mushroom(at, grow, root)
			end
		end
	end

	-- the clearing's edge
	local thick = 8
	wall(
		"WallNorth",
		Vector3.new(LobbyConfig.size.X + 2 * thick, 24, thick),
		CFrame.new(world(Vector2.new(0, -half.Y - thick / 2), 12)),
		root
	)
	wall(
		"WallSouth",
		Vector3.new(LobbyConfig.size.X + 2 * thick, 24, thick),
		CFrame.new(world(Vector2.new(0, half.Y + thick / 2), 12)),
		root
	)
	wall(
		"WallWest",
		Vector3.new(thick, 24, LobbyConfig.size.Y),
		CFrame.new(world(Vector2.new(-half.X - thick / 2, 0), 12)),
		root
	)
	wall(
		"WallEast",
		Vector3.new(thick, 24, LobbyConfig.size.Y),
		CFrame.new(world(Vector2.new(half.X + thick / 2, 0), 12)),
		root
	)

	root.Parent = parent
	folder = root
end

function Lobby.place(character: Model)
	local at = world(LobbyConfig.spawn, 3)
	character:PivotTo(CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
end

--[[ The index of the nearest active portal whose mouth `position` stands
     within `LobbyConfig.portalReach` (plus `slack`) of, or nil. ]]
function Lobby.portalAt(position: Vector3, slack: number?): number?
	local best, bestDistance = nil, LobbyConfig.portalReach + (slack or 0)
	for index, portal in LobbyConfig.portals do
		if portal.levels then
			local mouth = world(Lobby.archAt(index) + Vector2.new(0, LobbyConfig.mouthAhead))
			local distance = Vector3.new(position.X - mouth.X, 0, position.Z - mouth.Z).Magnitude
			if distance <= bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

--[[
	START on a portal's screen: the stage level `level` of portal `index`
	plays, or nil when the request is not one this player may make. Both
	numbers come from the client, so each is checked: a whole number, an
	active portal, the portal itself open to this player (`requires`:
	Endless waits on 1-10), one of its levels, that level open to this
	player (the levels they have beaten, `beaten`, from their saved profile:
	`Util/LevelUnlocks`), and the player standing at that portal (within
	`startSlack` more than its screen opens at, for the press's trip), so
	nobody starts an area from across the lobby.
]]
function Lobby.startFor(
	position: Vector3,
	index: unknown,
	level: unknown,
	beaten: LevelUnlocks.Beaten?
): number?
	if type(index) ~= "number" or type(level) ~= "number" then
		return nil
	end
	if index ~= math.floor(index) or level ~= math.floor(level) then
		return nil
	end
	local portal = LobbyConfig.portals[index]
	local levels = portal and portal.levels
	local stage = levels and levels[level]
	if not stage or not levels then
		return nil
	end
	--[[ The portal's own gate first (Endless waits on 1-10), then the
	     level's. Both are checked here because both come from the client. ]]
	if not LevelUnlocks.portalOpen(portal.requires, beaten) then
		return nil
	end
	if not LevelUnlocks.isUnlocked(levels, Balance.Stages, beaten, level) then
		return nil
	end
	if Lobby.portalAt(position, LobbyConfig.startSlack) ~= index then
		return nil
	end
	return stage
end

function Lobby.contains(position: Vector3): boolean
	local relative = position - ORIGIN
	return math.abs(relative.X) < LobbyConfig.size.X and math.abs(relative.Z) < LobbyConfig.size.Y
end

function Lobby.leaderboardFace(): Part?
	return leaderboardFace
end

--[[ The DEEPEST DELVERS board's face (`Run/EndlessLeaderboard`). ]]
function Lobby.endlessLeaderboardFace(): Part?
	return endlessLeaderboardFace
end

function Lobby.folder(): Folder?
	return folder
end

return Lobby
