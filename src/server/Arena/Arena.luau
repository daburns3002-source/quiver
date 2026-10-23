--!strict
--[[
	Grey-box arena.

	Builds the Phase 1 room and answers collision queries against it. Procedural
	rather than a Studio model on purpose: the filesystem is the source of truth,
	so the room has to be reproducible from code.

	Phase 2 replaces this with a room library and a layout generator.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaModels = require(ReplicatedStorage.Shared.Config.ArenaModels)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Log = require(ReplicatedStorage.Shared.Util.Log)

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
local doorPart: BasePart? = nil
local boxes: { Box } = {}
local halfSize = Vector2.zero

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
	for _, model in ArenaModels :: { [string]: ArenaModels.ArenaModel } do
		local specs = table.clone(model.parts)
		local surround: { ArenaModels.ArenaPart } = model.surround or {}
		for _, spec in surround do
			table.insert(specs, spec)
		end
		for _, spec in specs do
			if meshTemplates[spec.meshId] then
				continue
			end
			local ok, result = pcall(function()
				return AssetService:CreateMeshPartAsync(spec.meshId, {
					CollisionFidelity = Enum.CollisionFidelity.Box,
					RenderFidelity = Enum.RenderFidelity.Automatic,
				})
			end)
			if ok and result then
				meshTemplates[spec.meshId] = result
			else
				log.warn("arena mesh %s did not load: %s", spec.meshId, tostring(result))
			end
		end
	end
end

--[[
	Draws a room with its area's model instead of the grey-box dressing.
	Every part is scenery: it never collides, answers a raycast or stops an
	arrow. The room's own invisible walls and obstacle boxes still do.
]]
local function placeModel(root: Instance, model: ArenaModels.ArenaModel)
	local folder = Instance.new("Folder")
	folder.Name = "Model"
	folder.Parent = root

	--[[ The importer turns models 180° about Y; turned back, the room faces
	     the way Claude Design shows it. Offsets are already turned. ]]
	local turn = CFrame.Angles(0, math.pi, 0)

	local function place(spec: ArenaModels.ArenaPart, shift: Vector3, name: string)
		local water = spec.water
		if water then
			local sheet = Instance.new("Part")
			sheet.Name = name
			sheet.Size = Vector3.new(spec.size.X, 0.06, spec.size.Z)
			--[[ Flush with the lawn, not at the mesh's own depth: the pond's
			     dark basin is drawn above that and hid it. ]]
			local at = spec.offset + shift
			sheet.CFrame = CFrame.new(at.X, 0.03, at.Z)
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
		part.Color = Color3.new(1, 1, 1)
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

	--[[ The forest again to either side, so it runs past the screen's edges. ]]
	local spacing = model.surroundSpacing
	if spacing and model.surround then
		for _, spec in model.surround do
			for _, side in { -1, 1 } do
				place(spec, Vector3.new(side * spacing, 0, 0), `{spec.name}Surround`)
			end
		end
	end

	--[[ A forest floor under everything, just below the model's own ground
	     so the two never share a plane and flicker. ]]
	local outside = model.outsideColor
	if outside then
		local floor =
			decor("Outside", Vector3.new(600, 1, 600), CFrame.new(0, -0.55, 0), outside, folder)
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

		table.insert(boxes, {
			centre = obstacle.offset,
			halfExtents = Vector2.new(obstacle.size.X / 2, obstacle.size.Z / 2),
		})
	end

	--[[
		The exit pad. Built with the room but dark and inert until the wave is
		cleared, so the player can see where they are going to have to get to
		for the whole fight rather than discovering it afterwards.

		Not a blocker: it is flat on the floor and must never stop an arrow.
	]]
	local run = Balance.Run
	local door = makePart(
		"Door",
		run.doorSize,
		Vector3.new(run.doorOffset.X, run.doorSize.Y / 2, run.doorOffset.Y),
		config.obstacleColor
	)
	door.CanCollide = false
	door.CanQuery = false
	door.Transparency = 0.4
	door.Parent = root

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
		placeModel(root, model)
	else
		dress(root, obstacles)
	end

	root.Parent = parent
	blockersFolder = blockers
	doorPart = door
	Arena.setDoorOpen(false)

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
	local door = doorPart
	if not door then
		return
	end

	local run = Balance.Run
	door.Color = if open then run.doorColor else Balance.Arena.obstacleColor
	door.Material = if open then Enum.Material.Neon else Enum.Material.SmoothPlastic
	door.Transparency = if open then 0 else 0.4
end

--[[ True when `position` is standing on the exit pad. ]]
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
