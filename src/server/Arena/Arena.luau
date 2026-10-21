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
	Builds the room under `parent` and returns the folder holding everything that
	blocks a projectile.
]]
function Arena.build(parent: Instance): Folder
	local config = Balance.Arena

	local existing = parent:FindFirstChild("Arena")
	if existing then
		existing:Destroy()
	end

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

	for index, obstacle in config.obstacles do
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

	root.Parent = parent
	blockersFolder = blockers

	log.info("built arena with %d obstacles", #boxes)

	return blockers
end

function Arena.blockers(): Folder?
	return blockersFolder
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

--[[ True if a circle at this point would be clear of obstacles and walls. ]]
function Arena.isClear(position: Vector3, radius: number): boolean
	local resolved = Arena.resolve(position, radius)
	return (resolved - position).Magnitude < 1e-3
end

return Arena
