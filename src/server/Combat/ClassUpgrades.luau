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

	And the owner's picks of 2026-11-03 (`docs/CARD-IDEAS.md`):

	- Windrunner (Ranger, Rare): volleys bank move speed, which lapses.
	- Thornfall (Ranger, Epic): a kill plants arrows that fire outward.
	- Headhunter (Ranger, Legendary): every Nth shot is a guaranteed crit.
	- Ghost Quiver (Ranger, Legendary): an archer behind copies the volley.
	- Twin Elements (Arcanist, Epic): the cast's orbs alternate fire and ice
	  (the extra orb itself is a lane in `AbilityEffects.stages`).
	- Time Dilation (Arcanist, Legendary): a hit leaves a crawling field.
	- Prismatic Burst (Arcanist, Legendary): a kill bursts into shards.
	- Bull Rush (Warden, Rare): the dash runs enemies down.
	- Vengeful Spirit (Warden, Legendary): a kill raises a sword.

	Guard Break and Blood Pact are blows, so they live in
	`Combat/MeleeSystem` with the rest of the swing.

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
	--[[ Windrunner: stacks banked, and when they all lapse (os.clock). ]]
	windStacks: number,
	windUntil: number,
	--[[ Headhunter and Twin Elements: shots dressed this run. One counter
	     serves both — "every Nth shot" and "alternate fire and ice" are
	     both questions about which shot this is. ]]
	shots: number,
	--[[ Bull Rush: while the dash is running, and what it has already run
	     through, so one dash hits an enemy once. ]]
	rushUntil: number,
	rushHit: { [Model]: true },
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

--[[ Vengeful Spirit: a sword risen from a kill, hovering by its Warden
     until `endsAt` and striking at `strikeAt` (os.clock). `slot` is which
     side of him it hangs on, so two do not sit in the same place. ]]
type Spirit = { session: Session, endsAt: number, strikeAt: number, slot: number }
local spirits: { Spirit } = {}

--[[ Time Dilation: a patch of crawling ground, left where a shot landed. ]]
type Field = { session: Session, at: Vector3, endsAt: number }
local fields: { Field } = {}

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
		windStacks = 0,
		windUntil = 0,
		shots = 0,
		rushUntil = 0,
		rushHit = {},
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
		critChance = 0,
		critMultiplier = 1,
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

--[[ Thornfall: the arrows a kill plants in the ground, which fire outward
     a moment later, spread evenly round the circle. ]]
local function thornfall(session: Session, at: Vector3, count: number)
	local config = Balance.Player.thornfall
	local damage = session.damage * config.damage
	local spec = plainSpec(config.speed, config.lifetime, 0)
	local origin = Vector3.new(at.X, Balance.Projectile.height, at.Z)
	upgradeFx:FireAllClients("Thornfall", session.player, origin, count)
	task.delay(config.delay, function()
		if not session.alive then
			return
		end
		local fired = os.clock()
		for index = 1, count do
			local angle = (index - 1) / count * math.pi * 2
			invent(
				session,
				origin,
				Vector3.new(math.cos(angle), 0, math.sin(angle)),
				spec,
				damage,
				"Arrow",
				fired
			)
		end
	end)
end

--[[ Prismatic Burst: the shards an orb's kill throws out, each seeking
     whatever is nearest from where the body fell. ]]
local function prismatic(session: Session, at: Vector3, count: number, now: number)
	local config = Balance.Player.prismaticBurst
	local damage = session.damage * config.damage
	local spec = plainSpec(config.speed, config.lifetime, 0)
	spec.homing = math.rad(config.homing)
	local origin = Vector3.new(at.X, Balance.Projectile.height, at.Z)
	upgradeFx:FireAllClients("PrismaticBurst", session.player, origin, count)
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		invent(
			session,
			origin,
			Vector3.new(math.cos(angle), 0, math.sin(angle)),
			spec,
			damage,
			"Orb",
			now
		)
	end
end

--[[ Vengeful Spirit: a kill raises a sword, or refreshes the oldest when
     the Warden already has all he may have at once. ]]
local function raiseSpirit(session: Session, now: number)
	local config = Balance.Player.vengefulSpirit
	local mine, oldest = 0, nil :: Spirit?
	for _, spirit in spirits do
		if spirit.session == session then
			mine += 1
			if not oldest or spirit.endsAt < oldest.endsAt then
				oldest = spirit
			end
		end
	end
	if mine >= config.most and oldest then
		oldest.endsAt = now + config.duration
		return
	end
	table.insert(spirits, {
		session = session,
		endsAt = now + config.duration,
		strikeAt = now + config.strikeEvery,
		slot = mine,
	})
	session.player:SetAttribute("SpiritsUntil", serverIn(config.duration))
	session.player:SetAttribute("Spirits", mine + 1)
end

--[[
	An enemy this player killed fell here (`RunSession.onKillAt`).

	Each card is its own class's, so what killed the enemy never has to be
	asked: a Warden cannot hold Thornfall and a Ranger cannot raise a
	spirit. The card held is the question, as everywhere else here.
]]
function ClassUpgrades.onKillAt(session: Session, at: Vector3)
	local held = session.upgrades
	local now = os.clock()
	if held.thornfall > 0 then
		thornfall(session, at, math.round(held.thornfall))
	end
	if held.prismaticBurst > 0 then
		prismatic(session, at, math.round(held.prismaticBurst), now)
	end
	if held.vengefulSpirit > 0 then
		raiseSpirit(session, now)
	end
end

--[[
	Time Dilation: one of this player's shots landed here, so the field
	opens (`ProjectileSystem.onPlayerHit`).

	Enemies inside it crawl, and so do their shots: the slow is re-applied
	every step rather than set once, because an enemy that walks in after
	the blast should be caught too, and `EnemyManager.slow` is a deadline
	and not a state to clear.
]]
function ClassUpgrades.onPlayerHit(player: Player, at: Vector3)
	local session = RunSession.get(player)
	if not session or session.upgrades.timeDilation <= 0 then
		return
	end
	local config = Balance.Player.timeDilation
	local now = os.clock()
	table.insert(fields, {
		session = session,
		at = Vector3.new(at.X, 0, at.Z),
		endsAt = now + session.upgrades.timeDilation,
	})
	upgradeFx:FireAllClients(
		"TimeField",
		player,
		Vector3.new(at.X, 0, at.Z),
		config.radius,
		session.upgrades.timeDilation
	)
end

--[[ Bull Rush: the dash has begun, so for its length the Warden runs down
     whatever he passes through (`Remotes.DashStarted`, `Main.server`). ]]
function ClassUpgrades.beginRush(session: Session, now: number)
	if session.melee.bullRush <= 0 then
		return
	end
	local own = state(session)
	own.rushUntil = now + Balance.Player.dash.duration
	own.rushHit = {}
	session.player:SetAttribute("BullRushAt", Workspace:GetServerTimeNow())
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
	now: number,
	specs: { Types.ShotSpec }?
)
	local held = session.upgrades
	if
		held.phoenix <= 0
		and held.arrowRain <= 0
		and held.blackHole <= 0
		and held.elemental <= 0
		and held.ghostQuiver <= 0
		and session.windrunner <= 0
	then
		return
	end
	local own = state(session)
	own.volleys += 1

	--[[ Windrunner: a stack a volley, up to the cap, all of them lapsing
	     together a moment after the last one. Published on the player
	     because move speed is the client's to apply
	     (`AbilityEffects.moveSpeedAt`). ]]
	if session.windrunner > 0 then
		local wind = Balance.Player.windrunner
		if now > own.windUntil then
			own.windStacks = 0
		end
		own.windStacks = math.min(own.windStacks + 1, wind.maxStacks)
		own.windUntil = now + wind.duration
		session.player:SetAttribute("Windrunner", own.windStacks)
	end

	--[[ Ghost Quiver: the same volley again from behind the player, at a
	     share of its damage. The specs the pipeline just built are passed
	     in, so this is the volley the player fired and not an invention of
	     its own: every card that shaped it shapes the ghost's too. ]]
	if held.ghostQuiver > 0 and specs then
		local ghost = Balance.Player.ghostQuiver
		local behind = origin - direction * ghost.behind
		upgradeFx:FireAllClients("GhostQuiver", session.player, behind, ghost.behind)
		for _, spec in specs do
			local copy = table.clone(spec)
			copy.delay = (copy.delay or 0) + ghost.delay
			invent(
				session,
				behind,
				direction,
				copy,
				session.damage * copy.damageScale * ghost.damage,
				"Arrow",
				now
			)
		end
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

--[[
	Dresses one of this cast's projectiles before it is spawned: Elemental
	Orbs' element, Twin Elements' alternating pair, and Headhunter's
	guaranteed crit. Nothing without those cards.

	This is the per-projectile hook, so `FiringSystem` calls it for every
	shot and never asks which card did what (CLAUDE.md non-negotiable 1).
]]
function ClassUpgrades.dress(session: Session, params: ProjectileSystem.SpawnParams)
	local held = session.upgrades
	if held.elemental <= 0 and held.twinElements <= 0 and held.headhunterEvery <= 0 then
		return
	end
	local own = state(session)
	own.shots += 1

	--[[ Headhunter: every Nth shot crits for certain, and for more than a
	     crit would have been — it multiplies whatever Deadly Strike and the
	     weapon have already built up rather than replacing it. ]]
	if held.headhunterEvery > 0 and own.shots % held.headhunterEvery == 0 then
		params.critChance = 1
		params.critMultiplier = params.critMultiplier * Balance.Player.headhunter.multiplier
	end

	--[[ Twin Elements: the orbs alternate fire and ice. Counted across all
	     shots rather than reset each cast, which comes to the same thing
	     while the card's own lane is what makes the pair. ]]
	if held.twinElements > 0 then
		local twin = Balance.Player.twinElements
		if own.shots % 2 == 1 then
			params.burn = math.max(params.burn or 0, Balance.Player.elemental.burn)
			params.burnDuration =
				math.max(params.burnDuration or 0, Balance.Player.elemental.burnDuration)
		else
			params.slow = twin.slow
			params.slowDuration = twin.slowDuration
		end
	end

	if held.elemental <= 0 then
		return
	end
	local config = Balance.Player.elemental
	local element = ELEMENTS[own.element]
	if element == "Fire" then
		params.burn = math.max(params.burn or 0, config.burn)
		params.burnDuration = math.max(params.burnDuration or 0, config.burnDuration)
	elseif element == "Ice" then
		params.slow = config.slow
		params.slowDuration = config.slowDuration
	else
		params.ricochet += config.chain
	end
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
		for _, spirit in spirits do
			spirit.endsAt += stood
			spirit.strikeAt += stood
		end
		for _, field in fields do
			field.endsAt += stood
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
			if own.windUntil > now - stood then
				own.windUntil += stood
			end
			if own.rushUntil > now - stood then
				own.rushUntil += stood
			end
		end
	end

	--[[ Windrunner: the stacks lapse together, and the player is told once
	     rather than every frame. ]]
	for session, own in states do
		if own.windStacks > 0 and now > own.windUntil then
			own.windStacks = 0
			session.player:SetAttribute("Windrunner", 0)
		end
	end

	--[[ Bull Rush: while the dash runs, everything the Warden passes
	     through is run down, once each. Measured against the root as it
	     moves, so it needs no direction from the client. ]]
	local rush = Balance.Player.bullRush
	for session, own in states do
		if own.rushUntil <= now then
			continue
		end
		local root = session.root
		if not (root and session.alive) then
			own.rushUntil = 0
			continue
		end
		local centre = root.Position
		for model, position in EnemyManager.positions() do
			if own.rushHit[model] then
				continue
			end
			local body = model.PrimaryPart
			local half = if body then math.max(body.Size.X, body.Size.Z) / 2 else 1
			local away = Vector3.new(position.X - centre.X, 0, position.Z - centre.Z).Magnitude
			if away > rush.width + half then
				continue
			end
			own.rushHit[model] = true
			local _, xp, fell = EnemyManager.damage(
				model,
				session.damage * session.melee.bullRush,
				centre,
				"Hit",
				session.player
			)
			RunSession.creditKill(session.player, xp, fell)
			EnemyManager.shove(model, centre, rush.shove, rush.stagger)
		end
	end

	--[[ Time Dilation: everything standing in a field crawls, and so do the
	     shots crossing it. Re-applied every step rather than set once, so an
	     enemy that walks in afterwards is caught too. ]]
	local dilation = Balance.Player.timeDilation
	for index = #fields, 1, -1 do
		local field = fields[index]
		if now >= field.endsAt then
			table.remove(fields, index)
			continue
		end
		for model, position in EnemyManager.positions() do
			local away = Vector3.new(position.X - field.at.X, 0, position.Z - field.at.Z).Magnitude
			if away <= dilation.radius then
				EnemyManager.slow(model, dilation.slow, now + 0.2)
			end
		end
	end

	--[[ Vengeful Spirit: each sword strikes what is nearest it, then goes
	     when its time is up. ]]
	local sword = Balance.Player.vengefulSpirit
	for index = #spirits, 1, -1 do
		local spirit = spirits[index]
		local session = spirit.session
		local root = session.root
		if now >= spirit.endsAt or not (root and session.alive) then
			table.remove(spirits, index)
			local left = 0
			for _, other in spirits do
				if other.session == session then
					left += 1
				end
			end
			session.player:SetAttribute("Spirits", left)
			continue
		end
		if now < spirit.strikeAt then
			continue
		end
		spirit.strikeAt = now + sword.strikeEvery
		local at = root.Position
		local target = Targeting.nearest(at, EnemyManager.positions(), sword.reach)
		if not target then
			continue
		end
		hitWithin(session, target.position, 1.2, session.damage * sword.damage, at)
		upgradeFx:FireAllClients("SpiritStrike", session.player, target.position, spirit.slot)
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
	end
end

--[[ A new room: nothing pending carries over, and a crystal up goes. ]]
function ClassUpgrades.clear()
	table.clear(holes)
	table.clear(embers)
	table.clear(spirits)
	table.clear(fields)
	lastStep = nil
	for session, own in states do
		own.turretNextAt = nil
		own.rushUntil = 0
		table.clear(own.rushHit)
		if own.windStacks > 0 then
			own.windStacks = 0
			own.windUntil = 0
			session.player:SetAttribute("Windrunner", 0)
		end
		session.player:SetAttribute("Spirits", 0)
		if own.turretUntil > 0 then
			own.turretUntil = 0
			session.player:SetAttribute("TurretUntil", 0)
		end
	end
end

return ClassUpgrades
