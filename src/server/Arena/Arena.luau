--!strict
--[[
	Grey-box arena.

	Builds the Phase 1 room and answers collision queries against it. Procedural
	rather than a Studio model on purpose: the filesystem is the source of truth,
	so the room has to be reproducible from code.

	Phase 2 replaces this with a room library and a layout generator.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

--[[
	Builds the room under `parent` and returns the folder holding everything that
	blocks a projectile.

	`obstacles` is the room's layout. The walls, floor and door are the same in
	every room; the pillars are what make one room a different fight from the
	last, which is why they are the only thing passed in.
]]
function Arena.build(parent: Instance, obstacles: { Balance.Obstacle }): Folder
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
	Pushes a circle of `radius` out of any obstacle it overlaps and back inside
	the walls. Analytic rather than physics-driven: enemies are anchored and
	moved by CFrame, which is far cheaper than a Humanoid each and avoids them
	shoving each other into geometry.
]]
function Arena.resolve(position: Vector3, radius: number): Vector3
	local point = Vector2.new(position.X, position.Z)

	for _, box in boxes do
		local delta = point - box.centre
		local overlapX = (box.halfExtents.X + radius) - math.abs(delta.X)
		local overlapZ = (box.halfExtents.Y + radius) - math.abs(delta.Y)

		if overlapX > 0 and overlapZ > 0 then
			-- Push out along the shallower axis, which is the nearest way out.
			if overlapX < overlapZ then
				local sign = if delta.X >= 0 then 1 else -1
				point = Vector2.new(box.centre.X + sign * (box.halfExtents.X + radius), point.Y)
			else
				local sign = if delta.Y >= 0 then 1 else -1
				point = Vector2.new(point.X, box.centre.Y + sign * (box.halfExtents.Y + radius))
			end
		end
	end

	local limitX = math.max(halfSize.X - radius, 0)
	local limitZ = math.max(halfSize.Y - radius, 0)

	point = Vector2.new(math.clamp(point.X, -limitX, limitX), math.clamp(point.Y, -limitZ, limitZ))

	return Vector3.new(point.X, position.Y, point.Y)
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
