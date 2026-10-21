--!strict
--[[
	Authoritative projectile simulation.

	The server creates no parts for projectiles. It advances positions, raycasts
	the segment travelled each step, and applies damage. Clients render the
	flight themselves from the volley description — straight lines are exact
	from origin, direction, speed and time, so streaming positions would be pure
	waste.

	Everything that decides an outcome happens here. A client can render a
	projectile wherever it likes; it cannot make one deal damage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.forTag("Projectiles")

--[[ Ceiling on segment-walk iterations per projectile per step. The loop
     already decrements `remaining` by at least a hundredth of a stud each
     pass, so it cannot spin; this also bounds its raycast cost in one frame. ]]
local MAX_SEGMENT_STEPS = 8

type Projectile = {
	position: Vector3,
	direction: Vector3,
	speed: number,
	damage: number,
	--[[ Enemies left to pass through after the current one. 0 stops on first
	     contact. Raised by Piercing Shot in Phase 3. ]]
	pierce: number,
	expiresAt: number,
	--[[ Guards against a single projectile hitting the same enemy on
	     consecutive steps while it is still inside the hitbox. ]]
	hitModels: { [Model]: boolean },
}

local ProjectileSystem = {}

local active: { Projectile } = {}
local raycastParams: RaycastParams? = nil
local droppedThisRun = 0

--[[
	Rebuilt whenever the arena or enemy folder is recreated. Include-list rather
	than exclude-list so a stray part in Workspace can never block a shot.
]]
function ProjectileSystem.refreshFilter()
	local blockers = Arena.blockers()
	local enemyFolder = EnemyManager.folder()

	local instances: { Instance } = {}
	if blockers then
		table.insert(instances, blockers)
	end
	if enemyFolder then
		table.insert(instances, enemyFolder)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = instances
	params.IgnoreWater = true

	raycastParams = params
end

function ProjectileSystem.clear()
	table.clear(active)
	droppedThisRun = 0
end

function ProjectileSystem.activeCount(): number
	return #active
end

--[[
	Queues one projectile. Called once per spec in a volley by the firing
	system, never by anything a client can reach.
]]
function ProjectileSystem.spawn(
	origin: Vector3,
	direction: Vector3,
	speed: number,
	lifetime: number,
	damage: number,
	pierce: number,
	now: number
)
	if #active >= Balance.Projectile.maxActive then
		droppedThisRun += 1

		-- One line per hundred, so a runaway build is visible without spamming.
		if droppedThisRun % 100 == 1 then
			log.warn(
				"projectile cap of %d reached, dropped %d so far",
				Balance.Projectile.maxActive,
				droppedThisRun
			)
		end

		return
	end

	table.insert(active, {
		position = origin,
		direction = direction,
		speed = speed,
		damage = damage,
		pierce = pierce,
		expiresAt = now + lifetime,
		hitModels = {},
	})
end

--[[
	Walks a projectile along this step's segment, resolving every enemy it
	passes through in order rather than only the first. Without the loop a
	piercing shot at high speed would skip targets between frames.
]]
local function advance(projectile: Projectile, deltaTime: number, params: RaycastParams): boolean
	local remaining = projectile.speed * deltaTime
	local steps = 0

	while remaining > 1e-3 do
		steps += 1
		if steps > MAX_SEGMENT_STEPS then
			-- Out of budget, not out of life: it resumes on the next step.
			return true
		end

		local segment = projectile.direction * remaining
		local result = workspace:Raycast(projectile.position, segment, params)

		if not result then
			projectile.position += segment
			return true
		end

		local hitInstance = result.Instance
		local model = hitInstance:FindFirstAncestorOfClass("Model")

		-- A blocker, not an enemy: the arrow stops. Enemy projectiles will
		-- ignore these in Phase 2; the player's never do.
		if not model then
			return false
		end

		local travelled = (result.Position - projectile.position).Magnitude
		projectile.position = result.Position + projectile.direction * 1e-2
		remaining -= math.max(travelled, 1e-2)

		if projectile.hitModels[model] then
			continue
		end

		projectile.hitModels[model] = true
		EnemyManager.damage(model, projectile.damage, projectile.position)

		if projectile.pierce <= 0 then
			return false
		end

		projectile.pierce -= 1
	end

	return true
end

function ProjectileSystem.step(deltaTime: number, now: number)
	local params = raycastParams
	if not params or #active == 0 then
		return
	end

	-- Reverse iteration so removals do not skip entries.
	for index = #active, 1, -1 do
		local projectile = active[index]
		local alive = now < projectile.expiresAt

		if alive then
			alive = advance(projectile, deltaTime, params)
		end

		if not alive then
			local last = #active
			active[index] = active[last]
			active[last] = nil
		end
	end
end

return ProjectileSystem
