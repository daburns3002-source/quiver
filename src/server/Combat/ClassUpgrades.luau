--!strict
--[[
	The class upgrades the owner picked on 2026-10-27
	(docs/UPGRADES-BRAINSTORM.md, `Config/Abilities`): the build-defining
	cards that act beside the shot rather than inside it.

	- Phoenix Arrow (Ranger, Mythic): every 8th volley a phoenix flies
	  through every enemy to the wall, leaving burning ground behind it.
	- Rain of Arrows (Ranger, Legendary): every 6th volley an arrow goes up
	  and a rain of them falls on the target's area.
	- Black Hole (Arcanist, Mythic): every 7th cast a black orb opens a hole
	  at the target that drags enemies in, then implodes.
	- Elemental Orbs (Arcanist, Epic): casts cycle fire, ice and lightning.
	- Arcane Turret (Arcanist, Legendary): every 10 s a crystal hovers beside
	  the Arcanist and casts orbs of its own.
	- Titan's Grip (Warden, Mythic): the swing itself is grown in
	  `Combat/MeleeSystem` (`MeleeStats.reachScale`); here, the slam's shake.
	- Counter Strike (Warden, Epic): a hit taken charges the next blow.

	The class cards of 2026-11-13 (owner's pick C):
	- Sniper Shot (Ranger, Rare): standing still readies a sniper arrow,
	  fired with the next volley, through everything, always a crit.
	- Split Shot (Ranger, Epic) and Wind Arrows (Ranger, Uncommon): put on
	  each arrow here (`dress`), resolved in `Combat/ProjectileSystem`.
	- Mana Surge (Arcanist, Rare): a kill (`RunSession.onEnemyKilled`)
	  charges the next cast, spent here (`spendSurge`).
	- Frost Orb (Arcanist, Uncommon): put on each orb here (`dress`).
	- Shield Throw (Warden, Rare): the dash throws a shield that hops
	  enemy to enemy (`onDash`).
	- Blade Storm (Warden, Legendary): every 5th blow that lands throws the
	  sword out and back (`afterBlow`).
	Arcane Shield and Sunder live where they act (`RunSession.applyDamage`,
	`EnemyManager.sunder`).

	Each reads its level from the session (`AbilityEffects.ServerStats`), so
	nothing here asks for a card by name; the counters and timers live here,
	per session. Server-authoritative like every other hit: damage goes
	through `EnemyManager.damage` and kills are credited to the owner. The
	clients only draw: `Remotes.UpgradeFx` and the player's attributes
	(`OrbElement`, `TurretUntil`, `CounterReady`, `CounterAt`) feed
	`Fx/Upgrades/*BuildFx`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Aim = require(ReplicatedStorage.Shared.Combat.Aim)
local AreaStrikes = require(script.Parent.AreaStrikes)
local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local ProjectileSystem = require(script.Parent.ProjectileSystem)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local Targeting = require(script.Parent.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)

type Session = RunSession.Session

local ClassUpgrades = {}

local upgradeFx = Remotes.event(Remotes.UpgradeFx)
local shotFired = Remotes.event(Remotes.ShotFired)

--[[ Elemental Orbs' cycle, in the order the owner named it. ]]
local ELEMENTS = { "Fire", "Ice", "Lightning" }

--[[ A gap between steps longer than this is the world standing still
     behind a card screen; none of it may count (as `AreaStrikes`). ]]
local PAUSE = 0.25

type State = {
	--[[ Volleys (casts) fired this run, for the every-nth cards. ]]
	volleys: number,
	--[[ Elemental Orbs: the next cast's place in `ELEMENTS`, and the one
	     last published on the player. ]]
	element: number,
	shownElement: string?,
	--[[ Counter Strike: a hit has charged the next blow. ]]
	counterReady: boolean,
	--[[ Arcane Turret: when the next crystal appears, when the one up goes,
	     and when it casts next (os.clock); nil before the first fight. ]]
	turretNextAt: number?,
	turretUntil: number,
	turretCastAt: number,
	--[[ Sniper Shot: when the last sniper arrow left (os.clock), and
	     whether one is ready, as last published. ]]
	sniperAt: number,
	sniperShown: boolean,
	--[[ Blade Storm: blows landed this run. ]]
	blows: number,
}

local states: { [Session]: State } = setmetatable({}, { __mode = "k" }) :: any

--[[ A black hole on its way or open. ]]
type Hole = {
	session: Session,
	at: Vector3,
	opensAt: number,
	endsAt: number,
	tickAt: number,
}
local holes: { Hole } = {}

--[[ A patch of the phoenix's fire, dropped as the phoenix passes. ]]
type Ember = { session: Session, at: Vector3, dropAt: number }
local embers: { Ember } = {}

--[[ One hop of a thrown shield: the enemy it was sent at, where the
     shield came from, and when it arrives. ]]
type Hop = {
	session: Session,
	model: Model,
	from: Vector3,
	hitAt: number,
}
local hops: { Hop } = {}

--[[ A sword thrown by Blade Storm: where from, which way, how far, when,
     and what each pass has already struck. ]]
type Blade = {
	session: Session,
	origin: Vector3,
	direction: Vector3,
	length: number,
	startsAt: number,
	struckOut: { [Model]: boolean },
	struckBack: { [Model]: boolean },
}
local blades: { Blade } = {}

local lastStep: number? = nil

local function state(session: Session): State
	local existing = states[session]
	if existing then
		return existing
	end
	local fresh: State = {
		volleys = 0,
		element = 1,
		shownElement = nil,
		counterReady = false,
		turretNextAt = nil,
		turretUntil = 0,
		turretCastAt = 0,
		sniperAt = -math.huge,
		sniperShown = false,
		blows = 0,
	}
	states[session] = fresh
	return fresh
end

local function serverIn(seconds: number): number
	return Workspace:GetServerTimeNow() + seconds
end

--[[ A plain projectile's spec, for a shot the server invents and the
     clients draw from `ShotFired`. ]]
local function plainSpec(speed: number, lifetime: number, pierce: number): Types.ShotSpec
	return {
		angleOffset = 0,
		lateralOffset = 0,
		damageScale = 1,
		speed = speed,
		lifetime = lifetime,
		pierce = pierce,
		critChance = 0,
		critMultiplier = 1,
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
end

--[[ Fires one invented shot for `session` and tells every client to draw
     it (not predicted: no client drew it already). ]]
local function invent(
	session: Session,
	origin: Vector3,
	direction: Vector3,
	spec: Types.ShotSpec,
	damage: number,
	look: string,
	now: number
)
	ProjectileSystem.spawn({
		faction = "Player" :: Types.Faction,
		origin = origin,
		direction = direction,
		speed = spec.speed,
		lifetime = spec.lifetime,
		damage = damage,
		pierce = spec.pierce,
		critChance = spec.critChance,
		critMultiplier = spec.critMultiplier,
		splashRadius = 0,
		splashScale = 0,
		bounces = 0,
		ricochet = 0,
		homing = 0,
		look = look,
		owner = session.player,
		now = now,
	})
	shotFired:FireAllClients({
		faction = "Player" :: Types.Faction,
		shooterId = session.player.UserId,
		origin = origin,
		direction = direction,
		specs = { spec },
		firedAt = now,
		look = look,
		predicted = false,
	} :: Types.ShotEvent)
end

--[[ Everything within `radius` of `at` (to the edge of each body) takes
     `damage`, knocked away from `from` when given. ]]
local function hitWithin(
	session: Session,
	at: Vector3,
	radius: number,
	damage: number,
	from: Vector3?
)
	for model, position in EnemyManager.positions() do
		local body = model.PrimaryPart
		local half = if body then math.max(body.Size.X, body.Size.Z) / 2 else 1
		local away = Vector3.new(position.X - at.X, 0, position.Z - at.Z).Magnitude
		if away <= radius + half then
			local _, xp, fell = EnemyManager.damage(model, damage, from)
			RunSession.creditKill(session.player, xp, fell)
		end
	end
end

--[[ How far a shot from `origin` along `direction` flies before a wall or
     the arena's cover stops it, up to `most` studs. ]]
local function flightLength(origin: Vector3, direction: Vector3, most: number): number
	local half = Arena.halfSize()
	local length = most
	-- the room's outer walls (the arena is centred on the origin)
	if math.abs(direction.X) > 1e-4 then
		local edge = if direction.X > 0 then half.X else -half.X
		length = math.min(length, math.max(0, (edge - origin.X) / direction.X))
	end
	if math.abs(direction.Z) > 1e-4 then
		local edge = if direction.Z > 0 then half.Y else -half.Y
		length = math.min(length, math.max(0, (edge - origin.Z) / direction.Z))
	end
	-- the cover arrows stop at
	local blockers = Arena.blockers()
	if blockers then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { blockers }
		local hit = Workspace:Raycast(origin, direction * length, params)
		if hit then
			length = math.min(length, hit.Distance)
		end
	end
	return length
end

--[[ Phoenix Arrow: the phoenix itself, and its fire dropped along its
     path as it passes. ]]
local function phoenix(session: Session, origin: Vector3, direction: Vector3, now: number)
	local config = Balance.Player.phoenix
	local length = flightLength(origin, direction, Balance.Player.attackRange * 2)
	if length < 1 then
		return
	end
	local spec = plainSpec(config.speed, length / config.speed, math.huge)
	invent(session, origin, direction, spec, session.damage * config.damage, "Phoenix", now)
	local along = config.trailStep / 2
	while along <= length do
		table.insert(embers, {
			session = session,
			at = origin + direction * along,
			dropAt = now + along / config.speed,
		})
		along += config.trailStep
	end
end

--[[ Sniper Shot: ready once the player has stood still `charge` seconds
     and as long again since the last sniper arrow. ]]
local function sniperReady(session: Session, own: State, now: number): boolean
	local still = session.stationarySince
	if session.upgrades.sniper <= 0 or not still then
		return false
	end
	return now - math.max(still, own.sniperAt) >= Balance.Player.sniper.charge
end

--[[ Sniper Shot: a fast arrow through every enemy to the wall, always a
     crit, drawn by every client in its own look. ]]
local function sniper(
	session: Session,
	own: State,
	origin: Vector3,
	direction: Vector3,
	now: number
)
	local config = Balance.Player.sniper
	own.sniperAt = now
	local speed = session.projectileSpeed * config.speedScale
	local length = flightLength(origin, direction, Balance.Player.attackRange * 2)
	if length < 1 then
		return
	end
	local spec = plainSpec(speed, length / speed, math.huge)
	spec.critChance = 1
	spec.critMultiplier = Balance.Player.critMultiplier
	invent(session, origin, direction, spec, session.damage * config.damage, "Sniper", now)
end

--[[ Rain of Arrows: one arrow up from the bow, and a rain on the target's
     area, each arrow its own small blast. The clients draw the whole rain
     from one event. ]]
local function rain(session: Session, origin: Vector3, target: Vector3, now: number)
	local config = Balance.Player.arrowRain
	local points: { Vector3 } = {}
	for index = 1, config.arrows do
		local angle = session.random:NextNumber() * math.pi * 2
		local distance = config.radius * math.sqrt(session.random:NextNumber())
		local point = Arena.clampToWalls(
			Vector3.new(
				target.X + math.cos(angle) * distance,
				0,
				target.Z + math.sin(angle) * distance
			),
			0.5
		)
		table.insert(points, point)
		AreaStrikes.strike({
			owner = session.player,
			at = point,
			radius = config.arrowRadius,
			damage = session.damage * config.damage,
			delay = config.delay + (index - 1) * config.stagger,
			now = now,
		})
	end
	upgradeFx:FireAllClients(
		"ArrowRain",
		session.player,
		origin,
		Vector3.new(target.X, 0, target.Z),
		points,
		config.delay,
		config.stagger,
		config.radius
	)
end

--[[ Black Hole: the black orb flies to the target at the cast's speed and
     the hole opens where it arrives. ]]
local function blackHole(session: Session, origin: Vector3, target: Vector3, now: number)
	local config = Balance.Player.blackHole
	local at = Vector3.new(target.X, 0, target.Z)
	local flight = Vector3.new(at.X - origin.X, 0, at.Z - origin.Z).Magnitude
		/ math.max(session.projectileSpeed, 1)
	table.insert(holes, {
		session = session,
		at = at,
		opensAt = now + flight,
		endsAt = now + flight + config.duration,
		tickAt = now + flight + config.tickEvery,
	})
	upgradeFx:FireAllClients(
		"BlackHole",
		session.player,
		origin,
		at,
		flight,
		config.duration,
		config.pullRadius
	)
end

--[[
	After a ranged volley (`FiringSystem`): counts it, and fires whichever
	every-nth upgrades it completes. `origin` is where the shot left from,
	`direction` its flat aim, `target` the enemy's position.
]]
function ClassUpgrades.afterVolley(
	session: Session,
	origin: Vector3,
	direction: Vector3,
	target: Vector3,
	now: number
)
	local held = session.upgrades
	if
		held.phoenix <= 0
		and held.arrowRain <= 0
		and held.blackHole <= 0
		and held.elemental <= 0
		and held.sniper <= 0
	then
		return
	end
	local own = state(session)
	own.volleys += 1
	if sniperReady(session, own, now) then
		sniper(session, own, origin, direction, now)
	end
	if held.phoenix > 0 and own.volleys % Balance.Player.phoenix.every == 0 then
		phoenix(session, origin, direction, now)
	end
	if held.arrowRain > 0 and own.volleys % Balance.Player.arrowRain.every == 0 then
		rain(session, origin, target, now)
	end
	if held.blackHole > 0 and own.volleys % Balance.Player.blackHole.every == 0 then
		blackHole(session, origin, target, now)
	end
	if held.elemental > 0 then
		own.element = own.element % #ELEMENTS + 1
		own.shownElement = ELEMENTS[own.element]
		session.player:SetAttribute("OrbElement", own.shownElement)
	end
end

--[[ What an element does to an orb about to be spawned. Fire burns, ice
     slows, and lightning chains on as arcs: bolts between the enemies, as
     Chain Lightning's are, not an orb bouncing on (owner, 2026-11-12). Apart
     from `dress` so `tests/ChainSoulFx.spec` can hold each element to its
     own. ]]
function ClassUpgrades.dressAs(element: string, params: ProjectileSystem.SpawnParams)
	local config = Balance.Player.elemental
	if element == "Fire" then
		params.burn = math.max(params.burn or 0, config.burn)
		params.burnDuration = math.max(params.burnDuration or 0, config.burnDuration)
	elseif element == "Ice" then
		params.slow = math.min(params.slow or 1, config.slow)
		params.slowDuration = math.max(params.slowDuration or 0, config.slowDuration)
	else
		params.ricochet += config.chain
		params.arcSpeed = Balance.Projectile.arcSpeed
	end
end

--[[ What the cards put on each projectile of a volley before it is
     spawned: Split Shot's splinters, Wind Arrows' gust, Frost Orb's chill,
     then Elemental Orbs' element. Nothing without the cards. ]]
function ClassUpgrades.dress(session: Session, params: ProjectileSystem.SpawnParams)
	local held = session.upgrades
	if held.splitShot > 0 then
		params.split = Balance.Player.splitShot.count
	end
	if held.wind > 0 then
		params.gust = held.wind
	end
	if held.frost > 0 then
		params.slow = math.min(params.slow or 1, 1 - held.frost)
		params.slowDuration = math.max(params.slowDuration or 0, Balance.Player.frost.duration)
	end
	if held.elemental > 0 then
		ClassUpgrades.dressAs(ELEMENTS[state(session).element], params)
	end
end

--[[ Mana Surge: the charge a kill left, spent on the cast going now. The
     cast's damage and blast scales; 1, 1 with no charge. ]]
function ClassUpgrades.spendSurge(session: Session): (number, number)
	if not session.surgeReady then
		return 1, 1
	end
	session.surgeReady = false
	session.player:SetAttribute("ManaSurge", false)
	if session.upgrades.manaSurge <= 0 then
		return 1, 1
	end
	local config = Balance.Player.manaSurge
	return config.damage, config.size
end

--[[ Shield Throw: a dash the server accepted (`Main`'s `DashStarted`).
     The shield goes to the nearest enemy in range, then on to the nearest
     not yet struck, each hop landing as it arrives; every client draws the
     whole flight, and the shield home, from one event. ]]
function ClassUpgrades.onDash(session: Session, root: BasePart, now: number)
	if session.upgrades.shieldThrow <= 0 then
		return
	end
	local config = Balance.Player.shieldThrow
	local start = Vector3.new(root.Position.X, 0, root.Position.Z)
	local from = start
	local struck: { [Model]: boolean } = {}
	local points: { Vector3 } = {}
	local times: { number } = {}
	local elapsed = 0
	for index = 1, config.hits do
		local candidates: { [Model]: Vector3 } = {}
		for model, position in EnemyManager.positions() do
			if not struck[model] then
				candidates[model] = position
			end
		end
		local reach = if index == 1 then config.range else config.hopRange
		local target = Targeting.nearest(from, candidates, reach)
		if not target then
			break
		end
		local at = Vector3.new(target.position.X, 0, target.position.Z)
		elapsed += (at - from).Magnitude / config.speed
		struck[target.model] = true
		table.insert(hops, {
			session = session,
			model = target.model,
			from = from,
			hitAt = now + elapsed,
		})
		table.insert(points, at)
		table.insert(times, elapsed)
		from = at
	end
	if #points == 0 then
		return
	end
	upgradeFx:FireAllClients("ShieldThrow", session.player, start, points, times, config.speed)
end

--[[ Blade Storm: a blow landed (`Combat/MeleeSystem`); every `every`th
     throws the sword along the swing and back. ]]
function ClassUpgrades.afterBlow(session: Session, origin: Vector3, direction: Vector3, now: number)
	if session.upgrades.bladeStorm <= 0 then
		return
	end
	local config = Balance.Player.bladeStorm
	local own = state(session)
	own.blows += 1
	if own.blows % config.every ~= 0 then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	flat = flat.Unit
	local start = Vector3.new(origin.X, 0, origin.Z)
	local length = flightLength(Aim.shotOrigin(origin), flat, config.length)
	if length < 2 then
		return
	end
	table.insert(blades, {
		session = session,
		origin = start,
		direction = flat,
		length = length,
		startsAt = now,
		struckOut = {},
		struckBack = {},
	})
	upgradeFx:FireAllClients("BladeStorm", session.player, start, flat, length, config.duration)
end

--[[ Counter Strike: a hit really landed on the player (`RunSession.onHurt`). ]]
function ClassUpgrades.onHurt(session: Session)
	if session.melee.counterStrike <= 0 then
		return
	end
	state(session).counterReady = true
	session.player:SetAttribute("CounterReady", true)
end

--[[ Counter Strike: the multiplier on the blow landing now, spending the
     charge; 1 when there is none. ]]
function ClassUpgrades.spendCounter(session: Session): number
	local own = states[session]
	if not own or not own.counterReady or session.melee.counterStrike <= 0 then
		return 1
	end
	own.counterReady = false
	session.player:SetAttribute("CounterReady", false)
	session.player:SetAttribute("CounterAt", Workspace:GetServerTimeNow())
	return session.melee.counterStrike
end

--[[ Titan's Grip: a slam landed `radius` wide at `centre`; with the giant
     sword, every client shakes and draws it. ]]
function ClassUpgrades.slammed(session: Session, centre: Vector3, radius: number)
	if session.melee.reachScale <= 1 then
		return
	end
	upgradeFx:FireAllClients(
		"TitanSlam",
		session.player,
		Vector3.new(centre.X, 0, centre.Z),
		radius
	)
end

--[[ Arcane Turret: one session's crystal, appearing, casting, going. Its
     clock only runs while there is something to fight. ]]
local function turret(session: Session, own: State, now: number)
	local config = Balance.Player.turret
	local player = session.player
	local root = session.root
	local fighting = root ~= nil and session.alive and EnemyManager.aliveCount() > 0
	if session.upgrades.turret <= 0 or not fighting then
		if own.turretUntil > now then
			own.turretUntil = 0
			player:SetAttribute("TurretUntil", 0)
		end
		-- the first crystal of a fight comes a moment into it
		own.turretNextAt = nil
		return
	end
	local nextAt = own.turretNextAt
	if not nextAt then
		own.turretNextAt = now + 1
		return
	end
	if now >= nextAt and own.turretUntil <= now then
		own.turretUntil = now + config.duration
		own.turretNextAt = now + config.every
		own.turretCastAt = now + config.castEvery
		player:SetAttribute("TurretUntil", serverIn(config.duration))
	end
	if own.turretUntil <= now or now < own.turretCastAt or not root then
		return
	end
	own.turretCastAt = now + config.castEvery
	local origin = Aim.shotOrigin(root.Position + config.offset)
	local target = Targeting.nearest(origin, EnemyManager.positions(), Balance.Player.attackRange)
	if not target then
		return
	end
	local direction = Targeting.flatDirection(origin, target.position)
	if not direction then
		return
	end
	local spec = plainSpec(session.projectileSpeed, session.projectileLifetime, 0)
	invent(session, origin, direction, spec, session.damage * config.damage, "TurretOrb", now)
end

function ClassUpgrades.step(deltaTime: number, now: number)
	--[[ A card screen held the world: push every clock on by the time it
	     stood, so nothing fires what it missed at once. ]]
	local last = lastStep
	lastStep = now
	if last and now - last > PAUSE then
		local stood = now - last
		for _, hole in holes do
			hole.opensAt += stood
			hole.endsAt += stood
			hole.tickAt += stood
		end
		for _, ember in embers do
			ember.dropAt += stood
		end
		for _, hop in hops do
			hop.hitAt += stood
		end
		for _, blade in blades do
			blade.startsAt += stood
		end
		for session, own in states do
			if own.turretUntil > now - stood then
				own.turretUntil += stood
				own.turretCastAt += stood
				session.player:SetAttribute("TurretUntil", serverIn(own.turretUntil - now))
			end
			if own.turretNextAt then
				own.turretNextAt = (own.turretNextAt :: number) + stood
			end
			own.sniperAt += stood
		end
	end

	--[[ Shield Throw: each hop lands as the shield arrives. ]]
	local throw = Balance.Player.shieldThrow
	for index = #hops, 1, -1 do
		local hop = hops[index]
		if now >= hop.hitAt then
			table.remove(hops, index)
			local session = hop.session
			if session.alive and EnemyManager.healthFraction(hop.model) then
				local _, xp, fell = EnemyManager.damage(
					hop.model,
					session.damage * throw.damage,
					hop.from,
					"Hit",
					session.player
				)
				RunSession.creditKill(session.player, xp, fell)
			end
		end
	end

	--[[ Blade Storm: the sword out and back, each pass striking each enemy
	     it meets once. ]]
	local storm = Balance.Player.bladeStorm
	for index = #blades, 1, -1 do
		local blade = blades[index]
		local t = (now - blade.startsAt) / storm.duration
		local session = blade.session
		if t >= 1 or not session.alive then
			table.remove(blades, index)
			continue
		end
		local at = blade.origin + blade.direction * (blade.length * math.sin(math.pi * t))
		local struck = if t < 0.5 then blade.struckOut else blade.struckBack
		for model, position in EnemyManager.positions() do
			if struck[model] then
				continue
			end
			local body = model.PrimaryPart
			local half = if body then math.max(body.Size.X, body.Size.Z) / 2 else 1
			local away = Vector3.new(position.X - at.X, 0, position.Z - at.Z).Magnitude
			if away <= storm.radius + half then
				struck[model] = true
				local _, xp, fell = EnemyManager.damage(
					model,
					session.damage * storm.damage,
					at,
					"Hit",
					session.player
				)
				RunSession.creditKill(session.player, xp, fell)
			end
		end
	end

	--[[ The phoenix's fire, patch by patch behind it. ]]
	local fire = Balance.Player.phoenix
	for index = #embers, 1, -1 do
		local ember = embers[index]
		if now >= ember.dropAt then
			table.remove(embers, index)
			if ember.session.alive then
				AreaStrikes.zone(
					ember.session.player,
					ember.at,
					fire.trailRadius,
					ember.session.damage * fire.trailDamage,
					fire.trailEvery,
					fire.trailDuration,
					now,
					nil,
					false
				)
			end
		end
	end

	--[[ Black holes: drag, tick, implode. ]]
	local hole = Balance.Player.blackHole
	for index = #holes, 1, -1 do
		local open = holes[index]
		if now < open.opensAt then
			continue
		end
		local session = open.session
		if now >= open.endsAt then
			table.remove(holes, index)
			if session.alive then
				hitWithin(
					session,
					open.at,
					hole.implodeRadius,
					session.damage * hole.implodeDamage,
					open.at
				)
			end
			upgradeFx:FireAllClients(
				"BlackHoleImplode",
				session.player,
				open.at,
				hole.implodeRadius
			)
			continue
		end
		for model, position in EnemyManager.positions() do
			local away = Vector3.new(position.X - open.at.X, 0, position.Z - open.at.Z).Magnitude
			if away <= hole.pullRadius then
				-- harder the nearer the middle, as a well pulls
				local pull = hole.pullSpeed * (0.5 + 0.5 * (1 - away / hole.pullRadius))
				EnemyManager.pull(model, open.at, pull * deltaTime, 0.6)
			end
		end
		if now >= open.tickAt then
			open.tickAt += hole.tickEvery
			if session.alive then
				hitWithin(
					session,
					open.at,
					hole.pullRadius * 0.5,
					session.damage * hole.tickDamage,
					nil
				)
			end
		end
	end

	for _, session in RunSession.all() do
		local own = state(session)
		turret(session, own, now)
		--[[ Elemental Orbs: the next cast's element is always on the player,
		     for their client to colour the orb it predicts. ]]
		local element = if session.upgrades.elemental > 0 then ELEMENTS[own.element] else nil
		if element ~= own.shownElement then
			own.shownElement = element
			session.player:SetAttribute("OrbElement", element)
		end
		--[[ Sniper Shot: a ready sniper arrow glints on the bow
		     (`Fx/Upgrades/RangerBuildFx`). ]]
		local ready = sniperReady(session, own, now)
		if ready ~= own.sniperShown then
			own.sniperShown = ready
			session.player:SetAttribute("SniperReady", ready)
		end
	end
end

--[[ A new room: nothing pending carries over, and a crystal up goes. ]]
function ClassUpgrades.clear()
	table.clear(holes)
	table.clear(embers)
	table.clear(hops)
	table.clear(blades)
	lastStep = nil
	for session, own in states do
		own.turretNextAt = nil
		if own.turretUntil > 0 then
			own.turretUntil = 0
			session.player:SetAttribute("TurretUntil", 0)
		end
	end
end

return ClassUpgrades
