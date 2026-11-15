--!strict
--[[
	The REWARDS screen (the loop review's item 4, owner-approved 2026-11-11):
	the 7-day login calendar, today's three quests and the one-time starter
	list (`Config/Rewards`), in the chunky kit, opened from a REWARDS button
	in the lobby and by itself once a day when the calendar has a gift.

	Three tabs since 2026-11-14 (owner: "the quests tab is too cluttered",
	"the quests need to be clearer"): DAILY, the calendar; QUESTS, today's
	three with the chest for claiming them all; GOALS, the starter steps
	and then the lifetime goals (`Config/Goals`), each in three medals, and
	a chest for an area's stars (`Util/StarRules`) and for each finished
	Dex page (`Util/PageRules`), in a list that
	scrolls; DAILY also holds the gift box (`Util/GiftRules`). Each tab wears the count of what waits on it. A row is a picture of
	what to do, the words, the bar with its numbers on it, what it pays, and
	one button: CLAIM, GO (a gold arrow to where it is done,
	`Fx/QuestPointer`) or DONE. CLAIM ALL takes everything owed at once.

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
local EggRules = require(ReplicatedStorage.Shared.Util.EggRules)
local EndScreenAssets = require(ReplicatedStorage.Shared.Config.EndScreenAssets)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local GiftRules = require(ReplicatedStorage.Shared.Util.GiftRules)
local GoalRules = require(ReplicatedStorage.Shared.Util.GoalRules)
local Goals = require(ReplicatedStorage.Shared.Config.Goals)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local PageRules = require(ReplicatedStorage.Shared.Util.PageRules)
local PortalScreen = require(script.Parent.PortalScreen)
local PrizeRules = require(ReplicatedStorage.Shared.Util.PrizeRules)
local QuestPointer = require(script.Parent.Parent.Fx.QuestPointer)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Reveal = require(script.Parent.Reveal)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local StarRules = require(ReplicatedStorage.Shared.Util.StarRules)
local StationScreen = require(script.Parent.StationScreen)

local RewardsScreen = {}

local player = Players.LocalPlayer
local screen: StationScreen.Screen? = nil
--[[ The day the screen last opened by itself, so it does so once a day. ]]
local shownFor = 0
--[[ The tabs, and the one showing: nil until the screen picks one as it
     opens from its button (`draw`). ]]
type Tab = string
local TABS: { Tab } = { "DAILY", "QUESTS", "GOALS" }
local tab: Tab? = nil

local function today(): number
	local day = player:GetAttribute("RewardDay")
	return if type(day) == "number" then day else RewardRules.day(os.time())
end

function RewardsScreen.open()
	local s = screen
	if s then
		tab = nil
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

--[[ One thing a reward pays: its picture and how many. ]]
type Pay = { asset: string, words: string }

--[[ What a reward pays, a line for each thing, in a box `w` x `h` at
     (x, y). ]]
local function payAt(sheet: Chunky.Sheet, pay: { Pay }, x: number, y: number, w: number, h: number)
	local lines = math.max(#pay, 1)
	local line = math.min(h / lines, 46)
	local top = y + (h - line * lines) / 2
	for index, entry in pay do
		local ly = top + (index - 1) * line
		icon(sheet, entry.asset, x, ly, line)
		words(sheet, entry.words, x + line + 6, ly + line * 0.1, w - line - 6, line * 0.8)
	end
end

local function plus(pay: { Pay }, asset: string, amount: number?)
	if amount and amount > 0 then
		table.insert(pay, { asset = asset, words = "+" .. Chunky.commas(amount) })
	end
end

--[[ A gift's gems, and its coins under them when it has any. ]]
local function giftPay(gift: Rewards.Gift): { Pay }
	local pay: { Pay } = {}
	plus(pay, ShopAssets.gem, gift.gems)
	plus(pay, ShopAssets.coin, gift.coins)
	return pay
end

--[[ The free egg the server gives this player, drawn: the best one open
     to them (`Util/PrizeRules`). ]]
local function eggArt(profile: SaveSchema.Profile): string
	local eggs = GearAssets.areaPictures.eggs
	local key = PrizeRules.eggKey(profile.bossesBeaten)
	local egg = if key then EggRules.find(key) else nil
	return (if egg then eggs[egg.area] else nil) or eggs.MossyGlade
end

--[[ And the free crate: the best with a weapon for the class they play. ]]
local function crateArt(): string
	local chests = GearAssets.areaPictures.chests
	local class = player:GetAttribute("Class")
	local index = PrizeRules.crateIndex(if type(class) == "string" then class else nil)
	local crate = if index then Shop.crates[index] else nil
	return (if crate then chests[crate.area] else nil) or chests.MossyGlade
end

--[[ A goal step's or a Dex page's prize (`Config/Goals`, `Util/PageRules`). ]]
local function prizePay(profile: SaveSchema.Profile, prize: Goals.Prize): { Pay }
	local pay: { Pay } = {}
	plus(pay, eggArt(profile), prize.eggs)
	plus(pay, crateArt(), prize.crates)
	plus(pay, ShopAssets.gem, prize.gems)
	plus(pay, ShopAssets.coin, prize.coins)
	return pay
end

--[[ The picture beside each kind of quest and starter step: what it asks
     for, drawn rather than read (owner, 2026-11-14: "the quests need to be
     clearer"). Existing 2D art only. ]]
local PICTURES: { [string]: string } = {
	kills = EndScreenAssets.skull,
	coins = ShopAssets.coin,
	levels = EndScreenAssets.heroVictory,
	bosses = ShopAssets.items.RoyalJelly,
	hatches = GearAssets.areaPictures.eggs.MossyGlade,
	crates = GearAssets.areaPictures.chests.MossyGlade,
}

--[[ The picture of a Dex page's chest, by its book. ]]
local PAGE_KINDS: { [string]: string } = { Enemies = "kills", Pets = "hatches", Weapons = "crates" }

--[[ One quest, starter step, goal or Dex page. ]]
type Row = {
	--[[ The kind it is, for its picture (`PICTURES`). ]]
	kind: string,
	title: string,
	have: number,
	goal: number,
	pay: { Pay },
	claimed: boolean,
	onClaim: () -> (),
	--[[ Where it is done, for GO (`Fx/QuestPointer`); nil for no GO. ]]
	place: string?,
	--[[ A goal's medals won so far (0 to 3, `Config/Goals.medals`); nil for
	     a row with no medals. ]]
	medals: number?,
}

--[[ Rows in the order they matter: what can be claimed, what is still to
     do, and what is done, each group in the order given. ]]
local function sorted(rows: { Row }): { Row }
	local function rank(r: Row): number
		return if r.claimed then 3 elseif r.have >= r.goal then 1 else 2
	end
	local out: { Row } = {}
	for wanted = 1, 3 do
		for _, r in rows do
			if rank(r) == wanted then
				table.insert(out, r)
			end
		end
	end
	return out
end

--[[ One quest or starter step: its picture, what to do, how far along on
     the bar itself, what it pays, and one button: CLAIM once it is owed, GO
     to be shown where it is done, DONE once it is claimed. ]]
local function row(
	s: StationScreen.Screen,
	sheet: Chunky.Sheet,
	x: number,
	y: number,
	w: number,
	h: number,
	spec: Row
)
	local card = Chunky.card(sheet, x, y, w, h)
	local ready = spec.have >= spec.goal and not spec.claimed
	local buttonW, giftW = 190, 150
	local size = h - 28
	local art = PICTURES[spec.kind] or ShopAssets.gem
	if spec.medals then
		--[[ A goal: its picture a little smaller, and bronze, silver and
		     gold in a row under it, each lit once it is won. ]]
		local disc, gap = math.floor(size * 0.24), 6
		local small = size - disc - 6
		icon(sheet, art, x + 16 + (size - small) / 2, y + 12, small)
		local mx = x + 16 + (size - (disc + gap) * #Goals.medals + gap) / 2
		for index, colour in Goals.medalColours do
			local medal = Instance.new("Frame")
			medal.Name = "Medal"
			medal.BorderSizePixel = 0
			medal.BackgroundColor3 = if index <= spec.medals then colour else Chunky.pale
			medal.ZIndex = 32
			Chunky.put(sheet, medal, mx + (index - 1) * (disc + gap), y + 18 + small, disc, disc)
			Chunky.round(medal, disc)
			Chunky.outline(medal, 3)
		end
	else
		icon(sheet, art, x + 16, y + 14, size)
	end
	local tx = x + 16 + size + 18
	local left = w - (tx - x) - buttonW - giftW - 48
	words(sheet, spec.title, tx, y + h * 0.1, left, h * 0.36)
	local trough = Chunky.bar(
		sheet,
		if spec.claimed then 1 else spec.have / spec.goal,
		if spec.claimed then Chunky.grey else Chunky.green,
		tx,
		y + h * 0.54,
		left,
		h * 0.32
	)
	local count = Chunky.text(
		trough,
		`{Chunky.commas(math.min(spec.have, spec.goal))} / {Chunky.commas(spec.goal)}`,
		Chunky.white,
		4
	)
	count.Position, count.Size = UDim2.fromScale(0.1, 0.08), UDim2.fromScale(0.8, 0.84)
	payAt(sheet, spec.pay, x + w - buttonW - giftW - 30, y + 8, giftW, h - 16)
	local bh = math.min(84, h - 36)
	local bx, by = x + w - buttonW - 18, y + (h - bh) / 2
	if spec.claimed then
		card.BackgroundColor3 = Chunky.pale
		words(sheet, "DONE", bx, by + bh * 0.2, buttonW, bh * 0.6, Enum.TextXAlignment.Center).TextColor3 =
			Chunky.inkSoft
	elseif ready then
		Chunky.gleam(Chunky.button(sheet, "CLAIM", Chunky.green, bx, by, buttonW, bh, spec.onClaim))
	elseif spec.place then
		local place = spec.place
		Chunky.button(sheet, "GO", Chunky.blue, bx, by, buttonW, bh, function()
			--[[ The screen goes and a gold arrow shows where: nothing is
			     started for the player. ]]
			if QuestPointer.show(place, spec.title) then
				s.close()
			end
		end)
	end
end

--[[ A list that scrolls, `w` x `h` at (x, y) with `content` sheet pixels
     of rows in it: returned as a sheet of its own, so a row is put in it as
     it is on the screen's. ]]
local function scroller(
	sheet: Chunky.Sheet,
	x: number,
	y: number,
	w: number,
	h: number,
	content: number
): Chunky.Sheet
	local tall = math.max(content, h)
	local list = Instance.new("ScrollingFrame")
	list.Name = "GoalList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.ScrollBarImageColor3 = Chunky.navy
	-- a canvas is sized against the frame's parent, the sheet, not the frame
	list.CanvasSize = UDim2.fromScale(0, tall / sheet.h)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ZIndex = 6
	Chunky.put(sheet, list, x, y, w, h)
	return { canvas = list :: any, w = w, h = tall, upright = sheet.upright }
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

--[[ The seven squares of the calendar, from (x, y) down; returns where
     they end. ]]
local function calendar(
	sheet: Chunky.Sheet,
	r: SaveSchema.RewardState,
	day: number,
	x: number,
	y: number,
	w: number
): number
	local up = sheet.upright
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
	if up then
		local gap = 14
		local cw, ch = (w - 3 * gap) / 4, 300
		for index = 1, #Rewards.calendar do
			local col, line = (index - 1) % 4, (index - 1) // 4
			-- day 7, the big one, takes the last two places of its line
			local wide = if index == 7 then cw * 2 + gap else cw
			dayCard(
				sheet,
				x + col * (cw + gap),
				y + line * (ch + gap),
				wide,
				ch,
				index,
				stateOf(index)
			)
		end
		return y + 2 * ch + gap
	end
	local gap = 16
	local cw, ch = (w - 6 * gap) / 7, 330
	for index = 1, #Rewards.calendar do
		dayCard(sheet, x + (index - 1) * (cw + gap), y, cw, ch, index, stateOf(index))
	end
	return y + ch
end

--[[ A chest that fills as the player plays: its picture, what it asks, a
     pip for each step done, and OPEN once it is owed. The quests' chest
     (`Rewards.bonus`) and the gift box (`Rewards.gift`) are both one. ]]
type Bar = {
	art: string,
	title: string,
	sub: string,
	pips: number,
	done: number,
	owed: boolean,
	--[[ Opened and done with for now: drawn pale. ]]
	faded: boolean,
	onOpen: () -> (),
}
local function chestBar(sheet: Chunky.Sheet, x: number, y: number, w: number, h: number, spec: Bar)
	local up = sheet.upright
	local card = Chunky.card(sheet, x, y, w, h)
	local size = if up then 150 else h - 24
	icon(sheet, spec.art, x + 16, y + (if up then 16 else 12), size)
	local tx = x + 16 + size + 20
	local buttonW = 190
	local textW = if up then w - (tx - x) - 20 else w - (tx - x) - buttonW - 330
	if spec.faded then
		card.BackgroundColor3 = Chunky.pale
	end
	words(
		sheet,
		spec.title,
		tx,
		y + (if up then 22 else h * 0.14),
		textW,
		if up then 56 else h * 0.4
	)
	words(
		sheet,
		spec.sub,
		tx,
		y + (if up then 86 else h * 0.58),
		textW,
		if up then 36 else h * 0.26
	).TextColor3 =
		Chunky.inkSoft
	local pip = if up then 58 else 62
	local px = if up then tx else x + w - buttonW - 40 - spec.pips * (pip + 14)
	local py = if up then y + h - pip - 22 else y + (h - pip) / 2
	for index = 1, spec.pips do
		local dot = Instance.new("Frame")
		dot.Name = "Pip"
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = if index <= spec.done then Chunky.lime else Chunky.trough
		dot.ZIndex = 30
		Chunky.put(sheet, dot, px + (index - 1) * (pip + 14), py, pip, pip)
		Chunky.round(dot, pip)
		Chunky.outline(dot, 5)
	end
	local bh = if up then 84 else math.min(84, h - 36)
	local bx = x + w - buttonW - 18
	local by = if up then y + h - bh - 18 else y + (h - bh) / 2
	if spec.owed then
		Chunky.gleam(Chunky.button(sheet, "OPEN", Chunky.gold, bx, by, buttonW, bh, spec.onOpen))
	end
end

local function draw(s: StationScreen.Screen)
	local profile = s.profile
	local loaded = profile ~= nil and (profile :: any).rewards ~= nil
	local day = today()
	--[[ The tab the screen opens on: the calendar when it has a gift, the
	     quests otherwise. It stays where the player put it until the
	     screen is opened again from its button. ]]
	local showing: Tab = tab
		or (
			if loaded
					and RewardRules.loginReady((profile :: SaveSchema.Profile).rewards, day)
				then "DAILY"
				else "QUESTS"
		)
	tab = showing
	local modes = {}
	for _, name in TABS do
		table.insert(modes, {
			words = name,
			on = showing == name,
			pick = function()
				if tab ~= name then
					tab = name
					s.open()
				end
			end,
		})
	end
	local area = HatchStand.chrome(s, "REWARDS", modes)
	local sheet = area.sheet
	if not loaded then
		words(sheet, "LOADING...", area.x, area.y + 200, area.w, 80, Enum.TextXAlignment.Center)
		return
	end
	local p = profile :: SaveSchema.Profile
	local r = p.rewards
	local up = sheet.upright
	local x, y, w = area.x, area.y, area.w

	-- how many rewards wait on each tab, on its corner
	local waiting = RewardRules.readyBy(p, day)
	local counts: { [Tab]: number } =
		{ DAILY = waiting.daily, QUESTS = waiting.quests, GOALS = waiting.goals }
	local tabW, tabX, tabY = if up then 300 else 250, if up then 70 else 190, y - 108
	for index, name in TABS do
		if counts[name] > 0 then
			local dot = Instance.new("Frame")
			dot.Name = "TabBadge"
			dot.BorderSizePixel = 0
			dot.BackgroundColor3 = Chunky.red
			dot.ZIndex = 45
			Chunky.put(sheet, dot, tabX + (index - 1) * (tabW + 18) + tabW - 34, tabY - 14, 48, 48)
			Chunky.round(dot, 24)
			Chunky.outline(dot, 5)
			local n = Chunky.textOn(dot, tostring(counts[name]), Chunky.red, 3)
			n.Position, n.Size = UDim2.fromScale(0.15, 0.12), UDim2.fromScale(0.7, 0.76)
			n.ZIndex = 46
		end
	end

	--[[ CLAIM ALL shows once two or more wait: the calendar, the quests and
	     the starter steps in one press. The chest and a goal's step are
	     claimed by themselves, for what comes out of them. ]]
	local owed = RewardRules.owedAll(p, day)

	local rowH, rowGap = if up then 170 else 140, 14
	local function list(rows: { Row }, from: number)
		for index, spec in sorted(rows) do
			row(s, sheet, x, from + (index - 1) * (rowH + rowGap), w, rowH, spec)
		end
	end

	if showing == "DAILY" then
		words(sheet, "A GIFT EVERY DAY YOU PLAY", x, y, w, 44)
		local below = calendar(sheet, r, day, x, y + 56, w)
		words(
			sheet,
			"MISS A DAY AND YOU KEEP YOUR PLACE",
			x,
			below + 18,
			w,
			36,
			Enum.TextXAlignment.Center
		).TextColor3 =
			Chunky.inkSoft
		--[[ The gift box (`Util/GiftRules`): a pip for each level won
		     towards the next gift, and OPEN while one waits. ]]
		local have, need = GiftRules.progress(p.gift)
		local gifts = GiftRules.ready(p.gift)
		chestBar(sheet, x, below + 66, w, if up then 240 else 140, {
			art = if GiftRules.kind(p.gift) == "Egg" then eggArt(p) else crateArt(),
			title = if gifts > 1
				then `{gifts} GIFTS READY!`
				elseif gifts == 1 then "GIFT READY!"
				else Rewards.gift.words,
			sub = "A FREE EGG OR WEAPON CRATE, NO WAITING",
			pips = need,
			done = have,
			owed = gifts > 0,
			faded = false,
			onOpen = function()
				claim("gift")
			end,
		})
	elseif showing == "QUESTS" then
		local barH = if up then 240 else 150
		local opened = RewardRules.bonusClaimed(r, day)
		chestBar(sheet, x, y, w, barH, {
			art = if RewardRules.bonusKind(day) == "Egg" then eggArt(p) else crateArt(),
			title = if opened then "CHEST OPENED!" else Rewards.bonus.words,
			sub = "NEW QUESTS IN " .. untilReset(),
			pips = #RewardRules.questsFor(day),
			done = RewardRules.questsClaimed(r, day),
			owed = RewardRules.bonusReady(r, day),
			faded = opened,
			onOpen = function()
				claim("bonus")
			end,
		})
		local rows: { Row } = {}
		for _, key in RewardRules.questsFor(day) do
			local quest = Rewards.quests[key]
			table.insert(rows, {
				kind = quest.kind,
				title = string.format(quest.words, quest.goal),
				have = RewardRules.progress(r, day, key),
				goal = quest.goal,
				pay = giftPay({ gems = quest.gems, coins = quest.coins }),
				claimed = RewardRules.questClaimed(r, day, key),
				onClaim = function()
					claim("quest", key)
				end,
				place = Rewards.places[quest.kind],
			})
		end
		list(rows, y + barH + 16)
	else
		--[[ The starter steps first, while any is left, then every goal
		     not finished yet (`Config/Goals`): what can be claimed on top.
		     A finished goal leaves the list and is counted in the line
		     above it. ]]
		local rows: { Row } = {}
		if not RewardRules.starterFinished(p) then
			for _, entry in Rewards.starter do
				table.insert(rows, {
					kind = entry.kind,
					title = entry.words,
					have = if RewardRules.starterDone(p, entry.key) then 1 else 0,
					goal = 1,
					pay = giftPay({ gems = entry.gems, coins = entry.coins }),
					claimed = r.starterClaimed[entry.key] == true,
					onClaim = function()
						claim("starter", entry.key)
					end,
					place = entry.place,
				})
			end
		end
		for _, goal in Goals.goals do
			local _, wanted, prize = GoalRules.step(p, goal)
			if wanted and prize then
				table.insert(rows, {
					kind = goal.kind,
					title = (string.gsub(goal.words, "%%d", Chunky.commas(wanted))),
					have = GoalRules.value(p, goal.stat),
					goal = wanted,
					pay = prizePay(p, prize),
					claimed = false,
					onClaim = function()
						claim("goal", goal.key)
					end,
					place = goal.place,
					medals = GoalRules.claimed(p, goal),
				})
			end
		end
		--[[ An area's star chests not opened yet (`Util/StarRules`): its
		     levels' stars against 10, 20 and 30. ]]
		for _, chest in StarRules.chests(p) do
			if not chest.claimed then
				table.insert(rows, {
					kind = "levels",
					title = chest.words,
					have = chest.have,
					goal = chest.need,
					pay = prizePay(p, chest.prize),
					claimed = false,
					onClaim = function()
						claim("stars", chest.key)
					end,
					place = "Portal",
				})
			end
		end
		--[[ And a chest for each Dex page not opened yet (`Util/PageRules`):
		     an area's enemies, or its set of pets or weapons. ]]
		for _, page in PageRules.pages(p) do
			if not page.claimed then
				table.insert(rows, {
					kind = PAGE_KINDS[page.book] or "kills",
					title = page.words,
					have = page.found,
					goal = page.total,
					pay = prizePay(p, page.prize),
					claimed = false,
					onClaim = function()
						claim("page", page.key)
					end,
					place = "DexHall",
				})
			end
		end
		local _, finished = GoalRules.tally(p)
		words(sheet, `{finished} / {#Goals.goals} GOALS DONE`, x, y, w, 44)
		if #rows == 0 then
			words(sheet, "EVERY GOAL DONE!", x, y + 120, w, 64, Enum.TextXAlignment.Center)
		else
			local top = y + 56
			local viewH = area.bottom - top - (if owed >= 2 then 100 else 0)
			local inner = scroller(sheet, x, top, w, viewH, #rows * (rowH + rowGap) + 10)
			for index, spec in sorted(rows) do
				row(s, inner, 8, 8 + (index - 1) * (rowH + rowGap), w - 40, rowH, spec)
			end
		end
	end

	if owed >= 2 then
		local bw, bh = 360, 84
		Chunky.gleam(
			Chunky.button(
				sheet,
				`CLAIM ALL ({owed})`,
				Chunky.green,
				x + w - bw,
				area.bottom - bh - 4,
				bw,
				bh,
				function()
					claim("all")
				end
			)
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
		-- on the corner, clear of the word's last letter (it covered the S)
		Chunky.put(sheet, dot, bx + bw - 18, by - 24, 52, 52)
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
			--[[ Put away under a portal's screen too, as PLAY is: it peeked
			     out beside the level panel (polish playthrough, 2026-11-13). ]]
			local free = inLobby
				and player:GetAttribute("InStation") ~= true
				and not PortalScreen.isOpen()
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
	--[[ A line that pays nothing by itself (how a quest is going) is said
	     alone, with no diamond and no "+0". ]]
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
			if gems == 0 then
				-- quest lines: the last said is the latest
				line = batch[#batch].words
			end
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
			if gems > 0 then
				t.Position, t.Size = UDim2.fromScale(0.04, 0.2), UDim2.fromScale(0.68, 0.6)
				t.TextXAlignment = Enum.TextXAlignment.Left
				local gem = Kit.image(pill, ShopAssets.gem)
				gem.Position, gem.Size = UDim2.fromScale(0.75, 0.12), UDim2.fromScale(0.08, 0.76)
				gem.ZIndex = 30
				local amount = Chunky.text(pill, "+" .. gems, Chunky.gold, 4)
				amount.Position, amount.Size =
					UDim2.fromScale(0.84, 0.2), UDim2.fromScale(0.13, 0.6)
				amount.TextXAlignment = Enum.TextXAlignment.Left
			else
				t.Position, t.Size = UDim2.fromScale(0.05, 0.2), UDim2.fromScale(0.9, 0.6)
			end
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

--[[ Reveals wait their turn: a goal's step can pay eggs and crates
     together, and a reveal asked for while another plays is dropped
     (`Reveal`). ]]
local reveals: { () -> () } = {}
local revealing = false
local function reveal(show: () -> ())
	table.insert(reveals, show)
	if revealing then
		return
	end
	revealing = true
	task.spawn(function()
		while #reveals > 0 do
			while Reveal.busy() do
				task.wait(0.2)
			end
			local nextOne = table.remove(reveals, 1)
			if nextOne then
				nextOne()
			end
			task.wait(0.2)
		end
		revealing = false
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
	QuestPointer.start()
	--[[ The quests' chest was opened (`Data/QuestChest`): what came out is
	     already in the profile; this is its reveal, the hatchery's or the
	     Blacksmith's own. ]]
	Remotes.event(Remotes.QuestChest).OnClientEvent:Connect(function(kind, key, results)
		if type(results) ~= "table" then
			return
		end
		if kind == "Egg" and type(key) == "string" then
			reveal(function()
				Reveal.eggs(key, results)
			end)
		elseif kind == "Crate" and type(key) == "number" then
			reveal(function()
				Reveal.crates(key, results)
			end)
		end
	end)
end

return RewardsScreen
