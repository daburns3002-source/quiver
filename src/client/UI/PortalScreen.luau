--!strict
--[[
	A portal's screen (owner, 2026-10-26: "need screen for portal entry with
	the level selector"). Walking into a lit portal's mouth no longer starts
	the run: the server sees the player there and sends the portal's index
	(`Remotes.PortalOpen`, 0 as they step out), and this shows the area — its
	name in the portal's colour, its act — and its levels to pick from, each
	with its boss, its rooms and whether it is cleared (the profile's
	`bossesBeaten`), then locked COMING SOON slots up to
	`Config/Lobby.levelSlots`. An area with more levels than that (Mossy
	Glade's ten, owner 2026-10-26: "2 ROWS OF 5 LEVELS EACH") shows them as
	a grid of numbered buttons, `Config/Lobby.levelColumns` to a row: a
	locked one dimmed under a lock, a beaten one marked CLEARED in gold, the
	picked one framed in gold, with its rooms or waves (and its boss) on the
	line under the grid. Which are open is `Util/LevelUnlocks` over the
	profile's `levelsBeaten`; the server checks it again on START. START asks
	the server (`Remotes.PortalStart`), which checks the player still stands
	at that portal and has that level open, and starts the run; X, Escape or
	walking away closes it.

	Built like the Blacksmith's shop (`UI/ShopScreen`): blocky wood boxes
	with an ink border, every word in the blocky font (rule 11), buttons
	still until hovered or pressed. The boss pictures are the boss banners'
	Codex icons (`Config/BossBanners`), their first frame. On a screen taller
	than it is wide (a phone, held upright) the level cards stack as rows,
	picture beside words, instead of standing side by side.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossBanners = require(ReplicatedStorage.Shared.Config.BossBanners)
local LevelUnlocks = require(ReplicatedStorage.Shared.Util.LevelUnlocks)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)

local Device = require(script.Parent.Parent.Device)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local PortalScreen = {}

local FONT = Font.fromEnum(Enum.Font.Arcade)
local INK = Color3.fromRGB(24, 16, 10)
local WOOD = Color3.fromRGB(78, 52, 32)
local PLANK = Color3.fromRGB(58, 38, 24)
local GOLD = Color3.fromRGB(255, 206, 74)
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(70, 176, 58)
local RED = Color3.fromRGB(196, 64, 52)
local GREY = Color3.fromRGB(96, 92, 88)
local LOCKED = Color3.fromRGB(40, 34, 30)

type Slot = { frame: Frame, face: Frame, button: TextButton, level: number? }
--[[ A numbered button of the grid: the `position`th of the portal's levels. ]]
type Tile = { frame: Frame, position: number, open: boolean }

local gui: ScreenGui? = nil
local panel: Frame? = nil
local startButton: TextButton? = nil
local startFace: Frame? = nil
local startWords: TextLabel? = nil
local profile: SaveSchema.Profile? = nil
--[[ The portal showing (its index in `Config/Lobby.portals`), the level
     picked, and whether START has been pressed. ]]
local portalIndex: number? = nil
local picked = 1
local starting = false
local slots: { Slot } = {}
local levelRow: Frame? = nil
local levelList: UIListLayout? = nil
--[[ Whether the cards are laid as rows, for an upright screen. ]]
local rows = false
--[[ The grid of numbered levels, for an area with more than
     `levelSlots` (`fillGrid`), and the line under it naming the pick. ]]
local levelGrid: Frame? = nil
local gridInfo: TextLabel? = nil
local tiles: { Tile } = {}
local grid = false

--[[ Where a piece of a card goes, as {x, y, w, h} shares of the card: `tall`
     for a card standing in a row of them, `wide` for one of a stack. ]]
local function put(item: GuiObject, tall: { number }, wide: { number })
	local at = if rows then wide else tall
	item.Position = UDim2.fromScale(at[1], at[2])
	item.Size = UDim2.fromScale(at[3], at[4])
end

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

--[[ A blocky box: an ink border round a face, with a lighter top edge. ]]
local function box(parent: Instance, name: string, face: Color3, z: number): (Frame, Frame)
	local outer = rect(parent, name, INK, z)
	local inner = rect(outer, "Face", face, z + 1)
	inner.Position = UDim2.fromOffset(3, 3)
	inner.Size = UDim2.new(1, -6, 1, -6)
	local top = rect(inner, "Shine", face:Lerp(WHITE, 0.25), z + 1)
	top.Size = UDim2.new(1, 0, 0, 3)
	return outer, inner
end

local function hit(parent: Instance, z: number): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Size = UDim2.fromScale(1, 1)
	b.ZIndex = z
	b.AutoButtonColor = false
	b.Parent = parent
	return b
end

--[[ The boss banner (`Config/BossBanners`) of the area named `area`. ]]
local function bannerFor(area: string?): BossBanners.Banner?
	for _, banner in BossBanners.bosses do
		if banner.area == area then
			return banner
		end
	end
	return nil
end

--[[ The levels this player has beaten, from their profile. ]]
local function beaten(): LevelUnlocks.Beaten?
	local p = profile
	return if p then p.levelsBeaten else nil
end

local function close()
	local screen = gui
	if screen then
		screen.Enabled = false
	end
	if startButton and GuiService.SelectedObject == startButton then
		GuiService.SelectedObject = nil
	end
	portalIndex = nil
	starting = false
end

local function start()
	local index = portalIndex
	local portal = index and LobbyConfig.portals[index]
	local levels = portal and portal.levels
	if not index or not levels or not levels[picked] or starting then
		return
	end
	--[[ The portal's own gate (Endless waits on 1-10), then the level's.
	     The server checks both again on START, and its answer is the one
	     that decides (`Run/Lobby.startFor`). ]]
	if not LevelUnlocks.portalOpen(portal and portal.requires, beaten()) then
		return
	end
	if not LevelUnlocks.isUnlocked(levels, Balance.Stages, beaten(), picked) then
		return
	end
	starting = true
	SoundFx.play("card_click")
	Remotes.event(Remotes.PortalStart):FireServer(index, picked)
end

--[[ How big a stage is, in its own unit: rooms, waves, or — for Endless,
     which has no last floor — the hard cap it stops at
     (`Balance.Endless.maxFloor`, `docs/ENDLESS.md`). ]]
local function sizeOf(stage: Balance.StageConfig): string
	if stage.mode == "Endless" then
		return `ENDLESS FLOORS`
	end
	return if stage.mode == "Waves"
		then `{stage.waves or 0} WAVES`
		else `{#(stage.rooms or {})} ROOMS`
end

--[[ What the line under the grid says of the picked level: its number,
     its rooms or waves, and its boss if it ends in one. ]]
local function describe(stage: Balance.StageConfig): string
	if stage.mode == "Endless" then
		return `{sizeOf(stage)}, EVERY 10TH A BOSS`
	end
	local size = sizeOf(stage)
	local finale = stage.finale
	local first = finale and finale.roster[1]
	local boss = first and first.boss
	local words = `LEVEL {stage.level or ""}: {size}`
	if boss then
		-- the boss by its banner's name (King Bloblin), as the boss bar shows it
		local banner = BossBanners.bosses[boss.title]
		local name = if banner then banner.name else boss.title
		words ..= `, THEN {string.upper(name)}`
	end
	return words
end

--[[ The grid: one numbered button per level, `levelColumns` to a row, in
     order (Mossy Glade 1-1..1-5 above 1-6..1-10). ]]
local function fillGrid(levels: { number })
	local frame = levelGrid
	if not frame then
		return
	end
	for _, tile in tiles do
		tile.frame:Destroy()
	end
	table.clear(tiles)
	local done = beaten()
	local columns = math.max(LobbyConfig.levelColumns, 1)
	local lines = math.max(math.ceil(#levels / columns), 1)
	local gapX, gapY = 0.025, 0.08
	local w = (1 - gapX * (columns - 1)) / columns
	local h = (1 - gapY * (lines - 1)) / lines
	if not LevelUnlocks.isUnlocked(levels, Balance.Stages, done, picked) then
		picked = LevelUnlocks.suggested(levels, Balance.Stages, done)
	end
	for position, index in levels do
		local stage = Balance.Stages[index]
		local open = LevelUnlocks.isUnlocked(levels, Balance.Stages, done, position)
		local cleared = LevelUnlocks.isBeaten(stage, done)
		local column = (position - 1) % columns
		local line = (position - 1) // columns
		local card, face = box(frame, `Level{position}`, if open then PLANK else LOCKED, 10)
		card.Position = UDim2.fromScale(column * (w + gapX), line * (h + gapY))
		card.Size = UDim2.fromScale(w, h)
		local name = if stage then stage.level or tostring(position) else ""
		local number = label(face, name, if open then GOLD else GREY, 14, 34)
		number.Name = "Number"
		number.Position = UDim2.fromScale(0.06, if open then 0.14 else 0.08)
		number.Size = UDim2.fromScale(0.88, 0.38)
		if not open then
			-- locked: dimmed, under a lock
			face.BackgroundTransparency = 0.25
			local lock = Instance.new("ImageLabel")
			lock.Name = "Lock"
			lock.BackgroundTransparency = 1
			lock.ScaleType = Enum.ScaleType.Fit
			lock.Image = ShopAssets.lock
			lock.ImageTransparency = 0.15
			lock.Position = UDim2.fromScale(0.25, 0.5)
			lock.Size = UDim2.fromScale(0.5, 0.42)
			lock.ZIndex = 14
			lock.Parent = face
		else
			local chip, chipFace = box(face, "Status", if cleared then GOLD else GREEN, 14)
			chip.Position = UDim2.fromScale(0.08, 0.6)
			chip.Size = UDim2.fromScale(0.84, 0.28)
			local words = label(chipFace, if cleared then "CLEARED" else "PLAY", WHITE, 16, 14)
			words.Position = UDim2.fromScale(0.06, 0.15)
			words.Size = UDim2.fromScale(0.88, 0.7)
		end
		local b = hit(card, 20)
		local tile: Tile = { frame = card, position = position, open = open }
		b.Activated:Connect(function()
			if tile.open and not starting then
				picked = tile.position
				SoundFx.play("card_click")
			end
		end)
		table.insert(tiles, tile)
	end
end

--[[ Fills the panel for portal `index`. ]]
local function fill(index: number)
	local p = panel
	local portal = LobbyConfig.portals[index]
	if not p or not portal then
		return
	end
	local tint = portal.tint or GOLD
	local banner = bannerFor(portal.name)
	local header = p:FindFirstChild("Header") :: Frame
	local headerFace = header:FindFirstChild("Face") :: Frame
	headerFace.BackgroundColor3 = tint:Lerp(INK, 0.35)
	local name = header:FindFirstChild("AreaName") :: TextLabel
	name.Text = string.upper(portal.name or "")
	local act = header:FindFirstChild("Act") :: TextLabel
	act.Text = if banner then string.upper(banner.act) else ""

	local levels = portal.levels or {}
	--[[ A portal with a `requires` this player has not beaten (Endless
	     before 1-10) draws its slot locked and says what opens it, rather
	     than looking playable and being refused on START. ]]
	local portalOpen = LevelUnlocks.portalOpen(portal.requires, beaten())
	grid = #levels > LobbyConfig.levelSlots
	if levelRow then
		levelRow.Visible = not grid
	end
	if levelGrid and gridInfo then
		levelGrid.Visible = grid
		gridInfo.Visible = grid
	end
	if grid then
		fillGrid(levels)
		return
	end
	picked = math.clamp(picked, 1, math.max(#levels, 1))
	for i, slot in slots do
		local stage = if portalOpen then Balance.Stages[levels[i]] else nil
		slot.level = if stage then i else nil
		local f = slot.face
		for _, child in f:GetChildren() do
			if child.Name ~= "Shine" then
				child:Destroy()
			end
		end
		local title = label(f, `LEVEL {i}`, if stage then GOLD else GREY, 14, 24)
		put(title, { 0.05, 0.04, 0.9, 0.12 }, { 0.36, 0.08, 0.6, 0.22 })
		if rows then
			title.TextXAlignment = Enum.TextXAlignment.Left
		end
		if stage then
			f.BackgroundColor3 = PLANK
			local pic = Instance.new("ImageLabel")
			pic.Name = "Boss"
			pic.BackgroundTransparency = 1
			pic.ScaleType = Enum.ScaleType.Fit
			put(pic, { 0.1, 0.18, 0.8, 0.42 }, { 0.03, 0.08, 0.3, 0.84 })
			pic.ZIndex = 14
			pic.Parent = f
			if banner and banner.icon ~= "" then
				-- the banner's sheet, its first frame (ready)
				local cell = BossBanners.sheet.cell
				pic.Image = banner.icon
				pic.ImageRectOffset = Vector2.zero
				pic.ImageRectSize = Vector2.new(cell, cell)
			end
			local boss = label(f, if banner then string.upper(banner.name) else "", WHITE, 14, 16)
			put(boss, { 0.05, 0.61, 0.9, 0.09 }, { 0.36, 0.34, 0.6, 0.16 })
			local rooms = label(f, sizeOf(stage), WHITE, 14, 16)
			put(rooms, { 0.05, 0.72, 0.9, 0.08 }, { 0.36, 0.52, 0.6, 0.13 })
			if rows then
				boss.TextXAlignment = Enum.TextXAlignment.Left
				rooms.TextXAlignment = Enum.TextXAlignment.Left
			end
			local p2 = profile
			local cleared = p2 ~= nil and stage.area ~= nil and p2.bossesBeaten[stage.area] == true
			local chip, chipFace = box(f, "Status", if cleared then GOLD else GREEN, 14)
			put(chip, { 0.12, 0.83, 0.76, 0.12 }, { 0.36, 0.7, 0.5, 0.22 })
			local words = label(chipFace, if cleared then "CLEARED" else "UNLOCKED", WHITE, 16, 16)
			words.Position = UDim2.fromScale(0.05, 0.15)
			words.Size = UDim2.fromScale(0.9, 0.7)
		else
			f.BackgroundColor3 = LOCKED
			local lock = Instance.new("ImageLabel")
			lock.Name = "Lock"
			lock.BackgroundTransparency = 1
			lock.ScaleType = Enum.ScaleType.Fit
			lock.Image = ShopAssets.lock
			put(lock, { 0.25, 0.25, 0.5, 0.4 }, { 0.08, 0.15, 0.2, 0.7 })
			lock.ZIndex = 14
			lock.Parent = f
			--[[ A locked portal says what opens it; an area not built yet
			     says COMING SOON, as before. ]]
			local words = if portalOpen or not portal.requires
				then "COMING SOON"
				else `BEAT {portal.requires}`
			local soon = label(f, words, GREY, 14, 16)
			put(soon, { 0.05, 0.75, 0.9, 0.1 }, { 0.36, 0.45, 0.6, 0.2 })
			if rows then
				soon.TextXAlignment = Enum.TextXAlignment.Left
			end
		end
	end
end

--[[ Repaints what changes from frame to frame: the picked level's gold
     border, and the buttons' hover and press. ]]
local function pose()
	for _, slot in slots do
		local chosen = slot.level ~= nil and slot.level == picked
		slot.frame.BackgroundColor3 = if chosen then GOLD else INK
	end
	local pickedOpen = true
	if grid then
		pickedOpen = false
		for _, tile in tiles do
			local chosen = tile.position == picked
			tile.frame.BackgroundColor3 = if chosen then GOLD else INK
			if chosen then
				pickedOpen = tile.open
			end
		end
		local index = portalIndex
		local portal = index and LobbyConfig.portals[index]
		local levels = portal and portal.levels
		local stage = levels and Balance.Stages[levels[picked]]
		if gridInfo then
			gridInfo.Text = if stage then describe(stage) else ""
		end
	end
	local face, button, words = startFace, startButton, startWords
	if face and button and words then
		local idle = starting or not pickedOpen
		local colour = if idle then GREY else GREEN
		local state = button.GuiState
		if not idle and state == Enum.GuiState.Press then
			colour = colour:Lerp(Color3.new(0, 0, 0), 0.3)
		elseif
			not idle and (state == Enum.GuiState.Hover or GuiService.SelectedObject == button)
		then
			colour = colour:Lerp(WHITE, 0.2)
		end
		face.BackgroundColor3 = colour
		words.Text = if starting
			then "STARTING..."
			elseif not pickedOpen then "LOCKED"
			elseif UserInputService.KeyboardEnabled and not Device.isPhone() then "START [ENTER]"
			else "START"
	end
end

local function build(playerGui: PlayerGui)
	local phone = Device.isPhone()
	local screen = Instance.new("ScreenGui")
	screen.Name = "PortalScreen"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.DisplayOrder = 114
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	local dim = rect(screen, "Dim", Color3.new(0, 0, 0), 1)
	dim.BackgroundTransparency = 0.5
	dim.Size = UDim2.new(1, 0, 1, 200)
	dim.Position = UDim2.fromOffset(0, -100)

	local p = box(screen, "Panel", WOOD, 2)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.5)
	p.Size = UDim2.fromScale(if phone then 0.96 else 0.62, if phone then 0.94 else 0.74)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(920, 620)
	limit.Parent = p
	panel = p

	-- the area's name on a band in its portal's colour
	local header = box(p, "Header", GOLD, 4)
	header.Position = UDim2.fromScale(0.03, 0.03)
	header.Size = UDim2.fromScale(0.94, 0.2)
	local areaName = label(header, "", WHITE, 7, 48)
	areaName.Name = "AreaName"
	areaName.Position = UDim2.fromScale(0.04, 0.1)
	areaName.Size = UDim2.fromScale(0.8, 0.5)
	areaName.TextXAlignment = Enum.TextXAlignment.Left
	local act = label(header, "", GOLD, 7, 20)
	act.Name = "Act"
	act.Position = UDim2.fromScale(0.04, 0.62)
	act.Size = UDim2.fromScale(0.6, 0.26)
	act.TextXAlignment = Enum.TextXAlignment.Left

	local x, xFace = box(p, "Close", RED, 8)
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -12, 0, 12)
	x.Size = UDim2.fromScale(0.08, 0.1)
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = x
	local xWords = label(xFace, "X", WHITE, 10, 26)
	xWords.Size = UDim2.fromScale(1, 1)
	local xHit = hit(x, 11)
	xHit.Activated:Connect(close)

	local pick = label(p, "CHOOSE A LEVEL", WHITE, 4, 22)
	pick.Position = UDim2.fromScale(0.05, 0.255)
	pick.Size = UDim2.fromScale(0.9, 0.06)

	-- the level cards
	local row = Instance.new("Frame")
	row.Name = "Levels"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromScale(0.04, 0.33)
	row.Size = UDim2.fromScale(0.92, 0.48)
	row.ZIndex = 4
	row.Parent = p
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.03, 0)
	list.Parent = row
	levelRow, levelList = row, list
	table.clear(slots)
	for i = 1, LobbyConfig.levelSlots do
		local card, face = box(row, `Level{i}`, PLANK, 10)
		card.LayoutOrder = i
		local b = hit(card, 20)
		local slot: Slot = { frame = card, face = face, button = b, level = nil }
		b.Activated:Connect(function()
			if slot.level and not starting then
				picked = slot.level
				SoundFx.play("card_click")
			end
		end)
		table.insert(slots, slot)
	end

	-- the grid, for an area of many levels (`fillGrid`), in the cards' place
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "LevelGrid"
	gridFrame.BackgroundTransparency = 1
	gridFrame.Position = UDim2.fromScale(0.05, 0.34)
	gridFrame.Size = UDim2.fromScale(0.9, 0.4)
	gridFrame.ZIndex = 4
	gridFrame.Visible = false
	gridFrame.Parent = p
	levelGrid = gridFrame
	local info = label(p, "", WHITE, 4, 20)
	info.Name = "LevelInfo"
	info.Position = UDim2.fromScale(0.05, 0.755)
	info.Size = UDim2.fromScale(0.9, 0.06)
	info.Visible = false
	gridInfo = info

	local go, goFace = box(p, "Start", GREEN, 8)
	go.AnchorPoint = Vector2.new(0.5, 0)
	go.Position = UDim2.fromScale(0.5, 0.84)
	go.Size = UDim2.fromScale(if phone then 0.5 else 0.36, 0.12)
	local goWords = label(goFace, "START", WHITE, 10, 28)
	goWords.Position = UDim2.fromScale(0.06, 0.18)
	goWords.Size = UDim2.fromScale(0.88, 0.64)
	local goHit = hit(go, 11)
	goHit.Activated:Connect(start)
	startButton, startFace, startWords = goHit, goFace, goWords
end

function PortalScreen.isOpen(): boolean
	local screen = gui
	return screen ~= nil and screen.Enabled
end

--[[ Lays the level cards out for the screen's shape: side by side, or
     stacked as rows on an upright screen. ]]
local function layCards(screen: ScreenGui)
	local row, list = levelRow, levelList
	if not row or not list then
		return
	end
	local view = screen.AbsoluteSize
	rows = view.Y > view.X
	local share = (1 - 0.03 * (LobbyConfig.levelSlots - 1)) / LobbyConfig.levelSlots
	list.FillDirection = if rows then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	for _, slot in slots do
		slot.frame.Size = if rows then UDim2.fromScale(1, share) else UDim2.fromScale(share, 1)
	end
	-- stacked, the cards take the panel's height down to START
	row.Size = UDim2.fromScale(0.92, if rows then 0.5 else 0.48)
end

--[[ Opens portal `index`'s screen, as if the server had sent it: for the
     server's message, and for a Studio capture. ]]
function PortalScreen.open(index: number)
	if Players.LocalPlayer:GetAttribute("ClassSelecting") == true then
		return
	end
	local screen = gui
	local portal = LobbyConfig.portals[index]
	if not screen or not portal or not portal.levels then
		return
	end
	layCards(screen)
	if portalIndex ~= index then
		-- the first open level not beaten yet (1 for a single-level area)
		picked = LevelUnlocks.suggested(portal.levels, Balance.Stages, beaten())
	end
	portalIndex = index
	starting = false
	fill(index)
	screen.Enabled = true
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = startButton
	end
end

PortalScreen.close = close

function PortalScreen.start()
	local player = Players.LocalPlayer
	build(player:WaitForChild("PlayerGui") :: PlayerGui)

	Remotes.event(Remotes.PortalOpen).OnClientEvent:Connect(function(index)
		if type(index) == "number" and index > 0 then
			PortalScreen.open(index)
		else
			close()
		end
	end)
	Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(next)
		if type(next) ~= "table" then
			return
		end
		profile = next
		local index = portalIndex
		if index and PortalScreen.isOpen() then
			fill(index)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not PortalScreen.isOpen() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			close()
		elseif
			not processed
			and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter)
		then
			start()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not PortalScreen.isOpen() then
			return
		end
		-- the run has begun (or the lobby is gone): nothing to choose
		if Workspace:GetAttribute("InLobby") ~= true then
			close()
			return
		end
		pose()
	end)
end

return PortalScreen
