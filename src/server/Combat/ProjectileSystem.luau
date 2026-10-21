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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local Targeting = require(script.Parent.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)

type Faction = Types.Faction

local log = Log.forTag("Projectiles")

--[[ Ceiling on segment-walk iterations per projectile per step. The loop
     already decrements `remaining` by at least a hundredth of a stud each
     pass, so it cannot spin; this also bounds its raycast cost in one frame. ]]
local MAX_SEGMENT_STEPS = 8

local shotFired = Remotes.event(Remotes.ShotFired)
local explosion = Remotes.event(Remotes.Explosion)

--[[ Studs a reflected arrow is nudged off the surface it bounced from, so the
     next cast does not begin inside the wall it just left. ]]
local BOUNCE_CLEARANCE = 0.15

--[[ How far a chain shot looks for its next target. Generous — most of the
     room — because a chain that finds nothing is a card that did nothing. ]]
local CHAIN_RANGE = 22

--[[ `os.clock()` for the step currently running. Chain shots are created deep
     inside the hit path, which has no reason to be handed the time. ]]
local currentNow = 0

type Projectile = {
	--[[ Decides both what this can damage and what stops it. See
	     Types.Faction — the blocking asymmetry is load-bearing. ]]
	faction: Faction,
	position: Vector3,
	direction: Vector3,
	speed: number,
	damage: number,
	--[[ Enemies left to pass through after the current one. 0 stops on first
	     contact. Raised by Piercing Shot in Phase 3. ]]
	pierce: number,
	expiresAt: number,
	--[[
		Who fired it, or nil for an enemy shot.

		Carried on the projectile rather than looked up at impact, because by
		the time an arrow lands the player who fired it may have died, left, or
		started a new run — and XP for a kill belongs to the run that earned
		it. Single-player makes this look unnecessary; co-op is what it is for.
	]]
	owner: Player?,
	--[[ Rolled per contact, not per volley, so a piercing arrow can crit on
	     its second target and not its first. ]]
	critChance: number,
	critMultiplier: number,
	--[[ Studs of splash around a hit and the fraction of this arrow's damage
	     it deals. A radius of zero means no splash. ]]
	splashRadius: number,
	splashScale: number,
	--[[ Reflections off arena geometry left before this one dies. Spent, so a
	     projectile is its own counter. ]]
	bounces: number,
	--[[ Free arrows a kill by this one fires at whatever is nearest. ]]
	chainOnKill: number,
	--[[ Guards against a single projectile hitting the same enemy on
	     consecutive steps while it is still inside the hitbox. ]]
	hitModels: { [Model]: boolean },
}

local ProjectileSystem = {}

local active: { Projectile } = {}

--[[
	One filter per faction, because the two factions are stopped by different
	things. The player's shots are stopped by obstacles and hit enemies; enemy
	shots ignore obstacles entirely and hit players. Keeping these as separate
	include-lists means the asymmetry is a data difference rather than a branch
	inside the hit loop.
]]
local playerFilter: RaycastParams? = nil
local enemyFilter: RaycastParams? = nil

--[[ The same two include-lists again, for the overlap test that catches
     bodies a projectile is created inside. ]]
local playerOverlap: OverlapParams? = nil
local enemyOverlap: OverlapParams? = nil

--[[
	Cap-warning throttle. Counted since the last warning rather than since the
	server started, and gated on elapsed time, so the line fires once per
	incident however long the process has been up.
]]
local droppedSinceWarning = 0
local lastWarnedAt = -math.huge
local WARN_INTERVAL = 5

local function makeFilter(instances: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = instances
	params.IgnoreWater = true
	return params
end

local function makeOverlap(instances: { Instance }): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = instances
	return params
end

--[[
	Rebuilt whenever the arena, the enemy folder or a character is recreated.
	Include-lists rather than exclude-lists, so a stray part in Workspace can
	never block a shot.

	Note what is deliberately absent from the enemy filter: the arena blockers.
	An enemy projectile is not stopped by a pillar. That is the asymmetry the
	whole game rests on, and it lives here as an omission rather than as a
	special case somewhere hotter.
]]
function ProjectileSystem.refreshFilters()
	local blockers = Arena.blockers()
	local enemyFolder = EnemyManager.folder()

	local playerTargets: { Instance } = {}
	if blockers then
		table.insert(playerTargets, blockers)
	end
	if enemyFolder then
		table.insert(playerTargets, enemyFolder)
	end

	local enemyTargets: { Instance } = {}
	for _, session in RunSession.all() do
		local character = session.character
		if character then
			table.insert(enemyTargets, character)
		end
	end

	playerFilter = makeFilter(playerTargets)
	enemyFilter = makeFilter(enemyTargets)
	playerOverlap = makeOverlap(playerTargets)
	enemyOverlap = makeOverlap(enemyTargets)
end

--[[
	Drops every projectile still in the air.

	Called when a room is torn down. Without it an arrow fired at the last
	enemy of one room arrives in the next one, where it either hits nothing or
	hits whatever happens to be standing where its old target was — and an
	enemy volley crossing a room boundary would damage a player who never saw
	it fired.
]]
function ProjectileSystem.clear()
	table.clear(active)
	droppedSinceWarning = 0
	lastWarnedAt = -math.huge
end

--[[
	Queues one projectile. Called once per spec in a volley by the firing
	system, never by anything a client can reach.
]]
export type SpawnParams = {
	faction: Faction,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	lifetime: number,
	damage: number,
	pierce: number,
	critChance: number,
	critMultiplier: number,
	splashRadius: number,
	splashScale: number,
	bounces: number,
	chainOnKill: number,
	owner: Player?,
	now: number,
}

--[[
	Queues one projectile.

	Takes a table rather than a positional list: this grew to eleven fields as
	abilities arrived, and eleven positional arguments is a bug waiting for
	someone to swap two numbers of the same type.
]]
function ProjectileSystem.spawn(params: SpawnParams)
	local faction: Faction = params.faction
	local now = params.now
	if #active >= Balance.Projectile.maxActive then
		droppedSinceWarning += 1

		-- One line per interval, so a runaway build is visible without spamming.
		if now - lastWarnedAt >= WARN_INTERVAL then
			log.warn(
				"projectile cap of %d reached, dropped %d in the last %ds",
				Balance.Projectile.maxActive,
				droppedSinceWarning,
				WARN_INTERVAL
			)
			lastWarnedAt = now
			droppedSinceWarning = 0
		end

		return
	end

	table.insert(active, {
		faction = faction,
		position = params.origin,
		direction = params.direction,
		speed = params.speed,
		damage = params.damage,
		pierce = params.pierce,
		owner = params.owner,
		critChance = params.critChance,
		critMultiplier = params.critMultiplier,
		splashRadius = params.splashRadius,
		splashScale = params.splashScale,
		bounces = params.bounces,
		chainOnKill = params.chainOnKill,
		expiresAt = now + params.lifetime,
		hitModels = {},
	})
end

--[[
	Applies a projectile's damage to the model it reached, routed by faction.
	Returns whether anything was actually damaged, so the caller knows whether
	to spend pierce on the contact.

	Both branches stay server-authoritative: the damage amount comes off the
	projectile the server itself queued, never from anything a client said.
]]
--[[ Credits a kill to the run that fired the arrow, which may no longer be
     that player's current one. A session replaced since simply does not get
     it. ]]
local function creditXp(owner: Player?, xp: number)
	if xp <= 0 or not owner then
		return
	end

	local session = RunSession.get(owner)
	if session then
		--[[ The kill's rewards before its XP: levelling opens a card screen
		     and pauses the run, and a heal that landed after that would be
		     applied to a player already reading cards. ]]
		RunSession.onEnemyKilled(session)
		RunSession.awardXp(session, xp)
	end
end

--[[
	Damages everything standing near a hit.

	Snapshotted before anything is damaged, because killing an enemy removes
	it from the very table being iterated. The enemy that was hit directly is
	excluded rather than taking a second, smaller hit.
]]
local function applySplash(projectile: Projectile, centre: Vector3, damage: number, hit: Model)
	if projectile.splashRadius <= 0 or projectile.splashScale <= 0 then
		return
	end

	local splashDamage = damage * projectile.splashScale
	if splashDamage <= 0 then
		return
	end

	--[[ Announced before anything is damaged, so the blast is on screen in
	     the same frame as the damage numbers it caused rather than after
	     them. ]]
	explosion:FireAllClients(centre, projectile.splashRadius)

	local nearby: { { model: Model, position: Vector3 } } = {}
	for model, position in EnemyManager.positions() do
		if model ~= hit then
			table.insert(nearby, { model = model, position = position })
		end
	end

	local flatCentre = Vector3.new(centre.X, 0, centre.Z)

	for _, entry in nearby do
		local flat = Vector3.new(entry.position.X, 0, entry.position.Z)
		if (flat - flatCentre).Magnitude <= projectile.splashRadius then
			local _, xp = EnemyManager.damage(entry.model, splashDamage, centre)
			creditXp(projectile.owner, xp)
		end
	end
end

--[[
	Fires free arrows at whatever is nearest, when this one kills something.

	The chain shot carries no `chainOnKill` of its own. Without that, a kill
	that chains into a kill chains again and one arrow clears the room, which
	is a different game.

	Announced on the shot channel as *not predicted*: the client draws its own
	volleys and skips the server's copy of them, so a shot the server invented
	has to be marked as one the client has not already drawn.
]]
local function fireChain(projectile: Projectile, from: Vector3)
	if projectile.chainOnKill <= 0 then
		return
	end

	local target = Targeting.nearest(from, EnemyManager.positions(), CHAIN_RANGE)
	if not target then
		return
	end

	local direction = Targeting.flatDirection(from, target.position)
	if not direction then
		return
	end

	local specs: { Types.ShotSpec } = {}

	for _ = 1, projectile.chainOnKill do
		ProjectileSystem.spawn({
			faction = "Player" :: Faction,
			origin = from,
			direction = direction,
			speed = Balance.Projectile.speed,
			lifetime = Balance.Projectile.lifetime,
			damage = projectile.damage,
			pierce = 0,
			critChance = projectile.critChance,
			critMultiplier = projectile.critMultiplier,
			splashRadius = projectile.splashRadius,
			splashScale = projectile.splashScale,
			bounces = 0,
			chainOnKill = 0,
			owner = projectile.owner,
			now = currentNow,
		})

		table.insert(specs, {
			angleOffset = 0,
			lateralOffset = 0,
			damageScale = 1,
			speed = Balance.Projectile.speed,
			lifetime = Balance.Projectile.lifetime,
			pierce = 0,
			critChance = projectile.critChance,
			critMultiplier = projectile.critMultiplier,
			splashRadius = projectile.splashRadius,
			splashScale = projectile.splashScale,
			bounces = 0,
			chainOnKill = 0,
		})
	end

	local owner = projectile.owner

	shotFired:FireAllClients({
		faction = "Player" :: Faction,
		shooterId = if owner then owner.UserId else 0,
		origin = from,
		direction = direction,
		specs = specs,
		firedAt = currentNow,
		predicted = false,
	} :: Types.ShotEvent)
end

local function applyHit(projectile: Projectile, model: Model): boolean
	if projectile.faction == "Player" then
		--[[
			Crit is rolled here, at the moment of contact, which is the whole
			reason the OnHit bucket exists. Everything else a stage does is
			decided before the arrow is in the air; this cannot be, or a
			piercing arrow would crit on all of its targets or none.
		]]
		local damage = projectile.damage
		if projectile.critChance > 0 and math.random() < projectile.critChance then
			damage *= projectile.critMultiplier
		end

		--[[ Returned, not discarded. A model inside the enemy folder is not
		     necessarily a live enemy — it can be one killed earlier in this
		     same step — and an arrow that stopped dead on one of those looked
		     exactly like a hit that failed to register. ]]
		local landed, xp = EnemyManager.damage(model, damage, projectile.position)

		if landed then
			--[[ Splash before the chain, so an explosion that finishes a
			     second enemy has already happened by the time the chain looks
			     for what is nearest. ]]
			applySplash(projectile, projectile.position, damage, model)
		end

		if xp > 0 then
			creditXp(projectile.owner, xp)
			fireChain(projectile, projectile.position)
		end

		return landed
	end

	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return false
	end

	local session = RunSession.get(player)
	if not session then
		return false
	end

	RunSession.applyDamage(session, projectile.damage)
	return true
end

--[[
	The box the server sweeps: exactly the arrow the client draws.

	Width and length both come from config rather than being a server-side
	approximation, so there is one shape and both halves of the game agree on
	it. A sphere here meant only the arrow's nose could ever register a hit,
	which is what made shots along a visibly-connecting shaft do nothing.
]]
local function projectileSize(faction: Faction): Vector3
	--[[ Enemy shots are orbs, swept as the orb the player sees. A long arrow
	     box on something drawn as a ball would hit the player along a length
	     that is not on screen. ]]
	if faction == "Enemy" then
		return Vector3.one * Balance.Projectile.enemyOrbDiameter
	end

	local width = Balance.Projectile.radius * 2
	return Vector3.new(width, width, Balance.Projectile.length)
end

--[[ Centred on the projectile's position and pointed down its travel, which
     is how the client orients the drawn part. ]]
local function projectileCFrame(projectile: Projectile): CFrame
	return CFrame.lookAt(projectile.position, projectile.position + projectile.direction)
end

--[[
	Resolves everything the arrow is intersecting *right now*.

	This runs every step, not once at spawn, and it is the only reason hits
	land reliably. A shape cast ignores anything it already overlaps when it
	starts. Measured in Studio against the live arrow (0.7 x 0.7 x 4.2) with
	one frame of travel (0.93 studs at 56 studs/s), a target overlapping the
	box reports a clean miss at every depth tried — 0.1 studs, 0.6 studs, and
	dead centre. It then stays missed for as long as it is inside, because the
	box carries it along with it.

	So the arrow has a dead zone 2.1 studs deep in front of the simulated
	point, and nothing the sweep does can see into it.

	Static geometry cannot get in there: a pillar's gap to the arrow shrinks by
	exactly one frame of travel per frame, so the sweep always catches it on
	the way in. A *moving* target can, and routinely does — a Charger closes at
	63.5 studs/s against a sweep that only covers the arrow's own 0.93, so the
	gap can go from comfortably positive to deep inside the box between two
	frames. That is the whole bug, and this pass is the fix.

	Which is also why this only resolves models. Arena blockers are left to the
	sweep deliberately: the arrow's box straddles the shooter at spawn, so
	stopping on overlapped geometry here would kill every shot fired by a
	player standing with their back to a wall.

	Returns whether the projectile survives.
]]
local function resolveOverlaps(projectile: Projectile, overlap: OverlapParams): boolean
	--[[ Bounds, not exact geometry, so this is marginally generous at the
	     corners of a hitbox. That favours the player, which is the right way
	     for it to be wrong. ]]
	local touching = workspace:GetPartBoundsInBox(
		projectileCFrame(projectile),
		projectileSize(projectile.faction),
		overlap
	)

	for _, part in touching do
		local model = part:FindFirstAncestorOfClass("Model")

		if not model or projectile.hitModels[model] then
			continue
		end

		projectile.hitModels[model] = true

		if not applyHit(projectile, model) then
			continue
		end

		if projectile.pierce <= 0 then
			return false
		end

		projectile.pierce -= 1
	end

	return true
end

--[[
	Advances a projectile by one step.

	Two passes, and both are needed. `resolveOverlaps` handles everything the
	arrow is already touching, which the sweep is structurally blind to; the
	sweep below then covers the gap the arrow would otherwise tunnel across
	between frames. Neither one alone is sufficient.

	The sweep loops rather than taking the first hit so that a piercing shot at
	high speed resolves every target along the segment in order, instead of
	skipping the ones between frames.
]]
local function advance(
	projectile: Projectile,
	deltaTime: number,
	params: RaycastParams,
	overlap: OverlapParams
): boolean
	if not resolveOverlaps(projectile, overlap) then
		return false
	end

	local remaining = projectile.speed * deltaTime
	local steps = 0
	local size = projectileSize(projectile.faction)

	while remaining > 1e-3 do
		steps += 1
		if steps > MAX_SEGMENT_STEPS then
			-- Out of budget, not out of life: it resumes on the next step.
			return true
		end

		local segment = projectile.direction * remaining
		local result = workspace:Blockcast(projectileCFrame(projectile), size, segment, params)

		if not result then
			projectile.position += segment
			return true
		end

		local hitInstance = result.Instance
		local model = hitInstance:FindFirstAncestorOfClass("Model")

		--[[ Something in the filter with no Model above it is arena geometry,
		     which only ever appears in the player's filter. ]]
		if not model then
			if projectile.bounces <= 0 then
				return false
			end

			--[[
				Reflected and sent back out.

				Flattened to the floor plane afterwards. The arena's walls are
				vertical and its floor is not in the filter, so a reflection
				should never gain height — but a glancing hit on a corner can
				produce one, and an arrow that leaves the ground is an arrow
				that silently stops hitting anything.
			]]
			projectile.bounces -= 1

			local normal = result.Normal
			local reflected = projectile.direction - 2 * projectile.direction:Dot(normal) * normal
			local flat = Vector3.new(reflected.X, 0, reflected.Z)

			if flat.Magnitude < 1e-3 then
				return false
			end

			local travelledToWall = (result.Position - projectile.position).Magnitude
			projectile.direction = flat.Unit
			projectile.position = result.Position + projectile.direction * BOUNCE_CLEARANCE
			remaining -= math.max(travelledToWall, 1e-2)

			--[[ A bounced arrow is a new threat, so it may hit things it has
			     already passed through on the way out. ]]
			table.clear(projectile.hitModels)
			continue
		end

		local travelled = (result.Position - projectile.position).Magnitude
		projectile.position = result.Position + projectile.direction * 1e-2
		remaining -= math.max(travelled, 1e-2)

		if projectile.hitModels[model] then
			continue
		end

		projectile.hitModels[model] = true

		if not applyHit(projectile, model) then
			--[[ Nothing valid was there — a nested model inside a character,
			     say. Keep flying rather than spending pierce on it. ]]
			continue
		end

		if projectile.pierce <= 0 then
			return false
		end

		projectile.pierce -= 1
	end

	return true
end

function ProjectileSystem.step(deltaTime: number, now: number)
	currentNow = now

	if #active == 0 then
		return
	end

	-- Reverse iteration so removals do not skip entries.
	for index = #active, 1, -1 do
		local projectile = active[index]
		--[[ Picked per projectile, not per step: a volley can hold shots of
		     both factions at once. ]]
		local isPlayer = projectile.faction == "Player"
		local params = if isPlayer then playerFilter else enemyFilter
		local overlap = if isPlayer then playerOverlap else enemyOverlap

		local alive = params ~= nil and overlap ~= nil and now < projectile.expiresAt

		if alive and params and overlap then
			alive = advance(projectile, deltaTime, params, overlap)
		end

		if not alive then
			local last = #active
			active[index] = active[last]
			active[last] = nil
		end
	end
end

return ProjectileSystem
