--!strict
--[[
	The Gear sheet (owner, 2026-10-26: "the player's own character in the middle").
	Weapons remain 2D pictures; the character, held preview and companions enter the viewport.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local EggScreen = require(script.Parent.EggScreen)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
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
type Entry = {
	key: string,
	name: string,
	rarity: string,
	icon: string,
	owned: boolean,
	count: number,
}
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
	weaponName: string?,
	pets: { string }?
)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = 2
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.new(1, 0.94, 0.8)
	put(viewport, 600, 88, 720, 412)
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
	-- Fit the full body to 92% of the frame, allowing for depth and the gentle turn.
	local function frameCamera()
		local aspect = viewport.AbsoluteSize.X / math.max(1, viewport.AbsoluteSize.Y)
		local halfFov = math.tan(math.rad(camera.FieldOfView / 2))
		local chest = center
		local halfWidth = (size.X + size.Z * 0.35) / 2
		local distance = math.max(
			size.Y / (2.04 * halfFov),
			halfWidth / (0.95 * halfFov * math.max(aspect, 0.1))
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
type Rect = { number }
--[[ Whether the screen is laid out landscape (PC and console, owner,
     2026-10-27: "these buttons and the layout needs to also be formatted
     landscape for the pc and console"): the canvas is 1920 x 1080, the
     showcase on the left and the sheet on the right; otherwise the
     reference's tall column, 1920 x `TALL`. ]]
local wideLayout = false
--[[ An item's details over the screen (owner, 2026-10-27, with a video of
     the reference game: tapping an item opens its card first): a name
     banner in its rarity's colour, the rarity, the icon big on its card,
     what it does, and EQUIP (or EQUIPPED / UNEQUIP / LOCKED) and CLOSE. ]]
local function details(
	c: Frame,
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
	shade.ZIndex = 40
	shade.Parent = c
	local function close()
		shade:Destroy()
	end
	shade.Activated:Connect(close)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.ZIndex = 41
	holder.Parent = shade
	if wideLayout then
		Kit.put(holder, 560, 120, 800, 840)
	else
		Kit.put(holder, 160, 300 * 1080 / 3413, 1600, 2300 * 1080 / 3413)
	end
	local panel = Kit.nativePanel(holder, nil, true)
	panel.ZIndex = 41
	-- swallow clicks on the card itself
	local guard = Instance.new("TextButton")
	guard.Text, guard.BackgroundTransparency, guard.Size = "", 1, UDim2.fromScale(1, 1)
	guard.ZIndex = 41
	guard.Parent = panel
	local colour = if entry.owned then Kit.colour(entry.rarity) else Color3.fromRGB(112, 120, 132)
	local banner = Kit.nativePanel(holder, colour)
	banner.ZIndex = 42
	banner.Position, banner.Size = UDim2.fromScale(0.08, -0.03), UDim2.fromScale(0.84, 0.13)
	local title = Kit.nativeText(banner, entry.name)
	title.ZIndex = 43
	local ribbon = Kit.nativePanel(holder, colour:Lerp(Color3.new(0, 0, 0), 0.35))
	ribbon.ZIndex = 42
	ribbon.Position, ribbon.Size = UDim2.fromScale(0.3, 0.11), UDim2.fromScale(0.4, 0.07)
	Kit.nativeText(ribbon, string.upper(entry.rarity)).ZIndex = 43
	local card = Kit.nativeTile(holder, entry.rarity, entry.icon, not entry.owned, true)
	card.Position, card.Size = UDim2.fromScale(0.33, 0.21), UDim2.fromScale(0.34, 0.32)
	for _, d in card:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 42
		end
	end
	card.ZIndex = 42
	local lines: { string } = {}
	if isPet then
		local info = Pets[entry.key]
		local egg = info and EggRules.find(info.egg)
		table.insert(lines, "FIGHTS BESIDE YOU IN RUNS")
		table.insert(lines, "FROM THE " .. (if egg then egg.name else "EGG"))
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
	local list = Kit.nativePanel(holder, Color3.fromRGB(28, 30, 38))
	list.ZIndex = 42
	list.Position, list.Size = UDim2.fromScale(0.08, 0.56), UDim2.fromScale(0.84, 0.25)
	for i, words in lines do
		local line = Kit.nativeText(list, words)
		line.ZIndex = 43
		line.Position = UDim2.fromScale(0.05, 0.06 + (i - 1) * (0.88 / math.max(#lines, 1)))
		line.Size = UDim2.fromScale(0.9, 0.8 / math.max(#lines, 3))
	end
	local label = if not entry.owned
		then "LOCKED"
		elseif isEquipped and isPet then "UNEQUIP"
		elseif isEquipped then "EQUIPPED"
		else "EQUIP"
	local can = entry.owned and not (isEquipped and not isPet)
	local equip = Kit.nativeButton(
		holder,
		label,
		if can then Kit.green else Color3.fromRGB(80, 84, 96),
		function()
			if can then
				close()
				onEquip()
			end
		end
	)
	equip.Position, equip.Size = UDim2.fromScale(0.08, 0.84), UDim2.fromScale(0.5, 0.12)
	local shut = Kit.nativeButton(holder, "CLOSE", Color3.fromRGB(80, 84, 96), close)
	shut.Position, shut.Size = UDim2.fromScale(0.62, 0.84), UDim2.fromScale(0.3, 0.12)
	for _, button in { equip, shut } do
		for _, d in button:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 42
			end
		end
		button.ZIndex = 42
	end
	for _, d in panel:GetDescendants() do
		if d:IsA("GuiObject") and d ~= guard then
			d.ZIndex += 41
		end
	end
	for _, d in banner:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 43)
		end
	end
	for _, d in ribbon:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 43)
		end
	end
	for _, d in list:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 43)
		end
	end
	SoundFx.play("new_item")
end
--[[ The screen's design canvas: 1920 wide and 9:16 tall, the owner's
     reference (a phone gear screen, 2026-10-27: "i want it ONE to ONE")
     laid out piece for piece at its own proportions (its 683 x 1170 shot
     scaled 2.81 across, 2.92 down); on a wide screen the column stands
     centred over the jungle. Our own art and words throughout. ]]
local TALL = 3413
local function put(item: GuiObject, x: number, y: number, w: number, h: number)
	Kit.put(item, x, y * 1080 / TALL, w, h * 1080 / TALL)
end
local NAVY = Color3.fromRGB(26, 32, 62)
local NAVY_DARK = Color3.fromRGB(16, 20, 40)
local LETTER = {
	Common = "C",
	Uncommon = "U",
	Rare = "R",
	Epic = "E",
	Legendary = "L",
	Mythic = "M",
}
local function corner(item: GuiObject, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(radius, 0)
	round.Parent = item
end
local function gradient(item: GuiObject, top: Color3, bottom: Color3)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(top, bottom)
	shade.Parent = item
end
local function rim(item: GuiObject, colour: Color3, canvasPx: number): UIStroke
	local edge = Instance.new("UIStroke")
	edge.Color = colour
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = item
	local function size()
		local canvas: Instance? = item.Parent
		while canvas and canvas.Name ~= "StationCanvas" do
			canvas = canvas.Parent
		end
		local unit = if canvas and canvas:IsA("GuiObject") then canvas.AbsoluteSize.X / 1920 else 1
		edge.Thickness = math.max(1, canvasPx * unit)
	end
	size()
	item:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
	return edge
end
local function frame(parent: Instance, colour: Color3): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Parent = parent
	return f
end
--[[ A round dark badge (the reference's small circles on every card). ]]
local function badge(
	parent: GuiObject,
	words: string,
	colour: Color3,
	x: number,
	y: number,
	size: number
)
	local dot = frame(parent, colour)
	dot.Position, dot.Size = UDim2.fromScale(x, y), UDim2.fromScale(size, size)
	dot.ZIndex = 8
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = dot
	corner(dot, 0.5)
	rim(dot, Color3.fromRGB(255, 236, 170), 4)
	local text = Kit.nativeText(dot, words)
	text.ZIndex = 9
	text.Position, text.Size = UDim2.fromScale(0.16, 0.18), UDim2.fromScale(0.68, 0.64)
	return dot
end
--[[ The reference's item card: the whole card its rarity's colour, light
     at the top and deeper at the bottom, a thick lighter rim, the picture
     big, the rarity's letter big in gold
     bottom-left, a count badge bottom-centre. Locked: grey, the picture a
     silhouette, a lock. ]]
local function card(
	parent: Instance,
	rarity: string,
	icon: string,
	locked: boolean,
	count: string?
): Frame
	local colour = if locked then Color3.fromRGB(120, 126, 140) else Kit.colour(rarity)
	local body = frame(parent, colour)
	body.Name = "Card"
	corner(body, 0.12)
	gradient(body, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	rim(body, colour:Lerp(Color3.new(1, 1, 1), 0.45), 9)
	-- the inner face: a deeper panel, as the reference's cards have
	local face = frame(body, colour:Lerp(Color3.new(0, 0, 0), 0.18))
	face.Position, face.Size = UDim2.fromScale(0.07, 0.06), UDim2.fromScale(0.86, 0.74)
	corner(face, 0.1)
	gradient(face, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190))
	if icon ~= "" then
		local picture = Kit.image(face, icon, locked)
		picture.Position, picture.Size = UDim2.fromScale(0.1, 0.06), UDim2.fromScale(0.8, 0.88)
		picture.ZIndex = 4
	end
	if locked then
		local lock = Kit.image(body, ShopAssets.lock)
		lock.Position, lock.Size = UDim2.fromScale(0.62, 0.52), UDim2.fromScale(0.3, 0.3)
		lock.ZIndex = 8
	elseif rarity == "Mythic" then
		Kit.rainbowRing(body)
	elseif rarity == "Legendary" then
		local halo = frame(body, Kit.gold)
		halo.BackgroundTransparency = 1
		halo.Position, halo.Size = UDim2.fromScale(-0.04, -0.04), UDim2.fromScale(1.08, 1.08)
		corner(halo, 0.14)
		local glow = rim(halo, Kit.gold, 6)
		Kit.animate(body, function(t)
			glow.Transparency = 0.45 + math.sin(t * 3) * 0.3
		end)
	end
	-- the big rarity letter, gold with a dark drop, bottom-left
	local letter = Kit.nativeText(body, if locked then "?" else LETTER[rarity] or "C", Kit.gold)
	letter.ZIndex = 9
	letter.Position, letter.Size = UDim2.fromScale(0.02, 0.62), UDim2.fromScale(0.32, 0.36)
	if count then
		badge(body, count, Color3.fromRGB(150, 24, 40), 0.38, 0.76, 0.24)
	end
	return body
end

local function lay(item: GuiObject, tall: Rect, wide: Rect)
	if wideLayout then
		Kit.put(item, wide[1], wide[2], wide[3], wide[4])
	else
		put(item, tall[1], tall[2], tall[3], tall[4])
	end
end
local function drawNative(s: StationScreen.Screen)
	local c, p = s.canvas, s.profile
	for _, child in c:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local player = Players.LocalPlayer
	local class = Classes[currentClass()] or Classes.Ranger
	local equipped = equippedForClass(p)
	local weapon = ShopRules.find(equipped)
	local petKeys: { string } = {}
	for slot = 1, 2 do
		local key = p and p.equippedPets[slot]
		if key then
			table.insert(petKeys, key)
		end
	end

	-- the showcase stage: our jungle temple behind the hero, darker at its foot
	local stage = Kit.image(c, GearAssets.backgrounds.gear)
	stage.ScaleType = Enum.ScaleType.Crop
	-- behind everything else on the canvas
	stage.ZIndex = 0
	lay(stage, { 0, 220, 1920, 1090 }, { 0, 110, 940, 970 })
	local foot = frame(stage, Color3.new(0, 0, 0))
	foot.Size = UDim2.fromScale(1, 1)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.7, 0.85),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	fade.Parent = foot

	-- the top bar: the player's picture, name and class; the wallet
	local bar = frame(c, NAVY_DARK)
	lay(bar, { 0, 0, 1920, 228 }, { 0, 0, 1920, 110 })
	gradient(bar, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 170))
	local avatar = frame(c, Color3.fromRGB(90, 50, 140))
	lay(avatar, { 30, 14, 210, 210 }, { 14, 8, 94, 94 })
	corner(avatar, 0.16)
	rim(avatar, Kit.gold, 8)
	local head = Instance.new("ImageLabel")
	head.BackgroundTransparency = 1
	head.Position, head.Size = UDim2.fromScale(0.06, 0.06), UDim2.fromScale(0.88, 0.88)
	head.Parent = avatar
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if ok and head.Parent then
			head.Image = image
		end
	end)
	local name = Kit.nativeText(c, string.upper(player.DisplayName))
	lay(name, { 270, 28, 520, 80 }, { 124, 10, 420, 46 })
	name.TextXAlignment = Enum.TextXAlignment.Left
	local role = Kit.nativeText(c, string.upper(currentClass()), Kit.gold)
	lay(role, { 270, 120, 420, 74 }, { 124, 60, 300, 40 })
	role.TextXAlignment = Enum.TextXAlignment.Left
	s.wallet(c, if p then p.coins else 0, if p then p.gems else 0)

	-- the hero, big in the middle of the stage
	portrait(c, function(item)
		lay(item, { 400, 228, 1120, 1080 }, { 210, 120, 520, 820 })
	end, equipped, petKeys)

	-- the slots: three down each side, each a card with its name on a tab
	local function makeSlot(
		words: string,
		column: number,
		row: number,
		rarity: string?,
		icon: string?,
		locked: boolean
	): Frame
		local holder = frame(c, Color3.new(0, 0, 0))
		holder.BackgroundTransparency = 1
		lay(
			holder,
			{ if column == 1 then 126 else 1498, 300 + (row - 1) * 330, 296, 296 },
			{ if column == 1 then 40 else 740, 170 + (row - 1) * 230, 170, 170 }
		)
		local tile = card(holder, rarity or "Common", icon or "", locked)
		tile.Size = UDim2.fromScale(1, 1)
		if not icon or icon == "" then
			local letter = tile:FindFirstChild("NativeText")
			if letter and letter:IsA("TextLabel") and not locked then
				letter.Visible = false
			end
		end
		-- the name tab on the card's top edge (the reference's "Lv." tab)
		local plate = frame(holder, NAVY_DARK)
		plate.Position, plate.Size = UDim2.fromScale(0.2, -0.08), UDim2.fromScale(0.6, 0.17)
		plate.ZIndex = 10
		corner(plate, 0.4)
		local tabText = Kit.nativeText(plate, words)
		tabText.ZIndex = 11
		return holder
	end
	local weaponSlot = makeSlot(
		"WEAPON",
		1,
		1,
		if weapon then weapon.rarity else "Common",
		GearAssets.weapons[equipped],
		false
	)
	makeSlot("TRAIL", 1, 2, nil, nil, true)
	makeSlot("SOON", 1, 3, nil, nil, true)
	makeSlot("SOON", 2, 3, nil, nil, true)
	local petSlots: { GuiObject } = {}
	for index = 1, 2 do
		local key = p and p.equippedPets[index]
		local info = key and Pets[key]
		local slot = makeSlot(
			"PET " .. tostring(index),
			2,
			index,
			if info then info.rarity else nil,
			if key then GearAssets.pets[key] else nil,
			false
		)
		if not key then
			local plus = Kit.nativeText(slot, "+")
			plus.ZIndex = 9
			plus.Position, plus.Size = UDim2.fromScale(0.3, 0.25), UDim2.fromScale(0.4, 0.4)
		end
		Kit.nativePress(slot, function()
			if key and not Reveal.busy() then
				Remotes.event(Remotes.EquipPet):FireServer(index, nil)
			end
		end)
		petSlots[index] = slot
	end

	-- ATK and HP under the hero, each with its pixel icon
	local stats = WeaponStats.weapons[equipped]
	local scale = if stats
		then (1 + WeaponStats.bonus[stats.rarity]) * (WeaponStats.areaScale[stats.area] or 1)
		else 1
	local chosenClass = if weapon then Classes[weapon.class] or class else class
	local values = {
		{
			"ATK",
			tostring(math.round(Balance.Player.baseDamage * chosenClass.damageScale * scale)),
			GearAssets.uiIcons.sword,
		},
		{ "HP", tostring(Balance.Player.maxHealth), GearAssets.uiIcons.heart },
	}
	for i, entry in values do
		local pill = frame(c, Color3.fromRGB(34, 28, 24))
		pill.BackgroundTransparency = 0.15
		lay(pill, { 576 + (i - 1) * 390, 1160, 370, 122 }, { 250 + (i - 1) * 230, 960, 210, 90 })
		corner(pill, 0.3)
		rim(pill, Color3.fromRGB(70, 58, 44), 4)
		local icon = Kit.image(pill, entry[3])
		icon.Position, icon.Size = UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.3, 0.62)
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = icon
		local label = Kit.nativeText(pill, entry[1])
		label.Position, label.Size = UDim2.fromScale(0.04, 0.66), UDim2.fromScale(0.28, 0.3)
		label.ZIndex = 8
		local value = Kit.nativeText(pill, entry[2])
		value.Position, value.Size = UDim2.fromScale(0.36, 0.2), UDim2.fromScale(0.58, 0.6)
	end

	-- the sheet: navy, its tabs along the top edge
	local sheet = frame(c, NAVY)
	lay(sheet, { 0, 1500, 1920, 1568 }, { 940, 110, 980, 970 })
	gradient(sheet, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200))
	local tabsBack = frame(c, NAVY_DARK)
	lay(tabsBack, { 0, 1300, 1920, 210 }, { 940, 110, 980, 120 })
	local tabs: { { id: string, words: string, icon: string } } = {
		{ id = "CLASSES", words = "CLASSES", icon = GearAssets.uiIcons.archerHead },
		{ id = "GEAR", words = "WEAPON", icon = GearAssets.uiIcons.swordTab },
		{ id = "PETS", words = "PETS", icon = GearAssets.uiIcons.egg },
	}
	for i, entry in tabs do
		local selected = tab == entry.id
		local tabButton = frame(c, if selected then Kit.gold else Color3.fromRGB(44, 52, 90))
		lay(tabButton, {
			34 + (i - 1) * 622,
			if selected then 1300 else 1322,
			606,
			if selected then 210 else 170,
		}, {
			954 + (i - 1) * 322,
			if selected then 114 else 126,
			312,
			if selected then 116 else 96,
		})
		corner(tabButton, 0.18)
		gradient(
			tabButton,
			Color3.new(1, 1, 1),
			if selected then Color3.fromRGB(230, 170, 60) else Color3.fromRGB(170, 170, 170)
		)
		rim(
			tabButton,
			if selected then Color3.fromRGB(255, 240, 170) else Color3.fromRGB(70, 82, 130),
			5
		)
		if entry.icon ~= "" then
			local glyph = Kit.image(tabButton, entry.icon)
			glyph.Position, glyph.Size = UDim2.fromScale(0.06, 0.14), UDim2.fromScale(0.18, 0.72)
			local square = Instance.new("UIAspectRatioConstraint")
			square.Parent = glyph
		end
		local text = Kit.nativeText(tabButton, entry.words)
		text.Position, text.Size = UDim2.fromScale(0.28, 0.22), UDim2.fromScale(0.66, 0.56)
		Kit.nativePress(tabButton, function()
			if not Reveal.busy() and not selected then
				tab = entry.id
				s.open()
			end
		end)
	end
	-- the toolbar: sort left, TRAILS right
	local function goldPill(words: string, left: boolean, action: () -> ()): Frame
		local pill = frame(c, Kit.gold)
		lay(
			pill,
			{ if left then 70 else 1418, 1556, 436, 160 },
			{ if left then 970 else 1610, 250, 280, 84 }
		)
		corner(pill, 0.3)
		gradient(pill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(235, 150, 40))
		rim(pill, Color3.fromRGB(150, 80, 10), 6)
		local text = Kit.nativeText(pill, words)
		text.Position, text.Size = UDim2.fromScale(0.08, 0.24), UDim2.fromScale(0.84, 0.52)
		Kit.nativePress(pill, action)
		return pill
	end
	goldPill(if byName then "BY NAME" else "BY RARITY", true, function()
		if not Reveal.busy() then
			byName = not byName
			s.open()
		end
	end)
	goldPill("TRAILS", false, function()
		if not Reveal.busy() and tab ~= "TRAILS" then
			tab = "TRAILS"
			s.open()
		end
	end)
	local divider = frame(c, Color3.fromRGB(60, 72, 120))
	lay(divider, { 40, 1750, 1840, 6 }, { 960, 350, 940, 4 })

	-- the grid: five cards a row
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
				icon = GearAssets.weapons[entry.weapon] or "",
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
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "InventoryGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Kit.gold
	grid.Parent = c
	lay(grid, { 80, 1790, 1760, 1260 }, { 970, 370, 920, 560 })
	grid.CanvasSize = UDim2.fromScale(0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	-- the reference's card and gap, as shares of the visible grid
	if wideLayout then
		layout.CellSize = UDim2.fromScale(164 / 920, 164 / 560)
		layout.CellPadding = UDim2.fromScale(20 / 920, 22 / 560)
	else
		layout.CellSize = UDim2.fromScale(316 / 1760, 316 / 1260)
		layout.CellPadding = UDim2.fromScale(34 / 1760, 40 / 1260)
	end
	layout.Parent = grid
	if tab == "CLASSES" then
		for i, className in { "Ranger", "Arcanist", "Warden" } do
			local selected = className == currentClass()
			local holder = frame(grid, Color3.new(0, 0, 0))
			holder.BackgroundTransparency = 1
			holder.LayoutOrder = i
			local tile = card(
				holder,
				if selected then "Legendary" else "Common",
				GearAssets.weapons[Classes[className].weapon] or "",
				false
			)
			tile.Size = UDim2.fromScale(1, 1)
			local title = frame(holder, NAVY_DARK)
			title.Position, title.Size = UDim2.fromScale(0.08, -0.06), UDim2.fromScale(0.84, 0.18)
			title.ZIndex = 10
			corner(title, 0.4)
			Kit.nativeText(title, string.upper(className)).ZIndex = 11
			Kit.nativePress(holder, function()
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
		-- trails do not exist yet: their slots, locked
		for i = 1, 5 do
			local holder = frame(grid, Color3.new(0, 0, 0))
			holder.BackgroundTransparency = 1
			holder.LayoutOrder = i
			local soon = card(holder, "Common", "", true)
			soon.Size = UDim2.fromScale(1, 1)
			local text = Kit.nativeText(soon, "SOON")
			text.ZIndex = 9
			text.Position, text.Size = UDim2.fromScale(0.1, 0.3), UDim2.fromScale(0.8, 0.22)
		end
	end
	for i, entry in entries do
		local isPet = tab == "PETS"
		local isEquipped = if isPet
			then p ~= nil and (p.equippedPets[1] == entry.key or p.equippedPets[2] == entry.key)
			else equipped == entry.key
		local holder = frame(grid, Color3.new(0, 0, 0))
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = i
		local tile = card(
			holder,
			entry.rarity,
			entry.icon,
			not entry.owned,
			if isPet and entry.owned then tostring(entry.count) elseif isEquipped then "E" else nil
		)
		tile.Size = UDim2.fromScale(1, 1)
		if isEquipped then
			Kit.owned(tile)
		end
		Kit.nativePress(holder, function()
			if Reveal.busy() or not p then
				return
			end
			details(c, entry, isPet, isEquipped, function()
				if isPet and isEquipped then
					for slot = 1, 2 do
						if p.equippedPets[slot] == entry.key then
							Remotes.event(Remotes.EquipPet):FireServer(slot, nil)
						end
					end
				elseif isPet then
					local slot = if not p.equippedPets[1]
						then 1
						elseif not p.equippedPets[2] then 2
						else 1
					Reveal.equip(holder, petSlots[slot], entry.icon, true)
					Remotes.event(Remotes.EquipPet):FireServer(slot, entry.key)
				else
					Reveal.equip(holder, weaponSlot, entry.icon, false)
					Remotes.event(Remotes.ShopEquip):FireServer(entry.key)
				end
			end)
		end)
	end

	-- the bottom bar: the lobby's screens, ours raised in gold
	local nav = frame(c, NAVY_DARK)
	lay(nav, { 0, 3068, 1920, 345 }, { 940, 945, 980, 135 })
	gradient(nav, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150))
	local crate = GearAssets.crates.MossyGlade
	local egg = GearAssets.eggs.MossyEgg
	local items: { { words: string, picture: string, tall: Rect, wide: Rect } } = {
		{
			words = "BLACKSMITH",
			picture = if crate then crate.closed else "",
			tall = { 60, 3090, 360, 320 },
			wide = { 960, 952, 210, 124 },
		},
		{
			words = "WEAPON",
			picture = GearAssets.weapons[equipped] or "",
			tall = { 430, 3010, 520, 400 },
			wide = { 1185, 920, 280, 156 },
		},
		{
			words = "LOBBY",
			picture = "",
			tall = { 970, 3090, 360, 320 },
			wide = { 1480, 952, 190, 124 },
		},
		{
			words = "HATCHERY",
			picture = if egg then egg.whole else "",
			tall = { 1360, 3090, 360, 320 },
			wide = { 1685, 952, 210, 124 },
		},
	}
	for _, item in items do
		local words, picture = item.words, item.picture
		local here = words == "WEAPON"
		local button = frame(c, if here then Kit.gold else NAVY_DARK)
		button.BackgroundTransparency = if here then 0 else 1
		lay(button, item.tall, item.wide)
		if here then
			corner(button, 0.14)
			gradient(button, Color3.fromRGB(255, 255, 255), Color3.fromRGB(230, 160, 40))
			rim(button, Color3.fromRGB(255, 240, 170), 6)
		end
		if picture ~= "" then
			local icon = Kit.image(button, picture)
			icon.Position, icon.Size = UDim2.fromScale(0.1, -0.06), UDim2.fromScale(0.8, 0.78)
			local square = Instance.new("UIAspectRatioConstraint")
			square.Parent = icon
		else
			local arrow = Kit.nativeText(button, "<")
			arrow.Position, arrow.Size = UDim2.fromScale(0.25, 0.08), UDim2.fromScale(0.5, 0.5)
		end
		local label =
			Kit.nativeText(button, words, if here then Color3.fromRGB(60, 36, 10) else nil)
		label.Position, label.Size = UDim2.fromScale(0.04, 0.68), UDim2.fromScale(0.92, 0.26)
		Kit.nativePress(button, function()
			if here or Reveal.busy() then
				return
			end
			s.close()
			if words == "BLACKSMITH" then
				StationScreen.openShortcut(ShopScreen.open)
			elseif words == "HATCHERY" then
				StationScreen.openShortcut(EggScreen.open)
			end
		end)
	end
end
function GearScreen.start()
	if screen then
		return
	end
	local s = StationScreen.new("GearScreen", "GearStation", "GEAR")
	screen = s
	local layer = Instance.new("ScreenGui")
	layer.Name = "GearBackground"
	layer.IgnoreGuiInset = true
	layer.ScreenInsets = Enum.ScreenInsets.None
	layer.ResetOnSpawn = false
	layer.DisplayOrder = s.gui.DisplayOrder - 1
	layer.Enabled = false
	layer.Parent = s.gui.Parent
	local backdrop = Kit.image(layer, GearAssets.backgrounds.gear)
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ScaleType = Enum.ScaleType.Crop
	backdrop.ResampleMode = Enum.ResamplerMode.Default
	backdrop:ClearAllChildren()
	local dim = s.canvas.Parent :: GuiObject
	local function follow()
		layer.Enabled = dim.Visible and GearAssets.backgrounds.gear ~= ""
		dim.BackgroundTransparency = 1
	end
	s.connect(dim:GetPropertyChangedSignal("Visible"), follow)
	s.gui.Destroying:Once(function()
		layer:Destroy()
	end)
	local lastUpright = false
	s.connect(dim:GetPropertyChangedSignal("AbsoluteSize"), function()
		local upright = dim.AbsoluteSize.Y > dim.AbsoluteSize.X
		if upright ~= lastUpright and s.isOpen() and not Reveal.busy() then
			s.open()
		end
	end)
	s.wallet = function(parent: Instance, coins: number, gems: number)
		for i, entry in
			{ { icon = ShopAssets.coin, amount = coins }, { icon = ShopAssets.gem, amount = gems } }
		do
			local pill = Instance.new("Frame")
			pill.Name = "Wallet"
			pill.BorderSizePixel = 0
			pill.BackgroundColor3 = Color3.fromRGB(12, 16, 32)
			pill.Parent = parent
			if wideLayout then
				Kit.put(pill, 1360 + (i - 1) * 280, 20, 260, 70)
			else
				Kit.put(pill, 830 + (i - 1) * 540, 52 * 1080 / 3413, 500, 120 * 1080 / 3413)
			end
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = pill
			local icon = Kit.image(pill, entry.icon)
			icon.Position, icon.Size = UDim2.fromScale(-0.06, -0.12), UDim2.fromScale(0.3, 1.24)
			icon.ZIndex = 3
			local text = Kit.nativeText(pill, tostring(entry.amount))
			text.Position, text.Size = UDim2.fromScale(0.28, 0.16), UDim2.fromScale(0.66, 0.68)
		end
	end
	s.draw = function()
		follow()
		lastUpright = dim.AbsoluteSize.Y > dim.AbsoluteSize.X
		-- the reference's tall column on an upright screen, landscape otherwise
		wideLayout = not lastUpright
		local aspect = s.canvas:FindFirstChildOfClass("UIAspectRatioConstraint")
		if aspect then
			aspect.AspectRatio = if wideLayout then 16 / 9 else 9 / 16
		end
		drawNative(s)
	end
end
return GearScreen
