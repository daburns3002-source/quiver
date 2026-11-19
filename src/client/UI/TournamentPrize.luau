--!strict
--[[
	What last week's Endless tournament paid (`Remotes.TournamentPrize`,
	`Run/WeeklyTournament`): a chunky panel (`UI/Chunky`) on the join after
	a week ends, with the place, the floor and its time, the coins, gems
	and Soulstones, and the ENDLESS CHAMPION title for a winner.

	A top-ten week also gives themed set weapon picks (two for the winner):
	PICK! opens the second panel, every stocked set's weapons with the ones
	owned marked, and TAKE IT asks the server for the one chosen
	(`Remotes.TournamentPick`, `Wallet.pickTournamentWeapon`). Picks not
	taken wait in the save, and the server offers them again on the next
	join.

	Shows only, and asks. The server has already paid the week and taken it
	out of the save; closing this, or never seeing it, changes nothing. A
	week that ends mid-run is paid at once but shown only back in the lobby
	(`InLobby`, and the Player's `Arrived`), never over a fight. One coin
	and one diamond picture, `Config/ShopAssets`' (rule 15); the weapons'
	own 2D pictures.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemIcons = require(ReplicatedStorage.Shared.Util.ItemIcons)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local Tournament = require(ReplicatedStorage.Shared.Config.Tournament)

local Chunky = require(script.Parent.Chunky)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local TournamentPrize = {}

--[[ The panels, in points: this wide at most, `MARGIN` clear of the
     screen's edges. ]]
local WIDTH = 500
local PICK_WIDTH = 560
local MARGIN = 12
--[[ Points a set's row takes in the pick panel's list. ]]
local ROW = 96

type Paid = {
	kind: "Paid",
	place: number?,
	floor: number,
	time: string,
	gems: number,
	coins: number,
	soulstones: number,
	champion: boolean,
	picks: number,
}
type Item = { kind: "Paid", paid: Paid } | { kind: "Picks" }

local gui: ScreenGui? = nil
--[[ Panels still to show: two weeks can pay on one join. ]]
local queue: { Item } = {}
local open = false
local profile: SaveSchema.Profile? = nil
--[[ The pick panel's redraw when the profile comes back, while it is up. ]]
local onProfile: (() -> ())? = nil

local show: () -> ()

local function close()
	open = false
	onProfile = nil
	local screen = gui
	if screen then
		screen.Enabled = false
		screen:ClearAllChildren()
	end
	if #queue > 0 then
		task.defer(show)
	end
end

local function whole(value: unknown): number
	return if type(value) == "number" and value == value then math.max(math.floor(value), 0) else 0
end

--[[ The server's table as what to draw; anything not its shape is left
     out rather than trusted. ]]
local function read(data: unknown): Item?
	if type(data) ~= "table" then
		return nil
	end
	local raw = data :: any
	if raw.owed ~= nil then
		return { kind = "Picks" }
	end
	local place = if type(raw.place) == "number" then whole(raw.place) else nil
	return {
		kind = "Paid",
		paid = {
			kind = "Paid",
			place = if place and place > 0 then place else nil,
			floor = whole(raw.floor),
			time = if type(raw.time) == "string" then raw.time else "",
			gems = whole(raw.gems),
			coins = whole(raw.coins),
			soulstones = whole(raw.soulstones),
			champion = raw.champion == true,
			picks = whole(raw.picks),
		},
	}
end

--[[ Standing in the lobby, off the title and the story. ]]
local function inLobby(): boolean
	return Workspace:GetAttribute("InLobby") == true
		and Players.LocalPlayer:GetAttribute("Arrived") == true
end

--[[ How much a panel `w` by `h` points is scaled to fit the screen. ]]
local function fitOf(w: number, h: number): number
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return RunHudRules.fit(view, w, h, MARGIN)
end

--[[ The dark behind a panel, and the panel's box, `w` by `h` points before
     fitting, with its sheet. ]]
local function frame(screen: ScreenGui, w: number, h: number): (Frame, Chunky.Sheet)
	local fit = fitOf(w, h)
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = screen

	local box = Instance.new("Frame")
	box.Name = "Prize"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(w * fit, h * fit)
	box.Parent = screen
	return box, Chunky.pointSheet(box, w, h)
end

--[[ A line of words across the sheet at `top`, `tall` sheet pixels. ]]
local function line(
	sheet: Chunky.Sheet,
	words: string,
	colour: Color3,
	top: number,
	tall: number
): TextLabel
	local pad = 44
	local text = Chunky.text(sheet.canvas, words, colour, 0)
	text.Position = UDim2.fromScale(pad / sheet.w, top / sheet.h)
	text.Size = UDim2.fromScale(1 - 2 * pad / sheet.w, tall / sheet.h)
	return text
end

local function showPaid(screen: ScreenGui, paid: Paid)
	-- in sheet pixels, two to a point
	local w = WIDTH * 2
	local pad = 44
	local header = 104
	local placeTop = header + 22
	local floorTop = placeTop + 70
	local titleTop = floorTop + 56
	local pillsTop = titleTop + (if paid.champion then 64 else 6)
	local stonesTop = pillsTop + 96
	local picksTop = stonesTop + (if paid.soulstones > 0 then 62 else 0)
	local buttonTop = picksTop + (if paid.picks > 0 then 62 else 8)
	local h = buttonTop + 110 + 36 + 12

	local box, sheet = frame(screen, WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "WEEKLY TOURNAMENT", 0, 0, w, header)
	Chunky.close(sheet, 0, 0, 0, close)

	local headline = if paid.champion
		then "YOU WON THE WEEK!"
		elseif paid.place then `YOU PLACED #{paid.place}!`
		else "THANKS FOR DELVING!"
	line(sheet, headline, Chunky.ink, placeTop, 60)
	local reached = `FLOOR {paid.floor}` .. (if paid.time ~= "" then ` IN {paid.time}` else "")
	line(
		sheet,
		if paid.place then reached else `{reached}, PAST THE TOP 100`,
		Chunky.ink,
		floorTop,
		44
	)
	if paid.champion then
		line(sheet, `NEW TITLE: {Tournament.title}`, Tournament.colors.prizeInk, titleTop, 50)
	end

	-- the coins and gems on their pills, centred together
	local pills: { { icon: string, amount: number, wide: number } } = {}
	if paid.coins > 0 then
		table.insert(pills, { icon = ShopAssets.coin, amount = paid.coins, wide = 300 })
	end
	if paid.gems > 0 then
		table.insert(pills, { icon = ShopAssets.gem, amount = paid.gems, wide = 240 })
	end
	local total = 0
	for _, pill in pills do
		total += pill.wide
	end
	total += math.max(#pills - 1, 0) * 30
	local x = (w - total) / 2
	for _, pill in pills do
		Chunky.pill(sheet, pill.icon, `+{Chunky.commas(pill.amount)}`, x, pillsTop, pill.wide, 80)
		x += pill.wide + 30
	end
	if paid.soulstones > 0 then
		line(
			sheet,
			`+{Chunky.commas(paid.soulstones)} {SaveSchema.SOULSTONES}`,
			Chunky.ink,
			stonesTop,
			52
		)
	end
	if paid.picks > 0 then
		local words = if paid.picks == 1
			then "+1 SET WEAPON OF YOUR CHOICE"
			else `+{paid.picks} SET WEAPONS OF YOUR CHOICE`
		line(sheet, words, Tournament.colors.prizeInk, picksTop, 52)
		Chunky.button(sheet, "PICK!", Chunky.gold, pad, buttonTop, w - 2 * pad, 110, function()
			local pick: Item = { kind = "Picks" }
			table.insert(queue, 1, pick)
			close()
		end)
	else
		Chunky.button(sheet, "COLLECT", Chunky.green, pad, buttonTop, w - 2 * pad, 110, close)
	end
	Chunky.pop(box)
	SoundFx.play("new_item")
end

local function picture(weapon: string): string
	return ItemIcons.weapon(weapon)
end

local function showPicks(screen: ScreenGui)
	local mine = profile
	if not mine or mine.tournamentPicks < 1 then
		close()
		return
	end
	-- every stocked set's weapons, by set in the shelf's order, any class
	local sets: { { name: string, weapons: { ShopRules.Entry } } } = {}
	local index: { [string]: number } = {}
	for _, entry in ShopRules.catalog() do
		local key = entry.set
		if key then
			if not index[key] then
				local set = ShopRules.set(key)
				table.insert(sets, { name = if set then set.name else key, weapons = {} })
				index[key] = #sets
			end
			table.insert(sets[index[key]].weapons, entry)
		end
	end

	local w = PICK_WIDTH * 2
	local pad = 40
	local header = 104
	local countTop = header + 18
	local listTop = countTop + 60
	local listH = 900
	local nameTop = listTop + listH + 18
	local buttonTop = nameTop + 60
	local h = buttonTop + 110 + 36 + 12
	local fit = fitOf(PICK_WIDTH, h / 2)

	local box, sheet = frame(screen, PICK_WIDTH, h / 2)
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "PICK A SET WEAPON", 0, 0, w, header)
	Chunky.close(sheet, 0, 0, 0, close)

	local count = line(sheet, "", Chunky.ink, countTop, 48)
	local chosenName = line(sheet, "TAP A WEAPON", Chunky.inkSoft, nameTop, 48)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Sets"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 6
	Chunky.put(sheet, list, pad, listTop, w - 2 * pad, listH)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local chosen: string? = nil
	local ring: Frame? = nil
	local take: Frame? = nil
	local slots: { [string]: Frame } = {}

	local function paintTake()
		if take then
			Chunky.repaint(take, if chosen then Chunky.green else Chunky.inkSoft, "TAKE IT")
		end
	end

	local function refresh()
		local now = profile
		if not now or now.tournamentPicks < 1 then
			close()
			return
		end
		count.Text = if now.tournamentPicks == 1
			then "1 PICK LEFT: ANY SET, ANY CLASS"
			else `{now.tournamentPicks} PICKS LEFT: ANY SET, ANY CLASS`
		if chosen and now.weapons[chosen] then
			chosen = nil
			if ring then
				ring:Destroy()
				ring = nil
			end
			chosenName.Text = "TAP A WEAPON"
		end
		-- a weapon just taken is drawn owned, and no longer pressable
		for weapon, slot in slots do
			if now.weapons[weapon] and slot:GetAttribute("Owned") ~= true then
				slot:SetAttribute("Owned", true)
				slot:ClearAllChildren()
				local entry = ShopRules.find(weapon)
				Chunky.tile(
					slot,
					if entry then entry.rarity else "Legendary",
					picture(weapon),
					"OWNED",
					false,
					true
				)
			end
		end
		paintTake()
	end

	for order, set in sets do
		local row = Instance.new("Frame")
		row.Name = set.name
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -12, 0, ROW * fit)
		row.Parent = list
		local title = Chunky.text(row, set.name, Chunky.ink, 0)
		title.Position, title.Size = UDim2.fromScale(0, 0.2), UDim2.fromScale(0.26, 0.6)
		title.TextXAlignment = Enum.TextXAlignment.Left
		-- every set's name at one size, that of a ten-letter name
		local even = Instance.new("UITextSizeConstraint")
		even.MaxTextSize = math.max(math.floor((PICK_WIDTH - pad) * fit * 0.26 / 6.8), 8)
		even.Parent = title
		for n, entry in set.weapons do
			local slot = Instance.new("Frame")
			slot.Name = entry.weapon
			slot.BackgroundTransparency = 1
			slot.ZIndex = 7
			slot.Position = UDim2.fromScale(0.27 + (n - 1) * 0.183, 0.05)
			slot.Size = UDim2.fromScale(0.17, 0.9)
			local square = Instance.new("UIAspectRatioConstraint")
			square.AspectRatio = 1
			square.Parent = slot
			slot.Parent = row
			slots[entry.weapon] = slot
			local owned = mine.weapons[entry.weapon] == true
			slot:SetAttribute("Owned", owned)
			local made = Chunky.tile(
				slot,
				entry.rarity,
				picture(entry.weapon),
				if owned then "OWNED" else nil,
				false,
				owned
			)
			if owned then
				continue
			end
			if entry.rarity == "Legendary" or entry.rarity == "Mythic" then
				Chunky.twinkle(made)
			end
			Chunky.press(slot, function()
				local held = profile
				if not held or held.weapons[entry.weapon] then
					return
				end
				chosen = entry.weapon
				if ring then
					ring:Destroy()
				end
				ring = Chunky.select(slot)
				chosenName.Text = `{entry.label}, {set.name}`
				paintTake()
			end)
		end
	end

	take = Chunky.button(
		sheet,
		"TAKE IT",
		Chunky.inkSoft,
		pad,
		buttonTop,
		w - 2 * pad,
		110,
		function()
			local weapon = chosen
			if weapon then
				Remotes.event(Remotes.TournamentPick):FireServer(weapon)
				SoundFx.play("new_item")
			end
		end
	)
	onProfile = refresh
	refresh()
	Chunky.pop(box)
end

function show()
	local screen = gui
	if not screen or open or #queue == 0 or not inLobby() then
		return
	end
	local item = table.remove(queue, 1) :: Item
	open = true
	if item.kind == "Paid" then
		showPaid(screen, item.paid)
	else
		showPicks(screen)
	end
	if open then
		screen.Enabled = true
	end
end

function TournamentPrize.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("TournamentPrize")
	if existing then
		existing:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "TournamentPrize"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- as the Endless prize's panel: over the lobby's screens, under a reveal
	screen.DisplayOrder = 150
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(next_: unknown)
		if type(next_) == "table" then
			profile = next_ :: any
			local redraw = onProfile
			if redraw then
				redraw()
			end
		end
	end)
	Remotes.event(Remotes.TournamentPrize).OnClientEvent
		:Connect(function(_week: unknown, data: unknown)
			local item = read(data)
			if item then
				table.insert(queue, item)
				show()
			end
		end)
	-- held for the lobby: shown when the player is back in it
	Workspace:GetAttributeChangedSignal("InLobby"):Connect(show)
	Players.LocalPlayer:GetAttributeChangedSignal("Arrived"):Connect(show)
end

return TournamentPrize
