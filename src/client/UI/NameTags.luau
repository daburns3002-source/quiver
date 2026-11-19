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

	A Roblox Premium member's tag carries Roblox's own Premium mark just
	before the name (owner, 2026-11-18), from the `Premium` attribute the
	server sets (`Server/Data/Premium`): Roblox's picture from its own
	content, so no upload and never redrawn. The name is then sized to its
	words, as the frame's is, so the mark sits beside them.

	A season title (`Config/Season.titles`, tier 30 of a season's premium
	track) stands over the name on a line of its own, in its own colours,
	above the champion's when both are held, from the `SeasonTitle`
	attribute the server sets (`Server/Data/Season`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local HardRules = require(ReplicatedStorage.Shared.Util.HardRules)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local PremiumRules = require(ReplicatedStorage.Shared.Util.PremiumRules)
local RobuxStore = require(ReplicatedStorage.Shared.Config.RobuxStore)
local Season = require(ReplicatedStorage.Shared.Config.Season)
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
--[[ The season title worn (`Data/Season`). ]]
local SEASON_TITLE = "SeasonTitle"
--[[ Points: the tag's width, the name's row, and the title's over it. ]]
local WIDE = 220
local NAME = 26
local TITLE = 17

--[[ One line over the name's row: its words and colours. ]]
type Line = { name: string, words: string, colour: Color3, stroke: Color3, see: number }

--[[ The titles over the name's row, or none: the season's title, then the
     champion's, each on a line of its own. The tag grows to hold them and
     the row keeps its own height. ]]
local function crown(player: Player, gui: BillboardGui)
	local row = gui:FindFirstChild("Row")
	if not row or not row:IsA("Frame") then
		return
	end
	local lines: { Line } = {}
	local key = player:GetAttribute(SEASON_TITLE)
	local season = if type(key) == "string" then Season.titles[key] else nil
	if season then
		-- its stars are plus-shaped, as every star in the game
		table.insert(lines, {
			name = "SeasonTitle",
			words = "+ " .. season.text .. " +",
			colour = season.colour,
			stroke = season.stroke,
			see = 0,
		})
	end
	local wins = player:GetAttribute(WINS)
	local words = TournamentRules.title(if type(wins) == "number" then wins else 0)
	if words then
		table.insert(lines, {
			name = "Title",
			words = words,
			colour = Tournament.colors.champion,
			stroke = Color3.fromRGB(70, 40, 0),
			see = 0.2,
		})
	end
	for _, name in { "SeasonTitle", "Title" } do
		local shown = false
		for _, line in lines do
			shown = shown or line.name == name
		end
		local old = gui:FindFirstChild(name)
		if old and not shown then
			old:Destroy()
		end
	end
	local y = 0
	for _, line in lines do
		local found = gui:FindFirstChild(line.name)
		local text: TextLabel
		if found and found:IsA("TextLabel") then
			text = found
		else
			text = Instance.new("TextLabel")
			text.Name = line.name
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.FredokaOne
			text.TextScaled = true
			text.Parent = gui
		end
		text.Text = line.words
		text.TextColor3 = line.colour
		text.TextStrokeColor3 = line.stroke
		text.TextStrokeTransparency = line.see
		text.Position = UDim2.fromOffset(0, y)
		text.Size = UDim2.new(1, 0, 0, TITLE)
		y += TITLE + 1
	end
	if y == 0 then
		gui.Size = UDim2.fromOffset(WIDE, NAME)
		row.Position = UDim2.fromOffset(0, 0)
		row.Size = UDim2.fromScale(1, 1)
		return
	end
	gui.Size = UDim2.fromOffset(WIDE, y + NAME)
	row.Position = UDim2.fromOffset(0, y)
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
--[[ Roblox's Premium mark (its own content), its size and gap in points,
     and the bare tag's words when a mark stands beside them. ]]
local PREMIUM_MARK = "rbxasset://textures/ui/PlayerList/PremiumIcon.png"
local MARK = 20
local MARK_GAP = 4
local MARK_TEXT = 22

--[[ Puts Roblox's Premium mark before a Premium member's name, or takes
     it away. After `frame`, which lays the label out: a bare tag is then
     sized to its words too, so the mark sits just before them, and the
     two are centred together. ]]
local function mark(player: Player, label: TextLabel)
	local existing = label:FindFirstChild("PremiumMark")
	if player:GetAttribute(PremiumRules.ATTRIBUTE) ~= true then
		if existing then
			existing:Destroy()
		end
		return
	end
	local framed = label:FindFirstChild("Pad") ~= nil
	if not framed then
		label.TextScaled = false
		label.TextSize = MARK_TEXT
		label.AutomaticSize = Enum.AutomaticSize.X
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Size = UDim2.fromScale(0, 1)
	end
	label.Position = UDim2.new(0.5, (MARK + MARK_GAP) / 2, 0, 0)
	local picture = existing :: ImageLabel?
	if not picture then
		local made = Instance.new("ImageLabel")
		made.Name = "PremiumMark"
		made.BackgroundTransparency = 1
		made.Image = PREMIUM_MARK
		made.ScaleType = Enum.ScaleType.Fit
		made.AnchorPoint = Vector2.new(1, 0.5)
		made.Size = UDim2.fromOffset(MARK, MARK)
		made.Parent = label
		picture = made
	end -- outside the frame's plate and its padding, when it has one
	(picture :: ImageLabel).Position =
		UDim2.new(0, -(MARK_GAP + (if framed then FRAME_PAD else 0)), 0.5, 0)
end

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
	mark(player, label)
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
			mark(player, label)
		end
		if gui and gui:IsA("BillboardGui") then
			crown(player, gui)
		end
	end
	player:GetAttributeChangedSignal(VIP):Connect(repaint)
	player:GetAttributeChangedSignal(HardRules.FRAME):Connect(repaint)
	player:GetAttributeChangedSignal(WINS):Connect(repaint)
	player:GetAttributeChangedSignal(SEASON_TITLE):Connect(repaint)
	player:GetAttributeChangedSignal(PremiumRules.ATTRIBUTE):Connect(repaint)
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
