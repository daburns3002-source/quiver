--!strict
--[[
	Keys for testing in Studio, and nowhere else.

	M — the next card hand includes a Mythic, so its flip reveal can be seen
	without waiting for the roughly one-in-forty hand that deals one.

	Bound only when the game runs in Studio; the server checks the same
	thing before honouring the request, so a live client gains nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local DevKeys = {}

local function toast(text: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevToast"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 120)
	label.Size = UDim2.fromOffset(360, 36)
	label.BackgroundColor3 = Color3.fromRGB(27, 27, 43)
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(255, 106, 85)
	label.Text = text
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	TweenService:Create(
		label,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.4),
		{
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}
	):Play()
	task.delay(1.9, function()
		gui:Destroy()
	end)
end

function DevKeys.start()
	if not RunService:IsStudio() then
		return
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			Remotes.event(Remotes.DebugForceMythic):FireServer()
			toast("Studio: next hand includes a Mythic")
		end
	end)
end

return DevKeys
