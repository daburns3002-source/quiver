--!strict
--[[
	The Gear sheet (owner, 2026-10-26: "the player's own character in the middle"),
	in the chunky style (owner, 2026-11-05; mockup assets/concepts/ui_refs/
	mockups/gear.jpg): the gold GEAR ribbon and red X, the hero on a stone
	pedestal with ATK and HP on a gold plate, the slots either side, and a
	white inventory card of tabs, rarity tiles and buttons. Laid out on
	1920 x 1080, or 1080 x 1920 held upright. Weapons remain 2D pictures; the
	character, held preview and companions enter the viewport.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Chunky = require(script.Parent.Chunky)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local EggScreen = require(script.Parent.EggScreen)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Reveal = require(script.Parent.Reveal)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local ShopScreen = require(script.Parent.ShopScreen)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local StationScreen = require(script.Parent.StationScreen)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)
local GearScreen = {}
local screen: StationScreen.Screen? = nil
local tab = "GEAR"
local byName = false
local preferredPetSlot: number? = nil
function GearScreen.open()
	if screen then
		screen.open()
	end
end
function GearScreen.close()
	if screen and not Reveal.busy() then
		screen.close()
	end
end
function GearScreen.isOpen(): boolean
	return screen ~= nil and screen.isOpen()
end
local function currentClass(): string
	local name = Players.LocalPlayer:GetAttribute("Class")
	return if type(name) == "string" and Classes[name] then name else "Ranger"
end
local function equippedForClass(profile: SaveSchema.Profile?): string
	local name = currentClass()
	local saved = profile and profile.equipped and ShopRules.find(profile.equipped)
	return if saved and saved.class == name then saved.weapon else Classes[name].weapon
end
local function portrait(
	parent: Instance,
	put: (GuiObject, number, number, number, number) -> (),
	rect: { number },
	weaponName: string?,
	pets: { string }?
)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = 2
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.new(1, 0.94, 0.8)
	put(viewport, rect[1], rect[2], rect[3], rect[4])
	viewport.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 36
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	local archivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = archivable
	-- Preserve intentionally invisible parts while undoing camera hiding on the copy.
	local function restoreVisibility(original: Instance, copy: Instance)
		if original:IsA("BasePart") and copy:IsA("BasePart") then
			copy.LocalTransparencyModifier = 0
			if original.Transparency == 0 and original.Name ~= "HumanoidRootPart" then
				copy.Transparency = 0
			end
		end
		for _, child in copy:GetChildren() do
			local source = original:FindFirstChild(child.Name)
			if source then
				restoreVisibility(source, child)
			end
		end
	end
	restoreVisibility(character, clone)
	for _, child in clone:GetDescendants() do
		if
			child:IsA("Script")
			or child:IsA("LocalScript")
			or child:IsA("ModuleScript")
			or child:IsA("Tool")
			or child.Name == "HeldWeapon"
			or child.Name == "Weapon"
		then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.LocalTransparencyModifier = 0
			if child.Name == "HumanoidRootPart" then
				child.Transparency = 1
			end
		end
	end
	clone.Parent = world
	clone:PivotTo(CFrame.new())
	-- their weapon in hand and their pets at their feet (owner, 2026-10-26)
	local body, bodySize = clone:GetBoundingBox()
	local floor = body.Position.Y - bodySize.Y / 2
	local weapons = ReplicatedStorage:FindFirstChild("WeaponPreview")
	local held = weaponName and weapons and weapons:FindFirstChild(weaponName)
	if held and held:IsA("Model") then
		local hand = clone:FindFirstChild(held:GetAttribute("Hand") or "RightHand")
		if hand and hand:IsA("BasePart") then
			local copy = held:Clone()
			copy:PivotTo(hand.CFrame)
			copy.Parent = clone
		end
	end
	local petModels = ReplicatedStorage:FindFirstChild("PetPreview")
	for index, key in pets or ({} :: { string }) do
		local template = petModels and petModels:FindFirstChild(key)
		if template and template:IsA("Model") then
			local pet = template:Clone()
			local _, petSize = pet:GetBoundingBox()
			if petSize.Y > 0 then
				pet:ScaleTo(pet:GetScale() * (bodySize.Y * 0.42) / petSize.Y)
			end
			local box, scaled = pet:GetBoundingBox()
			local lift = pet:GetPivot().Position.Y - (box.Position.Y - scaled.Y / 2)
			local side = if index == 1 then -1 else 1
			pet:PivotTo(
				CFrame.new(side * (bodySize.X / 2 + scaled.X / 2 + 0.6), floor + lift, -0.4)
			)
			for _, part in pet:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			pet.Parent = clone
		end
	end
	local bounds, size = clone:GetBoundingBox()
	local center = bounds.Position
	-- Fit the full body to 92% of the frame, allowing for depth and the gentle turn;
	-- a held sword or an aura may reach a little past the sides.
	local function frameCamera()
		local aspect = viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y)
		local halfFov = math.tan(math.rad(camera.FieldOfView / 2))
		local chest = center
		local halfWidth = (size.X + size.Z * 0.35) / 2
		local distance = math.max(
			size.Y / (2.04 * halfFov),
			halfWidth / (1.15 * halfFov * math.max(aspect, 0.1))
		) + size.Z / 2
		-- Roblox characters face -Z after PivotTo(CFrame.new()).
		camera.CFrame = CFrame.lookAt(chest - Vector3.new(0, 0, distance), chest)
	end
	frameCamera()
	local resized = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCamera)
	local began = os.clock()
	local step = RunService.RenderStepped:Connect(function()
		clone:PivotTo(CFrame.Angles(0, math.sin((os.clock() - began) * 0.18) * 0.35, 0))
	end)
	viewport.Destroying:Once(function()
		step:Disconnect()
		resized:Disconnect()
	end)
end
--[[ A weapon's 2D art, the same picture the Blacksmith shows (never a
     render: owner's standing rule). ]]
local function weaponArt(weapon: string): string
	return ShopAssets.weapons[weapon] or GearAssets.weapons[weapon] or ""
end
type Entry = {
	key: string,
	name: string,
	rarity: string,
	icon: string,
	owned: boolean,
	count: number,
}
--[[ A fresh sheet that draws over everything already on `sheet`: the
     same sheet pixels, laid on `over` (which covers the whole canvas). ]]
local function overlay(sheet: Chunky.Sheet, over: GuiObject): Chunky.Sheet
	return { canvas = over :: any, w = sheet.w, h = sheet.h, upright = sheet.upright }
end
local function plate(
	sheet: Chunky.Sheet,
	colour: Color3,
	x: number,
	y: number,
	w: number,
	h: number
): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.ZIndex = 8
	Chunky.put(sheet, f, x, y, w, h)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.3), colour)
	shade.Parent = f
	Chunky.round(f, math.min(26, h * 0.4))
	Chunky.outline(f, 6)
	return f
end
--[[ An item's details over the screen (owner, 2026-10-27, with a video of
     the reference game: tapping an item opens its card first), in the
     chunky style: a blue panel, the name on the gold ribbon, the rarity on
     a plate in its colour, the item big in its rarity frame, what it does
     on a white card, and EQUIP (or EQUIPPED / UNEQUIP / LOCKED) and CLOSE. ]]
local function details(
	sheet: Chunky.Sheet,
	entry: Entry,
	isPet: boolean,
	isEquipped: boolean,
	onEquip: () -> ()
)
	local shade = Instance.new("TextButton")
	shade.Name = "Details"
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.35
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 100
	shade.Parent = sheet.canvas
	local function close()
		shade:Destroy()
	end
	shade.Activated:Connect(close)
	local pop = overlay(sheet, shade)
	local up = sheet.upright
	-- panel, ribbon, X, rarity, tile, lines card, buttons (sheet pixels)
	local L = if up
		then {
			panel = { 90, 480, 900, 1010 },
			ribbon = { 150, 404, 780, 150 },
			x = { 920, 436, 104 },
			rarity = { 380, 590, 320, 64 },
			tile = { 370, 676, 340, 340 },
			lines = { 150, 1040, 780, 230 },
			equip = { 150, 1310, 460, 116 },
			shut = { 640, 1310, 290, 116 },
		}
		else {
			panel = { 560, 140, 800, 840 },
			ribbon = { 590, 68, 740, 144 },
			x = { 1296, 100, 100 },
			rarity = { 800, 230, 320, 60 },
			tile = { 805, 306, 310, 310 },
			lines = { 620, 640, 680, 180 },
			equip = { 620, 846, 400, 104 },
			shut = { 1040, 846, 260, 104 },
		}
	local panel = Chunky.panel(pop, table.unpack(L.panel))
	-- swallow clicks on the panel itself
	local guard = Instance.new("TextButton")
	guard.Text, guard.BackgroundTransparency, guard.AutoButtonColor = "", 1, false
	guard.ZIndex = 3
	Chunky.put(pop, guard, table.unpack(L.panel))
	Chunky.pop(panel)
	Chunky.ribbon(pop, string.upper(entry.name), table.unpack(L.ribbon))
	Chunky.close(pop, L.x[1], L.x[2], L.x[3], close)
	local colour = if entry.owned then Chunky.rarity[entry.rarity] or Chunky.grey else Chunky.grey
	local badge = plate(pop, colour, table.unpack(L.rarity))
	Chunky.text(badge, string.upper(entry.rarity), nil, 5).Position = UDim2.fromScale(0, 0)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.ZIndex = 6
	Chunky.put(pop, holder, table.unpack(L.tile))
	-- a weapon is always its 2D art; a pet stands as its model
	local tile = Chunky.tile(
		holder,
		entry.rarity,
		entry.icon,
		nil,
		not entry.owned,
		false,
		if isPet then entry.key else nil
	)
	if entry.owned then
		Chunky.gleam(tile)
	end
	local lines: { string } = {}
	if isPet then
		local info = Pets[entry.key]
		local egg = if info and info.egg then EggRules.find(info.egg) else nil
		table.insert(lines, "FIGHTS BESIDE YOU IN RUNS")
		table.insert(lines, "FROM THE " .. string.upper(if egg then egg.name else "EGG"))
		if entry.owned then
			table.insert(lines, "OWNED x" .. tostring(entry.count))
		end
	else
		local stats = WeaponStats.weapons[entry.key]
		local shop = ShopRules.find(entry.key)
		if stats then
			local boost = WeaponStats.bonus[stats.rarity] or 0
			local scale = WeaponStats.areaScale[stats.area] or 1
			table.insert(lines, "DAMAGE x" .. string.format("%.2f", (1 + boost) * scale))
		end
		if shop then
			table.insert(lines, string.upper(shop.class) .. " WEAPON")
		end
		if stats and stats.effect then
			table.insert(lines, string.upper(stats.effect))
		end
	end
	if not entry.owned then
		table.insert(
			lines,
			if isPet then "HATCH IT AT THE EGG HATCHERY" else "OPEN CRATES AT THE BLACKSMITH"
		)
	end
	local card = Chunky.card(pop, table.unpack(L.lines))
	local count = math.max(#lines, 1)
	for i, words in lines do
		local line = Chunky.text(card, words, Chunky.ink, 0)
		line.Position = UDim2.fromScale(0.05, 0.08 + (i - 1) * 0.84 / count)
		line.Size = UDim2.fromScale(0.9, 0.84 / math.max(count, 3) * 0.8)
	end
	local label = if not entry.owned
		then "LOCKED"
		elseif isEquipped and isPet then "UNEQUIP"
		elseif isEquipped then "EQUIPPED"
		else "EQUIP"
	local can = entry.owned and not (isEquipped and not isPet)
	local e = L.equip
	Chunky.button(
		pop,
		label,
		if can then Chunky.green else Chunky.grey,
		e[1],
		e[2],
		e[3],
		e[4],
		function()
			if can then
				close()
				onEquip()
			end
		end
	)
	local c = L.shut
	Chunky.button(pop, "CLOSE", Chunky.blue, c[1], c[2], c[3], c[4], close)
	SoundFx.play("new_item")
end

--[[ One of the hero's slots: its name over a rarity tile, the equipped
     thing on it (gleaming), "+" when empty, a lock when there is nothing
     to put in it yet. Pressing it opens the matching tab. ]]
local function slot(
	sheet: Chunky.Sheet,
	words: string,
	x: number,
	y: number,
	size: number,
	rarity: string?,
	icon: string?,
	locked: boolean,
	action: () -> ()
): Frame
	local holder = Instance.new("Frame")
	holder.Name = words:gsub(" ", "") .. "Slot"
	holder.BackgroundTransparency = 1
	holder.ZIndex = 6
	local tall = size + 58
	Chunky.put(sheet, holder, x, y, size, tall)
	local name = Chunky.text(holder, words, nil, 5)
	name.Size = UDim2.fromScale(1, 50 / tall)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Position, box.Size = UDim2.fromScale(0, 58 / tall), UDim2.fromScale(1, size / tall)
	box.ZIndex = 6
	box.Parent = holder
	local filled = icon ~= nil and icon ~= ""
	local tile = Chunky.tile(box, if filled then rarity or "Common" else "Common", icon or "")
	if filled then
		Chunky.gleam(tile, x * 0.003 + y * 0.002)
	elseif locked then
		local lock = Kit.image(tile, ShopAssets.lock)
		lock.Position, lock.Size = UDim2.fromScale(0.25, 0.22), UDim2.fromScale(0.5, 0.5)
		lock.ZIndex = 12
	else
		local plus = Chunky.text(tile, "+", nil, 6)
		plus.Position, plus.Size = UDim2.fromScale(0.25, 0.18), UDim2.fromScale(0.5, 0.56)
	end
	Chunky.press(holder, function()
		if not Reveal.busy() then
			action()
		end
	end)
	return holder
end

local function draw(s: StationScreen.Screen)
	local c, p = s.canvas, s.profile
	for _, child in c:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local area = HatchStand.chrome(s, "GEAR")
	local sheet = area.sheet
	local up = sheet.upright
	local class = Classes[currentClass()] or Classes.Ranger
	local equipped = equippedForClass(p)
	local weapon = ShopRules.find(equipped)
	local petKeys: { string } = {}
	for index = 1, 2 do
		local key = p and p.equippedPets[index]
		if key then
			table.insert(petKeys, key)
		end
	end
	local function reopen(nextTab: string)
		return function()
			tab = nextTab
			s.open()
		end
	end

	-- the hero on a round stone pedestal, the slots either side
	local L = if up
		then {
			hero = { 290, 290, 500, 700 },
			pedestal = { 320, 826, 440, 100 },
			plate = { 330, 960, 420, 92 },
			left = 90,
			right = 800,
			rows = { 330, 640 },
			size = 190,
			card = { 60, 1086, 960, 784 },
		}
		else {
			hero = { 360, 176, 400, 700 },
			pedestal = { 400, 712, 320, 90 },
			plate = { 380, 850, 360, 100 },
			left = 196,
			right = 728,
			rows = { 250, 610 },
			size = 196,
			card = { 950, 190, 780, 830 },
		}
	local pedestal = Instance.new("Frame")
	pedestal.BorderSizePixel = 0
	pedestal.BackgroundColor3 = Color3.new(1, 1, 1)
	pedestal.ZIndex = 4
	Chunky.put(sheet, pedestal, table.unpack(L.pedestal))
	local stone = Instance.new("UIGradient")
	stone.Rotation = 90
	stone.Color = ColorSequence.new(Color3.fromRGB(150, 160, 186), Color3.fromRGB(84, 92, 124))
	stone.Parent = pedestal
	local oval = Instance.new("UICorner")
	oval.CornerRadius = UDim.new(0.5, 0)
	oval.Parent = pedestal
	Chunky.outline(pedestal, 6)
	portrait(c, function(item, x, y, w, h)
		Chunky.put(sheet, item, x, y, w, h)
		item.ZIndex = 6
	end, L.hero, equipped, petKeys)

	-- ATK and HP on the gold plate under the hero (the mockup's POWER plate)
	local stats = WeaponStats.weapons[equipped]
	local scale = if stats
		then (1 + WeaponStats.bonus[stats.rarity]) * (WeaponStats.areaScale[stats.area] or 1)
		else 1
	local chosenClass = if weapon then Classes[weapon.class] or class else class
	local atk = math.round(Balance.Player.baseDamage * chosenClass.damageScale * scale)
	local power = plate(sheet, Chunky.gold, table.unpack(L.plate))
	local words = Chunky.text(
		power,
		"ATK " .. Chunky.commas(atk) .. "   HP " .. Chunky.commas(Balance.Player.maxHealth),
		nil,
		6
	)
	words.Position, words.Size = UDim2.fromScale(0.06, 0.16), UDim2.fromScale(0.88, 0.68)

	local weaponSlot = slot(
		sheet,
		"WEAPON",
		L.left,
		L.rows[1],
		L.size,
		if weapon then weapon.rarity else "Common",
		weaponArt(equipped),
		false,
		reopen("GEAR")
	)
	slot(sheet, "TRAIL", L.left, L.rows[2], L.size, nil, nil, true, reopen("TRAILS"))
	local petSlots: { GuiObject } = {}
	for index = 1, 2 do
		local key = p and p.equippedPets[index]
		local info = key and Pets[key]
		petSlots[index] = slot(
			sheet,
			"PET " .. tostring(index),
			L.right,
			L.rows[index],
			L.size,
			if info then info.rarity else nil,
			if key then GearAssets.pets[key] else nil,
			false,
			function()
				preferredPetSlot = index
				tab = "PETS"
				s.open()
			end
		)
	end

	-- the white inventory card: its tabs, the grid, the buttons under it
	local cx, cy, cw, ch = table.unpack(L.card)
	Chunky.card(sheet, cx, cy, cw, ch)
	local tabs = {
		{ id = "CLASSES", words = "CLASSES", colour = Chunky.purple },
		{ id = "GEAR", words = "WEAPONS", colour = Chunky.gold },
		{ id = "PETS", words = "PETS", colour = Chunky.blue },
		{ id = "TRAILS", words = "TRAILS", colour = Chunky.green },
	}
	local tabGap = 10
	local tabW = (cw - 44 - tabGap * (#tabs - 1)) / #tabs
	for i, entry in tabs do
		Chunky.tab(
			sheet,
			entry.words,
			entry.colour,
			tab == entry.id,
			cx + 22 + (i - 1) * (tabW + tabGap),
			cy + 20,
			tabW,
			if up then 86 else 80,
			function()
				if not Reveal.busy() and tab ~= entry.id then
					tab = entry.id
					s.open()
				end
			end
		)
	end
	local buttonH = if up then 110 else 100
	local gx, gy = cx + 22, cy + 120
	local gw, gh = cw - 44, ch - 120 - buttonH - 40

	local entries: { Entry } = {}
	if tab == "GEAR" then
		for _, entry in ShopRules.catalog() do
			if entry.class ~= currentClass() then
				continue
			end
			table.insert(entries, {
				key = entry.weapon,
				name = entry.label,
				rarity = entry.rarity,
				icon = weaponArt(entry.weapon),
				owned = p ~= nil and p.weapons[entry.weapon] == true,
				count = 1,
			})
		end
	elseif tab == "PETS" then
		for key, info in Pets do
			table.insert(entries, {
				key = key,
				name = info.name,
				rarity = info.rarity,
				icon = GearAssets.pets[key] or "",
				owned = p ~= nil and (p.pets[key] or 0) > 0,
				count = if p then p.pets[key] or 0 else 0,
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.owned ~= b.owned then
			return a.owned
		end
		if not byName and a.rarity ~= b.rarity then
			return Rarities.byName[a.rarity].tier > Rarities.byName[b.rarity].tier
		end
		return a.name < b.name
	end)

	-- the grid: four tiles a row landscape, five upright; it scrolls
	local cols = if up then 5 else 4
	local pad, gap = 14, 16
	local cell = (gw - 24 - pad * 2 - gap * (cols - 1)) / cols
	local count = if tab == "CLASSES" then 3 else #entries
	local rows = math.max(math.ceil(count / cols), 1)
	local contentH = math.max(gh, pad * 2 + rows * cell + (rows - 1) * gap)
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "InventoryGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 10
	grid.ScrollBarImageColor3 = Chunky.navy
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ZIndex = 6
	Chunky.put(sheet, grid, gx, gy, gw, gh)
	--[[ The cells in screen pixels, from the grid's width: a scroll
	     canvas's own scale does not follow its window, so scale positions
	     inside it stretch. ]]
	local placed: { { holder: Frame, x: number, y: number } } = {}
	local function layout()
		local unit = grid.AbsoluteSize.X / gw
		grid.CanvasSize = UDim2.fromOffset(0, contentH * unit)
		for _, each in placed do
			each.holder.Position = UDim2.fromOffset(each.x * unit, each.y * unit)
			each.holder.Size = UDim2.fromOffset(cell * unit, cell * unit)
		end
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	local function cellAt(n: number): Frame
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.ZIndex = 6
		table.insert(placed, {
			holder = holder,
			x = pad + ((n - 1) % cols) * (cell + gap),
			y = pad + ((n - 1) // cols) * (cell + gap),
		})
		holder.Parent = grid
		return holder
	end
	if tab == "CLASSES" then
		for i, className in { "Ranger", "Arcanist", "Warden" } do
			local selected = className == currentClass()
			local holder = cellAt(i)
			local tile = Chunky.tile(
				holder,
				if selected then "Legendary" else "Common",
				weaponArt(Classes[className].weapon),
				string.upper(className),
				false,
				selected
			)
			Chunky.gleam(tile, i * 0.37)
			Chunky.press(holder, function()
				if
					not selected
					and Workspace:GetAttribute("InLobby") == true
					and not Reveal.busy()
				then
					SoundFx.play("equip_weapon")
					Remotes.event(Remotes.SwitchClass):FireServer(className)
				end
			end)
		end
	elseif tab == "TRAILS" then
		local empty = Instance.new("Frame")
		empty.BackgroundTransparency = 1
		empty.ZIndex = 6
		Chunky.put(sheet, empty, gx + 40, gy + gh * 0.4, gw - 80, 70)
		Chunky.text(empty, "TRAILS ARE NOT AVAILABLE YET", Chunky.ink, 0)
	end
	for i, entry in entries do
		local isPet = tab == "PETS"
		local isEquipped = if isPet
			then p ~= nil and (p.equippedPets[1] == entry.key or p.equippedPets[2] == entry.key)
			else equipped == entry.key
		local holder = cellAt(i)
		-- a weapon is always its 2D art (owner's standing rule); a pet stands
		local tile = Chunky.tile(
			holder,
			entry.rarity,
			entry.icon,
			if isPet and entry.owned
				then "x" .. tostring(entry.count)
				elseif isEquipped then "EQUIPPED"
				else nil,
			not entry.owned,
			isEquipped,
			if isPet and entry.icon == "" then entry.key else nil
		)
		if entry.owned then
			Chunky.gleam(tile, i * 0.37)
		else
			local lock = Kit.image(tile, ShopAssets.lock)
			lock.Position, lock.Size = UDim2.fromScale(0.6, 0.56), UDim2.fromScale(0.34, 0.34)
			lock.ZIndex = 13
		end
		Chunky.press(holder, function()
			if Reveal.busy() or not p then
				return
			end
			details(sheet, entry, isPet, isEquipped, function()
				if isPet and isEquipped then
					for index = 1, 2 do
						if p.equippedPets[index] == entry.key then
							Remotes.event(Remotes.EquipPet):FireServer(index, nil)
						end
					end
				elseif isPet then
					local index = if preferredPetSlot
						then preferredPetSlot
						elseif not p.equippedPets[1] then 1
						elseif not p.equippedPets[2] then 2
						else 1
					Reveal.equip(holder, petSlots[index], entry.icon, true)
					Remotes.event(Remotes.EquipPet):FireServer(index, entry.key)
				else
					Reveal.equip(holder, weaponSlot, entry.icon, false)
					Remotes.event(Remotes.ShopEquip):FireServer(entry.key)
				end
			end)
		end)
	end

	layout()

	-- under the grid: the sort, and the Blacksmith and Hatchery shortcuts
	local by = cy + ch - buttonH - 22
	local bw = (cw - 44 - 2 * 16) / 3
	local crate = GearAssets.crates.MossyGlade
	local egg = GearAssets.eggs.MossyEgg
	local function shortcut(open: () -> ()): () -> ()
		return function()
			if not Reveal.busy() then
				s.close()
				StationScreen.openShortcut(open)
			end
		end
	end
	Chunky.button(
		sheet,
		if byName then "BY NAME" else "BY RARITY",
		Chunky.gold,
		cx + 22,
		by,
		bw,
		buttonH,
		function()
			if not Reveal.busy() then
				byName = not byName
				s.open()
			end
		end
	)
	Chunky.button(
		sheet,
		"SMITH",
		Chunky.blue,
		cx + 22 + bw + 16,
		by,
		bw,
		buttonH,
		shortcut(ShopScreen.open),
		if crate then crate.closed else nil
	)
	Chunky.button(
		sheet,
		"HATCH",
		Chunky.green,
		cx + 22 + 2 * (bw + 16),
		by,
		bw,
		buttonH,
		shortcut(EggScreen.open),
		if egg then egg.whole else nil
	)
end
function GearScreen.start()
	if screen then
		return
	end
	local s = StationScreen.new("GearScreen", "GearStation", "GEAR")
	screen = s
	s.draw = function()
		draw(s)
	end
end
return GearScreen
