--!strict
--[[
	The on-screen dash button.

	Touch only. A keyboard player has the spacebar and a gamepad player has a
	face button, and putting a permanent control on their screen would be
	clutter they cannot dismiss.

	It sits bottom-right because the thumbstick is driven with the left thumb
	and this has to be reachable without crossing hands or looking down. Being
	a real `TextButton` matters for more than hit-testing: Roblox marks a touch
	it handles as processed, and `Thumbstick` refuses processed touches, so a
	finger landing here cannot also drag the movement stick out from under it.

	The ring is the cooldown. It is a fill rather than a number because the
	player reads it in peripheral vision while looking at a fan of projectiles
	somewhere else on the screen.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Dash = require(script.Parent.Dash)

local DashButton = {}

--[[ Studs of screen, not of world. Sized for a thumb: Roblox's own guidance
     and every mobile action game land near this, and smaller is a miss. ]]
local SIZE = 92
local MARGIN = 28

local gui: ScreenGui? = nil
local connections: { RBXScriptConnection } = {}

local READY_COLOUR = Color3.fromRGB(120, 210, 255)
local COOLING_COLOUR = Color3.fromRGB(70, 86, 104)

--[[ Set by `start`, called when the button is pressed. Kept as a hook rather
     than calling Dash directly so MoveController stays the only thing that
     knows what a dash does to a character. ]]
local onPressed: (() -> ())? = nil

function DashButton.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)

	if gui then
		gui:Destroy()
		gui = nil
	end

	onPressed = nil
end

--[[ `pressed` is invoked on every tap, ready or not. Whether a dash is
     actually available is Dash's decision, not this module's — asking twice
     is how the two drift apart. ]]
function DashButton.start(pressed: () -> ())
	DashButton.stop()

	if not UserInputService.TouchEnabled then
		return
	end

	onPressed = pressed

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local created = Instance.new("ScreenGui")
	created.Name = "DashButton"
	created.IgnoreGuiInset = true
	created.ResetOnSpawn = false
	--[[ Under the hit vignette, which is a full-screen flash, and over the
	     world. ]]
	created.DisplayOrder = 20
	created.Parent = playerGui
	gui = created

	local button = Instance.new("TextButton")
	button.Name = "Dash"
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -MARGIN, 1, -MARGIN)
	button.BackgroundColor3 = COOLING_COLOUR
	button.BackgroundTransparency = 0.25
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = created

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = READY_COLOUR
	stroke.Transparency = 0.5
	stroke.Parent = button

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "»"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0.1
	label.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = label

	table.insert(
		connections,
		button.MouseButton1Down:Connect(function()
			local handler = onPressed
			if handler then
				handler()
			end
		end)
	)

	--[[ Repainted every frame from the single source of truth rather than
	     tweened on press, so a dash triggered by the spacebar on a device that
	     also has touch still shows the right state here. ]]
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local readiness = Dash.readiness(os.clock())
			local ready = readiness >= 1

			button.BackgroundColor3 = if ready then READY_COLOUR else COOLING_COLOUR
			button.BackgroundTransparency = if ready then 0.15 else 0.45
			stroke.Transparency = 1 - readiness * 0.7
			label.TextTransparency = if ready then 0.1 else 0.55
		end)
	)
end

return DashButton
