--!strict
--[[
	Grey-box arena.

	Builds the Phase 1 room and answers collision queries against it. Procedural
	rather than a Studio model on purpose: the filesystem is the source of truth,
	so the room has to be reproducible from code.

	Phase 2 replaces this with a room library and a layout generator.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaKits = require(ReplicatedStorage.Shared.Config.ArenaKits)
local ArenaModels = require(ReplicatedStorage.Shared.Config.ArenaModels)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ExitGate = require(script.Parent.ExitGate)
local KitLayout = require(ReplicatedStorage.Shared.Util.KitLayout)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)

local log = Log.forTag("Arena")

--[[ An axis-aligned box on the XZ plane, used for collision resolution. ]]
type Box = {
	centre: Vector2,
	halfExtents: Vector2,
}

local Arena = {}

--[[
	Everything a projectile raycast should be able to hit that is not an enemy.
	Walls and pillars both block the player's arrows.
]]
local blockersFolder: Folder? = nil
local exitGate: ExitGate.Gate? = nil
local boxes: { Box } = {}
local halfSize = Vector2.zero
--[[ Bumped every time a room is built, so anything cached against the
     layout (`Enemies/Pathing`'s grids) knows to rebuild. ]]
local layoutVersion = 0

local function makePart(name: string, size: Vector3, position: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.CastShadow = false
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

--[[
	Drops the place's default baseplate.

	The arena lays its own floor with the top surface at exactly y = 0, and
	Roblox's template baseplate sits at exactly the same height. Two opaque
	coplanar surfaces z-fight across the whole play area, which reads as the
	ground shimmering — and only while the camera is moving, so it looks like a
	movement bug rather than a rendering one.

	The arena owns its ground plane, so the baseplate goes. A room built from
	code cannot rely on what a place file happens to contain.
]]
local function clearDefaultBaseplate(parent: Instance)
	local baseplate = parent:FindFirstChild("Baseplate")

	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
		log.info("removed the default baseplate; the arena owns the ground plane")
	end
end

--[[ A piece of dressing: seen, never touched. It must not collide, answer a
     raycast or stop an arrow, or decoration would quietly become level
     geometry. ]]
local function decor(
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function varied(colour: Color3, amount: number): Color3
	return Color3.new(
		math.clamp(colour.R * amount, 0, 1),
		math.clamp(colour.G * amount, 0, 1),
		math.clamp(colour.B * amount, 0, 1)
	)
end

--[[
	Dresses the room in Archero 2's first-chapter look (docs/ART-archero2.md
	§2, §5). Flagstones laid over darker grout, caps on the walls and
	pillars, orb lamps along the side walls, a grass edge at the back, and
	something past the walls other than sky.

	The flagstones come from a fixed seed, so every room is laid the same and
	a rebuild never shimmers between patterns. They sit three hundredths of a
	stud above the true floor, which stays the ground everything stands on.
]]
local function dress(root: Instance, obstacles: { Balance.Obstacle })
	local config = Balance.Arena
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = root

	local extentX = config.size.X / 2
	local extentZ = config.size.Z / 2
	local random = Random.new(20261022)
	local gap = 0.14
	local tileHeight = 0.03

	local z = -extentZ
	while z < extentZ - 0.5 do
		local depth = math.min(random:NextNumber(2.6, 4.4), extentZ - z)
		local x = -extentX

		while x < extentX - 0.5 do
			local width = math.min(random:NextNumber(2.6, 5.0), extentX - x)
			local shade = random:NextNumber(0.93, 1.07)
			decor(
				"Tile",
				Vector3.new(width - gap, tileHeight, depth - gap),
				CFrame.new(x + width / 2, tileHeight / 2, z + depth / 2),
				varied(config.tileColor, shade),
				folder
			)
			x += width
		end

		z += depth
	end

	-- A grass edge along the back wall, where Archero 2's courtyards meet the garden.
	decor(
		"Grass",
		Vector3.new(config.size.X, 0.04, 2.4),
		CFrame.new(0, 0.02 + tileHeight, -extentZ + 1.2),
		config.grassColor,
		folder
	)

	-- Wall caps: a lighter bevel along the top of every wall. The side caps
	-- stop where the end caps begin: overlapping at the corners, their tops
	-- were one plane in two parts, which z-fights while the camera moves.
	local thickness = config.wallThickness
	local height = config.wallHeight
	local sideCapLength = config.size.Z - 0.3
	local caps = {
		{
			Vector3.new(config.size.X + thickness * 2 + 0.3, 0.5, thickness + 0.3),
			Vector3.new(0, height + 0.25, -extentZ - thickness / 2),
		},
		{
			Vector3.new(config.size.X + thickness * 2 + 0.3, 0.5, thickness + 0.3),
			Vector3.new(0, height + 0.25, extentZ + thickness / 2),
		},
		{
			Vector3.new(thickness + 0.3, 0.5, sideCapLength),
			Vector3.new(-extentX - thickness / 2, height + 0.25, 0),
		},
		{
			Vector3.new(thickness + 0.3, 0.5, sideCapLength),
			Vector3.new(extentX + thickness / 2, height + 0.25, 0),
		},
	}
	for _, cap in caps do
		decor("WallCap", cap[1], CFrame.new(cap[2]), config.wallCapColor, folder)
	end

	-- Orb lamps on columns along both side walls: pilasters standing a little
	-- proud of the wall on both faces. A column exactly as thick as the wall
	-- shared its faces with it, and two coplanar faces in two colours flicker
	-- whenever the camera moves.
	local spacing = config.lampSpacing
	local count = math.floor(config.size.Z / spacing)
	for index = 0, count do
		local lampZ = -extentZ + spacing / 2 + index * spacing
		if lampZ > extentZ - 1 then
			continue
		end

		for _, side in { -1, 1 } do
			local columnX = side * (extentX + thickness / 2)
			decor(
				"LampColumn",
				Vector3.new(thickness + 0.4, height + 1.4, 1.8),
				CFrame.new(columnX, (height + 1.4) / 2, lampZ),
				config.wallCapColor,
				folder
			)
			local orb = decor(
				"LampOrb",
				Vector3.one * 1.3,
				CFrame.new(columnX, height + 1.4 + 0.55, lampZ),
				config.lampColor,
				folder
			)
			orb.Shape = Enum.PartType.Ball
			orb.Material = Enum.Material.Neon
		end
	end

	-- Caps on the pillars, the same bevel as the walls.
	for _, obstacle in obstacles do
		decor(
			"ObstacleCap",
			Vector3.new(obstacle.size.X + 0.25, 0.45, obstacle.size.Z + 0.25),
			CFrame.new(obstacle.offset.X, obstacle.size.Y + 0.22, obstacle.offset.Y),
			config.obstacleCapColor,
			folder
		)
	end

	-- The world past the walls: a dark, cool plane below the floor, so the
	-- edges of the screen are a place rather than the sky.
	decor("Outside", Vector3.new(400, 1, 400), CFrame.new(0, -1.2, 0), config.outsideColor, folder)
end

--[[ One template per uploaded arena mesh, made once and cloned per room:
     CreateMeshPartAsync yields, which building a room must not wait on. ]]
local meshTemplates: { [string]: MeshPart } = {}

--[[ Makes the templates every arena model needs. Called once at server
     start; a mesh that fails to load is left out of its room, which then
     shows the invisible-walled floor rather than failing to build. ]]
function Arena.preload()
	local ids: { string } = {}
	for _, model in ArenaModels :: { [string]: ArenaModels.ArenaModel } do
		local surround: { ArenaModels.ArenaPart } = model.surround or {}
		for _, list in { model.parts, surround } do
			for _, spec in list do
				table.insert(ids, spec.meshId)
			end
		end
	end
	for _, kit in ArenaKits do
		for _, piece in kit.pieces do
			table.insert(ids, piece.meshId)
			local glow = piece.glow
			if glow then
				table.insert(ids, glow.meshId)
			end
		end
	end
	meshTemplates = MeshTemplates.load(ids)
end

--[[
	Draws a room with its area's model instead of the grey-box dressing.
	Every part is scenery: it never collides, answers a raycast or stops an
	arrow. The room's own invisible walls and obstacle boxes still do.
]]
--[[ How high a pond's water sheet sits, clear of the lawn's lip; and how
     much wider than the water its dark rim is. ]]
local WATER_HEIGHT = 0.1
local WATER_RIM = 1.08
--[[ The bank covers the lawn's stepped darker ring, which reaches about
     1.15 times the water's size. ]]
local WATER_BANK = 1.18

--[[ A room built from a kit (`Shared/Util/KitLayout`): its lawn, water,
     walls, cover and plants, each piece cloned from its imported mesh. A
     piece whose mesh has not loaded is left out rather than failing the
     room. ]]
local function placeKit(
	folder: Instance,
	kitName: string,
	obstacles: { Balance.Obstacle },
	lowCover: KitLayout.LowCover,
	seed: number
)
	local config = Balance.Arena
	local kit = ArenaKits[kitName]
	local layout = KitLayout.build(kitName, {
		size = config.size,
		wallThickness = config.wallThickness,
		spawn = config.spawnPosition,
		gateWidth = Balance.Run.gate.width + Balance.Run.gate.pillarWidth * 2,
	}, obstacles, lowCover, seed)

	for _, patch in layout.patches do
		local part = Instance.new("Part")
		part.Name = patch.kind
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = patch.size
		part.Position = patch.centre
		part.Color = patch.colour
		part.Material = Enum.Material.Fabric
		if patch.kind == "Water" or patch.kind == "Bank" then
			--[[ Water and its bank are round: a sphere mesh flattened to
			     the patch, as the round glade's pond was. ]]
			if patch.kind == "Water" then
				part.Material = Enum.Material.SmoothPlastic
				part.Reflectance = 0.15
			end
			local sphere = Instance.new("SpecialMesh")
			sphere.MeshType = Enum.MeshType.Sphere
			sphere.Parent = part
		end
		part.Parent = folder
	end

	--[[ The importer turns each mesh 180° about Y; turned back. ]]
	local turn = CFrame.Angles(0, math.pi, 0)
	local function mesh(
		meshId: string,
		name: string,
		size: Vector3,
		at: CFrame,
		glow: boolean,
		tint: Color3?
	)
		local template = meshTemplates[meshId]
		if not template then
			return
		end
		local part = template:Clone()
		part.Name = name
		part.Size = size
		part.CFrame = at * turn
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Color = tint or Color3.new(1, 1, 1)
		part.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.CastShadow = not glow
		part.Parent = folder
	end
	for _, placed in layout.pieces do
		local piece = KitLayout.piece(kit, placed.piece)
		if not piece then
			continue
		end
		local facing = CFrame.Angles(0, placed.yaw, 0)
		local grown = placed.size / piece.size
		mesh(
			piece.meshId,
			placed.piece,
			placed.size,
			CFrame.new(placed.base + Vector3.new(0, placed.size.Y / 2, 0)) * facing,
			false,
			piece.tint
		)
		local glow = piece.glow
		if glow then
			mesh(
				glow.meshId,
				placed.piece .. "Glow",
				glow.size * grown,
				CFrame.new(placed.base + facing:VectorToWorldSpace(glow.centre * grown)) * facing,
				true
			)
		end
	end
end

local function placeModel(
	root: Instance,
	model: ArenaModels.ArenaModel,
	obstacles: { Balance.Obstacle },
	seed: number
)
	local folder = Instance.new("Folder")
	folder.Name = "Model"
	folder.Parent = root

	--[[ The importer turns models 180° about Y; turned back, the room faces
	     the way Claude Design shows it. Offsets are already turned. ]]
	local turn = CFrame.Angles(0, math.pi, 0)

	local function place(spec: ArenaModels.ArenaPart, shift: Vector3, name: string)
		local water = spec.water
		if water then
			local at = spec.offset + shift
			--[[
				A soft, round shadow at the pond's edge (owner, 2026-10-23:
				"fix the shadows of the pond, it should be circular"). The
				lawn's low-poly lip used to shade the water in jagged steps;
				the water now sits just above that lip, and this darker
				ellipse a little wider than it, under it, is its edge.
			]]
			local bank = spec.bank
			if bank then
				local ring = Instance.new("Part")
				ring.Name = `{name}Bank`
				ring.Size = Vector3.new(spec.size.X * WATER_BANK, 0.04, spec.size.Z * WATER_BANK)
				ring.CFrame = CFrame.new(at.X, WATER_HEIGHT - 0.04, at.Z)
				ring.Anchored = true
				ring.CanCollide = false
				ring.CanQuery = false
				ring.CanTouch = false
				ring.CastShadow = false
				ring.Color = bank
				ring.Material = Enum.Material.Fabric
				local ringMesh = Instance.new("SpecialMesh")
				ringMesh.MeshType = Enum.MeshType.Sphere
				ringMesh.Parent = ring
				ring.Parent = folder
			end

			local rim = Instance.new("Part")
			rim.Name = `{name}Rim`
			rim.Size = Vector3.new(spec.size.X * WATER_RIM, 0.04, spec.size.Z * WATER_RIM)
			rim.CFrame = CFrame.new(at.X, WATER_HEIGHT - 0.02, at.Z)
			rim.Anchored = true
			rim.CanCollide = false
			rim.CanQuery = false
			rim.CanTouch = false
			rim.CastShadow = false
			rim.Color = water:Lerp(Color3.new(0, 0, 0), 0.55)
			rim.Material = Enum.Material.SmoothPlastic
			local rimMesh = Instance.new("SpecialMesh")
			rimMesh.MeshType = Enum.MeshType.Sphere
			rimMesh.Parent = rim
			rim.Parent = folder

			local sheet = Instance.new("Part")
			sheet.Name = name
			sheet.Size = Vector3.new(spec.size.X, 0.06, spec.size.Z)
			--[[ Just above the lawn, not at the mesh's own depth: the pond's
			     dark basin is drawn above that and hid it, and the lawn's lip
			     shaded it. ]]
			sheet.CFrame = CFrame.new(at.X, WATER_HEIGHT, at.Z)
			sheet.Anchored = true
			sheet.CanCollide = false
			sheet.CanQuery = false
			sheet.CanTouch = false
			sheet.CastShadow = false
			sheet.Color = water
			sheet.Material = Enum.Material.SmoothPlastic
			sheet.Reflectance = 0.15
			--[[ An ellipse: a sphere mesh flattened to the sheet. A cylinder
			     mesh stays round, whatever the part's size. ]]
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = sheet
			sheet.Parent = folder
			return
		end

		local template = meshTemplates[spec.meshId]
		if not template then
			return
		end
		local part = template:Clone()
		part.Name = name
		part.Size = spec.size
		part.CFrame = CFrame.new(spec.offset + shift) * turn
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		--[[ White, so the model's own vertex colours show unchanged. ]]
		part.Color = spec.tint or Color3.new(1, 1, 1)
		part.Material = if spec.glow
			then Enum.Material.Neon
			elseif spec.matte then Enum.Material.Fabric
			else Enum.Material.SmoothPlastic
		part.CastShadow = not spec.glow
		part.Parent = folder
	end

	for _, spec in model.parts do
		place(spec, Vector3.zero, spec.name)
	end

	local kit = model.kit
	if kit and ArenaKits[kit] then
		placeKit(folder, kit, obstacles, model.lowCover or "Thicket", seed)
	end

	--[[ The forest again to either side, so it runs past the screen's edges. ]]
	local spacing = model.surroundSpacing
	if spacing and model.surround then
		for _, spec in model.surround do
			for _, side in { -1, 1 } do
				place(spec, Vector3.new(side * spacing, 0, 0), `{spec.name}Surround`)
			end
		end
	end

	--[[ A forest floor under everything, its top just below the outer
	     forest's ground (Y -0.2) so the two never share a plane and flicker,
	     and it shows only past the forest's edge. ]]
	local outside = model.outsideColor
	if outside then
		local floor =
			decor("Outside", Vector3.new(600, 1, 600), CFrame.new(0, -0.75, 0), outside, folder)
		--[[ Matte: plastic catches the sun at a glance and paled to grey. ]]
		floor.Material = Enum.Material.Fabric
	end
end

--[[
	Builds the room under `parent` and returns the folder holding everything that
	blocks a projectile.

	`obstacles` is the room's layout. The walls, floor and door are the same in
	every room; the pillars are what make one room a different fight from the
	last, which is why they are the only thing passed in.
]]
--[[ `arena` names the `ArenaModels` entry that dresses the room; nil, or a
     name with no model, is the grey box. ]]
function Arena.build(parent: Instance, obstacles: { Balance.Obstacle }, arena: string?): Folder
	local config = Balance.Arena

	local existing = parent:FindFirstChild("Arena")
	if existing then
		existing:Destroy()
	end

	clearDefaultBaseplate(parent)

	local root = Instance.new("Folder")
	root.Name = "Arena"

	local blockers = Instance.new("Folder")
	blockers.Name = "Blockers"
	blockers.Parent = root

	--[[ Outside `Blockers`, which the projectile filters list: these stop
	     the player and nothing else. ]]
	local playerWalls = Instance.new("Folder")
	playerWalls.Name = "PlayerWalls"
	playerWalls.Parent = root

	-- Floor sits with its top surface exactly at y = 0.
	local floor =
		makePart("Floor", config.size, Vector3.new(0, -config.size.Y / 2, 0), config.floorColor)
	floor.Parent = root

	local extentX = config.size.X / 2
	local extentZ = config.size.Z / 2
	local thickness = config.wallThickness
	local height = config.wallHeight

	halfSize = Vector2.new(extentX, extentZ)
	table.clear(boxes)
	layoutVersion += 1

	local wallDefinitions = {
		{
			name = "WallNorth",
			size = Vector3.new(config.size.X + thickness * 2, height, thickness),
			position = Vector3.new(0, height / 2, -extentZ - thickness / 2),
		},
		{
			name = "WallSouth",
			size = Vector3.new(config.size.X + thickness * 2, height, thickness),
			position = Vector3.new(0, height / 2, extentZ + thickness / 2),
		},
		{
			name = "WallWest",
			size = Vector3.new(thickness, height, config.size.Z),
			position = Vector3.new(-extentX - thickness / 2, height / 2, 0),
		},
		{
			name = "WallEast",
			size = Vector3.new(thickness, height, config.size.Z),
			position = Vector3.new(extentX + thickness / 2, height / 2, 0),
		},
	}

	for _, definition in wallDefinitions do
		local wall =
			makePart(definition.name, definition.size, definition.position, config.wallColor)
		wall.Parent = blockers
	end

	for index, obstacle in obstacles do
		local part = makePart(
			`Obstacle{index}`,
			obstacle.size,
			Vector3.new(obstacle.offset.X, obstacle.size.Y / 2, obstacle.offset.Y),
			config.obstacleColor
		)
		part.Parent = blockers

		--[[
			A wall over the cover, as tall as the room's walls, that only the
			player meets. Low cover — the pond, the thorns, a log or a stump —
			was short enough for a character to step up onto and walk across
			(owner, 2026-10-23: "the player should not be able to walk over any
			obstacles"). Not queryable, so arrows still fly over low cover and
			nothing that sweeps or targets ever sees it; enemies are kept out
			of cover analytically and never touch it either.
		]]
		local wall = makePart(
			`PlayerWall{index}`,
			Vector3.new(obstacle.size.X, height, obstacle.size.Z),
			Vector3.new(obstacle.offset.X, height / 2, obstacle.offset.Y),
			config.obstacleColor
		)
		wall.CanQuery = false
		wall.CanTouch = false
		wall.Transparency = 1
		wall.Parent = playerWalls

		table.insert(boxes, {
			centre = obstacle.offset,
			halfExtents = Vector2.new(obstacle.size.X / 2, obstacle.size.Z / 2),
		})
	end

	--[[ The exit gate in the north wall: dark until the room is cleared. ]]
	local gate = ExitGate.build(root)

	local model = if arena then (ArenaModels :: any)[arena] :: ArenaModels.ArenaModel? else nil
	if model then
		--[[ The model draws the room, so the grey box's floor, walls and
		     cover boxes go invisible. They still collide and stop arrows. ]]
		floor.Transparency = 1
		for _, part in blockers:GetChildren() do
			if part:IsA("BasePart") then
				part.Transparency = 1
			end
		end
		placeModel(root, model, obstacles, KitLayout.seed(arena or ""))
		--[[ The client draws the scenery's life from this
		     (`Fx/ForestAmbience`). ]]
		root:SetAttribute("Ambience", model.ambience)
	else
		dress(root, obstacles)
	end

	root.Parent = parent
	blockersFolder = blockers
	exitGate = gate

	log.info("built arena with %d obstacles", #boxes)

	return blockers
end

function Arena.blockers(): Folder?
	return blockersFolder
end

--[[
	Lights the exit pad, or puts it out.

	Appearance only — whether standing on it actually advances the run is
	decided by the server, which never trusts the pad's own state.
]]
function Arena.setDoorOpen(open: boolean)
	local gate = exitGate
	if gate then
		ExitGate.setOpen(gate, open)
	end
end

--[[ The number over the gate: the room it leads to. ]]
function Arena.setDoorLabel(text: string)
	local gate = exitGate
	if gate then
		ExitGate.setLabel(gate, text)
	end
end

--[[ True when `position` has reached the exit, in front of the gate. ]]
function Arena.isAtDoor(position: Vector3): boolean
	local run = Balance.Run
	local flat = Vector2.new(position.X - run.doorOffset.X, position.Z - run.doorOffset.Y)

	return flat.Magnitude <= run.doorRadius
end

--[[
	Pushes a footprint of `half` (half-widths along X and Z) out of any
	obstacle it overlaps and back inside the walls. Analytic rather than
	physics-driven: enemies are anchored and moved by CFrame, which is far
	cheaper than a Humanoid each and avoids them shoving each other into
	geometry.

	Per-axis because an enemy's hitbox is a square that turns with it. Kept
	clear by a single radius, a turned square's corners reached 0.62 studs
	into pillars; a footprint measured at its current turn keeps the whole
	box out.
]]
function Arena.resolveBox(position: Vector3, half: Vector2): Vector3
	local point = Vector2.new(position.X, position.Z)

	for _, box in boxes do
		local delta = point - box.centre
		local overlapX = (box.halfExtents.X + half.X) - math.abs(delta.X)
		local overlapZ = (box.halfExtents.Y + half.Y) - math.abs(delta.Y)

		if overlapX > 0 and overlapZ > 0 then
			-- Push out along the shallower axis, which is the nearest way out.
			if overlapX < overlapZ then
				local sign = if delta.X >= 0 then 1 else -1
				point = Vector2.new(box.centre.X + sign * (box.halfExtents.X + half.X), point.Y)
			else
				local sign = if delta.Y >= 0 then 1 else -1
				point = Vector2.new(point.X, box.centre.Y + sign * (box.halfExtents.Y + half.Y))
			end
		end
	end

	local limitX = math.max(halfSize.X - half.X, 0)
	local limitZ = math.max(halfSize.Y - half.Y, 0)

	point = Vector2.new(math.clamp(point.X, -limitX, limitX), math.clamp(point.Y, -limitZ, limitZ))

	return Vector3.new(point.X, position.Y, point.Y)
end

--[[ `resolveBox` for something the same width on both axes — a body that
     does not turn, or a probe. ]]
function Arena.resolve(position: Vector3, radius: number): Vector3
	return Arena.resolveBox(position, Vector2.new(radius, radius))
end

--[[
	Keeps a circle inside the outer walls while ignoring obstacles entirely.

	For things that are not travelling through the room so much as under it. A
	burrowing enemy that still had to walk around pillars would spend its whole
	dive steering and surface no closer than it started, which makes the dive
	pointless — but it still must not leave the arena.
]]
function Arena.clampToWalls(position: Vector3, radius: number): Vector3
	local limitX = math.max(halfSize.X - radius, 0)
	local limitZ = math.max(halfSize.Y - radius, 0)

	return Vector3.new(
		math.clamp(position.X, -limitX, limitX),
		position.Y,
		math.clamp(position.Z, -limitZ, limitZ)
	)
end

--[[ True if a circle at this point would be clear of obstacles and walls. ]]
function Arena.isClear(position: Vector3, radius: number): boolean
	local resolved = Arena.resolve(position, radius)
	return (resolved - position).Magnitude < 1e-3
end

--[[ Studs between samples along a segment: well under any body's radius, so
     no obstacle corner can slip between two of them. ]]
local SEGMENT_STEP = 0.5

--[[ True if a body of `radius` could travel in a straight line from `from`
     to `to` without touching an obstacle or wall. ]]
function Arena.isSegmentClear(from: Vector3, to: Vector3, radius: number): boolean
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local steps = math.max(1, math.ceil(flat.Magnitude / SEGMENT_STEP))
	for index = 0, steps do
		local point = from + flat * (index / steps)
		if not Arena.isClear(Vector3.new(point.X, 0, point.Z), radius) then
			return false
		end
	end
	return true
end

--[[ The floor's half-size, for anything laying a grid over it. ]]
function Arena.halfSize(): Vector2
	return halfSize
end

--[[ Changes whenever a new room is built. ]]
function Arena.layoutVersion(): number
	return layoutVersion
end

--[[
	The outward normal of the obstacle that would block a circle of `radius`
	travelling from `from` towards `probe`, or nil if nothing is in the way.

	The blocking box is found at `probe`, but the normal is measured at `from`,
	because those can name different faces: a body flush against a pillar's
	east face probes into the span of its north face. Taking the normal at the
	probe would then hand the caller a tangent pointing straight into the
	pillar, and `resolve` would shove it back to the same spot every frame.

	Axis choice mirrors `resolve`, so the face returned is the one `resolve`
	would push out of.
]]
function Arena.deflectionNormal(from: Vector3, probe: Vector3, radius: number): Vector3?
	local probePoint = Vector2.new(probe.X, probe.Z)
	local fromPoint = Vector2.new(from.X, from.Z)

	for _, box in boxes do
		local delta = probePoint - box.centre
		local overlapX = (box.halfExtents.X + radius) - math.abs(delta.X)
		local overlapZ = (box.halfExtents.Y + radius) - math.abs(delta.Y)

		if overlapX > 0 and overlapZ > 0 then
			-- Smaller clearance wins: that is the face the body is nearest to
			-- being outside of, and so the one it is really held against.
			local at = fromPoint - box.centre
			local faceX = (box.halfExtents.X + radius) - math.abs(at.X)
			local faceZ = (box.halfExtents.Y + radius) - math.abs(at.Y)

			if faceX < faceZ then
				return Vector3.new(if at.X >= 0 then 1 else -1, 0, 0)
			end

			return Vector3.new(0, 0, if at.Y >= 0 then 1 else -1)
		end
	end

	return nil
end

return Arena
