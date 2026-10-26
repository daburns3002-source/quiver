--!strict
--[[
	The Blacksmith's weapon shop (owner, 2026-10-25; `Config/Shop`), opened
	at the lobby's Blacksmith: walk up to it and press SHOP (or E).

	- **CRATES**: one per area, for coins. Opening one asks the server
	  (`Remotes.ShopOpenCrate`), which rolls it; the answer plays the reveal:
	  the crate shakes, bursts, and the weapon pops out in its rarity's
	  colour (a Mythic's glow turning round the rainbow, rule 12), NEW! or
	  the coins paid back for one already owned. Areas with no weapons yet
	  are black silhouettes.
	- **STORE**: an area's weapons for gems; its Legendaries for coins and
	  its boss's item.
	- **MY WEAPONS**: every weapon, the ones not owned yet as black
	  silhouettes; EQUIP holds one in runs (its class with it).

	Everything shown comes from the server's profile (`Remotes.ProfileChanged`);
	the screen only asks. Weapon pictures are the 2D Codex art (rule 14);
	every word is in the blocky font (rule 11). Buttons stay still until
	hovered or pressed, as the intro's does.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Purse = require(ReplicatedStorage.Shared.Util.Purse)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)

local Device = require(script.Parent.Parent.Device)

local ShopScreen = {}

local FONT = Font.fromEnum(Enum.Font.Arcade)
local INK = Color3.fromRGB(24, 16, 10)
local WOOD = Color3.fromRGB(78, 52, 32)
local WOOD_LIGHT = Color3.fromRGB(112, 78, 48)
local PLANK = Color3.fromRGB(58, 38, 24)
local GOLD = Color3.fromRGB(255, 206, 74)
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(70, 176, 58)
local GREY = Color3.fromRGB(96, 92, 88)
--[[ Studs from the Blacksmith's centre within which SHOP shows: past its
     front, where its smith sits, now the lobby is twice the size. ]]
local REACH = 28

-- "Crates", "Store" or "Weapons"
type Tab = string
type Button =
	{ frame: Frame, button: TextButton, label: TextLabel, colour: Color3, enabled: boolean }

local profile: SaveSchema.Profile? = nil
local gui: ScreenGui? = nil
local panel: Frame? = nil
local content: ScrollingFrame? = nil
local walletRow: Frame? = nil
local hud: Frame? = nil
local prompt: Frame? = nil
local tabButtons: { [Tab]: Button } = {}
local current: Tab = "Crates"
local reveal: Frame? = nil
local buttons: { Button } = {}

local function rect(parent: Instance, name: string, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function label(
	parent: Instance,
	text: string,
	colour: Color3,
	z: number,
	maxSize: number?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.Text = text
	l.TextColor3 = colour
	l.TextScaled = true
	l.ZIndex = z
	l.Parent = parent
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = maxSize or 28
	fit.Parent = l
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Parent = l
	return l
end

local function image(parent: Instance, id: string, z: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = id
	i.ScaleType = Enum.ScaleType.Fit
	i.ZIndex = z
	i.Parent = parent
	return i
end

--[[ A blocky box: an ink border round a face, with a lighter top edge. ]]
local function box(parent: Instance, name: string, face: Color3, z: number): Frame
	local outer = rect(parent, name, INK, z)
	local inner = rect(outer, "Face", face, z + 1)
	inner.Position = UDim2.fromOffset(3, 3)
	inner.Size = UDim2.new(1, -6, 1, -6)
	local top = rect(inner, "Shine", face:Lerp(WHITE, 0.25), z + 1)
	top.Size = UDim2.new(1, 0, 0, 3)
	return outer
end

--[[ A blocky button that only reacts when hovered (brighter, a little
     larger) or pressed (darker, pressed in). ]]
local function makeButton(parent: Instance, text: string, colour: Color3, z: number): Button
	local frame = box(parent, "Button", colour, z)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local words = label(frame, text, WHITE, z + 3, 22)
	words.Size = UDim2.fromScale(0.86, 0.6)
	words.Position = UDim2.fromScale(0.07, 0.2)
	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = z + 4
	button.AutoButtonColor = false
	button.Parent = frame
	local made: Button =
		{ frame = frame, button = button, label = words, colour = colour, enabled = true }
	table.insert(buttons, made)
	return made
end

local function setButton(b: Button, text: string, colour: Color3, enabled: boolean)
	b.label.Text = text
	b.colour = colour
	b.enabled = enabled
end

local function poseButtons()
	for _, b in buttons do
		if not b.frame.Parent then
			continue
		end
		local state = b.button.GuiState
		local face = b.frame:FindFirstChild("Face") :: Frame?
		local scale = b.frame:FindFirstChildOfClass("UIScale")
		local colour = if b.enabled then b.colour else GREY
		local look = 1
		if b.enabled and state == Enum.GuiState.Press then
			colour = colour:Lerp(Color3.new(0, 0, 0), 0.3)
			look = 0.95
		elseif
			b.enabled and (state == Enum.GuiState.Hover or GuiService.SelectedObject == b.button)
		then
			colour = colour:Lerp(WHITE, 0.2)
			look = 1.05
		end
		if face then
			face.BackgroundColor3 = colour
		end
		if scale then
			scale.Scale = look
		end
	end
end

local function rarityColour(name: string): Color3
	local r = Rarities.byName[name]
	return if r then r.color else WHITE
end

--[[ A small price: an icon and a number per part (coins, gems, items). ]]
local function priceRow(parent: Instance, cost: Purse.Cost, z: number)
	local row = Instance.new("Frame")
	row.Name = "Price"
	row.BackgroundTransparency = 1
	row.ZIndex = z
	row.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = row
	local function part(icon: string, amount: number, times: boolean?)
		local i = image(row, icon, z)
		i.Size = UDim2.fromScale(0.2, 1)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = i
		local n = label(row, if times then `x{amount}` else tostring(amount), WHITE, z, 20)
		n.AutomaticSize = Enum.AutomaticSize.X
		n.Size = UDim2.fromScale(0, 0.8)
		n.TextScaled = false
		n.TextSize = 18
	end
	if cost.coins then
		part(ShopAssets.coin, cost.coins)
	end
	if cost.gems then
		part(ShopAssets.gem, cost.gems)
	end
	local items: { [string]: number } = cost.items or {}
	for id, n in items do
		part(ShopAssets.items[id] or ShopAssets.lock, n, true)
	end
	return row
end

--[[ One card: a picture, a name, a line, and a button. ]]
local function card(
	name: string,
	picture: string,
	silhouette: boolean,
	colour: Color3
): (Frame, Button)
	local holder = box(content :: ScrollingFrame, name, PLANK, 10)
	local stripe = rect(holder:FindFirstChild("Face") :: Frame, "Rarity", colour, 12)
	stripe.Size = UDim2.new(1, 0, 0, 6)
	stripe.Position = UDim2.fromOffset(0, 3)
	local pic = image(holder, picture, 13)
	pic.Name = "Picture"
	pic.Position = UDim2.fromScale(0.1, 0.06)
	pic.Size = UDim2.fromScale(0.8, 0.5)
	if silhouette then
		pic.ImageColor3 = Color3.new(0, 0, 0)
	end
	local b = makeButton(holder, "", GREEN, 14)
	b.frame.Position = UDim2.fromScale(0.1, 0.8)
	b.frame.Size = UDim2.fromScale(0.8, 0.15)
	return holder, b
end

local function cardText(holder: Frame, title: string, colour: Color3)
	local t = label(holder, title, colour, 13, 18)
	t.Name = "Title"
	t.Position = UDim2.fromScale(0.05, 0.57)
	t.Size = UDim2.fromScale(0.9, 0.1)
end

local fillTab: (Tab) -> ()

local function openCrate(index: number)
	Remotes.event(Remotes.ShopOpenCrate):FireServer(index)
end

local function fillCrates()
	local p = profile
	for index, crate in Shop.crates do
		local pool = ShopRules.cratePool(index)
		local empty = #pool == 0
		local picture = ShopAssets.crates[crate.area] or ShopAssets.crates.MossyGlade
		local holder, b = card(`Crate{index}`, picture, empty, if empty then GREY else GOLD)
		holder.LayoutOrder = index
		cardText(holder, if empty then "???" else crate.name, if empty then GREY else GOLD)
		local price = priceRow(holder, { coins = crate.price }, 13)
		price.Position = UDim2.fromScale(0.1, 0.68)
		price.Size = UDim2.fromScale(0.8, 0.09)
		if empty then
			setButton(b, "SOON", GREY, false)
		else
			local can = p ~= nil and p.coins >= crate.price
			setButton(b, "OPEN", GREEN, can)
			b.button.Activated:Connect(function()
				if b.enabled and not reveal then
					openCrate(index)
				end
			end)
		end
	end
end

local function fillStore()
	local p = profile
	local order = 0
	for _, entry in ShopRules.catalog() do
		local price = ShopRules.price(entry)
		if not price then
			continue
		end
		order += 1
		local owned = p ~= nil and p.weapons[entry.weapon] == true
		local holder, b = card(
			entry.weapon,
			ShopAssets.weapons[entry.weapon] or "",
			false,
			rarityColour(entry.rarity)
		)
		holder.LayoutOrder = order
		cardText(holder, entry.label, rarityColour(entry.rarity))
		local row = priceRow(holder, price, 13)
		row.Position = UDim2.fromScale(0.05, 0.68)
		row.Size = UDim2.fromScale(0.9, 0.09)
		if owned then
			setButton(b, "OWNED", GREY, false)
		else
			setButton(b, "BUY", GREEN, p ~= nil and Purse.canAfford(p, price))
			b.button.Activated:Connect(function()
				if b.enabled then
					Remotes.event(Remotes.ShopBuy):FireServer(entry.weapon)
				end
			end)
		end
	end
end

local function fillWeapons()
	local p = profile
	for order, entry in ShopRules.catalog() do
		local owned = p ~= nil and p.weapons[entry.weapon] == true
		local colour = if owned then rarityColour(entry.rarity) else GREY
		local holder, b =
			card(entry.weapon, ShopAssets.weapons[entry.weapon] or "", not owned, colour)
		holder.LayoutOrder = order
		cardText(holder, if owned then entry.label else "???", colour)
		local tag = label(holder, string.upper(entry.rarity), colour, 13, 14)
		tag.Position = UDim2.fromScale(0.1, 0.68)
		tag.Size = UDim2.fromScale(0.8, 0.08)
		local equipped = p ~= nil
			and (p.equipped == entry.weapon or (p.equipped == nil and entry.weapon == "TwigBow"))
		if not owned then
			setButton(b, "LOCKED", GREY, false)
		elseif equipped then
			setButton(b, "EQUIPPED", GOLD, false)
		else
			setButton(b, "EQUIP", GREEN, true)
			b.button.Activated:Connect(function()
				Remotes.event(Remotes.ShopEquip):FireServer(entry.weapon)
			end)
		end
	end
end

local function fillWallet()
	local row = walletRow
	if not row then
		return
	end
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local p = profile
	local parts: { { icon: string, n: number } } = {
		{ icon = ShopAssets.coin, n = if p then p.coins else 0 },
		{ icon = ShopAssets.gem, n = if p then p.gems else 0 },
	}
	for id in Economy.items do
		table.insert(parts, {
			icon = ShopAssets.items[id] or ShopAssets.lock,
			n = if p then p.items[id] or 0 else 0,
		})
	end
	for i, part in parts do
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.LayoutOrder = i
		cell.Size = UDim2.fromScale(0.24, 1)
		cell.ZIndex = 8
		cell.Parent = row
		local icon = image(cell, part.icon, 9)
		icon.Size = UDim2.fromScale(0.36, 1)
		local n = label(cell, tostring(part.n), WHITE, 9, 22)
		n.Position = UDim2.fromScale(0.38, 0.15)
		n.Size = UDim2.fromScale(0.62, 0.7)
		n.TextXAlignment = Enum.TextXAlignment.Left
	end
end

fillTab = function(tab: Tab)
	current = tab
	local c = content
	if not c then
		return
	end
	for _, child in c:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- forget the destroyed cards' buttons
	for i = #buttons, 1, -1 do
		if not buttons[i].frame.Parent then
			table.remove(buttons, i)
		end
	end
	local grid = c:FindFirstChildOfClass("UIGridLayout")
	if grid then
		local phone = Device.isPhone()
		grid.CellSize = if tab == "Crates"
			then UDim2.new(if phone then 0.48 else 0.315, 0, 0, if phone then 250 else 330)
			else UDim2.new(if phone then 0.31 else 0.155, 0, 0, if phone then 190 else 230)
	end
	if tab == "Crates" then
		fillCrates()
	elseif tab == "Store" then
		fillStore()
	else
		fillWeapons()
	end
	for name, b in tabButtons do
		setButton(b, b.label.Text, if name == tab then GOLD else WOOD_LIGHT, true)
	end
	fillWallet()
end

local function updateHud()
	local h = hud
	if not h then
		return
	end
	local p = profile
	local coins = h:FindFirstChild("Coins") :: TextLabel?
	local gems = h:FindFirstChild("Gems") :: TextLabel?
	if coins then
		coins.Text = tostring(if p then p.coins else 0)
	end
	if gems then
		gems.Text = tostring(if p then p.gems else 0)
	end
end

local function build(playerGui: PlayerGui)
	local phone = Device.isPhone()
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShopScreen"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.DisplayOrder = 115
	-- each piece over its parent (this place defaults to Global)
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	gui = screen

	-- the wallet, top right, in the lobby
	local h = box(screen, "Wallet", WOOD, 2)
	h.AnchorPoint = Vector2.new(1, 0)
	h.Position = UDim2.new(1, -12, 0, 12)
	h.Size = UDim2.fromOffset(if phone then 200 else 240, if phone then 40 else 46)
	local coinIcon = image(h, ShopAssets.coin, 4)
	coinIcon.Size = UDim2.fromScale(0.16, 0.8)
	coinIcon.Position = UDim2.fromScale(0.03, 0.1)
	local coins = label(h, "0", WHITE, 4, 22)
	coins.Name = "Coins"
	coins.Position = UDim2.fromScale(0.2, 0.2)
	coins.Size = UDim2.fromScale(0.3, 0.6)
	coins.TextXAlignment = Enum.TextXAlignment.Left
	local gemIcon = image(h, ShopAssets.gem, 4)
	gemIcon.Size = UDim2.fromScale(0.16, 0.8)
	gemIcon.Position = UDim2.fromScale(0.52, 0.1)
	local gems = label(h, "0", WHITE, 4, 22)
	gems.Name = "Gems"
	gems.Position = UDim2.fromScale(0.69, 0.2)
	gems.Size = UDim2.fromScale(0.3, 0.6)
	gems.TextXAlignment = Enum.TextXAlignment.Left
	h.Visible = false
	hud = h

	-- SHOP, by the Blacksmith
	local pr = Instance.new("Frame")
	pr.Name = "Prompt"
	pr.BackgroundTransparency = 1
	pr.AnchorPoint = Vector2.new(0.5, 1)
	pr.Position = UDim2.new(0.5, 0, 1, -24)
	pr.Size = UDim2.fromOffset(if phone then 200 else 240, if phone then 56 else 62)
	pr.Visible = false
	pr.Parent = screen
	local open = makeButton(
		pr,
		if UserInputService.KeyboardEnabled and not phone then "SHOP [E]" else "SHOP",
		GOLD,
		5
	)
	open.frame.Size = UDim2.fromScale(1, 1)
	open.button.Activated:Connect(function()
		ShopScreen.open()
	end)
	prompt = pr

	local dim = rect(screen, "Dim", Color3.new(0, 0, 0), 20)
	dim.BackgroundTransparency = 0.45
	dim.Size = UDim2.new(1, 0, 1, 200)
	dim.Position = UDim2.fromOffset(0, -100)
	dim.Active = true
	dim.Visible = false

	local p = box(screen, "Panel", WOOD, 21)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.5)
	p.Size = UDim2.fromScale(if phone then 0.97 else 0.86, if phone then 0.95 else 0.86)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1180, 720)
	limit.Parent = p
	p.Visible = false
	panel = p

	local title = label(p, "BLACKSMITH", GOLD, 24, 40)
	title.Position = UDim2.fromScale(0.03, 0.02)
	title.Size = UDim2.fromScale(0.36, 0.08)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local row = Instance.new("Frame")
	row.Name = "WalletRow"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromScale(0.42, 0.025)
	row.Size = UDim2.fromScale(0.48, 0.07)
	row.ZIndex = 24
	row.Parent = p
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Padding = UDim.new(0.01, 0)
	rowList.Parent = row
	walletRow = row

	local close = makeButton(p, "X", Color3.fromRGB(196, 64, 52), 24)
	close.frame.AnchorPoint = Vector2.new(1, 0)
	close.frame.Position = UDim2.new(1, -10, 0, 10)
	close.frame.Size = UDim2.fromScale(0.06, 0.08)
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = close.frame
	close.button.Activated:Connect(function()
		ShopScreen.close()
	end)

	local TABS: { { tab: Tab, words: string } } = {
		{ tab = "Crates", words = "CRATES" },
		{ tab = "Store", words = "STORE" },
		{ tab = "Weapons", words = "MY WEAPONS" },
	}
	for i, entry in TABS do
		local tab, words = entry.tab, entry.words
		local b = makeButton(p, words, WOOD_LIGHT, 24)
		b.frame.Name = `Tab{tab}`
		b.frame.Position = UDim2.fromScale(0.03 + (i - 1) * 0.215, 0.12)
		b.frame.Size = UDim2.fromScale(0.2, 0.08)
		b.button.Activated:Connect(function()
			fillTab(tab)
		end)
		tabButtons[tab] = b
	end

	local c = Instance.new("ScrollingFrame")
	c.Name = "Content"
	c.BackgroundColor3 = PLANK:Lerp(INK, 0.4)
	c.BorderSizePixel = 0
	c.Position = UDim2.fromScale(0.03, 0.22)
	c.Size = UDim2.fromScale(0.94, 0.74)
	c.ScrollBarThickness = 8
	c.ScrollBarImageColor3 = GOLD
	c.AutomaticCanvasSize = Enum.AutomaticSize.Y
	c.CanvasSize = UDim2.new()
	c.ScrollingDirection = Enum.ScrollingDirection.Y
	c.ZIndex = 22
	c.Parent = p
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 18)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = c
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(if phone then 0.31 else 0.155, 0, 0, if phone then 190 else 230)
	grid.CellPadding = UDim2.new(0.01, 0, 0, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = c
	content = c
end

--[[ The reveal: the crate shakes, bursts, and the weapon pops out. ]]
local function playReveal(index: number, weapon: string, new: boolean, refund: number)
	local p = panel
	if not p or reveal then
		return
	end
	local entry = ShopRules.find(weapon)
	local rarity = entry and entry.rarity or "Uncommon"
	local colour = rarityColour(rarity)
	local crate = Shop.crates[index]

	local overlay = rect(p, "Reveal", Color3.new(0, 0, 0), 40)
	overlay.BackgroundTransparency = 0.25
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Active = true
	reveal = overlay

	local rays = Instance.new("Frame")
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.42)
	rays.Size = UDim2.fromScale(0.9, 0.9)
	rays.ZIndex = 41
	rays.Visible = false
	rays.Parent = overlay
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = rays
	local beams = {}
	for i = 1, 8 do
		local beam = rect(rays, "Ray", colour, 41)
		beam.AnchorPoint = Vector2.new(0.5, 0.5)
		beam.Position = UDim2.fromScale(0.5, 0.5)
		beam.Size = UDim2.fromScale(0.05, 1)
		beam.Rotation = i * 22.5
		beam.BackgroundTransparency = 0.72
		table.insert(beams, beam)
	end

	local crateImage =
		image(overlay, ShopAssets.crates[crate.area] or ShopAssets.crates.MossyGlade, 43)
	crateImage.AnchorPoint = Vector2.new(0.5, 0.5)
	crateImage.Position = UDim2.fromScale(0.5, 0.42)
	crateImage.Size = UDim2.fromScale(0.42, 0.52)

	local prize = image(overlay, ShopAssets.weapons[weapon] or "", 44)
	prize.AnchorPoint = Vector2.new(0.5, 0.5)
	prize.Position = UDim2.fromScale(0.5, 0.4)
	prize.Size = UDim2.fromScale(0.36, 0.46)
	prize.Visible = false
	local prizeScale = Instance.new("UIScale")
	prizeScale.Parent = prize

	local flash = rect(overlay, "Flash", WHITE, 45)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1

	local name = label(overlay, entry and entry.label or weapon, colour, 46, 40)
	name.Position = UDim2.fromScale(0.1, 0.7)
	name.Size = UDim2.fromScale(0.8, 0.08)
	name.Visible = false
	local tag = label(overlay, string.upper(rarity), colour, 46, 26)
	tag.Position = UDim2.fromScale(0.3, 0.79)
	tag.Size = UDim2.fromScale(0.4, 0.05)
	tag.Visible = false
	local note = label(
		overlay,
		if new then "NEW!" else `ALREADY OWNED  +{refund} COINS`,
		if new then GOLD else WHITE,
		46,
		26
	)
	note.Position = UDim2.fromScale(0.2, 0.855)
	note.Size = UDim2.fromScale(0.6, 0.05)
	note.Visible = false
	local tap = label(overlay, "TAP TO CONTINUE", WHITE, 46, 16)
	tap.Position = UDim2.fromScale(0.3, 0.93)
	tap.Size = UDim2.fromScale(0.4, 0.04)
	tap.Visible = false

	local started = os.clock()
	local SHAKE, BURST = 0.9, 1.05
	local done = false
	local step: RBXScriptConnection
	step = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t < SHAKE then
			local k = t / SHAKE
			crateImage.Rotation = math.sin(t * 40) * 8 * k
			crateImage.Position = UDim2.fromScale(0.5 + math.sin(t * 53) * 0.01 * k, 0.42)
		elseif t < BURST then
			crateImage.Visible = false
			flash.BackgroundTransparency = (t - SHAKE) / (BURST - SHAKE)
		else
			flash.BackgroundTransparency = 1
			rays.Visible = true
			rays.Rotation = t * 20
			prize.Visible = true
			local pop = math.min((t - BURST) / 0.35, 1)
			prizeScale.Scale = 0.2 + 0.8 * (1 + 2.2 * (pop - 1) ^ 3 + 1.2 * (pop - 1) ^ 2)
			name.Visible, tag.Visible, note.Visible = true, true, true
			tap.Visible = t > BURST + 0.6
			-- a Mythic's glow turns round the rainbow (rule 12)
			if rarity == "Mythic" then
				local hue = Color3.fromHSV((t * 0.35) % 1, 0.75, 1)
				for _, beam in beams do
					beam.BackgroundColor3 = hue
				end
				name.TextColor3, tag.TextColor3 = hue, hue
			end
			done = true
		end
	end)
	local closeButton = Instance.new("TextButton")
	closeButton.BackgroundTransparency = 1
	closeButton.Text = ""
	closeButton.Size = UDim2.fromScale(1, 1)
	closeButton.ZIndex = 47
	closeButton.Parent = overlay
	closeButton.Activated:Connect(function()
		if done and os.clock() - started > BURST + 0.6 then
			step:Disconnect()
			overlay:Destroy()
			reveal = nil
			fillTab(current)
		end
	end)
end

local function blacksmithPosition(): Vector3?
	for _, station in LobbyConfig.stations do
		if station.piece == "Blacksmith" then
			return LobbyConfig.origin + Vector3.new(station.at.X, 0, station.at.Y)
		end
	end
	return nil
end

function ShopScreen.isOpen(): boolean
	local p = panel
	return p ~= nil and p.Visible
end

function ShopScreen.open()
	local p = panel
	local screen = gui
	if not p or not screen then
		return
	end
	p.Visible = true
	local dim = screen:FindFirstChild("Dim") :: Frame?
	if dim then
		dim.Visible = true
	end
	fillTab(current)
end

function ShopScreen.close()
	local p = panel
	local screen = gui
	if not p or not screen or reveal then
		return
	end
	p.Visible = false
	local dim = screen:FindFirstChild("Dim") :: Frame?
	if dim then
		dim.Visible = false
	end
end

function ShopScreen.start()
	local player = Players.LocalPlayer
	build(player:WaitForChild("PlayerGui") :: PlayerGui)
	local smith = blacksmithPosition()

	Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(next)
		if type(next) ~= "table" then
			return
		end
		profile = next
		updateHud()
		if ShopScreen.isOpen() and not reveal then
			fillTab(current)
		end
	end)
	Remotes.event(Remotes.ShopCrateOpened).OnClientEvent
		:Connect(function(index, weapon, new, refund)
			if type(index) == "number" and type(weapon) == "string" then
				playReveal(
					index,
					weapon,
					new == true,
					if type(refund) == "number" then refund else 0
				)
			end
		end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local pr = prompt
		if input.KeyCode == Enum.KeyCode.E and pr and pr.Visible and not ShopScreen.isOpen() then
			ShopScreen.open()
		elseif input.KeyCode == Enum.KeyCode.Escape and ShopScreen.isOpen() then
			ShopScreen.close()
		end
	end)

	--[[ Studio only (`Sandbox.openShop`): open by itself the first time the
	     player is in the lobby, past the story cutscene, wallet topped up. ]]
	local autoOpen = if RunService:IsStudio() then Sandbox.openShop else nil
	RunService.RenderStepped:Connect(function()
		poseButtons()
		local fill = autoOpen
		if
			fill
			and Workspace:GetAttribute("InLobby") == true
			and not player.PlayerGui:FindFirstChild("StoryCutscene")
			and not player.PlayerGui:FindFirstChild("IntroCutscene")
		then
			autoOpen = nil
			Remotes.event(Remotes.DebugWallet):FireServer(fill.coins, fill.gems, fill.items)
			ShopScreen.open()
		end
		-- not over the story cutscene that plays in the lobby after BEGIN ADVENTURE
		local story = player.PlayerGui:FindFirstChild("StoryCutscene")
		local inLobby = Workspace:GetAttribute("InLobby") == true and story == nil
		local h = hud
		if h then
			h.Visible = inLobby
		end
		local pr = prompt
		if pr then
			local root = player.Character
				and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local near = inLobby
				and smith ~= nil
				and root ~= nil
				and (Vector3.new(root.Position.X, 0, root.Position.Z) - smith).Magnitude
					<= REACH
			pr.Visible = near == true and not ShopScreen.isOpen()
		end
		if not inLobby and ShopScreen.isOpen() then
			ShopScreen.close()
		end
	end)
end

return ShopScreen
