--!strict
--[[
	The Blacksmith. CRATES is the same stand as the Egg Hatchery's
	(`UI/HatchStand`; owner, 2026-10-27: the weapon chests "changed exactly
	how you are changing the pets and with the same ui"): OPEN 1 and OPEN 3,
	AUTO, the crate picker, every weapon inside with its odds. STORE sells
	the selected area's weapons.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Chunky = require(script.Parent.Chunky)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local Purse = require(ReplicatedStorage.Shared.Util.Purse)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Reveal = require(script.Parent.Reveal)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local StationScreen = require(script.Parent.StationScreen)
local ShopScreen = {}
local screen: StationScreen.Screen? = nil
local selected = 1
local store = false
--[[ Which of the area's three chests is open (owner, 2026-11-01: "It
     should be 3 separate chests"), as an index into `Shop.chests`. ]]
local chest = 1
function ShopScreen.isOpen(): boolean
	return screen ~= nil and screen.isOpen()
end
function ShopScreen.open()
	if screen then
		screen.open()
	end
end
function ShopScreen.close()
	if screen and not Reveal.busy() then
		screen.close()
	end
end
local function priceText(cost: Purse.Cost): string
	-- coins or gems alone read as the number beside their picture on the button
	if next(cost.items or {}) == nil then
		if cost.coins and not cost.gems then
			return Chunky.commas(cost.coins)
		elseif cost.gems and not cost.coins then
			return Chunky.commas(cost.gems)
		end
	end
	local parts = {}
	if cost.coins then
		table.insert(parts, tostring(cost.coins) .. " COINS")
	end
	if cost.gems then
		table.insert(parts, tostring(cost.gems) .. " GEMS")
	end
	for item, count in cost.items or ({} :: { [string]: number }) do
		table.insert(parts, tostring(count) .. " " .. string.upper(item))
	end
	return table.concat(parts, " + ")
end
local function picture(weapon: string): string
	return ShopAssets.weapons[weapon] or GearAssets.weapons[weapon] or ""
end
--[[ The store: the selected area's weapons for sale, as the approved style
     sheet's SHOP rows (owner, 2026-11-05): a white card per weapon with its
     2D art in its rarity's frame, its name and rarity, its price and a fat
     BUY. Two columns across a landscape screen, one upright; the list
     scrolls when the area sells more than fit. ]]
local function drawStore(s: StationScreen.Screen, area: HatchStand.Area)
	local p = s.profile
	local sheet = area.sheet
	local up = sheet.upright
	local function step(direction: number): () -> ()
		return function()
			if not Reveal.busy() then
				selected = (selected - 1 + direction) % #Shop.crates + 1
				s.open()
			end
		end
	end
	-- the area picker across the head of the list
	Chunky.button(sheet, "<", Chunky.blue, area.x, area.y, 100, 84, step(-1))
	Chunky.button(sheet, ">", Chunky.blue, area.x + area.w - 100, area.y, 100, 84, step(1))
	local nameBox = Instance.new("Frame")
	nameBox.BackgroundTransparency = 1
	nameBox.ZIndex = 6
	Chunky.put(sheet, nameBox, area.x + 120, area.y + 4, area.w - 240, 76)
	Chunky.text(nameBox, Shop.crates[selected].name .. " STORE", nil, 6)

	local entries = {}
	for _, entry in ShopRules.catalog() do
		if entry.area == selected and ShopRules.price(entry) then
			table.insert(entries, entry)
		end
	end
	local top = area.y + 104
	local viewW, viewH = area.w, area.bottom - top
	local cols = if up then 1 else 2
	local gap, rowH = 18, 150
	local rows = math.max(math.ceil(#entries / cols), 1)
	local contentH = math.max(viewH, rows * (rowH + gap))
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.ScrollBarImageColor3 = Chunky.navy
	list.CanvasSize = UDim2.fromScale(0, contentH / viewH)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ZIndex = 6
	Chunky.put(sheet, list, area.x, top, viewW, viewH)
	local colW = (viewW - 24 - (cols - 1) * gap) / cols
	local function inList(item: GuiObject, x: number, y: number, w: number, h: number)
		item.Position = UDim2.fromScale(x / viewW, y / contentH)
		item.Size = UDim2.fromScale(w / viewW, h / contentH)
		item.Parent = list
	end
	for n, entry in entries do
		local price = assert(ShopRules.price(entry), "for sale")
		local x = ((n - 1) % cols) * (colW + gap)
		local y = ((n - 1) // cols) * (rowH + gap) + 6
		local owned = p ~= nil and p.weapons[entry.weapon] == true
		local can = p ~= nil and Purse.canAfford(p, price)
		local row = Instance.new("Frame")
		row.BorderSizePixel = 0
		row.BackgroundColor3 = Chunky.white
		row.ZIndex = 6
		inList(row, x, y, colW, rowH)
		Chunky.round(row, 22)
		Chunky.outline(row, 5)
		-- the weapon in its rarity's frame (always the 2D art)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Position, holder.Size =
			UDim2.fromScale(12 / colW, 12 / rowH), UDim2.fromScale(126 / colW, 126 / rowH)
		holder.ZIndex = 7
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = holder
		holder.Parent = row
		Chunky.tile(holder, entry.rarity, picture(entry.weapon), nil, false, owned)
		local nameText = Chunky.text(row, entry.label, Chunky.navy, 0)
		nameText.TextXAlignment = Enum.TextXAlignment.Left
		nameText.Position, nameText.Size =
			UDim2.fromScale(156 / colW, 18 / rowH),
			UDim2.fromScale((colW - 156 - 250) / colW, 56 / rowH)
		local rarityText = Chunky.text(
			row,
			string.upper(entry.rarity),
			Chunky.rarity[entry.rarity] or Chunky.grey,
			3
		)
		rarityText.TextXAlignment = Enum.TextXAlignment.Left
		rarityText.Position, rarityText.Size =
			UDim2.fromScale(156 / colW, 80 / rowH),
			UDim2.fromScale((colW - 156 - 250) / colW, 40 / rowH)
		-- the price on its button; BUY when it can be paid
		local buyHolder = Instance.new("Frame")
		buyHolder.BackgroundTransparency = 1
		buyHolder.ZIndex = 8
		buyHolder.Position, buyHolder.Size =
			UDim2.fromScale((colW - 236) / colW, 30 / rowH), UDim2.fromScale(220 / colW, 96 / rowH)
		buyHolder.Parent = row
		local label = if owned then "OWNED" else priceText(price)
		--[[ The currency's own picture beside the price: the diamond for a
		     gem price, the coin for a coin one (a Legendary's coins and boss
		     item keep the coin, with the rest in words). ]]
		local icon: string? = nil
		if not owned then
			icon = if price.gems and not price.coins then ShopAssets.gem else ShopAssets.coin
		end
		local colour = if owned then Chunky.grey elseif can then Chunky.green else Chunky.grey
		local miniSheet: Chunky.Sheet =
			{ canvas = buyHolder :: any, w = 220, h = 96, upright = false }
		Chunky.button(miniSheet, label, colour, 0, 0, 220, 96, function()
			if owned or not can then
				return
			end
			Reveal.request(function()
				Remotes.event(Remotes.ShopBuy):FireServer(entry.weapon)
			end)
		end, icon)
	end
	if #entries == 0 then
		local empty = Instance.new("Frame")
		empty.BackgroundTransparency = 1
		inList(empty, 0, 40, viewW, 90)
		Chunky.text(empty, "NO WEAPONS YET")
	end
end
function ShopScreen.start()
	if screen then
		return
	end
	local s = StationScreen.new("ShopScreen", "Blacksmith", "SHOP")
	screen = s
	-- the forge fills the whole screen, under Roblox's top bar too (owner,
	-- 2026-10-26), in a layer of its own under the shop's
	local layer = Instance.new("ScreenGui")
	layer.Name = "BlacksmithBackground"
	layer.IgnoreGuiInset = true
	layer.ScreenInsets = Enum.ScreenInsets.None
	layer.ResetOnSpawn = false
	layer.DisplayOrder = s.gui.DisplayOrder - 1
	layer.Enabled = false
	layer.Parent = s.gui.Parent
	local backdrop = Kit.image(layer, GearAssets.backgrounds.blacksmith)
	backdrop.Position, backdrop.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
	backdrop.ScaleType = Enum.ScaleType.Crop
	backdrop.ResampleMode = Enum.ResamplerMode.Default
	--[[ Codex's screens stand on an empty dark background: the area's
	     scene belongs inside the odds panel and nowhere else (owner,
	     2026-10-31, on the full-screen art). The layer stays, because it is
	     what covers Roblox's own top bar; what it carries goes dark. ]]
	--[[ The approved mockups (2026-11-05) stand the panel over the lobby
	     itself, dimmed, rather than over a black screen. ]]
	backdrop.Visible = false
	local veil = Instance.new("Frame")
	veil.BackgroundColor3 = Color3.fromRGB(10, 14, 40)
	veil.BackgroundTransparency = 0.45
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 50
	veil.Parent = layer
	local dim = s.canvas.Parent :: GuiObject
	local function follow()
		layer.Enabled = dim.Visible and GearAssets.backgrounds.blacksmith ~= ""
	end
	s.connect(dim:GetPropertyChangedSignal("Visible"), follow)
	follow()
	s.gui.Destroying:Once(function()
		layer:Destroy()
	end)
	-- whether a press of `count` can open the selected crate now
	local function affordable(count: number): boolean
		local p = s.profile
		return p ~= nil
			and #ShopRules.cratePool(selected, Shop.chests[chest].class) > 0
			and p.coins >= Shop.crates[selected].price * count
	end
	local function press(count: number)
		if affordable(count) then
			local index, class = selected, Shop.chests[chest].class
			Reveal.request(function()
				Remotes.event(Remotes.ShopOpenCrate):FireServer(index, count, class)
			end)
		end
	end
	local control = HatchStand.controller(s, Shop.counts, press, affordable, function()
		return not store
	end)
	s.draw = function()
		local p = s.profile
		-- the Blacksmith's two modes, as tabs along the panel's head
		local modes = {}
		for index, words in { "CRATES", "STORE" } do
			table.insert(modes, {
				words = words,
				on = store == (index == 2),
				pick = function()
					store = index == 2
					control.auto = false
					s.open()
				end,
			})
		end
		if store then
			drawStore(s, HatchStand.chrome(s, "BLACKSMITH", modes))
			return
		end
		local crate = Shop.crates[selected]
		local holds = Shop.chests[chest]
		local pool = table.clone(ShopRules.cratePool(selected, holds.class))
		table.sort(pool, function(a, b)
			local ra, rb = Rarities.byName[a.rarity].tier, Rarities.byName[b.rarity].tier
			if ra ~= rb then
				return ra < rb
			end
			return a.label < b.label
		end)
		local tabs = {}
		for index, each in Shop.chests do
			table.insert(tabs, {
				words = each.tab,
				on = index == chest,
				pick = function()
					chest = index
					s.open()
				end,
			})
		end
		local tiles = {}
		for _, entry in pool do
			local owned = p ~= nil and p.weapons[entry.weapon] == true
			table.insert(tiles, {
				rarity = entry.rarity,
				-- always the 2D weapon art, never a render (owner's standing rule)
				icon = picture(entry.weapon),
				chance = ShopRules.chance(selected, entry, holds.class),
				owned = owned,
				silhouette = entry.rarity == "Mythic" and not owned,
			})
		end
		HatchStand.draw(s, {
			title = holds.name .. " CHEST",
			price = crate.price,
			picker = crate.name,
			onPick = function()
				selected = selected % #Shop.crates + 1
				s.open()
			end,
			tabs = tabs,
			tiles = tiles,
			locked = if #pool == 0 then "NO WEAPONS YET" else nil,
			pity = if p then p.pity.crates else 0,
			picture = GearAssets.crates[crate.area].closed,
			backdrop = GearAssets.backgrounds.blacksmith,
			counts = Shop.counts,
			verb = "OPEN",
			noun = "WEAPONS",
			heading = "BLACKSMITH",
			modes = modes,
		}, control, press, affordable)
	end
	s.connect(Remotes.event(Remotes.ShopCrateOpened).OnClientEvent, function(index, results)
		if type(index) == "number" and type(results) == "table" then
			Reveal.crates(index, results)
		end
	end)
	local auto = if RunService:IsStudio() then Sandbox.openShop else nil
	s.connect(RunService.RenderStepped, function()
		if
			auto
			and Workspace:GetAttribute("InLobby") == true
			and s.profile
			and s.gui.Parent ~= nil
			and not s.gui.Parent:FindFirstChild("IntroCutscene")
			and not s.gui.Parent:FindFirstChild("StoryCutscene")
		then
			local wallet = auto
			auto = nil
			Remotes.event(Remotes.DebugWallet):FireServer(wallet.coins, wallet.gems, wallet.items)
			s.open()
		end
	end)
end
return ShopScreen
