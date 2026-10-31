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
-- The store: the selected area's weapons for sale, five to a row.
local function drawStore(s: StationScreen.Screen)
	local c, p = s.canvas, s.profile
	local plate = Kit.plate(c)
	Kit.put(plate, 552, 248, 816, 104)
	Kit.label(plate, Shop.crates[selected].name .. " STORE")
	for i, direction in { -1, 1 } do
		local b = Kit.imageButton(
			c,
			if direction < 0 then GearAssets.buttons.left else GearAssets.buttons.right,
			function()
				if not Reveal.busy() then
					selected = (selected - 1 + direction) % #Shop.crates + 1
					s.open()
				end
			end
		)
		Kit.put(b, if i == 1 then 408 else 1392, 240, 120, 120)
	end
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	local saleCount = 0
	for _, entry in ShopRules.catalog() do
		if entry.area == selected and ShopRules.price(entry) then
			saleCount += 1
		end
	end
	local viewHeight = 632
	local canvasHeight = math.max(viewHeight, math.ceil(saleCount / 5) * 288 + 16)
	list.CanvasSize = UDim2.fromScale(0, canvasHeight / viewHeight)
	list.ScrollBarThickness = 8
	Kit.put(list, 200, 368, 1520, 632)
	list.Parent = c
	local n = 0
	for _, entry in ShopRules.catalog() do
		local price = ShopRules.price(entry)
		if entry.area ~= selected or not price then
			continue
		end
		local owned = p ~= nil and p.weapons[entry.weapon] == true
		local art = picture(entry.weapon)
		local tile = Kit.tile(list, entry.rarity, art, art == "")
		tile.Position =
			UDim2.fromScale((8 + n % 5 * 304) / 1520, (8 + math.floor(n / 5) * 288) / canvasHeight)
		tile.Size = UDim2.fromScale(280 / 1520, 264 / canvasHeight)
		for _, child in tile:GetChildren() do
			if child:IsA("ImageLabel") and child.Image == art then
				child.Size = UDim2.fromScale(0.94, 0.48)
			end
		end
		local name = Kit.label(tile, entry.label)
		name.Position, name.Size = UDim2.fromScale(0.04, 0.5), UDim2.fromScale(0.92, 0.12)
		local priceLabel = Kit.label(tile, priceText(price))
		priceLabel.Position, priceLabel.Size =
			UDim2.fromScale(0.04, 0.62), UDim2.fromScale(0.92, 0.12)
		local can = p ~= nil and Purse.canAfford(p, price)
		local buy = Kit.button(
			tile,
			if owned then "OWNED" elseif can then "BUY" else "NEED FUNDS",
			if can and not owned then Kit.green else Kit.slate,
			function()
				if owned or not can then
					return
				end
				Reveal.request(function()
					Remotes.event(Remotes.ShopBuy):FireServer(entry.weapon)
				end)
			end
		)
		buy.Position, buy.Size = UDim2.fromScale(0.04, 0.74), UDim2.fromScale(0.92, 0.26)
		n += 1
	end
	if n == 0 then
		Kit.label(list, "NO WEAPONS YET")
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
			and #ShopRules.cratePool(selected) > 0
			and p.coins >= Shop.crates[selected].price * count
	end
	local function press(count: number)
		if affordable(count) then
			local index = selected
			Reveal.request(function()
				Remotes.event(Remotes.ShopOpenCrate):FireServer(index, count)
			end)
		end
	end
	local control = HatchStand.controller(s, Shop.counts, press, affordable, function()
		return not store
	end)
	s.draw = function()
		local c, p = s.canvas, s.profile
		for index, words in { "CRATES", "STORE" } do
			local b = Kit.button(
				c,
				words,
				if store == (index == 2) then Kit.gold else Kit.slate,
				function()
					if not Reveal.busy() then
						store = index == 2
						control.auto = false
						s.open()
					end
				end
			)
			Kit.put(b, if index == 1 then 620 else 960, 40, 320, 84)
		end
		if store then
			drawStore(s)
			return
		end
		local crate = Shop.crates[selected]
		local pool = table.clone(ShopRules.cratePool(selected))
		table.sort(pool, function(a, b)
			local ra, rb = Rarities.byName[a.rarity].tier, Rarities.byName[b.rarity].tier
			if ra ~= rb then
				return ra < rb
			end
			return a.label < b.label
		end)
		local tiles = {}
		for _, entry in pool do
			local owned = p ~= nil and p.weapons[entry.weapon] == true
			table.insert(tiles, {
				rarity = entry.rarity,
				-- always the 2D weapon art, never a render (owner's standing rule)
				icon = picture(entry.weapon),
				chance = ShopRules.chance(selected, entry),
				owned = owned,
				silhouette = entry.rarity == "Mythic" and not owned,
			})
		end
		HatchStand.draw(s, {
			title = crate.name .. " CRATE",
			price = crate.price,
			picker = crate.name,
			onPick = function()
				selected = selected % #Shop.crates + 1
				s.open()
			end,
			tiles = tiles,
			locked = if #pool == 0 then "NO WEAPONS YET" else nil,
			pity = if p then p.pity.crates else 0,
			picture = GearAssets.crates[crate.area].closed,
			moss = crate.area == "MossyGlade",
			counts = Shop.counts,
			verb = "OPEN",
			noun = "WEAPONS",
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
