--!strict
--[[
	Turns the volleys enemies decided to fire into actual projectiles.

	This exists as its own module for the same reason FiringSystem sits beside
	RunSession rather than inside it: spawning a projectile needs
	ProjectileSystem, and ProjectileSystem needs EnemyManager to resolve
	damage. Having the two require each other would be a cycle, so EnemyManager
	queues and this drains.

	Enemy attacks run through the same ShotPipeline the player's abilities use.
	That is deliberate and is the whole reason the pipeline is in Shared rather
	than owned by RunSession: a Spitter's three-way fan is the same Spread
	stage that will give the player Diagonal Arrows in Phase 3. Keeping both on
	one pipeline is what lets a later biome's roster be a table of stage
	configurations instead of a new behaviour module per enemy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local ProjectileSystem = require(script.Parent.ProjectileSystem)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)
local Stages = require(ReplicatedStorage.Shared.Combat.Stages)
local Types = require(ReplicatedStorage.Shared.Types)

local EnemyFiring = {}

local shotFired = Remotes.event(Remotes.ShotFired)

--[[
	One pipeline per archetype rather than per enemy. Enemies of a kind share a
	firing pattern and cannot gain abilities, so there is nothing per-instance
	to keep — unlike a player, whose pipeline is their run.
]]
local pipelines: { [Balance.EnemyShot]: ShotPipeline.ShotPipeline } = {}

--[[ Projectiles of a fan that leave one after another (`EnemyShot.every`)
     and are not out yet: each one's volley and spec, and when it leaves. ]]
type Pending = { volley: EnemyManager.Volley, spec: Types.ShotSpec, at: number }
local pending: { Pending } = {}

local function pipelineFor(shot: Balance.EnemyShot): ShotPipeline.ShotPipeline
	local existing = pipelines[shot]
	if existing then
		return existing
	end

	local pipeline = ShotPipeline.new()
	pipeline:addStage(Stages.spread(shot.count, shot.spread))
	pipelines[shot] = pipeline

	return pipeline
end

--[[ Spawns `specs` of `volley` now and tells every client to draw them. ]]
local function release(volley: EnemyManager.Volley, specs: { Types.ShotSpec }, now: number)
	for _, spec in specs do
		ProjectileSystem.spawn({
			faction = "Enemy" :: Types.Faction,
			origin = volley.origin,
			direction = ShotPipeline.aim(volley.direction, spec),
			speed = spec.speed,
			lifetime = spec.lifetime,
			damage = volley.damage * spec.damageScale,
			--[[ Enemy shots never pierce. One projectile, one player: a
			     piercing enemy shot would hit the same person twice. ]]
			pierce = 0,
			--[[ And they never crit. Crit is a draft reward; an enemy
			     landing a surprise double is noise the player cannot act
			     on or build towards. ]]
			critChance = 0,
			critMultiplier = 1,
			--[[ None of the draft's projectile behaviour belongs to
			     enemies. An exploding or bouncing enemy shot is a
			     different design decision, not a free one. ]]
			splashRadius = 0,
			splashScale = 0,
			bounces = 0,
			ricochet = 0,
			homing = 0,
			link = 0,
			owner = nil,
			now = now,
			--[[ The Hollow Fisherman's hook drags whoever it catches back
			     along its own line (`Balance.EnemyShot.reel`). ]]
			reel = volley.shot.reel,
		})
	end

	--[[ shooterId 0: the shooter is not a player, so no client should
	     treat this volley as one of its own and skip drawing it. ]]
	shotFired:FireAllClients({
		faction = "Enemy" :: Types.Faction,
		shooterId = 0,
		origin = volley.origin,
		direction = volley.direction,
		specs = specs,
		firedAt = now,
		--[[ Nobody predicts an enemy volley; every client draws it from
		     this event. ]]
		predicted = false,
	} :: Types.ShotEvent)
end

function EnemyFiring.step(now: number)
	-- the fan's later projectiles whose turn has come
	local index = 1
	while index <= #pending do
		local entry = pending[index]
		if entry.at <= now then
			table.remove(pending, index)
			release(entry.volley, { entry.spec }, now)
		else
			index += 1
		end
	end

	for _, volley in EnemyManager.takeVolleys() do
		local shot = volley.shot

		local specs = pipelineFor(shot):build({
			damage = volley.damage,
			speed = shot.speed,
			lifetime = shot.lifetime,
			origin = volley.origin,
			direction = volley.direction,
		})

		local every = shot.every
		if every and every > 0 then
			release(volley, { specs[1] }, now)
			for i = 2, #specs do
				table.insert(
					pending,
					{ volley = volley, spec = specs[i], at = now + (i - 1) * every }
				)
			end
		else
			release(volley, specs, now)
		end
	end
end

return EnemyFiring
