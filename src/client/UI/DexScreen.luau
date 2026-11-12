--!strict
--[[
	The Dex Hall's three books (owner, 2026-10-25: Enemy, Weapon and Pet
	codexes, entries not yet found drawn as black silhouettes; 2026-11-01:
	"start on the dex screens").

	Drawn in the chunky style (owner, 2026-11-05, approving the mockups in
	`assets/concepts/ui_refs/mockups/dex.jpg`): the blue panel with the gold
	DEX ribbon, a tab for each book and the FOUND count along its head, the
	chosen entry written out on a white card down the left, and fifteen
	rarity tiles on the right with an arrow either side. That replaces the
	painted book and its page-turn frames; a page now slides in from the
	side it was turned towards.

	A locked entry is its own picture tinted black. That is the whole trick
	of a silhouette here -- the shape is the answer, so it has to be the
	real picture and not a stand-in.

	`draw` builds the whole screen, because `UI/StationScreen` empties the
	canvas before every redraw. Within a draw, everything that changes with
	the page -- the left card's entry and the tiles -- lives in its own
	`Pages` frame that `fill` empties and remakes, so turning a page or
	picking a tile never rebuilds the panel or re-pops it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Chunky = require(script.Parent.Chunky)
local Dex = require(ReplicatedStorage.Shared.Config.Dex)
local DexBook = require(ReplicatedStorage.Shared.Util.DexBook)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local StationScreen = require(script.Parent.StationScreen)

local DexScreen = {}

--[[ Five across and three down, in both orientations, so a page holds the
     same entries however the phone is held. ]]
local COLUMNS, ROWS = 5, 3
local PER_PAGE = COLUMNS * ROWS

local screen: StationScreen.Screen? = nil
--[[ Which book is open, which page of it, and which entry is written out
     on the left. The page and the choice reset with the book, because
     entry 4 of the enemies has nothing to do with entry 4 of the pets. ]]
local book = DexBook.BOOKS[1]
local page = 1
local chosen: string? = nil

function DexScreen.open()
	if screen then
		screen.open()
	end
end

function DexScreen.close()
	if screen then
		screen.close()
	end
end

function DexScreen.isOpen(): boolean
	return screen ~= nil and screen.isOpen()
end

--[[ Where everything sits, in sheet pixels, landscape and upright. ]]
type Layout = {
	tab: { number }, -- x, y, w, h of the first tab; the rest step right
	found: { number },
	card: { number },
	picture: { number },
	name: { number },
	detail: { number },
	line: { number },
	grid: { number }, -- x, y and the tile size
	gap: number,
	back: { number },
	forward: { number },
	page: { number },
}

local WIDE: Layout = {
	tab = { 190, 182, 290, 88 },
	found = { 1330, 186, 400, 80 },
	card = { 190, 296, 470, 716 },
	picture = { 230, 320, 390, 300 },
	name = { 214, 630, 422, 70 },
	detail = { 240, 712, 370, 64 },
	line = { 222, 790, 406, 200 },
	grid = { 750, 300, 166 },
	gap = 16,
	back = { 674, 520, 64, 100 },
	forward = { 1666, 520, 64, 100 },
	page = { 1050, 880, 300, 72 },
}

local TALL: Layout = {
	tab = { 70, 290, 300, 88 },
	found = { 290, 400, 500, 76 },
	card = { 70, 500, 940, 520 },
	picture = { 96, 530, 360, 360 },
	name = { 470, 540, 516, 90 },
	detail = { 500, 650, 456, 66 },
	line = { 470, 740, 516, 250 },
	grid = { 70, 1060, 175 },
	gap = 16,
	back = { 70, 1660, 170, 100 },
	forward = { 840, 1660, 170, 100 },
	page = { 300, 1670, 480, 80 },
}

--[[ A deep-sea pill with white words, for the FOUND count and the page. ]]
local function plate(sheet: Chunky.Sheet, words: string, box: { number }): Frame
	local p = Instance.new("Frame")
	p.Name = "Plate"
	p.BorderSizePixel = 0
	p.BackgroundColor3 = Chunky.edge
	p.ZIndex = 6
	Chunky.put(sheet, p, box[1], box[2], box[3], box[4])
	Chunky.round(p, box[4])
	Chunky.outline(p, 5)
	local t = Chunky.text(p, words, nil, 4)
	t.Position, t.Size = UDim2.fromScale(0.08, 0.18), UDim2.fromScale(0.84, 0.64)
	t.ZIndex = 7
	return p
end

function DexScreen.start()
	if screen then
		return
	end
	local s = StationScreen.new("DexScreen", "DexHall", "DEX")
	screen = s

	s.draw = function()
		local area = HatchStand.chrome(s, "DEX")
		local sheet = area.sheet
		local L = if sheet.upright then TALL else WIDE

		for index, name in DexBook.BOOKS do
			Chunky.tab(
				sheet,
				string.upper(name),
				name == book,
				L.tab[1] + (index - 1) * (L.tab[3] + 18),
				L.tab[2],
				L.tab[3],
				L.tab[4],
				function()
					if book == name then
						return
					end
					book = name
					page = 1
					chosen = nil
					-- `open` clears the canvas before it draws; `draw` alone would not
					s.open()
				end
			)
		end

		local all = DexBook.entries(book, s.profile)
		local found, every = DexBook.found(all)
		plate(sheet, `FOUND {found} / {every}`, L.found)
		Chunky.card(sheet, table.unpack(L.card))

		--[[ Everything that changes with the page, on its own full-canvas
		     frame so a turn can empty it and slide it in. Laid out against
		     the same sheet, so its boxes line up with the panel's. ]]
		local pages = Instance.new("Frame")
		pages.Name = "Pages"
		pages.BackgroundTransparency = 1
		pages.Size = UDim2.fromScale(1, 1)
		-- above the panel (2) and the card (4): siblings draw by ZIndex
		pages.ZIndex = 8
		pages.Parent = sheet.canvas
		local on: Chunky.Sheet =
			{ canvas = pages, w = sheet.w, h = sheet.h, upright = sheet.upright }

		local total = DexBook.pages(all, PER_PAGE)
		local fill: (number) -> ()

		local function turn(step: number)
			if page + step < 1 or page + step > total then
				return
			end
			page += step
			chosen = nil
			fill(step)
		end
		local back = Chunky.button(
			sheet,
			"<",
			Chunky.blue,
			L.back[1],
			L.back[2],
			L.back[3],
			L.back[4],
			function()
				turn(-1)
			end
		)
		local forward = Chunky.button(
			sheet,
			">",
			Chunky.blue,
			L.forward[1],
			L.forward[2],
			L.forward[3],
			L.forward[4],
			function()
				turn(1)
			end
		)

		fill = function(step: number)
			pages:ClearAllChildren()
			page = math.clamp(page, 1, total)
			local shown = DexBook.page(all, page, PER_PAGE)
			back.Visible = page > 1
			forward.Visible = page < total
			plate(on, `PAGE {page}/{total}`, L.page)

			--[[ With nothing picked, the page writes out its first entry,
			     so the card is never blank. ]]
			local pick: DexBook.Entry? = nil
			for _, entry in shown do
				if entry.key == chosen then
					pick = entry
				end
			end
			pick = pick or shown[1]

			if pick then
				local picture = Kit.image(pages, pick.picture, not pick.unlocked)
				Chunky.put(on, picture, table.unpack(L.picture))
				picture.ZIndex = 8
				if not pick.unlocked then
					picture.ImageColor3 = Dex.silhouette
				end
				local name = Chunky.text(
					pages,
					if pick.unlocked then pick.name else Dex.unknownName,
					Chunky.ink,
					0
				)
				Chunky.put(on, name, table.unpack(L.name))
				name.ZIndex = 8

				local tone = Chunky.rarity[pick.rarity] or Chunky.grey
				local tag = Instance.new("Frame")
				tag.Name = "Detail"
				tag.BorderSizePixel = 0
				tag.BackgroundColor3 = tone
				tag.ZIndex = 7
				Chunky.put(on, tag, table.unpack(L.detail))
				Chunky.round(tag, L.detail[4])
				Chunky.outline(tag, 5)
				local tagWords = Chunky.textOn(
					tag,
					string.upper(if pick.unlocked then pick.detail else "???"),
					tone,
					4
				)
				tagWords.Position, tagWords.Size =
					UDim2.fromScale(0.08, 0.16), UDim2.fromScale(0.84, 0.68)
				tagWords.ZIndex = 8

				local line = Chunky.text(
					pages,
					if pick.unlocked then pick.description else Dex.unknownLine,
					Chunky.ink,
					0
				)
				Chunky.put(on, line, table.unpack(L.line))
				line.TextWrapped = true
				line.TextYAlignment = Enum.TextYAlignment.Top
				line.ZIndex = 8
				local most = Instance.new("UITextSizeConstraint")
				most.MaxTextSize = 34
				most.Parent = line
			end

			--[[ The fifteen tiles. A short last page leaves the rest of its
			     places empty rather than padding them. ]]
			local x0, y0, size = L.grid[1], L.grid[2], L.grid[3]
			local tiles = Instance.new("Frame")
			tiles.Name = "Tiles"
			tiles.BackgroundTransparency = 1
			tiles.Size = UDim2.fromScale(1, 1)
			tiles.Parent = pages
			local grid: Chunky.Sheet =
				{ canvas = tiles, w = sheet.w, h = sheet.h, upright = sheet.upright }
			for index, entry in shown do
				local across = (index - 1) % COLUMNS
				local down = math.floor((index - 1) / COLUMNS)
				local slot = Instance.new("Frame")
				slot.Name = `Slot{index}`
				slot.BackgroundTransparency = 1
				slot.ZIndex = 6
				Chunky.put(
					grid,
					slot,
					x0 + across * (size + L.gap),
					y0 + down * (size + L.gap),
					size,
					size
				)
				local tile = Chunky.tile(slot, entry.rarity, entry.picture, nil, not entry.unlocked)
				if not entry.unlocked then
					local mark = Chunky.text(tile, "?", nil, 5)
					mark.AnchorPoint = Vector2.new(1, 1)
					mark.Position, mark.Size =
						UDim2.fromScale(0.95, 0.95), UDim2.fromScale(0.34, 0.34)
					mark.ZIndex = 14
				end
				if pick and entry.key == pick.key then
					local ring = Instance.new("Frame")
					ring.Name = "Chosen"
					ring.BackgroundTransparency = 1
					ring.AnchorPoint = Vector2.new(0.5, 0.5)
					ring.Position, ring.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.1, 1.1)
					ring.ZIndex = 15
					ring.Parent = slot
					Chunky.round(ring, 22)
					Chunky.outline(ring, 7, Chunky.edge)
				end
				Chunky.press(slot, function()
					if chosen ~= entry.key then
						chosen = entry.key
						fill(0)
					end
				end)
			end

			--[[ A turned page's tiles slide in from the side it was turned
			     to; the card stays put. ]]
			if step ~= 0 then
				tiles.Position = UDim2.fromScale(0.05 * step, 0)
				TweenService:Create(
					tiles,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Position = UDim2.fromScale(0, 0) }
				):Play()
			end
		end

		fill(0)
	end
end

return DexScreen
