--!strict
--[[
	The shops' drawing kit (owner, 2026-10-26: "Scale, never Offset").
	All layout rectangles use the 1920 by 1080 sheet's 8px grid.
	Candy gloss (owner: "Match option B"): cream, gold and warm ink.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Device = require(script.Parent.Parent.Device)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local OptcAssets = require(ReplicatedStorage.Shared.Config.OptcAssets)
local Pity = require(ReplicatedStorage.Shared.Util.Pity)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local Kit = {}
Kit.wood = Color3.fromRGB(255, 236, 196)
Kit.slate = Color3.fromRGB(235, 211, 164)
Kit.gold = Color3.fromRGB(255, 205, 40)
Kit.green = Color3.fromRGB(46, 220, 46)
Kit.white = Color3.fromRGB(255, 248, 220)
local INK = Color3.fromRGB(58, 36, 18)
function Kit.box(x: number, y: number, w: number, h: number): (UDim2, UDim2)
	return UDim2.fromScale(x / 1920, y / 1080), UDim2.fromScale(w / 1920, h / 1080)
end
function Kit.put(item: GuiObject, x: number, y: number, w: number, h: number)
	item.Position, item.Size = Kit.box(x, y, w, h)
end
local function canvasUnit(item: Instance): number
	local canvas: Instance? = item.Parent
	while canvas and canvas.Name ~= "StationCanvas" do
		canvas = canvas.Parent
	end
	return if canvas and canvas:IsA("GuiObject") then canvas.AbsoluteSize.X / 1920 else 1
end
local function rounded(item: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = item
end
local function gloss(parent: Frame, strong: boolean): Frame
	local shine = Instance.new("Frame")
	shine.Name = "Gloss"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.Position, shine.Size = UDim2.fromScale(0.035, 0.04), UDim2.fromScale(0.93, 0.48)
	shine.Parent = parent
	rounded(shine, 0.5)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(if strong then 0.45 else 0.72, 1)
	fade.Parent = shine
	return shine
end
function Kit.panel(parent: Instance, colour: Color3): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color = 4, INK
	stroke.Parent = f
	rounded(f, 0.06)
	f:SetAttribute("CornerPixels", 28)
	local gradient = Instance.new("UIGradient")
	gradient.Color = if colour == Kit.green
		then ColorSequence.new(Color3.fromRGB(123, 234, 58), Kit.green)
		elseif colour == Kit.gold then ColorSequence.new(
			Kit.gold,
			Color3.fromRGB(247, 165, 49)
		)
		elseif colour == Kit.wood or colour == Kit.slate then ColorSequence.new(
			Kit.wood,
			Kit.slate
		)
		else ColorSequence.new(colour:Lerp(Kit.white, 0.22), colour:Lerp(INK, 0.12))
	gradient.Rotation = 90
	gradient.Parent = f
	local bevel = Instance.new("Frame")
	bevel.Name = "Rim"
	bevel.BackgroundTransparency = 1
	bevel.Position, bevel.Size = UDim2.fromScale(0.012, 0.018), UDim2.fromScale(0.976, 0.964)
	bevel.Parent = f
	rounded(bevel, 0.06)
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness = Kit.gold, 2
	edge.Parent = bevel
	local function resizeSurface()
		local unit = canvasUnit(f)
		local pixels = f:GetAttribute("CornerPixels")
		if type(pixels) == "number" then
			local curve = f:FindFirstChildOfClass("UICorner")
			if curve then
				curve.CornerRadius = UDim.new(
					math.min(
						0.48,
						pixels * unit / math.max(1, math.min(f.AbsoluteSize.X, f.AbsoluteSize.Y))
					),
					0
				)
			end
			local innerCurve = bevel:FindFirstChildOfClass("UICorner")
			if innerCurve and curve then
				innerCurve.CornerRadius = curve.CornerRadius
			end
		end
		stroke.Thickness, edge.Thickness = math.max(1, 4 * unit), math.max(1, 2 * unit)
	end
	local changed = f:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeSurface)
	local radiusChanged = f:GetAttributeChangedSignal("CornerPixels"):Connect(resizeSurface)
	f.Destroying:Once(function()
		changed:Disconnect()
		radiusChanged:Disconnect()
	end)
	resizeSurface()
	gloss(f, false)
	return f
end
function Kit.pill(f: Frame)
	f:SetAttribute("CornerPixels", nil)
	local corner = f:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.48, 0)
	end
	local rim = f:FindFirstChild("Rim")
	if rim and rim:IsA("Frame") then
		local curve = rim:FindFirstChildOfClass("UICorner")
		if curve then
			curve.CornerRadius = UDim.new(0.48, 0)
		end
	end
	local old = f:FindFirstChild("Gloss")
	if old then
		old:Destroy()
	end
	gloss(f, true)
end
function Kit.plate(parent: Instance): Frame
	local f = Kit.panel(parent, Color3.fromRGB(132, 49, 14))
	f.Name = "TitlePlate"
	Kit.pill(f)
	local face = Kit.panel(f, Color3.fromRGB(91, 34, 12))
	face.Position, face.Size = UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.92, 0.76)
	Kit.pill(face)
	for row = 1, 3 do
		local seam = Instance.new("Frame")
		seam.Name = "PlankSeam"
		seam.BorderSizePixel = 0
		seam.BackgroundColor3 = Color3.fromRGB(45, 17, 7)
		seam.BackgroundTransparency = 0.5
		seam.Position, seam.Size = UDim2.fromScale(0.05, row * 0.24), UDim2.fromScale(0.9, 0.018)
		seam.Parent = face
	end
	for _, x in { 0.015, 0.94 } do
		local gem = Kit.panel(f, Color3.fromRGB(117, 124, 137))
		gem.Position, gem.Size = UDim2.fromScale(x, 0.26), UDim2.fromScale(0.045, 0.48)
		Kit.pill(gem)
	end
	return f
end
function Kit.leaves(parent: Instance)
	for _, x in { 0.02, 0.92 } do
		for i = 1, 3 do
			local leaf = Kit.panel(parent, Color3.fromRGB(58, 184, 18))
			leaf.Position, leaf.Size =
				UDim2.fromScale(x + (i - 2) * 0.016, 0.04 + (i % 2) * 0.12),
				UDim2.fromScale(0.045, 0.2)
			leaf.Rotation = (i - 2) * 40
		end
		local flower = Kit.label(parent, "*", Kit.white)
		flower.Position, flower.Size = UDim2.fromScale(x + 0.02, 0.02), UDim2.fromScale(0.045, 0.3)
	end
end
function Kit.label(parent: Instance, words: string, colour: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	if parent.Name == "TitlePlate" then
		l.Position, l.Size = UDim2.fromScale(0.08, 0.12), UDim2.fromScale(0.84, 0.76)
	end
	l.Font = Enum.Font.Arcade
	l.Text = words
	l.TextColor3 = colour or Kit.white
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0
	l.TextScaled = true
	l.TextWrapped = true
	l.ZIndex = 4
	l.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	-- Allow the fitted portrait sheet to shrink text within its existing rectangles.
	limit.MinTextSize = 1
	limit.MaxTextSize = 96
	limit.Parent = l
	local shadow = l:Clone()
	shadow.Name = "TextShadow"
	shadow.TextColor3, shadow.TextTransparency = INK, 0.35
	shadow.ZIndex = 3
	-- a child always draws over its parent, so a shadow inside the label
	-- covered the letters (they read dark): keep it, but hidden; the font's
	-- own dark stroke outlines the words
	shadow.Visible = false
	shadow.Parent = l
	local function sync()
		shadow.Text = l.Text
		shadow.TextTransparency = 1 - (1 - l.TextTransparency) * 0.65
		shadow.TextStrokeTransparency = 1 - (1 - l.TextStrokeTransparency) * 0.65
		shadow.ZIndex = math.max(1, l.ZIndex - 1)
		shadow.TextScaled, shadow.TextSize = l.TextScaled, l.TextSize
		shadow.TextWrapped = l.TextWrapped
		shadow.TextXAlignment, shadow.TextYAlignment = l.TextXAlignment, l.TextYAlignment
		local distance = 2.5 * canvasUnit(l)
		shadow.Position = UDim2.fromScale(
			distance / math.max(1, l.AbsoluteSize.X),
			distance / math.max(1, l.AbsoluteSize.Y)
		)
		shadow.Size = UDim2.fromScale(1, 1)
		local cap = shadow:FindFirstChildOfClass("UITextSizeConstraint")
		if cap then
			cap.MinTextSize, cap.MaxTextSize = limit.MinTextSize, limit.MaxTextSize
		end
	end
	local changed = l.Changed:Connect(sync)
	local resized = limit.Changed:Connect(sync)
	l.Destroying:Once(function()
		changed:Disconnect()
		resized:Disconnect()
	end)
	sync()
	return l
end
function Kit.image(parent: Instance, asset: string, hidden: boolean?): ImageLabel
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Size = UDim2.fromScale(1, 1)
	i.Image = asset
	i.ImageColor3 = if hidden then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
	i.ScaleType = Enum.ScaleType.Fit
	i.ResampleMode = Enum.ResamplerMode.Pixelated
	i.ZIndex = 3
	i.Parent = parent
	if asset == "" and not hidden then
		Kit.label(i, "?")
	end
	return i
end
--[[ Option C's own lettering, fitted without changing the glyph proportions. ]]
function Kit.glyphs(parent: GuiObject, text: string, colour: Color3?, height: number?): Frame
	local row = Instance.new("Frame")
	row.Name = "Glyphs"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = parent.ZIndex + 1
	row.Parent = parent
	local cells: { { image: ImageLabel?, ratio: number } } = {}
	for character in string.gmatch(string.upper(text), ".") do
		local box = OptcAssets.glyphs[character]
		if box then
			local glyph = Kit.image(row, OptcAssets.glyphSheet)
			glyph.ImageRectOffset = Vector2.new(box.x, box.y)
			glyph.ImageRectSize = Vector2.new(box.w, box.h)
			glyph.ImageColor3 = colour or Color3.new(1, 1, 1)
			glyph.ScaleType = Enum.ScaleType.Stretch
			glyph.ZIndex = row.ZIndex
			table.insert(cells, { image = glyph, ratio = box.w / box.h })
		elseif character == " " then
			table.insert(cells, { image = nil, ratio = 40 / 128 })
		end
	end
	local function layout()
		local size = row.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local unit = canvasUnit(row)
		local tall = math.min(size.Y * 0.7, (height or math.huge) * unit)
		local ratios = 0
		for _, cell in cells do
			ratios += cell.ratio
		end
		local tracking = 4 * unit
		local width = ratios * tall + math.max(0, #cells - 1) * tracking
		local fit = math.min(1, size.X / math.max(1, width))
		tall, tracking, width = tall * fit, tracking * fit, width * fit
		local x = (size.X - width) / 2
		for _, cell in cells do
			local wide = cell.ratio * tall
			if cell.image then
				cell.image.Position = UDim2.fromScale(x / size.X, (size.Y - tall) / 2 / size.Y)
				cell.image.Size = UDim2.fromScale(wide / size.X, tall / size.Y)
			end
			x += wide + tracking
		end
	end
	local resized = row:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	row.Destroying:Once(function()
		resized:Disconnect()
	end)
	layout()
	return row
end
--[[ Uploaded mockup pieces retain their canvas rectangles; only changing words
     are composed from the approved glyph atlas. Shared by Hatchery and Gear. ]]
export type CutBox = { x: number, y: number, w: number, h: number }
export type CutPieces = { [string]: { image: string, box: CutBox } }
function Kit.cutPiece(parent: Instance, pieces: CutPieces, name: string, at: CutBox?): ImageLabel
	local data = pieces[name]
	local box = at or data.box
	local image = Kit.image(parent, data.image)
	image.Name = name
	image.ScaleType = Enum.ScaleType.Stretch
	Kit.put(image, box.x, box.y, box.w, box.h)
	return image
end
function Kit.cutText(parent: GuiObject, text: string, x: number, y: number, w: number, h: number)
	local row = Kit.glyphs(parent, text)
	row.Position, row.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
end
function Kit.clickArea(parent: GuiObject, action: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 10
	button.Parent = parent
	local connection = button.Activated:Connect(action)
	button.Destroying:Once(function()
		connection:Disconnect()
	end)
	return button
end
function Kit.cutTile(
	parent: Instance,
	pieces: CutPieces,
	rarity: string,
	asset: string,
	locked: boolean
): ImageLabel
	local tile = Kit.cutPiece(parent, pieces, if locked then "TileLocked" else "Tile" .. rarity)
	local icon = Kit.image(tile, asset, locked)
	icon.Position, icon.Size = UDim2.fromScale(0.13, 0.08), UDim2.fromScale(0.74, 0.84)
	icon.ZIndex = tile.ZIndex + 1
	if locked then
		local lock = Kit.image(tile, ShopAssets.lock)
		lock.Position, lock.Size = UDim2.fromScale(0.8, 0.55), UDim2.fromScale(0.16, 0.32)
		lock.ZIndex = icon.ZIndex + 1
	end
	if rarity == "Mythic" then
		Kit.rainbowRing(tile)
	elseif rarity == "Legendary" then
		local glow = Kit.image(tile, GearAssets.fx.glow)
		glow.Position, glow.Size = UDim2.fromScale(-0.08, -0.12), UDim2.fromScale(1.16, 1.24)
		glow.ImageColor3 = Kit.gold
		glow.ZIndex = tile.ZIndex
		Kit.animate(glow, function(t)
			glow.ImageTransparency = 0.75 + math.sin(t * 3) * 0.1
		end)
	end
	return tile
end
function Kit.button(parent: Instance, words: string, colour: Color3, action: () -> ()): Frame
	local f = Kit.panel(parent, colour)
	Kit.pill(f)
	local l = Kit.label(f, words)
	l.Position = UDim2.fromScale(0.04, 0.12)
	l.Size = UDim2.fromScale(0.92, 0.76)
	l.TextColor3 = if colour == Kit.gold or colour == Kit.slate then INK else Kit.white
	local limit = l:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MaxTextSize = 72
	end
	local scale = Instance.new("UIScale")
	scale.Parent = f
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.Arcade
	b.Text = ""
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromScale(1, 1)
	b.ZIndex = 5
	b.Parent = f
	local hovered, pressed = false, false
	local connections: { RBXScriptConnection } = {}
	local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
		table.insert(connections, signal:Connect(callback))
	end
	local motion: Tween? = nil
	local function grow(target: number)
		if motion then
			motion:Cancel()
		end
		local tween = TweenService:Create(
			scale,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad),
			{ Scale = target }
		)
		motion = tween
		tween:Play()
	end
	connect(b.MouseEnter, function()
		hovered = true
		grow(1.025)
	end)
	connect(b.MouseLeave, function()
		hovered, pressed = false, false
		grow(1)
	end)
	connect(b.InputBegan, function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressed = true
			grow(0.96)
		end
	end)
	connect(b.InputEnded, function()
		pressed = false
		grow(if hovered then 1.025 else 1)
	end)
	f.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		if motion then
			motion:Cancel()
		end
	end)
	if words == "OPEN" or string.match(words, "^HATCH %d+$") ~= nil then
		local sweep = gloss(f, true)
		sweep.Size, sweep.Rotation = UDim2.fromScale(0.12, 0.7), 18
		Kit.animate(f, function(t)
			if
				not hovered
				and not pressed
				and (not motion or motion.PlaybackState ~= Enum.PlaybackState.Playing)
			then
				scale.Scale = 1 + math.sin(t * 2) * 0.008
			end
			local phase = t % 5
			sweep.Visible = phase < 1.2
			sweep.Position = UDim2.fromScale(0.05 + math.min(phase / 1.2, 1) * 0.78, 0.1)
		end)
	end
	connect(b.Activated, function()
		scale.Scale = 0.94
		grow(if hovered then 1.025 else 1)
		action()
	end)
	return f
end
--[[ The screens' rarity colours: vivid, as in the chosen mockup (owner,
     2026-10-26: "the colors need to be brighter to match the reference
     photo"); the cards keep `Config/Rarities`' softer ones. ]]
local VIVID: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 200, 210),
	Uncommon = Color3.fromRGB(57, 235, 64),
	Rare = Color3.fromRGB(30, 150, 255),
	Epic = Color3.fromRGB(190, 70, 255),
	Legendary = Color3.fromRGB(255, 196, 20),
	Mythic = Color3.fromRGB(255, 60, 160),
}
function Kit.colour(rarity: string): Color3
	local vivid = VIVID[rarity]
	if vivid then
		return vivid
	end
	local r = Rarities.byName[rarity]
	return if r then r.color else INK
end
--[[ A tile that is one picture, border and all (a mockup's cut tile), its
     label snapped into the band along its bottom as `Kit.tile` does; a
     Mythic's border turns the rainbow over it. ]]
--[[ A button that is one picture (a mockup's cut button): it grows on
     hover and squashes on press, then calls `onClick`. ]]
function Kit.imageButton(parent: Instance, picture: string, onClick: () -> ()): ImageButton
	local b = Instance.new("ImageButton")
	b.BackgroundTransparency = 1
	b.Image = picture
	b.ScaleType = Enum.ScaleType.Fit
	b.ZIndex = 5
	b.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local target = 1
	b.MouseEnter:Connect(function()
		target = 1.08
	end)
	b.MouseLeave:Connect(function()
		target = 1
	end)
	b.MouseButton1Down:Connect(function()
		scale.Scale = 0.9
	end)
	b.Activated:Connect(onClick)
	Kit.animate(b, function()
		scale.Scale += (target - scale.Scale) * 0.25
	end)
	return b
end
--[[ A rainbow ring round a tile, turning clockwise (a Mythic's). ]]
function Kit.rainbowRing(tile: GuiObject)
	local corner = tile:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = tile
	local ring = Instance.new("UIStroke")
	ring.Thickness = 4
	ring.Color = Color3.new(1, 1, 1)
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = tile
	local spin = Instance.new("UIGradient")
	spin.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 170, 40)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 230, 90)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 190, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(170, 90, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 70)),
	})
	spin.Parent = ring
	Kit.animate(spin, function(t)
		spin.Rotation = (t * 90) % 360
	end)
end
--[[ A green tick badge in a tile's top-right corner: the player owns it. ]]
function Kit.owned(tile: GuiObject)
	local badge = Instance.new("Frame")
	badge.Name = "Owned"
	badge.BackgroundColor3 = Color3.fromRGB(46, 210, 60)
	badge.BorderSizePixel = 0
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position, badge.Size = UDim2.fromScale(0.96, 0.04), UDim2.fromScale(0.3, 0.3)
	badge.ZIndex = 8
	badge.Parent = tile
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = badge
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = badge
	local edge = Instance.new("UIStroke")
	edge.Thickness, edge.Color = 3, INK
	edge.Parent = badge
	-- the tick: two white bars
	for _, bar in { { 0.2, 0.52, 0.32, 0.16, 45 }, { 0.36, 0.42, 0.52, 0.16, -50 } } do
		local stroke = Instance.new("Frame")
		stroke.BackgroundColor3 = Color3.new(1, 1, 1)
		stroke.BorderSizePixel = 0
		stroke.Position, stroke.Size =
			UDim2.fromScale(bar[1], bar[2]), UDim2.fromScale(bar[3], bar[4])
		stroke.Rotation = bar[5]
		stroke.ZIndex = 9
		stroke.Parent = badge
	end
end
function Kit.pictureTile(parent: Instance, rarity: string, picture: string): ImageLabel
	local f = Kit.image(parent, picture)
	f.ScaleType = Enum.ScaleType.Stretch
	f.ZIndex = 4
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = f
	if rarity == "Mythic" then
		local ring = Instance.new("UIStroke")
		ring.Thickness = 4
		ring.Color = Color3.new(1, 1, 1)
		ring.Parent = f
		local spin = Instance.new("UIGradient")
		spin.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 170, 40)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 230, 90)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 190, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(170, 90, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 70)),
		})
		spin.Parent = ring
		Kit.animate(spin, function(t)
			spin.Rotation = (t * 90) % 360
		end)
	end
	f.ChildAdded:Connect(function(child)
		if child:IsA("TextLabel") then
			task.defer(function()
				child.Position, child.Size = UDim2.fromScale(0.1, 0.74), UDim2.fromScale(0.8, 0.19)
				child.ZIndex = math.max(child.ZIndex, 6)
			end)
		end
	end)
	return f
end
function Kit.tile(parent: Instance, rarity: string, asset: string, hidden: boolean): Frame
	-- a dark centre framed by a thick border in its rarity's colour, as in
	-- the chosen mockup; a Mythic's border is a rainbow turning clockwise
	-- (owner, 2026-10-26)
	local colour = Kit.colour(rarity)
	local f = Kit.panel(parent, colour)
	f:SetAttribute("CornerPixels", 16)
	local outline = f:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Thickness = 3
		outline.Color = INK
		outline.Transparency = 0
	end
	local inner = Kit.panel(f, Color3.fromRGB(30, 26, 34))
	inner:SetAttribute("CornerPixels", 10)
	inner.Position, inner.Size = UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.84, 0.84)
	local band = inner:FindFirstChildOfClass("UIStroke")
	if band then
		band.Thickness = 2
		band.Color = colour:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.fromRGB(70, 66, 80), Color3.fromRGB(20, 18, 24))
	shade.Parent = inner
	if rarity == "Mythic" then
		local spin = Instance.new("UIGradient")
		spin.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 170, 40)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 230, 90)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 190, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(170, 90, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 70)),
		})
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		-- one UIGradient per Frame counts: drop the panel's own first
		for _, old in f:GetChildren() do
			if old:IsA("UIGradient") then
				old:Destroy()
			end
		end
		spin.Parent = f
		Kit.animate(spin, function(t)
			spin.Rotation = (t * 90) % 360
		end)
	end
	local icon = Kit.image(f, asset, hidden)
	-- as big as the tile allows, above the label strip along its bottom
	-- inside the dark centre, clear of the border: the picture above, a strip
	-- for its label (a chance, a price) below (owner, 2026-10-26: "make sure
	-- the weapons and rarities fit in the boxes")
	icon.Position = UDim2.fromScale(0.13, 0.11)
	icon.Size = UDim2.fromScale(0.74, 0.58)
	icon.ScaleType = Enum.ScaleType.Fit
	if hidden then
		local lock = Kit.image(f, ShopAssets.lock)
		lock.Position = UDim2.fromScale(0.7, 0.5)
		lock.Size = UDim2.fromScale(0.24, 0.24)
	end
	if rarity == "Legendary" then
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if outline and f.Visible then
				outline.Color = INK:Lerp(Kit.gold, 0.5 + math.sin(os.clock() * 3) * 0.5)
			end
		end)
		f.Destroying:Once(function()
			connection:Disconnect()
		end)
	end
	Kit.gem(f, rarity)
	f.ChildAdded:Connect(function(child)
		if child:IsA("TextLabel") then
			task.defer(function()
				child.Position, child.Size = UDim2.fromScale(0.1, 0.7), UDim2.fromScale(0.8, 0.2)
				child.ZIndex = math.max(child.ZIndex, 6)
				local cap = child:FindFirstChildOfClass("UITextSizeConstraint")
				if cap then
					cap.MinTextSize = 10
				end
			end)
		end
	end)
	return f
end
function Kit.animate(item: Instance, action: (number) -> ())
	local step = RunService.RenderStepped:Connect(function()
		action(os.clock())
	end)
	item.Destroying:Once(function()
		step:Disconnect()
	end)
end
function Kit.gem(parent: Instance, rarity: string)
	local gem = Kit.image(parent, ShopAssets.gem)
	gem.Position, gem.Size = UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.16, 0.18)
	gem.ImageColor3 = Kit.colour(rarity)
	if rarity == "Mythic" then
		Kit.animate(gem, function(t)
			gem.ImageColor3 = Color3.fromHSV(t * 0.2 % 1, 0.8, 1)
		end)
	end
end
function Kit.highlight(frame: Frame)
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness = Kit.gold, 6
	edge.Parent = frame
	Kit.animate(frame, function(t)
		edge.Transparency = 0.15 + math.sin(t * 3) * 0.12
	end)
end
function Kit.price(parent: Instance, amount: number)
	local icon = Kit.image(parent, ShopAssets.coin)
	icon.Position, icon.Size = UDim2.fromScale(0.22, 0.58), UDim2.fromScale(0.16, 0.3)
	local value = Kit.label(parent, tostring(amount), Kit.gold)
	value.Position, value.Size = UDim2.fromScale(0.4, 0.58), UDim2.fromScale(0.48, 0.3)
end
function Kit.stage(parent: Instance, x: number, y: number, w: number, moss: boolean)
	local glow = Kit.image(parent, GearAssets.fx.glow)
	Kit.put(glow, x, y - w, w, w)
	glow.ImageColor3 = if moss then Color3.fromRGB(255, 224, 128) else Color3.fromRGB(255, 128, 32)
	glow.ImageTransparency = 0.5
	for i = 1, 3 do
		local stone = Kit.panel(
			parent,
			if moss and i == 3 then Color3.fromRGB(88, 122, 52) else Color3.fromRGB(65, 70, 68)
		)
		Kit.put(stone, x + (3 - i) * 16, y - i * 16, w - (3 - i) * 32, 48)
		local corner = stone:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0.4, 0)
		end
	end
end
function Kit.wallet(parent: Instance, coins: number, gems: number)
	for index, entry in { { ShopAssets.coin, tostring(coins) }, { ShopAssets.gem, tostring(gems) } } do
		local p = Kit.panel(parent, Color3.fromRGB(70, 29, 12))
		Kit.pill(p)
		p.Name = "Wallet"
		Kit.put(p, if index == 1 then 1352 else 1632, 52, if index == 1 then 264 else 240, 100)
		local i = Kit.image(p, entry[1])
		i.Size = UDim2.fromScale(0.24, 0.8)
		i.Position = UDim2.fromScale(0.04, 0.1)
		local l = Kit.label(p, entry[2])
		l.Position = UDim2.fromScale(0.3, 0.2)
		l.Size = UDim2.fromScale(0.66, 0.6)
	end
end
function Kit.canvas(parent: Instance): Frame
	local c = Instance.new("Frame")
	c.Name = "StationCanvas"
	c.BackgroundTransparency = 1
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.5)
	c.Size = UDim2.fromScale(1, if Device.isPhone() then 0.96 else 1)
	c.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 16 / 9
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.Parent = c
	return c
end
function Kit.paw(parent: Instance)
	local pad = Instance.new("Frame")
	pad.BackgroundColor3 = Kit.slate:Lerp(Kit.white, 0.2)
	pad.BorderSizePixel = 0
	pad.Position = UDim2.fromScale(0.36, 0.44)
	pad.Size = UDim2.fromScale(0.28, 0.28)
	pad.Parent = parent
	for i = 1, 4 do
		local toe = pad:Clone()
		toe.Position =
			UDim2.fromScale(0.18 + (i - 1) * 0.16, if i == 1 or i == 4 then 0.32 else 0.2)
		toe.Size = UDim2.fromScale(0.12, 0.16)
		toe.Parent = parent
	end
	local plus = Kit.label(parent, "+")
	plus.Position, plus.Size = UDim2.fromScale(0.36, 0.44), UDim2.fromScale(0.28, 0.28)
end
--[[ Native Gear surfaces. Kept separate from the existing station kit so
     Blacksmith and Hatchery retain their approved rendering. ]]
function Kit.nativePanel(parent: Instance, colour: Color3?, rivets: boolean?): Frame
	local fill = colour or Color3.fromRGB(38, 40, 48)
	local frame = Instance.new("Frame")
	frame.Name = "NativePanel"
	frame.BackgroundColor3 = fill
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = parent
	rounded(frame, 0.1)
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(232, 176, 40)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = frame
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	-- a UIGradient multiplies the fill, so white (as is) down to grey
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	shade.Parent = frame
	local inset = Instance.new("Frame")
	inset.BackgroundTransparency = 1
	inset.Position, inset.Size = UDim2.fromScale(0.018, 0.04), UDim2.fromScale(0.964, 0.92)
	inset.Parent = frame
	rounded(inset, 0.09)
	local inner = Instance.new("UIStroke")
	inner.Color = Color3.fromRGB(20, 21, 26)
	inner.Parent = inset
	local rivetList: { Frame } = {}
	local function resize()
		local unit = canvasUnit(frame)
		edge.Thickness, inner.Thickness = math.max(1, 7 * unit), math.max(1, 2 * unit)
		-- rivets 16 canvas px square, 10 px in from the corners
		local size = frame.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			local w, h = 16 * unit / size.X, 16 * unit / size.Y
			local mx, my = 10 * unit / size.X, 10 * unit / size.Y
			for i, rivet in rivetList do
				local right, bottom = i == 2 or i == 4, i == 3 or i == 4
				rivet.Size = UDim2.fromScale(w, h)
				rivet.Position = UDim2.fromScale(
					if right then 1 - mx - w else mx,
					if bottom then 1 - my - h else my
				)
			end
		end
	end
	local changed = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	frame.Destroying:Once(function()
		changed:Disconnect()
	end)
	resize()
	if rivets then
		for _ = 1, 4 do
			local rivet = Instance.new("Frame")
			rivet.BackgroundColor3 = Kit.gold
			rivet.BorderSizePixel = 0
			rivet.ZIndex = 4
			rivet.Parent = frame
			rounded(rivet, 0.2)
			local rim = Instance.new("UIStroke")
			rim.Color, rim.Thickness = Color3.fromRGB(95, 53, 10), 1
			rim.Parent = rivet
			table.insert(rivetList, rivet)
		end
		resize()
	end
	return frame
end
function Kit.nativeText(parent: Instance, words: string, colour: Color3?): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = "NativeText"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.88, 0.72)
	text.Position = UDim2.fromScale(0.06, 0.14)
	text.Font = Enum.Font.Arcade
	text.Text = words
	text.TextColor3 = colour or Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 1
	-- TextScaled alone: setting TextWrapped false would switch it back off
	text.TextScaled = true
	text.ZIndex = 6
	local cap = Instance.new("UITextSizeConstraint")
	cap.MinTextSize, cap.MaxTextSize = 1, 96
	cap.Parent = text
	local shadow = text:Clone()
	shadow.Name = "NativeShadow"
	shadow.TextColor3 = Color3.fromRGB(10, 11, 14)
	shadow.ZIndex = 5
	shadow.Parent = parent
	text.Parent = parent
	local function sync()
		local unit = canvasUnit(text)
		local size = if parent:IsA("GuiObject")
			then parent.AbsoluteSize
			else Vector2.new(1920, 1080)
		shadow.Position = text.Position
			+ UDim2.fromScale(3 * unit / math.max(1, size.X), 3 * unit / math.max(1, size.Y))
		shadow.Size, shadow.Text, shadow.Visible = text.Size, text.Text, text.Visible
		shadow.TextXAlignment, shadow.TextYAlignment = text.TextXAlignment, text.TextYAlignment
		shadow.ZIndex = math.max(0, text.ZIndex - 1)
	end
	local changed = text.Changed:Connect(sync)
	text.Destroying:Once(function()
		changed:Disconnect()
		shadow:Destroy()
	end)
	sync()
	return text
end
function Kit.nativePress(frame: Frame, action: () -> ()): TextButton
	local hit = Instance.new("TextButton")
	hit.Font = Enum.Font.Arcade
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.AutoButtonColor = false
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 20
	hit.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local target, held = 1, false
	local connections: { RBXScriptConnection } = {}
	table.insert(
		connections,
		hit.MouseEnter:Connect(function()
			target = 1.035
		end)
	)
	table.insert(
		connections,
		hit.MouseLeave:Connect(function()
			target, held = 1, false
		end)
	)
	table.insert(
		connections,
		hit.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				held = true
				scale.Scale = 0.9
			end
		end)
	)
	table.insert(
		connections,
		hit.InputEnded:Connect(function()
			held = false
		end)
	)
	-- every press clicks (owner, 2026-10-27: "there should also be a sound
	-- whenever you click on anything")
	table.insert(
		connections,
		hit.Activated:Connect(function()
			SoundFx.play("card_click")
			action()
		end)
	)
	Kit.animate(frame, function()
		scale.Scale += ((if held then 0.9 else target) - scale.Scale) * 0.25
	end)
	frame.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	return hit
end
function Kit.nativeButton(parent: Instance, words: string, colour: Color3, action: () -> ()): Frame
	local frame = Kit.nativePanel(parent, colour)
	local edge = frame:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = if colour == Kit.gold then Kit.gold else colour:Lerp(Color3.new(0, 0, 0), 0.4)
	end
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0.02, 0), UDim.new(0.02, 0)
	padding.Parent = frame
	-- the glossy top highlight on buttons only, not on slots and tiles
	gloss(frame, false)
	Kit.nativeText(frame, words, if colour == Kit.gold then Color3.fromRGB(38, 27, 10) else nil)
	Kit.nativePress(frame, action)
	return frame
end
function Kit.nativePaw(parent: Frame)
	for _, box in
		{
			{ 0.35, 0.5, 0.3, 0.28 },
			{ 0.2, 0.3, 0.12, 0.2 },
			{ 0.36, 0.18, 0.12, 0.2 },
			{ 0.52, 0.18, 0.12, 0.2 },
			{ 0.68, 0.3, 0.12, 0.2 },
		}
	do
		local pad = Instance.new("Frame")
		pad.BackgroundColor3 = Color3.fromRGB(88, 94, 108)
		pad.BorderSizePixel = 0
		pad.Position, pad.Size = UDim2.fromScale(box[1], box[2]), UDim2.fromScale(box[3], box[4])
		pad.Parent = parent
		rounded(pad, 0.3)
	end
	local plus = Kit.nativeText(parent, "+")
	plus.Position, plus.Size = UDim2.fromScale(0.36, 0.44), UDim2.fromScale(0.28, 0.42)
end
function Kit.nativeTile(
	parent: Instance,
	rarity: string,
	asset: string,
	locked: boolean,
	fullColour: boolean?
): Frame
	local colour = if locked then Color3.fromRGB(112, 120, 132) else Kit.colour(rarity)
	-- full-colour cards as the owner's reference; locked ones slate grey, not black
	local tile = Kit.nativePanel(
		parent,
		colour:Lerp(
			Color3.new(0, 0, 0),
			if fullColour and not locked then 0.22 elseif fullColour then 0.45 else 0.75
		)
	)
	local edge = tile:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = colour
	end
	if asset ~= "" then
		local icon = Kit.image(tile, asset, locked)
		icon.Position, icon.Size = UDim2.fromScale(0.12, 0.08), UDim2.fromScale(0.76, 0.8)
		icon.ZIndex = 3
	end
	if locked then
		local lock = Kit.image(tile, ShopAssets.lock)
		lock.Position, lock.Size = UDim2.fromScale(0.78, 0.65), UDim2.fromScale(0.17, 0.27)
		lock.ZIndex = 4
	end
	-- The rarity gem is geometry too: no panel or glyph atlas is sampled.
	if asset ~= "" then
		local gem = Instance.new("Frame")
		gem.BackgroundColor3 = colour
		gem.BorderSizePixel = 0
		gem.Position, gem.Size = UDim2.fromScale(0.065, 0.08), UDim2.fromScale(0.12, 0.18)
		gem.Rotation = 45
		gem.ZIndex = 4
		gem.Parent = tile
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = gem
		local facet = Instance.new("UIGradient")
		facet.Color = ColorSequence.new(Color3.new(1, 1, 1), colour)
		facet.Parent = gem
	end
	if not locked and rarity == "Mythic" then
		Kit.rainbowRing(tile)
	elseif not locked and rarity == "Legendary" and edge then
		local glow = Instance.new("Frame")
		glow.BackgroundTransparency = 1
		glow.Position, glow.Size = UDim2.fromScale(-0.015, -0.025), UDim2.fromScale(1.03, 1.05)
		glow.Parent = tile
		rounded(glow, 0.1)
		local halo = Instance.new("UIStroke")
		halo.Color, halo.Thickness = Kit.gold, 3
		halo.Parent = glow
		Kit.animate(tile, function(t)
			halo.Transparency = 0.55 + math.sin(t * 3) * 0.2
			edge.Color = colour:Lerp(Color3.new(1, 1, 1), 0.15 + math.sin(t * 3) * 0.15)
		end)
	end
	return tile
end
function Kit.nativeSlotBadge(parent: Frame, glyph: string)
	local badge = Kit.nativePanel(parent, Color3.fromRGB(32, 34, 44))
	badge.Name = "SlotBadge"
	badge.Position, badge.Size = UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.22, 0.18)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = badge
	local corner = badge:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	Kit.nativeText(badge, glyph)
end
--[[ The guaranteed Mythic's countdown (owner, 2026-10-28: "show a 'Mythic
     guaranteed in N' counter on the crate and egg screens"), gold Arcade
     words at canvas box x, y, w, h; `since` is the profile's pity count. ]]
function Kit.pityLine(parent: Instance, since: number, x: number, y: number, w: number, h: number)
	local left = math.max(1, Pity.EVERY - since)
	local line = Kit.nativeText(
		parent,
		if left == 1 then "NEXT ONE IS A MYTHIC!" else "MYTHIC GUARANTEED IN " .. tostring(left),
		Kit.gold
	)
	line.Name = "PityLine"
	Kit.put(line, x, y, w, h)
	return line
end
return Kit
