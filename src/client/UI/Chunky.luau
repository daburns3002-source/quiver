--!strict
--[[
	The chunky UI kit (owner, 2026-11-05: "WE NEED TO DO SEVERE WORK ON THE
	UI FOR EVERYTHING").

	**Its look is the owner's major reference of 2026-11-11** ("use this as
	the major reference image": a house-tycoon game's store screen), which
	replaced the royal-blue panels of the first pass:

	- a cream panel with a thick dark-brown outline and modest corners, an
	  orange header bar across its top with soft diagonal stripes, the
	  title at the bar's left and a red hexagon X at its right;
	- buttons that are rounded rectangles with the same diagonal stripes,
	  outlined in a darker shade of their own colour (green buy, gold
	  primary, orange action, blue secondary, red danger, purple gems) over
	  a darker lip, the words in white with that dark shade as their stroke;
	- item tiles filled with their colour, not washed out, and outlined in
	  its dark shade; white row cards on the cream;
	- currency as an icon on a cream pill with the amount in the currency's
	  colour;
	- one bold rounded font: white with a dark stroke on anything coloured,
	  `Chunky.ink` brown and unstroked on cream and white;
	- **effects** (owner, the same day: "make sure there are effects as
	  well, the top games have effects"): panels pop in, every button
	  swells under the pointer, squashes when pressed, clicks and throws a
	  few sparks, primary buttons carry a shine that sweeps across, and
	  `Chunky.twinkle` puts blinking sparkles on whatever is selected or new.

	Layout is in sheet pixels: `Chunky.sheet` makes the station canvas
	1920 x 1080 (landscape) or 1080 x 1920 (a phone held upright), and every
	piece is placed and outlined in those pixels, so a stroke stays as thick
	as the mockup's at any screen size.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Kit = require(script.Parent.Kit)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local Chunky = {}

--[[ The smallest a pressable's hit area may be, in screen points. ]]
local MIN_TOUCH = 48

Chunky.font = Enum.Font.FredokaOne
--[[ The outline round the cream and orange pieces and the stroke round the
     kit's words: the reference's dark brown. `navy` is the same colour
     under the name the blue look gave it, which the screens still use. ]]
Chunky.edge = Color3.fromRGB(86, 44, 16)
Chunky.navy = Chunky.edge
--[[ Words on cream and white: brown, with no stroke. ]]
Chunky.ink = Color3.fromRGB(112, 62, 24)
Chunky.white = Color3.fromRGB(255, 252, 244)
Chunky.green = Color3.fromRGB(104, 214, 46)
Chunky.gold = Color3.fromRGB(255, 196, 38)
Chunky.orange = Color3.fromRGB(250, 152, 40)
Chunky.blue = Color3.fromRGB(28, 168, 255)
Chunky.red = Color3.fromRGB(238, 60, 60)
Chunky.purple = Color3.fromRGB(168, 86, 255)
Chunky.grey = Color3.fromRGB(150, 160, 178)
Chunky.panelTop = Color3.fromRGB(255, 248, 232)
Chunky.panelBottom = Color3.fromRGB(252, 236, 206)
Chunky.headerTop = Color3.fromRGB(255, 192, 84)
Chunky.headerBottom = Color3.fromRGB(246, 146, 40)
--[[ The dark inside of a bar. ]]
Chunky.trough = Color3.fromRGB(104, 62, 30)

--[[ The darker shade of a colour that outlines it and strokes the words on
     it, as the reference's green button is edged dark green and its red
     one dark red. ]]
function Chunky.shade(colour: Color3): Color3
	return colour:Lerp(Color3.new(0, 0, 0), 0.62)
end

--[[ The six rarity frames, as the style sheet draws them. ]]
Chunky.rarity = {
	Common = Color3.fromRGB(160, 170, 186),
	Uncommon = Color3.fromRGB(70, 200, 80),
	Rare = Color3.fromRGB(28, 168, 255),
	Epic = Color3.fromRGB(168, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 30),
	Mythic = Color3.fromRGB(255, 70, 150),
}

export type Box = { x: number, y: number, w: number, h: number }

export type Sheet = {
	canvas: Frame,
	w: number,
	h: number,
	upright: boolean,
	--[[ The panel last drawn on this sheet and the header bar across its
	     top, in sheet pixels, so the title and the X know where it is. ]]
	panel: Box?,
	panelFrame: Frame?,
	panelFoot: Frame?,
	header: number?,
}

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
	return {
		canvas = canvas,
		w = w,
		h = h,
		upright = upright,
		panel = nil,
		panelFrame = nil,
		panelFoot = nil,
		header = nil,
	}
end

--[[ A sheet over any frame laid out in screen points rather than on the
     station canvas (the run's MENU, the draft's phone tray): two sheet
     pixels to a point when the frame is `w` points wide, so the kit's
     outlines come out as thick as they do on a station screen, and thicker
     or thinner with the frame if it is resized. ]]
function Chunky.pointSheet(frame: Frame, w: number, h: number): Sheet
	frame:SetAttribute("SheetW", w * 2)
	return {
		canvas = frame,
		w = w * 2,
		h = h * 2,
		upright = h > w,
		panel = nil,
		panelFrame = nil,
		panelFoot = nil,
		header = nil,
	}
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

--[[ Soft diagonal stripes over a coloured piece, as the reference's
     header and buttons carry: a white wash whose see-through runs in bands
     along a slanted line. `strength` is how solid a band gets (0 none). ]]
local function stripes(parent: GuiObject, z: number, radius: number, strength: number?): Frame
	local wash = fill(parent, Color3.new(1, 1, 1), z)
	wash.Name = "Stripes"
	if radius > 0 then
		Chunky.round(wash, radius)
	end
	local bands = Instance.new("UIGradient")
	bands.Rotation = -58
	local clear, solid = 1, 1 - (strength or 0.3)
	local keys = {}
	local last = 19
	for n = 0, last do
		table.insert(
			keys,
			NumberSequenceKeypoint.new(n / last, if n % 2 == 0 then clear else solid)
		)
	end
	bands.Transparency = NumberSequence.new(keys)
	bands.Parent = wash
	return wash
end

--[[ The cream panel: a dark-brown outline, a pale rim just inside its
     edge, and a darker foot under it so it stands off the screen. A
     `Chunky.ribbon` drawn after it becomes its header bar. ]]
function Chunky.panel(sheet: Sheet, x: number, y: number, w: number, h: number): Frame
	local foot = Instance.new("Frame")
	foot.Name = "ChunkyPanelFoot"
	foot.BorderSizePixel = 0
	foot.BackgroundColor3 = Chunky.edge
	foot.ZIndex = 1
	Chunky.put(sheet, foot, x, y + 12, w, h)
	Chunky.round(foot, 24)
	Chunky.outline(foot, 7)
	local p = Instance.new("Frame")
	p.Name = "ChunkyPanel"
	p.BorderSizePixel = 0
	p.BackgroundColor3 = Color3.new(1, 1, 1)
	p.ZIndex = 2
	Chunky.put(sheet, p, x, y, w, h)
	gradient(p, Chunky.panelTop, Chunky.panelBottom)
	Chunky.round(p, 24)
	Chunky.outline(p, 7)
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.BackgroundTransparency = 1
	rim.Position = UDim2.fromScale(7 / w, 7 / h)
	rim.Size = UDim2.fromScale(1 - 14 / w, 1 - 14 / h)
	rim.ZIndex = 2
	rim.Parent = p
	Chunky.round(rim, 18)
	Chunky.outline(rim, 3, Color3.new(1, 1, 1)).Transparency = 0.25
	sheet.panel = { x = x, y = y, w = w, h = h }
	sheet.panelFrame = p
	sheet.panelFoot = foot
	sheet.header = nil
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
	gradient(c, Color3.new(1, 1, 1), Color3.fromRGB(255, 244, 224))
	Chunky.round(c, 18)
	Chunky.outline(c, 5)
	return c
end

--[[ The orange striped bar, lit from the top: a header across a panel, or
     a title plate standing alone. Its lower half is one colour so a square
     skirt can hide the rounded bottom corners where it meets the panel. ]]
local function orangeBar(parent: Instance, radius: number, skirt: boolean): Frame
	local bar = fill(parent, Color3.new(1, 1, 1), 3)
	bar.Name = "Header"
	local light = Instance.new("UIGradient")
	light.Rotation = 90
	light.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Chunky.headerTop),
		ColorSequenceKeypoint.new(0.5, Chunky.headerBottom),
		ColorSequenceKeypoint.new(1, Chunky.headerBottom),
	})
	light.Parent = bar
	Chunky.round(bar, radius)
	if skirt then
		local square = fill(bar, Chunky.headerBottom, 3)
		square.Name = "Skirt"
		square.Position, square.Size = UDim2.fromScale(0, 0.5), UDim2.fromScale(1, 0.5)
	end
	stripes(bar, 4, radius, 0.36)
	return bar
end

--[[
	A screen's title. Drawn after a `Chunky.panel` it is that panel's
	header: the orange striped bar across its top, as deep as the old gold
	ribbon reached into the panel, the title at its left in white with the
	brown stroke and a brown line under the bar. `x`, `y`, `w` and `h` are
	the box the ribbon used to hang in; with no panel on the sheet the title
	stands in that box on a plate of its own.
]]
function Chunky.ribbon(sheet: Sheet, words: string, x: number, y: number, w: number, h: number)
	local on, frame = sheet.panel, sheet.panelFrame
	if not on or not frame then
		local holder = Instance.new("Frame")
		holder.Name = "Ribbon"
		holder.BackgroundTransparency = 1
		holder.ZIndex = 20
		Chunky.put(sheet, holder, x, y, w, h)
		local plate = orangeBar(holder, 18, false)
		plate.ZIndex = 20
		Chunky.outline(plate, 7)
		local t = Chunky.text(plate, words, nil, 6)
		t.Position, t.Size = UDim2.fromScale(0.06, 0.16), UDim2.fromScale(0.88, 0.7)
		return
	end
	--[[ The bar is as deep as the old ribbon reached into the panel, so it
	     never covers what the screen laid out under it. Where that is too
	     shallow to carry the title, the panel's top rises to make room
	     rather than the bar coming down. ]]
	local natural = math.max(1, y + h - on.y)
	local grow = math.clamp(80 - natural, 0, 26)
	if grow > 0 then
		on = { x = on.x, y = on.y - grow, w = on.w, h = on.h + grow }
		sheet.panel = on
		frame.Position = UDim2.fromScale(on.x / sheet.w, on.y / sheet.h)
		frame.Size = UDim2.fromScale(on.w / sheet.w, on.h / sheet.h)
		local foot = sheet.panelFoot
		if foot then
			foot.Position = UDim2.fromScale(on.x / sheet.w, (on.y + 12) / sheet.h)
			foot.Size = frame.Size
		end
	end
	local deep = math.min(natural + grow, on.h * 0.3)
	sheet.header = deep
	local bar = orangeBar(frame, 24, true)
	bar.Size = UDim2.fromScale(1, deep / on.h)
	local line = fill(bar, Chunky.edge, 5)
	line.Name = "Line"
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position, line.Size = UDim2.fromScale(0, 1), UDim2.fromScale(1, 7 / deep)
	local t = Chunky.text(bar, words, nil, 6)
	t.Name = "Title"
	t.Position, t.Size = UDim2.fromScale(28 / on.w, 0.16), UDim2.fromScale(0.72, 0.66)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 6
end

--[[ A few sparks thrown out of a pressed piece: small diamonds in white
     and gold that fly a short way, turn and fade (the owner's "effects"). ]]
function Chunky.burst(item: GuiObject)
	local layer = item:FindFirstAncestorWhichIsA("ScreenGui")
	if not layer then
		return
	end
	local middle = item.AbsolutePosition + item.AbsoluteSize / 2 - layer.AbsolutePosition
	local reach = math.clamp(math.min(item.AbsoluteSize.X, item.AbsoluteSize.Y), 28, 90)
	for n = 1, 7 do
		local angle = (n + math.random()) * math.pi * 2 / 7
		local size = math.random(7, 13)
		local spark = Instance.new("Frame")
		spark.Name = "Spark"
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.BorderSizePixel = 0
		spark.BackgroundColor3 = if n % 2 == 0 then Chunky.gold else Color3.new(1, 1, 1)
		spark.Position = UDim2.fromOffset(
			middle.X + math.cos(angle) * item.AbsoluteSize.X * 0.3,
			middle.Y + math.sin(angle) * item.AbsoluteSize.Y * 0.3
		)
		spark.Rotation = 45
		spark.Size = UDim2.fromOffset(size, size)
		spark.ZIndex = 60
		spark.Parent = layer
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = spark
		local fly = TweenService:Create(
			spark,
			TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(
					middle.X + math.cos(angle) * (item.AbsoluteSize.X * 0.5 + reach * 0.6),
					middle.Y + math.sin(angle) * (item.AbsoluteSize.Y * 0.5 + reach * 0.6)
				),
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 0.4,
				Rotation = 225,
			}
		)
		fly:Play()
		fly.Completed:Once(function()
			spark:Destroy()
		end)
	end
end

--[[ Squash on press, swell a touch on hover; the click, its sound and its
     sparks. ]]
local function pressable(holder: GuiObject, visual: GuiObject, action: () -> ()): TextButton
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 40
	hit.Parent = holder
	hit.Activated:Connect(function()
		SoundFx.play("card_click")
		Chunky.burst(visual)
		action()
	end)
	Kit.pressFx(hit, visual, false)
	return hit
end

--[[ A fat striped button: a darker lip under a face lit from the top, soft
     diagonal stripes across it, all of it outlined in the colour's dark
     shade, the words (and an icon) in white with that shade round them. A
     gold one, the screen's main action, carries a shine that sweeps it. ]]
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
	local dark = Chunky.shade(colour)
	local radius = math.min(18, h * 0.22)
	local lip = fill(body, colour:Lerp(Color3.new(0, 0, 0), 0.38), 10)
	lip.Name = "Lip"
	lip.Position, lip.Size = UDim2.fromScale(0, 0.1), UDim2.fromScale(1, 0.9)
	Chunky.round(lip, radius)
	Chunky.outline(lip, 6, dark)
	local face = fill(body, Color3.new(1, 1, 1), 11)
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 0.88)
	gradient(face, colour:Lerp(Color3.new(1, 1, 1), 0.3), colour)
	Chunky.round(face, radius)
	Chunky.outline(face, 6, dark)
	stripes(face, 12, radius)
	local left = 0.08
	if icon and icon ~= "" then
		local picture = Kit.image(face, icon)
		picture.Position, picture.Size = UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.3, 0.76)
		picture.ZIndex = 13
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = picture
		left = 0.3
	end
	local t = Chunky.text(face, words, nil, 5, dark)
	t.Name = "Words"
	t.Position, t.Size = UDim2.fromScale(left, 0.16), UDim2.fromScale(0.92 - left, 0.66)
	pressable(holder, body, action)
	if colour == Chunky.gold then
		Chunky.gleam(face)
	end
	return holder
end

--[[ Repaints a `Chunky.button` in another colour and, with `words`, says
     something else on it: a button that greys out until it can be pressed
     (the draft's CHOOSE!), or counts something down (its REROLL). ]]
function Chunky.repaint(button: Frame, colour: Color3, words: string?)
	local dark = Chunky.shade(colour)
	local function edge(item: Instance?)
		local stroke = if item then item:FindFirstChildOfClass("UIStroke") else nil
		if stroke then
			stroke.Color = dark
		end
	end
	local lip = button:FindFirstChild("Lip", true)
	if lip and lip:IsA("Frame") then
		lip.BackgroundColor3 = colour:Lerp(Color3.new(0, 0, 0), 0.38)
		edge(lip)
	end
	local face = button:FindFirstChild("Face", true)
	local light = if face then face:FindFirstChildOfClass("UIGradient") else nil
	if light then
		light.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.3), colour)
	end
	edge(face)
	local label = button:FindFirstChild("Words", true)
	edge(label)
	if words and label and label:IsA("TextLabel") then
		label.Text = words
	end
end

--[[ A regular hexagon filling `share` of a square `parent`: three bars
     through its middle, a third of a turn apart. ]]
local function hexagon(parent: GuiObject, colour: Color3, share: number, z: number)
	for turn = 0, 2 do
		local bar = Instance.new("Frame")
		bar.Name = "Hex"
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = colour
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(share * 0.5, share * 0.866)
		bar.Rotation = turn * 60
		bar.ZIndex = z
		bar.Parent = parent
	end
end

--[[ The red hexagon X. With a header on the sheet it sits at the bar's
     right end, as the reference has it, whatever box it was given; without
     one it hangs where it was told, `size` square at (`x`, `y`). ]]
function Chunky.close(sheet: Sheet, x: number, y: number, size: number, action: () -> ())
	local on, deep = sheet.panel, sheet.header
	if on and deep then
		size = deep * 0.84
		x = on.x + on.w - size - deep * 0.16
		y = on.y + (deep - size) / 2
	end
	local holder = Instance.new("Frame")
	holder.Name = "Close"
	holder.BackgroundTransparency = 1
	holder.ZIndex = 30
	Chunky.put(sheet, holder, x, y, size, size)
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.ZIndex = 30
	body.Parent = holder
	hexagon(body, Chunky.shade(Chunky.red), 1, 30)
	hexagon(body, Chunky.red, 0.82, 31)
	hexagon(body, Chunky.red:Lerp(Color3.new(1, 1, 1), 0.22), 0.6, 32)
	local cross = Chunky.text(body, "X", nil, 5, Chunky.shade(Chunky.red))
	cross.Position, cross.Size = UDim2.fromScale(0.24, 0.24), UDim2.fromScale(0.52, 0.52)
	cross.ZIndex = 33
	--[[ In a header the X is drawn only as tall as the bar, about 24 points
	     on an upright phone, so the area that takes the press grows round
	     it to a finger's `MIN_TOUCH` (the 2026-11-11 loop and UI review). ]]
	local hit = pressable(holder, body, action)
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	scaled(holder, function(unit)
		local grow = math.max(1, MIN_TOUCH / math.max(size * unit, 1))
		hit.Size = UDim2.fromScale(grow, grow)
	end)
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
	local pill = fill(holder, Chunky.panelTop, 20)
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

--[[ The colours a currency's amount is written in on its pill. ]]
Chunky.coinText = Color3.fromRGB(255, 206, 46)
Chunky.gemText = Color3.fromRGB(96, 208, 255)

--[[ The player's coins and gems. ]]
function Chunky.wallet(sheet: Sheet, coins: number, gems: number, x: number, y: number, h: number)
	Chunky.pill(sheet, ShopAssets.coin, Chunky.commas(coins), x, y, h * 3.4, h, Chunky.coinText)
	Chunky.pill(
		sheet,
		ShopAssets.gem,
		Chunky.commas(gems),
		x + h * 3.6,
		y,
		h * 2.8,
		h,
		Chunky.gemText
	)
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
	trough.BackgroundColor3 = Chunky.trough
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
	gradient(t, tone:Lerp(Color3.new(1, 1, 1), 0.5), tone:Lerp(Color3.new(1, 1, 1), 0.12))
	Chunky.round(t, 16)
	local edge = Chunky.outline(t, 6, Chunky.shade(tone))
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
		for ring, spread in { 16, 9, 4 } do
			local halo = Instance.new("Frame")
			halo.BackgroundTransparency = 1
			halo.Size = UDim2.fromScale(1, 1)
			halo.ZIndex = 5
			halo.Parent = t
			Chunky.round(halo, 18)
			local glow = Chunky.outline(halo, spread * 2 + 6, tone)
			glow.Transparency = ({ 0.76, 0.54, 0.24 })[ring]
		end
	end
	if rarity == "Mythic" then
		edge:Destroy()
		Kit.rainbowRing(t)
		local ring = t:FindFirstChildOfClass("UIStroke")
		if ring then
			scaled(t, function(unit)
				ring.Thickness = math.max(3, 9 * unit)
			end)
		end
	end
	if owned then
		Kit.owned(t)
	end
	return t
end

--[[ Makes any piece pressable the way the kit's buttons are: it swells a
     touch under the pointer, squashes when pressed and springs back past
     full size on release (owner, 2026-11-05: "the bounce on click"). ]]
function Chunky.press(holder: GuiObject, action: () -> ())
	pressable(holder, holder, action)
end

--[[ A bright slanted streak that sweeps across `item` every few seconds,
     the shine on something the player can equip (owner, 2026-11-05: "the
     gleam on equippables"). `phase` staggers neighbours so a row of tiles
     does not flash in step. ]]
function Chunky.gleam(item: GuiObject, phase: number?)
	local shine = fill(item, Color3.new(1, 1, 1), item.ZIndex + 7)
	shine.Name = "Gleam"
	shine.BackgroundTransparency = 0.35
	Chunky.round(shine, 18)
	local slant = Instance.new("UIGradient")
	slant.Rotation = 30
	slant.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	slant.Offset = Vector2.new(-1.5, 0)
	slant.Parent = shine
	local start = phase or 0
	Kit.animate(shine, function(t)
		local cycle = (t * 0.6 + start) % 2.4
		slant.Offset = Vector2.new(if cycle < 1 then -1.2 + cycle * 2.4 else 1.5, 0)
	end)
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

--[[ Blinking sparkles on the corners of whatever is selected or new, as
     the reference's chosen rail button carries: three small diamonds that
     swell and shrink out of step. ]]
function Chunky.twinkle(item: GuiObject)
	local spots = { { 0.08, 0.1, 0.2 }, { 0.92, 0.2, 0.14 }, { 0.84, 0.9, 0.17 } }
	local stars: { Frame } = {}
	for n, spot in spots do
		local star = Instance.new("Frame")
		star.Name = "Twinkle"
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.BorderSizePixel = 0
		star.BackgroundColor3 = Color3.new(1, 1, 1)
		star.Position = UDim2.fromScale(spot[1], spot[2])
		star.Size = UDim2.fromScale(spot[3], spot[3])
		star.SizeConstraint = Enum.SizeConstraint.RelativeYY
		star.Rotation = 45
		star.ZIndex = item.ZIndex + 20
		star.Parent = item
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = star
		local scale = Instance.new("UIScale")
		scale.Parent = star
		stars[n] = star
	end
	Kit.animate(stars[1], function(t)
		for n, star in stars do
			local scale = star:FindFirstChildOfClass("UIScale")
			if scale then
				scale.Scale = math.max(0, math.sin(t * 3.2 + n * 2.1))
			end
			star.Rotation = 45 + t * 40
		end
	end)
end

--[[ Runs a number on `label` from what it shows to `to`, quickly, so a
     currency that changes is seen to change. ]]
function Chunky.count(label: TextLabel, to: number)
	local from = tonumber((string.gsub(label.Text, "[^%d]", ""))) or 0
	if from == to then
		label.Text = Chunky.commas(to)
		return
	end
	label:SetAttribute("CountTo", to)
	local start = os.clock()
	local length = 0.45
	task.spawn(function()
		while label.Parent and label:GetAttribute("CountTo") == to do
			local share = math.min(1, (os.clock() - start) / length)
			local eased = 1 - (1 - share) ^ 3
			label.Text = Chunky.commas(math.floor(from + (to - from) * eased + 0.5))
			if share >= 1 then
				break
			end
			task.wait()
		end
	end)
end

return Chunky
