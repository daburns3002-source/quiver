--!strict
--[[
	Slime residue (owner, 2026-10-23): every hit on a slime throws a few
	little cubes of its jelly out of the face the shot struck. They tumble,
	land as flat splats on the floor or on the cover they come down on (a
	log, a boulder, the pond), sit a moment and shrink away. A crit
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
local CoverPush = require(ReplicatedStorage.Shared.Util.CoverPush)
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
	--[[ The height it rests at: the floor, or the top of the cover it
	     comes down on, or the floor beside cover it meets (`restOf`). ]]
	floor: number,
	--[[ Studs over the floor it flies before it meets cover's side and
	     drops, from `start`, where it was thrown; nil when it meets none. ]]
	wall: number?,
	start: Vector3,
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

--[[ Rays down onto the room's floor and cover boxes (`Workspace.Arena`;
     its drawn art is not queryable, and the boxes are sized to it). ]]
local RAY_TOP = 100
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

--[[ Where a cube thrown from `at` at `velocity` comes to rest
     (`ResidueSpray.rest`, owner's checklist `rg-slime`: they sank into
     cover at y = 0): on the top of the cover it comes down on, or, if it
     meets the side of cover it cannot clear, on the floor beside it,
     dropping after `wall` studs. Rays onto the room's floor and cover boxes
     (`Workspace.Arena`; the drawn art is not queryable, and is sized to its
     box). ]]
local function restOf(at: Vector3, velocity: Vector3, half: number): (number, number?)
	local base = floorY()
	local arena = Workspace:FindFirstChild("Arena")
	if not arena then
		return base, nil
	end
	rayParams.FilterDescendantsInstances = { arena }
	--[[ From above any cover, not the cube's own peak: a ray starting
	     inside cover taller than the throw misses it and finds the floor
	     under it. Cover too tall to land on is met by its side instead. ]]
	local from = RAY_TOP
	local function topAt(point: Vector3): number
		local hit = Workspace:Raycast(
			Vector3.new(point.X, from, point.Z),
			Vector3.new(0, -(from + 1), 0),
			rayParams
		)
		return if hit and hit.Normal.Y > 0.5 then math.max(hit.Position.Y, 0) else 0
	end
	local function sideAt(origin: Vector3, along: Vector3): number?
		local hit = Workspace:Raycast(origin, along.Unit * (along.Magnitude + 1), rayParams)
		if not hit or math.abs(hit.Normal.Y) > 0.5 then
			return nil
		end
		return Vector3.new(hit.Position.X - origin.X, 0, hit.Position.Z - origin.Z).Magnitude
	end
	local height, wall = ResidueSpray.rest(at, velocity, settings.gravity, half, topAt, sideAt)
	return height + base, wall
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
			--[[ On the exact arc, so it comes down where `restOf` worked out
			     it would: a stepped fall dropped ~0.2 studs low and landed
			     short, inside cover at its edge. ]]
			local before = cube.position
			cube.position += cube.velocity * dt - Vector3.yAxis * (0.5 * settings.gravity * dt * dt)
			cube.velocity -= Vector3.yAxis * settings.gravity * dt
			--[[ Met the side of cover it cannot clear: it drops there. ]]
			local wall = cube.wall
			if wall then
				local flat =
					Vector3.new(cube.position.X - cube.start.X, 0, cube.position.Z - cube.start.Z)
				if flat.Magnitude >= wall then
					local back = if flat.Magnitude > 1e-6 then flat.Unit * wall else Vector3.zero
					cube.position =
						Vector3.new(cube.start.X + back.X, cube.position.Y, cube.start.Z + back.Z)
					cube.velocity = Vector3.new(0, math.min(cube.velocity.Y, 0), 0)
					cube.wall = nil
				end
			end
			cube.rotation = CFrame.fromAxisAngle(cube.spinAxis, cube.spinRate * dt) * cube.rotation
			if cube.position.Y - cube.size / 2 <= cube.floor and cube.velocity.Y < 0 then
				--[[ Lands: flat on the floor, square to it, turned only
				     about the vertical so splats do not all line up; where
				     during this frame it reached the floor, not where the
				     frame left it. ]]
				local above = before.Y - cube.size / 2 - cube.floor
				local fell = before.Y - cube.position.Y
				local share = if fell > 1e-6 then math.clamp(above / fell, 0, 1) else 1
				local at = before:Lerp(cube.position, share)
				cube.landed = true
				cube.landedAt = now
				cube.position = Vector3.new(at.X, cube.floor + cube.splat.Y / 2, at.Z)
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
			CFrame.new(cube.position.X, cube.floor + size.Y / 2, cube.position.Z) * cube.rotation
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
	--[[ A slime pressed against cover and struck from across it throws
	     from its struck face, inside that cover: the throw starts outside
	     any cover taller than it, or no ray could find that cover's side
	     and the cubes sank into it (`rg-slime`). ]]
	local arena = Workspace:FindFirstChild("Arena")
	local blockers = arena and arena:FindFirstChild("Blockers")
	if blockers then
		local taller: { CoverPush.Box } = {}
		for _, part in blockers:GetChildren() do
			if
				part:IsA("BasePart")
				and string.sub(part.Name, 1, 8) == "Obstacle"
				and part.Position.Y + part.Size.Y / 2 > at.Y - kind.size
			then
				table.insert(taller, {
					centre = Vector2.new(part.Position.X, part.Position.Z),
					half = Vector2.new(part.Size.X / 2, part.Size.Z / 2),
				})
			end
		end
		local reach = Vector2.one * (kind.size * (1 + settings.sizeJitter) / 2 + 0.05)
		local out = CoverPush.out(Vector2.new(at.X, at.Z), reach, taller)
		at = Vector3.new(out.X, at.Y, out.Y)
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
		local floor, wall = restOf(at, velocity, edge / 2)
		cube.floor = floor
		cube.wall = wall
		cube.start = at
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
	--[[ A low body's top can stand under the lowest a cube may start. `clamp`
	     errors on that, which lost the hit's whole spray. ]]
	local lowest = floorY() + kind.size
	local height = math.clamp(Balance.Projectile.height, lowest, math.max(lowest, top))
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
			floor = 0,
			wall = nil,
			start = Vector3.zero,
		})
	end
end

return SlimeResidue
