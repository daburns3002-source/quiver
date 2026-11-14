--!strict
--[[
	The STORE (`Config/RobuxStore`, owner 2026-11-13): what the game sells for
	Robux, opened by the + beside the lobby's gem pill (`UI/LobbyHud`) and by
	a locked PET 3 on the gear sheet.

	A chunky panel in the Lagoon look (`UI/Chunky`, `Config/UiPalette`) with
	two tabs: GEMS (the starter pack until it is bought, and the five gem
	packs) and PASSES (2x Coins, Extra Pet Slot, VIP). Each is a card: its
	picture, what it gives with the one coin and one diamond beside the
	numbers (CLAUDE.md rule 15), and a green button with its Robux price. A
	pass owned says OWNED; one the dashboard has not got yet says SOON.
	Three cards across on a wide screen, two on an upright phone.

	It decides nothing. BUY sends `Remotes.StoreBuy`; the server opens
	Roblox's prompt and grants on Roblox's receipt (`Server/Data/Purchases`,
	`Server/Data/Passes`). When a grant lands (`Remotes.StoreGranted`) or a
	pass bought here turns up, a thank-you shows at the top of the screen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RobuxConfig = require(ReplicatedStorage.Shared.Config.RobuxStore)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)

local Chunky = require(script.Parent.Chunky)
local FirstTips = require(script.Parent.FirstTips)
local Kit = require(script.Parent.Kit)

local RobuxStore = {}

--[[ The panel's width in points, wide and upright, and its clearance. ]]
local WIDE = 620
local TALL = 380
local MARGIN = 12
--[[ Roblox's own Robux sign, which every font draws. ]]
RobuxStore.ROBUX = utf8.char(0xE002)

export type Chip = { icon: string, words: string }
type Offer = {
	key: string,
	title: string,
	chips: { Chip },
	line: string?,
	icon: string,
	robux: number,
	state: "buy" | "owned" | "soon",
	flag: string?,
}

local gui: ScreenGui? = nil
local toastGui: ScreenGui? = nil
local profile: SaveSchema.Profile? = nil
local isOpen = false
local tab = "GEMS"
--[[ A pass whose prompt this screen opened, for its thank-you. ]]
local askedPass: string? = nil

--[[ "<robux sign> 199". ]]
function RobuxStore.price(robux: number): string
	return `{RobuxStore.ROBUX} {Chunky.commas(robux)}`
end

--[[ The passes this player owns, as the server shows them. ]]
function RobuxStore.owned(): StoreRules.Owned
	local player = Players.LocalPlayer
	local out: StoreRules.Owned = {}
	for _, pass in RobuxConfig.passes do
		if player:GetAttribute(RobuxConfig.passAttribute .. pass.key) == true then
			out[pass.key] = true
		end
	end
	return out
end

--[[ A product's picture: its own icon once uploaded, else the game's own
     pictures (the diamond, the Mossy Egg, the heart). ]]
function RobuxStore.art(product: RobuxConfig.Product): string
	if product.art == "gem" then
		return ShopAssets.gem
	end
	if product.icon and product.icon ~= "" then
		return product.icon
	end
	if product.art == "starter" then
		return GearAssets.eggs.MossyEgg.whole
	end
	return GearAssets.uiIcons.heart
end

--[[ What a product gives, as pictures beside numbers. ]]
function RobuxStore.chips(product: RobuxConfig.Product): { Chip }
	local out: { Chip } = {}
	if product.gems then
		table.insert(out, { icon = ShopAssets.gem, words = Chunky.commas(product.gems) })
	end
	local eggs: { RobuxConfig.Egg } = product.eggs or {}
	for _, egg in eggs do
		local look = GearAssets.eggs[egg.key]
		table.insert(out, { icon = if look then look.whole else "", words = `x{egg.count}` })
	end
	if product.coins then
		table.insert(out, { icon = ShopAssets.coin, words = Chunky.commas(product.coins) })
	end
	return out
end

local function passChips(pass: RobuxConfig.Pass): { Chip }
	local out: { Chip } = {}
	if pass.coinBonus then
		local words = if pass.coinBonus >= 1
			then `x{1 + pass.coinBonus}`
			else `+{math.round(pass.coinBonus * 100)}%`
		table.insert(out, { icon = ShopAssets.coin, words = words })
	end
	if pass.dailyGems then
		table.insert(out, { icon = ShopAssets.gem, words = `{pass.dailyGems} A DAY` })
	end
	return out
end

local PASS_LINES: { [string]: string } = {
	DoubleCoins = "Every kill and clear",
	PetSlot = "Take 3 pets into every run",
	VIP = "Gold name tag",
}

local function offers(): { Offer }
	local out: { Offer } = {}
	if tab == "PASSES" then
		local owned = RobuxStore.owned()
		for _, pass in RobuxConfig.passes do
			table.insert(out, {
				key = pass.key,
				title = string.upper(pass.name),
				chips = passChips(pass),
				line = PASS_LINES[pass.key],
				icon = pass.icon,
				robux = pass.robux,
				state = if owned[pass.key]
					then "owned"
					elseif StoreRules.live(pass) then "buy"
					else "soon",
				flag = nil,
			})
		end
		return out
	end
	local p = profile
	for _, product in StoreRules.shelf(if p then p.purchases else nil) do
		local starter = product.art == "starter"
		table.insert(out, {
			key = product.key,
			title = if starter then "STARTER PACK" else Chunky.commas(product.gems or 0),
			chips = if starter then RobuxStore.chips(product) else {},
			line = if starter then "Once per player" else product.name,
			icon = RobuxStore.art(product),
			robux = product.robux,
			state = if StoreRules.live(product) then "buy" else "soon",
			flag = if starter then "BEST DEAL" else product.flag,
		})
	end
	return out
end

--[[ A row of pictures beside numbers, centred in `parent` (a strip). ]]
function RobuxStore.chipRow(parent: GuiObject, chips: { Chip }, z: number)
	local row = Instance.new("Frame")
	row.Name = "Chips"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = z
	row.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0.03, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local share = 1 / math.max(#chips, 1)
	for n, chip in chips do
		local pair = Instance.new("Frame")
		pair.BackgroundTransparency = 1
		pair.LayoutOrder = n
		pair.Size = UDim2.fromScale(share * 0.94, 1)
		pair.ZIndex = z
		pair.Parent = row
		local picture = Kit.image(pair, chip.icon)
		picture.Size = UDim2.fromScale(1, 1)
		picture.ZIndex = z + 1
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = picture
		local words = Chunky.text(pair, chip.words, Chunky.ink, 0)
		words.AnchorPoint = Vector2.new(1, 0)
		words.Position, words.Size = UDim2.fromScale(1, 0.1), UDim2.fromScale(0.62, 0.8)
		words.TextXAlignment = Enum.TextXAlignment.Left
		words.ZIndex = z + 1
	end
end

local function close()
	isOpen = false
	local screen = gui
	if screen then
		screen.Enabled = false
		screen:ClearAllChildren()
	end
end

local function card(sheet: Chunky.Sheet, offer: Offer, x: number, y: number, w: number, h: number)
	local c = Chunky.card(sheet, x, y, w, h)
	c.Name = offer.key
	if offer.flag then
		local flag = Instance.new("Frame")
		flag.Name = "Flag"
		flag.BorderSizePixel = 0
		flag.BackgroundColor3 = Chunky.gold
		flag.ZIndex = 8
		flag.AnchorPoint = Vector2.new(0.5, 0.5)
		flag.Position, flag.Size = UDim2.fromScale(0.5, 0), UDim2.fromScale(0.7, 0.09)
		flag.Parent = c
		Chunky.light(flag, Chunky.gold)
		Chunky.round(flag, 14)
		Chunky.outline(flag, 4, Chunky.face(Chunky.gold).edge)
		local words = Chunky.textOn(flag, offer.flag, Chunky.gold, 3)
		words.Position, words.Size = UDim2.fromScale(0.08, 0.14), UDim2.fromScale(0.84, 0.72)
		words.ZIndex = 9
	end
	local picture = Kit.image(c, offer.icon)
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position, picture.Size = UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.8, 0.36)
	picture.ZIndex = 6
	local title = Chunky.text(c, offer.title, Chunky.ink, 0)
	title.Position, title.Size = UDim2.fromScale(0.06, 0.45), UDim2.fromScale(0.88, 0.11)
	title.ZIndex = 6
	local nextY = 0.57
	if #offer.chips > 0 then
		local strip = Instance.new("Frame")
		strip.BackgroundTransparency = 1
		strip.Position, strip.Size = UDim2.fromScale(0.05, nextY), UDim2.fromScale(0.9, 0.09)
		strip.ZIndex = 6
		strip.Parent = c
		RobuxStore.chipRow(strip, offer.chips, 6)
		nextY += 0.1
	end
	if offer.line then
		local line = Chunky.text(c, offer.line, Chunky.inkSoft, 0)
		line.Position, line.Size = UDim2.fromScale(0.06, nextY), UDim2.fromScale(0.88, 0.07)
		line.ZIndex = 6
	end
	local bh = h * 0.18
	local words = if offer.state == "owned"
		then "OWNED"
		elseif offer.state == "soon" then "SOON"
		else RobuxStore.price(offer.robux)
	Chunky.button(
		sheet,
		words,
		if offer.state == "buy" then Chunky.green else Chunky.grey,
		x + w * 0.08,
		y + h - bh - h * 0.05,
		w * 0.84,
		bh,
		function()
			if offer.state ~= "buy" then
				return
			end
			if tab == "PASSES" then
				askedPass = offer.key
			end
			Remotes.event(Remotes.StoreBuy):FireServer(offer.key, "Store")
		end
	)
end

local function draw(): Frame?
	local screen = gui
	if not screen then
		return nil
	end
	screen:ClearAllChildren()
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local upright = view.Y > view.X
	local width = if upright then TALL else WIDE
	local columns = if upright then 2 else 3
	local list = offers()
	local rows = math.ceil(#list / columns)
	-- laid out in sheet pixels, two to a point
	local w = width * 2
	local pad, gap = 30, 22
	local header = 104
	local tabsTop, tabsH = header + 20, 84
	local gridTop = tabsTop + tabsH + 26
	local cardW = (w - 2 * pad - (columns - 1) * gap) / columns
	local cardH = math.floor(cardW * 1.22)
	local h = gridTop + rows * (cardH + gap) + 24 + 12
	local fit = RunHudRules.fit(view, width, h / 2, MARGIN)

	local shade = Instance.new("TextButton")
	shade.Name = "Shade"
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = screen

	local box = Instance.new("Frame")
	box.Name = "Store"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(width * fit, h / 2 * fit)
	box.Parent = screen
	local sheet = Chunky.pointSheet(box, width, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "STORE", 0, 0, w, header)
	Chunky.close(sheet, 0, 0, 0, close)

	local tabs = { "GEMS", "PASSES" }
	local tabW = (w - 2 * pad - gap) / #tabs
	for i, name in tabs do
		Chunky.tab(
			sheet,
			name,
			tab == name,
			pad + (i - 1) * (tabW + gap),
			tabsTop,
			tabW,
			tabsH,
			function()
				if tab ~= name then
					tab = name
					draw()
				end
			end
		)
	end

	for n, offer in list do
		local column = (n - 1) % columns
		local row = (n - 1) // columns
		card(
			sheet,
			offer,
			pad + column * (cardW + gap),
			gridTop + row * (cardH + gap),
			cardW,
			cardH
		)
	end
	screen.Enabled = true
	return box
end

--[[ Opens the STORE on `which` tab ("GEMS" or "PASSES"; GEMS if none). ]]
function RobuxStore.open(which: string?)
	if which == "GEMS" or which == "PASSES" then
		tab = which
	end
	isOpen = true
	local box = draw()
	if box then
		Chunky.pop(box)
	end
	FirstTips.show("Store")
end

function RobuxStore.isOpen(): boolean
	return isOpen
end

--[[ A thank-you across the top of the screen for a moment: `title` and
     what came, as pictures beside numbers. ]]
function RobuxStore.toast(title: string, chips: { Chip })
	local screen = toastGui
	if not screen then
		return
	end
	screen:ClearAllChildren()
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local width, height = 300, 92
	local fit = RunHudRules.fit(view, width, height, MARGIN)
	local box = Instance.new("Frame")
	box.Name = "Toast"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 64)
	box.Size = UDim2.fromOffset(width * fit, height * fit)
	box.Parent = screen
	local sheet = Chunky.pointSheet(box, width, height)
	Chunky.panel(sheet, 0, 0, width * 2, height * 2 - 12)
	local words = Chunky.text(box, title, Chunky.ink, 0)
	words.Position, words.Size = UDim2.fromScale(0.08, 0.1), UDim2.fromScale(0.84, 0.36)
	words.ZIndex = 6
	if #chips > 0 then
		local strip = Instance.new("Frame")
		strip.BackgroundTransparency = 1
		strip.Position, strip.Size = UDim2.fromScale(0.1, 0.5), UDim2.fromScale(0.8, 0.34)
		strip.ZIndex = 6
		strip.Parent = box
		RobuxStore.chipRow(strip, chips, 6)
	end
	screen.Enabled = true
	Chunky.pop(box)
	Chunky.burst(box)
	task.delay(2.6, function()
		if box.Parent then
			box:Destroy()
		end
	end)
end

local function onGranted(key: unknown, gems: unknown)
	local amount = if type(gems) == "number" then gems else 0
	if key == "VIPDaily" then
		RobuxStore.toast("VIP GEMS", { { icon = ShopAssets.gem, words = `+{amount}` } })
		return
	end
	local product = StoreRules.product(key)
	if not product or product.revive then
		return
	end
	RobuxStore.toast("THANK YOU!", RobuxStore.chips(product))
end

function RobuxStore.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	for _, name in { "RobuxStore", "StoreToast" } do
		local existing = playerGui:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "RobuxStore"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over the lobby HUD (110) and the station screens, under a prize (150)
	screen.DisplayOrder = 120
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen
	local toast = Instance.new("ScreenGui")
	toast.Name = "StoreToast"
	toast.ResetOnSpawn = false
	toast.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	toast.DisplayOrder = 160
	toast.Enabled = false
	toast.Parent = playerGui
	toastGui = toast

	Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(next_)
		profile = next_
		if isOpen then
			draw()
		end
	end)
	Remotes.event(Remotes.StoreGranted).OnClientEvent:Connect(onGranted)
	for _, pass in RobuxConfig.passes do
		local attribute = RobuxConfig.passAttribute .. pass.key
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if player:GetAttribute(attribute) == true and askedPass == pass.key then
				askedPass = nil
				RobuxStore.toast(
					"THANK YOU!",
					{ { icon = pass.icon, words = string.upper(pass.name) } }
				)
			end
			if isOpen then
				draw()
			end
		end)
	end
	--[[ A run starting shuts it: there is nothing to buy mid-fight. ]]
	Workspace:GetAttributeChangedSignal("InLobby"):Connect(function()
		if Workspace:GetAttribute("InLobby") ~= true then
			close()
		end
	end)
end

return RobuxStore
