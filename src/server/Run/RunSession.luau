--!strict
--[[
	Per-player run state.

	There is deliberately no "the current run" singleton anywhere in this
	project. Even in Phase 1, where exactly one player exists, every piece of run
	state hangs off a session keyed by Player. Co-op in Phase 9 is then a
	scheduling problem rather than a rewrite.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Loadout = require(script.Parent.Loadout)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Pickups = require(script.Parent.Pickups)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)

local log = Log.forTag("RunSession")

export type Session = {
	player: Player,
	character: Model?,
	humanoid: Humanoid?,
	root: BasePart?,

	health: number,
	maxHealth: number,
	damage: number,

	--[[
		This player's own shot pipeline. Phase 3 abilities are added here, which
		is why it can never be shared or global.
	]]
	pipeline: ShotPipeline.ShotPipeline,

	--[[ What this run has drafted. Per-session, never shared — two players
	     drawing from one pool is the first thing that breaks in co-op. ]]
	loadout: Loadout.State,
	--[[ Recomputed from the loadout on every grant rather than nudged, so a
	     stat cannot drift out of step with the abilities that produced it. ]]
	attackCooldown: number,
	--[[ The class's shot speed and lifetime. ]]
	projectileSpeed: number,
	projectileLifetime: number,
	--[[ What the drafted abilities pay out, recomputed from the loadout on
	     every grant like everything else. Shares of max health for the
	     heals; fractions for the rest. ]]
	healPerKill: number,
	regenPerSecond: number,
	dodgeChance: number,
	overdrawBonus: number,
	momentumBonus: number,
	--[[ Multiplier on damage taken (Iron Skin), and a melee class's swing
	     as its cards change it (`AbilityEffects.MeleeStats`). ]]
	damageTaken: number,
	melee: AbilityEffects.MeleeStats,
	--[[ The area-attack Mythics held (`AbilityEffects.ServerStats`); the
	     casts counted towards the next meteor; and when the last dash the
	     server accepted began, which Earthbreaker's cooldown counts from. ]]
	meteor: number,
	earthbreaker: number,
	casts: number,
	lastDashAt: number,
	--[[ Share of max health Second Wind revives with (0 without it), and
	     whether it has been spent. The ability is held; the charge is spent. ]]
	secondWind: number,
	secondWindUsed: boolean,
	--[[ This stage's kills and when it began, for the end screen. ]]
	stageKills: number,
	stageStartedAt: number,
	--[[ Regen accrues every frame but is only told to the client a few
	     times a second. ]]
	healthSentAt: number,
	--[[ Revives left this stage, and `os.clock()` until which nothing hurts
	     the player — set by a revive. ]]
	revivesLeft: number,
	invulnerableUntil: number,
	--[[ A melee class's guard: untouchable from `guardFrom` until
	     `guardUntil`, while its blade is moving (`Combat/MeleeSystem`). ]]
	guardFrom: number,
	guardUntil: number,
	--[[ Its own Random, so one player's draft cannot shift another's rolls,
	     and a run is reproducible from a seed if that is ever wanted. ]]
	random: Random,

	lastFiredAt: number,
	--[[ A melee class's combo: the blow it swung last (0 for none yet), and
	     when that swing's clip ends (`Combat/MeleeSystem`). ]]
	swingIndex: number,
	swingEndsAt: number,
	--[[
		`os.clock()` at which the player last became stationary, or nil while
		moving. The firing system uses it to enforce the settle delay.
	]]
	stationarySince: number?,
	--[[ When the player started moving, while they are; and how long their
	     last stretch of moving lasted. Momentum reads both. ]]
	movingSince: number?,
	movedFor: number,

	alive: boolean,
}

local RunSession = {}

local sessions: { [Player]: Session } = {}

--[[
	Called when a player's run health reaches zero.

	A hook rather than a require, because the run controller already requires
	this module and the two calling each other would be a cycle. Set once at
	boot; nothing else should reach for it.
]]
RunSession.onDeath = nil :: ((Session) -> ())?

--[[ Called when a player is revived, with where they stand. A hook for the
     same reason as `onDeath`: the projectile system requires this module. ]]
RunSession.onRevive = nil :: ((Session, Vector3) -> ())?

local healthChanged = Remotes.event(Remotes.HealthChanged)
local xpChanged = Remotes.event(Remotes.XpChanged)
local abilityOffer = Remotes.event(Remotes.AbilityOffer)
local playerStats = Remotes.event(Remotes.PlayerStats)
local playerDamaged = Remotes.event(Remotes.PlayerDamaged)
local playerRevived = Remotes.event(Remotes.PlayerRevived)
local playerDodged = Remotes.event(Remotes.PlayerDodged)

--[[ Seconds between health updates sent for regeneration alone. ]]
local REGEN_SEND_INTERVAL = 0.25

function RunSession.create(player: Player): Session
	local session: Session = {
		player = player,
		character = nil,
		humanoid = nil,
		root = nil,

		health = Balance.Player.maxHealth,
		maxHealth = Balance.Player.maxHealth,
		damage = Balance.Player.baseDamage,

		pipeline = ShotPipeline.new(),
		loadout = Loadout.new(),
		attackCooldown = Balance.Player.attackCooldown,
		projectileSpeed = Balance.Projectile.speed,
		projectileLifetime = Balance.Projectile.lifetime,
		healPerKill = 0,
		regenPerSecond = 0,
		dodgeChance = 0,
		overdrawBonus = 0,
		momentumBonus = 0,
		damageTaken = 1,
		meteor = 0,
		earthbreaker = 0,
		casts = 0,
		lastDashAt = -math.huge,
		melee = {
			widthScale = 1,
			reachBonus = 0,
			guardLinger = 0,
			slamBonus = 0,
			lifesteal = 0,
			executeBonus = 0,
		},
		secondWind = 0,
		secondWindUsed = false,
		stageKills = 0,
		stageStartedAt = os.clock(),
		healthSentAt = 0,
		revivesLeft = Balance.Revive.perStage,
		invulnerableUntil = 0,
		guardFrom = 0,
		guardUntil = 0,
		random = Random.new(),

		lastFiredAt = 0,
		swingIndex = 0,
		swingEndsAt = 0,
		stationarySince = nil,
		movingSince = nil,
		movedFor = 0,

		alive = false,
	}

	sessions[player] = session
	RunSession.applyLoadout(session)
	log.info("session created for %s", player.Name)

	return session
end

--[[
	Rebuilds everything the loadout decides, from the stack counts alone.

	Called after every grant and on session creation. A full rebuild rather
	than an incremental nudge, because the failure mode of nudging is a stat
	that is subtly wrong after the fourth copy of something and no way to tell
	which copy did it.

	`keepRatio` carries health across a max-health change instead of topping
	the player up: gaining Vitality should not be a full heal, or it would be
	strictly better than the card that *is* a heal.
]]
function RunSession.applyLoadout(session: Session)
	local counts = session.loadout.counts
	local class = session.loadout.class
	local stats = AbilityEffects.serverStats(counts, class)

	local ratio = if session.maxHealth > 0 then session.health / session.maxHealth else 1

	session.damage = stats.damage
	session.maxHealth = stats.maxHealth
	session.health = math.clamp(stats.maxHealth * ratio, 1, stats.maxHealth)
	session.attackCooldown = stats.attackCooldown
	session.projectileSpeed = stats.projectileSpeed
	session.projectileLifetime = stats.projectileLifetime
	session.healPerKill = stats.healPerKill
	session.regenPerSecond = stats.regenPerSecond
	session.dodgeChance = stats.dodgeChance
	session.overdrawBonus = stats.overdrawBonus
	session.momentumBonus = stats.momentumBonus
	session.secondWind = stats.secondWind
	session.damageTaken = stats.damageTaken
	session.meteor = stats.meteor
	session.earthbreaker = stats.earthbreaker
	session.melee = stats.melee

	session.pipeline:clear()
	for _, stage in AbilityEffects.stages(counts, class) do
		session.pipeline:addStage(stage)
	end

	playerStats:FireClient(session.player, AbilityEffects.clientStats(counts, class))
	--[[ The weapon in hand: the class's own, unless a drafted card puts
	     another there (`Ability.weapon`, the Dual Bows Mythic). `Main`
	     re-equips when it changes, and the client poses whatever it is. ]]
	local weapon = Classes[class].weapon
	for id, level in counts do
		local ability = Abilities.byId[id]
		if level > 0 and ability and ability.weapon then
			weapon = ability.weapon
		end
	end
	session.player:SetAttribute("Weapon", weapon)
	session.player:SetAttribute("Class", class)
	healthChanged:FireClient(session.player, session.health, session.maxHealth)
end

--[[ Whether a card screen is open for this player. The run pauses while it
     is, so this is read every frame by the server loop. ]]
function RunSession.isChoosing(session: Session): boolean
	return session.loadout.offer ~= nil
end

--[[
	Whether anyone is mid-draft.

	The run pauses for everybody, which is the honest single-player answer and
	a deliberate placeholder for co-op: freezing the world for four players
	because one is reading three cards will not survive Phase 9. The decision
	of what to do instead — per-player time, or a draft that does not stop the
	fight — belongs with co-op rather than ahead of it.
]]
function RunSession.anyChoosing(): boolean
	for _, session in sessions do
		if session.loadout.offer ~= nil then
			return true
		end
	end

	return false
end

local function sendXp(session: Session)
	local loadout = session.loadout
	xpChanged:FireClient(session.player, loadout.xp, loadout.xpToNext, loadout.level)
end

--[[ Opens a card screen if one is owed and none is open. Safe to call every
     frame; it does nothing until there is something to show. ]]
function RunSession.offerIfOwed(session: Session)
	if not session.alive then
		return
	end

	local atFullHealth = session.health >= session.maxHealth - 1e-3
	local offer = Loadout.openOffer(session.loadout, atFullHealth, session.random)

	if offer then
		abilityOffer:FireClient(
			session.player,
			offer,
			session.loadout.level,
			"Level",
			session.loadout.rerolls
		)
	end
end

--[[
	A Valkyrie or an Angel, from a Waves stage. Pauses the run exactly as a
	level-up does — the offer being open is what `anyChoosing` reads — and
	is chosen through the same validated `chooseAbility`.
]]
function RunSession.offerEncounter(session: Session, source: "Valkyrie" | "Angel")
	if not session.alive then
		return
	end

	local offer = if source == "Valkyrie"
		then Loadout.openValkyrie(
			session.loadout,
			session.health >= session.maxHealth - 1e-3,
			session.random,
			Balance.Waves.valkyrieOffer
		)
		else Loadout.openAngel(session.loadout, session.random)

	if offer then
		abilityOffer:FireClient(
			session.player,
			offer,
			session.loadout.level,
			source,
			session.loadout.rerolls
		)
	end
end

--[[
	Credits XP for something this player killed.

	Takes the session rather than the player so a caller has already had to
	answer "whose kill was it", which is the question that quietly becomes
	wrong in co-op.
]]
function RunSession.awardXp(session: Session, amount: number)
	if amount <= 0 or not session.alive then
		return
	end

	Loadout.addXp(session.loadout, amount)
	sendXp(session)
	RunSession.offerIfOwed(session)
end

--[[
	Everything a kill is worth beyond the XP.

	Separate from `awardXp` because they answer different questions — one is
	progression, the other is a drafted ability paying out — and folding the
	heal into the XP call would make a future "XP without a kill" source heal
	the player for no reason.
]]
function RunSession.onEnemyKilled(session: Session)
	session.stageKills += 1
	if not session.alive or session.healPerKill <= 0 then
		return
	end

	if session.health >= session.maxHealth then
		return
	end

	RunSession.heal(session, session.healPerKill * session.maxHealth)
end

--[[ Mending: a share of max health back every second, while alive and
     hurt. Sent to the client a few times a second, not every frame. ]]
function RunSession.regenerate(deltaTime: number, now: number)
	for _, session in sessions do
		if not session.alive or session.regenPerSecond <= 0 then
			continue
		end

		if session.health >= session.maxHealth then
			continue
		end

		session.health = math.min(
			session.maxHealth,
			session.health + session.regenPerSecond * session.maxHealth * deltaTime
		)

		if now - session.healthSentAt >= REGEN_SEND_INTERVAL then
			session.healthSentAt = now
			healthChanged:FireClient(session.player, session.health, session.maxHealth)
		end
	end
end

--[[
	Credits a kill to the run of the player who made it, which may no longer
	be that player's current one — an arrow or a burn can outlive the run it
	came from. A session replaced since simply does not get it.

	The XP does not arrive here. It drops at `position` as crystals, which
	the player can walk over (`pickUpFloor`) and which are otherwise drawn
	in when the fight clears (`collectCrystals`). Without a position there
	is nowhere to drop them, and the XP is credited at once.
]]
function RunSession.creditKill(owner: Player?, xp: number, position: Vector3?)
	if xp <= 0 or not owner then
		return
	end

	local session = RunSession.get(owner)
	if not session then
		return
	end

	RunSession.onEnemyKilled(session)

	if position then
		Pickups.dropForKill(owner, position, xp, session.random, function(point)
			return Arena.clampToWalls(Arena.resolve(point, 0.6), 0.6)
		end)
	else
		RunSession.awardXp(session, xp)
	end
end

--[[ Draws in every crystal on the floor and credits each player the XP of
     their own. Called when a wave or a room clears. ]]
function RunSession.collectCrystals()
	for player, xp in Pickups.collectCrystals() do
		local session = RunSession.get(player)
		if session then
			RunSession.awardXp(session, xp)
		end
	end
end

--[[ Restores a share of max health. Server-only, like damage. ]]
function RunSession.heal(session: Session, amount: number)
	if not session.alive or amount <= 0 then
		return
	end

	session.health = math.min(session.maxHealth, session.health + amount)
	healthChanged:FireClient(session.player, session.health, session.maxHealth)
end

--[[
	Hands each living player what they are standing on: their own crystals
	and any heart. Read from the server's own copy of where the player is,
	so a pickup is taken by being walked over and by nothing a client says.

	Hearts before crystals, because crystals can level the player up, and a
	card screen opening pauses the run before a heal would land.
]]
function RunSession.pickUpFloor()
	for _, session in sessions do
		local root = session.root
		if not root or not session.alive then
			continue
		end

		local taken = Pickups.takeHearts(session.player, root.Position)
		if taken > 0 then
			RunSession.heal(session, taken * Balance.Pickups.heartHeal * session.maxHealth)
		end

		local xp = Pickups.takeCrystals(session.player, root.Position)
		if xp > 0 then
			RunSession.awardXp(session, xp)
		end
	end
end

--[[
	Redeals the open hand, if a reroll is left. The client asks; whether it
	may is decided here, by `Loadout.reroll`.
]]
function RunSession.reroll(session: Session): boolean
	local atFullHealth = session.health >= session.maxHealth - 1e-3
	local offer = Loadout.reroll(session.loadout, atFullHealth, session.random)
	if not offer then
		return false
	end

	abilityOffer:FireClient(
		session.player,
		offer,
		session.loadout.level,
		session.loadout.offerSource or "Level",
		session.loadout.rerolls
	)
	return true
end

--[[
	Applies the player's choice of card.

	Returns whether it was legal. Everything about trusting the client stops
	here: `Loadout.choose` validates the index against the offer the server
	itself sent, and an invalid one changes nothing at all.
]]
function RunSession.chooseAbility(session: Session, index: number): boolean
	local ability = Loadout.choose(session.loadout, index)
	if not ability then
		return false
	end

	RunSession.applyLoadout(session)

	--[[ After the rebuild, so a heal measured as a fraction of max health uses
	     the max health the card itself may have just raised. ]]
	local heal = AbilityEffects.instantHeal(ability.id, session.maxHealth)
	if heal > 0 then
		session.health = math.min(session.maxHealth, session.health + heal)
		healthChanged:FireClient(session.player, session.health, session.maxHealth)
	end

	log.info("%s drafted %s (level %d)", session.player.Name, ability.id, session.loadout.level)

	sendXp(session)
	--[[ A player can level twice from one kill, so the next card opens as soon
	     as this one closes rather than waiting for another kill. ]]
	RunSession.offerIfOwed(session)
	return true
end

--[[ Clears the draft for a fresh run. Levels and abilities are run-local by
     design: the meta loop is Phase 6, and until then a death costs the build
     and nothing else. ]]
function RunSession.resetRun(session: Session)
	--[[ A Studio test request for a rarity outlives the run it was made in,
	     so dying before the next hand does not swallow it. ]]
	local forced = session.loadout.forceRarity
	local class = session.loadout.class
	session.loadout = Loadout.new()
	session.loadout.forceRarity = forced
	-- A new run is the same class.
	session.loadout.class = class
	session.secondWindUsed = false
	RunSession.newStage(session)
	RunSession.applyLoadout(session)
	session.health = session.maxHealth
	sendXp(session)
	healthChanged:FireClient(session.player, session.health, session.maxHealth)
end

--[[ A stage is starting: its revives are full again. ]]
function RunSession.newStage(session: Session)
	session.revivesLeft = Balance.Revive.perStage
	session.stageKills = 0
	session.stageStartedAt = os.clock()
	session.invulnerableUntil = 0
end

--[[ Whether nothing can hurt this player right now: a revive's shield, or
     a melee class mid-swing. ]]
function RunSession.isInvulnerable(session: Session): boolean
	local now = os.clock()
	return now < session.invulnerableUntil
		or (now >= session.guardFrom and now < session.guardUntil)
end

function RunSession.get(player: Player): Session?
	return sessions[player]
end

--[[ Iterating sessions rather than Players keeps callers co-op-shaped. ]]
function RunSession.all(): { [Player]: Session }
	return sessions
end

function RunSession.destroy(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	session.pipeline:clear()
	sessions[player] = nil
	log.info("session destroyed for %s", player.Name)
end

--[[
	Binds a freshly spawned character. Called from the server bootstrap, never
	from the client.
]]
function RunSession.bindCharacter(session: Session, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?

	if not humanoid or not root then
		log.warn("character for %s never produced a Humanoid/root", session.player.Name)
		return
	end

	humanoid.WalkSpeed = Balance.Player.moveSpeed
	--[[
		The archer faces its target while shooting and its direction while
		moving, so the default "face the way you walk" behaviour is off and the
		client drives facing instead.
	]]
	humanoid.AutoRotate = false
	--[[
		Health is tracked on the session, not on the Humanoid, so that run rules
		(Extra Life, Devil-room max-HP costs) have one owner. The Humanoid is
		kept at full so Roblox never kills the character out from under us.
	]]
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge

	--[[
		No jumping inside a run.

		Walking is the only defensive verb this game has — no dodge, no dash,
		no block (docs/RESEARCH-archero.md §1). A jump is a dodge that costs no
		ground, so it would answer the one question move-or-shoot exists to
		ask: can you afford to stop where you are? Letting a player hop a
		telegraphed line without giving up their firing position deletes the
		decision rather than testing it.

		Set three ways on purpose. `UseJumpPower` decides which of the two
		height properties the engine reads, so zeroing only one leaves the
		other live, and disabling the state stops the jump animation and the
		freefall transition firing from anything that bypasses both.

		The lobby is not a run and is free to re-enable all of this.
	]]
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	session.character = character
	session.humanoid = humanoid
	session.root = root
	session.health = session.maxHealth
	session.alive = true
	session.lastFiredAt = 0
	session.swingIndex = 0
	session.stationarySince = nil

	healthChanged:FireClient(session.player, session.health, session.maxHealth)
end

function RunSession.unbindCharacter(session: Session)
	session.character = nil
	session.humanoid = nil
	session.root = nil
	session.alive = false
	session.stationarySince = nil
end

--[[ Brings a player back from a killing blow at `health`, untouchable for
     a moment, with the enemy shots around them cleared. ]]
local function revive(session: Session, health: number, kind: string)
	session.health = math.max(1, health)
	session.invulnerableUntil = os.clock() + Balance.Revive.invulnerable

	local position = if session.root then session.root.Position else Vector3.zero
	local handler = RunSession.onRevive
	if handler then
		handler(session, position)
	end

	-- which save it was, so Second Wind can be drawn as itself
	playerRevived:FireAllClients(session.player, position, Balance.Revive.invulnerable, kind)
end

--[[
	Applies damage. Server-only: there is no client path into this function, and
	the amount is never supplied by a client.
]]
function RunSession.applyDamage(session: Session, amount: number)
	if not session.alive or amount <= 0 then
		return
	end
	if RunSession.isInvulnerable(session) then
		--[[ A swing's guard caught it (Steadfast's plates flash); a revive's
		     grace says nothing. ]]
		local now = os.clock()
		if
			now >= session.invulnerableUntil
			and now >= session.guardFrom
			and now < session.guardUntil
		then
			playerDodged:FireClient(session.player, "Guard")
		end
		return
	end

	--[[ Agility: rolled on the session's own Random, by the server. ]]
	if session.dodgeChance > 0 and session.random:NextNumber() < session.dodgeChance then
		playerDodged:FireClient(session.player, "Agility")
		return
	end

	amount *= session.damageTaken
	session.health = math.max(0, session.health - amount)
	playerDamaged:FireClient(session.player, amount)

	--[[
		A killing blow is undone, if anything can: Second Wind first — a
		drafted ability is the player's own save — at its share of max
		health, once a run; then the stage's revive, at full health. Either
		way a moment untouchable and the shots around them cleared, or the
		volley that killed them would kill them again.
	]]
	if session.health <= 0 then
		if session.secondWind > 0 and not session.secondWindUsed then
			session.secondWindUsed = true
			revive(session, session.maxHealth * session.secondWind, "SecondWind")
			log.info("%s survived on Second Wind", session.player.Name)
		elseif session.revivesLeft > 0 then
			session.revivesLeft -= 1
			revive(session, session.maxHealth, "Revive")
			log.info("%s revived (%d left)", session.player.Name, session.revivesLeft)
		end
	end

	healthChanged:FireClient(session.player, session.health, session.maxHealth)

	if session.health > 0 then
		return
	end

	session.alive = false
	log.info("%s died", session.player.Name)

	--[[
		Phase 1 has no run structure to fail out of, so death is just a respawn.
		Phase 2 replaces this with the real run-end flow.
	]]
	local humanoid = session.humanoid
	if humanoid then
		humanoid.Health = 0
	end

	local handler = RunSession.onDeath
	if handler then
		handler(session)
	end
end

function RunSession.isStationary(session: Session, now: number): boolean
	local humanoid = session.humanoid
	if not humanoid or not session.alive then
		return false
	end

	local moving = humanoid.MoveDirection.Magnitude > Balance.Player.stationaryThreshold

	if moving then
		session.stationarySince = nil
		session.movingSince = session.movingSince or now
		return false
	end

	local since = session.stationarySince
	if not since then
		session.stationarySince = now
		--[[ How long the stretch of moving that just ended lasted, for
		     Momentum. ]]
		session.movedFor = if session.movingSince then now - session.movingSince else 0
		session.movingSince = nil
		return false
	end

	return (now - since) >= Balance.Player.stationaryDelay
end

Players.PlayerRemoving:Connect(RunSession.destroy)

return RunSession
