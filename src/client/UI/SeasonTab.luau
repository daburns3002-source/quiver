--!strict
--[[
	The REWARDS screen's SEASON tab (`Config/Season`; owner, 2026-11-18):
	the season's name and "SEASON ENDS IN", the player's tier and XP bar,
	premium bought or a button to buy it, and the 30 tiers in a list that
	scrolls, the free track and the premium track side by side, each with
	CLAIM once it is owed. CLAIM ALL takes every tier owed.

	It only draws and asks. What is owed is worked out with the same pure
	rules the server uses (`Util/SeasonRules`) from the profile the server
	sent and the server's time (`Workspace:GetServerTimeNow()` plus the
	Player's `SeasonShift`, Studio's clock shift); CLAIM sends
	`Remotes.SeasonClaim` with the track and tier and nothing else, and
	PREMIUM sends `Remotes.StoreBuy("SeasonPass", "Season")`, which the
	server prompts only if it can be bought.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Chunky = require(script.Parent.Chunky)
local ItemIcons = require(ReplicatedStorage.Shared.Util.ItemIcons)
local Kit = require(script.Parent.Kit)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RewardPickRules = require(ReplicatedStorage.Shared.Util.RewardPickRules)
local RobuxStore = require(script.Parent.RobuxStore)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local Season = require(ReplicatedStorage.Shared.Config.Season)
local SeasonRules = require(ReplicatedStorage.Shared.Util.SeasonRules)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local StoreRules = require(ReplicatedStorage.Shared.Util.StoreRules)
local Trails = require(ReplicatedStorage.Shared.Config.Trails)

local SeasonTab = {}

local player = Players.LocalPlayer

--[[ What the tab is drawn in: the screen's area (`HatchStand.chrome`), and
     the pictures of the free egg and crate this player would get. ]]
export type Area = {
	--[[ The season titles held and the one worn, for tier 30's WEAR. ]]
	titles: { [string]: boolean },
	title: string?,
	sheet: Chunky.Sheet,
	x: number,
	y: number,
	w: number,
	bottom: number,
	egg: string,
	crate: string,
}

--[[ The server's time for this player's season. ]]
function SeasonTab.now(): number
	local shift = player:GetAttribute("SeasonShift")
	return Workspace:GetServerTimeNow() + (if type(shift) == "number" then shift else 0)
end

local function state(profile: SaveSchema.Profile): SeasonRules.State
	return (profile :: any).season or SeasonRules.empty()
end

--[[ How many tiers wait to be claimed, for the tab's corner. ]]
function SeasonTab.owed(profile: SaveSchema.Profile): number
	local s = state(profile)
	return if SeasonRules.live(s, SeasonTab.now()) then #SeasonRules.owed(s) else 0
end

local function claim(track: string, tier: number?)
	Remotes.event(Remotes.SeasonClaim):FireServer(track, tier)
end

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

--[[ A season title as it stands over a name tag, on a dark chip. ]]
local function titleChip(
	sheet: Chunky.Sheet,
	key: string,
	x: number,
	y: number,
	w: number,
	h: number
)
	local title = Season.titles[key]
	if not title then
		return
	end
	local chip = Instance.new("Frame")
	chip.Name = "TitleChip"
	chip.BorderSizePixel = 0
	chip.BackgroundColor3 = Chunky.navy
	chip.ZIndex = 30
	Chunky.put(sheet, chip, x, y, w, h)
	Chunky.round(chip, 14)
	local t = Chunky.text(chip, "+ " .. title.text .. " +", title.colour, 2, title.stroke)
	t.Position, t.Size = UDim2.fromScale(0.06, 0.12), UDim2.fromScale(0.88, 0.76)
	t.ZIndex = 31
end

--[[ One line of what a tier gives: a picture and words, or a title. ]]
type Line = { asset: string?, words: string, title: string? }

local function lines(
	prize: Season.Prize,
	def: Season.SeasonDef,
	area: Area,
	track: SeasonRules.Track
): { Line }
	local out: { Line } = {}
	local function add(asset: string, n: number?)
		if n and n > 0 then
			table.insert(out, { asset = asset, words = "+" .. Chunky.commas(n) })
		end
	end
	--[[ Tier 30's earned weapon, first: its 2D picture and its name. Or its
	     set pick (`Util/RewardPickRules`): the set's star's picture, and
	     ANY LANTERN BLOOM WEAPON. ]]
	local weapon = if prize.weapon then SeasonRules.weapon(def, track) else nil
	local pick = if prize.weapon then SeasonRules.pick(def, track) else nil
	if weapon then
		local picture = ItemIcons.weapon(weapon)
		local spaced = string.gsub(weapon, "(%l)(%u)", "%1 %2")
		table.insert(
			out,
			{ asset = if picture ~= "" then picture else nil, words = string.upper(spaced) }
		)
	elseif pick then
		local star = RewardPickRules.headline(pick)
		local picture = if star then ItemIcons.weapon(star) else ""
		local set = ShopRules.set(pick)
		table.insert(out, {
			asset = if picture ~= "" then picture else nil,
			words = `ANY {if set then set.name else string.upper(pick)} WEAPON`,
		})
	end
	if prize.title then
		table.insert(out, { words = "", title = def.title })
	end
	if prize.trail then
		local trail = Trails.trails[def.trail]
		table.insert(out, {
			asset = if trail and trail.icon ~= "" then trail.icon else nil,
			words = if trail then trail.name else "TRAIL",
		})
	end
	add(area.egg, prize.eggs)
	add(area.crate, prize.crates)
	add(ShopAssets.gem, prize.gems)
	add(ShopAssets.coin, prize.coins)
	return out
end

--[[ One track's cell of a tier: what it gives, and CLAIM, DONE or a lock. ]]
local function cell(
	sheet: Chunky.Sheet,
	area: Area,
	def: Season.SeasonDef,
	s: SeasonRules.State,
	track: SeasonRules.Track,
	tier: number,
	x: number,
	y: number,
	w: number,
	h: number
)
	local card = Chunky.card(sheet, x, y, w, h)
	local prize = SeasonRules.prize(track, tier)
	if not prize then
		return
	end
	local claimed = SeasonRules.claimed(s, track, tier)
	local ready = SeasonRules.ready(s, track, tier)
	local locked = track == "premium" and not s.premium
	if claimed then
		card.BackgroundColor3 = Chunky.pale
	elseif track == "premium" then
		card.BackgroundColor3 = Chunky.lit(Chunky.gold)
	end
	local buttonW = math.min(170, w * 0.36)
	local list = lines(prize, def, area, track)
	local line = math.min((h - 16) / math.max(#list, 1), 56)
	local top = y + (h - line * #list) / 2
	local left = w - buttonW - 36
	for index, entry in list do
		local ly = top + (index - 1) * line
		local title = entry.title
		if title then
			titleChip(sheet, title, x + 14, ly + 2, left, line - 4)
		else
			local asset = entry.asset
			local tx = x + 14
			if asset then
				icon(sheet, asset, tx, ly, line)
				tx += line + 6
			end
			words(sheet, entry.words, tx, ly + line * 0.12, x + 14 + left - tx, line * 0.76)
		end
	end
	local bh = math.min(76, h - 28)
	local bx, by = x + w - buttonW - 12, y + (h - bh) / 2
	local title = if prize.title then def.title else nil
	if claimed and title and area.titles[title] then
		--[[ The title, once held, is worn or taken off here
		     (`Remotes.SeasonTitle`). ]]
		local worn = area.title == title
		Chunky.button(
			sheet,
			if worn then "TAKE OFF" else "WEAR",
			if worn then Chunky.grey else Chunky.blue,
			bx,
			by,
			buttonW,
			bh,
			function()
				Remotes.event(Remotes.SeasonTitle):FireServer(if worn then nil else title)
			end
		)
	elseif claimed then
		words(sheet, "DONE", bx, by + bh * 0.2, buttonW, bh * 0.6, Enum.TextXAlignment.Center).TextColor3 =
			Chunky.inkSoft
	elseif ready then
		Chunky.gleam(Chunky.button(sheet, "CLAIM", Chunky.green, bx, by, buttonW, bh, function()
			claim(track, tier)
		end))
	elseif locked then
		icon(sheet, ShopAssets.lock, bx + (buttonW - bh) / 2, by, bh)
	end
end

--[[ A list that scrolls, as the GOALS tab's: a sheet of its own. ]]
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
	list.Name = "SeasonList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 10
	list.ScrollBarImageColor3 = Chunky.navy
	list.CanvasSize = UDim2.fromScale(0, tall / sheet.h)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ZIndex = 6
	Chunky.put(sheet, list, x, y, w, h)
	return { canvas = list :: any, w = w, h = tall, upright = sheet.upright }
end

--[[ The countdown's words at `time`. ]]
local function countdown(window: SeasonRules.Window, running: boolean, time: number): string
	if running then
		return "SEASON ENDS IN " .. SeasonRules.left(window.ends - time)
	end
	return string.format(
		"SEASON %d STARTS IN %s",
		window.def.number,
		SeasonRules.left(window.starts - time)
	)
end

function SeasonTab.draw(profile: SaveSchema.Profile, area: Area)
	local sheet = area.sheet
	local up = sheet.upright
	local x, y, w = area.x, area.y, area.w
	local time = SeasonTab.now()
	local s = state(profile)
	local running = SeasonRules.at(time)
	local window = running or SeasonRules.upcoming(time)
	if not window then
		words(sheet, "NO SEASON RIGHT NOW", x, y + 160, w, 64, Enum.TextXAlignment.Center)
		words(sheet, "THE NEXT ONE IS COMING SOON", x, y + 240, w, 44, Enum.TextXAlignment.Center).TextColor3 =
			Chunky.inkSoft
		return
	end
	local def = window.def
	-- the state shown is this season's; one from an ended month is settled by the server
	local mine = if running and s.key == running.key then s else SeasonRules.empty(window.key)

	-- the season: its name, its countdown, and premium
	local headH = if up then 210 else 150
	local head = Chunky.card(sheet, x, y, w, headH)
	head.Name = "SeasonHead"
	-- the season's two colours, a band down the card's left
	for index, colour in { def.colour, def.accent } do
		local band = Instance.new("Frame")
		band.Name = "SeasonBand"
		band.BorderSizePixel = 0
		band.BackgroundColor3 = colour
		band.ZIndex = 5
		Chunky.put(
			sheet,
			band,
			x + 10 + (index - 1) * 30,
			y + 10,
			if index == 1 then 26 else 14,
			headH - 20
		)
		Chunky.round(band, 10)
	end
	local textW = w * (if up then 0.56 else 0.6)
	words(
		sheet,
		string.format("SEASON %d: %s", def.number, def.name),
		x + 72,
		y + headH * 0.12,
		textW,
		headH * 0.36
	)
	local clock = words(
		sheet,
		countdown(window, running ~= nil, time),
		x + 72,
		y + headH * 0.56,
		textW,
		headH * 0.26
	)
	clock.TextColor3 = Chunky.inkSoft
	-- the countdown runs while it is on screen
	task.spawn(function()
		while clock.Parent do
			task.wait(1)
			if clock.Parent then
				clock.Text = countdown(window, running ~= nil, SeasonTab.now())
			end
		end
	end)
	local buyW, buyH = w - textW - 120, math.min(96, headH - 40)
	local bx, by = x + w - buyW - 20, y + (headH - buyH) / 2
	local product = StoreRules.product(Season.product)
	if mine.premium then
		local tag = Chunky.text(sheet.canvas, "PREMIUM", Chunky.gold, 4)
		Chunky.put(sheet, tag, bx, by + buyH * 0.1, buyW, buyH * 0.8)
	elseif product and running then
		local live = StoreRules.live(product)
		local button = Chunky.button(
			sheet,
			if live then "PREMIUM " .. RobuxStore.price(product.robux) else "PREMIUM SOON",
			if live then Chunky.gold else Chunky.grey,
			bx,
			by,
			buyW,
			buyH,
			function()
				if live then
					Remotes.event(Remotes.StoreBuy):FireServer(product.key, "Season")
				end
			end
		)
		if live then
			Chunky.gleam(button)
		end
	end

	-- the tier and the XP into the next
	local rowY = y + headH + 16
	local tierH = if up then 70 else 56
	local tier = SeasonRules.tier(mine.xp)
	words(sheet, string.format("TIER %d / %d", tier, #Season.tiers), x, rowY, w * 0.3, tierH)
	local into, need = SeasonRules.bar(mine.xp)
	local trough =
		Chunky.bar(sheet, into / need, Chunky.lime, x + w * 0.32, rowY + 6, w * 0.68, tierH - 12)
	local count = Chunky.text(
		trough,
		if tier >= #Season.tiers
			then "EVERY TIER REACHED!"
			else `{Chunky.commas(into)} / {Chunky.commas(need)} XP`,
		Chunky.white,
		4
	)
	count.Position, count.Size = UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.8)

	-- the two tracks' names over their columns
	local discW = if up then 96 else 110
	local gap = 12
	local listX = 8
	local cellW = (w - 40 - listX - discW - gap * 2) / 2
	local namesY = rowY + tierH + 12
	local function trackName(text: string, column: number, colour: Color3)
		local t = words(
			sheet,
			text,
			x + listX + discW + gap + column * (cellW + gap),
			namesY,
			cellW,
			40,
			Enum.TextXAlignment.Center
		)
		t.TextColor3 = colour
	end
	trackName("FREE", 0, Chunky.ink)
	trackName("PREMIUM", 1, Chunky.shade(Chunky.gold))

	-- the tiers, from 1, the list starting where the player is
	local owed = if running and s.key == running.key then #SeasonRules.owed(s) else 0
	local listTop = namesY + 48
	local viewH = area.bottom - listTop - (if owed >= 2 then 100 else 0)
	local rowH = if up then 150 else 118
	local step = rowH + gap
	local inner = scroller(sheet, x, listTop, w, viewH, #Season.tiers * step + 10)
	for n = 1, #Season.tiers do
		local ty = 6 + (n - 1) * step
		local disc = Instance.new("Frame")
		disc.Name = "TierDisc"
		disc.BorderSizePixel = 0
		disc.BackgroundColor3 = if tier >= n then def.colour else Chunky.pale
		disc.ZIndex = 8
		local size = math.min(discW, rowH - 20)
		Chunky.put(inner, disc, listX + (discW - size) / 2, ty + (rowH - size) / 2, size, size)
		Chunky.round(disc, size / 2)
		Chunky.outline(disc, 4)
		local label = Chunky.textOn(disc, tostring(n), disc.BackgroundColor3, 3)
		label.Position, label.Size = UDim2.fromScale(0.15, 0.18), UDim2.fromScale(0.7, 0.64)
		label.ZIndex = 9
		for column, track: SeasonRules.Track in SeasonRules.TRACKS do
			cell(
				inner,
				area,
				def,
				mine,
				track,
				n,
				listX + discW + gap + (column - 1) * (cellW + gap),
				ty,
				cellW,
				rowH
			)
		end
	end
	-- scrolled to the first tier owed, or the one being worked on
	local first = tier + 1
	for _, entry in SeasonRules.owed(mine) do
		first = math.min(first, entry.tier)
	end
	local list = inner.canvas :: any
	task.defer(function()
		if list.Parent then
			local at = math.max(0, (math.min(first, #Season.tiers) - 1) * step)
			list.CanvasPosition = Vector2.new(0, list.AbsoluteCanvasSize.Y * at / inner.h)
		end
	end)

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

return SeasonTab
