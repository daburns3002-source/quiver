--!strict
--[[
	Hit feedback: enemy flash, damage numbers, death pop, screen shake.

	Entirely cosmetic and entirely driven by what the server says happened. The
	Phase 1 playtest question is whether standing still to shoot feels like a
	decision, and a hit that produces no visible reaction reads as a miss — so
	this is not polish, it is part of the thing being tested.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)
local TopDownCamera = require(script.Parent.Parent.Camera.TopDownCamera)

local HitFeedback = {}

local folder: Folder? = nil
local activeNumbers = 0

function HitFeedback.start(parent: Instance)
	local existing = parent:FindFirstChild("HitFeedback")
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = "HitFeedback"
	created.Parent = parent
	folder = created
	activeNumbers = 0
end

local function spawnDamageNumber(position: Vector3, amount: number)
	local tier = Device.tier()

	if activeNumbers >= tier.maxDamageNumbers then
		return
	end

	activeNumbers += 1

	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumber"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	--[[ Jittered so several hits in one spot do not stack into one unreadable
	     number. ]]
	anchor.Position = position
		+ Vector3.new((math.random() - 0.5) * 2, 2.5, (math.random() - 0.5) * 2)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(4, 2)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 244, 214)
	label.TextStrokeTransparency = 0.4
	label.Text = tostring(math.floor(amount + 0.5))
	label.Parent = billboard

	anchor.Parent = folder

	local duration = Balance.Feedback.damageNumberDuration
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(anchor, info, {
		Position = anchor.Position + Vector3.new(0, Balance.Feedback.damageNumberRise, 0),
	}):Play()

	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	task.delay(duration, function()
		activeNumbers -= 1
	end)

	Debris:AddItem(anchor, duration)
end

local function flash(model: Model)
	local primary = model.PrimaryPart
	if not primary then
		return
	end

	local original = primary.Color
	primary.Color = Balance.Feedback.hitFlashColor

	task.delay(Balance.Feedback.hitFlashDuration, function()
		if primary.Parent then
			primary.Color = original
		end
	end)
end

function HitFeedback.onEnemyHit(model: Model, amount: number, position: Vector3)
	if typeof(model) == "Instance" and model:IsA("Model") then
		flash(model)
	end

	spawnDamageNumber(position, amount)
end

--[[ Takes the position rather than the model: the enemy instance is destroyed
     on the server in the same step the remote fires, so no reference to it
     would reliably survive the trip. ]]
function HitFeedback.onEnemyDied(position: Vector3)
	local burst = Instance.new("Part")
	burst.Name = "DeathBurst"
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.one * 2
	burst.Position = position
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.CastShadow = false
	burst.Material = Enum.Material.Neon
	burst.Color = Color3.fromRGB(255, 196, 140)
	burst.Parent = folder

	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(burst, info, {
		Size = Vector3.one * 7,
		Transparency = 1,
	}):Play()

	Debris:AddItem(burst, 0.3)
end

function HitFeedback.onPlayerDamaged(_amount: number)
	if not Device.tier().enableScreenShake then
		return
	end

	TopDownCamera.shake(
		Balance.Feedback.shakeOnDamageMagnitude,
		Balance.Feedback.shakeOnDamageDuration
	)
end

return HitFeedback
