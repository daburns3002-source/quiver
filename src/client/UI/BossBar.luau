--!strict
--[[
	A boss's health across the top of the screen, under the run banner, as
	Archero 2 shows it: the boss's name over a long red bar.

	Drawn from the attributes the server already sets on every enemy
	(`Health`, `MaxHealth`) and the `Boss` attribute it adds to a boss,
	which carries its title. Shown while one is in the room, hidden
	otherwise. Read for drawing only; the server's number is the truth.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BossBar = {}

local BAR_COLOUR = Color3.fromRGB(220, 58, 52)
local TRACK_COLOUR = Color3.fromRGB(24, 26, 32)

local connection: RBXScriptConnection? = nil

local function findBoss(): Model?
	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end
	for _, child in enemies:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Boss") then
			return child
		end
	end
	return nil
end

function BossBar.start()
	BossBar.stop()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("BossBar")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BossBar"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	--[[ Below the run banner's XP bar and its level label. ]]
	frame.Position = UDim2.fromScale(0.5, 0.135)
	frame.Size = UDim2.fromScale(0.5, 0.06)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 54)
	limit.MinSize = Vector2.new(220, 30)
	limit.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.45)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Parent = frame

	local track = Instance.new("Frame")
	track.Position = UDim2.fromScale(0, 0.52)
	track.Size = UDim2.fromScale(1, 0.48)
	track.BackgroundColor3 = TRACK_COLOUR
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	track.Parent = frame
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = BAR_COLOUR
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	gui.Parent = playerGui

	connection = RunService.RenderStepped:Connect(function()
		local boss = findBoss()
		gui.Enabled = boss ~= nil
		if not boss then
			return
		end
		local name = boss:GetAttribute("Boss")
		title.Text = if type(name) == "string" then string.upper(name) else "BOSS"
		local health = boss:GetAttribute("Health")
		local maxHealth = boss:GetAttribute("MaxHealth")
		if type(health) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
			fill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
		end
	end)
end

function BossBar.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return BossBar
