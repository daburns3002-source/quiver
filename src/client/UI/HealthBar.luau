--!strict
--[[
	Health readout.

	Health is owned by the server's run session rather than the Humanoid, so
	Roblox's built-in health bar would show the wrong thing. This shows the real
	number and nothing else — the full HUD arrives with the run structure in
	Phase 2.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local HealthBar = {}

local fill: Frame? = nil
local label: TextLabel? = nil

local LOW_HEALTH_FRACTION = 0.3
local HEALTHY_COLOUR = Color3.fromRGB(104, 198, 122)
local LOW_COLOUR = Color3.fromRGB(214, 96, 86)

function HealthBar.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("HealthBar")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HealthBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local container = Instance.new("Frame")
	--[[
		Anchored to the bottom centre and sized in scale, so it lands in the
		same place on a phone and a desktop without a per-device branch. Sits
		above the mobile thumbstick rather than under the player's thumb, and
		above the skill bar, which takes the bottom 78 px through a fight
		(16 margin + its ~62 px combat size, `CardTheme.skillBar`).
	]]
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.new(0.5, 0, 1, -86)
	container.Size = UDim2.new(0.34, 0, 0, 22)
	container.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	container.BackgroundTransparency = 0.25
	container.BorderSizePixel = 0
	container.Parent = gui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 6)
	containerCorner.Parent = container

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(180, 18)
	constraint.MaxSize = Vector2.new(460, 28)
	constraint.Parent = container

	local bar = Instance.new("Frame")
	bar.Name = "Fill"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = HEALTHY_COLOUR
	bar.BorderSizePixel = 0
	bar.Parent = container

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = bar

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.6
	text.Text = ""
	text.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.Parent = text

	gui.Parent = playerGui

	fill = bar
	label = text
end

function HealthBar.update(health: number, maxHealth: number)
	local bar = fill
	local text = label

	if not bar or not text then
		return
	end

	local fraction = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0

	TweenService:Create(bar, TweenInfo.new(0.15), {
		Size = UDim2.fromScale(fraction, 1),
		BackgroundColor3 = if fraction <= LOW_HEALTH_FRACTION then LOW_COLOUR else HEALTHY_COLOUR,
	}):Play()

	text.Text = `{math.max(0, math.floor(health + 0.5))} / {math.floor(maxHealth + 0.5)}`
end

return HealthBar
