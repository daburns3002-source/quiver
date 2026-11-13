--!strict
--[[
	The Dex Hall's three books (owner, 2026-10-25: Enemy, Weapon and Pet
	codexes, entries not yet found drawn as black silhouettes; 2026-11-01:
	"start on the dex screens").

	**A book is a page an area** (owner, 2026-11-12: "the dexes should be 1
	page for each area with bigger icons on the right page. the page should
	also be themed to match the area"). The left card writes out the chosen
	entry, standing in front of its area's own scenery; the right-hand page
	is that area's whole set at once, its tiles as large as the page allows
	(`HatchStand.grid`: four enemies are a quarter of the page each, an
	area's eighteen weapons still fit), on a page in the area's colours
	with its name on the area's plate and its motes drifting over it
	(`Config/Dex.areas`, sampled off the area's approved NEW ENEMY! sheet).
	The arrows turn to the next area; `Util/DexBook` says which areas a
	book has.

	Drawn in the chunky style (owner, 2026-11-05, approving the mockups in
	`assets/concepts/ui_refs/mockups/dex.jpg`): the panel with the DEX
	ribbon, a tab for each book and the FOUND count along its head.

	A locked entry is its own picture tinted black. That is the whole trick
	of a silhouette here -- the shape is the answer, so it has to be the
	real picture and not a stand-in.

	`draw` builds the whole screen, because `UI/StationScreen` empties the
	canvas before every redraw. Within a draw, everything that changes with
	the page -- the left card's entry, the area's page and its tiles --
	lives in its own `Pages` frame that `fill` empties and remakes, so
	turning a page or picking a tile never rebuilds the panel or re-pops it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Chunky = require(script.Parent.Chunky)
local Dex = require(ReplicatedStorage.Shared.Config.Dex)
local DexBook = require(ReplicatedStorage.Shared.Util.DexBook)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)
local StationScreen = require(script.Parent.StationScreen)

local DexScreen = {}

local screen: StationScreen.Screen? = nil
--[[ Which book is open, which area's page of it, and which entry is
     written out on the left. The page and the choice reset with the book,
     because the weapon book has no Thornwood page to stay on. ]]
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

--[[ Where everything sits, in sheet pixels, landscape and upright. Each
     box is x, y, w, h. ]]
type Layout = {
	tab: { number }, -- the first tab; the rest step right
	found: { number },
	card: { number },
	scene: { number },
	picture: { number },
	name: { number },
	detail: { number },
	line: { number },
	leaf: { number }, -- the area's page
	back: { number },
	forward: { number },
	title: { number },
	count: { number },
	grid: { number }, -- the box the tiles are fitted into
	gap: number,
	--[[ The largest a tile is drawn: four enemies would otherwise be a
	     quarter of the page each and crowd its edges. ]]
	most: number,
}

local WIDE: Layout = {
	tab = { 190, 182, 290, 88 },
	found = { 1330, 186, 400, 80 },
	card = { 190, 296, 380, 716 },
	scene = { 208, 314, 344, 236 },
	picture = { 268, 320, 224, 224 },
	name = { 204, 562, 352, 64 },
	detail = { 228, 638, 304, 56 },
	line = { 208, 708, 344, 286 },
	leaf = { 588, 296, 1142, 716 },
	back = { 604, 310, 84, 72 },
	forward = { 1630, 310, 84, 72 },
	title = { 700, 310, 700, 72 },
	count = { 1414, 310, 204, 72 },
	grid = { 606, 396, 1106, 598 },
	gap = 14,
	most = 250,
}

local TALL: Layout = {
	tab = { 70, 290, 300, 88 },
	found = { 290, 400, 500, 76 },
	card = { 70, 496, 940, 330 },
	scene = { 90, 514, 400, 294 },
	picture = { 155, 526, 270, 270 },
	name = { 510, 520, 480, 78 },
	detail = { 530, 608, 440, 58 },
	line = { 510, 678, 480, 134 },
	leaf = { 70, 846, 940, 1004 },
	back = { 86, 862, 100, 80 },
	forward = { 894, 862, 100, 80 },
	title = { 200, 862, 500, 80 },
	count = { 712, 862, 170, 80 },
	grid = { 82, 960, 916, 872 },
	gap = 12,
	most = 260,
}

--[[ Where an area's motes sit on its page, as shares of the page: along
     its edges and its head, where the tiles do not cover them. ]]
local MOTES = {
	{ 0.03, 0.2 },
	{ 0.97, 0.3 },
	{ 0.5, 0.135 },
	{ 0.025, 0.62 },
	{ 0.975, 0.74 },
	{ 0.22, 0.985 },
	{ 0.68, 0.985 },
	{ 0.86, 0.14 },
	{ 0.14, 0.14 },
	{ 0.975, 0.5 },
}

--[[ A pill with words that read on it: deep sea with white words, or
     `colour` with the words that colour's face has (`Chunky.textOn`). For
     the FOUND count, an area's name and count, and the entry's name. ]]
local function plate(sheet: Chunky.Sheet, words: string, box: { number }, colour: Color3?): Frame
	local p = Instance.new("Frame")
	p.Name = "Plate"
	p.BorderSizePixel = 0
	p.BackgroundColor3 = colour or Chunky.edge
	p.ZIndex = 6
	Chunky.put(sheet, p, box[1], box[2], box[3], box[4])
	Chunky.round(p, box[4])
	Chunky.outline(p, 5, if colour then Chunky.shade(colour) else nil)
	local t = if colour then Chunky.textOn(p, words, colour, 4) else Chunky.text(p, words, nil, 4)
	t.Position, t.Size = UDim2.fromScale(0.08, 0.18), UDim2.fromScale(0.84, 0.64)
	t.ZIndex = 7
	return p
end

--[[ The area's page: its ground in the area's two colours inside its
     trim, and its motes, glowing round and breathing in turn. ]]
local function leaf(sheet: Chunky.Sheet, theme: Dex.AreaTheme, box: { number }): Frame
	local ground = Instance.new("Frame")
	ground.Name = "Leaf"
	ground.BorderSizePixel = 0
	ground.BackgroundColor3 = Color3.new(1, 1, 1)
	ground.ZIndex = 4
	Chunky.put(sheet, ground, box[1], box[2], box[3], box[4])
	local wash = Instance.new("UIGradient")
	wash.Rotation = 90
	wash.Color = ColorSequence.new(theme.groundTop, theme.groundBottom)
	wash.Parent = ground
	Chunky.round(ground, 26)
	Chunky.outline(ground, 8, theme.trim)
	for index, at in MOTES do
		local mote = Instance.new("Frame")
		mote.Name = "Mote"
		mote.BorderSizePixel = 0
		mote.BackgroundColor3 = theme.accent
		mote.AnchorPoint = Vector2.new(0.5, 0.5)
		mote.Position = UDim2.fromScale(at[1], at[2])
		mote.Size = UDim2.fromScale(0.012, 0.012)
		mote.SizeConstraint = Enum.SizeConstraint.RelativeXX
		mote.ZIndex = 5
		mote.Parent = ground
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = mote
		local halo = Instance.new("UIStroke")
		halo.Color = theme.accent
		halo.Transparency = 0.7
		halo.Parent = mote
		Kit.animate(mote, function(t)
			local glow = 0.5 + 0.5 * math.sin(t * 1.6 + index * 1.9)
			mote.BackgroundTransparency = 0.55 - 0.45 * glow
			halo.Thickness = math.max(1, mote.AbsoluteSize.X * (0.25 + 0.35 * glow))
		end)
	end
	return ground
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

		local areas = DexBook.areas(all)
		local total = math.max(#areas, 1)
		local fill: (number) -> ()

		local function turn(step: number)
			if page + step < 1 or page + step > total then
				return
			end
			page += step
			chosen = nil
			fill(step)
		end

		fill = function(step: number)
			pages:ClearAllChildren()
			page = math.clamp(page, 1, total)
			local here = areas[page]
			local theme: Dex.AreaTheme = (if here then Dex.areas[here] else nil) or Dex.plainArea
			local shown: { DexBook.Entry } = if here then DexBook.inArea(all, here) else {}

			--[[ With nothing picked, the page writes out its first entry,
			     so the card is never blank. ]]
			local pick: DexBook.Entry? = nil
			for _, entry in shown do
				if entry.key == chosen then
					pick = entry
				end
			end
			pick = pick or shown[1]

			-- the left card: the area's scenery, and the chosen entry in front of it
			local sheetArt = if here then NewEnemies.sheets[here] else nil
			local scene = Instance.new("ImageLabel")
			scene.Name = "Scene"
			scene.BorderSizePixel = 0
			scene.BackgroundColor3 = theme.groundTop
			scene.ZIndex = 6
			if sheetArt and theme.scene.w > 0 then
				scene.Image = sheetArt.top
				scene.ImageRectOffset = Vector2.new(theme.scene.x, theme.scene.y)
				scene.ImageRectSize = Vector2.new(theme.scene.w, theme.scene.h)
				scene.ScaleType = Enum.ScaleType.Crop
				scene.ResampleMode = Enum.ResamplerMode.Pixelated
			end
			Chunky.put(on, scene, table.unpack(L.scene))
			Chunky.round(scene, 18)
			Chunky.outline(scene, 6, theme.trim)

			if pick then
				local picture = Kit.image(pages, pick.picture, not pick.unlocked)
				Chunky.put(on, picture, table.unpack(L.picture))
				picture.ZIndex = 8
				if not pick.unlocked then
					picture.ImageColor3 = Dex.silhouette
				end
				local name = plate(
					on,
					if pick.unlocked then pick.name else Dex.unknownName,
					L.name,
					theme.plate
				)
				name.Name = "Name"

				local tone = Chunky.rarity[pick.rarity] or Chunky.grey
				local tag = plate(
					on,
					string.upper(if pick.unlocked then pick.detail else "???"),
					L.detail,
					tone
				)
				tag.Name = "Detail"

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

			--[[ The area's page, and what turns with it: the page itself,
			     its name, its own count, the arrows and the tiles. A turned
			     page slides in from the side it was turned to; the card
			     stays put. ]]
			local turning = Instance.new("Frame")
			turning.Name = "Turning"
			turning.BackgroundTransparency = 1
			turning.Size = UDim2.fromScale(1, 1)
			turning.ZIndex = 4
			turning.Parent = pages
			local leafOn: Chunky.Sheet =
				{ canvas = turning, w = sheet.w, h = sheet.h, upright = sheet.upright }
			leaf(leafOn, theme, L.leaf)
			local title = "NOTHING HERE YET"
			if here then
				title = if theme.name ~= ""
					then theme.name
					else string.upper((string.gsub(here, "(%l)(%u)", "%1 %2")))
			end
			plate(leafOn, title, L.title, theme.plate).Name = "Area"
			local areaFound = DexBook.found(shown)
			plate(leafOn, `{areaFound} / {#shown}`, L.count).Name = "AreaFound"
			if page > 1 then
				Chunky.button(
					leafOn,
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
			end
			if page < total then
				Chunky.button(
					leafOn,
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
			end

			--[[ The tiles, as large as the page allows for however many the
			     area has, centred on it. ]]
			local gx, gy, gw, gh = L.grid[1], L.grid[2], L.grid[3], L.grid[4]
			local columns, size = HatchStand.grid(#shown, gw, gh, L.gap)
			size = math.min(size, L.most)
			local rows = math.max(math.ceil(#shown / columns), 1)
			local x0 = gx + (gw - (columns * size + (columns - 1) * L.gap)) / 2
			local y0 = gy + (gh - (rows * size + (rows - 1) * L.gap)) / 2
			for index, entry in shown do
				local across = (index - 1) % columns
				local down = (index - 1) // columns
				local slot = Instance.new("Frame")
				slot.Name = `Slot{index}`
				slot.BackgroundTransparency = 1
				slot.ZIndex = 6
				Chunky.put(
					leafOn,
					slot,
					x0 + across * (size + L.gap),
					y0 + down * (size + L.gap),
					size,
					size
				)
				local tile = Chunky.tile(slot, entry.rarity, entry.picture, nil, not entry.unlocked)
				--[[ No caption here, so the picture has the whole tile
				     (owner: "bigger icons"). ]]
				local art = tile:FindFirstChild("Picture")
				if art and art:IsA("GuiObject") then
					art.Position, art.Size =
						UDim2.fromScale(0.07, 0.07), UDim2.fromScale(0.86, 0.86)
				end
				Chunky.tier(tile, entry.tier)
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
					ring.Position, ring.Size =
						UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.08, 1.08)
					ring.ZIndex = 15
					ring.Parent = slot
					Chunky.round(ring, 22)
					Chunky.outline(ring, 7, Chunky.white)
				end
				Chunky.press(slot, function()
					if chosen ~= entry.key then
						chosen = entry.key
						fill(0)
					end
				end)
			end

			if step ~= 0 then
				turning.Position = UDim2.fromScale(0.05 * step, 0)
				TweenService:Create(
					turning,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Position = UDim2.fromScale(0, 0) }
				):Play()
			end
		end

		fill(0)
	end
end

return DexScreen
