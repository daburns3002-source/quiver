--!strict
--[[
	A portal's screen (owner, 2026-10-26: "need screen for portal entry with
	the level selector"). Walking into a lit portal's mouth no longer starts
	the run: the server sees the player there and sends the portal's index
	(`Remotes.PortalOpen`, 0 as they step out), and this shows the area and
	its levels to pick from. START asks the server (`Remotes.PortalStart`),
	which checks the player still stands at that portal and has that level
	open, and starts the run; X, Escape or walking away closes it.

	Drawn in the chunky style (owner, 2026-11-05, approving
	`assets/concepts/ui_refs/mockups/portal.jpg`): the blue panel with the
	area's name on the gold ribbon and its act on a pill under it, the
	levels as round numbered buttons in rows of `Config/Lobby.levelColumns`
	(Mossy Glade's ten, owner 2026-10-26: "2 ROWS OF 5 LEVELS EACH") joined
	by dotted paths, and a white card beside them naming the picked level,
	its rooms or waves, its boss, and PLAY. A beaten level is green, an open
	one blue, the picked one ringed in gold, a locked one grey under a lock;
	a level that ends in a boss carries the boss's banner icon. Which are
	open is `Util/LevelUnlocks` over the profile's `levelsBeaten`; the server
	checks it again on START.

	The whole panel is redrawn by `fill` whenever anything on it changes (a
	pick, the profile, the phone turning), on a 1920 x 1080 sheet, or
	1080 x 1920 when the phone is held upright.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossBanners = require(ReplicatedStorage.Shared.Config.BossBanners)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local LevelUnlocks = require(ReplicatedStorage.Shared.Util.LevelUnlocks)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)

local Chunky = require(script.Parent.Chunky)
local Kit = require(script.Parent.Kit)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local PortalScreen = {}

local gui: ScreenGui? = nil
local canvas: Frame? = nil
local startButton: TextButton? = nil
local profile: SaveSchema.Profile? = nil
--[[ The portal showing (its index in `Config/Lobby.portals`), the level
     picked, and whether START has been pressed. ]]
local portalIndex: number? = nil
local picked = 1
local starting = false

--[[ Where the panel's pieces sit, in sheet pixels. `nodes` is the box the
     level buttons share; `card` the white card and the rows down it. ]]
type Layout = {
	panel: { number },
	ribbon: { number },
	act: { number },
	close: { number },
	nodes: { number },
	card: { number },
	title: { number },
	size: { number },
	boss: { number },
	status: { number },
	--[[ What the level pays, a row of pictures and numbers above PLAY
	     (review item 10, as the mockup's coin and gem row). ]]
	rewards: { number },
	play: { number },
}

local WIDE: Layout = {
	panel = { 150, 104, 1620, 940 },
	ribbon = { 520, 22, 880, 150 },
	act = { 790, 168, 340, 72 },
	close = { 1688, 66, 108 },
	nodes = { 200, 270, 1060, 720 },
	card = { 1290, 262, 440, 748 },
	title = { 1314, 290, 392, 110 },
	size = { 1322, 420, 376, 86 },
	boss = { 1322, 524, 376, 130 },
	status = { 1342, 672, 336, 64 },
	rewards = { 1314, 748, 392, 86 },
	play = { 1314, 846, 392, 136 },
}

local TALL: Layout = {
	panel = { 30, 196, 1020, 1694 },
	ribbon = { 120, 116, 840, 150 },
	act = { 370, 256, 340, 72 },
	close = { 956, 150, 110 },
	nodes = { 70, 350, 940, 800 },
	card = { 70, 1180, 940, 670 },
	title = { 110, 1200, 860, 100 },
	size = { 110, 1308, 860, 72 },
	boss = { 110, 1390, 860, 80 },
	status = { 250, 1480, 580, 58 },
	rewards = { 110, 1546, 860, 88 },
	play = { 230, 1648, 620, 160 },
}

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

--[[ The boss a level ends in, if it ends in one: a Waves stage's
     `finale`, or a Rooms stage's last room (Mossy Glade 1-10 is King
     Bloblin alone in the Glade Heart, Thornwood the Broodmother in the
     Brood Heart). Read the same way `RoomController.endsInBoss` reads it,
     so the card and the boss drop can never disagree. ]]
local function bossOf(stage: Balance.StageConfig): Balance.EnemyBoss?
	local roster: { Balance.EnemyConfig }
	local finale = stage.finale
	if finale then
		roster = finale.roster
	else
		local rooms = stage.rooms or {}
		local last = Balance.Rooms[rooms[#rooms]]
		roster = if last then last.roster else {}
	end
	for _, config in roster do
		local boss = (config :: any).boss
		if boss then
			return boss
		end
	end
	return nil
end

--[[ The boss's line on the card: by its banner's name (King Bloblin), as
     the boss bar shows it. ]]
local function bossLine(stage: Balance.StageConfig): string
	if stage.mode == "Endless" then
		return "EVERY 10TH FLOOR A BOSS"
	end
	local boss = bossOf(stage)
	if not boss then
		return "NO BOSS"
	end
	local banner = BossBanners.bosses[boss.title]
	return `BOSS: {string.upper(if banner then banner.name else boss.title)}`
end

--[[ What winning a level pays (review item 10, owner 2026-11-11), as the
     server pays it (`Config/Economy`, `RoomController.complete`,
     `Wallet.beatBoss`): the area's free egg on the level's first clear,
     the clear's coins, and for a level that ends in its boss the gems
     (more the first time) and the boss's item. Kill coins come on top.
     Nothing for Endless, which pays Soulstones by the floor. ]]
type Reward = { icon: string, words: string? }
local function rewardsOf(stage: Balance.StageConfig, done: LevelUnlocks.Beaten?): { Reward }
	local area = stage.area
	local pay = area and Economy.areas[area]
	local list: { Reward } = {}
	if not area or not pay or stage.mode == "Endless" then
		return list
	end
	local egg = pay.firstClearEgg
	if egg and stage.level and not LevelUnlocks.isBeaten(stage, done) then
		local art = GearAssets.eggs[egg]
		local icon = if art then art.whole else GearAssets.areaPictures.eggs[area]
		if icon then
			table.insert(list, { icon = icon, words = "FREE" })
		end
	end
	table.insert(list, { icon = ShopAssets.coin, words = tostring(pay.clearCoins) })
	if bossOf(stage) then
		local p = profile
		local first = not (p and p.bossesBeaten[area])
		local gems = if first then pay.firstBossGems else pay.bossGems
		table.insert(list, { icon = ShopAssets.gem, words = tostring(gems) })
		local item = ShopAssets.items[pay.bossItem]
		if item then
			table.insert(list, { icon = item })
		end
	end
	return list
end

--[[ The rewards in a row: each one's picture, then its number, sized to
     share the row's width and never taller than it. ]]
local function rewardRow(sheet: Chunky.Sheet, rewards: { Reward }, box: { number })
	if #rewards == 0 then
		return
	end
	local row = Instance.new("Frame")
	row.Name = "Rewards"
	row.BackgroundTransparency = 1
	row.ZIndex = 6
	Chunky.put(sheet, row, box[1], box[2], box[3], box[4])
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.015, 0)
	list.Parent = row
	-- widths in pictures: a picture is 1, its words about half that a letter
	local total = 0
	for _, reward in rewards do
		total += 1 + (if reward.words then 0.2 + 0.5 * #reward.words else 0.15)
	end
	local unit = math.min(0.9 / total, box[4] / box[3])
	for i, reward in rewards do
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = reward.icon
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Size = UDim2.fromScale(unit, 0.96)
		icon.LayoutOrder = i * 2
		icon.ZIndex = 7
		icon.Parent = row
		local words = reward.words
		local t = Chunky.text(row, words or "", nil, 4)
		t.Name = "Words"
		t.Size = UDim2.fromScale(unit * (if words then 0.2 + 0.5 * #words else 0.15), 0.6)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.LayoutOrder = i * 2 + 1
		t.ZIndex = 7
	end
end

--[[ A pale blue pill with words, as the mockup's ROOMS and REWARD rows. ]]
local function pill(sheet: Chunky.Sheet, words: string, box: { number }, colour: Color3?)
	local p = Instance.new("Frame")
	p.Name = "Pill"
	p.BorderSizePixel = 0
	p.BackgroundColor3 = colour or Color3.fromRGB(170, 204, 255)
	p.ZIndex = 6
	Chunky.put(sheet, p, box[1], box[2], box[3], box[4])
	Chunky.round(p, math.min(box[4], 60))
	local t = Chunky.text(p, words, nil, 4)
	t.Position, t.Size = UDim2.fromScale(0.06, 0.16), UDim2.fromScale(0.88, 0.68)
	t.ZIndex = 7
end

--[[ A round level button: its number, a lock if shut, the boss's icon if
     it ends in one, a gold ring if picked. ]]
local function node(
	sheet: Chunky.Sheet,
	words: string,
	open: boolean,
	cleared: boolean,
	chosen: boolean,
	bossIcon: string?,
	x: number,
	y: number,
	size: number,
	action: () -> ()
)
	local holder = Instance.new("Frame")
	holder.Name = "Node"
	holder.BackgroundTransparency = 1
	holder.ZIndex = 6
	Chunky.put(sheet, holder, x, y, size, size)
	if chosen then
		for ring, spread in { 18, 10 } do
			local halo = Instance.new("Frame")
			halo.BackgroundTransparency = 1
			halo.AnchorPoint = Vector2.new(0.5, 0.5)
			halo.Position = UDim2.fromScale(0.5, 0.5)
			halo.Size = UDim2.fromScale(1 + spread / size * 2, 1 + spread / size * 2)
			halo.ZIndex = 5
			halo.Parent = holder
			Chunky.round(halo, size)
			local glow = Chunky.outline(halo, spread, Chunky.gold)
			glow.Transparency = ({ 0.6, 0 })[ring]
		end
	end
	local tone = if not open
		then Chunky.grey
		elseif chosen then Chunky.blue
		elseif cleared then Chunky.green
		else Chunky.blue
	local ball = Instance.new("Frame")
	ball.BorderSizePixel = 0
	ball.BackgroundColor3 = Color3.new(1, 1, 1)
	ball.Size = UDim2.fromScale(1, 1)
	ball.ZIndex = 6
	ball.Parent = holder
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color =
		ColorSequence.new(tone:Lerp(Color3.new(1, 1, 1), 0.3), tone:Lerp(Color3.new(0, 0, 0), 0.12))
	shade.Parent = ball
	Chunky.round(ball, size)
	Chunky.outline(ball, 7)
	local gloss = Instance.new("Frame")
	gloss.BorderSizePixel = 0
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.55
	gloss.Position, gloss.Size = UDim2.fromScale(0.2, 0.08), UDim2.fromScale(0.6, 0.26)
	gloss.ZIndex = 7
	gloss.Parent = ball
	Chunky.round(gloss, size)

	local lower = not open or (bossIcon ~= nil and bossIcon ~= "")
	local number = Chunky.text(ball, words, nil, 6)
	number.Position = UDim2.fromScale(0.12, if lower then 0.1 else 0.22)
	number.Size = UDim2.fromScale(0.76, if lower then 0.36 else 0.5)
	number.ZIndex = 9
	if bossIcon and bossIcon ~= "" then
		local cell = BossBanners.sheet.cell
		local face = Instance.new("ImageLabel")
		face.Name = "Boss"
		face.BackgroundTransparency = 1
		face.ScaleType = Enum.ScaleType.Fit
		face.Image = bossIcon
		face.ImageRectOffset = Vector2.zero
		face.ImageRectSize = Vector2.new(cell, cell)
		face.Position, face.Size = UDim2.fromScale(0.18, 0.42), UDim2.fromScale(0.64, 0.5)
		face.ZIndex = 8
		face.Parent = ball
	end
	if not open then
		local lock = Kit.image(ball, ShopAssets.lock)
		lock.Position = if bossIcon and bossIcon ~= ""
			then UDim2.fromScale(0.56, 0.6)
			else UDim2.fromScale(0.3, 0.48)
		lock.Size = if bossIcon and bossIcon ~= ""
			then UDim2.fromScale(0.34, 0.34)
			else UDim2.fromScale(0.4, 0.4)
		lock.ZIndex = 10
	elseif cleared then
		local tick = Chunky.text(ball, "CLEARED", Chunky.gold, 4)
		tick.Position, tick.Size = UDim2.fromScale(0.1, 0.72), UDim2.fromScale(0.8, 0.18)
		tick.ZIndex = 10
	end
	Chunky.press(holder, action)
end

local fill: (index: number) -> ()

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
	fill(index)
end

--[[ Draws the whole panel for portal `index`. ]]
fill = function(index: number)
	local c = canvas
	local portal = LobbyConfig.portals[index]
	if not c or not portal then
		return
	end
	for _, child in c:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local sheet = Chunky.sheet(c)
	local L = if sheet.upright then TALL else WIDE
	local banner = bannerFor(portal.name)
	local levels: { number } = portal.levels or {}
	local done = beaten()
	--[[ A portal with a `requires` this player has not beaten (Endless
	     before 1-10) draws every level locked and says what opens it,
	     rather than looking playable and being refused on START. ]]
	local portalOpen = LevelUnlocks.portalOpen(portal.requires, done)
	if portalOpen and not LevelUnlocks.isUnlocked(levels, Balance.Stages, done, picked) then
		picked = LevelUnlocks.suggested(levels, Balance.Stages, done)
	end
	picked = math.clamp(picked, 1, math.max(#levels, 1))

	Chunky.panel(sheet, table.unpack(L.panel))
	Chunky.ribbon(sheet, string.upper(portal.name or ""), table.unpack(L.ribbon))
	if banner then
		pill(sheet, string.upper(banner.act), L.act, Chunky.blue)
	end
	Chunky.close(sheet, L.close[1], L.close[2], L.close[3], close)

	--[[ The level buttons, `levelColumns` to a row, as big as fits, with a
	     dotted path from each to the next along its row. ]]
	local columns = math.min(math.max(LobbyConfig.levelColumns, 1), math.max(#levels, 1))
	local lines = math.max(math.ceil(#levels / columns), 1)
	local bx, by, bw, bh = L.nodes[1], L.nodes[2], L.nodes[3], L.nodes[4]
	local cell = math.min(bw / columns, bh / lines, 300)
	local size = cell * 0.76
	local left = bx + (bw - cell * columns) / 2
	local top = by + (bh - cell * lines) / 2
	for position, stageIndex in levels do
		local stage = Balance.Stages[stageIndex]
		local column = (position - 1) % columns
		local line = (position - 1) // columns
		local cx = left + column * cell + cell / 2
		local cy = top + line * cell + cell / 2
		if column < columns - 1 and position < #levels then
			for dot = 1, 3 do
				local d = Instance.new("Frame")
				d.BorderSizePixel = 0
				d.BackgroundColor3 = Chunky.white
				d.ZIndex = 5
				local step = (cell - size) / 4
				Chunky.put(sheet, d, cx + size / 2 + step * dot - 5, cy - 5, 10, 10)
				Chunky.round(d, 10)
				Chunky.outline(d, 2)
			end
		end
		local open = portalOpen and LevelUnlocks.isUnlocked(levels, Balance.Stages, done, position)
		local cleared = stage ~= nil and LevelUnlocks.isBeaten(stage, done)
		local icon = if stage and bossOf(stage) and banner then banner.icon else nil
		node(
			sheet,
			if stage then stage.level or tostring(position) else tostring(position),
			open,
			cleared,
			position == picked,
			icon,
			cx - size / 2,
			cy - size / 2,
			size,
			function()
				if open and not starting and picked ~= position then
					picked = position
					SoundFx.play("card_click")
					fill(index)
				end
			end
		)
	end

	-- the picked level's card
	Chunky.card(sheet, table.unpack(L.card))
	local stage = Balance.Stages[levels[picked]]
	local pickedOpen = portalOpen and LevelUnlocks.isUnlocked(levels, Balance.Stages, done, picked)
	local title = Chunky.text(
		c,
		if not portalOpen
			then "LOCKED"
			elseif stage then `LEVEL {stage.level or picked}`
			else "COMING SOON",
		nil,
		7
	)
	Chunky.put(sheet, title, table.unpack(L.title))
	title.ZIndex = 8
	if not portalOpen then
		pill(sheet, `BEAT {portal.requires or ""}`, L.size)
	elseif stage then
		pill(sheet, sizeOf(stage), L.size)
		pill(sheet, bossLine(stage), L.boss)
		if LevelUnlocks.isBeaten(stage, done) then
			pill(sheet, "CLEARED", L.status, Chunky.gold)
		elseif not pickedOpen then
			pill(sheet, "LOCKED", L.status, Chunky.grey)
		end
		rewardRow(sheet, rewardsOf(stage, done), L.rewards)
	end
	local idle = starting or not pickedOpen or stage == nil
	local play = Chunky.button(
		sheet,
		if starting then "STARTING..." elseif idle then "LOCKED" else "PLAY",
		if idle then Chunky.grey else Chunky.gold,
		L.play[1],
		L.play[2],
		L.play[3],
		L.play[4],
		start
	)
	startButton = play:FindFirstChildWhichIsA("TextButton", true)
end

function PortalScreen.isOpen(): boolean
	local screen = gui
	return screen ~= nil and screen.Enabled
end

local function build(playerGui: PlayerGui)
	local screen = Instance.new("ScreenGui")
	screen.Name = "PortalScreen"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- above the station screens (115), whose lobby wallet would cover the X
	screen.DisplayOrder = 116
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	-- the lobby dimmed behind, as the other chunky screens stand over it
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BorderSizePixel = 0
	dim.BackgroundColor3 = Color3.fromRGB(10, 14, 40)
	dim.BackgroundTransparency = 0.45
	dim.Size = UDim2.new(1, 0, 1, 200)
	dim.Position = UDim2.fromOffset(0, -100)
	dim.ZIndex = 1
	dim.Parent = screen

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 2
	holder.Parent = screen

	local c = Instance.new("Frame")
	c.Name = "Canvas"
	c.BackgroundTransparency = 1
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.5)
	c.Size = UDim2.fromScale(0.98, 0.98)
	c.ZIndex = 2
	c.Parent = holder
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 16 / 9
	aspect.Parent = c
	canvas = c

	-- lay out again when a phone turns between upright and landscape
	local upright = holder.AbsoluteSize.Y > holder.AbsoluteSize.X
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local now = holder.AbsoluteSize.Y > holder.AbsoluteSize.X
		local index = portalIndex
		if now ~= upright then
			upright = now
			if index and PortalScreen.isOpen() then
				fill(index)
			end
		end
	end)
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
	local fresh = not screen.Enabled or portalIndex ~= index
	if portalIndex ~= index then
		-- the first open level not beaten yet (1 for a single-level area)
		picked = LevelUnlocks.suggested(portal.levels, Balance.Stages, beaten())
	end
	portalIndex = index
	starting = false
	screen.Enabled = true
	fill(index)
	if fresh and canvas then
		Chunky.pop(canvas)
	end
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
		-- the run has begun (or the lobby is gone): nothing to choose
		if PortalScreen.isOpen() and Workspace:GetAttribute("InLobby") ~= true then
			close()
		end
	end)
end

return PortalScreen
