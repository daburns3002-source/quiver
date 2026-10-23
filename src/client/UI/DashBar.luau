--!strict
--[[
	Dash readiness.

	A four-second cooldown is long enough that the player has to plan around
	it, which only works if they can see it. Without this the dash is a button
	you press hopefully — and a dash that does not fire when you expected it to
	reads as the game dropping your input rather than as you being early.

	Sits directly above the health bar, in the same place on every device,
	because the two answer the same question: can I afford to be here. The
	touch dash button carries its own ring, but that is touch-only and under
	the player's thumb; this is the readout a keyboard player gets, and the one
	a phone player can see without looking at their hand.

	Art and animation are placeholders — this is shape and position, which is
	what the layout needs to be right about before anything prettier lands on
	top of it.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Dash = require(script.Parent.Parent.Input.Dash)
local HudLayout = require(script.Parent.HudLayout)

local DashBar = {}

local READY_COLOUR = Color3.fromRGB(120, 210, 255)
local CHARGING_COLOUR = Color3.fromRGB(70, 110, 150)

local fill: Frame? = nil
local label: TextLabel? = nil
local connection: RBXScriptConnection? = nil

function DashBar.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end

	fill = nil
	label = nil
end

function DashBar.start()
	DashBar.stop()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("DashBar")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DashBar"
	gui.ResetOnSpawn = false
	--[[ Inside the phone's safe area, clear of the home bar and rounded
	     corners: ignoring it, the bottom of the HUD ran under them and was
	     cut off (owner, 2026-10-22). ]]
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	--[[ Same anchor and width as the health bar so the two read as one block
	     rather than as two unrelated widgets that happen to be near each
	     other. ]]
	local container = Instance.new("Frame")
	container.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	container.BackgroundTransparency = 0.25
	container.BorderSizePixel = 0
	container.Parent = gui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 5)
	containerCorner.Parent = container

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(180, 10)
	constraint.Parent = container
	HudLayout.bind(function(layout)
		local place = layout.dash
		container.AnchorPoint = place.anchor
		container.Position = place.position
		container.Size = place.size
		constraint.MaxSize = Vector2.new(460, place.maxHeight)
	end)

	local bar = Instance.new("Frame")
	bar.Name = "Fill"
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = CHARGING_COLOUR
	bar.BorderSizePixel = 0
	bar.Parent = container

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 5)
	barCorner.Parent = bar

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.7
	text.Text = "DASH"
	text.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 1)
	padding.PaddingBottom = UDim.new(0, 1)
	padding.Parent = text

	gui.Parent = playerGui

	fill = bar
	label = text

	--[[ Driven straight off Dash rather than from an event, because the thing
	     being shown is a continuous countdown. There is no "cooldown changed"
	     moment to listen for — only the passage of time. ]]
	connection = RunService.RenderStepped:Connect(function()
		local bar2, text2 = fill, label
		if not bar2 or not text2 then
			return
		end

		local readiness = Dash.readiness(os.clock())
		local ready = readiness >= 1

		bar2.Size = UDim2.fromScale(readiness, 1)
		bar2.BackgroundColor3 = if ready then READY_COLOUR else CHARGING_COLOUR
		--[[ The word only once it means something. A label that always says
		     DASH is decoration; one that appears when the dash is available is
		     the readout. ]]
		text2.TextTransparency = if ready then 0.1 else 0.75
	end)
end

return DashBar
