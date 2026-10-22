--!strict
--[[
	Flames on burning enemies.

	The server marks a burning enemy with a `Burning` attribute; this puts a
	flame on it while the mark is there. Nothing here decides anything — the
	burn's damage arrives as ordinary hits through `HitFeedback`. This exists
	so a player can see *which* enemies are on fire, which is the only way
	Blaze reads as a card that did something rather than as numbers appearing
	from nowhere.

	Polled a few times a second rather than wired to events, because the enemy
	folder is rebuilt every room and a hook on the old one would quietly stop
	firing. A burn lasts two seconds; a fifth of one is not late.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Parent.Device)

local ATTRIBUTE = "Burning"
local EMITTER_NAME = "BurnFlame"
local POLL_INTERVAL = 0.2

local FLAME = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 140)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 130, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 20)),
})

local BurnFx = {}

local connection: RBXScriptConnection? = nil
local sinceLastPoll = 0

--[[ The part a flame sits on: the hitbox where there is one, since it is
     what the player's arrows hit and it spans the whole body. ]]
local function anchorPart(model: Model): BasePart?
	local hitbox = model:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		return hitbox
	end

	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function createEmitter(part: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = EMITTER_NAME
	emitter.Rate = Device.tier().burnParticleRate
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	emitter.Speed = NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Color = FLAME
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
	return emitter
end

local function poll()
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return
	end

	for _, model in enemies:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local part = anchorPart(model)
		if not part then
			continue
		end

		local existing = part:FindFirstChild(EMITTER_NAME)
		local burning = model:GetAttribute(ATTRIBUTE) == true

		if burning and not existing then
			createEmitter(part)
		elseif not burning and existing then
			existing:Destroy()
		end
	end
end

function BurnFx.start()
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

return BurnFx
