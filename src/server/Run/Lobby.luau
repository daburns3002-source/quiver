--!strict
--[[
	The lobby (`Config/Lobby`): built once at boot beside the arena, where
	players arrive after BEGIN ADVENTURE,
	and where stepping into an active portal starts that area's run.

	- `build` lays out Lobby B from plain smooth parts (owner, 2026-10-27:
	  "i dont want it to have the pixely texture"; the layout sheet,
	  `assets/concepts/blocky/lobby/palace/lobby_layout_reference.png`): the
	  courtyard's floor, carpets, fountain and ruins (`Run/LobbyCourtyard`),
	  the four station buildings (`Config/PalaceBuildings`), the portal terrace
	  and its arches, the two leaderboards, and past the balustrade a ring of
	  cliffs and trees with waterfalls and a scatter of trees, bushes,
	  boulders, flowers and mushrooms.
	  Round things are ellipsoids (a block with a sphere `SpecialMesh`).
	- `place` puts a character at the spawn.
	- `portalAt` says which active portal a player is standing in, if any,
	  for its screen to open (`UI/PortalScreen`); `startFor` checks a START
	  from that screen and names the stage it may start.

	Seeded, so the lobby is the same every time.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local LaunchLocks = require(ReplicatedStorage.Shared.Util.LaunchLocks)
local LevelUnlocks = require(ReplicatedStorage.Shared.Util.LevelUnlocks)
local LobbyBackdrop = require(script.Parent.LobbyBackdrop)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local LobbyCourtyard = require(script.Parent.LobbyCourtyard)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)
local PalaceBuildings = require(ReplicatedStorage.Shared.Config.PalaceBuildings)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)

local Lobby = {}

local ORIGIN = LobbyConfig.origin
local COLOURS = LobbyConfig.colours
local folder: Folder? = nil
local leaderboardFace: Part? = nil
local endlessLeaderboardFace: Part? = nil

--[[ The courtyard's floor, which the buildings and the terrace stand on, and
     the ground past the balustrade, below it. ]]
local LAWN = LobbyCourtyard.FLOOR
local OUTSIDE = LobbyCourtyard.OUTSIDE
--[[ The wood beyond the cliff ring, so the edge of the world never shows
     (owner, 2026-10-27: "the player should not see this in the lobby"):
     its rings, studs out from the clearing's edge, each tree's size range,
     and how far the floor reaches. ]]
local OUTER_RINGS = {
	{ out = 34, spacing = 16, grow = { 1.3, 1.7 } },
	{ out = 58, spacing = 20, grow = { 1.6, 2.2 } },
	{ out = 86, spacing = 24, grow = { 2.0, 2.8 } },
}
local OUTER_FLOOR = 2000
--[[ How far each scatter kind keeps from everything else, studs. ]]
--[[ How much room each scattered thing keeps to itself, in studs at
     `grow` 1. A tree asked for 6, which with everything else competing
     for the same cells left only thirteen standing on the lawn -- the
     weight in `Config/Lobby.scatter` cannot help if the space test
     rejects the cell anyway (owner, 2026-11-01: "add more around the
     lobby"). At 4.2 they stand in loose groups instead of singly, which
     is what a clearing in a wood looks like. ]]
local REACH = { Tree = 4.2, Bush = 3, Boulder = 3.5, Flowers = 2, Mushroom = 1.5 }
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

local function world(at: Vector2, y: number?): Vector3
	return ORIGIN + Vector3.new(at.X, y or 0, at.Y)
end

--[[ Which row arch `index` stands in: 1 the front, 2 the back. ]]
function Lobby.rowOf(index: number): number
	return math.ceil(index / LobbyConfig.perRow)
end

--[[ How many arches stand in row `row`. ]]
local function rowCount(row: number): number
	return math.clamp(#LobbyConfig.portals - (row - 1) * LobbyConfig.perRow, 0, LobbyConfig.perRow)
end

--[[ The centre of row `row`'s ledge, and how high its top stands. ]]
local function rowCentre(row: number): (Vector2, number)
	return LobbyConfig.terrace - Vector2.new(0, (row - 1) * LobbyConfig.rowDepth),
		LobbyConfig.ledge + (row - 1) * LobbyConfig.rowRise
end

--[[ Where arch `index` stands: front row west to east, then the back, each
     row centred on the carpet however many arches it has. ]]
function Lobby.archAt(index: number): Vector2
	local perRow = LobbyConfig.perRow
	local column = (index - 1) % perRow + 1
	local row = Lobby.rowOf(index)
	local offset = (column - (rowCount(row) + 1) / 2) * LobbyConfig.archSpacing
	return rowCentre(row) + Vector2.new(offset, 0)
end

local part = LobbyCourtyard.part
local blob = LobbyCourtyard.blob
local wall = LobbyCourtyard.wall

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
--[[ The same table under a name that is not about the dex, for the tree
     and the arches. ]]
local lobbyTemplates: { [string]: MeshPart } = {}

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
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.TextWrapped = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = colour
	label.TextStrokeColor3 = Color3.fromRGB(60, 36, 20)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = gui
end

--[[ A plaque in a gold frame, reading out of `where`'s own front (+Z). ]]
local function signboard(
	text: string,
	where: CFrame,
	width: number,
	height: number,
	colour: Color3,
	parent: Instance
)
	--[[ A part's face is its -Z, and a building's front is its +Z, so the
	     board turns half round to read out of the wall it hangs on. ]]
	local facing = where * CFrame.Angles(0, math.pi, 0)
	part(
		"SignFrame",
		Vector3.new(width + 0.8, height + 0.8, 0.5),
		facing * CFrame.new(0, 0, 0.3),
		COLOURS.gold,
		parent
	)
	local board = part("Sign", Vector3.new(width, height, 0.5), facing, colour, parent)
	words(board, text, COLOURS.text)
end

--[[
	A tree, built in code in the blocky voxel look of the enemy spotlight
	loading screens: a square trunk on a flared foot, and a crown of stacked
	slabs and offset cubes, darkest underneath and sunlit on top, each piece
	turned a little so the outline is lumpy rather than one box (owner,
	2026-11-05: the round-blob tree "look[s] terrible", "redo them").

	`grow` times the size a tree of 1 stands, `tall` matched to the trees
	before it so every scatter and ring keeps its spacing. Each is turned a
	random amount and stretched in height on its own, so no two are the same.
	`y` stands it on a cliff top instead of the forest floor.
]]
local function tree(
	at: Vector2,
	grow: number,
	rng: Random,
	parent: Instance,
	solid: boolean,
	y: number?
)
	local spec = LobbyConfig.tree
	local model = Instance.new("Model")
	model.Name = "Tree"
	local tall = spec.tall * grow * rng:NextNumber(spec.stretch.Min, spec.stretch.Max)
	local c = spec.tall * grow * spec.crown
	local bare = tall * spec.trunk
	local foot = CFrame.new(world(at, y or OUTSIDE))
		* CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	local function twist(): CFrame
		return CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
	end
	local thick = math.max(1.2, c * 0.2)
	local trunkTall = bare + c * 0.3
	part(
		"Trunk",
		Vector3.new(thick, trunkTall, thick),
		foot * CFrame.new(0, trunkTall / 2, 0),
		spec.bark,
		model
	)
	part(
		"Roots",
		Vector3.new(thick * 1.7, thick * 0.5, thick * 1.7),
		foot * CFrame.new(0, thick * 0.25, 0) * CFrame.Angles(0, math.pi / 4, 0),
		spec.barkDark,
		model
	)
	local leaves = spec.leaves
	local base = foot * CFrame.new(0, bare, 0)
	-- the shaded underside, the body, and lumps hanging off its sides
	part(
		"Leaves",
		Vector3.new(c, c * 0.3, c * 0.92),
		base * CFrame.new(0, c * 0.15, 0) * twist(),
		leaves[1],
		model
	)
	part(
		"Leaves",
		Vector3.new(c * 0.86, c * 0.34, c),
		base * CFrame.new(0, c * 0.4, 0) * twist(),
		leaves[2],
		model
	)
	local spin = rng:NextNumber() * math.pi * 2
	for k = 0, 2 do
		local angle = spin + k * math.pi * 2 / 3 + rng:NextNumber(-0.4, 0.4)
		local s = c * rng:NextNumber(0.34, 0.46)
		part(
			"Leaves",
			Vector3.new(s, s * 0.8, s),
			base
				* CFrame.new(
					math.cos(angle) * c * 0.44,
					c * rng:NextNumber(0.18, 0.5),
					math.sin(angle) * c * 0.44
				)
				* twist(),
			if k == 0 then leaves[1] else leaves[2],
			model
		)
	end
	-- the sunlit top and a small cap off centre
	part(
		"Leaves",
		Vector3.new(c * 0.62, c * 0.26, c * 0.62),
		base * CFrame.new(c * 0.05, c * 0.68, -c * 0.04) * twist(),
		leaves[3],
		model
	)
	part(
		"Leaves",
		Vector3.new(c * 0.3, c * 0.18, c * 0.3),
		base * CFrame.new(-c * 0.12, c * 0.86, c * 0.08) * twist(),
		leaves[3],
		model
	)
	for _, p in model:GetChildren() do
		local piece = p :: BasePart
		piece.CanCollide = solid and piece.Name ~= "Leaves"
		piece.CanQuery = solid
		piece.CastShadow = solid
	end
	model.Parent = parent
end

--[[ A round grey boulder of two or three stones. ]]
local function boulder(at: Vector2, grow: number, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Boulder"
	local foot = world(at, OUTSIDE)
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
	local foot = world(at, OUTSIDE)
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
	local foot = world(at, OUTSIDE)
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
	local foot = world(at, OUTSIDE)
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

--[[ A station's name floating over it, which is how a player picks it
     out from across the lawn. Its own function because the Dex Hall is
     built and returned before the rest of `building` runs, and it needs
     one too (owner, 2026-11-01: "the text to be above like the rest of
     the buildings"). ]]
local function floatingTitle(spec: LobbyConfig.Building, at: CFrame, model: Model)
	local anchor = wall("Title", Vector3.one, at, model)
	anchor.CanCollide = false
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(28, 14)
	board.LightInfluence = 0
	board.MaxDistance = 320
	board.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	-- two chunky lines, as the sheet letters them
	label.Text = string.gsub(spec.title or "", " ", "\n")
	label.TextColor3 = spec.titleColour or COLOURS.text
	label.Parent = board
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 24, 12)
	stroke.Thickness = 3
	stroke.Parent = label
end

--[[ The bob of the Hatch Eggs' floating egg. ]]
local BOB = TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local BOB_HEIGHT = 1.2

--[[
	A station's building: the owner's imported model (`Config/PalaceBuildings`),
	its name floating over it, and a wall that keeps players out of it and off
	its steps. Each building faces the middle of the clearing, and everything
	is placed in its frame, front +Z. Returns its footprint.

	A mesh that did not load is left out rather than stopping the lobby.
]]
local function building(name: string, at: Vector2, parent: Instance): Vector3?
	local spec = LobbyConfig.buildings[name]
	local design = PalaceBuildings[name]
	if not spec or not design then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	local base = CFrame.new(world(at, LAWN)) * CFrame.Angles(0, LobbyConfig.facing(at), 0)
	local bobbing: MeshPart? = nil

	for _, piece in design.pieces do
		local template = lobbyTemplates[piece.mesh]
		if not template then
			continue
		end
		local mesh = template:Clone()
		local spot = base * CFrame.new(piece.offset)
		mesh.Name = piece.name
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		mesh.CastShadow = not piece.glow
		mesh.Material = if piece.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		mesh.Color = Color3.new(1, 1, 1)
		mesh.Size = piece.size
		mesh.CFrame = spot
		mesh.Parent = model
		if piece.bob then
			bobbing = mesh
		end
	end

	local top = design.top
	if name == "DexHall" then
		--[[ The two books the owner modelled stay as they are: the open
		     book on the hall's flat deck and a stand on each pad. They
		     were modelled facing -Z, so they take `turn`. ]]
		local dex = LobbyConfig.dex
		local pads = dex.pads
		for _, sx in { -1, 1 } do
			dexPiece(
				"StandBook",
				dex.standBook,
				base
					* CFrame.new(sx * pads.out, pads.top, pads.forward)
					* CFrame.Angles(0, dex.turn, 0),
				model
			)
		end
		local book = dexPiece(
			"RoofBook",
			dex.roofBook,
			base
				* CFrame.new(0, dex.hall.ridge - dex.roofBook.seat, dex.roofBook.forward)
				* CFrame.Angles(0, dex.turn, 0),
			model
		)
		if book then
			top += book.Size.Y - dex.roofBook.seat
		end
	end

	--[[ From the back wall to the foot of the steps, turned with the building.
	     Nobody walks in: a station's screen opens from out front. ]]
	local back = spec.size.Z / 2
	wall(
		"StationWall",
		Vector3.new(spec.size.X, 20, back + design.front),
		base * CFrame.new(0, 10, (design.front - back) / 2),
		model
	)

	-- everything grows from the building's own foot
	local scale = LobbyConfig.buildingScale
	model.WorldPivot = base
	model:ScaleTo(scale)
	if bobbing then
		-- drawn at the screen's frame rate on each client (`Fx/SmoothMotion`)
		CollectionService:AddTag(bobbing, "SmoothMotion")
		TweenService
			:Create(bobbing, BOB, { CFrame = bobbing.CFrame * CFrame.new(0, BOB_HEIGHT, 0) })
			:Play()
	end
	--[[ Its name above its outer shoulder, where the sheet letters it, so a
	     building in front never hides behind the words of one behind. ]]
	local titleAt = at + Vector2.new(math.sign(at.X) * spec.size.X * 0.4, 0)
	floatingTitle(spec, CFrame.new(world(titleAt, LAWN + top * scale + 4)), model)

	model.Parent = parent
	return Vector3.new(spec.size.X, top, spec.size.Z) * scale
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
			label.Font = Enum.Font.FredokaOne
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

--[[ A gold padlock hanging at `centre`, across a locked opening. ]]
local function padlock(centre: CFrame, model: Instance)
	local lock = centre * CFrame.new(0, -1, 0.3)
	part("Lock", Vector3.new(3.2, 2.8, 1), lock, COLOURS.gold, model)
	part(
		"Keyhole",
		Vector3.new(0.6, 1, 0.2),
		lock * CFrame.new(0, 0, 0.55),
		COLOURS.woodDark,
		model
	)
	for _, side in { -1, 1 } do
		part(
			"Shackle",
			Vector3.new(0.5, 2, 0.5),
			lock * CFrame.new(side, 2, 0),
			COLOURS.gold,
			model
		)
	end
	part("Shackle", Vector3.new(2.5, 0.5, 0.5), lock * CFrame.new(0, 3, 0), COLOURS.gold, model)
end

--[[ An area's portal from its import (`LobbyConfig.portalModels`), standing out
     from the wall on `base`, its spinning vortex a picture in the doorway that
     `Fx/PortalVortex` steps through on each client. ]]
local function meshPortal(
	spec: LobbyConfig.PortalModel,
	template: MeshPart,
	base: CFrame,
	active: boolean,
	model: Instance
)
	local vortex = LobbyConfig.portalVortex
	local middle = base * CFrame.new(0, 0, 1 + spec.size.Z / 2)
	local frame = template:Clone()
	frame.Name = "Frame"
	frame.Anchored = true
	frame.CanCollide = false
	frame.CanQuery = false
	frame.CanTouch = false
	frame.Material = Enum.Material.SmoothPlastic
	frame.Size = spec.size
	frame.TextureID = spec.texture
	frame.Color = Color3.new(1, 1, 1)
	-- an import's front is its -Z, and the portals face south
	frame.CFrame = middle * CFrame.new(0, spec.size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0)
	frame.Parent = model

	local plane = part(
		"Vortex",
		Vector3.new(vortex.size.X, vortex.size.Y, 0.2),
		middle * CFrame.new(0, vortex.foot + vortex.size.Y / 2, vortex.forward),
		spec.glow,
		model
	)
	plane.Transparency = 1
	plane.CanCollide = false
	plane.CanQuery = false
	plane.CanTouch = false
	plane.CastShadow = false

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = vortex.cell
	gui.LightInfluence = 0
	gui.Parent = plane

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = spec.vortex
	image.ImageRectSize = vortex.cell
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.Parent = gui
	CollectionService:AddTag(image, vortex.tag)

	local pulse = Instance.new("ImageLabel")
	pulse.Name = "Pulse"
	pulse.BackgroundTransparency = 1
	pulse.AnchorPoint = Vector2.new(0.5, 0.5)
	pulse.Position = UDim2.fromScale(0.5, 1 - (vortex.heart - vortex.foot) / vortex.size.Y)
	pulse.Size = UDim2.fromScale(0.45, 0.39)
	pulse.Image = vortex.pulse
	pulse.ImageTransparency = 0.5
	pulse.ZIndex = 2
	pulse.Parent = image

	local light = Instance.new("PointLight")
	light.Color = spec.glow
	light.Range = 18
	light.Brightness = 2
	light.Parent = plane

	if not active then
		padlock(middle * CFrame.new(0, vortex.foot + vortex.size.Y / 2, 1.2), model)
	end
end

--[[ A portal, set in its row's wall (`terrace` builds the wall): a stone arch
     with a gold keystone round an opening that holds a swirl in its colour, or
     the dark and a gold padlock while its area is locked, and its name on a
     plaque above. Built facing south, its foot on the ledge. ]]
local function portalArch(index: number, portal: LobbyConfig.Portal, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. index
	local _, ledge = rowCentre(Lobby.rowOf(index))
	local base = CFrame.new(world(Lobby.archAt(index), LAWN + ledge))
	local across = LobbyConfig.archWidth
	local sides = LobbyConfig.archSides
	local active = portal.levels ~= nil
	local spec = if portal.name then LobbyConfig.portalModels[portal.name] else nil
	local template = if spec then lobbyTemplates[spec.mesh] else nil
	if spec and template then
		meshPortal(spec, template, base, active, model)
		signboard(
			string.upper(portal.name :: string),
			base * CFrame.new(0, spec.size.Y + 1.8, 1.6),
			LobbyConfig.archSpacing - 5.5,
			3.4,
			LobbyConfig.plaques[portal.name :: string] or COLOURS.woodDark,
			model
		)
		model.Parent = parent
		return
	end
	local fill = if active
		then (portal.tint or COLOURS.gold):Lerp(Color3.new(0, 0, 0), 0.35)
		else LobbyConfig.archDark

	-- the opening: straight sides and a round top, laid on the wall
	local mouth = part(
		"Mouth",
		Vector3.new(across, sides, 0.3),
		base * CFrame.new(0, sides / 2, 1),
		fill,
		model
	)
	local top = part(
		"Swirl",
		Vector3.new(0.3, across, across),
		base * CFrame.new(0, sides, 1) * CFrame.Angles(0, math.pi / 2, 0),
		fill,
		model,
		Enum.PartType.Cylinder
	)
	mouth.CastShadow = false
	top.CastShadow = false

	-- the stones round it
	local ring = across / 2 + 0.8
	for _, side in { -1, 1 } do
		part(
			"Jamb",
			Vector3.new(1.6, sides, 1.2),
			base * CFrame.new(side * ring, sides / 2, 1.1),
			COLOURS.stoneShade,
			model
		)
	end
	local STONES = 9
	for k = 0, STONES do
		local turn = k / STONES * math.pi
		local keystone = k == math.floor(STONES / 2) or k == math.ceil(STONES / 2)
		part(
			if keystone then "Keystone" else "Stone",
			Vector3.new(1.6, 2.2, 1.2),
			base
				* CFrame.new(math.cos(turn) * ring, sides + math.sin(turn) * ring, 1.1)
				* CFrame.Angles(0, 0, turn - math.pi / 2),
			if keystone then COLOURS.gold else COLOURS.stoneShade,
			model
		)
	end

	local centre = base * CFrame.new(0, sides - 0.5, 1.3)
	if active then
		local tint = portal.tint or COLOURS.gold
		-- the swirl's arms, paler toward its heart
		for arm = 0, 2 do
			for step = 1, 8 do
				local turn = step * 0.62 + arm * math.pi * 2 / 3
				local out = step * 0.62
				local piece = part(
					"SwirlArm",
					Vector3.new(1.1, 1.1, 0.2),
					centre
						* CFrame.new(math.cos(turn) * out, math.sin(turn) * out, 0)
						* CFrame.Angles(0, 0, turn),
					tint:Lerp(Color3.new(1, 1, 1), 0.5 - step * 0.055),
					model
				)
				piece.Material = Enum.Material.Neon
				piece.CastShadow = false
			end
		end
		local light = Instance.new("PointLight")
		light.Color = tint
		light.Range = 18
		light.Brightness = 2
		light.Parent = top
	else
		padlock(centre, model)
	end
	if portal.name then
		signboard(
			string.upper(portal.name),
			base * CFrame.new(0, sides + across / 2 + 3.5, 1.6),
			LobbyConfig.archSpacing - 5.5,
			3.4,
			LobbyConfig.plaques[portal.name] or COLOURS.woodDark,
			model
		)
	end
	model.Parent = parent
end

--[[ Broad marble steps up a ledge's front edge: from `low` to `high`, starting
     at `edge` (z) and coming south, `width` across at `x`. `carpet` is how wide
     a red carpet runs up their middle, if one does. Returns the foot's z. ]]
local function steps(
	x: number,
	edge: number,
	low: number,
	high: number,
	width: number,
	parent: Instance,
	carpet: number?
): number
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
			if k % 2 == 0 then COLOURS.stone else COLOURS.stoneShade,
			parent
		)
		step.CanCollide = true
		step.CanQuery = true
		if carpet then
			local edge2 = LobbyConfig.courtyard.carpetEdge * 2
			local at = world(Vector2.new(x, z), LAWN + topY)
			part(
				"StepEdge",
				Vector3.new(carpet + edge2, 0.1, depth),
				CFrame.new(at + Vector3.new(0, 0.05, 0)),
				COLOURS.gold,
				parent
			).CastShadow =
				false
			part(
				"StepCarpet",
				Vector3.new(carpet, 0.1, depth),
				CFrame.new(at + Vector3.new(0, 0.1, 0)),
				COLOURS.carpet,
				parent
			).CastShadow =
				false
		end
	end
	return edge + count * 1.4
end

--[[ A stone pier between two arches: a gold band at its foot and head, and a
     red banner hung down its front. ]]
local function pier(at: Vector2, foot: number, tall: number, parent: Instance)
	local base = CFrame.new(world(at, foot))
	part(
		"Pier",
		Vector3.new(3.4, tall, 3),
		base * CFrame.new(0, tall / 2, 0.6),
		COLOURS.stone,
		parent
	)
	for _, y in { 1, tall - 0.8 } do
		part(
			"PierGold",
			Vector3.new(3.8, 0.6, 3.4),
			base * CFrame.new(0, y, 0.6),
			COLOURS.gold,
			parent
		)
	end
	part(
		"Banner",
		Vector3.new(2, tall * 0.42, 0.2),
		base * CFrame.new(0, tall * 0.7, 2.2),
		COLOURS.carpet,
		parent
	)
	part(
		"BannerHem",
		Vector3.new(2, 0.4, 0.3),
		base * CFrame.new(0, tall * 0.49, 2.2),
		COLOURS.gold,
		parent
	)
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
	--[[ Every mesh the lobby uses, fetched before anything is placed: the
	     Dex Hall's two books and the four buildings. One wait for the lot, which is what `MeshTemplates` is
	     for -- asked one at a time they cost about a second each. ]]
	do
		local ids = { LobbyConfig.dex.roofBook.mesh, LobbyConfig.dex.standBook.mesh }
		for _, design in PalaceBuildings do
			for _, piece in design.pieces do
				table.insert(ids, piece.mesh)
			end
		end
		for _, spec in LobbyConfig.portalModels do
			table.insert(ids, spec.mesh)
		end
		dexTemplates = MeshTemplates.load(ids)
		lobbyTemplates = dexTemplates
	end
	local rng = Random.new(20261027)
	local root = Instance.new("Folder")
	root.Name = "Lobby"
	local half = LobbyConfig.size / 2

	-- the ground past the balustrade, out to the wood's edge
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	part(
		"Lawn",
		Vector3.new(OUTER_FLOOR, 1, OUTER_FLOOR),
		CFrame.new(world(Vector2.zero, OUTSIDE - 0.5)),
		LobbyConfig.forestFloor,
		root
	).CanCollide =
		true

	-- the courtyard's floor, its rings and its ruins
	LobbyCourtyard.floor(rng, root)
	LobbyCourtyard.plaza(rng, root)
	LobbyCourtyard.arrival(rng, root)
	LobbyCourtyard.buildingCarpets(root)
	LobbyCourtyard.southStairs(root)
	LobbyCourtyard.balustrade(rng, root)
	LobbyCourtyard.ruins(rng, root)
	LobbyCourtyard.sky()

	-- the stations, and their stands out front
	for _, station in LobbyConfig.stations do
		building(station.piece, station.at, root)
		local spots = LobbyConfig.stands[station.piece]
		if spots then
			for _, spot in spots do
				--[[ Out front of its own station, whichever corner that
				     is on: the offset turns with the building. ]]
				local at = station.at
					+ LobbyConfig.turnedOffset(station.at, spot.at * LobbyConfig.buildingScale)
				standOut(spot.kind, spot.key, world(at, LAWN), root)
			end
		end
	end

	-- the portal ledges, back row first, each with its wall of arches
	local rows = Lobby.rowOf(#LobbyConfig.portals)
	local across = LobbyConfig.perRow * LobbyConfig.archSpacing + 24
	local drop = LobbyConfig.courtyard.drop
	local walkWidth = LobbyConfig.courtyard.walkWidth
	local carpetFoot = 0
	for row = rows, 1, -1 do
		local centre, height = rowCentre(row)
		local extra = if row == rows then 8 else 0
		local depth = LobbyConfig.rowDepth + extra
		local back = centre.Y - LobbyConfig.rowDepth / 2 - extra
		local middle = Vector2.new(centre.X, back + depth / 2)
		local ledge = part(
			"Ledge",
			Vector3.new(across, height + drop, depth),
			CFrame.new(world(middle, LAWN + (height - drop) / 2)),
			COLOURS.stoneShade,
			root
		)
		ledge.CanCollide = true
		ledge.CanQuery = true
		part(
			"LedgeTop",
			Vector3.new(across + 0.6, 0.2, depth + 0.6),
			CFrame.new(world(middle, LAWN + height + 0.02)),
			COLOURS.marble[1],
			root
		).CastShadow =
			false
		local front = centre.Y + LobbyConfig.rowDepth / 2 + 0.5
		local _, below = rowCentre(row - 1)
		local low = if row == 1 then 0 else below
		if row == 1 then
			carpetFoot = steps(0, front, low, height, 52, root, walkWidth)
		else
			for _, side in { -1, 1 } do
				steps(side * (across / 2 - 5), front, low, height, 9, root)
			end
		end

		-- the wall the arches are set in, solid, with a pier either side of each
		local count = rowCount(row)
		local tall = LobbyConfig.archWall
		local long = count * LobbyConfig.archSpacing + 3.4
		local arcade = part(
			"Arcade",
			Vector3.new(long, tall, 1.6),
			CFrame.new(world(centre, LAWN + height + tall / 2)),
			COLOURS.stone,
			root
		)
		arcade.CanCollide = true
		part(
			"Cornice",
			Vector3.new(long + 1, 0.8, 2.6),
			CFrame.new(world(centre, LAWN + height + tall + 0.4)),
			COLOURS.gold,
			root
		)
		for k = 0, count do
			local x = (k - count / 2) * LobbyConfig.archSpacing
			pier(centre + Vector2.new(x, 0), LAWN + height, tall, root)
			if k % 2 == 0 then
				local leaves = COLOURS.leaves
				blob(
					"ArcadeLeaves",
					Vector3.new(7, 2.6, 3.6),
					CFrame.new(world(centre + Vector2.new(x + 3, 0), LAWN + height + tall + 1.2)),
					leaves[k % #leaves + 1],
					root
				)
			end
		end
	end
	-- the carpet from the plaza's inner ring to the foot of the steps, and on
	-- across the ledge to the arches
	do
		local carpets = root:FindFirstChild("Carpets") :: Instance
		local top = LobbyConfig.middle.Y - LobbyConfig.courtyard.plazaInner / 2 + 0.4
		LobbyCourtyard.carpet(Vector2.new(0, top), Vector2.new(0, carpetFoot), walkWidth, carpets)
		local front, height = rowCentre(1)
		LobbyCourtyard.carpet(
			Vector2.new(0, front.Y + 1),
			Vector2.new(0, front.Y + LobbyConfig.rowDepth / 2 + 0.5),
			walkWidth,
			carpets,
			height
		)
		-- and south between the leaderboards to the stairs
		local arrival = LobbyConfig.courtyard.arrival
		LobbyCourtyard.carpet(
			arrival.at + Vector2.new(0, arrival.across / 2 - 0.5),
			Vector2.new(0, 88),
			walkWidth,
			carpets
		)
	end
	for index, portal in LobbyConfig.portals do
		portalArch(index, portal, root)
	end
	local back = rowCentre(rows)
	wall(
		"TerraceWall",
		Vector3.new(across, 30, 4),
		CFrame.new(world(back + Vector2.new(0, -10), 15)),
		root
	)
	for _, side in { -1, 1 } do
		local z = LobbyConfig.terrace.Y - LobbyConfig.rowDepth
		wall(
			"TerraceSide",
			Vector3.new(4, 30, 60),
			CFrame.new(world(Vector2.new(side * (across / 2 + 2), z), 15)),
			root
		)
	end

	--[[ A leaderboard: a stone board on two posts, the names on its dark face.
	     Built twice — FARTHEST ADVENTURERS and DEEPEST DELVERS
	     (`LobbyConfig.leaderboard`, `LobbyConfig.endlessLeaderboard`) — so
	     the two boards are the same board, drawn on by different modules.

	     Everything is placed off `base`, which carries the board's `turn`.
	     It used to be built straight onto world axes, which only read the
	     one way; both boards now stand south of the spawn and face north
	     (owner, 2026-11-01: "move the leaderboards to behind the player
	     south of the spawn"). In `base` the board always reads toward +Z. ]]
	local function buildBoard(name: string, board: typeof(LobbyConfig.leaderboard)): Part
		local face = board.face
		local base = CFrame.new(world(board.at, LAWN)) * CFrame.Angles(0, board.turn, 0)
		local model = Instance.new("Model")
		model.Name = name
		for _, side in { -1, 1 } do
			local post = part(
				"Post",
				Vector3.new(1.4, face.centre.Y + face.size.Y / 2 + 1.5, 1.4),
				base
					* CFrame.new(
						side * (face.size.X / 2 + 1.3),
						(face.centre.Y + face.size.Y / 2 + 1.5) / 2,
						0
					),
				COLOURS.stone,
				model
			)
			post.CanCollide = true
		end
		part(
			"Backing",
			Vector3.new(face.size.X + 2, face.size.Y + 2, 0.8),
			base * CFrame.new(0, face.centre.Y, face.centre.Z - 0.6),
			COLOURS.gold,
			model
		)
		part(
			"Crest",
			Vector3.new(face.size.X + 3, 1.4, 1.2),
			base * CFrame.new(0, face.centre.Y + face.size.Y / 2 + 1.4, face.centre.Z - 0.6),
			COLOURS.stone,
			model
		)
		-- stone behind, where the frame's gold would otherwise show as one slab
		part(
			"BackPanel",
			Vector3.new(face.size.X, face.size.Y, 0.2),
			base * CFrame.new(0, face.centre.Y, face.centre.Z - 1.05),
			COLOURS.stoneShade,
			model
		)
		-- the gold diamond and its red gem on the crest
		local crest = base
			* CFrame.new(0, face.centre.Y + face.size.Y / 2 + 3.2, face.centre.Z - 0.6)
		part(
			"CrestGold",
			Vector3.new(3, 3, 0.8),
			crest * CFrame.Angles(0, 0, math.pi / 4),
			COLOURS.gold,
			model
		)
		part(
			"CrestGem",
			Vector3.new(1.5, 1.5, 1.2),
			crest * CFrame.Angles(0, 0, math.pi / 4),
			COLOURS.carpet,
			model
		)
		model.Parent = root
		local surface = part(
			`{name}Face`,
			Vector3.new(face.size.X, face.size.Y, 0.2),
			base * CFrame.new(face.centre) * CFrame.Angles(0, math.pi, 0),
			Color3.fromRGB(28, 24, 22),
			root
		)
		surface.CastShadow = false
		return surface
	end

	leaderboardFace = buildBoard("Leaderboard", LobbyConfig.leaderboard)
	endlessLeaderboardFace = buildBoard("EndlessLeaderboard", LobbyConfig.endlessLeaderboard)

	-- waterfalls down the corner cliffs into round pools
	for _, at in LobbyConfig.waterfalls do
		local fall = Instance.new("Model")
		fall.Name = "Waterfall"
		local facing = CFrame.lookAt(world(at, OUTSIDE), world(Vector2.zero, OUTSIDE))
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

	-- the trees round the clearing, below the balustrade
	local spacing = LobbyConfig.ringSpacing
	local function ring(at: Vector2, out: Vector2)
		if near(at, LobbyConfig.waterfalls, spacing + 6) or (at.Y > 0 and math.abs(at.X) < 24) then
			return
		end
		tree(at + out * rng:NextNumber(8, 22), rng:NextNumber(1.1, 1.5), rng, root, false)
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

	--[[ The scatter past the balustrade: one jittered point in each cell of a grid, its
	     kind drawn by weight, clear of the courtyard, the south stairs and
	     each other. ]]
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
		if LobbyCourtyard.inside(at, -(reach + 2)) or (at.Y > 80 and math.abs(at.X) < 20) then
			return true
		end
		if math.abs(at.X) + reach > half.X - 2 or math.abs(at.Y) + reach > half.Y - 2 then
			return true
		end
		if at.Y < LobbyConfig.terrace.Y + 12 and math.abs(at.X) < across / 2 + reach then
			return true
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
				tree(at, grow * 0.9, rng, root, false)
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

	-- the cliffs, falls and ruins far past the wood
	LobbyBackdrop.build(rng, root, function(at, grow, treeRng, treeParent, y)
		tree(at, grow, treeRng, treeParent, false, y)
	end)

	root.Parent = parent
	folder = root
end

function Lobby.place(character: Model)
	local at = world(LobbyConfig.spawn, 3)
	character:PivotTo(CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
end

--[[ Whether `stage` is the first level of a portal's area. Endless has no
     area to load into. ]]
function Lobby.isFirstLevel(stage: number): boolean
	for _, portal in LobbyConfig.portals do
		local levels = portal.levels
		if levels and levels[1] == stage and portal.name ~= "Endless" then
			return true
		end
	end
	return false
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

--[[ Where a player stands to be in portal `index`'s mouth, facing the
     arch: where PLAY puts them (`Remotes.LobbyPlay`). ]]
function Lobby.mouthAt(index: number): CFrame
	local arch = world(Lobby.archAt(index), 3)
	local at = world(Lobby.archAt(index) + Vector2.new(0, LobbyConfig.mouthAhead), 3)
	return CFrame.lookAt(at, Vector3.new(arch.X, at.Y, arch.Z))
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
	beaten: LevelUnlocks.Beaten?,
	bosses: { [string]: boolean }?
): number?
	local stage = Lobby.levelOpen(index, level, beaten, bosses)
	if not stage or Lobby.portalAt(position, LobbyConfig.startSlack) ~= index then
		return nil
	end
	return stage
end

--[[ `startFor` without the standing-at-the-portal check: the stage level
     `level` of portal `index` plays for a player who has beaten `beaten`,
     or nil. A party's run server checks its leader's request again with
     this (`Run/Party`), since what a teleport carries passes through the
     client. ]]
function Lobby.levelOpen(
	index: unknown,
	level: unknown,
	beaten: LevelUnlocks.Beaten?,
	bosses: { [string]: boolean }?
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
	--[[ The portal's own gate first (at launch each area waits on the
	     one before it, `Util/LaunchLocks`), then the level's. Both are
	     checked here because both come from the client. `bosses` is the
	     player's beaten bosses, for a gate that waits on one. ]]
	if not LaunchLocks.portalOpen(portal, beaten, bosses) then
		return nil
	end
	if not LevelUnlocks.isUnlocked(levels, Balance.Stages, beaten, level) then
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
