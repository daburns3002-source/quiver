--!strict
--[[
	Health readout.

	Health is owned by the server's run session rather than the Humanoid, so
	Roblox's built-in health bar would show the wrong thing. This shows the real
	number and nothing else — the full HUD arrives with the run structure in
	Phase 2.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Hud = require(ReplicatedStorage.Shared.Config.Hud)

local HudLayout = require(script.Parent.HudLayout)

local HealthBar = {}

local fill: Frame? = nil
local label: TextLabel? = nil
local box: Frame? = nil

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

	-- taller than the bar, centred on it and outlined (`Hud.barText`)
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	text.Size = UDim2.fromScale(1, Hud.barText.health)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Arcade
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0
	text.Text = ""
	text.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 1)
	padding.PaddingBottom = UDim.new(0, 1)
	padding.Parent = text

	gui.Parent = playerGui

	fill = bar
	label = text
	box = container
end

--[[ A "+N" rising off the bar's right end and fading: a heart's heal, told
     by the server with the health it brought (`Remotes.HealthChanged`).
     Each heal its own, so two hearts taken together show twice. ]]
local function showHeal(amount: number)
	local container = box
	if not container then
		return
	end

	local config = Hud.healNumber
	local number = Instance.new("TextLabel")
	number.Name = "HealNumber"
	number.AnchorPoint = Vector2.new(0.5, 0.5)
	number.Position = UDim2.fromScale(config.x, 0.5)
	number.Size = UDim2.fromScale(0.26, config.height)
	number.BackgroundTransparency = 1
	number.Font = Enum.Font.Arcade
	number.TextScaled = true
	number.TextColor3 = config.colour
	number.Text = `+{math.max(1, math.floor(amount + 0.5))}`
	number.ZIndex = 5
	number.Parent = container

	-- a thick dark edge, so green reads on the bar's own green
	local edge = Instance.new("UIStroke")
	edge.Color = config.edge
	edge.Thickness = config.edgeWidth
	edge.Parent = number

	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = number

	-- a quick pop, then the rise; solid for its first half, fading over the rest
	local seconds = config.seconds
	local fade = TweenInfo.new(
		seconds / 2,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In,
		0,
		false,
		seconds / 2
	)
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(number, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(edge, fade, { Transparency = 1 }):Play()
	local rise = TweenService:Create(
		number,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(config.x, 0.5 - config.rise) }
	)
	rise.Completed:Once(function()
		number:Destroy()
	end)
	rise:Play()
end

function HealthBar.update(health: number, maxHealth: number, shown: number?)
	if shown and shown > 0 then
		showHeal(shown)
	end

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
