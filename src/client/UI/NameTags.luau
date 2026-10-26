--!strict
--[[
	Player name tags in the game's own font (owner, 2026-10-26: "make every
	piece of text in the lobby the same font"). Roblox draws a player's name
	over their head in its own typeface; this turns that off and puts the
	name up in the blocky font (CLAUDE.md rule 11) instead, for every player
	this client sees.
]]

local Players = game:GetService("Players")

local NameTags = {}

--[[ Studs above the head, and how far away a tag still shows. ]]
local LIFT = 2.6
local RANGE = 100

local function tag(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local head = character:WaitForChild("Head", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not head or not head:IsA("BasePart") then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local existing = head:FindFirstChild("NameTag")
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, LIFT, 0)
	gui.MaxDistance = RANGE
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Arcade
	label.Text = player.DisplayName
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Parent = gui

	gui.Parent = head
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		tag(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(tag, player, character)
	end
end

function NameTags.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return NameTags
