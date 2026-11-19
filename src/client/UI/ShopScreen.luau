--!strict
--[[
	The Blacksmith. CRATES is the same stand as the Egg Hatchery's
	(`UI/HatchStand`; owner, 2026-10-27: the weapon chests "changed exactly
	how you are changing the pets and with the same ui"): OPEN 1 and OPEN 3,
	AUTO, the crate picker, every weapon inside with its odds. STORE sells
	the selected area's weapons.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Chunky = require(script.Parent.Chunky)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local LiveBoosts = require(ReplicatedStorage.Shared.Util.LiveBoosts)
local LiveState = require(ReplicatedStorage.Shared.Util.LiveState)
local MergeRules = require(ReplicatedStorage.Shared.Util.MergeRules)
local Purse = require(ReplicatedStorage.Shared.Util.Purse)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Reveal = require(script.Parent.Reveal)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local SetRotation = require(ReplicatedStorage.Shared.Util.SetRotation)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local StationScreen = require(script.Parent.StationScreen)
local ShopScreen = {}
local screen: StationScreen.Screen? = nil
local selected = 1
local store = false
--[[ The SETS shelf (`Config/Shop.sets`, docs/WEAPONS-THEMED.md): the themed
     sets' weapons, which belong to no area. `setAt` is the one shown, an
     index into the sets that are for sale: this week's two, by the server's
     clock (`Util/SetRotation`, docs/LIVE-EVENTS.md); the server sells no
     other. ]]
local sets = false
local setAt = 1
local function stockedSets(): { Shop.Set }
	local out = {}
	for _, key in SetRotation.featured(LiveState.now()) do
		local set = ShopRules.set(key)
		if set then
			table.insert(out, set)
		end
	end
	return out
end
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
	--[[ Coins or gems read as the number beside their picture on the
	     button. A boss item in the price is drawn as its own picture beside
	     the button (`itemPrice`), never spelled out: it read "3000 COINS +
	     3 ROYALJELLY", the save's key (the run-through, 2026-11-14). ]]
	if cost.coins and not cost.gems then
		return Chunky.commas(cost.coins)
	elseif cost.gems and not cost.coins then
		return Chunky.commas(cost.gems)
	end
	local parts = {}
	if cost.coins then
		table.insert(parts, Chunky.commas(cost.coins) .. " COINS")
	end
	if cost.gems then
		table.insert(parts, Chunky.commas(cost.gems) .. " GEMS")
	end
	return if #parts > 0 then table.concat(parts, " + ") else "BUY"
end
--[[ A boss item a price asks for: its picture with how many, `size` sheet
     pixels square, its right edge at `right`. ]]
local function itemPrice(
	row: GuiObject,
	item: string,
	image: string,
	words: string,
	right: number,
	y: number,
	size: number,
	colW: number,
	rowH: number
)
	local holder = Instance.new("Frame")
	holder.Name = "Item_" .. item
	holder.BackgroundTransparency = 1
	holder.ZIndex = 8
	holder.Position, holder.Size =
		UDim2.fromScale((right - size) / colW, y / rowH), UDim2.fromScale(size / colW, size / rowH)
	holder.Parent = row
	local art = Instance.new("ImageLabel")
	art.BackgroundTransparency = 1
	art.Image = image
	art.ScaleType = Enum.ScaleType.Fit
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = 8
	art.Parent = holder
	local n = Chunky.text(holder, words, nil, 5)
	n.TextXAlignment = Enum.TextXAlignment.Right
	n.Position, n.Size = UDim2.fromScale(0.3, 0.58), UDim2.fromScale(0.74, 0.44)
	n.ZIndex = 9
end
local function picture(weapon: string): string
	return ShopAssets.weapons[weapon] or GearAssets.weapons[weapon] or ""
end
--[[ The store: the selected area's weapons for sale, as the approved style
     sheet's SHOP rows (owner, 2026-11-05): a white card per weapon with its
     2D art in its rarity's frame, its name and rarity, its price and a fat
     BUY. Two columns across a landscape screen, one upright; the list
     scrolls when the area sells more than fit. ]]
local function drawStore(s: StationScreen.Screen, area: HatchStand.Area, set: Shop.Set?)
	local p = s.profile
	local sheet = area.sheet
	local up = sheet.upright
	local shelves = stockedSets()
	local function step(direction: number): () -> ()
		return function()
			if not Reveal.busy() then
				if set then
					setAt = (setAt - 1 + direction) % #shelves + 1
				else
					selected = (selected - 1 + direction) % #Shop.crates + 1
				end
				s.open()
			end
		end
	end
	-- the area picker across the head of the list; a lone set has nothing to step to
	if not set or #shelves > 1 then
		Chunky.button(sheet, "<", Chunky.blue, area.x, area.y, 100, 84, step(-1))
		Chunky.button(sheet, ">", Chunky.blue, area.x + area.w - 100, area.y, 100, 84, step(1))
	end
	local nameBox = Instance.new("Frame")
	nameBox.BackgroundTransparency = 1
	nameBox.ZIndex = 6
	Chunky.put(sheet, nameBox, area.x + 120, area.y + 4, area.w - 240, if set then 54 else 76)
	Chunky.text(
		nameBox,
		if set then set.name .. " SET" else Shop.crates[selected].name .. " STORE",
		Chunky.ink,
		0
	)
	if set then
		-- the week's sets change on Monday 00:00 UTC; the shelf redraws then
		local soon = Instance.new("Frame")
		soon.BackgroundTransparency = 1
		soon.ZIndex = 6
		Chunky.put(sheet, soon, area.x + 120, area.y + 58, area.w - 240, 36)
		local label = Chunky.text(soon, "", Chunky.inkSoft, 0)
		label.Name = "NewSets"
		local week = SetRotation.week(LiveState.now())
		task.spawn(function()
			while label.Parent do
				local now = LiveState.now()
				if SetRotation.week(now) ~= week then
					s.open()
					return
				end
				label.Text = "NEW SETS IN " .. LiveBoosts.clock(SetRotation.left(now))
				task.wait(1)
			end
		end)
	end

	local entries = {}
	for _, entry in ShopRules.catalog() do
		-- a set's weapon is on its set's shelf, never in an area's store
		local here = if set then entry.set == set.key else entry.area == selected and not entry.set
		if here and ShopRules.price(entry) then
			table.insert(entries, entry)
		end
	end
	--[[ The class being played first: a Ranger saw the staffs before the
	     bows (the run-through, 2026-11-14). The catalog's order otherwise. ]]
	local mine = Players.LocalPlayer:GetAttribute("Class")
	local order: { [any]: number } = {}
	for index, entry in entries do
		order[entry] = if entry.class == mine then index - #entries else index
	end
	table.sort(entries, function(a, b)
		return order[a] < order[b]
	end)
	-- an area shut at launch shows its weapons, with what opens them on each button
	-- (a set waits on no boss)
	local shut = if set
		then nil
		else ShopRules.crateWords(selected, if p then p.bossesBeaten else nil)
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
	-- a canvas's scale is against the frame's parent, the sheet
	list.CanvasSize = UDim2.fromScale(0, contentH / sheet.h)
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
		local tile = Chunky.tile(holder, entry.rarity, picture(entry.weapon), nil, false, owned)
		if p and owned then
			Chunky.tier(tile, MergeRules.best(p.tiers.weapons[entry.weapon]) or "C")
		end
		--[[ The boss items the price asks for, as pictures left of the
		     button; the words give way to them. ]]
		local asked = 0
		if not owned and not shut then
			for item, count in price.items or ({} :: { [string]: number }) do
				local art = ShopAssets.items[item] or ""
				local words = "x" .. tostring(count)
				itemPrice(row, item, art, words, colW - 264 - asked * 96, 30, 92, colW, rowH)
				asked += 1
			end
			--[[ A set's price is coins and gems: the coins on the button
			     and the gems as the diamond with their number beside it,
			     as a boss item is, never "5,000 COINS + 300 GEMS" in words. ]]
			if price.coins and price.gems then
				local words = Chunky.commas(price.gems)
				itemPrice(row, "Gems", ShopAssets.gem, words, colW - 264, 30, 92, colW, rowH)
				asked += 1
			end
		end
		local wordsW = colW - 156 - 264 - asked * 96
		local nameText = Chunky.text(row, entry.label, Chunky.navy, 0)
		nameText.TextXAlignment = Enum.TextXAlignment.Left
		nameText.Position, nameText.Size =
			UDim2.fromScale(156 / colW, 14 / rowH), UDim2.fromScale(wordsW / colW, 64 / rowH)
		--[[ Under the name, smaller than it: the rarity and what the
		     weapon hits for in its class's hands, as Gear's plate counts
		     it, so it can be held against the one in hand. ]]
		local class = Classes[entry.class]
		local atk = math.round(
			Balance.Player.baseDamage
				* (if class then class.damageScale else 1)
				* ShopRules.strength(entry.weapon, nil)
		)
		local rarityText = Chunky.text(
			row,
			string.upper(entry.rarity) .. "   ATK " .. Chunky.commas(atk),
			Chunky.inkSoft,
			0
		)
		rarityText.TextXAlignment = Enum.TextXAlignment.Left
		rarityText.Position, rarityText.Size =
			UDim2.fromScale(156 / colW, 86 / rowH), UDim2.fromScale(wordsW / colW, 34 / rowH)
		-- the price on its button; BUY when it can be paid
		local buyHolder = Instance.new("Frame")
		buyHolder.BackgroundTransparency = 1
		buyHolder.ZIndex = 8
		buyHolder.Position, buyHolder.Size =
			UDim2.fromScale((colW - 236) / colW, 30 / rowH), UDim2.fromScale(220 / colW, 96 / rowH)
		buyHolder.Parent = row
		local both = price.coins ~= nil and price.gems ~= nil
		local label = if owned
			then "OWNED"
			elseif shut then shut
			elseif both then Chunky.commas(price.coins or 0)
			else priceText(price)
		--[[ The currency's own picture beside the price: the diamond for a
		     gem price, the coin for a coin one (a Legendary's coins and boss
		     item keep the coin, with the rest in words). ]]
		local icon: string? = nil
		if not owned and not shut then
			icon = if price.gems and not price.coins then ShopAssets.gem else ShopAssets.coin
		end
		local colour = if owned or shut
			then Chunky.grey
			elseif can then Chunky.green
			else Chunky.grey
		local miniSheet: Chunky.Sheet =
			{ canvas = buyHolder :: any, w = 220, h = 96, upright = false }
		Chunky.button(miniSheet, label, colour, 0, 0, 220, 96, function()
			if owned or shut or not can then
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
		Chunky.text(empty, "NO WEAPONS YET", Chunky.ink, 0)
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
	--[[ Each time the Blacksmith is opened afresh its CRATES start on the
	     chest of the class being played, as its STORE lists that class
	     first: a Warden's opened on BOWS (the every-class run-through,
	     2026-11-16). A tab picked stays picked until the screen is shut. ]]
	local fresh = true
	local function follow()
		layer.Enabled = dim.Visible and GearAssets.backgrounds.blacksmith ~= ""
		if not dim.Visible then
			fresh = true
		end
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
		return not store and not sets
	end)
	s.draw = function()
		local p = s.profile
		if fresh then
			fresh = false
			local mine = Players.LocalPlayer:GetAttribute("Class")
			for index, each in Shop.chests do
				if each.class == mine then
					chest = index
				end
			end
		end
		-- the Blacksmith's two modes, as tabs along the panel's head
		local modes = {}
		--[[ SETS is a third tab once a themed set is for sale; with none
		     the Blacksmith is the two tabs it always was. ]]
		local shelves = stockedSets()
		if #shelves == 0 then
			sets = false
		end
		setAt = math.clamp(setAt, 1, math.max(#shelves, 1))
		local names: { string } = { "CRATES", "STORE" }
		if #shelves > 0 then
			table.insert(names, "SETS")
		end
		local at = if sets then 3 elseif store then 2 else 1
		for index, words in names do
			table.insert(modes, {
				words = words,
				on = at == index,
				pick = function()
					store, sets = index == 2, index == 3
					control.auto = false
					s.open()
				end,
			})
		end
		if sets then
			drawStore(s, HatchStand.chrome(s, "BLACKSMITH", modes), shelves[setAt])
			return
		elseif store then
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
				tier = if p and owned
					then MergeRules.best(p.tiers.weapons[entry.weapon]) or "C"
					else nil,
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
			locked = if #pool == 0
				then "NO WEAPONS YET"
				else ShopRules.crateWords(selected, if p then p.bossesBeaten else nil),
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
