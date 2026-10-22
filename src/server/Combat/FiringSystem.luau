--!strict
--[[
	Who shoots, when.

	The whole move-or-shoot rule lives in this file and it is deliberately
	small: stand still long enough, have a target in range, be off cooldown, and
	a volley goes out. The server decides, reading the character's replicated
	MoveDirection, so a client cannot fire while moving.

	The client predicts the same decision locally and draws the arrows
	immediately, which is what makes it feel instant. See LocalFiring on the
	client, and the drift note in docs/ROADMAP.md.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local ProjectileSystem = require(script.Parent.ProjectileSystem)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.Parent.Run.RunSession)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Targeting = require(script.Parent.Targeting)
local Types = require(ReplicatedStorage.Shared.Types)

type Session = RunSession.Session
type ShotSpec = Types.ShotSpec

local FiringSystem = {}

local shotFired = Remotes.event(Remotes.ShotFired)

--[[
	How much Momentum is paying out right now.

	Charges from the moment the player stopped moving, which is the same
	instant the archer starts its settle timer — so the ability rewards
	exactly the decision this whole game is built on: staying still when
	staying still is dangerous. Returns 1 without the ability, so the caller
	never needs to know whether it was drafted.
]]
local function momentumScale(session: Session, now: number): number
	if session.momentumBonus <= 0 then
		return 1
	end

	local since = session.stationarySince
	if not since then
		return 1
	end

	local charge = math.clamp((now - since) / Balance.Player.momentumRamp, 0, 1)
	return 1 + session.momentumBonus * charge
end

local function fire(session: Session, root: BasePart, now: number)
	local target =
		Targeting.nearest(root.Position, EnemyManager.positions(), Balance.Player.attackRange)

	if not target then
		return
	end

	local direction = Targeting.flatDirection(root.Position, target.position)
	if not direction then
		return
	end

	local origin = Vector3.new(root.Position.X, root.Position.Y, root.Position.Z)

	local momentum = momentumScale(session, now)

	local specs = session.pipeline:build({
		damage = session.damage * momentum,
		speed = Balance.Projectile.speed,
		lifetime = Balance.Projectile.lifetime,
		origin = origin,
		direction = direction,
	})

	for _, spec in specs do
		local aim = ShotPipeline.aim(direction, spec)

		ProjectileSystem.spawn({
			faction = "Player" :: Types.Faction,
			--[[ Offset sideways so parallel arrows start beside each other
			     rather than on top of one another. The renderer calls the
			     same helper, so what is drawn starts where this does. ]]
			origin = ShotPipeline.spawnPoint(origin, aim, spec),
			direction = aim,
			speed = spec.speed,
			lifetime = spec.lifetime,
			damage = session.damage * spec.damageScale * momentum,
			pierce = spec.pierce,
			critChance = spec.critChance,
			critMultiplier = spec.critMultiplier,
			splashRadius = spec.splashRadius,
			splashScale = spec.splashScale,
			bounces = spec.bounces,
			ricochet = spec.ricochet,
			homing = spec.homing,
			chainOnKill = spec.chainOnKill,
			--[[ The run that fired it, so the kill credits the right player's
			     draft even if the arrow outlives their current session. ]]
			owner = session.player,
			now = now,
		})
	end

	session.lastFiredAt = now

	--[[
		One packet per volley. Specs go over whole rather than packed: Phase 1
		volleys are a single projectile, and clarity is worth more right now
		than the bytes. Revisit when Phase 3 makes volleys large.
	]]
	shotFired:FireAllClients({
		faction = "Player" :: Types.Faction,
		shooterId = session.player.UserId,
		origin = origin,
		direction = direction,
		specs = specs,
		firedAt = now,
		--[[ The shooter's own client drew this the moment their input asked
		     for it, so that client must skip this copy. ]]
		predicted = true,
	} :: Types.ShotEvent)
end

function FiringSystem.step(_deltaTime: number, now: number)
	for _, session in RunSession.all() do
		local root = session.root

		if not root or not session.alive then
			continue
		end

		--[[
			Evaluated every frame, and before the cooldown check, because this
			call is what advances the settle timer. Gating it behind the
			cooldown would stop the timer starting until the cooldown expired,
			so firing would resume a whole cooldown late — and the server would
			disagree with the client, whose prediction already settles first.
		]]
		local stationary = RunSession.isStationary(session, now)

		if not stationary then
			continue
		end

		--[[ From the session, not from Balance: Precision shortens it, and the
		     loadout recomputes it on every grant. ]]
		if now - session.lastFiredAt < session.attackCooldown then
			continue
		end

		fire(session, root, now)
	end
end

return FiringSystem
