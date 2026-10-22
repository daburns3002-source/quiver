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

local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Loadout = require(script.Parent.Loadout)
local Log = require(ReplicatedStorage.Shared.Util.Log)
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
	--[[ Health restored per kill, and the damage ramp for standing still.
	     Recomputed from the loadout on every grant, like everything else. ]]
	healPerKill: number,
	momentumBonus: number,
	--[[ Whether this run may survive a killing blow, and whether it already
	     has. The ability is held; the charge is spent. ]]
	secondWind: boolean,
	secondWindUsed: boolean,
	--[[ Its own Random, so one player's draft cannot shift another's rolls,
	     and a run is reproducible from a seed if that is ever wanted. ]]
	random: Random,

	lastFiredAt: number,
	--[[
		`os.clock()` at which the player last became stationary, or nil while
		moving. The firing system uses it to enforce the settle delay.
	]]
	stationarySince: number?,

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

local healthChanged = Remotes.event(Remotes.HealthChanged)
local xpChanged = Remotes.event(Remotes.XpChanged)
local abilityOffer = Remotes.event(Remotes.AbilityOffer)
local playerStats = Remotes.event(Remotes.PlayerStats)
local playerDamaged = Remotes.event(Remotes.PlayerDamaged)

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
		healPerKill = 0,
		momentumBonus = 0,
		secondWind = false,
		secondWindUsed = false,
		random = Random.new(),

		lastFiredAt = 0,
		stationarySince = nil,

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
	local stats = AbilityEffects.serverStats(counts)

	local ratio = if session.maxHealth > 0 then session.health / session.maxHealth else 1

	session.damage = stats.damage
	session.maxHealth = stats.maxHealth
	session.health = math.clamp(stats.maxHealth * ratio, 1, stats.maxHealth)
	session.attackCooldown = stats.attackCooldown
	session.healPerKill = stats.healPerKill
	session.momentumBonus = stats.momentumBonus
	session.secondWind = stats.secondWind

	session.pipeline:clear()
	for _, stage in AbilityEffects.stages(counts) do
		session.pipeline:addStage(stage)
	end

	playerStats:FireClient(session.player, AbilityEffects.clientStats(counts))
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
		abilityOffer:FireClient(session.player, offer, session.loadout.level)
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
	if not session.alive or session.healPerKill <= 0 then
		return
	end

	if session.health >= session.maxHealth then
		return
	end

	session.health = math.min(session.maxHealth, session.health + session.healPerKill)
	healthChanged:FireClient(session.player, session.health, session.maxHealth)
end

--[[
	Credits a kill to the run of the player who made it, which may no longer
	be that player's current one — an arrow or a burn can outlive the run it
	came from. A session replaced since simply does not get it.

	The kill's rewards before its XP: levelling opens a card screen and
	pauses the run, and a heal that landed after that would be applied to a
	player already reading cards.
]]
function RunSession.creditKill(owner: Player?, xp: number)
	if xp <= 0 or not owner then
		return
	end

	local session = RunSession.get(owner)
	if session then
		RunSession.onEnemyKilled(session)
		RunSession.awardXp(session, xp)
	end
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
	session.loadout = Loadout.new()
	session.secondWindUsed = false
	RunSession.applyLoadout(session)
	session.health = session.maxHealth
	sendXp(session)
	healthChanged:FireClient(session.player, session.health, session.maxHealth)
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

--[[
	Applies damage. Server-only: there is no client path into this function, and
	the amount is never supplied by a client.
]]
function RunSession.applyDamage(session: Session, amount: number)
	if not session.alive or amount <= 0 then
		return
	end

	session.health = math.max(0, session.health - amount)

	--[[
		Second Wind, spent here rather than at the death check below, so the
		player is never briefly at zero. It leaves them at one health: enough
		to act on, not enough to ignore, and the moment reads as a save rather
		than as a hit that did nothing.

		Once per run, tracked on the session rather than the loadout — the
		ability is still held, it is the *charge* that is gone.
	]]
	if session.health <= 0 and session.secondWind and not session.secondWindUsed then
		session.secondWindUsed = true
		session.health = 1
		log.info("%s survived on Second Wind", session.player.Name)
	end

	playerDamaged:FireClient(session.player, amount)
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
		return false
	end

	local since = session.stationarySince
	if not since then
		session.stationarySince = now
		return false
	end

	return (now - since) >= Balance.Player.stationaryDelay
end

Players.PlayerRemoving:Connect(RunSession.destroy)

return RunSession
