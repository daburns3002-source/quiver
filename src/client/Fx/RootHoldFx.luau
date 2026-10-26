--!strict
--[[
	Roots round the feet of every enemy a pet holds (Stumpy's Root Snare,
	`Shared/Util/RootHold`). The server marks a held enemy with `RootedUntil`
	(server time) and `RootedBy` (the pet); this plays that pet's `Hold` piece
	(`Config/PetAttacks`, the Claude Design root snare) on the floor under it,
	its clip stretched over the hold so the roots grow, grip and sink back as
	it ends, and puts it away when the enemy dies. A fresh root on a held
	enemy grows them again. Sized to the enemy's hitbox.

	Polled, as `Fx/BurnFx` is: the enemy folder is rebuilt every room.
	Presentation only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)
local UpgradeFx = require(script.Parent.Upgrades.UpgradeFx)

local POLL_INTERVAL = 0.05
--[[ The snare's roots stand this far from its middle: an enemy's hitbox
     this wide takes it at its own size, a wider one scales it up. ]]
local SNARE_RADIUS = 1.5

local RootHoldFx = {}

type Held = { untilTime: number, fx: Model? }

local held: { [Model]: Held } = {}
local connection: RBXScriptConnection? = nil
local sinceLastPoll = 0

local function holdPiece(pet: string): PetAttacks.Shot?
	for _, shot in (PetAttacks :: any)[pet] or {} do
		if shot.kind == "Hold" then
			return shot
		end
	end
	return nil
end

local function radiusOf(model: Model): number
	local hitbox = model:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		return math.max(hitbox.Size.X, hitbox.Size.Z) / 2
	end
	return SNARE_RADIUS
end

local function grow(model: Model, untilTime: number, now: number)
	local by = model:GetAttribute("RootedBy")
	local shot = if type(by) == "string" then holdPiece(by) else nil
	if not shot then
		return
	end
	local remaining = untilTime - now
	local function under(): CFrame?
		if model.Parent and Workspace:GetServerTimeNow() < untilTime then
			return CFrame.new(UpgradeFx.floor(model:GetPivot().Position, shot.lift))
		end
		return nil
	end
	local at = under()
	if not at then
		return
	end
	local entry = held[model]
	if entry then
		UpgradeFx.stop(entry.fx)
	end
	held[model] = {
		untilTime = untilTime,
		fx = UpgradeFx.play(shot.effect, {
			at = at,
			life = remaining,
			clip = shot.clip,
			span = remaining,
			scale = math.max(1, radiusOf(model) / SNARE_RADIUS),
			follow = under,
		}),
	}
end

local function poll()
	local now = Workspace:GetServerTimeNow()
	for model, entry in held do
		if not model.Parent or now >= entry.untilTime then
			held[model] = nil
		end
	end
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return
	end
	for _, model in enemies:GetChildren() do
		local untilTime = model:GetAttribute("RootedUntil")
		if not model:IsA("Model") or type(untilTime) ~= "number" or untilTime <= now then
			continue
		end
		local entry = held[model]
		if not entry or untilTime > entry.untilTime + 1e-3 then
			grow(model, untilTime, now)
		end
	end
end

function RootHoldFx.start()
	if connection then
		connection:Disconnect()
	end
	sinceLastPoll = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		sinceLastPoll += deltaTime
		if sinceLastPoll < POLL_INTERVAL then
			return
		end
		sinceLastPoll = 0
		poll()
	end)
end

return RootHoldFx
