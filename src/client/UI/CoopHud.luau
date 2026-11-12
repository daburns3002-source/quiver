--!strict
--[[
	Co-op on screen (`docs/COOP.md`, `Shared/Util/Coop`):

	- **The party line** under an open portal screen: who is standing at
	  this portal with you and so goes with you on START (the server sets
	  each player's `Portal` attribute), an INVITE A FRIEND button
	  (`SocialService:PromptGameInvite`), and the server's word on the
	  teleport (`Remotes.PartyNotice`).
	- **Downed players**: DOWN! over their heads with the revive filling and
	  the seconds left (`Downed`, `ReviveProgress`, `DownedEndsAt`), or OUT
	  once the bleed-out has run down. Downed yourself, you cannot move or
	  shoot (`RunPaused.setDowned`), and the screen says what to wait for.
	- **The teammate arrow**: in a co-op run, a teammate off the screen is
	  an arrow at its edge pointing at them, with how far away they are.

	Every word in the Arcade font (CLAUDE.md rule 11).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local Workspace = game:GetService("Workspace")

local Coop = require(ReplicatedStorage.Shared.Util.Coop)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunPaused = require(script.Parent.Parent.RunPaused)

local CoopHud = {}

local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(255, 214, 92)
local RED = Color3.fromRGB(235, 76, 76)
local WHITE = Color3.new(1, 1, 1)
local NOTICE_SECONDS = 4

local localPlayer = Players.LocalPlayer

local function label(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	colour: Color3?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = colour or WHITE
	l.TextStrokeTransparency = 0
	l.Size = size
	l.Position = position
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Parent = parent
	return l
end

--[[ The names at portal `index`, the local player first. ]]
local function partyAt(index: number): { string }
	local names = { localPlayer.DisplayName:upper() }
	for _, other in Players:GetPlayers() do
		if other ~= localPlayer and other:GetAttribute("Portal") == index then
			table.insert(names, other.DisplayName:upper())
		end
	end
	return names
end

local function buildPartyLine(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "PartyLine"
	frame.BackgroundColor3 = Color3.fromRGB(20, 30, 60)
	frame.BackgroundTransparency = 0.25
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 0.985)
	frame.Size = UDim2.fromScale(0.62, 0.075)
	frame.Visible = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = frame

	local line = label(frame, "", UDim2.fromScale(0.66, 0.6), UDim2.fromScale(0.36, 0.5), GOLD)
	line.TextXAlignment = Enum.TextXAlignment.Left

	local invite = Instance.new("TextButton")
	invite.Font = FONT
	invite.TextScaled = true
	invite.Text = "INVITE A FRIEND"
	invite.TextColor3 = WHITE
	invite.BackgroundColor3 = Color3.fromRGB(70, 160, 70)
	invite.AnchorPoint = Vector2.new(1, 0.5)
	invite.Position = UDim2.fromScale(0.98, 0.5)
	invite.Size = UDim2.fromScale(0.27, 0.7)
	invite.Parent = frame
	local inviteCorner = Instance.new("UICorner")
	inviteCorner.CornerRadius = UDim.new(0.3, 0)
	inviteCorner.Parent = invite
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.Parent = invite
	invite.Activated:Connect(function()
		pcall(function()
			if SocialService:CanSendGameInviteAsync(localPlayer) then
				SocialService:PromptGameInvite(localPlayer)
			end
		end)
	end)

	local noticeText: string? = nil
	local noticeUntil = 0
	Remotes.event(Remotes.PartyNotice).OnClientEvent:Connect(function(text: unknown)
		if type(text) == "string" then
			noticeText = text
			noticeUntil = os.clock() + NOTICE_SECONDS
		end
	end)

	RunService.RenderStepped:Connect(function()
		local index = localPlayer:GetAttribute("Portal")
		local open = type(index) == "number"
		frame.Visible = open or os.clock() < noticeUntil
		if not frame.Visible then
			return
		end
		if noticeText and os.clock() < noticeUntil then
			line.Text = noticeText
			return
		end
		if not open then
			return
		end
		local names = partyAt(index :: number)
		if #names <= 1 then
			line.Text = "SOLO. A FRIEND CAN STAND HERE TOO"
		else
			local shown = {}
			for i = 1, math.min(#names, Coop.maxParty) do
				shown[i] = names[i]
			end
			line.Text = `PARTY {#shown}/{Coop.maxParty}: {table.concat(shown, " + ")}`
		end
	end)
end

--[[ DOWN! / OUT over one player's head. ]]
local function downedTag(player: Player): BillboardGui?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local existing = head:FindFirstChild("DownedTag")
	if existing and existing:IsA("BillboardGui") then
		return existing
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "DownedTag"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(150, 60)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.LightInfluence = 0
	gui.Parent = head
	local title = label(gui, "DOWN!", UDim2.fromScale(1, 0.45), UDim2.fromScale(0.5, 0.22), RED)
	title.Name = "Title"
	local back = Instance.new("Frame")
	back.Name = "Bar"
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.AnchorPoint = Vector2.new(0.5, 0.5)
	back.Position = UDim2.fromScale(0.5, 0.62)
	back.Size = UDim2.fromScale(0.8, 0.14)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(110, 230, 110)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = back
	local seconds = label(gui, "", UDim2.fromScale(1, 0.26), UDim2.fromScale(0.5, 0.88), WHITE)
	seconds.Name = "Seconds"
	return gui
end

local function stepDowned(selfLine: TextLabel)
	local now = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local downed = player:GetAttribute("Downed")
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if downed == nil then
			local old = head and head:FindFirstChild("DownedTag")
			if old then
				old:Destroy()
			end
			continue
		end
		local gui = downedTag(player)
		if not gui then
			continue
		end
		local title = gui:FindFirstChild("Title") :: TextLabel
		local bar = gui:FindFirstChild("Bar") :: Frame
		local seconds = gui:FindFirstChild("Seconds") :: TextLabel
		if downed == true then
			title.Text = "DOWN!"
			bar.Visible = true
			local progress = player:GetAttribute("ReviveProgress")
			local fill = bar:FindFirstChild("Fill") :: Frame
			fill.Size = UDim2.fromScale(
				if type(progress) == "number" then math.clamp(progress, 0, 1) else 0,
				1
			)
			local endsAt = player:GetAttribute("DownedEndsAt")
			local left = if type(endsAt) == "number"
				then math.max(0, math.ceil(endsAt - now))
				else 0
			seconds.Text = if player == localPlayer then `{left}` else `STAND CLOSE! {left}`
		else
			title.Text = "OUT"
			bar.Visible = false
			seconds.Text = "BACK NEXT ROOM"
		end
	end

	local mine = localPlayer:GetAttribute("Downed")
	RunPaused.setDowned(mine ~= nil)
	selfLine.Visible = mine ~= nil
	selfLine.Text = if mine == true
		then "YOU ARE DOWN! YOUR TEAMMATE CAN REVIVE YOU"
		else "YOU ARE OUT. BACK IN THE NEXT ROOM"
end

local function buildArrow(gui: ScreenGui, player: Player): Frame
	local holder = Instance.new("Frame")
	holder.Name = `Arrow_{player.UserId}`
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(70, 70)
	holder.Visible = false
	holder.Parent = gui
	local arrow = label(holder, "^", UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.5, 0.4), GOLD)
	arrow.Name = "Arrow"
	local distance = label(holder, "", UDim2.fromScale(1.4, 0.3), UDim2.fromScale(0.5, 0.95), WHITE)
	distance.Name = "Distance"
	return holder
end

local function stepArrows(gui: ScreenGui, arrows: { [Player]: Frame })
	local camera = Workspace.CurrentCamera
	local coop = Coop.partySize() > 1
	local mine = localPlayer.Character
	local myRoot = mine and mine:FindFirstChild("HumanoidRootPart")
	for _, player in Players:GetPlayers() do
		if player == localPlayer then
			continue
		end
		local holder = arrows[player]
		if not holder then
			holder = buildArrow(gui, player)
			arrows[player] = holder
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			not coop
			or not camera
			or not root
			or not root:IsA("BasePart")
			or not myRoot
			or not myRoot:IsA("BasePart")
		then
			holder.Visible = false
			continue
		end
		local point, onScreen = camera:WorldToViewportPoint(root.Position)
		local size = camera.ViewportSize
		if onScreen and point.X > 0 and point.X < size.X and point.Y > 0 and point.Y < size.Y then
			holder.Visible = false
			continue
		end
		local centre = size / 2
		local direction = Vector2.new(point.X, point.Y) - centre
		if point.Z < 0 then
			direction = -direction
		end
		if direction.Magnitude < 1 then
			direction = Vector2.new(0, -1)
		end
		local margin = 50
		local half = centre - Vector2.new(margin, margin)
		local scale = math.min(
			half.X / math.max(math.abs(direction.X), 1e-3),
			half.Y / math.max(math.abs(direction.Y), 1e-3)
		)
		local at = centre + direction * scale
		holder.Position = UDim2.fromOffset(at.X, at.Y)
		holder.Visible = true
		local arrow = holder:FindFirstChild("Arrow") :: TextLabel
		arrow.Rotation = math.deg(math.atan2(direction.X, -direction.Y))
		local studs = (root.Position - myRoot.Position).Magnitude
		local distance = holder:FindFirstChild("Distance") :: TextLabel
		distance.Text = `{player.DisplayName:upper()} {math.floor(studs + 0.5)}`
	end
	for player, holder in arrows do
		if not player.Parent then
			holder:Destroy()
			arrows[player] = nil
		end
	end
end

function CoopHud.start()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "CoopHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	buildPartyLine(gui)

	local selfLine = label(gui, "", UDim2.fromScale(0.7, 0.05), UDim2.fromScale(0.5, 0.3), RED)
	selfLine.Visible = false

	local arrows: { [Player]: Frame } = {}
	RunService.RenderStepped:Connect(function()
		stepDowned(selfLine)
		stepArrows(gui, arrows)
	end)
end

return CoopHud
