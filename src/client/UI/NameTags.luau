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

	**A hard-mode frame** (owner, 2026-11-18; `Util/HardRules`): a player who
	has won an area's last level on hard wears a plate behind their name in
	that area's colour (its portal's tint) with the kit's outline (`UiPalette.edge`), the
	furthest such area's, from the `HardFrame` attribute the server sets
	(`Data/Wallet`). VIP's gold words sit on it as on the bare tag.

	A weekly tournament winner's tag carries ENDLESS CHAMPION over the name
	(`Config/Tournament.title`, "x2" and on for more wins), from the
	`TournamentWins` attribute the server sets from the save
	(`Run/WeeklyTournament`). The name sits in its own row under it, so the
	frame above and the title never fight over the name's size.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local HardRules = require(ReplicatedStorage.Shared.Util.HardRules)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local Tournament = require(ReplicatedStorage.Shared.Config.Tournament)
local TournamentRules = require(ReplicatedStorage.Shared.Util.TournamentRules)
local UiPalette = require(ReplicatedStorage.Shared.Config.UiPalette)

local NameTags = {}

--[[ Studs above the head, and how far away a tag still shows. ]]
local LIFT = 2.6
local RANGE = 100
local VIP = RobuxStore.passAttribute .. "VIP"
--[[ The frame's words, in points, and its padding beside them. ]]
local FRAME_TEXT = 19
local FRAME_PAD = 10
local WINS = Tournament.winsAttribute
--[[ Points: the tag's width, the name's row, and the title's over it. ]]
local WIDE = 220
local NAME = 26
local TITLE = 17

--[[ The champion's title over the name's row, or none: the tag grows to
     hold it and the row keeps its own height. ]]
local function crown(player: Player, gui: BillboardGui)
	local row = gui:FindFirstChild("Row")
	if not row or not row:IsA("Frame") then
		return
	end
	local wins = player:GetAttribute(WINS)
	local words = TournamentRules.title(if type(wins) == "number" then wins else 0)
	local title = gui:FindFirstChild("Title")
	if not words then
		if title then
			title:Destroy()
		end
		gui.Size = UDim2.fromOffset(WIDE, NAME)
		row.Position = UDim2.fromOffset(0, 0)
		row.Size = UDim2.fromScale(1, 1)
		return
	end
	local text: TextLabel
	if title and title:IsA("TextLabel") then
		text = title
	else
		text = Instance.new("TextLabel")
		text.Name = "Title"
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextColor3 = Tournament.colors.champion
		text.TextStrokeColor3 = Color3.fromRGB(70, 40, 0)
		text.TextStrokeTransparency = 0.2
		text.TextScaled = true
		text.Parent = gui
	end
	text.Text = words
	gui.Size = UDim2.fromOffset(WIDE, TITLE + 1 + NAME)
	text.Position = UDim2.fromOffset(0, 0)
	text.Size = UDim2.new(1, 0, 0, TITLE)
	row.Position = UDim2.fromOffset(0, TITLE + 1)
	row.Size = UDim2.new(1, 0, 0, NAME)
end

--[[ Puts the hard-mode frame behind a tag, or takes it away. ]]
local function frame(player: Player, label: TextLabel)
	local area = player:GetAttribute(HardRules.FRAME)
	local colour = HardRules.frameColour(
		LobbyConfig.portals,
		Balance.Stages,
		if type(area) == "string" then area else nil
	)
	local stroke = label:FindFirstChild("Frame")
	local corner = label:FindFirstChild("Round")
	local pad = label:FindFirstChild("Pad")
	if not colour then
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.AutomaticSize = Enum.AutomaticSize.None
		label.AnchorPoint = Vector2.zero
		label.Position = UDim2.fromScale(0, 0)
		label.Size = UDim2.fromScale(1, 1)
		for _, piece in { stroke, corner, pad } do
			if piece then
				piece:Destroy()
			end
		end
		return
	end
	label.BackgroundTransparency = 0
	label.BackgroundColor3 = colour
	-- sized to the name, centred, rather than the tag's whole width
	label.TextScaled = false
	label.TextSize = FRAME_TEXT
	label.AutomaticSize = Enum.AutomaticSize.X
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0)
	label.Size = UDim2.fromScale(0, 1)
	if not stroke then
		local line = Instance.new("UIStroke")
		line.Name = "Frame"
		line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		line.Thickness = 2.5
		line.Color = UiPalette.edge
		line.Parent = label
	end
	if not corner then
		local round = Instance.new("UICorner")
		round.Name = "Round"
		round.CornerRadius = UDim.new(0, 8)
		round.Parent = label
	end
	if not pad then
		local inset = Instance.new("UIPadding")
		inset.Name = "Pad"
		inset.PaddingLeft = UDim.new(0, FRAME_PAD)
		inset.PaddingRight = UDim.new(0, FRAME_PAD)
		inset.Parent = label
	end
end

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
	gui.Size = UDim2.fromOffset(WIDE, NAME)
	gui.StudsOffsetWorldSpace = Vector3.new(0, LIFT, 0)
	gui.MaxDistance = RANGE
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	-- the name's own row, under the title when there is one (`crown`)
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = gui

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
	label.Parent = row
	paint(player, label)
	frame(player, label)
	crown(player, gui)

	gui.Parent = head
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		tag(player, character)
	end)
	local function repaint()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local gui = head and head:FindFirstChild("NameTag")
		local row = gui and gui:FindFirstChild("Row")
		local label = row and row:FindFirstChild("Name")
		if label and label:IsA("TextLabel") then
			paint(player, label)
			frame(player, label)
		end
		if gui and gui:IsA("BillboardGui") then
			crown(player, gui)
		end
	end
	player:GetAttributeChangedSignal(VIP):Connect(repaint)
	player:GetAttributeChangedSignal(HardRules.FRAME):Connect(repaint)
	player:GetAttributeChangedSignal(WINS):Connect(repaint)
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
