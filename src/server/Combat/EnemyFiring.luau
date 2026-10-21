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

function EnemyFiring.step(now: number)
	local volleys = EnemyManager.takeVolleys()

	for _, volley in volleys do
		local shot = volley.shot

		local specs = pipelineFor(shot):build({
			damage = volley.damage,
			speed = shot.speed,
			lifetime = shot.lifetime,
			origin = volley.origin,
			direction = volley.direction,
		})

		for _, spec in specs do
			ProjectileSystem.spawn(
				"Enemy",
				volley.origin,
				ShotPipeline.aim(volley.direction, spec),
				spec.speed,
				spec.lifetime,
				volley.damage * spec.damageScale,
				--[[ Enemy shots never pierce. One projectile, one player: a
				     piercing enemy shot would hit the same person twice. ]]
				0,
				now
			)
		end

		--[[ shooterId 0: the shooter is not a player, so no client should
		     treat this volley as one of its own and skip drawing it. ]]
		shotFired:FireAllClients({
			faction = "Enemy",
			shooterId = 0,
			origin = volley.origin,
			direction = volley.direction,
			specs = specs,
			firedAt = now,
		} :: Types.ShotEvent)
	end
end

return EnemyFiring
