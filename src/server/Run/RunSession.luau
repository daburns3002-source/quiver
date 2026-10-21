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

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
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

local healthChanged = Remotes.event(Remotes.HealthChanged)
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

		lastFiredAt = 0,
		stationarySince = nil,

		alive = false,
	}

	sessions[player] = session
	log.info("session created for %s", player.Name)

	return session
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
