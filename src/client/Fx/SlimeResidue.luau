--!strict
--[[
	Slime residue (owner, 2026-10-23): every hit on a slime throws a few
	little cubes of its jelly out of the face the shot struck. They tumble,
	land on the floor as flat splats, sit a moment and shrink away. A crit
	throws more; a kill more again, all the way round. King Bloblin's are
	chunks. Which slimes, their colours, sizes and counts: `Balance.
	SlimeResidue`; the arithmetic: `Shared/Util/ResidueSpray`.

	Presentation only, on this client, from what the server says happened
	(`Remotes.EnemyHit`, `Remotes.EnemyDied`). The cubes neither collide,
	nor are queried, nor touch, so no arrow or player ever meets one.

	The cubes are built once, `DeviceTiers.maxSlimeResidue` of them, and
	reused oldest first; a frame moves them in one `BulkMoveTo` and makes
	nothing new.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)
local ResidueSpray = require(ReplicatedStorage.Shared.Util.ResidueSpray)

local SlimeResidue = {}

type Cube = {
	part: BasePart,
	alive: boolean,
	landed: boolean,
	position: Vector3,
	velocity: Vector3,
	rotation: CFrame,
	spinAxis: Vector3,
	spinRate: number,
	--[[ The cube's edge in flight. ]]
	size: number,
	--[[ The splat's size once landed. ]]
	splat: Vector3,
	landedAt: number,
}

--[[ Where an unused cube waits, out of sight under the world. ]]
local HIDDEN = CFrame.new(0, -500, 0)

local settings: ResidueSpray.Settings = Balance.SlimeResidue :: any
local rng = Random.new()
local pool: { Cube } = {}
local last = 0
local connection: RBXScriptConnection? = nil

--[[ Reused every frame for the one bulk move. ]]
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function floorY(): number
	return settings.floorLift
end

local function step(dt: number)
	local now = os.clock()
	local any = false
	table.clear(moveParts)
	table.clear(moveFrames)

	for _, cube in pool do
		if not cube.alive then
			continue
		end
		any = true
		local part = cube.part

		if not cube.landed then
			cube.velocity -= Vector3.yAxis * settings.gravity * dt
			cube.position += cube.velocity * dt
			cube.rotation = CFrame.fromAxisAngle(cube.spinAxis, cube.spinRate * dt) * cube.rotation
			if cube.position.Y - cube.size / 2 <= floorY() and cube.velocity.Y < 0 then
				--[[ Lands: flat on the floor, square to it, turned only
				     about the vertical so splats do not all line up. ]]
				cube.landed = true
				cube.landedAt = now
				cube.position =
					Vector3.new(cube.position.X, floorY() + cube.splat.Y / 2, cube.position.Z)
				cube.rotation = CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
				part.Size = cube.splat
			end
			table.insert(moveParts, part)
			table.insert(moveFrames, CFrame.new(cube.position) * cube.rotation)
			continue
		end

		local t = now - cube.landedAt - settings.rest
		if t <= 0 then
			continue
		end
		if t >= settings.shrink then
			cube.alive = false
			part.Transparency = 1
			table.insert(moveParts, part)
			table.insert(moveFrames, HIDDEN)
			continue
		end
		--[[ Shrinks into the floor: eased so it lingers, then goes. ]]
		local k = 1 - t / settings.shrink
		k *= k
		local size = cube.splat * k
		part.Size = size
		table.insert(moveParts, part)
		table.insert(
			moveFrames,
			CFrame.new(cube.position.X, floorY() + size.Y / 2, cube.position.Z) * cube.rotation
		)
	end

	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	if not any and connection then
		connection:Disconnect()
		connection = nil
	end
end

--[[ Throws a burst of `kind`'s residue from `at`, fanned across `arc`
     radians about `back`. ]]
local function burst(
	kind: ResidueSpray.Kind,
	at: Vector3,
	back: Vector3,
	count: number,
	arc: number
)
	local cap = #pool
	if cap == 0 then
		return
	end
	local velocities = ResidueSpray.velocities(back, count, arc, settings, rng)
	for index, velocity in velocities do
		last = ResidueSpray.slot(last, cap)
		local cube = pool[last]
		local edge = ResidueSpray.size(kind, settings, rng)
		cube.alive = true
		cube.landed = false
		cube.position = at
		cube.velocity = velocity
		cube.rotation = CFrame.Angles(
			rng:NextNumber() * math.pi,
			rng:NextNumber() * math.pi,
			rng:NextNumber() * math.pi
		)
		cube.spinAxis = rng:NextUnitVector()
		cube.spinRate = (0.4 + rng:NextNumber() * 0.6) * settings.spin
		cube.size = edge
		cube.splat = Vector3.new(
			edge * settings.splatWide,
			edge * settings.splatFlat,
			edge * settings.splatWide
		)
		local part = cube.part
		part.Size = Vector3.one * edge
		part.Color = ResidueSpray.colour(kind, index, settings, rng)
		part.Transparency = 0
		part.CFrame = CFrame.new(at) * cube.rotation
	end
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

local function kindOf(name: unknown): ResidueSpray.Kind?
	if type(name) ~= "string" then
		return nil
	end
	return settings.kinds[name]
end

local function fromOf(from: unknown): Vector3?
	return if typeof(from) == "Vector3" then from else nil
end

--[[ The server's `EnemyHit`: `from` is where the blow came from, nil for
     a burn, which ticks too often to throw anything. ]]
function SlimeResidue.onEnemyHit(
	model: unknown,
	_amount: unknown,
	position: unknown,
	hitKind: unknown,
	from: unknown
)
	if hitKind == "Burn" then
		return
	end
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	local kind = kindOf(model.Name)
	if not kind then
		return
	end

	local hitbox = model.PrimaryPart
	local centre = if hitbox
		then hitbox.Position
		elseif typeof(position) == "Vector3" then position
		else nil
	if not centre then
		return
	end
	local back = ResidueSpray.back(centre, fromOf(from), rng)
	--[[ From the struck face, at the height arrows fly, inside the body. ]]
	local reach = if hitbox then math.min(hitbox.Size.X, hitbox.Size.Z) / 2 else 1
	local top = if hitbox then centre.Y + hitbox.Size.Y / 2 else centre.Y
	local height = math.clamp(Balance.Projectile.height, floorY() + kind.size, top)
	local at = Vector3.new(centre.X, height, centre.Z) + back * reach * 0.9

	local count = ResidueSpray.count(kind, hitKind :: string?, false, settings)
	burst(kind, at, back, count, ResidueSpray.arc(false, settings))
end

--[[ The server's `EnemyDied`, which names the archetype because the model
     is gone by the time it arrives. ]]
function SlimeResidue.onEnemyDied(
	position: unknown,
	_amount: unknown,
	hitKind: unknown,
	name: unknown,
	from: unknown
)
	local kind = kindOf(name)
	if not kind or typeof(position) ~= "Vector3" then
		return
	end
	local back = ResidueSpray.back(position, fromOf(from), rng)
	local at = Vector3.new(position.X, math.max(position.Y, floorY() + kind.size), position.Z)
	local count = ResidueSpray.count(kind, hitKind :: string?, true, settings)
	burst(kind, at, back, count, ResidueSpray.arc(true, settings))
end

--[[ Builds the pool, once, at this device's cap. ]]
function SlimeResidue.start(parent: Instance)
	local existing = parent:FindFirstChild("SlimeResidue")
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("Folder")
	created.Name = "SlimeResidue"
	created.Parent = parent

	table.clear(pool)
	last = 0
	for _ = 1, Device.tier().maxSlimeResidue do
		local part: BasePart = Instance.new("Part")
		part.Name = "Residue"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Transparency = 1
		part.CFrame = HIDDEN
		part.Parent = created
		table.insert(pool, {
			part = part,
			alive = false,
			landed = false,
			position = Vector3.zero,
			velocity = Vector3.zero,
			rotation = CFrame.identity,
			spinAxis = Vector3.yAxis,
			spinRate = 0,
			size = 0,
			splat = Vector3.zero,
			landedAt = 0,
		})
	end
end

return SlimeResidue
