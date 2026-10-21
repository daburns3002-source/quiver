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

	local specs = session.pipeline:build({
		damage = session.damage,
		speed = Balance.Projectile.speed,
		lifetime = Balance.Projectile.lifetime,
		origin = origin,
		direction = direction,
	})

	for _, spec in specs do
		ProjectileSystem.spawn(
			"Player",
			origin,
			ShotPipeline.aim(direction, spec),
			spec.speed,
			spec.lifetime,
			session.damage * spec.damageScale,
			spec.pierce,
			now
		)
	end

	session.lastFiredAt = now

	--[[
		One packet per volley. Specs go over whole rather than packed: Phase 1
		volleys are a single projectile, and clarity is worth more right now
		than the bytes. Revisit when Phase 3 makes volleys large.
	]]
	shotFired:FireAllClients({
		faction = "Player",
		shooterId = session.player.UserId,
		origin = origin,
		direction = direction,
		specs = specs,
		firedAt = now,
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

		if now - session.lastFiredAt < Balance.Player.attackCooldown then
			continue
		end

		fire(session, root, now)
	end
end

return FiringSystem
