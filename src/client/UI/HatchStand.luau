--!strict
--[[
	Tap Simulator Reborn's egg stand (owner, 2026-10-27: "replicated exactly
	1 to 1"; docs/EGG-HATCH-REFERENCE.md), shared by the Egg Hatchery and the
	Blacksmith's crates (owner, 2026-10-27: the weapon chests "changed exactly
	how you are changing the pets and with the same ui"): the name over a
	white card holding the price, the picker and the AUTO toggle, what is
	inside with its odds and the pity bar; the egg or crate beside it with
	its key prompts, E for one and R for three (T toggles AUTO).

	`controller` runs AUTO for a screen: presses follow one another until
	STOP, the screen closes or the coins run out; the stand hides while a
	reveal plays over the backdrop.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Kit = require(script.Parent.Kit)
local Pity = require(ReplicatedStorage.Shared.Util.Pity)
local Reveal = require(script.Parent.Reveal)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local StationScreen = require(script.Parent.StationScreen)
local HatchStand = {}

export type Tile = {
	rarity: string,
	icon: string,
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
	--[[ The press counts (1 and 3) and the word on their prompts. ]]
	counts: { number },
	verb: string,
	--[[ What the cards hold, for the line under them: "PETS", "WEAPONS". ]]
	noun: string,
}
export type Controller = {
	auto: boolean,
	toggle: () -> (),
}

local keys = UserInputService.KeyboardEnabled

function HatchStand.commas(n: number): string
	local text = tostring(n)
	repeat
		local formatted, changes = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = formatted
	until changes == 0
	return text
end

--[[
	Codex's grid. He drew the hatchery at 1200x720 and `UI/Kit` lays out
	against 1920x1080, which is the same shape at 1.5x with 60 pixels of
	margin each side, so every number below is one of his own, untouched.
]]
local function at(item: GuiObject, x: number, y: number, w: number, h: number)
	Kit.put(item, 60 + x * 1.5, y * 1.5, w * 1.5, h * 1.5)
end

--[[ A frame of nothing, to hang a pixel panel and its words on. ]]
local function slot(c: Frame, x: number, y: number, w: number, h: number): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Parent = c
	at(holder, x, y, w, h)
	return holder
end

--[[ One of Codex's key prompts: a leaf-green pixel panel with the key in
     it and what it does underneath. Greyed when it cannot be afforded, and
     still pressable, so a player who cannot pay is told rather than
     ignored. ]]
local function prompt(
	c: Frame,
	x: number,
	y: number,
	w: number,
	h: number,
	key: string,
	words: string,
	can: boolean,
	action: () -> ()
)
	local holder = slot(c, x, y, w, h)
	local face = if can then Kit.pixelLeaf else Color3.fromRGB(120, 130, 120)
	local panel = Kit.pixelPanel(holder, w * 1.5, h * 1.5, face)
	local letter = Kit.pixelText(panel, if keys then key else "TAP", 54, Color3.new(1, 1, 1))
	letter.Position, letter.Size = UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.8, 0.48)
	letter.ZIndex = 11
	local cost = Kit.pixelText(panel, words, 22, Color3.fromRGB(229, 255, 184))
	cost.Position, cost.Size = UDim2.fromScale(0.06, 0.6), UDim2.fromScale(0.88, 0.28)
	cost.ZIndex = 11
	Kit.clickArea(holder, action)
end

--[[ Draws the stand onto `s`'s canvas; `press(count)` asks the server,
     `affordable(count)` says whether it may. ]]
function HatchStand.draw(
	s: StationScreen.Screen,
	spec: Spec,
	control: Controller,
	press: (number) -> (),
	affordable: (number) -> boolean
)
	local c = s.canvas

	--[[ The name across the top, which is also the picker: Codex drew one
	     egg and so had no need of one, and folding the arrows into his
	     title costs the layout nothing. ]]
	local titleBox = slot(c, 40, 4, 1120, 92)
	local title = Kit.pixelText(titleBox, `< {spec.title} >`, 74)
	title.ZIndex = 12
	Kit.clickArea(titleBox, function()
		if not Reveal.busy() then
			control.auto = false
			spec.onPick()
		end
	end)

	--[[ The odds panel, where Codex put it: forest green, with the area's
	     own scene washed in behind the cards so it is not an empty box. ]]
	local panelHolder = slot(c, 520, 110, 660, 552)
	Kit.pixelPanel(panelHolder, 990, 828, Kit.pixelForest)
	if spec.backdrop ~= "" then
		local scene = Kit.image(panelHolder, spec.backdrop)
		scene.Position, scene.Size = UDim2.fromScale(0.02, 0.03), UDim2.fromScale(0.96, 0.94)
		scene.ScaleType = Enum.ScaleType.Crop
		scene.ImageTransparency = 0.38
		scene.ZIndex = 4
	end

	-- the price, in his cream pill in the panel's top corner
	local priceHolder = slot(c, 536, 122, 190, 58)
	Kit.pixelPanel(priceHolder, 285, 87, Kit.pixelCream)
	local coin = Kit.image(priceHolder, ShopAssets.coin)
	coin.Position, coin.Size = UDim2.fromScale(0.06, 0.16), UDim2.fromScale(0.22, 0.68)
	coin.ZIndex = 10
	local cost =
		Kit.pixelText(priceHolder, HatchStand.commas(spec.price), 30, Color3.fromRGB(255, 213, 44))
	cost.Position, cost.Size = UDim2.fromScale(0.3, 0.2), UDim2.fromScale(0.64, 0.6)
	cost.ZIndex = 11

	--[[ What is inside, on Codex's cards. The grid measures itself: an egg
	     holds eight and a crate twelve, and a later area may hold another
	     number again. ]]
	local held = #spec.tiles
	local perRow = if held > 6 then 4 else 3
	local gap = 10
	local wide = (628 - (perRow - 1) * gap) // perRow
	local rows = math.max(math.ceil(held / perRow), 1)
	local tall = math.min((364 - (rows - 1) * gap) // rows, wide)
	for i, entry in spec.tiles do
		local col, row = (i - 1) % perRow, (i - 1) // perRow
		local tile = Kit.nativeTile(c, entry.rarity, entry.icon, spec.locked ~= nil, true)
		at(tile, 536 + col * (wide + gap), 196 + row * (tall + gap), wide, tall)
		tile.ZIndex = 8
		--[[ A silhouette keeps its card's colour: `nativeTile`'s own locked
		     look greys the whole card, which would lose the rarity. ]]
		if entry.silhouette then
			for _, child in tile:GetChildren() do
				if child:IsA("ImageLabel") and child.Image == entry.icon then
					child.ImageColor3 = Color3.new(0, 0, 0)
				end
			end
		end
		local odds =
			Kit.pixelText(tile, string.format("%g%%", math.round(entry.chance * 10000) / 100), 18)
		odds.Position, odds.Size = UDim2.fromScale(0.08, 0.74), UDim2.fromScale(0.84, 0.2)
		odds.ZIndex = 12
		if entry.owned then
			Kit.owned(tile)
		end
	end

	-- how many are in there, then the pity bar, both inside the panel
	local tallyBox = slot(c, 536, 566, 628, 26)
	local tally = Kit.pixelText(tallyBox, `{held} {spec.noun}`, 22)
	tally.ZIndex = 11

	local track = Instance.new("Frame")
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Color3.fromRGB(14, 34, 25)
	track.ZIndex = 8
	track.Parent = c
	at(track, 536, 598, 628, 40)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = track
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Size = UDim2.fromScale(math.clamp(spec.pity / Pity.EVERY, 0.04, 1), 1)
	fill.ZIndex = 9
	fill.Parent = track
	local curve = Instance.new("UICorner")
	curve.CornerRadius = UDim.new(0.5, 0)
	curve.Parent = fill
	local colours = {}
	for n = 0, 6 do
		table.insert(colours, ColorSequenceKeypoint.new(n / 6, Color3.fromHSV(n / 7, 0.75, 1)))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colours)
	gradient.Parent = fill
	Kit.pityLine(c, spec.pity, 60 + 536 * 1.5, 599 * 1.5, 628 * 1.5, 38 * 1.5)

	--[[ Codex's left column is the action side: his single E prompt sat
	     here under the word Hatch. The egg or crate stands where that word
	     was, with both prompts and AUTO under it. ]]
	local icon = Kit.image(c, spec.picture, spec.locked ~= nil)
	at(icon, 110, 116, 320, 290)
	Kit.animate(icon, function(t)
		at(icon, 110, 116 + math.sin(t * 1.8) * 5, 320, 290)
	end)

	if spec.locked then
		local lock = Kit.image(c, ShopAssets.lock)
		at(lock, 790, 200, 120, 104)
		lock.ZIndex = 14
		local whyBox = slot(c, 620, 320, 460, 54)
		local why = Kit.pixelText(whyBox, spec.locked, 34, Color3.fromRGB(255, 213, 44))
		why.ZIndex = 14
	end

	for i, count in spec.counts do
		prompt(
			c,
			if i == 1 then 60 else 280,
			428,
			180,
			134,
			if i == 1 then "E" else "R",
			`{spec.verb} {count}`,
			affordable(count),
			function()
				press(count)
			end
		)
	end

	local autoHolder = slot(c, 60, 584, 400, 64)
	Kit.pixelPanel(
		autoHolder,
		600,
		96,
		if control.auto then Kit.pixelLeaf else Color3.fromRGB(90, 110, 95)
	)
	local autoWords = Kit.pixelText(autoHolder, "AUTO" .. (if keys then " [T]" else ""), 30)
	autoWords.Position, autoWords.Size = UDim2.fromScale(0.08, 0.24), UDim2.fromScale(0.84, 0.52)
	autoWords.ZIndex = 11
	Kit.clickArea(autoHolder, control.toggle)
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
	local words = Kit.label(stopCanvas, "AUTO", Kit.white)
	Kit.put(words, 24, 788, 320, 48)
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
