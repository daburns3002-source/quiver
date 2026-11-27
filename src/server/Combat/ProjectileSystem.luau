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
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local SoulLink = require(script.Parent.SoulLink)
local Targeting = require(script.Parent.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)

type Faction = Types.Faction

local log = Log.forTag("Projectiles")

local shotFired = Remotes.event(Remotes.ShotFired)
local explosion = Remotes.event(Remotes.Explosion)
local upgradeFx = Remotes.event(Remotes.UpgradeFx)

--[[ Root Hold's roots are drawn as Stumpy's Root Snare is: the pet whose
     `Hold` piece `Fx/RootHoldFx` plays round a held enemy's feet. ]]
local ROOT_LOOK = "Stumpy"

--[[ `os.clock()` for the step currently running. Chain shots are created deep
     inside the hit path, which has no reason to be handed the time. ]]
local currentNow = 0

--[[ Gravity Well: each blast's pull, ticked in `step` until it ends. ]]
type Well = { at: Vector3, radius: number, speed: number, endsAt: number }
local wells: { Well } = {}

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
	--[[ The speed those ricochets leave at when it is not this one's own:
	     Chain Lightning's arc (`Balance.Projectile.arcSpeed`). ]]
	arcSpeed: number?,
	--[[ Radians a second it turns towards the nearest enemy ahead. ]]
	homing: number,
	--[[ Fraction of its damage a hit sets burning per second, and for how
	     long. ]]
	burn: number,
	burnDuration: number,
	--[[ What a hit slows its enemy to (1 none) and for how long: Elemental
	     Orbs' ice. ]]
	slow: number,
	slowDuration: number,
	--[[ Thornwood's cards: whether its slow is Web Snare's silk and its
	     splash a Thorn Burst, Root Hold's seconds and Burr Blight's stack
	     (0 none). ]]
	web: boolean,
	thorn: boolean,
	root: number,
	blight: number,
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
	--[[ Studs a struck player is pushed on along this line, away from the
	     shooter (`Balance.EnemyShot.push`, the Gust Shaman's gust). ]]
	push: number,
	--[[ Split Shot: splinters sent on from an enemy this kills (0 none). ]]
	split: number,
	--[[ Wind Arrows: extra knockback on a hit, as a share of the hit's own,
	     and enemy shots near it blown away (0 none). ]]
	gust: number,
	--[[ Split Orb: shards its first hit bursts it into (0 none, and spent
	     on that hit). Gravity Well: studs its blast pulls enemies in (0
	     none). ]]
	shards: number,
	well: number,
	--[[ Serpent Arrow's weave (`ProjectileFlight`). ]]
	weave: number?,
	weaveBase: Vector3?,
	weaveTravelled: number?,
	--[[ Trick Shot: extra damage, as a fraction, from its first bounce off
	     a wall on (0 none), and whether that bounce has come. ]]
	trick: number,
	tricked: boolean,
	--[[ Mana Burn: extra damage, as a fraction, against an enemy at full
	     health, less as its health falls (0 none). ]]
	healthy: number,
	--[[ The volley it is part of (when it was fired, os.clock), for a shot
	     of the player's own volley; nil for one the server invented. What
	     `onPlayerHit` hears of. ]]
	volley: number?,
}

local ProjectileSystem = {}

--[[ Called when a shot of a player's own volley lands on an enemy, with the
     shooter, what it hit, where, and which volley it was (its fire time):
     Pin Down, Serpent Arrow's bite, Siphon, Rune Circle and Arcane Tether
     act on it (`Combat/ClassUpgrades`). A hook rather than a require,
     because that module requires this one. Shots the server invented
     (splinters, shards, a ghost's copy) never call it. ]]
ProjectileSystem.onPlayerHit = nil :: ((Player, Model, Vector3, number) -> ())?

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
	table.clear(wells)
	droppedSinceWarning = 0
	lastWarnedAt = -math.huge
end

--[[ Removes every enemy shot within `radius` of `centre`, measured flat,
     and returns how many. For a revive: the volley that killed the player
     must not land again. ]]
function ProjectileSystem.clearEnemyShotsNear(centre: Vector3, radius: number): number
	local cleared = 0
	for index = #active, 1, -1 do
		local projectile = active[index]
		local offset = projectile.position - centre
		if
			projectile.faction == "Enemy"
			and Vector2.new(offset.X, offset.Z).Magnitude <= radius
		then
			active[index] = active[#active]
			active[#active] = nil
			cleared += 1
		end
	end
	return cleared
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
	--[[ Chain Lightning: its ricochets leave as arcs, at this speed. Omitted
	     means at the shot's own. ]]
	arcSpeed: number?,
	homing: number,
	owner: Player?,
	now: number,
	--[[ Seconds before it leaves. Omitted means at once. ]]
	delay: number?,
	--[[ Blaze's burn fraction and duration. Omitted means none. ]]
	burn: number?,
	burnDuration: number?,
	--[[ Elemental Orbs' ice: speed scale and seconds. Omitted means none. ]]
	slow: number?,
	slowDuration: number?,
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
	--[[ Studs a struck player is pushed on along this line
	     (`Balance.EnemyShot.push`). Omitted means none. ]]
	push: number?,
	--[[ Split Shot's splinters and Wind Arrows' gust (`Combat/ClassUpgrades`
	     `dress`). Omitted means none. ]]
	split: number?,
	gust: number?,
	--[[ Thornwood's cards (`dress` again). `web`: the slow on it is Web
	     Snare's silk, not a chill. `thorn`: its splash is a Thorn Burst, to
	     draw as one. `root`: Root Hold's seconds on what it hits. `blight`:
	     Burr Blight's stack, as a share of its damage. Omitted means none. ]]
	web: boolean?,
	thorn: boolean?,
	root: number?,
	blight: number?,
	--[[ Split Orb's shards and Gravity Well's pull (`dress` again). Omitted
	     means none. ]]
	shards: number?,
	well: number?,
	--[[ Serpent Arrow's weave, Trick Shot's bonus after a bounce and Mana
	     Burn's against a healthy enemy. Omitted means none. ]]
	weave: number?,
	trick: number?,
	healthy: number?,
	--[[ The volley this shot belongs to (its fire time), for a shot of the
	     player's own volley (`FiringSystem`). Omitted for an invented one. ]]
	volley: number?,
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
		arcSpeed = params.arcSpeed,
		homing = params.homing,
		burn = params.burn or 0,
		burnDuration = params.burnDuration or 0,
		slow = params.slow or 1,
		slowDuration = params.slowDuration or 0,
		web = params.web == true,
		thorn = params.thorn == true,
		root = params.root or 0,
		blight = params.blight or 0,
		farBonus = params.farBonus or 0,
		origin = params.origin,
		link = params.link or 0,
		look = params.look,
		reel = params.reel or 0,
		push = params.push or 0,
		split = params.split or 0,
		gust = params.gust or 0,
		shards = params.shards or 0,
		well = params.well or 0,
		weave = if params.weave and params.weave > 0 then params.weave else nil,
		weaveBase = if params.weave and params.weave > 0 then params.direction else nil,
		weaveTravelled = if params.weave and params.weave > 0 then 0 else nil,
		trick = params.trick or 0,
		tricked = false,
		healthy = params.healthy or 0,
		volley = params.volley,
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
	--[[ Thorn Burst: the same blast, drawn as thorns. ]]
	if projectile.thorn then
		upgradeFx:FireAllClients("ThornBurst", projectile.owner, centre, projectile.splashRadius)
	end
	--[[ Gravity Well: the blast pulls what is near it in, over a moment
	     (`step`), the card's studs in all. ]]
	if projectile.well > 0 then
		local well = Balance.Player.waveTwo.well
		table.insert(wells, {
			at = Vector3.new(centre.X, 0, centre.Z),
			radius = well.radius,
			speed = projectile.well / well.duration,
			endsAt = currentNow + well.duration,
		})
		upgradeFx:FireAllClients(
			"GravityWell",
			projectile.owner,
			centre,
			well.radius,
			well.duration
		)
	end

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
	--[[ Chain Lightning's arc: the enemy it was sent at, that it is drawn as
	     lightning between the two, and how long it lives
	     (`Balance.Projectile.arcLife`, not an arrow's life). ]]
	to: Model?,
	arc: boolean?,
	lifetime: number?,
}

local function fireOnward(projectile: Projectile, onward: Onward)
	local specs: { Types.ShotSpec } = {}
	local lifetime = onward.lifetime or Balance.Projectile.lifetime

	for _ = 1, onward.count do
		ProjectileSystem.spawn({
			faction = "Player" :: Faction,
			origin = onward.origin,
			direction = onward.direction,
			speed = onward.speed,
			lifetime = lifetime,
			damage = onward.damage,
			pierce = 0,
			critChance = projectile.critChance,
			critMultiplier = projectile.critMultiplier,
			splashRadius = projectile.splashRadius,
			splashScale = projectile.splashScale,
			bounces = 0,
			ricochet = onward.ricochet,
			arcSpeed = projectile.arcSpeed,
			homing = projectile.homing,
			burn = projectile.burn,
			burnDuration = projectile.burnDuration,
			slow = projectile.slow,
			slowDuration = projectile.slowDuration,
			web = projectile.web,
			blight = projectile.blight,
			farBonus = projectile.farBonus,
			link = projectile.link,
			look = projectile.look,
			owner = projectile.owner,
			now = currentNow,
			ignore = onward.from,
			split = projectile.split,
			gust = projectile.gust,
			well = projectile.well,
		})

		table.insert(specs, {
			angleOffset = 0,
			lateralOffset = 0,
			damageScale = 1,
			speed = onward.speed,
			lifetime = lifetime,
			pierce = 0,
			critChance = projectile.critChance,
			critMultiplier = projectile.critMultiplier,
			splashRadius = projectile.splashRadius,
			splashScale = projectile.splashScale,
			bounces = 0,
			ricochet = onward.ricochet,
			arcSpeed = projectile.arcSpeed,
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
		to = onward.to,
		arc = onward.arc,
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

	Chain Lightning's is an arc (`projectile.arcSpeed`): the same new shot, at
	a bolt's speed, so the hop lands a few hundredths of a second later, and
	the client is told the enemy it was sent at and draws lightning between
	the two bodies in place of a shot in flight.
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

	local arcSpeed = projectile.arcSpeed

	fireOnward(projectile, {
		origin = Vector3.new(from.X, from.Y, from.Z),
		direction = direction,
		count = 1,
		speed = arcSpeed or projectile.speed,
		damage = projectile.damage * Balance.Projectile.ricochetDamageScale,
		ricochet = projectile.ricochet - 1,
		from = hit,
		to = if arcSpeed then target.model else nil,
		arc = if arcSpeed then true else nil,
		lifetime = if arcSpeed then Balance.Projectile.arcLife else nil,
	})
end

--[[
	Split Shot: the arrow that killed sends splinters on from the kill, fanned
	about its heading, short and weak, and never splitting again. Announced as
	invented shots, so every client draws them (the "Splinter" look). Split
	Orb's shards are the same fan, from an orb's first hit ("Shard").
]]
type Fan = { spread: number, damage: number, range: number }

local function fireFan(
	projectile: Projectile,
	from: Model,
	count: number,
	config: Fan,
	look: string
)
	local direction = Vector3.new(projectile.direction.X, 0, projectile.direction.Z)
	if count <= 0 or direction.Magnitude < 1e-3 then
		return
	end
	direction = direction.Unit
	local origin = projectile.position
	local lifetime = config.range / math.max(projectile.speed, 1)
	local damage = projectile.damage * config.damage
	local specs: { Types.ShotSpec } = {}
	for index = 1, count do
		local spec: Types.ShotSpec = {
			angleOffset = (index - (count + 1) / 2) * config.spread,
			lateralOffset = 0,
			damageScale = config.damage,
			speed = projectile.speed,
			lifetime = lifetime,
			pierce = 0,
			critChance = projectile.critChance,
			critMultiplier = projectile.critMultiplier,
			splashRadius = 0,
			splashScale = 0,
			bounces = 0,
			ricochet = 0,
			homing = 0,
			delay = 0,
			burn = 0,
			burnDuration = 0,
			farBonus = 0,
			link = 0,
		}
		table.insert(specs, spec)
		ProjectileSystem.spawn({
			faction = "Player" :: Faction,
			origin = origin,
			direction = ShotPipeline.aim(direction, spec),
			speed = spec.speed,
			lifetime = lifetime,
			damage = damage,
			pierce = 0,
			critChance = spec.critChance,
			critMultiplier = spec.critMultiplier,
			splashRadius = 0,
			splashScale = 0,
			bounces = 0,
			ricochet = 0,
			homing = 0,
			look = look,
			owner = projectile.owner,
			now = currentNow,
			ignore = from,
		})
	end
	local owner = projectile.owner
	shotFired:FireAllClients({
		faction = "Player" :: Faction,
		shooterId = if owner then owner.UserId else 0,
		origin = origin,
		direction = direction,
		specs = specs,
		firedAt = currentNow,
		predicted = false,
		from = from,
		look = look,
	} :: Types.ShotEvent)
end

local function fireSplinters(projectile: Projectile, from: Model)
	fireFan(projectile, from, projectile.split, Balance.Player.splitShot, "Splinter")
end

--[[
	Riposte: a shot the Warden's swing guard caught flies back at whoever
	fired it -- the enemy nearest where it was fired, turning after it as
	Tracking Eye's arrows turn -- or straight back the way it came when none
	is near there. The Warden's own damage, at the card's share.
]]
local RIPOSTE_TURN = math.rad(240)

local function throwBack(projectile: Projectile, session: RunSession.Session)
	local config = Balance.Player.waveTwo.riposte
	local root = session.root
	local origin = if root
		then Vector3.new(root.Position.X, Balance.Projectile.height, root.Position.Z)
		else projectile.position
	local shooter: Vector3? = nil
	local nearest = config.seek
	for _, position in EnemyManager.positions() do
		local away = Vector3.new(
			position.X - projectile.origin.X,
			0,
			position.Z - projectile.origin.Z
		).Magnitude
		if away <= nearest then
			nearest = away
			shooter = position
		end
	end
	local heading = if shooter
		then Vector3.new(shooter.X - origin.X, 0, shooter.Z - origin.Z)
		else Vector3.new(-projectile.direction.X, 0, -projectile.direction.Z)
	if heading.Magnitude < 1e-3 then
		return
	end
	local direction = heading.Unit
	local speed = session.projectileSpeed * config.speed
	local lifetime = session.projectileLifetime
	local damage = session.damage * session.melee.riposte
	local spec: Types.ShotSpec = {
		angleOffset = 0,
		lateralOffset = 0,
		damageScale = 1,
		speed = speed,
		lifetime = lifetime,
		pierce = 0,
		critChance = 0,
		critMultiplier = 1,
		splashRadius = 0,
		splashScale = 0,
		bounces = 0,
		ricochet = 0,
		homing = RIPOSTE_TURN,
		delay = 0,
		burn = 0,
		burnDuration = 0,
		farBonus = 0,
		link = 0,
	}
	ProjectileSystem.spawn({
		faction = "Player" :: Faction,
		origin = origin,
		direction = direction,
		speed = speed,
		lifetime = lifetime,
		damage = damage,
		pierce = 0,
		critChance = 0,
		critMultiplier = 1,
		splashRadius = 0,
		splashScale = 0,
		bounces = 0,
		ricochet = 0,
		homing = RIPOSTE_TURN,
		look = "Riposte",
		owner = session.player,
		now = currentNow,
	})
	shotFired:FireAllClients({
		faction = "Player" :: Faction,
		shooterId = session.player.UserId,
		origin = origin,
		direction = direction,
		specs = { spec },
		firedAt = currentNow,
		predicted = false,
		look = "Riposte",
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

		--[[ Mana Burn: more the more health the enemy has left. ]]
		if projectile.healthy > 0 then
			local left = EnemyManager.healthFraction(model)
			if left then
				damage *= 1 + projectile.healthy * left
				if left >= 0.5 then
					upgradeFx:FireAllClients("ManaBurn", projectile.owner, projectile.position)
				end
			end
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
		--[[ `owner` says this is the player's own blow, which is what a
		     Deep Accord canopy shares out. ]]
		local landed, xp, fell =
			EnemyManager.damage(model, damage, projectile.position, kind, projectile.owner)

		if landed then
			--[[ Splash before the chain, so an explosion that finishes a
			     second enemy has already happened by the time the chain looks
			     for what is nearest. ]]
			applySplash(projectile, projectile.position, damage, model)
			--[[ Split Orb: its first hit bursts it into shards, fanned on
			     past what it hit; spent, so a piercing or chained orb
			     bursts once. ]]
			if projectile.shards > 0 then
				local shards = projectile.shards
				projectile.shards = 0
				fireFan(projectile, model, shards, Balance.Player.waveTwo.shard, "Shard")
			end
			SoulLink.apply(
				projectile.owner,
				projectile.link,
				model,
				projectile.position,
				damage,
				currentNow
			)
		end

		if xp > 0 then
			RunSession.creditKill(projectile.owner, xp, fell)
			fireSplinters(projectile, model)
		end

		--[[ Wind Arrows: the hit shoves harder. ]]
		if landed and projectile.gust > 0 then
			EnemyManager.knock(model, projectile.position - projectile.direction, projectile.gust)
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
			if projectile.slow < 1 then
				--[[ Web Snare's slow is silk, not ice: `WebbedUntil` for the
				     strands (`Fx/Upgrades/ThornwoodFx`), no chill. ]]
				EnemyManager.slow(
					model,
					projectile.slow,
					os.clock() + projectile.slowDuration,
					not projectile.web
				)
				if projectile.web then
					model:SetAttribute(
						"WebbedUntil",
						workspace:GetServerTimeNow() + projectile.slowDuration
					)
				end
			end
			--[[ Root Hold: held where it stands; a boss is slowed instead. ]]
			if projectile.root > 0 then
				if EnemyManager.isBoss(model) then
					EnemyManager.slow(
						model,
						Balance.Player.thornwood.root.boss,
						os.clock() + projectile.root
					)
				else
					EnemyManager.root(model, projectile.root, ROOT_LOOK)
				end
			end
			--[[ Burr Blight: another stack of poison, from the orb's base
			     damage as Blaze's burn is, spread over the stack's time. ]]
			if projectile.blight > 0 then
				local blight = Balance.Player.thornwood.blight
				Burning.bleed(model, {
					rate = projectile.damage * projectile.blight / blight.duration,
					stacks = blight.stacks,
					duration = blight.duration,
				}, projectile.owner, currentNow)
				model:SetAttribute("BlightedUntil", workspace:GetServerTimeNow() + blight.duration)
			end
			fireRicochet(projectile, model)
			--[[ The cards that act where the player's own shot landed. ]]
			local hook = ProjectileSystem.onPlayerHit
			local owner = projectile.owner
			local volley = projectile.volley
			if hook and owner and volley then
				hook(owner, model, projectile.position, volley)
			end
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
	--[[ Riposte: a shot the swing's guard catches is thrown back. ]]
	local caught = session.melee.riposte > 0 and session.alive and RunSession.guarding(session)
	RunSession.applyDamage(session, projectile.damage)
	if caught then
		throwBack(projectile, session)
	end
	--[[ A hook reels whoever it caught back along the line it flew, toward
	     the rod that cast it (`Balance.EnemyShot.reel`). Only on a hit that
	     landed: a dodge or a shield that took nothing was not caught, so
	     nothing drags. The client does the walking, so cover stops it. ]]
	if projectile.reel > 0 and session.alive and session.health < before then
		EnemyManager.shovePlayer(session, -projectile.direction, projectile.reel)
	end
	--[[ A gust pushes on along its line instead (`Balance.EnemyShot.push`). ]]
	if projectile.push > 0 and session.alive and session.health < before then
		EnemyManager.shovePlayer(session, projectile.direction, projectile.push)
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
	--[[ Trick Shot: the first bounce off a wall makes the shot hit harder. ]]
	onWall = function(
		flight: ProjectileFlight.Flight,
		position: Vector3,
		_normal: Vector3,
		bounced: boolean
	)
		local projectile = flight :: any
		if bounced and projectile.trick > 0 and not projectile.tricked then
			projectile.tricked = true
			projectile.damage *= 1 + projectile.trick
			upgradeFx:FireAllClients("TrickShot", projectile.owner, position)
		end
	end,
}

--[[ Gravity Well: each blast's pull, harder the nearer the middle as Black
     Hole's, until it ends. Ticked before anything else in `step`, which
     stops early when nothing is flying: the orb that opened a well has
     usually gone by then. ]]
local function pullWells(deltaTime: number, now: number)
	local well = Balance.Player.waveTwo.well
	for index = #wells, 1, -1 do
		local pulling = wells[index]
		if now >= pulling.endsAt then
			table.remove(wells, index)
			continue
		end
		for model, position in EnemyManager.positions() do
			local away =
				Vector3.new(position.X - pulling.at.X, 0, position.Z - pulling.at.Z).Magnitude
			if away <= pulling.radius then
				local pull = pulling.speed * (0.5 + 0.5 * (1 - away / pulling.radius))
				EnemyManager.pull(model, pulling.at, pull * deltaTime, well.stopAt)
			end
		end
	end
end

function ProjectileSystem.step(deltaTime: number, now: number)
	currentNow = now
	pullWells(deltaTime, now)

	if #active == 0 then
		return
	end

	--[[ Wind Arrows: where each gusting arrow is, its owner beside it, to
	     blow the enemy shots there away after the loop (removing them inside
	     it would move a shot already stepped back into the loop's way). ]]
	local gusts: { { at: Vector3, owner: Player? } } = {}

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

		if alive and projectile.gust > 0 then
			table.insert(gusts, { at = projectile.position, owner = projectile.owner })
		end

		if not alive then
			local last = #active
			active[index] = active[last]
			active[last] = nil
		end
	end

	local radius = Balance.Player.wind.clearRadius
	for _, gust in gusts do
		if ProjectileSystem.clearEnemyShotsNear(gust.at, radius) > 0 then
			upgradeFx:FireAllClients("Gust", gust.owner, gust.at, radius)
		end
	end
end

return ProjectileSystem
