--!strict
--[[
	The egg and crate stand, shared by the Egg Hatchery and the Blacksmith's
	crates (owner, 2026-10-27: the weapon chests "changed exactly how you are
	changing the pets and with the same ui"), in the chunky style the owner
	approved on 2026-11-05 (`UI/Chunky`, assets/concepts/ui_refs/mockups/
	hatchery.jpg and shop.jpg): the egg or crate on its pedestal with its
	name, price, picker and press buttons; a white card of what is inside
	with the odds and the pity bar. E presses one, R three, T toggles AUTO.

	`controller` runs AUTO for a screen: presses follow one another until
	STOP, the screen closes or the coins run out; the stand hides while a
	reveal plays over the backdrop.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Chunky = require(script.Parent.Chunky)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Kit = require(script.Parent.Kit)
local Pity = require(ReplicatedStorage.Shared.Util.Pity)
local Reveal = require(script.Parent.Reveal)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local StationScreen = require(script.Parent.StationScreen)
local HatchStand = {}

export type Tile = {
	rarity: string,
	icon: string,
	--[[ The pet's key (`Config/PetModels`), when the card should stand its
	     real model up rather than draw a picture. A weapon has none: its
	     card keeps the 2D art. ]]
	key: string?,
	chance: number,
	owned: boolean,
	--[[ Drawn black on its rarity's card, as Codex's screens draw a Mythic
	     nobody has pulled yet: the colour says how rare, the silhouette
	     keeps what it is a surprise. ]]
	silhouette: boolean?,
}
export type Spec = {
	title: string,
	price: number,
	picker: string,
	onPick: () -> (),
	tiles: { Tile },
	--[[ Why nothing can be opened, if so ("BEAT KING BLOBLIN", ...). ]]
	locked: string?,
	pity: number,
	picture: string,
	--[[ The scene washed in behind the cards (Codex put the Mossy Glade
	     behind his), empty for none. ]]
	backdrop: string,
	--[[ The chests along the panel's top strip, where Codex drew his
	     Bows / Wands / Swords (`Config/Shop.chests`). Empty for a stand
	     with one thing inside, like an egg, which then keeps its picker
	     in the strip instead. ]]
	tabs: { { words: string, on: boolean, pick: () -> () } },
	--[[ The press counts (1 and 3) and the word on their prompts. ]]
	counts: { number },
	verb: string,
	--[[ What the cards hold, for the line under them: "PETS", "WEAPONS". ]]
	noun: string,
	--[[ The ribbon's words when they are not `title` (the Blacksmith's
	     ribbon names the station; the stand under it names the chest). ]]
	heading: string?,
	--[[ The screen's own modes, as tabs along the panel's head (the
	     Blacksmith's CRATES and STORE). ]]
	modes: { Mode }?,
}
export type Mode = { words: string, on: boolean, pick: () -> () }
export type Controller = {
	auto: boolean,
	toggle: () -> (),
}
export type Area = { sheet: Chunky.Sheet, x: number, y: number, w: number, bottom: number }

function HatchStand.commas(n: number): string
	local text = tostring(n)
	repeat
		local formatted, changes = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = formatted
	until changes == 0
	return text
end

--[[
	The chunky frame every Blacksmith and Hatchery screen stands in: the blue
	panel, the gold ribbon carrying `title` over its top edge, the red X off
	its corner, the wallet top-left and `modes` as tabs along the panel's
	head. Returns the room left inside the panel. Laid out for the screen as
	it is held: 1920 x 1080, or 1080 x 1920 on a phone held upright.
]]
function HatchStand.chrome(s: StationScreen.Screen, title: string, modes: { Mode }?): Area
	local c = s.canvas
	local dim = c.Parent :: GuiObject
	-- the station's back arrow and old wallet give way to the X and the pills
	for _, child in c:GetChildren() do
		if child:IsA("ImageButton") or child.Name == "Wallet" then
			child:Destroy()
		end
	end
	--[[ Once per screen: pop in on each opening, and lay out again when a
	     phone turns between upright and landscape. ]]
	if not c:GetAttribute("ChunkyWatch") then
		c:SetAttribute("ChunkyWatch", true)
		local upright = dim.AbsoluteSize.Y > dim.AbsoluteSize.X
		s.connect(dim:GetPropertyChangedSignal("Visible"), function()
			if not dim.Visible then
				c:SetAttribute("Shown", nil)
			end
		end)
		s.connect(dim:GetPropertyChangedSignal("AbsoluteSize"), function()
			local now = dim.AbsoluteSize.Y > dim.AbsoluteSize.X
			if now ~= upright then
				upright = now
				if s.isOpen() and not Reveal.busy() then
					s.open()
				end
			end
		end)
	end
	local sheet = Chunky.sheet(c)
	local up = sheet.upright
	if up then
		Chunky.panel(sheet, 30, 196, 1020, 1694)
		Chunky.ribbon(sheet, title, 170, 116, 740, 150)
		Chunky.close(sheet, 956, 150, 110, s.close)
	else
		Chunky.panel(sheet, 150, 104, 1620, 940)
		Chunky.ribbon(sheet, title, 630, 22, 660, 144)
		Chunky.close(sheet, 1688, 66, 108, s.close)
	end
	local p = s.profile
	Chunky.wallet(
		sheet,
		if p then p.coins else 0,
		if p then p.gems else 0,
		if up then 40 else 170,
		if up then 24 else 18,
		if up then 80 else 70
	)
	local top = if up then 290 else 182
	if modes then
		local w = if up then 300 else 250
		for i, mode in modes do
			Chunky.tab(
				sheet,
				mode.words,
				if i == 1 then Chunky.gold else Chunky.blue,
				mode.on,
				(if up then 70 else 190) + (i - 1) * (w + 18),
				top,
				w,
				88,
				function()
					if not Reveal.busy() then
						mode.pick()
					end
				end
			)
		end
		top += 108
	end
	if not c:GetAttribute("Shown") then
		c:SetAttribute("Shown", true)
		Chunky.pop(c)
	end
	return {
		sheet = sheet,
		x = if up then 70 else 190,
		y = top,
		w = if up then 940 else 1540,
		bottom = if up then 1850 else 1012,
	}
end

--[[ The odds as the cards print them: "2.5%". ]]
local function odds(chance: number): string
	return string.format("%g%%", math.round(chance * 10000) / 100)
end

--[[ The columns that make the largest square tiles for `count` in a w x h
     box, and that size. ]]
function HatchStand.grid(count: number, w: number, h: number, gap: number): (number, number)
	local bestCols, bestSize = 1, 0
	for cols = 1, math.max(count, 1) do
		local rows = math.ceil(count / cols)
		local size = math.min((w - (cols - 1) * gap) / cols, (h - (rows - 1) * gap) / rows)
		if size > bestSize then
			bestCols, bestSize = cols, size
		end
	end
	return bestCols, math.floor(bestSize)
end

local function words(
	sheet: Chunky.Sheet,
	text: string,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3?,
	stroke: number?
): TextLabel
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.ZIndex = 6
	Chunky.put(sheet, box, x, y, w, h)
	return Chunky.text(box, text, colour, stroke)
end

--[[ Draws the stand onto `s`'s canvas, as the approved mockups' Hatchery
     and Blacksmith. `press(count)` asks the server, `affordable(count)`
     says whether it may. ]]
function HatchStand.draw(
	s: StationScreen.Screen,
	spec: Spec,
	control: Controller,
	press: (number) -> (),
	affordable: (number) -> boolean
)
	local area = HatchStand.chrome(s, spec.heading or spec.title, spec.modes)
	local sheet = area.sheet
	local up = sheet.upright
	-- the stand's column, and the white card beside it (under it, upright)
	local cx, cy, cw = area.x, area.y, if up then area.w else 620
	local cBottom = if up then cy + 820 else area.bottom
	local kx = if up then area.x else 850
	local ky = if up then cBottom + 30 else area.y
	local kw = if up then area.w else 880
	local kh = area.bottom - ky

	local function guard(action: () -> ()): () -> ()
		return function()
			if not Reveal.busy() then
				control.auto = false
				action()
			end
		end
	end

	-- the picker row: the chests as tabs, or the one picker for an egg
	local y = cy
	if #spec.tabs > 0 then
		local gap = 14
		local w = (cw - (#spec.tabs - 1) * gap) / #spec.tabs
		for i, tab in spec.tabs do
			Chunky.tab(
				sheet,
				tab.words,
				Chunky.purple,
				tab.on,
				cx + (i - 1) * (w + gap),
				y,
				w,
				78,
				guard(tab.pick)
			)
		end
	else
		Chunky.button(sheet, `<  {spec.picker}  >`, Chunky.blue, cx, y, cw, 84, guard(spec.onPick))
	end
	y += 100

	-- the egg or crate on its pedestal, in a soft glow
	local size = math.min(cw * 0.62, cBottom - 316 - y)
	local pedestal = Instance.new("Frame")
	pedestal.BorderSizePixel = 0
	pedestal.BackgroundColor3 = Chunky.navy
	pedestal.BackgroundTransparency = 0.45
	pedestal.ZIndex = 4
	Chunky.put(sheet, pedestal, cx + cw / 2 - size * 0.55, y + size * 0.84, size * 1.1, size * 0.2)
	Chunky.round(pedestal, size)
	local glow = Kit.image(sheet.canvas, GearAssets.fx.glow)
	Chunky.put(sheet, glow, cx + cw / 2 - size * 0.7, y - size * 0.1, size * 1.4, size * 1.2)
	glow.ImageTransparency = 0.55
	glow.ZIndex = 4
	if spec.picture ~= "" then
		local picture = Kit.image(sheet.canvas, spec.picture)
		Chunky.put(sheet, picture, cx + cw / 2 - size / 2, y, size, size)
		picture.ZIndex = 6
		if spec.locked then
			picture.ImageColor3 = Color3.fromRGB(70, 74, 96)
		end
	end
	y = cBottom - 316

	words(sheet, spec.title, cx, y, cw, 76, nil, 6)
	y += 92

	-- the price, and beside it the area picker when the chests took the tabs
	if #spec.tabs > 0 then
		Chunky.pill(sheet, ShopAssets.coin, Chunky.commas(spec.price), cx, y, 250, 82, Chunky.gold)
		Chunky.button(
			sheet,
			`<  {spec.picker}  >`,
			Chunky.blue,
			cx + 270,
			y,
			cw - 270,
			82,
			guard(spec.onPick)
		)
	else
		Chunky.pill(
			sheet,
			ShopAssets.coin,
			Chunky.commas(spec.price),
			cx + cw / 2 - 140,
			y,
			280,
			82,
			Chunky.gold
		)
	end
	y += 104

	-- one button per count, then AUTO
	local slots = #spec.counts + 1
	local gap = 16
	local bw = (cw - (slots - 1) * gap) / slots
	for i, count in spec.counts do
		Chunky.button(
			sheet,
			`{spec.verb} {count}`,
			if not affordable(count)
				then Chunky.grey
				elseif i == 1 then Chunky.green
				else Chunky.gold,
			cx + (i - 1) * (bw + gap),
			y,
			bw,
			116,
			function()
				press(count)
			end
		)
	end
	Chunky.button(
		sheet,
		if control.auto then "AUTO ON" else "AUTO",
		if control.auto then Chunky.green else Chunky.blue,
		cx + #spec.counts * (bw + gap),
		y,
		bw,
		116,
		control.toggle
	)

	-- what is inside, on the white card
	Chunky.card(sheet, kx, ky, kw, kh)
	words(sheet, `{spec.noun} INSIDE`, kx + 24, ky + 14, kw - 48, 62, Chunky.navy, 0)
	local held = #spec.tiles
	local gx, gy, gw, gh = kx + 28, ky + 88, kw - 56, kh - 88 - 120
	local tileGap = 16
	local cols, tile = HatchStand.grid(held, gw, gh, tileGap)
	local rows = math.max(math.ceil(held / cols), 1)
	local left = gx + (gw - (cols * tile + (cols - 1) * tileGap)) / 2
	local top = gy + (gh - (rows * tile + (rows - 1) * tileGap)) / 2
	for i, entry in spec.tiles do
		local col, row = (i - 1) % cols, (i - 1) // cols
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.ZIndex = 6
		Chunky.put(
			sheet,
			holder,
			left + col * (tile + tileGap),
			top + row * (tile + tileGap),
			tile,
			tile
		)
		Chunky.tile(
			holder,
			entry.rarity,
			entry.icon,
			odds(entry.chance),
			entry.silhouette == true or spec.locked ~= nil,
			entry.owned,
			entry.key
		)
	end

	if spec.locked then
		local veil = Instance.new("Frame")
		veil.BorderSizePixel = 0
		veil.BackgroundColor3 = Chunky.navy
		veil.BackgroundTransparency = 0.35
		veil.ZIndex = 20
		Chunky.put(sheet, veil, kx + 10, gy, kw - 20, gh)
		Chunky.round(veil, 20)
		local lock = Kit.image(sheet.canvas, ShopAssets.lock)
		Chunky.put(sheet, lock, kx + kw / 2 - 70, gy + gh / 2 - 130, 140, 122)
		lock.ZIndex = 22
		words(sheet, spec.locked, kx + 40, gy + gh / 2 + 10, kw - 80, 70, Chunky.gold, 5).ZIndex =
			23
	end

	-- the tally and the guaranteed Mythic along the card's foot
	local left2 = math.max(1, Pity.EVERY - spec.pity)
	local tally =
		words(sheet, `{held} {spec.noun}`, kx + 30, ky + kh - 112, kw - 60, 44, Chunky.navy, 0)
	tally.TextXAlignment = Enum.TextXAlignment.Left
	local line = words(
		sheet,
		if left2 == 1 then "NEXT ONE IS A MYTHIC!" else `MYTHIC IN {left2}`,
		kx + 30,
		ky + kh - 112,
		kw - 60,
		44,
		Chunky.purple,
		0
	)
	line.Name = "PityLine"
	line.TextXAlignment = Enum.TextXAlignment.Right
	Chunky.bar(
		sheet,
		spec.pity / Pity.EVERY,
		Chunky.purple,
		kx + 30,
		ky + kh - 60,
		kw - 60,
		34,
		true
	)
end

--[[ AUTO, the keys and the STOP button for a stand screen. `active` says
     whether the stand is showing (a screen may have other tabs). ]]
function HatchStand.controller(
	s: StationScreen.Screen,
	counts: { number },
	press: (number) -> (),
	affordable: (number) -> boolean,
	active: () -> boolean
): Controller
	local control: Controller = { auto = false, toggle = function() end }
	control.toggle = function()
		control.auto = not control.auto and affordable(counts[1])
		if s.isOpen() and not Reveal.busy() then
			s.open()
		end
	end
	local openedAt = 0
	local dim = s.canvas.Parent :: GuiObject
	s.connect(dim:GetPropertyChangedSignal("Visible"), function()
		openedAt = os.clock()
		if not dim.Visible then
			control.auto = false
		end
	end)
	-- STOP, over the reveals (bottom left, as the reference's)
	local stopLayer = Instance.new("ScreenGui")
	stopLayer.Name = "AutoHatch"
	stopLayer.IgnoreGuiInset = true
	stopLayer.ResetOnSpawn = false
	stopLayer.DisplayOrder = 190
	stopLayer.Enabled = false
	stopLayer.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local stopCanvas = Kit.canvas(stopLayer)
	local autoLabel = Kit.label(stopCanvas, "AUTO", Kit.white)
	Kit.put(autoLabel, 24, 788, 320, 48)
	local stop = Kit.button(stopCanvas, "STOP", Color3.fromRGB(230, 60, 50), function()
		control.auto = false
		if s.isOpen() and not Reveal.busy() then
			s.open()
		end
	end)
	Kit.put(stop, 64, 844, 220, 172)
	s.gui.Destroying:Once(function()
		stopLayer:Destroy()
	end)
	s.connect(UserInputService.InputBegan, function(input, processed)
		if
			processed
			or not s.isOpen()
			or not active()
			or os.clock() - openedAt < 0.3
			or Reveal.busy()
		then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			press(counts[1])
		elseif input.KeyCode == Enum.KeyCode.R then
			press(counts[#counts])
		elseif input.KeyCode == Enum.KeyCode.T then
			control.toggle()
		end
	end)
	local wasBusy = false
	s.connect(RunService.RenderStepped, function()
		local busy = Reveal.busy()
		-- the reveal plays over the backdrop itself, the stand out of the way
		s.canvas.Visible = not busy
		stopLayer.Enabled = control.auto and s.isOpen()
		if control.auto and s.isOpen() and active() and not busy then
			-- as many at once as the coins allow
			local count = if affordable(counts[#counts]) then counts[#counts] else counts[1]
			if affordable(count) then
				press(count)
			else
				control.auto = false
				s.open()
			end
		elseif wasBusy and not busy and s.isOpen() then
			s.open()
		end
		wasBusy = busy
	end)
	return control
end

return HatchStand
