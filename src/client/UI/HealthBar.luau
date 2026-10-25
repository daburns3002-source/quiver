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

local HudLayout = require(script.Parent.HudLayout)

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
	--[[ Inside the phone's safe area, clear of the home bar and rounded
	     corners: ignoring it, the bottom of the HUD ran under them and was
	     cut off (owner, 2026-10-22). ]]
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local container = Instance.new("Frame")
	--[[ Placed by `HudLayout` for this screen (`Config/Hud`): above the
	     skill bar on a computer, beside it on a phone held sideways. ]]
	container.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	container.BackgroundTransparency = 0.25
	container.BorderSizePixel = 0
	container.Parent = gui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 6)
	containerCorner.Parent = container

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(180, 18)
	constraint.Parent = container
	HudLayout.bind(function(layout)
		local place = layout.health
		container.AnchorPoint = place.anchor
		container.Position = place.position
		container.Size = place.size
		constraint.MaxSize = Vector2.new(460, place.maxHeight)
	end)

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
	text.Font = Enum.Font.Arcade
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
