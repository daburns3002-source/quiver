--!strict
--[[
	The lobby (`Config/Lobby`): built once at boot beside the arena, where
	players arrive after BEGIN ADVENTURE,
	and where stepping into an active portal starts that area's run.

	- `build` lays the clearing out from plain smooth parts (owner,
	  2026-10-27: "i dont want it to have the pixely texture. just make it
	  look like a normal lobby"): a lawn, sandy paths, the fountain, the
	  four station buildings (`Config/PalaceBuildings`), the egg and crate stands, the portal ledges and
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
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local LevelUnlocks = require(ReplicatedStorage.Shared.Util.LevelUnlocks)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)
local PalaceBuildings = require(ReplicatedStorage.Shared.Config.PalaceBuildings)
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

--[[
	A tree: the owner's imported model, `grow` times the size a tree of 1
	stands (owner, 2026-11-01: "use the tree import and replace the
	existing trees in the game with it").

	It was a trunk pillar under three leaf blobs. `tall` is set to what
	that came to, so every scatter and ring that places trees keeps its
	spacing without being retuned.

	Each is turned a random amount about Y and stretched in height on its
	own, so no two are the same shape; without that a hundred copies of one
	mesh read as wallpaper.
	Falls back to nothing if the mesh did not load, as the dex books do.
]]
local function tree(at: Vector2, grow: number, rng: Random, parent: Instance, solid: boolean)
	local spec = LobbyConfig.treeModel
	local template = lobbyTemplates[spec.mesh]
	if not template then
		return
	end
	local p = template:Clone()
	p.Name = "Tree"
	p.Anchored = true
	p.CanCollide = solid
	p.CanQuery = solid
	p.CanTouch = false
	p.CastShadow = solid
	p.Material = Enum.Material.SmoothPlastic
	--[[ `grow` sets how wide it is and `stretch` how tall, so no two
	     trees are the same shape. Scaling evenly only ever looked like
	     the same tree at a different distance. The spacing between
	     scattered things reads `grow`, so stretching the height alone
	     never crowds anything. ]]
	local scale = spec.tall * grow / spec.native.Y
	local stretch = rng:NextNumber(spec.stretch.Min, spec.stretch.Max)
	p.Size =
		Vector3.new(spec.native.X * scale, spec.native.Y * scale * stretch, spec.native.Z * scale)
	p.TextureID = spec.texture
	--[[ The tree carries its colours in its own texture, so the part must
	     not tint them. ]]
	p.Color = Color3.new(1, 1, 1)
	p.CFrame = CFrame.new(world(at, LAWN) + Vector3.new(0, p.Size.Y / 2, 0))
		* CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	p.Parent = parent
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
			TweenService:Create(mesh, BOB, { CFrame = spot * CFrame.new(0, BOB_HEIGHT, 0) }):Play()
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

	floatingTitle(spec, base * CFrame.new(0, top + 6, 0), model)

	--[[ From the back wall to the foot of the steps, turned with the building.
	     Nobody walks in: a station's screen opens from out front. ]]
	local back = spec.size.Z / 2
	wall(
		"StationWall",
		Vector3.new(spec.size.X, 20, back + design.front),
		base * CFrame.new(0, 10, (design.front - back) / 2),
		model
	)
	model.Parent = parent
	return Vector3.new(spec.size.X, top, spec.size.Z)
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
	--[[
		The arch itself. An area the owner has imported stands as its own
		model; one past `archSilhouetteFrom` has no model and none coming,
		so it stands as the first area's painted black (owner, 2026-11-01:
		"replace every portal past 4 with a silhouette of the arena 1
		portal until portals are made for them"). The rest -- Thornwood and
		the Drowned Village, whose models arrive tomorrow -- keep the built
		stone ring until they have one.
	]]
	local spec = LobbyConfig.archModels[index]
	local silhouette = spec == nil and index >= LobbyConfig.archSilhouetteFrom
	if silhouette then
		spec = LobbyConfig.archModels[1]
	end
	local template = if spec then lobbyTemplates[spec.mesh] else nil

	if spec and template then
		local arch = template:Clone()
		arch.Name = "Arch"
		arch.Anchored = true
		arch.CanCollide = false
		arch.CanQuery = false
		arch.CanTouch = false
		arch.Material = Enum.Material.SmoothPlastic
		arch.Size = spec.native * (LobbyConfig.archTall / spec.native.Y)
		if silhouette then
			--[[ No texture and no light in it: the shape is all a
			     silhouette says, which is the point of one. ]]
			arch.TextureID = ""
			arch.Color = LobbyConfig.archSilhouette
		else
			arch.TextureID = spec.texture
			--[[ It carries its colours in its own texture, so the part
			     must not tint them. ]]
			arch.Color = Color3.new(1, 1, 1)
		end
		arch.CFrame = CFrame.new(world(at, LAWN + ledge) + Vector3.new(0, arch.Size.Y / 2, 0))
			* CFrame.Angles(0, LobbyConfig.archTurn, 0)
		arch.Parent = model
		--[[ The legs stay, invisible, so a player is held out of the
		     uprights exactly as before whatever shape the model is. ]]
		for _, side in { -1, 1 } do
			local leg = part(
				"Leg",
				Vector3.new(2.6, LobbyConfig.archRise, 2.6),
				CFrame.new(
					world(
						at + Vector2.new(side * radius, 0),
						LAWN + ledge + LobbyConfig.archRise / 2
					)
				),
				stone,
				model
			)
			leg.CanCollide = true
			leg.Transparency = 1
			leg.CastShadow = false
		end
	else
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
					world(
						at + Vector2.new(side * radius, 0),
						LAWN + ledge + LobbyConfig.archRise / 2
					)
				),
				stone,
				model
			)
			leg.CanCollide = true
		end
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
	--[[ Every mesh the lobby uses, fetched before anything is placed: the
	     Dex Hall's two books, the tree, and each arch the owner has
	     imported. One wait for the lot, which is what `MeshTemplates` is
	     for -- asked one at a time they cost about a second each. ]]
	do
		local ids = { LobbyConfig.dex.roofBook.mesh, LobbyConfig.dex.standBook.mesh }
		table.insert(ids, LobbyConfig.treeModel.mesh)
		for _, arch in LobbyConfig.archModels do
			table.insert(ids, arch.mesh)
		end
		for _, design in PalaceBuildings do
			for _, piece in design.pieces do
				table.insert(ids, piece.mesh)
			end
		end
		dexTemplates = MeshTemplates.load(ids)
		lobbyTemplates = dexTemplates
	end
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

	-- the stations, and their stands out front
	for _, station in LobbyConfig.stations do
		local size = building(station.piece, station.at, root)
		if size then
			keep(station.at, Vector2.new(size.X, size.Z).Magnitude / 2 + 3)
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
				COLOURS.woodDark,
				model
			)
			post.CanCollide = true
		end
		part(
			"Backing",
			Vector3.new(face.size.X + 2, face.size.Y + 2, 0.8),
			base * CFrame.new(0, face.centre.Y, face.centre.Z - 0.6),
			COLOURS.wood,
			model
		)
		part(
			"Crest",
			Vector3.new(face.size.X + 3, 1.4, 1.2),
			base * CFrame.new(0, face.centre.Y + face.size.Y / 2 + 1.4, face.centre.Z - 0.6),
			COLOURS.gold,
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
