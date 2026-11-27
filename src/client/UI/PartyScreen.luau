--!strict
--[[
	The lobby's party (owner, 2026-11-19: "have there be a party system where
	you can invite someone in the server"; `Run/Parties`, `Util/PartyRules`):

	- **PARTY**, a teal button in the lobby's right column (mirroring
	  REWARDS on the left), with the party's count on its corner and, while
	  the party lasts, a card under it with the members' names, the leader's
	  with a gold pip.
	- **The panel** it opens: the party's state and what it means (the
	  leader's PLAY takes the party), every other player in this server with
	  INVITE (or why not: SENT, IN PARTY, IN A PARTY, BUSY), a page at a time,
	  INVITE A FRIEND (Roblox's own invite, for a friend not here:
	  `UI/InvitePrompt`) and, in a party, LEAVE.
	- **The news line**: the server's word on the party (`Remotes.PartyNews`)
	  across the top for a moment, in a run too.

	The server owns all of it: the panel only reads the Players' `PartyLeader`
	and `PartyInviting` attributes and asks (`Remotes.PartyInvite`,
	`PartyLeave`). The invite prompt itself is `UI/PartyAsk`. Chunky kit,
	Lagoon colours, every word in Fredoka One.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PartyRules = require(ReplicatedStorage.Shared.Util.PartyRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)

local Chunky = require(script.Parent.Chunky)
local InvitePrompt = require(script.Parent.InvitePrompt)
local Kit = require(script.Parent.Kit)
local PortalScreen = require(script.Parent.PortalScreen)
local RunPaused = require(script.Parent.Parent.RunPaused)

local PartyScreen = {}

--[[ What the server sets on each Player (`Run/Parties`). ]]
local LEADER = "PartyLeader"
local INVITING = "PartyInviting"

--[[ The panel's width in points, and what it keeps clear of the edges. ]]
local WIDTH = 380
local MARGIN = 12
--[[ The lobby button, in station-sheet pixels: the right column, at
     REWARDS' height on a phone held upright, lower on a wide screen, under
     Roblox's player list. ]]
local BUTTON_W, BUTTON_H, EDGE = 250, 92, 24
local BUTTON_Y_UPRIGHT, BUTTON_Y_WIDE = 230, 420
--[[ Seconds each news line shows. ]]
local NEWS_SECONDS = 3

local player = Players.LocalPlayer

local panelGui: ScreenGui? = nil
local panelOpen = false
local page = 1
local drawnFor = ""
--[[ Studio's look (`preview`): stand-ins for the other players and the
     party, and the screen size to fit to. ]]
local previewList: { any }? = nil
local previewMembers: { any }? = nil
local previewView: Vector2? = nil

--[[ The players in the local player's party, the leader first; empty when
     there is none. ]]
function PartyScreen.members(): { Player }
	if previewMembers then
		return previewMembers :: any
	end
	local leader = player:GetAttribute(LEADER)
	if type(leader) ~= "number" then
		return {}
	end
	local list = {}
	for _, other in Players:GetPlayers() do
		if other:GetAttribute(LEADER) == leader then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		if (a.UserId == leader) ~= (b.UserId == leader) then
			return a.UserId == leader
		end
		return a.UserId < b.UserId
	end)
	return list
end

--[[ What a row says about `other`: the words, and the button's colour when
     it is a button (INVITE), or nil when it is only a tag. ]]
local function rowState(other: Player): (string, Color3?)
	local mine = player:GetAttribute(LEADER)
	local theirs = other:GetAttribute(LEADER)
	if theirs ~= nil and theirs == mine then
		return if theirs == other.UserId then "LEADER" else "IN PARTY", nil
	end
	if theirs ~= nil then
		return "IN A PARTY", nil
	end
	if other:GetAttribute("Arrived") ~= true then
		return "BUSY", nil
	end
	if player:GetAttribute(INVITING) == other.UserId then
		return "SENT", nil
	end
	if mine ~= nil and #PartyScreen.members() >= PartyRules.maxParty then
		return "FULL", nil
	end
	-- a member, not the leader: the server says only the leader invites
	if mine ~= nil and mine ~= player.UserId then
		return "INVITE", Chunky.grey
	end
	return "INVITE", Chunky.green
end

--[[ The other players here: the party first, then by name. ]]
local function others(): { Player }
	local mine = player:GetAttribute(LEADER)
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		local inA = mine ~= nil and a:GetAttribute(LEADER) == mine
		local inB = mine ~= nil and b:GetAttribute(LEADER) == mine
		if inA ~= inB then
			return inA
		end
		return a.DisplayName:upper() < b.DisplayName:upper()
	end)
	return list
end

--[[ Everything the panel and the button draw from, as one string: a change
     redraws. ]]
local function signature(): string
	local parts = {}
	for _, other in Players:GetPlayers() do
		table.insert(
			parts,
			`{other.UserId}:{other.DisplayName}:{tostring(other:GetAttribute(LEADER))}:{tostring(
				other:GetAttribute(INVITING)
			)}:{tostring(other:GetAttribute("Arrived"))}`
		)
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

--[[ Whether the lobby is the local player's to use: the same as REWARDS'
     button. ]]
local function free(): boolean
	local playerGui = player:FindFirstChild("PlayerGui")
	return Workspace:GetAttribute("InLobby") == true
		and player:GetAttribute("Arrived") == true
		and player:GetAttribute("ClassSelecting") ~= true
		and player:GetAttribute("InStation") ~= true
		and not RunPaused.beforeArrival()
		and not PortalScreen.isOpen()
		and playerGui ~= nil
		and playerGui:FindFirstChild("IntroCutscene") == nil
		and playerGui:FindFirstChild("StoryCutscene") == nil
end

local function words(
	parent: GuiObject,
	text: string,
	colour: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	sheetW: number,
	sheetH: number
): TextLabel
	local t = Chunky.text(parent, text, colour, 0)
	t.Position = UDim2.fromScale(x / sheetW, y / sheetH)
	t.Size = UDim2.fromScale(w / sheetW, h / sheetH)
	t.ZIndex = 8
	return t
end

function PartyScreen.close()
	panelOpen = false
	previewList, previewMembers, previewView = nil, nil, nil
	local gui = panelGui
	if gui then
		gui.Enabled = false
		gui:ClearAllChildren()
	end
end

--[[ Draws the panel; `pop` on opening. ]]
local function draw(pop: boolean)
	local gui = panelGui
	if not gui then
		return
	end
	gui:ClearAllChildren()
	drawnFor = signature()
	local camera = Workspace.CurrentCamera
	local view = previewView or if camera then camera.ViewportSize else Vector2.new(1280, 720)
	-- a short screen shows fewer rows, so every button stays a finger's size
	local perPage = if view.Y >= 640 then 4 elseif view.Y >= 520 then 3 else 2
	local list: { Player } = if previewList then previewList :: any else others()
	local pages = math.max(1, math.ceil(#list / perPage))
	page = math.clamp(page, 1, pages)
	local members = PartyScreen.members()

	--[[ In sheet pixels, two to the point. A phone held upright fits the
	     panel to its width (about 0.96), so every button is laid out at
	     least 100 here: 48 points on the phone (`Config/LobbyHud.minTouch`
	     is the HUD's 56; these are a panel's rows). ]]
	local w = WIDTH * 2
	local pad = 36
	local header = 104
	local statusTop, statusH = header + 20, 100
	local hintTop, hintH = statusTop + statusH + 4, 76
	local listTop = hintTop + hintH + 16
	local rowH, rowGap = 124, 14
	local pagerTop = listTop + perPage * (rowH + rowGap)
	local pagerH = if pages > 1 then 112 else 0
	local footTop = pagerTop + pagerH + 4
	local footH = 112
	local h = footTop + footH + 34 + 12
	local fit = RunHudRules.fit(view, WIDTH, h / 2, MARGIN)

	local shade = Instance.new("TextButton")
	shade.Name = "Shade"
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui
	shade.Activated:Connect(PartyScreen.close)

	local box = Instance.new("Frame")
	box.Name = "Panel"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(WIDTH * fit, h / 2 * fit)
	box.Parent = gui
	local sheet = Chunky.pointSheet(box, WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "PARTY", 0, 0, w, header)
	Chunky.close(sheet, w - 100, 10, 84, PartyScreen.close)

	local buttonW = 220
	local status, hint
	if #members > 0 then
		local leader = members[1]
		status = `YOUR PARTY {#members}/{PartyRules.maxParty}`
		hint = if leader == player
			then "YOU LEAD. PRESS PLAY AND YOUR PARTY COMES WITH YOU"
			else `YOU GO WHEN {leader.DisplayName:upper()} PRESSES PLAY`
		local said = words(
			box,
			status,
			Chunky.ink,
			pad + 8,
			statusTop + 20,
			w - 2 * pad - buttonW - 40,
			statusH - 40,
			w,
			h
		)
		said.Name = "Status"
		said.TextXAlignment = Enum.TextXAlignment.Left
		Chunky.button(
			sheet,
			"LEAVE",
			Chunky.red,
			w - pad - buttonW,
			statusTop,
			buttonW,
			statusH,
			function()
				Remotes.event(Remotes.PartyLeave):FireServer()
			end
		).Name =
			"Leave"
	else
		status = "NO PARTY YET"
		hint = "INVITE SOMEONE HERE TO PLAY TOGETHER"
		words(box, status, Chunky.ink, pad, statusTop + 18, w - 2 * pad, statusH - 36, w, h).Name =
			"Status"
	end
	local said = words(box, hint, Chunky.inkSoft, pad, hintTop, w - 2 * pad, hintH, w, h)
	said.Name = "Hint"
	said.TextWrapped = true

	for i = 1, perPage do
		local other = list[(page - 1) * perPage + i]
		if not other then
			break
		end
		local y = listTop + (i - 1) * (rowH + rowGap)
		local card = Chunky.card(sheet, pad, y, w - 2 * pad, rowH)
		card.Name = `Row_{other.UserId}`
		local nameW = w - 2 * pad - buttonW - 56
		local name = words(
			box,
			other.DisplayName:upper(),
			Chunky.ink,
			pad + 24,
			y + 32,
			nameW,
			rowH - 64,
			w,
			h
		)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local state, colour = rowState(other)
		local bx = w - pad - buttonW - 12
		if colour then
			local target = other.UserId
			local button = Chunky.button(
				sheet,
				state,
				colour,
				bx,
				y + 12,
				buttonW,
				rowH - 24,
				function()
					Remotes.event(Remotes.PartyInvite):FireServer(target)
				end
			)
			button.Name = `Invite_{other.UserId}`
		else
			local tag = words(box, state, Chunky.inkSoft, bx, y + 38, buttonW, rowH - 76, w, h)
			tag.Name = `Tag_{other.UserId}`
		end
	end
	if #list == 0 then
		words(
			box,
			"NOBODY ELSE IS HERE YET",
			Chunky.inkSoft,
			pad,
			listTop + rowH * 0.6,
			w - 2 * pad,
			56,
			w,
			h
		).Name =
			"Nobody"
	end

	if pages > 1 then
		local go = function(step: number)
			return function()
				page = (page - 1 + step) % pages + 1
				draw(false)
			end
		end
		Chunky.button(sheet, "<", Chunky.blue, pad, pagerTop + 6, 150, 100, go(-1)).Name =
			"PagePrev"
		words(
			box,
			`{page}/{pages}`,
			Chunky.ink,
			pad + 170,
			pagerTop + 30,
			w - 2 * pad - 340,
			52,
			w,
			h
		)
		Chunky.button(sheet, ">", Chunky.blue, w - pad - 150, pagerTop + 6, 150, 100, go(1)).Name =
			"PageNext"
	end

	-- a friend who is not in this server: Roblox's own invite
	Chunky.button(
		sheet,
		"INVITE A FRIEND",
		Chunky.blue,
		pad,
		footTop,
		w - 2 * pad,
		footH,
		function()
			InvitePrompt.open()
		end
	).Name =
		"Friend"
	gui.Enabled = true
	if pop then
		Chunky.pop(box)
	end
end

function PartyScreen.open()
	if panelOpen then
		return
	end
	panelOpen = true
	page = 1
	draw(true)
end

function PartyScreen.isOpen(): boolean
	return panelOpen
end

--[[ Studio's look, from a probe in Play (a one-player Play has nobody to
     list): the panel with `stand` standing in for the other players
     (tables with `UserId`, `DisplayName` and a `GetAttribute` method),
     `members` for the party (the leader first), fitted to `view` (a
     phone's 390 x 844 points shows the size it has there). ]]
function PartyScreen.preview(stand: { any }, members: { any }?, view: Vector2?)
	previewList, previewMembers, previewView = stand, members, view
	panelOpen = true
	page = 1
	draw(true)
end

--[[ The lobby button and the party's card under it. ]]
local function startButton(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PartyButton"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = playerGui
	local canvas = Kit.canvas(gui)
	local built = ""

	local function build()
		for _, child in canvas:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local sheet = Chunky.sheet(canvas)
		built = `{sheet.upright}|{signature()}`
		local bx = sheet.w - EDGE - BUTTON_W
		local by = if sheet.upright then BUTTON_Y_UPRIGHT else BUTTON_Y_WIDE
		Chunky.button(sheet, "PARTY", Chunky.blue, bx, by, BUTTON_W, BUTTON_H, PartyScreen.open).Name =
			"Party"
		local members = PartyScreen.members()
		if #members == 0 then
			return
		end
		-- the count on the corner, as REWARDS carries its own
		local dot = Instance.new("Frame")
		dot.Name = "Count"
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = Chunky.green
		dot.ZIndex = 45
		Chunky.put(sheet, dot, bx - 30, by - 24, 52, 52)
		Chunky.round(dot, 26)
		Chunky.outline(dot, 5)
		local n = Chunky.textOn(dot, tostring(#members), Chunky.green, 3)
		n.Position, n.Size = UDim2.fromScale(0.15, 0.12), UDim2.fromScale(0.7, 0.76)
		n.ZIndex = 46
		-- who is in it, the leader first
		local rowH = 46
		local top = by + BUTTON_H + 22
		local card = Chunky.card(sheet, bx, top, BUTTON_W, 20 + rowH * #members)
		card.Name = "Members"
		for i, member in members do
			local rowY = top + 10 + rowH * (i - 1)
			-- the leader's gold pip: the leader comes first
			if i == 1 then
				local pip = Instance.new("Frame")
				pip.Name = "LeaderPip"
				pip.BorderSizePixel = 0
				pip.BackgroundColor3 = Chunky.gold
				pip.ZIndex = 8
				Chunky.put(sheet, pip, bx + 14, rowY + 13, 20, 20)
				Chunky.round(pip, 10)
				Chunky.outline(pip, 3)
			end
			local line = Chunky.text(
				canvas,
				member.DisplayName:upper(),
				if member == player then Chunky.ink else Chunky.inkSoft,
				0
			)
			line.Name = `Member{i}`
			line.Position = UDim2.fromScale((bx + 44) / sheet.w, (rowY + 6) / sheet.h)
			line.Size = UDim2.fromScale((BUTTON_W - 58) / sheet.w, (rowH - 12) / sheet.h)
			line.TextXAlignment = Enum.TextXAlignment.Left
			line.ZIndex = 8
		end
	end

	task.spawn(function()
		while gui.Parent do
			local shown = free()
			gui.Enabled = shown
			if shown then
				local upright = gui.AbsoluteSize.Y > gui.AbsoluteSize.X
				if built ~= `{upright}|{signature()}` then
					build()
				end
			end
			if panelOpen then
				if not shown then
					PartyScreen.close()
				elseif drawnFor ~= signature() then
					draw(false)
				end
			end
			task.wait(0.25)
		end
	end)
end

--[[ The news line across the top: one line at a time, in turn. ]]
local function startNews(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PartyNews"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over the party panel and the invite prompt
	gui.DisplayOrder = 146
	gui.Enabled = false
	gui.Parent = playerGui
	local queue: { string } = {}
	local showing = false

	local function show(text: string)
		gui:ClearAllChildren()
		local size = gui.AbsoluteSize
		local wPt = math.min(440, math.max(size.X - 32, 200))
		local hPt = 48
		local frame = Instance.new("Frame")
		frame.Name = "Line"
		frame.BackgroundTransparency = 1
		frame.AnchorPoint = Vector2.new(0.5, 0)
		-- under the wallet's pills on a phone
		frame.Position = UDim2.new(0.5, 0, 0, 60)
		frame.Size = UDim2.fromOffset(wPt, hPt)
		frame.Parent = gui
		local sheet = Chunky.pointSheet(frame, wPt, hPt)
		Chunky.card(sheet, 0, 0, wPt * 2, hPt * 2)
		local t = Chunky.text(frame, text, Chunky.ink, 0)
		t.Position, t.Size = UDim2.fromScale(0.05, 0.22), UDim2.fromScale(0.9, 0.56)
		t.ZIndex = 8
		gui.Enabled = true
		Chunky.pop(frame)
	end

	Remotes.event(Remotes.PartyNews).OnClientEvent:Connect(function(text: unknown)
		if type(text) ~= "string" then
			return
		end
		table.insert(queue, text)
		if showing then
			return
		end
		showing = true
		task.spawn(function()
			while #queue > 0 do
				show(table.remove(queue, 1) :: string)
				task.wait(NEWS_SECONDS)
			end
			gui.Enabled = false
			gui:ClearAllChildren()
			showing = false
		end)
	end)
end

function PartyScreen.start()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	for _, name in { "PartyPanel", "PartyButton", "PartyNews" } do
		local old = playerGui:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PartyPanel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over the lobby HUD (110), under the store's offers and the invite prompt
	gui.DisplayOrder = 130
	gui.Enabled = false
	gui.Parent = playerGui
	panelGui = gui
	startButton(playerGui)
	startNews(playerGui)
end

return PartyScreen
