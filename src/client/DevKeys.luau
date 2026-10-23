--!strict
--[[
	Keys for testing in Studio, and nowhere else.

	M — the next card hand includes a Mythic, so its flip reveal can be seen
	without waiting for the roughly one-in-forty hand that deals one.
	L — the next card hand includes a Legendary.
	V / B — preview the Victory / Defeat end screen with sample numbers.
	Drawn on this client only; the server is not told, so the run carries
	on underneath. Press the same key again, or the other, to swap it.

	Bound only when the game runs in Studio; the server checks the same
	thing before honouring the request, so a live client gains nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local EndScreen = require(script.Parent.UI.EndScreen)
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
			Remotes.event(Remotes.DebugForceMythic):FireServer("Mythic")
			toast("Studio: next hand includes a Mythic")
		elseif input.KeyCode == Enum.KeyCode.C then
			Remotes.event(Remotes.DebugNextClass):FireServer()
			toast("Studio: switching class")
		elseif input.KeyCode == Enum.KeyCode.L then
			Remotes.event(Remotes.DebugForceMythic):FireServer("Legendary")
			toast("Studio: next hand includes a Legendary")
		elseif input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.B then
			local won = input.KeyCode == Enum.KeyCode.V
			EndScreen.show({
				won = won,
				stage = 12,
				kills = if won then 48 else 37,
				seconds = if won then 154 else 128,
				healthPercent = 65,
				progressPercent = 77,
			})
			toast(if won then "Studio: Victory preview" else "Studio: Defeat preview")
		end
	end)
end

return DevKeys
