--!strict
--[[
	The revive, made visible: a golden burst where the player stands, a
	"REVIVED" call-out, and a shimmering shield around them for exactly as
	long as the server says nothing can hurt them.

	Presentation only. The server decided the revive, healed the player and
	cleared the shots around them; this shows it, and drops the drawn shots
	the server removed so none are seen to hit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ProjectileRenderer = require(script.Parent.ProjectileRenderer)

local ReviveFx = {}

local GOLD = Color3.fromRGB(255, 214, 90)
local BURST_TIME = 0.5
--[[ The shield flickers over its last stretch, so the end is not a surprise. ]]
local WARN_TIME = 0.7

local function effectPart(name: string, shape: Enum.PartType, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = GOLD
	part.Material = Enum.Material.Neon
	part.Parent = Workspace
	return part
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function burst(position: Vector3)
	local floor = Vector3.new(position.X, 0.1, position.Z)
	local ring = effectPart("ReviveRing", Enum.PartType.Cylinder, Vector3.new(0.1, 2, 2))
	ring.CFrame = CFrame.new(floor) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.1
	local radius = Balance.Revive.clearRadius
	TweenService:Create(ring, TweenInfo.new(BURST_TIME, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.1, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()

	local flash = effectPart("ReviveFlash", Enum.PartType.Ball, Vector3.one * 2)
	flash.Position = position
	flash.Color = Color3.fromRGB(255, 248, 220)
	TweenService:Create(flash, TweenInfo.new(BURST_TIME * 0.7, Enum.EasingStyle.Quad), {
		Size = Vector3.one * 8,
		Transparency = 1,
	}):Play()

	task.delay(BURST_TIME, function()
		ring:Destroy()
		flash:Destroy()
	end)
end

local function callout(root: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ReviveCallout"
	billboard.Adornee = root
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromScale(6, 1.4)
	billboard.StudsOffset = Vector3.new(0, 4, 0)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.TextStrokeColor3 = Color3.fromRGB(90, 50, 0)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	billboard.Parent = root

	TweenService:Create(billboard, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
		StudsOffset = Vector3.new(0, 6, 0),
	}):Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.8),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	):Play()
	task.delay(1.4, function()
		billboard:Destroy()
	end)
end

local function shield(player: Player, duration: number)
	local bubble = effectPart("ReviveShield", Enum.PartType.Ball, Vector3.one * 5.5)
	bubble.Material = Enum.Material.ForceField
	bubble.Transparency = 0.2

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - started
		local root = rootOf(player)
		if age >= duration or not root then
			connection:Disconnect()
			bubble:Destroy()
			return
		end

		bubble.Position = root.Position
		local left = duration - age
		bubble.Transparency = if left < WARN_TIME and math.floor(age * 12) % 2 == 0 then 1 else 0.2
	end)
end

function ReviveFx.onRevived(player: Player, position: Vector3, duration: number, kind: string?)
	ProjectileRenderer.clearEnemyNear(position, Balance.Revive.clearRadius)
	burst(position)

	local root = rootOf(player)
	if root then
		-- a spent Mythic is told apart from the stage's revive
		callout(root, if kind == "SecondWind" then "SECOND WIND!" else "REVIVED!")
	end
	shield(player, duration)
end

return ReviveFx
