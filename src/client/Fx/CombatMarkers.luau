--!strict
--[[
	The marks Archero 2 puts on the floor and over heads to say who is who:

	- a **blue ring** under the player, always;
	- a **segmented red ring** under the enemy the player is aiming at, and
	  only that one, turning slowly;
	- a red **"!"** that pops over an enemy while it winds up an attack.

	All three are presentation. The target is the one `LocalFiring` would
	shoot, by the same rule the server uses; the warning follows a
	`WindingUp` attribute the server sets for exactly as long as it is
	winding up. Nothing here changes what happens — it shows it.

	See docs/ART-archero2.md §3–4.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalFiring = require(script.Parent.Parent.Combat.LocalFiring)

local CombatMarkers = {}

local TARGET_RED = Color3.fromRGB(255, 58, 58)
local TARGET_DISC = Color3.fromRGB(30, 10, 16)
local PLAYER_BLUE = Color3.fromRGB(46, 150, 255)
local PLAYER_DISC = Color3.fromRGB(16, 34, 74)

--[[ The top of the floor's flagstones (Arena's dressing lays them 0.03
     above the true floor), and how far above that the marks float so they
     never z-fight with it. ]]
local FLOOR_Y = 0.03
local LIFT = 0.06

--[[ Segments in the target ring and how they group: three arcs, each this
     many segments long, separated by gaps of `GAP`. ]]
local ARCS = 3
local ARC_SEGMENTS = 7
local GAP = 2
local TARGET_SPIN = math.rad(60)

local WINDING_UP = "WindingUp"
local WARNING_NAME = "AttackWarning"

local folder: Folder? = nil
local connection: RBXScriptConnection? = nil

local targetRing: Model? = nil
local targetRadius = 0
local spin = 0

local playerRing: Model? = nil

local function markerPart(parent: Instance, colour: Color3, neon: boolean): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = colour
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

--[[ A flat disc: a cylinder laid on its side. ]]
local function disc(parent: Instance, diameter: number, colour: Color3, transparency: number): Part
	local part = markerPart(parent, colour, false)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.04, diameter, diameter)
	part.Transparency = transparency
	part:SetAttribute("Offset", Vector3.zero)
	return part
end

--[[ Builds the segmented ring for an enemy of `radius`. Parts carry their
     offset from the ring's centre, so placing it is one pass of CFrames. ]]
local function buildTargetRing(radius: number): Model
	local model = Instance.new("Model")
	model.Name = "TargetRing"

	disc(model, radius * 2, TARGET_DISC, 0.55)

	local total = ARCS * (ARC_SEGMENTS + GAP)
	local step = 2 * math.pi / total
	local length = radius * step * 1.05

	for index = 0, total - 1 do
		if index % (ARC_SEGMENTS + GAP) >= ARC_SEGMENTS then
			continue
		end

		local angle = index * step
		local segment = markerPart(model, TARGET_RED, true)
		segment.Size = Vector3.new(length, 0.06, 0.28)
		segment:SetAttribute("Angle", angle)
		segment:SetAttribute("Radius", radius)
	end

	model.Parent = folder
	return model
end

local function placeRing(model: Model, centre: Vector3, rotation: number)
	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end

		local angle = part:GetAttribute("Angle")
		local radius = part:GetAttribute("Radius")

		if type(angle) == "number" and type(radius) == "number" then
			local a = angle + rotation
			local position = centre + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			--[[ Each segment lies tangent to the circle. ]]
			part.CFrame = CFrame.new(position) * CFrame.Angles(0, -a + math.pi / 2, 0)
		else
			part.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

local function buildPlayerRing(): Model
	local model = Instance.new("Model")
	model.Name = "PlayerRing"
	local outer = disc(model, 3.4, PLAYER_BLUE, 0.15)
	outer.Material = Enum.Material.Neon
	disc(model, 2.7, PLAYER_DISC, 0.35)
	model.Parent = folder
	return model
end

local function placeDiscs(model: Model, centre: Vector3)
	local lift = 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			--[[ Inner discs a hair above outer ones, so they never fight. ]]
			part.CFrame = CFrame.new(centre + Vector3.new(0, lift, 0))
				* CFrame.Angles(0, 0, math.rad(90))
			lift += 0.01
		end
	end
end

--[[ A red burst with a white "!", built once per wind-up and popped in. ]]
local function addWarning(model: Model, root: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = WARNING_NAME
	billboard.Adornee = root
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromScale(0, 0)
	billboard.StudsOffset = Vector3.new(0, root.Size.Y / 2 + 1.8, 0)

	local burst = Instance.new("Frame")
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.5)
	burst.Size = UDim2.fromScale(1, 1)
	burst.BackgroundColor3 = TARGET_RED
	burst.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = burst

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 10, 16)
	stroke.Thickness = 2
	stroke.Parent = burst

	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Font = Enum.Font.Arcade
	mark.Text = "!"
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(255, 255, 255)
	mark.TextStrokeTransparency = 0.3
	mark.Parent = burst

	billboard.Parent = model

	TweenService:Create(
		billboard,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1.6, 1.6) }
	):Play()
end

local function updateWarnings()
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return
	end

	for _, child in enemies:GetChildren() do
		if not child:IsA("Model") then
			continue
		end

		local root = child.PrimaryPart
		local existing = child:FindFirstChild(WARNING_NAME)
		local winding = child:GetAttribute(WINDING_UP) == true

		if winding and not existing and root then
			addWarning(child, root)
		elseif not winding and existing then
			existing:Destroy()
		end
	end
end

local function updateTarget(deltaTime: number)
	local target = LocalFiring.currentTarget()
	local root = target and target.PrimaryPart

	if not target or not root then
		if targetRing then
			targetRing:Destroy()
			targetRing = nil
		end
		return
	end

	local radius = math.max(root.Size.X, root.Size.Z) / 2 + 0.35
	if not targetRing or math.abs(radius - targetRadius) > 1e-3 then
		if targetRing then
			targetRing:Destroy()
		end
		targetRing = buildTargetRing(radius)
		targetRadius = radius
	end

	spin = (spin + TARGET_SPIN * deltaTime) % (2 * math.pi)
	local centre = Vector3.new(root.Position.X, FLOOR_Y + LIFT, root.Position.Z)
	placeRing(targetRing :: Model, centre, spin)
end

local function updatePlayer()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not root then
		if playerRing then
			playerRing:Destroy()
			playerRing = nil
		end
		return
	end

	if not playerRing then
		playerRing = buildPlayerRing()
	end

	placeDiscs(
		playerRing :: Model,
		Vector3.new(root.Position.X, FLOOR_Y + LIFT * 0.5, root.Position.Z)
	)
end

function CombatMarkers.start(parent: Instance)
	local existing = parent:FindFirstChild("CombatMarkers")
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = "CombatMarkers"
	created.Parent = parent
	folder = created
	targetRing = nil
	playerRing = nil

	if connection then
		connection:Disconnect()
	end

	connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		updatePlayer()
		updateTarget(deltaTime)
		updateWarnings()
	end)
end

return CombatMarkers
