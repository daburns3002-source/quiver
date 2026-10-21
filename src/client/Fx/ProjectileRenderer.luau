--!strict
--[[
	Projectile visuals.

	Draws straight-line flights from a volley description. Nothing here decides
	anything: the server has already resolved who got hit. These parts exist so
	the player can read the shot, and they despawn on contact purely so arrows
	do not visibly pass through a wall.

	Parts are pooled. At Phase 3 volley sizes, allocating a Part per projectile
	would be the single biggest source of frame hitches.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)
local Types = require(ReplicatedStorage.Shared.Types)

type ShotSpec = Types.ShotSpec

type Visual = {
	part: BasePart,
	position: Vector3,
	direction: Vector3,
	speed: number,
	expiresAt: number,
}

local ProjectileRenderer = {}

local folder: Folder? = nil
local pool: { BasePart } = {}
local live: { Visual } = {}
local raycastParams: RaycastParams? = nil
local connection: RBXScriptConnection? = nil

local PROJECTILE_LENGTH = 2.2

local function createPart(): BasePart
	local tier = Device.tier()

	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Size =
		Vector3.new(Balance.Projectile.radius * 2, Balance.Projectile.radius * 2, PROJECTILE_LENGTH)
	part.Shape = if tier.projectileIsRound then Enum.PartType.Cylinder else Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 226, 150)
	return part
end

local function acquire(): BasePart
	local part = table.remove(pool)

	if not part then
		part = createPart()
	end

	local resolved = part :: BasePart
	resolved.Parent = folder
	return resolved
end

local function release(part: BasePart)
	part.Parent = nil
	table.insert(pool, part)
end

function ProjectileRenderer.refreshFilter()
	local instances: { Instance } = {}

	local arena = Workspace:FindFirstChild("Arena")
	local blockers = if arena then arena:FindFirstChild("Blockers") else nil
	if blockers then
		table.insert(instances, blockers)
	end

	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(instances, enemies)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = instances
	params.IgnoreWater = true

	raycastParams = params
end

local function step(deltaTime: number)
	local params = raycastParams
	local now = os.clock()

	for index = #live, 1, -1 do
		local visual = live[index]
		local travel = visual.speed * deltaTime
		local segment = visual.direction * travel
		local finished = now >= visual.expiresAt

		if not finished and params then
			local result = Workspace:Raycast(visual.position, segment, params)
			if result then
				visual.position = result.Position
				finished = true
			end
		end

		if not finished then
			visual.position += segment
		end

		visual.part.CFrame = CFrame.lookAt(visual.position, visual.position + visual.direction)

		if finished then
			release(visual.part)

			local last = #live
			live[index] = live[last]
			live[last] = nil
		end
	end
end

local function rotateY(direction: Vector3, radians: number): Vector3
	local cos = math.cos(radians)
	local sin = math.sin(radians)

	return Vector3.new(
		direction.X * cos - direction.Z * sin,
		0,
		direction.X * sin + direction.Z * cos
	)
end

--[[
	Draws one volley. `elapsed` lets a replicated shot start partway along its
	flight so a remote player's arrows are not drawn lagging behind where the
	server already has them.
]]
function ProjectileRenderer.spawnVolley(
	origin: Vector3,
	direction: Vector3,
	specs: { ShotSpec },
	elapsed: number
)
	local tier = Device.tier()
	local now = os.clock()

	for _, spec in specs do
		if #live >= tier.maxRenderedProjectiles then
			break
		end

		local aim = rotateY(direction, spec.angleOffset)
		local headStart = math.clamp(elapsed, 0, spec.lifetime)

		local part = acquire()
		local position = origin + aim * spec.speed * headStart
		part.CFrame = CFrame.lookAt(position, position + aim)

		table.insert(live, {
			part = part,
			position = position,
			direction = aim,
			speed = spec.speed,
			expiresAt = now + (spec.lifetime - headStart),
		})
	end
end

function ProjectileRenderer.start(parent: Instance)
	local existing = parent:FindFirstChild("ProjectileVisuals")
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = "ProjectileVisuals"
	created.Parent = parent
	folder = created

	ProjectileRenderer.refreshFilter()

	if connection then
		connection:Disconnect()
	end

	connection = RunService.RenderStepped:Connect(step)
end

return ProjectileRenderer
