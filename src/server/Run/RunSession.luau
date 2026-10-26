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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local HeldWeaponChoice = require(ReplicatedStorage.Shared.Combat.HeldWeaponChoice)
local Loadout = require(script.Parent.Loadout)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local Pickups = require(script.Parent.Pickups)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local TutorialHands = require(ReplicatedStorage.Shared.Util.TutorialHands)
local Wallet = require(script.Parent.Parent.Data.Wallet)

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
	--[[ The pet's part in the fight (`Combat/PetCombat`): the Mossback
	     Snail's shell is up and blocks the next hit; the Glimmerhorn's
	     revive is spent for this run; the Ember Wilf's howl has the player
	     attacking `petHaste` faster until `petHasteUntil` (os.clock). ]]
	petGuard: boolean,
	petReviveUsed: boolean,
	petHaste: number,
	petHasteUntil: number,
	--[[ Swings started this run, for Whirlwind's every-nth spin. ]]
	swingCount: number,
	--[[ Battle Cry: kill stacks, and when they lapse (os.clock). ]]
	battleCryStacks: number,
	battleCryUntil: number,
	--[[ This stage's kills and when it began, for the end screen. ]]
	stageKills: number,
	--[[ This stage's payouts so far, for the end screen's REWARDS box. ]]
	stageCoins: number,
	stageGems: number,
	stageStartedAt: number,
	--[[ Still on the intro's title screen: the run holds until they press
	     BEGIN ADVENTURE (`Remotes.IntroBegin`). ]]
	atTitle: boolean,
	--[[ The kinds of enemy (`EnemyConfig.displayName`) this player has met
	     since joining, and the NEW ENEMY! screens open on their client, in
	     order (`Config/NewEnemies`). The run holds while any is open. Kept
	     across runs: once per server visit until there is a save (owner,
	     2026-10-25). ]]
	seenEnemies: { [string]: boolean },
	meeting: { string },
	--[[ The tutorial's fixed hands dealt to this player so far this stage
	     (`Util/TutorialHands`). ]]
	tutorialProgress: TutorialHands.Progress,
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

--[[ Whether level-up hands are held back: once a stage's last room or wave
     is cleared, the area is done and a card would only stand between the
     player and the end screen (owner, 2026-10-24: "no longer prompt the
     player after the last boss of any area is defeated"). The levels are
     kept, owed, and dealt in the next stage. Set by `RoomController`. ]]
local offersHeld = false
--[[ Whether the stage being played is the tutorial (`Config/Tutorial`), and
     which of its rooms the run is in: its hands are fixed, not rolled. ]]
local tutorial = false
local tutorialRoom = 1

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
local newEnemy = Remotes.event(Remotes.NewEnemy)
local abilityOffer = Remotes.event(Remotes.AbilityOffer)
local playerStats = Remotes.event(Remotes.PlayerStats)
local playerDamaged = Remotes.event(Remotes.PlayerDamaged)
local playerRevived = Remotes.event(Remotes.PlayerRevived)
local playerDodged = Remotes.event(Remotes.PlayerDodged)
local petAttack = Remotes.event(Remotes.PetAttack)

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
			whirlwindEvery = 0,
			shockwaveLength = 0,
			battleCry = 0,
			parry = 0,
		},
		secondWind = 0,
		secondWindUsed = false,
		petGuard = false,
		petReviveUsed = false,
		petHaste = 0,
		petHasteUntil = 0,
		swingCount = 0,
		battleCryStacks = 0,
		battleCryUntil = 0,
		stageKills = 0,
		stageCoins = 0,
		stageGems = 0,
		stageStartedAt = os.clock(),
		-- in Studio, `SkipIntro` on Workspace starts without the title (`Config/Intro`)
		atTitle = not (RunService:IsStudio() and Workspace:GetAttribute("SkipIntro") == true),
		seenEnemies = {},
		meeting = {},
		tutorialProgress = TutorialHands.newProgress(),
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
	--[[ The weapon in hand when not the class's own: its rarity's damage
	     and a Legendary's or Mythic's built-in effect (`Config/WeaponStats`). ]]
	local equipped = session.loadout.weapon
	local stats = AbilityEffects.serverStats(counts, class, equipped)

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
	for _, stage in AbilityEffects.stages(counts, class, equipped) do
		session.pipeline:addStage(stage)
	end

	playerStats:FireClient(session.player, AbilityEffects.clientStats(counts, class, equipped))
	--[[ The weapon in hand: the class's own, unless a drafted card puts
	     another there (`Ability.weapon`, the Dual Bows Mythic, as a pair
	     of the bow in hand: `Combat/HeldWeaponChoice`). `Main` re-equips
	     when it changes, and the client poses whatever it is. ]]
	local cardWeapon: string? = nil
	for id, level in counts do
		local ability = Abilities.byId[id]
		if level > 0 and ability and ability.weapon then
			cardWeapon = ability.weapon
		end
	end
	local weapon =
		HeldWeaponChoice.pick(session.loadout.weapon or Classes[class].weapon, cardWeapon)
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

--[[ Whether anyone is still on the intro's title screen. The run holds for
     them as it does for a draft (`anyChoosing`), with the same co-op caveat. ]]
function RunSession.anyAtTitle(): boolean
	for _, session in sessions do
		if session.atTitle then
			return true
		end
	end

	return false
end

--[[ The player pressed BEGIN ADVENTURE. The stage's clock starts now, so
     the end screen's time leaves out the title. Only ever clears the hold. ]]
function RunSession.leaveTitle(session: Session)
	if not session.atTitle then
		return
	end
	session.atTitle = false
	session.stageStartedAt = os.clock()
end

--[[ A kind of enemy has landed (`EnemyManager`): everyone who has not met
     it yet this visit is shown its NEW ENEMY! screen, and the run holds
     until they close it (owner, 2026-10-25: pause until GOT IT!). Kinds
     without a screen (bosses, summons, the old archetypes) pass. ]]
function RunSession.meetEnemy(kind: string)
	if not NewEnemies.enemies[kind] then
		return
	end
	for _, session in sessions do
		if not session.seenEnemies[kind] then
			session.seenEnemies[kind] = true
			table.insert(session.meeting, kind)
			newEnemy:FireClient(session.player, kind)
		end
	end
end

--[[ Whether anyone has a NEW ENEMY! screen open. The run holds for them as
     it does for a draft (`anyChoosing`). ]]
function RunSession.anyMeeting(): boolean
	for _, session in sessions do
		if #session.meeting > 0 then
			return true
		end
	end

	return false
end

--[[ The player pressed GOT IT! on a kind's screen. Only clears a screen the
     server opened, so a stray or repeated press changes nothing. ]]
function RunSession.metEnemy(session: Session, kind: unknown)
	if type(kind) ~= "string" then
		return
	end
	local at = table.find(session.meeting, kind)
	if at then
		table.remove(session.meeting, at)
	end
end

local function sendXp(session: Session)
	local loadout = session.loadout
	xpChanged:FireClient(session.player, loadout.xp, loadout.xpToNext, loadout.level)
end

--[[ Opens a card screen if one is owed and none is open. Safe to call every
     frame; it does nothing until there is something to show. ]]
function RunSession.offerIfOwed(session: Session)
	if not session.alive or offersHeld then
		return
	end

	local atFullHealth = session.health >= session.maxHealth - 1e-3
	--[[ The tutorial deals its fixed hand for this level-up; a nil hand (the
	     list ran out) rolls from the pool its banned rarities keep clean. ]]
	local hand: { string }?, kind: TutorialHands.Kind? = nil, nil
	if tutorial then
		hand, kind = TutorialHands.handFor(Tutorial :: any, session.tutorialProgress, tutorialRoom)
	end
	local offer = Loadout.openOffer(session.loadout, atFullHealth, session.random, hand)
	if offer and hand and kind then
		TutorialHands.dealt(session.tutorialProgress, kind, tutorialRoom)
	end

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

--[[ A stage is starting: whether it is the tutorial. In it every player is
     the tutorial's class, can never be dealt its banned rarities, has no
     rerolls, and is dealt the fixed hands from the first. Called after the
     run's loadouts are fresh (`resetRun`, `newStage`). ]]
function RunSession.setTutorial(on: boolean)
	tutorial = on
	tutorialRoom = 1
	if not on then
		return
	end
	for _, session in sessions do
		session.tutorialProgress = TutorialHands.newProgress()
		local loadout = session.loadout
		loadout.class = Tutorial.class
		-- the class's own weapon, not one the sandbox put in hand
		loadout.weapon = nil
		loadout.banned = table.clone(Tutorial.bannedRarities)
		loadout.rerolls = Tutorial.rerolls
		RunSession.applyLoadout(session)
		sendXp(session)
	end
end

--[[ The run has entered room `room` of the stage. ]]
function RunSession.setRoom(room: number)
	tutorialRoom = room
end

--[[ The tutorial's room has been cleared and its crystals collected: a room
     that must level up (`Tutorial.levelUpIn`) and has not is granted the XP
     still owed, so its fixed hand is dealt before the gate opens. ]]
function RunSession.levelUpIfOwed()
	if not tutorial then
		return
	end
	for _, session in sessions do
		local loadout = session.loadout
		if
			session.alive
			and not loadout.offer
			and loadout.pendingLevels <= 0
			and TutorialHands.owesLevel(Tutorial :: any, session.tutorialProgress, tutorialRoom)
		then
			RunSession.awardXp(session, loadout.xpToNext - loadout.xp)
		end
	end
end

--[[ Holds level-up hands back, or lets them through again (`offersHeld`). ]]
function RunSession.holdOffers(held: boolean)
	offersHeld = held
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
	RunSession.payCoins(session, RunSession.areaPay().killCoins)
	--[[ Battle Cry: a stack per kill, up to the cap; they lapse together
	     `duration` seconds after the last kill. The attribute tells the
	     client to play its cry. ]]
	if session.alive and session.melee.battleCry > 0 then
		local now = os.clock()
		local config = Balance.Player.battleCry
		if now > session.battleCryUntil then
			session.battleCryStacks = 0
		end
		session.battleCryStacks = math.min(session.battleCryStacks + 1, config.maxStacks)
		session.battleCryUntil = now + config.duration
		local cries = session.player:GetAttribute("BattleCry")
		session.player:SetAttribute("BattleCry", (if type(cries) == "number" then cries else 0) + 1)
	end
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

--[[ The current stage's payouts (`Config/Economy`), all zero for a stage
     with no area (the courtyards, the Moonlit Arena). ]]
local NO_PAY: Economy.Area =
	{ killCoins = 0, clearCoins = 0, bossItem = "", firstBossGems = 0, bossGems = 0 }

function RunSession.areaPay(): Economy.Area
	local area = CurrentStage.config().area
	return area and Economy.areas[area] or NO_PAY
end

--[[ Coins into the player's saved wallet, counted for this stage's
     summary. ]]
function RunSession.payCoins(session: Session, amount: number)
	if amount <= 0 then
		return
	end
	session.stageCoins += amount
	Wallet.addCoins(session.player, amount)
end

--[[ This stage's boss is beaten: every player in the run gets its item and
     its gems (`Wallet.beatBoss`). ]]
function RunSession.payBoss()
	local area = CurrentStage.config().area
	if not area then
		return
	end
	for _, session in sessions do
		local gems = Wallet.beatBoss(session.player, area)
		session.stageGems += gems
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
	local weapon = session.loadout.weapon
	session.loadout = Loadout.new()
	session.loadout.forceRarity = forced
	-- A new run is the same class.
	session.loadout.class = class
	-- and holds the same weapon (one the sandbox put in hand)
	session.loadout.weapon = weapon
	session.secondWindUsed = false
	session.petReviveUsed = false
	-- a screen left open when the run ended holds nothing now
	table.clear(session.meeting)
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
	session.stageCoins = 0
	session.stageGems = 0
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

		The lobby is not a run and re-enables all of this (`allowJump`).
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

--[[ Jumping on in the lobby (owner, 2026-10-26: "let players sprint and
     jump in the lobby"), off again for a run, the same three ways
     `bindCharacter` takes it away. The client, which owns the character's
     physics, enables the state on its side too (`Input/MoveController`). ]]
function RunSession.allowJump(session: Session, allowed: boolean)
	local humanoid = session.humanoid
	if not humanoid then
		return
	end
	local height = if allowed then LobbyConfig.jumpHeight else 0
	humanoid.JumpHeight = height
	-- the same jump in JumpPower's terms, v = sqrt(2 g h)
	humanoid.JumpPower = math.sqrt(2 * Workspace.Gravity * height)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, allowed)
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
--[[ The share of max health the player's pet revives them at (the
     Glimmerhorn, `Config/PetCombat`), or nil. ]]
local function petRevive(session: Session): number?
	local pet = session.player:GetAttribute("Pet")
	local spec = if type(pet) == "string" then PetCombat.pets[pet] else nil
	return spec and spec.revive
end

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

	--[[ The Mossback Snail's shell takes it (`Combat/PetCombat`), and the
	     snail flies in front of its owner to show it (its Attack). ]]
	if session.petGuard then
		session.petGuard = false
		playerDodged:FireClient(session.player, "Guard")
		petAttack:FireAllClients(session.player, session.player:GetAttribute("Pet"))
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
		elseif not session.petReviveUsed and petRevive(session) then
			-- the Glimmerhorn's, once a run
			session.petReviveUsed = true
			revive(session, session.maxHealth * (petRevive(session) or 0), "Revive")
			log.info("%s revived by their pet", session.player.Name)
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
