--!strict
--[[
	The REWARDS screen (the loop review's item 4, owner-approved 2026-11-11):
	the 7-day login calendar, today's three quests and the one-time starter
	list (`Config/Rewards`), in the chunky kit, opened from a REWARDS button
	in the lobby and by itself once a day when the calendar has a gift.

	It only draws and asks. What is owed is worked out with the same pure
	rules the server uses (`Util/RewardRules`) from the profile the server
	sent and the day the server published (`RewardDay` on the Player); a
	CLAIM sends `Remotes.RewardClaim` with the reward's name and nothing
	else, and the screen redraws when the server's new profile arrives.

	Also the toast for a reward that lands by itself: a new Dex entry's gems
	(`Remotes.RewardToast`, `Data/DexPay`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Chunky = require(script.Parent.Chunky)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local StationScreen = require(script.Parent.StationScreen)

local RewardsScreen = {}

local player = Players.LocalPlayer
local screen: StationScreen.Screen? = nil
--[[ The day the screen last opened by itself, so it does so once a day. ]]
local shownFor = 0

local function today(): number
	local day = player:GetAttribute("RewardDay")
	return if type(day) == "number" then day else RewardRules.day(os.time())
end

function RewardsScreen.open()
	local s = screen
	if s then
		Remotes.event(Remotes.ProfileRequest):FireServer()
		StationScreen.openShortcut(s.open)
	end
end

function RewardsScreen.isOpen(): boolean
	return screen ~= nil and screen.isOpen()
end

local function claim(kind: string, key: string?)
	Remotes.event(Remotes.RewardClaim):FireServer(kind, key)
end

--[[ Words on the sheet, in sheet pixels: ink with no stroke, which reads
     on a white card and on the kit's cream panel alike. ]]
local function words(
	sheet: Chunky.Sheet,
	text: string,
	x: number,
	y: number,
	w: number,
	h: number,
	align: Enum.TextXAlignment?
): TextLabel
	local t = Chunky.text(sheet.canvas, text, Chunky.ink, 0)
	Chunky.put(sheet, t, x, y, w, h)
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	return t
end

local function icon(sheet: Chunky.Sheet, asset: string, x: number, y: number, size: number)
	local picture = Kit.image(sheet.canvas, asset)
	picture.ZIndex = 30
	Chunky.put(sheet, picture, x, y, size, size)
end

--[[ A gift's gems, and its coins under them when it has any, in a box
     `w` x `h` at (x, y). ]]
local function giftAt(
	sheet: Chunky.Sheet,
	gift: Rewards.Gift,
	x: number,
	y: number,
	w: number,
	h: number
)
	local lines = if gift.coins > 0 then 2 else 1
	local line = math.min(h / lines, 46)
	local top = y + (h - line * lines) / 2
	for index, entry in
		{ { ShopAssets.gem, gift.gems }, { ShopAssets.coin, gift.coins } } :: { { any } }
	do
		if entry[2] > 0 then
			local ly = top + (index - 1) * line
			icon(sheet, entry[1], x, ly, line)
			words(
				sheet,
				"+" .. Chunky.commas(entry[2]),
				x + line + 6,
				ly + line * 0.1,
				w - line - 6,
				line * 0.8
			)
		end
	end
end

--[[ One quest or starter step: what to do, how far along, what it pays,
     and CLAIM once it is owed. ]]
local function row(
	sheet: Chunky.Sheet,
	x: number,
	y: number,
	w: number,
	h: number,
	title: string,
	have: number,
	goal: number,
	gift: Rewards.Gift,
	claimed: boolean,
	onClaim: () -> ()
)
	local card = Chunky.card(sheet, x, y, w, h)
	local ready = have >= goal and not claimed
	local buttonW, giftW = 176, 150
	local left = w - buttonW - giftW - 60
	words(sheet, title, x + 22, y + h * 0.1, left, h * 0.38)
	local barW = left - 130
	Chunky.bar(
		sheet,
		if claimed then 1 else have / goal,
		if claimed then Chunky.grey else Chunky.green,
		x + 22,
		y + h * 0.58,
		barW,
		h * 0.26
	)
	words(
		sheet,
		`{Chunky.commas(math.min(have, goal))}/{Chunky.commas(goal)}`,
		x + 22 + barW + 12,
		y + h * 0.54,
		118,
		h * 0.34
	)
	giftAt(sheet, gift, x + w - buttonW - giftW - 30, y + 8, giftW, h - 16)
	local bx, by, bh = x + w - buttonW - 18, y + (h - 76) / 2, 76
	if claimed then
		card.BackgroundColor3 = Chunky.pale
		words(sheet, "DONE", bx, by + 16, buttonW, bh - 32, Enum.TextXAlignment.Center).TextColor3 =
			Chunky.inkSoft
	elseif ready then
		Chunky.gleam(Chunky.button(sheet, "CLAIM", Chunky.green, bx, by, buttonW, bh, onClaim))
	end
end

--[[ One square of the calendar. ]]
local function dayCard(
	sheet: Chunky.Sheet,
	x: number,
	y: number,
	w: number,
	h: number,
	index: number,
	state: "claimed" | "ready" | "next" | "later"
)
	local gift = Rewards.calendar[index]
	local card = Chunky.card(sheet, x, y, w, h)
	if state == "ready" then
		Chunky.outline(card, 9, Chunky.gold)
	end
	words(sheet, `DAY {index}`, x + 10, y + h * 0.05, w - 20, h * 0.17, Enum.TextXAlignment.Center)
	local size = h * 0.3
	icon(sheet, ShopAssets.gem, x + (w - size) / 2, y + h * 0.22, size)
	words(
		sheet,
		"+" .. gift.gems,
		x + 10,
		y + h * 0.52,
		w - 20,
		h * 0.16,
		Enum.TextXAlignment.Center
	)
	if gift.coins > 0 then
		local line = h * 0.11
		local half = (line + 6 + w * 0.34) / 2
		icon(sheet, ShopAssets.coin, x + w / 2 - half, y + h * 0.68, line)
		words(
			sheet,
			"+" .. Chunky.commas(gift.coins),
			x + w / 2 - half + line + 6,
			y + h * 0.68,
			w * 0.34,
			line
		)
	end
	local by, bh = y + h * 0.8, h * 0.26
	if state == "claimed" then
		local shade = Instance.new("Frame")
		shade.BorderSizePixel = 0
		shade.BackgroundColor3 = Chunky.navy
		shade.BackgroundTransparency = 0.25
		shade.ZIndex = 32
		Chunky.put(sheet, shade, x, y, w, h)
		Chunky.round(shade, 24)
		local done = Chunky.text(shade, "CLAIMED", Chunky.lime, 5)
		done.Position, done.Size = UDim2.fromScale(0.08, 0.38), UDim2.fromScale(0.84, 0.24)
		done.ZIndex = 33
		done.Rotation = -8
	elseif state == "ready" then
		Chunky.gleam(Chunky.button(sheet, "CLAIM", Chunky.green, x + 12, by, w - 24, bh, function()
			claim("login")
		end))
	elseif state == "next" then
		words(sheet, "TOMORROW", x + 10, y + h * 0.83, w - 20, h * 0.12, Enum.TextXAlignment.Center).TextColor3 =
			Chunky.inkSoft
	end
end

--[[ "5H 12M": how long until midnight UTC, when the quests change. ]]
local function untilReset(): string
	local left = Rewards.dayLength - os.time() % Rewards.dayLength
	return `{left // 3600}H {left % 3600 // 60}M`
end

local function draw(s: StationScreen.Screen)
	local area = HatchStand.chrome(s, "REWARDS")
	local sheet = area.sheet
	local profile = s.profile
	if not profile or not (profile :: any).rewards then
		words(sheet, "LOADING...", area.x, area.y + 200, area.w, 80, Enum.TextXAlignment.Center)
		return
	end
	local p = profile :: SaveSchema.Profile
	local r = p.rewards
	local day = today()
	local up = sheet.upright
	local x, y, w = area.x, area.y, area.w

	-- the calendar
	words(sheet, "DAILY LOGIN", x, y, 520, 44)
	local ready = RewardRules.loginReady(r, day)
	local slot = RewardRules.loginSlot(r)
	-- day 7 taken today: the whole week stays filled in until tomorrow
	local taken = if not ready
			and slot == 1
			and r.loginCount > 0
		then #Rewards.calendar
		else slot - 1
	local function stateOf(index: number): "claimed" | "ready" | "next" | "later"
		if index <= taken then
			return "claimed"
		elseif index == taken + 1 then
			return if ready then "ready" else "next"
		end
		return "later"
	end
	local cy = y + 52
	local below: number
	if up then
		local gap = 14
		local cw, ch = (w - 3 * gap) / 4, 222
		for index = 1, #Rewards.calendar do
			local col, line = (index - 1) % 4, (index - 1) // 4
			-- day 7, the big one, takes the last two places of its line
			local wide = if index == 7 then cw * 2 + gap else cw
			dayCard(
				sheet,
				x + col * (cw + gap),
				cy + line * (ch + gap),
				wide,
				ch,
				index,
				stateOf(index)
			)
		end
		below = cy + 2 * ch + gap + 22
	else
		local gap = 16
		local cw, ch = (w - 6 * gap) / 7, 250
		for index = 1, #Rewards.calendar do
			dayCard(sheet, x + (index - 1) * (cw + gap), cy, cw, ch, index, stateOf(index))
		end
		below = cy + ch + 20
	end

	-- today's quests, and the starter list beside (or under) them
	local colW = if up then w else (w - 18) / 2
	local rowH, rowGap = if up then 108 else 104, 12
	words(sheet, "DAILY QUESTS", x, below, 420, 44)
	words(
		sheet,
		"NEW IN " .. untilReset(),
		x + colW - 330,
		below + 8,
		330,
		32,
		Enum.TextXAlignment.Right
	)
	local qy = below + 52
	for index, key in RewardRules.questsFor(day) do
		local quest = Rewards.quests[key]
		row(
			sheet,
			x,
			qy + (index - 1) * (rowH + rowGap),
			colW,
			rowH,
			string.format(quest.words, quest.goal),
			RewardRules.progress(r, day, key),
			quest.goal,
			{ gems = quest.gems, coins = quest.coins },
			RewardRules.questClaimed(r, day, key),
			function()
				claim("quest", key)
			end
		)
	end

	local sx = if up then x else x + colW + 18
	local sy = if up then qy + 3 * (rowH + rowGap) + 12 else below
	words(sheet, "GETTING STARTED", sx, sy, 520, 44)
	for index, entry in Rewards.starter do
		row(
			sheet,
			sx,
			sy + 52 + (index - 1) * (rowH + rowGap),
			colW,
			rowH,
			entry.words,
			if RewardRules.starterDone(p, entry.key) then 1 else 0,
			1,
			{ gems = entry.gems, coins = entry.coins },
			r.starterClaimed[entry.key] == true,
			function()
				claim("starter", entry.key)
			end
		)
	end
end

--[[ The lobby's REWARDS button, with how many rewards wait on it. ]]
local function startButton(s: StationScreen.Screen)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RewardsButton"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	local canvas = Kit.canvas(gui)
	local built: boolean? = nil
	local badge: Frame? = nil
	local count: TextLabel? = nil

	local function build()
		for _, child in canvas:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local sheet = Chunky.sheet(canvas)
		built = sheet.upright
		local bx, by, bw, bh = 24, if sheet.upright then 230 else 150, 250, 92
		Chunky.button(
			sheet,
			"REWARDS",
			Chunky.gold,
			bx,
			by,
			bw,
			bh,
			RewardsScreen.open,
			ShopAssets.gem
		)
		local dot = Instance.new("Frame")
		dot.Name = "Badge"
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = Chunky.red
		dot.ZIndex = 45
		Chunky.put(sheet, dot, bx + bw - 30, by - 16, 52, 52)
		Chunky.round(dot, 26)
		Chunky.outline(dot, 5)
		local n = Chunky.textOn(dot, "1", Chunky.red, 3)
		n.Position, n.Size = UDim2.fromScale(0.15, 0.12), UDim2.fromScale(0.7, 0.76)
		n.ZIndex = 46
		badge, count = dot, n
	end

	task.spawn(function()
		while gui.Parent do
			local gui2 = player:FindFirstChild("PlayerGui")
			local inLobby = Workspace:GetAttribute("InLobby") == true
				and player:GetAttribute("ClassSelecting") ~= true
				and not RunPaused.beforeArrival()
				and gui2 ~= nil
				and gui2:FindFirstChild("IntroCutscene") == nil
				and gui2:FindFirstChild("StoryCutscene") == nil
			local free = inLobby and player:GetAttribute("InStation") ~= true
			--[[ `InLobby` is also true under the title and in the moment
			     between the story's end and the tutorial starting, so the
			     screen opens by itself only once the server says this player
			     stands in the lobby (`RunSession.ARRIVED`). Without it, SKIP
			     on the story could open the calendar over the tutorial's
			     first room, and spend the day's opening there. ]]
			local arrived = player:GetAttribute("Arrived") == true
			gui.Enabled = free
			if free then
				local upright = gui.AbsoluteSize.Y > gui.AbsoluteSize.X
				if built ~= upright then
					build()
				end
				local profile = s.profile
				local day = today()
				local waiting = 0
				if profile and (profile :: any).rewards then
					waiting = RewardRules.ready(profile, day)
					-- once a day, the calendar's gift opens the screen by itself
					if
						arrived
						and shownFor ~= day
						and RewardRules.loginReady(profile.rewards, day)
					then
						shownFor = day
						RewardsScreen.open()
					end
				end
				if badge and count then
					badge.Visible = waiting > 0
					count.Text = tostring(waiting)
				end
			end
			task.wait(0.5)
		end
	end)
end

--[[ A reward that landed by itself. Several at once (ten eggs, ten new
     pets) come up as one line. ]]
local function startToasts()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RewardToasts"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 140
	gui.Parent = player:WaitForChild("PlayerGui")
	local canvas = Kit.canvas(gui)
	local waiting: { { words: string, gems: number } } = {}
	local showing = false

	local function show()
		showing = true
		-- let the rest of a burst arrive
		task.wait(0.25)
		while #waiting > 0 do
			local batch = waiting
			waiting = {}
			local gems = 0
			for _, entry in batch do
				gems += entry.gems
			end
			local line = if #batch == 1 then batch[1].words else `{#batch} NEW DEX ENTRIES`
			local sheet = Chunky.sheet(canvas)
			local w, h = if sheet.upright then 980 else 1000, 96
			local x, y = (sheet.w - w) / 2, if sheet.upright then 330 else 150
			local pill = Instance.new("Frame")
			pill.Name = "Toast"
			pill.BorderSizePixel = 0
			pill.BackgroundColor3 = Chunky.navy
			pill.ZIndex = 20
			Chunky.put(sheet, pill, x, y, w, h)
			Chunky.round(pill, h / 2)
			Chunky.outline(pill, 6, Chunky.gold)
			local t = Chunky.text(pill, line, nil, 4)
			t.Position, t.Size = UDim2.fromScale(0.04, 0.2), UDim2.fromScale(0.68, 0.6)
			t.TextXAlignment = Enum.TextXAlignment.Left
			local gem = Kit.image(pill, ShopAssets.gem)
			gem.Position, gem.Size = UDim2.fromScale(0.75, 0.12), UDim2.fromScale(0.08, 0.76)
			gem.ZIndex = 30
			local amount = Chunky.text(pill, "+" .. gems, Chunky.gold, 4)
			amount.Position, amount.Size = UDim2.fromScale(0.84, 0.2), UDim2.fromScale(0.13, 0.6)
			amount.TextXAlignment = Enum.TextXAlignment.Left
			Chunky.pop(pill)
			task.wait(2.2)
			local scale = pill:FindFirstChild("PopScale")
			if scale then
				TweenService:Create(scale, TweenInfo.new(0.18), { Scale = 0 }):Play()
			end
			task.wait(0.2)
			pill:Destroy()
		end
		showing = false
	end

	Remotes.event(Remotes.RewardToast).OnClientEvent:Connect(function(line, gems)
		if type(line) ~= "string" or type(gems) ~= "number" then
			return
		end
		table.insert(waiting, { words = line, gems = gems })
		if not showing then
			task.spawn(show)
		end
	end)
end

function RewardsScreen.start()
	if screen then
		return
	end
	-- no station of its own: it opens from its button, never from a prompt
	local s = StationScreen.new("RewardsScreen", "Rewards", "REWARDS")
	screen = s
	s.draw = function()
		draw(s)
	end
	s.connect(player:GetAttributeChangedSignal("RewardDay"), function()
		if s.isOpen() then
			s.open()
		end
	end)
	startButton(s)
	startToasts()
end

return RewardsScreen
