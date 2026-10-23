--!strict
--[[
	Client-side prediction of the local player's own fire, plus character
	facing.

	The server decides what actually happens. This runs the same decision
	locally so the first arrow leaves the bow on the frame the stick is
	released, instead of a round trip later. Move-or-shoot lives or dies on that
	latency — see CLAUDE.md, "Feel beats correctness in the input path".

	Because both sides evaluate independently, cadence can drift by up to one
	cooldown under bad ping: the player may see a volley the server has not
	fired yet, or vice versa. Visual only; damage is always the server's. If
	playtesting shows the drift reads as "my arrows did nothing", the fix is to
	have the server stamp volleys with a sequence number and let the client
	reconcile, not to move the decision back to the client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AbilityEffects = require(ReplicatedStorage.Shared.Combat.AbilityEffects)
local Aim = require(ReplicatedStorage.Shared.Combat.Aim)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local PlayerStats = require(script.Parent.Parent.PlayerStats)
local ProjectileRenderer = require(script.Parent.Parent.Fx.ProjectileRenderer)
local RunPaused = require(script.Parent.Parent.RunPaused)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)

local LocalFiring = {}

local player = Players.LocalPlayer

--[[
	The client's mirror of the local player's pipeline.

	Rebuilt from the replicated stack counts every time the loadout changes.
	It has to be: this client draws its own volley and deliberately skips the
	server's copy of it, so an empty pipeline here means the player watches a
	single unbuffed arrow for the whole run while the server fires the real
	ones at angles nothing on screen reflects. Abilities then appear to do
	nothing, and shots appear to pass through enemies — because the arrow
	being watched is not one of the arrows that exists.
]]
local pipeline = ShotPipeline.new()

local function rebuildPipeline()
	pipeline:clear()

	local stats = PlayerStats.get()
	for _, stage in AbilityEffects.stages(stats.abilities, stats.class) do
		pipeline:addStage(stage)
	end
end

local lastFiredAt = 0
local stationarySince: number? = nil
--[[ For Momentum: when the current stretch of moving began, and how long
     the last one lasted. Tracked exactly as `RunSession.isStationary` does. ]]
local movingSince: number? = nil
local movedFor = 0
local connection: RBXScriptConnection? = nil
local loadoutConnection: RBXScriptConnection? = nil

--[[ Shared with movement and the dash. Prediction is only honest while the
     thing it predicts is still running. ]]
local pauseConnection: RBXScriptConnection? = nil

--[[ The last answer, reused for a moment: the aim is asked for every frame
     (to face the target and draw its ring), and each ask sweeps the arena. ]]
local AIM_REUSE = 0.08
local cachedAt = -math.huge
local cachedOrigin = Vector3.zero
local cachedModel: Model? = nil
local cachedAim: Vector3? = nil

--[[ The enemy the archer would shoot from `origin`, and the point it would
     fire at: the nearest targetable one with a clear line, aimed at the part
     of it that can be hit — `Shared/Combat/Aim`, the rule the server uses. ]]
local function nearestEnemy(origin: Vector3): (Model?, Vector3?)
	local now = os.clock()
	if now - cachedAt < AIM_REUSE and (origin - cachedOrigin).Magnitude < 0.5 then
		if cachedModel == nil or cachedModel.Parent then
			return cachedModel, cachedAim
		end
	end

	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		return nil, nil
	end

	local candidates: { Aim.Candidate } = {}
	for _, child in folder:GetChildren() do
		local model = child :: Model
		local primary = model.PrimaryPart
		if not primary then
			continue
		end

		--[[
			Prediction has to agree with the server about what is shootable, or
			a burrowed enemy would pull the archer's aim underground and draw
			arrows at something the server will not fire at. The server sets
			this attribute when an enemy submerges; absent means targetable,
			so archetypes that never burrow need no attribute at all.
		]]
		if model:GetAttribute("Targetable") == false then
			continue
		end

		table.insert(candidates, {
			model = model,
			position = primary.Position,
			halfWidth = math.max(primary.Size.X, primary.Size.Z) / 2,
		})
	end

	local arena = Workspace:FindFirstChild("Arena")
	local blockers = arena and arena:FindFirstChild("Blockers")
	--[[ A melee class picks only what it can reach, as the server does. ]]
	local class = Classes[PlayerStats.get().class]
	local choice = Aim.choose(
		origin,
		candidates,
		if class and class.reach then class.reach else Balance.Player.attackRange,
		Aim.clearTest(blockers, Balance.Projectile.radius)
	)

	cachedAt = now
	cachedOrigin = origin
	cachedModel = if choice then choice.model else nil
	cachedAim = if choice then choice.aimPoint else nil
	return cachedModel, cachedAim
end

local function nearestEnemyPosition(origin: Vector3): Vector3?
	local _, position = nearestEnemy(origin)
	return position
end

--[[ The enemy the local archer is aiming at right now, for drawing the
     target ring under it. Presentation only: the server picks what it
     actually shoots, by the same rule. ]]
function LocalFiring.currentTarget(): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	local model = nearestEnemy(root.Position)
	return model
end

local function face(root: BasePart, direction: Vector3)
	if direction.Magnitude < 1e-3 then
		return
	end

	--[[
		Position is preserved exactly, so writing CFrame here rotates the
		character without touching its velocity or fighting the physics solver.
	]]
	local flat = Vector3.new(direction.X, 0, direction.Z).Unit
	root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
end

local firedListeners: { () -> () } = {}

local function step()
	--[[ Nothing is being simulated behind the cards, so nothing should be
	     drawn either. ]]
	if RunPaused.get() then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local moveDirection = humanoid.MoveDirection
	local moving = moveDirection.Magnitude > Balance.Player.stationaryThreshold

	if moving then
		stationarySince = nil
		movingSince = movingSince or now
		face(root, moveDirection)
		return
	end

	local target = nearestEnemyPosition(root.Position)

	if target then
		face(root, (target :: Vector3) - root.Position)
	end

	if not stationarySince then
		stationarySince = now
		movedFor = if movingSince then now - movingSince else 0
		movingSince = nil
		return
	end

	if now - (stationarySince :: number) < Balance.Player.stationaryDelay then
		return
	end

	--[[ Replicated, and through the same `cooldownAt` the server asks, so
	     Momentum quickens the predicted rhythm too. A client predicting the
	     base rate drifts further from the server with every volley it draws. ]]
	local stats = PlayerStats.get()
	local cooldown = AbilityEffects.cooldownAt(
		stats.attackCooldown,
		stats.momentumBonus,
		movedFor,
		now - (stationarySince :: number)
	)
	if now - lastFiredAt < cooldown then
		return
	end

	if not target then
		return
	end

	local delta = (target :: Vector3) - root.Position
	local aim = Vector3.new(delta.X, 0, delta.Z)

	if aim.Magnitude < 1e-3 then
		return
	end

	lastFiredAt = now

	--[[ A melee class's swing is the server's to land (`Combat/MeleeSystem`);
	     this client only plays it. ]]
	local class = Classes[stats.class]
	if class and class.swing then
		for _, listener in firedListeners do
			listener()
		end
		return
	end

	local origin = Aim.shotOrigin(root.Position)
	local specs = pipeline:build({
		damage = Balance.Player.baseDamage,
		speed = stats.projectileSpeed,
		lifetime = stats.projectileLifetime,
		origin = origin,
		direction = aim.Unit,
	})

	local look = if class then class.look else "Arrow"
	ProjectileRenderer.spawnVolley("Player", origin, aim.Unit, specs, 0, nil, look)
	for _, listener in firedListeners do
		listener()
	end
end

--[[ Called on every volley this client fires, for the archer's release. ]]
function LocalFiring.onFired(listener: () -> ())
	table.insert(firedListeners, listener)
end

function LocalFiring.start()
	if connection then
		connection:Disconnect()
	end

	if loadoutConnection then
		loadoutConnection:Disconnect()
	end

	--[[ Built once now and again on every grant. Subscribing rather than
	     rebuilding per volley keeps the cost on the level-up, which happens
	     a dozen times a run, instead of on the shot, which happens hundreds. ]]
	rebuildPipeline()
	loadoutConnection = PlayerStats.onChanged(rebuildPipeline)

	if pauseConnection then
		pauseConnection:Disconnect()
	end

	--[[ Clearing the settle timer on resume matters: the player has been
	     standing still behind the cards, and letting that count would hand
	     them a free volley the instant they choose. ]]
	pauseConnection = RunPaused.onChanged(function(value: boolean)
		if not value then
			stationarySince = nil
			lastFiredAt = os.clock()
		end
	end)

	connection = RunService.RenderStepped:Connect(step)
end

function LocalFiring.reset()
	lastFiredAt = 0
	stationarySince = nil
	rebuildPipeline()
end

return LocalFiring
