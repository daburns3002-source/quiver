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
local Burning = require(script.Parent.Burning)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ProjectileFlight = require(ReplicatedStorage.Shared.Combat.ProjectileFlight)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local SoulLink = require(script.Parent.SoulLink)
local Targeting = require(script.Parent.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)

type Faction = Types.Faction

local log = Log.forTag("Projectiles")

local shotFired = Remotes.event(Remotes.ShotFired)
local explosion = Remotes.event(Remotes.Explosion)

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
	--[[ When it leaves. In the future only for Double Shot's copies, which
	     are queued with the volley and wait here rather than in a timer, so
	     clearing a room drops them along with everything already flying. ]]
	startsAt: number,
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
	--[[ Hits left that send it on to the nearest other enemy. ]]
	ricochet: number,
	--[[ Radians a second it turns towards the nearest enemy ahead. ]]
	homing: number,
	--[[ Fraction of its damage a hit sets burning per second, and for how
	     long. ]]
	burn: number,
	burnDuration: number,
	--[[ Long Shot's extra damage at full range, and where the flight began,
	     which is what "range" is measured from. ]]
	farBonus: number,
	origin: Vector3,
	--[[ Other enemies near a hit that share in it. Soul Chain. ]]
	link: number,
	--[[ How the shooter's class draws its shots (`Config/Classes.look`),
	     passed on to every shot it sends onward, or the Arcanist's chained
	     orbs are drawn as arrows and Chain Lightning's bolt never plays. ]]
	look: string?,
	--[[ Guards against a single projectile hitting the same enemy on
	     consecutive steps while it is still inside the hitbox. ]]
	hitModels: { [Model]: boolean },
	--[[ Studs a struck player is dragged back along this line. 0 for every
	     shot but the Hollow Fisherman's hook. ]]
	reel: number,
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

--[[ Removes every enemy shot within `radius` of `centre`, measured flat.
     For a revive: the volley that killed the player must not land again. ]]
function ProjectileSystem.clearEnemyShotsNear(centre: Vector3, radius: number)
	for index = #active, 1, -1 do
		local projectile = active[index]
		local offset = projectile.position - centre
		if
			projectile.faction == "Enemy"
			and Vector2.new(offset.X, offset.Z).Magnitude <= radius
		then
			active[index] = active[#active]
			active[#active] = nil
		end
	end
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
	ricochet: number,
	homing: number,
	owner: Player?,
	now: number,
	--[[ Seconds before it leaves. Omitted means at once. ]]
	delay: number?,
	--[[ Blaze's burn fraction and duration. Omitted means none. ]]
	burn: number?,
	burnDuration: number?,
	--[[ Long Shot and Soul Chain. Omitted means none. ]]
	farBonus: number?,
	link: number?,
	--[[ The shooter's class look. Omitted means the plain arrow. ]]
	look: string?,
	--[[ A body this projectile starts inside and must not strike: the enemy
	     a ricochet leaves from, which would otherwise be hit again by the
	     very first overlap pass. ]]
	ignore: Model?,
	--[[ Studs a struck player is dragged back along this projectile's own
	     line (`Balance.EnemyShot.reel`, the Hollow Fisherman's hook).
	     Omitted means none, which is every other shot. ]]
	reel: number?,
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
		ricochet = params.ricochet,
		homing = params.homing,
		burn = params.burn or 0,
		burnDuration = params.burnDuration or 0,
		farBonus = params.farBonus or 0,
		origin = params.origin,
		link = params.link or 0,
		look = params.look,
		reel = params.reel or 0,
		startsAt = now + (params.delay or 0),
		expiresAt = now + (params.delay or 0) + params.lifetime,
		hitModels = if params.ignore then { [params.ignore] = true } else {},
	})
end

--[[
	Applies a projectile's damage to the model it reached, routed by faction.
	Returns whether anything was actually damaged, so the caller knows whether
	to spend pierce on the contact.

	Both branches stay server-authoritative: the damage amount comes off the
	projectile the server itself queued, never from anything a client said.
]]
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
			local _, xp, fell = EnemyManager.damage(entry.model, splashDamage, centre)
			RunSession.creditKill(projectile.owner, xp, fell)
		end
	end
end

--[[
	Launches arrows the server invented — a ricochet off a hit — and tells
	every client to draw them.

	Announced on the shot channel as *not predicted*: the client draws its own
	volleys and skips the server's copy of them, so a shot the server invented
	has to be marked as one the client has not already drawn. `from` goes with
	it, so the drawn arrow ignores the body it leaves just as this one does.
]]
type Onward = {
	origin: Vector3,
	direction: Vector3,
	count: number,
	speed: number,
	damage: number,
	ricochet: number,
	from: Model?,
}

local function fireOnward(projectile: Projectile, onward: Onward)
	local specs: { Types.ShotSpec } = {}

	for _ = 1, onward.count do
		ProjectileSystem.spawn({
			faction = "Player" :: Faction,
			origin = onward.origin,
			direction = onward.direction,
			speed = onward.speed,
			lifetime = Balance.Projectile.lifetime,
			damage = onward.damage,
			pierce = 0,
			critChance = projectile.critChance,
			critMultiplier = projectile.critMultiplier,
			splashRadius = projectile.splashRadius,
			splashScale = projectile.splashScale,
			bounces = 0,
			ricochet = onward.ricochet,
			homing = projectile.homing,
			burn = projectile.burn,
			burnDuration = projectile.burnDuration,
			farBonus = projectile.farBonus,
			link = projectile.link,
			look = projectile.look,
			owner = projectile.owner,
			now = currentNow,
			ignore = onward.from,
		})

		table.insert(specs, {
			angleOffset = 0,
			lateralOffset = 0,
			damageScale = 1,
			speed = onward.speed,
			lifetime = Balance.Projectile.lifetime,
			pierce = 0,
			critChance = projectile.critChance,
			critMultiplier = projectile.critMultiplier,
			splashRadius = projectile.splashRadius,
			splashScale = projectile.splashScale,
			bounces = 0,
			ricochet = onward.ricochet,
			homing = projectile.homing,
			delay = 0,
			burn = projectile.burn,
			burnDuration = projectile.burnDuration,
			farBonus = projectile.farBonus,
			link = projectile.link,
		})
	end

	local owner = projectile.owner

	shotFired:FireAllClients({
		faction = "Player" :: Faction,
		shooterId = if owner then owner.UserId else 0,
		origin = onward.origin,
		direction = onward.direction,
		specs = specs,
		firedAt = currentNow,
		predicted = false,
		from = onward.from,
		look = projectile.look,
	} :: Types.ShotEvent)
end

--[[
	Sends the arrow on from the enemy it just hit to the nearest one it has
	not, which is Archero 2's Ricochet.

	Not a turn in mid-air but a new arrow from the point of contact: the one
	that hit stops there as any arrow does, and the client is told about the
	new one the way it is told about a chain. Every body this arrow has struck
	is skipped, so a ricochet never bounces straight back.
]]
local function fireRicochet(projectile: Projectile, hit: Model)
	if projectile.ricochet <= 0 then
		return
	end

	local from = projectile.position
	local candidates: { [Model]: Vector3 } = {}

	for model, position in EnemyManager.positions() do
		if model ~= hit and not projectile.hitModels[model] then
			candidates[model] = position
		end
	end

	local target = Targeting.nearest(from, candidates, Balance.Projectile.ricochetRange)
	if not target then
		return
	end

	local direction = Targeting.flatDirection(from, target.position)
	if not direction then
		return
	end

	fireOnward(projectile, {
		origin = Vector3.new(from.X, from.Y, from.Z),
		direction = direction,
		count = 1,
		speed = projectile.speed,
		damage = projectile.damage * Balance.Projectile.ricochetDamageScale,
		ricochet = projectile.ricochet - 1,
		from = hit,
	})
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

		--[[ Long Shot: more for a longer flight, rising evenly to its full
		     bonus at `farRange`. Measured flat from where this arrow began,
		     so a ricochet's range starts at the enemy it left. ]]
		if projectile.farBonus > 0 then
			local flown = Vector3.new(
				projectile.position.X - projectile.origin.X,
				0,
				projectile.position.Z - projectile.origin.Z
			).Magnitude
			local reach = math.clamp(flown / Balance.Projectile.farRange, 0, 1)
			damage *= 1 + projectile.farBonus * reach
		end

		local kind: Types.HitKind = "Hit"
		if projectile.critChance > 0 and math.random() < projectile.critChance then
			damage *= projectile.critMultiplier
			kind = "Crit"
		end

		--[[ Returned, not discarded. A model inside the enemy folder is not
		     necessarily a live enemy — it can be one killed earlier in this
		     same step — and an arrow that stopped dead on one of those looked
		     exactly like a hit that failed to register. ]]
		local landed, xp, fell = EnemyManager.damage(model, damage, projectile.position, kind)

		if landed then
			--[[ Splash before the chain, so an explosion that finishes a
			     second enemy has already happened by the time the chain looks
			     for what is nearest. ]]
			applySplash(projectile, projectile.position, damage, model)
			SoulLink.apply(projectile.owner, projectile.link, model, projectile.position, damage)
		end

		if xp > 0 then
			RunSession.creditKill(projectile.owner, xp, fell)
		end

		if landed then
			--[[ From the arrow's base damage, not a crit: Blaze is a bonus on
			     the hit, and a crit that also doubled the burn would make
			     two abilities one. ]]
			Burning.ignite(
				model,
				projectile.damage * projectile.burn,
				projectile.burnDuration,
				projectile.owner,
				currentNow
			)
			fireRicochet(projectile, model)
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

	local before = session.health
	RunSession.applyDamage(session, projectile.damage)
	--[[ A hook reels whoever it caught back along the line it flew, toward
	     the rod that cast it (`Balance.EnemyShot.reel`). Only on a hit that
	     landed: a dodge or a shield that took nothing was not caught, so
	     nothing drags. The client does the walking, so cover stops it. ]]
	if projectile.reel > 0 and session.alive and session.health < before then
		EnemyManager.shovePlayer(session, -projectile.direction, projectile.reel)
	end
	return true
end

--[[ How the shared flight reaches this side's outcomes. One table for every
     projectile, rather than a closure per projectile per frame. ]]
local contact: ProjectileFlight.Contact = {
	onModel = function(flight: ProjectileFlight.Flight, model: Model): boolean
		return applyHit(flight :: any, model)
	end,
	seek = function(flight: ProjectileFlight.Flight): Vector3?
		return ProjectileFlight.seekAhead(flight, EnemyManager.positions())
	end,
}

function ProjectileSystem.step(deltaTime: number, now: number)
	currentNow = now

	if #active == 0 then
		return
	end

	-- Reverse iteration so removals do not skip entries.
	for index = #active, 1, -1 do
		local projectile = active[index]
		--[[ Gone already: a hit earlier in this step can revive a player,
		     which clears the enemy shots round them and shortens the list
		     (2026-10-25 playtest: "attempt to index nil with 'faction'"). ]]
		if not projectile then
			continue
		end
		--[[ Picked per projectile, not per step: a volley can hold shots of
		     both factions at once. ]]
		local isPlayer = projectile.faction == "Player"
		local params = if isPlayer then playerFilter else enemyFilter
		local overlap = if isPlayer then playerOverlap else enemyOverlap

		--[[ Queued but not yet fired: it neither moves nor hits anything,
		     and it must not be culled as if it had expired. ]]
		if now < projectile.startsAt then
			continue
		end

		local alive = params ~= nil and overlap ~= nil and now < projectile.expiresAt

		if alive and params and overlap then
			alive = ProjectileFlight.advance(projectile, deltaTime, params, overlap, contact)
		end

		if not alive then
			local last = #active
			active[index] = active[last]
			active[last] = nil
		end
	end
end

return ProjectileSystem
