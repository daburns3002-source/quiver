--!strict
--[[
	The title screen's picture, "The World Tree at night" (owner, 2026-11-12;
	`Config/TitleScene` has every block and colour, `Util/TitleLayout` where
	they sit on a screen): a night sky with stars and a moon, the World Tree
	huge in the middle with mint lanterns and lit windows, a tiny hero and a
	pet on a dark ridge looking up at it, the gold ARROW BORNE logo with its
	streak of light, slow motes, and the green BEGIN ADVENTURE button.

	Built by hand from flat blocks: plain Frames, with one picture, the soft
	round glow the game already had. No painted or generated art and no live
	3D. `UI/IntroCutscene` shows it on the music's hit and fades it away on
	the press.

	Solid blocks are placed on whole pixels, grown outward, so no hairline
	shows between neighbours; the small lights are placed by share of the
	picture. The logo is laid out in its own points under a UIScale.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Chunky = require(script.Parent.Chunky)
local Config = require(ReplicatedStorage.Shared.Config.TitleScene)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local TitleLayout = require(ReplicatedStorage.Shared.Util.TitleLayout)

local TitleScene = {}

--[[ The one picture the scene draws, for the cutscene to load before the
     cut. ]]
TitleScene.images = { GearAssets.fx.glow }

type Fading = { item: Instance, property: string, base: number }
type Mote = {
	frame: Frame,
	halo: Frame,
	x: number,
	y: number,
	delay: number,
	loop: number,
}

export type Scene = {
	root: Frame,
	view: Vector2,
	design: Config.Design,
	motes: { Mote },
	fading: { Fading },
	shown: number,
	still: boolean,
}

export type Button = {
	group: Frame,
	hit: TextButton,
	scale: UIScale,
	view: Vector2,
	gap: number,
	fading: { Fading },
	shown: number,
	still: boolean,
}

--[[ Whether the player has asked Roblox for less motion: the motes then
     stand still and the button does not pulse. ]]
local function reducedMotion(): boolean
	local ok, reduced = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and reduced == true
end

local function collect(root: Instance, into: { Fading })
	local function note(item: Instance, property: string, base: number)
		if base < 1 then
			table.insert(into, { item = item, property = property, base = base })
		end
	end
	for _, item in root:GetDescendants() do
		if item:IsA("TextLabel") then
			note(item, "TextTransparency", item.TextTransparency)
		elseif item:IsA("ImageLabel") then
			note(item, "ImageTransparency", item.ImageTransparency)
		elseif item:IsA("UIStroke") then
			note(item, "Transparency", item.Transparency)
		elseif item:IsA("Frame") then
			note(item, "BackgroundTransparency", item.BackgroundTransparency)
		end
	end
end

local function fade(list: { Fading }, shown: number)
	for _, entry in list do
		(entry.item :: any)[entry.property] = 1 - (1 - entry.base) * shown
	end
end

local function round(value: number): number
	return math.floor(value + 0.5)
end

local function glowImage(name: string, colour: Color3, alpha: number): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.Image = GearAssets.fx.glow
	image.ImageColor3 = colour
	image.ImageTransparency = 1 - alpha
	image.ScaleType = Enum.ScaleType.Stretch
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	return image
end

--[[ The logo, in its own points inside `holder` (which a UIScale sizes to
     the screen): a faint gold haze, then for each word a soft ring, a hard
     shadow, the near-black outline and the gold face, then the streak of
     light and its arrowhead. ]]
local function buildLogo(holder: Frame, design: Config.Design, at: TitleLayout.Logo)
	local look = Config.logo
	local unit = design.logo.unit
	local z = 0
	local function layer(item: GuiObject)
		z += 1
		item.ZIndex = z
		item.Parent = holder
	end
	local wordsTall = at.lines[#at.lines].top + at.lines[#at.lines].tall - at.top

	local haze = glowImage("Haze", look.glow, look.haze.alpha)
	layer(haze)
	haze.Position = UDim2.fromOffset(round(at.width / 2), round(wordsTall / 2))
	haze.Size =
		UDim2.fromOffset(round(at.width * look.haze.wide), round(wordsTall * look.haze.tall))

	local function word(index: number, name: string, colour: Color3, drop: number): TextLabel
		--[[ The label is exactly one line of the font tall and the word fills
		     it (a TextSize may not pass 100, and BORNE's does). ]]
		local line = at.lines[index]
		local tall = line.size * Config.letterLine
		local label = Instance.new("TextLabel")
		label.Name = `{name}{index}`
		label.BackgroundTransparency = 1
		label.Font = Chunky.font
		label.Text = look.words[index]
		label.TextScaled = true
		label.TextColor3 = colour
		label.Position =
			UDim2.fromOffset(0, round(line.top - at.top + line.tall / 2 - tall / 2 + drop))
		label.Size = UDim2.fromOffset(at.width, round(tall))
		layer(label)
		return label
	end
	local function outlined(label: TextLabel, colour: Color3, thick: number, clear: number)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Color = colour
		stroke.Thickness = thick
		stroke.Transparency = clear
		stroke.Parent = label
	end
	local edge = look.outlineThick * unit
	for ring = #look.glowRings, 1, -1 do
		for index in look.words do
			local soft = word(index, "Glow", look.glow, 0)
			soft.TextTransparency = look.glowRingClear
			outlined(soft, look.glow, edge + look.glowRings[ring] * unit, look.glowRingClear)
		end
	end
	for index in look.words do
		outlined(word(index, "Shadow", look.outline, look.shadowDrop * unit), look.outline, edge, 0)
	end
	for index in look.words do
		outlined(word(index, "Outline", look.outline, 0), look.outline, edge, 0)
	end
	for index in look.words do
		local face = word(index, "Face", Color3.new(1, 1, 1), 0)
		local gold = Instance.new("UIGradient")
		gold.Rotation = 90
		local stops = {}
		for _, stop in look.gold do
			table.insert(stops, ColorSequenceKeypoint.new(stop.at, stop.colour))
		end
		gold.Color = ColorSequence.new(stops)
		gold.Parent = face
	end

	-- the streak: clear at its left end, brightest at its right
	local streak = look.streak
	local left = round(at.streakLeft - at.left)
	local top = round(at.streakTop - at.top)
	local wide = round(at.streakWide)
	local function bar(name: string, colour: Color3, grow: number, clear: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = colour
		frame.Position = UDim2.fromOffset(left, top - grow)
		frame.Size = UDim2.fromOffset(wide, streak.thick + 2 * grow)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local fadeIn = Instance.new("UIGradient")
		fadeIn.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(streak.midAt, clear),
			NumberSequenceKeypoint.new(1, clear),
		})
		fadeIn.Parent = frame
		layer(frame)
		return frame
	end
	bar("StreakGlow", streak.glow, 6, 0.9)
	bar("StreakGlow", streak.glow, 3, 0.8)
	local light = bar("Streak", Color3.new(1, 1, 1), 0, 0)
	local colours = light:FindFirstChildOfClass("UIGradient") :: UIGradient
	colours.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, streak.from),
		ColorSequenceKeypoint.new(streak.midAt, streak.mid),
		ColorSequenceKeypoint.new(1, streak.to),
	})

	-- the arrowhead: a small triangle of thin columns, pointing right
	local head = streak.head
	local tip = left + wide + head.overhang
	local middle = top + streak.thick / 2
	local halo = Instance.new("Frame")
	halo.Name = "HeadGlow"
	halo.BorderSizePixel = 0
	halo.BackgroundColor3 = streak.glow
	halo.BackgroundTransparency = 0.84
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromOffset(tip - head.long / 2, round(middle))
	halo.Size = UDim2.fromOffset(head.long + 8, head.tall + 6)
	local soft = Instance.new("UICorner")
	soft.CornerRadius = UDim.new(0.5, 0)
	soft.Parent = halo
	layer(halo)
	for column = 0, head.long - 1 do
		local half = head.tall / 2 * (1 - column / head.long)
		local piece = Instance.new("Frame")
		piece.Name = "Head"
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = streak.to
		piece.Position = UDim2.fromOffset(tip - head.long + column, round(middle - half))
		piece.Size = UDim2.fromOffset(2, math.max(1, round(2 * half)))
		layer(piece)
	end
end

--[[ Builds the picture into `parent`, which is `view` points in size (the
     whole screen, or a phone-sized frame in a Studio preview). ]]
function TitleScene.build(parent: Instance, view: Vector2): Scene
	local design = TitleLayout.design(view.X, view.Y)
	local fit = TitleLayout.fit(design, view.X, view.Y)
	local k = fit.scale
	local wide, tall = design.width, design.height

	local root = Instance.new("Frame")
	root.Name = "TitleScene"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	root.ZIndex = 3

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(round(fit.x), round(fit.y))
	stage.Size = UDim2.fromOffset(round(wide * k), round(tall * k))
	stage.Parent = root

	-- everything is stacked in the order it is made
	local z = 0
	local function layer(item: GuiObject)
		z += 1
		item.ZIndex = z
		item.Parent = stage
	end
	--[[ A solid block on whole pixels, grown outward to them. ]]
	local function block(name: string, x: number, y: number, w: number, h: number, colour: Color3)
		local x0, y0 = math.floor(x * k), math.floor(y * k)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = colour
		frame.Position = UDim2.fromOffset(x0, y0)
		frame.Size = UDim2.fromOffset(math.ceil((x + w) * k) - x0, math.ceil((y + h) * k) - y0)
		layer(frame)
		return frame
	end
	--[[ A small light, by share of the picture; `alpha` is how solid. ]]
	local function light(
		name: string,
		x: number,
		y: number,
		w: number,
		h: number,
		colour: Color3,
		alpha: number?
	): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = colour
		frame.BackgroundTransparency = 1 - (alpha or 1)
		frame.Position = UDim2.fromScale(x / wide, y / tall)
		frame.Size = UDim2.fromScale(w / wide, h / tall)
		layer(frame)
		return frame
	end

	-- the screen's own edges in layout points, with a little to spare
	local left, right = fit.left - 2, fit.right + 2
	local top, bottom = fit.top - 2, math.max(fit.bottom, tall) + 2

	-- the sky, and more of its darkest above a layout the screen is taller than
	if top < 0 then
		block("SkyAbove", left, top, right - left, 1 - top, Config.sky[1])
	end
	local sky = block("Sky", left, 0, right - left, tall, Color3.new(1, 1, 1))
	local dusk = Instance.new("UIGradient")
	dusk.Rotation = 90
	dusk.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.sky[1]),
		ColorSequenceKeypoint.new(Config.skyMid, Config.sky[2]),
		ColorSequenceKeypoint.new(design.horizon, Config.sky[3]),
		ColorSequenceKeypoint.new(1, Config.sky[4]),
	})
	dusk.Parent = sky

	for _, star in TitleLayout.stars(design, fit) do
		light("Star", star.x, star.y, star.size, star.size, Config.star, star.alpha)
	end
	local moon = Config.moon
	local disc =
		light("Moon", design.moon.x, design.moon.y, moon.size, moon.size, moon.colour, moon.alpha)
	local curve = Instance.new("UICorner")
	curve.CornerRadius = UDim.new(moon.corner / moon.size, 0)
	curve.Parent = disc

	-- the soft light behind the crown
	local tree = design.tree
	local u = tree.unit
	local glow = glowImage("Glow", Config.glow.colour, Config.glow.alpha)
	layer(glow)
	glow.Position = UDim2.fromScale(tree.x / wide, (tree.y - Config.glow.rise * u) / tall)
	glow.Size =
		UDim2.fromScale(2 * Config.glow.radius * u / wide, 2 * Config.glow.radius * u / tall)

	-- far hills, again to either side on a screen wider than the layout
	for shift = -1, 1 do
		for _, hill in design.hills do
			local x = hill[1] + shift * wide
			if x + hill[3] > left and x < right then
				block("Hill", x, hill[2], hill[3], Config.hill.tall, Config.hill.colour)
			end
		end
	end
	local groundTop = tree.y - Config.ground.above
	block(
		"Ground",
		left,
		groundTop,
		right - left,
		math.max(design.groundTall, bottom - groundTop),
		Config.ground.colour
	)

	-- the World Tree
	local shape = Config.tree
	local function onTree(name: string, part: { number }, colour: Color3)
		block(name, tree.x + part[1] * u, tree.y + part[2] * u, part[3] * u, part[4] * u, colour)
	end
	for _, part in shape.trunk do
		onTree("Trunk", part, shape.trunkColour)
	end
	for index, square in shape.crown do
		local x, y, side = square[1], square[2], square[3]
		onTree("Crown", { x, y, side, side }, shape.crownColours[(index - 1) % 2 + 1])
		onTree("CrownLit", { x, y, side, side * shape.crownStrip }, shape.crownLit)
		local patch = shape.crownPatch
		light(
			"CrownPatch",
			tree.x + (x + side * patch.x) * u,
			tree.y + (y + side * patch.y) * u,
			side * patch.w * u,
			side * patch.h * u,
			shape.crownLit,
			patch.alpha
		)
	end
	for _, lantern in shape.lanterns do
		local x, y, side = lantern[1], lantern[2], lantern[3]
		light(
			"LanternHalo",
			tree.x + (x - side) * u,
			tree.y + (y - side) * u,
			side * 3 * u,
			side * 3 * u,
			shape.lanternHalo,
			shape.lanternHaloAlpha
		)
		light("Lantern", tree.x + x * u, tree.y + y * u, side * u, side * u, shape.lantern)
	end
	for _, window in shape.windows do
		local x, y = tree.x + window[1] * u, tree.y + window[2] * u
		light(
			"WindowHalo",
			x - 3 * u,
			y - 3 * u,
			14 * u,
			16 * u,
			shape.windowHalo,
			shape.windowHaloAlpha
		)
		light("Window", x, y, 8 * u, 10 * u, shape.window)
	end

	--[[ The near ridge: its base runs to the bottom of the screen, and a
	     step that touches the layout's side runs on to the screen's. ]]
	for index, step in design.ridge do
		local x, y, w, h = step[1], step[2], step[3], step[4]
		local x1 = if x + w >= wide then right else x + w
		local x0 = if x <= 0 then left else x
		block("Ridge", x0, y, x1 - x0, if index == 1 then bottom - y else h, Config.ridge)
	end

	-- the hero from behind, bow across the back, and the pet at their heel
	local function figure(
		name: string,
		at: { x: number, y: number, unit: number },
		body: { Config.Block },
		rims: { Config.Block }
	)
		for _, part in body do
			block(
				name,
				at.x + part[1] * at.unit,
				at.y + part[2] * at.unit,
				part[3] * at.unit,
				part[4] * at.unit,
				Config.figure
			)
		end
		for _, rim in rims do
			light(
				`{name}Rim`,
				at.x + rim[1] * at.unit,
				at.y + rim[2] * at.unit,
				rim[3] * at.unit,
				rim[4] * at.unit,
				Config.rim,
				rim[5]
			)
		end
	end
	local hero, bow = design.hero, Config.hero.bow
	for _, piece in TitleLayout.curve(bow.from, bow.bend, bow.to, bow.pieces) do
		local frame = Instance.new("Frame")
		frame.Name = "Bow"
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Config.figure
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(
			(hero.x + piece.x * hero.unit) / wide,
			(hero.y + piece.y * hero.unit) / tall
		)
		frame.Size = UDim2.fromOffset(
			math.ceil(piece.long * hero.unit * k) + 1,
			math.max(1, round(bow.thick * hero.unit * k))
		)
		frame.Rotation = piece.turn
		layer(frame)
	end
	figure("Hero", hero, Config.hero.body, Config.hero.rims)
	figure("Pet", design.pet, Config.pet.body, Config.pet.rims)

	local fading: { Fading } = {}
	local logoAt = TitleLayout.logo(design)

	-- the motes, over the picture and under the logo
	local motes: { Mote } = {}
	local look = Config.mote
	for _, mote in TitleLayout.motes(design) do
		local function square(name: string, side: number): Frame
			local frame = Instance.new("Frame")
			frame.Name = name
			frame.BorderSizePixel = 0
			frame.BackgroundColor3 = look.colour
			frame.BackgroundTransparency = 1
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Size =
				UDim2.fromOffset(math.max(1, round(side * k)), math.max(1, round(side * k)))
			layer(frame)
			return frame
		end
		table.insert(motes, {
			halo = square("MoteHalo", mote.size * look.haloSize),
			frame = square("Mote", mote.size),
			x = mote.x + mote.size / 2,
			y = mote.y + mote.size / 2,
			delay = mote.delay,
			loop = mote.loop,
		})
	end

	--[[ The logo's own points are scaled inside a holder that is placed in
	     pixels, so the scale sizes the logo and never moves it. ]]
	local logoHolder = Instance.new("Frame")
	logoHolder.Name = "LogoHolder"
	logoHolder.BackgroundTransparency = 1
	logoHolder.Position = UDim2.fromOffset(round(logoAt.left * k), round(logoAt.top * k))
	logoHolder.Size =
		UDim2.fromOffset(round(logoAt.width * k), round((logoAt.bottom - logoAt.top) * k))
	layer(logoHolder)
	local logo = Instance.new("Frame")
	logo.Name = "Logo"
	logo.BackgroundTransparency = 1
	logo.Size = UDim2.fromOffset(logoAt.width, math.ceil(logoAt.bottom - logoAt.top))
	logo.Parent = logoHolder
	local size = Instance.new("UIScale")
	size.Scale = k
	size.Parent = logo
	buildLogo(logo, design, logoAt)

	collect(root, fading)
	-- the motes fade on their own loops (`step`)
	for index = #fading, 1, -1 do
		local name = fading[index].item.Name
		if name == "Mote" or name == "MoteHalo" then
			table.remove(fading, index)
		end
	end

	root.Parent = parent
	local scene: Scene = {
		root = root,
		view = view,
		design = design,
		motes = motes,
		fading = fading,
		shown = 1,
		still = reducedMotion(),
	}
	TitleScene.step(scene, 0, 1)
	return scene
end

--[[ Poses the picture `t` seconds after it appeared; `shown` is 1 until
     BEGIN ADVENTURE is pressed, then down to 0 as the title leaves. ]]
function TitleScene.step(scene: Scene, t: number, shown: number)
	if shown ~= scene.shown then
		scene.shown = shown
		fade(scene.fading, shown)
	end
	local look = Config.mote
	local wide, tall = scene.design.width, scene.design.height
	for _, mote in scene.motes do
		local share = if scene.still then look.ease else ((t + mote.delay) / mote.loop) % 1
		local alpha = TitleLayout.moteAlpha(share) * shown
		local drift = if scene.still then 0 else share
		local at = UDim2.fromScale(
			(mote.x + look.drift.x * drift) / wide,
			(mote.y + look.drift.y * drift) / tall
		)
		mote.frame.Position = at
		mote.frame.BackgroundTransparency = 1 - alpha
		mote.halo.Position = at
		mote.halo.BackgroundTransparency = 1 - alpha * look.haloAlpha
	end
end

--[[
	BEGIN ADVENTURE: the kit's green "go" button (`Chunky.button`, so it takes
	whatever colours the kit gives that role) with a small play triangle left
	of its words and the kit's shine, sitting `gap` above the bottom of
	`parent`. `scale` on the returned button is its pulse.
]]
function TitleScene.button(parent: Instance, view: Vector2, words: string, action: () -> ()): Button
	local design = TitleLayout.design(view.X, view.Y)
	local at = TitleLayout.button(design, TitleLayout.fit(design, view.X, view.Y))
	local look = Config.button

	local group = Instance.new("Frame")
	group.Name = "BeginAdventure"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 1)
	group.Position = UDim2.new(0.5, 0, 1, -round(at.gap))
	group.Size = UDim2.fromOffset(round(at.width), round(at.height))
	group.ZIndex = 20
	group.Parent = parent

	local sheet = Chunky.pointSheet(group, design.button.width, design.button.height)
	local holder = Chunky.button(sheet, words, Chunky.green, 0, 0, sheet.w, sheet.h, action)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local hit = holder:FindFirstChildWhichIsA("TextButton", true) :: TextButton
	local label = holder:FindFirstChild("Words", true) :: TextLabel
	local face = label.Parent :: Frame

	--[[ The words at the reference's size with the triangle to their left,
	     the pair centred on the face; smaller only if they would not fit. ]]
	local faceWide, faceTall = at.width, at.height * face.Size.Y.Scale
	-- the letters' own size, and the line Roblox measures a TextSize by
	local letters = at.words
	local line = math.max(1, round(letters * Config.letterLine))
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(words, line, Chunky.font, Vector2.new(1e4, 1e4))
	end)
	local wordsWide = if ok then bounds.X else letters * #words * 0.62
	local iconWide, gap = look.icon.wide * letters, look.icon.gap * letters
	local room = faceWide * 0.9
	local shrink = math.min(1, room / (iconWide + gap + wordsWide))
	line = math.max(1, math.floor(line * shrink))
	letters *= shrink
	iconWide, gap, wordsWide = iconWide * shrink, gap * shrink, wordsWide * shrink
	local start = (faceWide - (iconWide + gap + wordsWide)) / 2
	local slack = wordsWide * 0.04
	label.Position = UDim2.fromScale((start + iconWide + gap - slack) / faceWide, 0.16)
	label.Size = UDim2.fromScale((wordsWide + 2 * slack) / faceWide, 0.66)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = line
	limit.Parent = label

	local icon = Instance.new("Frame")
	icon.Name = "Play"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(start / faceWide, 0.49)
	icon.Size = UDim2.fromScale(iconWide / faceWide, look.icon.tall * letters / faceTall)
	icon.ZIndex = label.ZIndex
	icon.Parent = face
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local columns = 12
	local function triangle(colour: Color3, growX: number, growY: number, z: number)
		for column = 0, columns - 1 do
			local high = math.max(0.1, 1 - column / columns)
			local piece = Instance.new("Frame")
			piece.Name = "Column"
			piece.BorderSizePixel = 0
			piece.BackgroundColor3 = colour
			piece.Position = UDim2.fromScale(column / columns - growX, (1 - high) / 2 - growY)
			piece.Size = UDim2.fromScale(1.4 / columns + 2 * growX, high + 2 * growY)
			piece.ZIndex = z
			piece.Parent = icon
		end
	end
	if stroke and stroke.Enabled then
		-- the words' own dark edge, round the triangle too
		local thick = letters * 0.085
		triangle(stroke.Color, thick / iconWide, thick / (look.icon.tall * letters), label.ZIndex)
	end
	triangle(label.TextColor3, 0, 0, label.ZIndex + 1)

	local still = reducedMotion()
	if not still then
		Chunky.gleam(face)
	end

	local fading: { Fading } = {}
	collect(group, fading)
	return {
		group = group,
		hit = hit,
		scale = scale,
		view = view,
		gap = round(at.gap),
		fading = fading,
		shown = 1,
		still = still,
	}
end

--[[ Poses the button: `rise` 0 to 1 as it comes up from under the screen,
     `shown` as for the picture, `pulsing` while it waits to be pressed. ]]
function TitleScene.poseButton(
	button: Button,
	t: number,
	rise: number,
	shown: number,
	pulsing: boolean
)
	button.group.Visible = rise > 0 and shown > 0
	button.group.Position = UDim2.new(0.5, 0, 1 + 0.25 * (1 - rise), -button.gap)
	local pulse = if pulsing and not button.still then TitleLayout.pulse(t) else 1
	button.scale.Scale = pulse * (0.9 + 0.1 * shown)
	button.hit.Active = pulsing
	if shown ~= button.shown then
		button.shown = shown
		fade(button.fading, shown)
	end
end

return TitleScene
