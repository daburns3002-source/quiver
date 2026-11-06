--!strict
--[[
	The chunky UI kit (owner, 2026-11-05: "WE NEED TO DO SEVERE WORK ON THE
	UI FOR EVERYTHING"; approved style: assets/concepts/ui_refs/mockups/
	style_sheet.jpg, "i like this style a lot").

	What the top Roblox games do (assets/concepts/ui_refs/README.md): royal
	blue panels with a thick navy outline and a lighter rim, white row cards,
	a gold ribbon title over the panel's top edge, a red X off its corner,
	fat glossy buttons with a dark lip (green buy, gold primary, blue
	secondary, red close, purple gems), one bold rounded font in white with
	a navy stroke, currency as an icon overlapping a dark pill, rarity
	frames with Legendary glowing gold and Mythic turning rainbow.

	Layout is in sheet pixels: `Chunky.sheet` makes the station canvas
	1920 x 1080 (landscape) or 1080 x 1920 (a phone held upright), and every
	piece is placed and outlined in those pixels, so a stroke stays as thick
	as the mockup's at any screen size.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Kit = require(script.Parent.Kit)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local Chunky = {}

Chunky.font = Enum.Font.FredokaOne
Chunky.navy = Color3.fromRGB(26, 24, 66)
Chunky.ink = Color3.fromRGB(38, 44, 92)
Chunky.white = Color3.fromRGB(250, 251, 255)
Chunky.green = Color3.fromRGB(88, 214, 62)
Chunky.gold = Color3.fromRGB(255, 196, 38)
Chunky.blue = Color3.fromRGB(66, 146, 255)
Chunky.red = Color3.fromRGB(240, 66, 72)
Chunky.purple = Color3.fromRGB(168, 86, 255)
Chunky.grey = Color3.fromRGB(150, 160, 178)
Chunky.panelTop = Color3.fromRGB(70, 128, 240)
Chunky.panelBottom = Color3.fromRGB(34, 70, 186)

--[[ The six rarity frames, as the style sheet draws them. ]]
Chunky.rarity = {
	Common = Color3.fromRGB(160, 170, 186),
	Uncommon = Color3.fromRGB(70, 200, 80),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(168, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 30),
	Mythic = Color3.fromRGB(255, 70, 150),
}

export type Sheet = { canvas: Frame, w: number, h: number, upright: boolean }

--[[ Shapes the station canvas for the screen it is on and returns the sheet
     to lay out against: upright when the screen is taller than wide. ]]
function Chunky.sheet(canvas: Frame): Sheet
	local holder = canvas.Parent :: GuiObject
	local upright = holder.AbsoluteSize.Y > holder.AbsoluteSize.X
	local w, h = if upright then 1080 else 1920, if upright then 1920 else 1080
	local aspect = canvas:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then
		aspect.AspectRatio = w / h
	end
	canvas:SetAttribute("SheetW", w)
	return { canvas = canvas, w = w, h = h, upright = upright }
end

--[[ Places `item` on the sheet, in sheet pixels. ]]
function Chunky.put(sheet: Sheet, item: GuiObject, x: number, y: number, w: number, h: number)
	item.Position = UDim2.fromScale(x / sheet.w, y / sheet.h)
	item.Size = UDim2.fromScale(w / sheet.w, h / sheet.h)
	item.Parent = sheet.canvas
end

--[[ Calls `apply(unit)` now and whenever the canvas resizes, where `unit`
     is screen pixels per sheet pixel. ]]
local function scaled(item: Instance, apply: (number) -> ())
	local canvas: Instance? = item
	while canvas and not (canvas:IsA("Frame") and canvas:GetAttribute("SheetW")) do
		canvas = canvas.Parent
	end
	if not canvas then
		apply(0.5)
		return
	end
	local frame = canvas :: Frame
	local function update()
		local sheetW = frame:GetAttribute("SheetW")
		apply(frame.AbsoluteSize.X / (if type(sheetW) == "number" then sheetW else 1920))
	end
	local changed = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	item.Destroying:Once(function()
		changed:Disconnect()
	end)
	update()
end

--[[ A navy (or `colour`) outline `px` sheet pixels thick. ]]
function Chunky.outline(item: GuiObject, px: number, colour: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = colour or Chunky.navy
	stroke.Parent = item
	scaled(item, function(unit)
		stroke.Thickness = math.max(1, px * unit)
	end)
	return stroke
end

--[[ Corners `px` sheet pixels round. ]]
function Chunky.round(item: GuiObject, px: number)
	local corner = Instance.new("UICorner")
	corner.Parent = item
	scaled(item, function(unit)
		corner.CornerRadius = UDim.new(0, px * unit)
	end)
end

local function gradient(item: GuiObject, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = item
end

local function fill(parent: Instance, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = parent
	return f
end

--[[ Words in the one font: white with a thick navy stroke unless told
     otherwise, filling their box. ]]
function Chunky.text(
	parent: Instance,
	words: string,
	colour: Color3?,
	strokePx: number?,
	strokeColour: Color3?
): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Chunky.font
	t.Text = words
	t.TextScaled = true
	t.TextColor3 = colour or Chunky.white
	t.Size = UDim2.fromScale(1, 1)
	t.ZIndex = 30
	t.Parent = parent
	local px = strokePx or 4
	if px > 0 then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Color = strokeColour or Chunky.navy
		stroke.Parent = t
		scaled(t, function(unit)
			stroke.Thickness = math.max(1, px * unit)
		end)
	end
	return t
end

--[[ The big blue panel: navy outline, lit from the top, a lighter rim just
     inside its edge. ]]
function Chunky.panel(sheet: Sheet, x: number, y: number, w: number, h: number): Frame
	local p = Instance.new("Frame")
	p.Name = "ChunkyPanel"
	p.BorderSizePixel = 0
	p.BackgroundColor3 = Color3.new(1, 1, 1)
	p.ZIndex = 2
	Chunky.put(sheet, p, x, y, w, h)
	gradient(p, Chunky.panelTop, Chunky.panelBottom)
	Chunky.round(p, 34)
	Chunky.outline(p, 7)
	local rim = Instance.new("Frame")
	rim.BackgroundTransparency = 1
	rim.Position = UDim2.fromScale(8 / w, 8 / h)
	rim.Size = UDim2.fromScale(1 - 16 / w, 1 - 16 / h)
	rim.ZIndex = 2
	rim.Parent = p
	Chunky.round(rim, 28)
	Chunky.outline(rim, 3, Color3.fromRGB(130, 186, 255))
	return p
end

--[[ A white card inside a panel. ]]
function Chunky.card(sheet: Sheet, x: number, y: number, w: number, h: number): Frame
	local c = Instance.new("Frame")
	c.Name = "ChunkyCard"
	c.BorderSizePixel = 0
	c.BackgroundColor3 = Color3.new(1, 1, 1)
	c.ZIndex = 4
	Chunky.put(sheet, c, x, y, w, h)
	gradient(c, Chunky.white, Color3.fromRGB(222, 230, 248))
	Chunky.round(c, 24)
	Chunky.outline(c, 5)
	return c
end

--[[ The gold ribbon that carries a screen's title over the panel's top
     edge, its two tails folded behind. ]]
function Chunky.ribbon(sheet: Sheet, words: string, x: number, y: number, w: number, h: number)
	local holder = Instance.new("Frame")
	holder.Name = "Ribbon"
	holder.BackgroundTransparency = 1
	holder.ZIndex = 20
	Chunky.put(sheet, holder, x, y, w, h)
	for side = -1, 1, 2 do
		local tail = fill(holder, Color3.new(1, 1, 1), 19)
		tail.AnchorPoint = Vector2.new(0.5, 0.5)
		tail.Position = UDim2.fromScale(0.5 + side * 0.47, 0.62)
		tail.Size = UDim2.fromScale(0.14, 0.62)
		tail.Rotation = side * -8
		gradient(tail, Color3.fromRGB(236, 160, 24), Color3.fromRGB(196, 112, 16))
		Chunky.round(tail, 10)
		Chunky.outline(tail, 6)
	end
	local band = fill(holder, Color3.new(1, 1, 1), 21)
	band.Position, band.Size = UDim2.fromScale(0.06, 0.08), UDim2.fromScale(0.88, 0.84)
	gradient(band, Color3.fromRGB(255, 222, 70), Color3.fromRGB(246, 160, 24))
	Chunky.round(band, 18)
	Chunky.outline(band, 7)
	local shine = fill(band, Color3.new(1, 1, 1), 22)
	shine.BackgroundTransparency = 0.6
	shine.Position, shine.Size = UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.3)
	Chunky.round(shine, 12)
	local t = Chunky.text(band, words, nil, 6)
	t.Position, t.Size = UDim2.fromScale(0.06, 0.14), UDim2.fromScale(0.88, 0.74)
end

--[[ Squash on press, swell a touch on hover; and the click itself. ]]
local function pressable(holder: GuiObject, visual: GuiObject, action: () -> ())
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 40
	hit.Parent = holder
	hit.Activated:Connect(action)
	Kit.pressFx(hit, visual, false)
end

--[[ A fat glossy button: a darker lip under a face lit from the top, a gloss
     strip across its upper half, the words (and an icon) in white. ]]
function Chunky.button(
	sheet: Sheet,
	words: string,
	colour: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	action: () -> (),
	icon: string?
): Frame
	local holder = Instance.new("Frame")
	holder.Name = "ChunkyButton"
	holder.BackgroundTransparency = 1
	holder.ZIndex = 10
	Chunky.put(sheet, holder, x, y, w, h)
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.ZIndex = 10
	body.Parent = holder
	local lip = fill(body, colour:Lerp(Color3.new(0, 0, 0), 0.42), 10)
	lip.Position, lip.Size = UDim2.fromScale(0, 0.1), UDim2.fromScale(1, 0.9)
	Chunky.round(lip, math.min(26, h * 0.3))
	Chunky.outline(lip, 6)
	local face = fill(body, Color3.new(1, 1, 1), 11)
	face.Size = UDim2.fromScale(1, 0.88)
	gradient(face, colour:Lerp(Color3.new(1, 1, 1), 0.28), colour)
	Chunky.round(face, math.min(26, h * 0.3))
	Chunky.outline(face, 6)
	local gloss = fill(face, Color3.new(1, 1, 1), 12)
	gloss.BackgroundTransparency = 0.55
	gloss.Position, gloss.Size = UDim2.fromScale(0.06, 0.1), UDim2.fromScale(0.88, 0.32)
	Chunky.round(gloss, math.min(14, h * 0.16))
	local left = 0.08
	if icon and icon ~= "" then
		local picture = Kit.image(face, icon)
		picture.Position, picture.Size = UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.3, 0.76)
		picture.ZIndex = 13
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = picture
		left = 0.3
	end
	local t = Chunky.text(face, words, nil, 5)
	t.Position, t.Size = UDim2.fromScale(left, 0.18), UDim2.fromScale(0.92 - left, 0.62)
	pressable(holder, body, action)
	return holder
end

--[[ The red square X that hangs off a panel's top-right corner. ]]
function Chunky.close(sheet: Sheet, x: number, y: number, size: number, action: () -> ())
	local b = Chunky.button(sheet, "X", Chunky.red, x, y, size, size, action)
	b.Name = "Close"
	b.ZIndex = 30
	for _, d in b:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 20
		end
	end
end

--[[ A tab: raised and bright when chosen, sunk and dull when not. ]]
function Chunky.tab(
	sheet: Sheet,
	words: string,
	colour: Color3,
	on: boolean,
	x: number,
	y: number,
	w: number,
	h: number,
	action: () -> ()
): Frame
	local tone = if on then colour else colour:Lerp(Chunky.navy, 0.45)
	local b = Chunky.button(sheet, words, tone, x, if on then y else y + h * 0.08, w, h, action)
	if not on then
		b.Size = UDim2.fromScale(w / sheet.w, h * 0.92 / sheet.h)
	end
	return b
end

--[[ A currency: its icon, larger than the dark pill and overlapping the
     pill's left end, and the amount. ]]
function Chunky.pill(
	sheet: Sheet,
	icon: string,
	amount: string,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3?
): Frame
	local holder = Instance.new("Frame")
	holder.Name = "ChunkyWallet"
	holder.BackgroundTransparency = 1
	holder.ZIndex = 20
	Chunky.put(sheet, holder, x, y, w, h)
	local pill = fill(holder, Color3.fromRGB(28, 34, 78), 20)
	pill.BackgroundTransparency = 0.08
	pill.Position, pill.Size =
		UDim2.fromScale(h * 0.45 / w, 0.14), UDim2.fromScale(1 - h * 0.45 / w, 0.72)
	Chunky.round(pill, h)
	Chunky.outline(pill, 5)
	local picture = Kit.image(holder, icon)
	picture.Position, picture.Size = UDim2.fromScale(0, 0), UDim2.fromScale(h / w, 1)
	picture.ZIndex = 22
	local t = Chunky.text(pill, amount, colour, 4)
	t.Position, t.Size = UDim2.fromScale(0.36, 0.14), UDim2.fromScale(0.58, 0.72)
	t.TextXAlignment = Enum.TextXAlignment.Left
	return holder
end

--[[ The player's coins and gems. ]]
function Chunky.wallet(sheet: Sheet, coins: number, gems: number, x: number, y: number, h: number)
	Chunky.pill(sheet, ShopAssets.coin, Chunky.commas(coins), x, y, h * 3.4, h)
	Chunky.pill(sheet, ShopAssets.gem, Chunky.commas(gems), x + h * 3.6, y, h * 2.8, h)
end

function Chunky.commas(n: number): string
	local text = tostring(math.floor(n))
	repeat
		local formatted, changes = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = formatted
	until changes == 0
	return text
end

--[[ A progress bar: a dark trough with a lit fill. `rainbow` turns it into
     the pity bar's spectrum. ]]
function Chunky.bar(
	sheet: Sheet,
	fraction: number,
	colour: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	rainbow: boolean?
): Frame
	local trough = Instance.new("Frame")
	trough.BorderSizePixel = 0
	trough.BackgroundColor3 = Color3.fromRGB(30, 40, 90)
	trough.ZIndex = 8
	Chunky.put(sheet, trough, x, y, w, h)
	Chunky.round(trough, h)
	Chunky.outline(trough, 4)
	local f = fill(trough, Color3.new(1, 1, 1), 9)
	f.Size = UDim2.fromScale(math.clamp(fraction, 0.03, 1), 1)
	Chunky.round(f, h)
	if rainbow then
		local stops = {}
		for n = 0, 6 do
			table.insert(stops, ColorSequenceKeypoint.new(n / 6, Color3.fromHSV(n / 7, 0.7, 1)))
		end
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(stops)
		g.Parent = f
	else
		gradient(f, colour:Lerp(Color3.new(1, 1, 1), 0.3), colour)
	end
	return trough
end

--[[
	One item in its rarity's frame, as the style sheet's tiles: a pale wash
	of the rarity's colour under the picture (or the pet standing as its
	model), a thick frame in the colour, a small caption along the bottom
	(the odds, a level). Legendary glows gold and Mythic's frame turns
	rainbow with a glow (owner's standing rule). `hidden` draws it black.
]]
function Chunky.tile(
	parent: GuiObject,
	rarity: string,
	art: string,
	caption: string?,
	hidden: boolean?,
	owned: boolean?,
	key: string?
): Frame
	local tone = Chunky.rarity[rarity] or Chunky.grey
	local t = fill(parent, Color3.new(1, 1, 1), 6)
	t.Name = "ChunkyTile"
	gradient(t, tone:Lerp(Color3.new(1, 1, 1), 0.72), tone:Lerp(Color3.new(1, 1, 1), 0.38))
	Chunky.round(t, 18)
	local edge = Chunky.outline(t, 6, tone:Lerp(Chunky.navy, 0.15))
	local standing = if key then Kit.petModel(t, key, hidden == true) else nil
	if standing then
		standing.Position, standing.Size = UDim2.fromScale(0.04, 0.02), UDim2.fromScale(0.92, 0.8)
		standing.ZIndex = 8
	elseif art ~= "" then
		local picture = Kit.image(t, art)
		picture.Position, picture.Size = UDim2.fromScale(0.1, 0.06), UDim2.fromScale(0.8, 0.68)
		picture.ZIndex = 8
		if hidden then
			picture.ImageColor3 = Color3.new(0, 0, 0)
		end
	end
	if caption then
		local c = Chunky.text(t, caption, nil, 4)
		c.Position, c.Size = UDim2.fromScale(0.06, 0.74), UDim2.fromScale(0.88, 0.22)
		c.ZIndex = 12
	end
	if rarity == "Legendary" or rarity == "Mythic" then
		for ring, spread in { 12, 7, 3 } do
			local halo = Instance.new("Frame")
			halo.BackgroundTransparency = 1
			halo.Size = UDim2.fromScale(1, 1)
			halo.ZIndex = 5
			halo.Parent = t
			Chunky.round(halo, 18)
			local glow = Chunky.outline(halo, spread * 2 + 6, tone)
			glow.Transparency = ({ 0.88, 0.72, 0.45 })[ring]
		end
	end
	if rarity == "Mythic" then
		edge:Destroy()
		Kit.rainbowRing(t)
		local ring = t:FindFirstChildOfClass("UIStroke")
		if ring then
			scaled(t, function(unit)
				ring.Thickness = math.max(2, 7 * unit)
			end)
		end
	end
	if owned then
		Kit.owned(t)
	end
	return t
end

--[[ Pops a freshly opened panel in: from a little small, past full size,
     back to rest. ]]
function Chunky.pop(item: GuiObject)
	local scale = item:FindFirstChild("PopScale") :: UIScale? or Instance.new("UIScale")
	scale.Name = "PopScale"
	scale.Scale = 0.82
	scale.Parent = item
	TweenService:Create(
		scale,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

return Chunky
