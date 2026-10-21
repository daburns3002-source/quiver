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

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ProjectileRenderer = require(script.Parent.Parent.Fx.ProjectileRenderer)
local ShotPipeline = require(ReplicatedStorage.Shared.Combat.ShotPipeline)

local LocalFiring = {}

local player = Players.LocalPlayer

--[[
	The client's mirror of the local player's pipeline. Empty in Phase 1, which
	is why prediction matches the server exactly. When Phase 3 grants abilities,
	the server must replicate the stage list to this pipeline or prediction will
	silently diverge — that replication is part of Phase 3, not an afterthought.
]]
local pipeline = ShotPipeline.new()

local lastFiredAt = 0
local stationarySince: number? = nil
local connection: RBXScriptConnection? = nil

local function nearestEnemyPosition(origin: Vector3): Vector3?
	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		return nil
	end

	local bestPosition: Vector3? = nil
	local bestDistance = Balance.Player.attackRange

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

		local delta = Vector3.new(primary.Position.X - origin.X, 0, primary.Position.Z - origin.Z)
		local distance = delta.Magnitude

		if distance <= bestDistance then
			bestPosition = primary.Position
			bestDistance = distance
		end
	end

	return bestPosition
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

local function step()
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
		face(root, moveDirection)
		return
	end

	local target = nearestEnemyPosition(root.Position)

	if target then
		face(root, (target :: Vector3) - root.Position)
	end

	if not stationarySince then
		stationarySince = now
		return
	end

	if now - (stationarySince :: number) < Balance.Player.stationaryDelay then
		return
	end

	if now - lastFiredAt < Balance.Player.attackCooldown then
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

	local specs = pipeline:build({
		damage = Balance.Player.baseDamage,
		speed = Balance.Projectile.speed,
		lifetime = Balance.Projectile.lifetime,
		origin = root.Position,
		direction = aim.Unit,
	})

	ProjectileRenderer.spawnVolley("Player", root.Position, aim.Unit, specs, 0)
end

function LocalFiring.start()
	if connection then
		connection:Disconnect()
	end

	connection = RunService.RenderStepped:Connect(step)
end

function LocalFiring.reset()
	lastFiredAt = 0
	stationarySince = nil
end

return LocalFiring
