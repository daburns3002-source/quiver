--!strict
--[[
	Player name tags in the game's own font (owner, 2026-10-26: "make every
	piece of text in the lobby the same font"). Roblox draws a player's name
	over their head in its own typeface; this turns that off and puts the
	name up in the game's font (CLAUDE.md rule 11) instead, for every player
	this client sees.

	A VIP's tag is gold, "VIP" before the name (`Config/RobuxStore`), from the
	`PassVIP` attribute the server sets (`Server/Data/Passes`), and turns gold
	the moment the pass is bought.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)

local NameTags = {}

--[[ Studs above the head, and how far away a tag still shows. ]]
local LIFT = 2.6
local RANGE = 100
local VIP = RobuxStore.passAttribute .. "VIP"

--[[ Paints a tag plain or gold, as the player's VIP pass says. ]]
local function paint(player: Player, label: TextLabel)
	if player:GetAttribute(VIP) == true then
		label.Text = "VIP " .. player.DisplayName
		label.TextColor3 = RobuxStore.vipGold
		label.TextStrokeColor3 = Color3.fromRGB(70, 40, 0)
	else
		label.Text = player.DisplayName
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
	end
end

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
	label.Font = Enum.Font.FredokaOne
	label.Text = player.DisplayName
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Parent = gui
	paint(player, label)

	gui.Parent = head
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		tag(player, character)
	end)
	player:GetAttributeChangedSignal(VIP):Connect(function()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local gui = head and head:FindFirstChild("NameTag")
		local label = gui and gui:FindFirstChild("Name")
		if label and label:IsA("TextLabel") then
			paint(player, label)
		end
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
