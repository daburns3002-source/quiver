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
	moss: boolean,
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

-- A round key prompt: the key in a white circle, its words above.
local function prompt(
	c: Frame,
	x: number,
	y: number,
	key: string,
	words: string,
	can: boolean,
	action: () -> ()
)
	local over = Kit.label(c, words, if can then Kit.white else Color3.fromRGB(150, 150, 150))
	Kit.put(over, x - 200, y - 112, 400, 52)
	local circle = Instance.new("Frame")
	circle.BackgroundColor3 = if can then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
	circle.Parent = c
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = circle
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(40, 40, 48)
	edge.Thickness = 4
	edge.Parent = circle
	Kit.put(circle, x - 52, y - 52, 104, 104)
	local letter = Kit.label(circle, if keys then key else "TAP", Color3.fromRGB(40, 40, 48))
	letter.Position, letter.Size = UDim2.fromScale(0.15, 0.2), UDim2.fromScale(0.7, 0.6)
	Kit.clickArea(circle, action)
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
	-- the name over its card
	local title = Kit.label(c, spec.title)
	Kit.put(title, 120, 150, 860, 84)
	--[[ The card wraps whatever the pool is: an egg holds eight, the Mossy
	     Glade crate twelve, and a later area may hold another number again,
	     so the grid is measured rather than laid out by hand. ]]
	local held = #spec.tiles
	local perRow = if held > 6 then 4 else 3
	local gap = 14
	local wide = (820 - (perRow - 1) * gap) // perRow
	local rows = math.max(math.ceil(held / perRow), 1)
	--[[ Rows share the room between the top strip and the pity bar, and a
	     card never grows past the width of its own column. ]]
	local tall = math.min(math.floor((360 - (rows - 1) * gap) / rows), wide)
	local bottom = 340 + rows * tall + (rows - 1) * gap
	local card = Kit.panel(c, Color3.new(1, 1, 1))
	Kit.put(card, 120, 240, 860, bottom + 130 - 240)
	-- the top row: price, picker, AUTO
	local price = Kit.panel(c, Kit.gold)
	Kit.pill(price)
	Kit.put(price, 140, 258, 228, 66)
	local coin = Kit.image(price, ShopAssets.coin)
	coin.Position, coin.Size = UDim2.fromScale(0.06, 0.12), UDim2.fromScale(0.26, 0.76)
	local cost = Kit.label(price, HatchStand.commas(spec.price))
	cost.Position, cost.Size = UDim2.fromScale(0.34, 0.2), UDim2.fromScale(0.6, 0.6)
	local picker = Kit.button(c, "< " .. spec.picker .. " >", Kit.slate, function()
		if not Reveal.busy() then
			control.auto = false
			spec.onPick()
		end
	end)
	Kit.put(picker, 384, 258, 400, 66)
	local toggle = Kit.button(
		c,
		"AUTO" .. (if keys then " [T]" else ""),
		if control.auto then Kit.green else Kit.slate,
		control.toggle
	)
	Kit.put(toggle, 800, 258, 160, 66)
	--[[ What is inside, rarest last: one full-colour card each, laid out as
	     Codex's screens do (owner, 2026-10-31: "codex made a good one a
	     couple days ago that i want to use") -- the chance in the corner of
	     the card rather than on a band under it. ]]
	for i, entry in spec.tiles do
		local col, row = (i - 1) % perRow, (i - 1) // perRow
		local tile = Kit.nativeTile(c, entry.rarity, entry.icon, spec.locked ~= nil, true)
		Kit.put(tile, 140 + col * (wide + gap), 340 + row * (tall + gap), wide, tall)
		--[[ A silhouette keeps its card's colour: `nativeTile`'s own locked
		     look greys the whole card, which would lose the rarity. ]]
		if entry.silhouette then
			for _, child in tile:GetChildren() do
				if child:IsA("ImageLabel") and child.Image == entry.icon then
					child.ImageColor3 = Color3.new(0, 0, 0)
				end
			end
		end
		local odds = Kit.label(tile, string.format("%g%%", math.round(entry.chance * 10000) / 100))
		odds.Position, odds.Size = UDim2.fromScale(0.36, 0.7), UDim2.fromScale(0.58, 0.24)
		odds.TextXAlignment = Enum.TextXAlignment.Right
		odds.ZIndex = 6
		if entry.owned then
			Kit.owned(tile)
		end
	end
	-- how many are in there, under the cards, as Codex's screens say it
	local tally = Kit.label(c, `{held} {spec.noun}`, Kit.white)
	Kit.put(tally, 140, bottom + 8, 820, 32)
	if spec.locked then
		local lock = Kit.image(c, ShopAssets.lock)
		Kit.put(lock, 490, 380, 120, 140)
		local why = Kit.label(c, spec.locked, Kit.gold)
		Kit.put(why, 160, 540, 780, 56)
	end
	-- the pity bar: a rainbow filling towards the guaranteed Mythic
	local track = Kit.panel(c, Color3.fromRGB(60, 60, 72))
	Kit.pill(track)
	Kit.put(track, 140, bottom + 46, 820, 60)
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Size = UDim2.fromScale(math.clamp(spec.pity / Pity.EVERY, 0.04, 1), 1)
	fill.Parent = track
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = fill
	local colours = {}
	for n = 0, 6 do
		table.insert(colours, ColorSequenceKeypoint.new(n / 6, Color3.fromHSV(n / 7, 0.75, 1)))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colours)
	gradient.Parent = fill
	Kit.pityLine(c, spec.pity, 140, bottom + 48, 820, 54)
	-- the egg or crate on its stand, its prompts beside it
	Kit.stage(c, 1120, 860, 520, spec.moss)
	local icon = Kit.image(c, spec.picture, spec.locked ~= nil)
	Kit.put(icon, 1150, 300, 460, 560)
	Kit.animate(icon, function(t)
		icon.Position = UDim2.fromScale(1150 / 1920, (300 + math.sin(t * 1.8) * 8) / 1080)
	end)
	for i, count in spec.counts do
		prompt(
			c,
			1760,
			420 + (i - 1) * 300,
			if i == 1 then "E" else "R",
			spec.verb .. " " .. tostring(count) .. " " .. HatchStand.commas(spec.price * count),
			affordable(count),
			function()
				press(count)
			end
		)
	end
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
