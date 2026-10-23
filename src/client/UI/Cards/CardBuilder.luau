--!strict
--[[
	Builds one upgrade card, as the owner's card design draws it
	(design_handoff_upgrade_cards; README "The card").

	Built at the design's own size, 134 x 330 pixels, and scaled as a whole
	by whoever places it. Layers back to front:

	1. the rarity's crystal shards, behind the card;
	2. a glow, for Legendary and Mythic;
	3. a hard shadow, then the body with its gradient and bevel;
	4. the frame's parts — bezel, lines, diamonds, gems, sparkles;
	5. a shine band;
	6. the content: rarity, icon, level chip, name, stat, description, pips.

	The frame comes from `Config/CardFrames`, which is the design's own data,
	so this file knows how to draw each *kind* of part and nothing about which
	tier has which. Presentation only: a card does not know what an ability
	does, only what it says.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local CardFrames = require(ReplicatedStorage.Shared.Config.CardFrames)
local CardTheme = require(ReplicatedStorage.Shared.Config.CardTheme)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local CardBuilder = {}

export type State = "Default" | "Maxed" | "Locked"

export type Options = {
	--[[ Levels already held; 0 for a skill not yet owned. ]]
	level: number,
	state: State?,
	lockText: string?,
}

export type Card = {
	root: Frame,
	--[[ The parts that move with the pointer and the clock: the shine
	     band's offset, and the Mythic's embers and glow. ]]
	setShine: (offset: number, strength: number) -> (),
	--[[ The selected card's white outline. ]]
	setSelected: (selected: boolean) -> (),
	step: (time: number) -> (),
	destroy: () -> (),
}

type Paint = { color: Color3, transparency: number }

local INK = CardTheme.colors.ink
local WHITE = CardTheme.colors.white
local SIZE = CardTheme.card.size

--[[ Z layers inside a card. Sibling ZIndex, so these only order a card's
     own pieces. ]]
local Z = {
	backGlow = 1,
	shards = 2,
	glow = 3,
	shadow = 4,
	body = 5,
	frame = 7,
	shine = 9,
	content = 10,
	sticker = 12,
	scrim = 14,
	selection = 16,
}

local function frame(parent: Instance, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function round(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function fill(f: Frame, p: Paint)
	f.BackgroundColor3 = p.color
	f.BackgroundTransparency = p.transparency
end

--[[ A frame centred on a point of the card, `size` across. ]]
local function centred(
	parent: Instance,
	name: string,
	z: number,
	x: number,
	y: number,
	w: number,
	h: number
): Frame
	local f = frame(parent, name, z)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	return f
end

local function image(parent: Instance, name: string, z: number, asset: string, p: Paint): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = asset
	i.ImageColor3 = p.color
	i.ImageTransparency = p.transparency
	i.ZIndex = z
	i.Parent = parent
	return i
end

--[[ A soft glow behind something: the radial image, tinted, `size` across. ]]
local function glowAt(
	parent: Instance,
	z: number,
	x: number,
	y: number,
	size: number,
	colour: Color3,
	transparency: number
): ImageLabel
	local g =
		image(parent, "Glow", z, CardAssets.glow, { color = colour, transparency = transparency })
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromOffset(x, y)
	g.Size = UDim2.fromOffset(size, size)
	return g
end

--[[
	Text with an ink outline: a TextLabel and a Contextual UIStroke, which is
	how the design's stroked type comes out in Roblox.
]]
local function label(
	parent: Instance,
	name: string,
	text: string,
	font: Enum.Font,
	size: number,
	colour: Color3,
	strokeWidth: number,
	strokeTransparency: number?
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = font
	t.Text = text
	t.TextSize = size
	t.TextColor3 = colour
	t.TextWrapped = true
	t.ZIndex = Z.content
	t.Parent = parent

	if strokeWidth > 0 then
		local s = Instance.new("UIStroke")
		s.Color = INK
		s.Thickness = strokeWidth
		s.Transparency = strokeTransparency or 0
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = t
	end

	return t
end

--[[
	Breaks `text` into lines once, at the card's own size, and returns them
	joined with newlines.

	The card is scaled when it is picked, and Roblox re-wraps scaled text:
	at 1.05 the same description fell onto different lines than at 1.
	Breaking the lines here, and turning wrapping off, keeps every card's
	words exactly where they were printed whatever the card is doing.
]]
local function lines(text: string, font: Enum.Font, size: number, width: number): string
	local out: { string } = {}
	local current = ""
	for word in string.gmatch(text, "%S+") do
		local trial = if current == "" then word else current .. " " .. word
		local measured = TextService:GetTextSize(trial, size, font, Vector2.new(10000, 1000))
		if measured.X > width and current ~= "" then
			table.insert(out, current)
			current = word
		else
			current = trial
		end
	end
	if current ~= "" then
		table.insert(out, current)
	end
	return table.concat(out, "\n")
end

--[[
	A crystal shard behind the card.

	Roblox turns a GuiObject about its own centre, but a shard turns about
	its base. So each one sits in a transparent pivot frame twice its height,
	centred on the base point, with the shard filling the top half: turning
	the pivot then turns the shard about its base. An ink copy a little
	larger behind it is the outline.
]]
local function shard(parent: Instance, spec: any)
	local w, h = spec.w, spec.h
	local pivot = centred(parent, "Shard", Z.shards, spec.baseX, spec.baseY, w + 7, (h + 7) * 2)
	pivot.Rotation = spec.rot

	local outline =
		image(pivot, "Outline", Z.shards, CardAssets.shard, { color = INK, transparency = 0 })
	outline.AnchorPoint = Vector2.new(0.5, 1)
	outline.Position = UDim2.new(0.5, 0, 0.5, 4)
	outline.Size = UDim2.fromOffset(w + 7, h + 7)

	local body = image(pivot, "Fill", Z.shards, CardAssets.shard, spec.fill)
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromOffset(w, h)

	local facet = image(pivot, "Facet", Z.shards, CardAssets.shardFacet, spec.facet)
	facet.AnchorPoint = Vector2.new(0.5, 1)
	facet.Position = UDim2.fromScale(0.5, 0.5)
	facet.Size = UDim2.fromOffset(w, h)
end

--[[ A ring `inset` pixels inside the card's edge (outside, if negative),
     `thickness` wide: a frame on the ring's inner edge, stroked outward. ]]
local function ring(
	parent: Instance,
	name: string,
	z: number,
	inset: number,
	thickness: number,
	radius: number,
	p: Paint
)
	local inner = inset + thickness
	local f = frame(parent, name, z)
	f.Position = UDim2.fromOffset(inner, inner)
	f.Size = UDim2.new(1, -inner * 2, 1, -inner * 2)
	corner(f, math.max(radius - thickness, 2))
	stroke(f, p.color, thickness, p.transparency)
	return f
end

local function bezel(parent: Instance, part: any)
	local inset, thickness, radius = part.inset, part.thickness, part.radius
	-- Outer outline first, then the metal over it, then the inner outline.
	ring(
		parent,
		"BezelOuter",
		Z.frame,
		inset - part.outerOutline.width,
		thickness + part.outerOutline.width,
		radius + 2,
		part.outerOutline.paint
	)
	ring(parent, "Bezel", Z.frame + 1, inset, thickness, radius, part.color)
	ring(
		parent,
		"BezelInner",
		Z.frame + 1,
		inset + thickness,
		part.innerOutline.width,
		radius - thickness,
		part.innerOutline.paint
	)
end

--[[ A square turned 45°, `size` across corner to corner of its sides, with an
     ink outline counted inside that size as the design's borders are. ]]
local function diamond(
	parent: Instance,
	name: string,
	z: number,
	x: number,
	y: number,
	size: number,
	paint: Paint,
	outline: any?
)
	local width = if outline then outline.width else 0
	local d = centred(parent, name, z, x, y, size - width * 2, size - width * 2)
	fill(d, paint)
	d.Rotation = 45
	if outline then
		stroke(d, outline.paint.color, outline.width, outline.paint.transparency)
	end
	return d
end

local function gem(
	parent: Instance,
	name: string,
	z: number,
	x: number,
	y: number,
	size: number,
	part: any
)
	local width = if part.outline then part.outline.width else 0
	local g = centred(parent, name, z, x, y, size - width * 2, size - width * 2)
	fill(g, part.fill)
	round(g)
	if part.outline then
		stroke(g, part.outline.paint.color, width, part.outline.paint.transparency)
	end

	--[[ The design's inner shade — darker toward the bottom right — as a
	     gradient, since Roblox has no inset shadow. ]]
	if part.innerShade then
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 45
		gradient.Color = ColorSequence.new(WHITE, Color3.new(0.78, 0.78, 0.78))
		gradient.Parent = g
	end

	if part.highlight then
		local h = part.highlight
		local spot = centred(
			parent,
			name .. "Highlight",
			z + 1,
			x + h.offset[1],
			y - size / 4 + 2 + h.offset[2] + 2,
			h.size,
			h.size
		)
		fill(spot, h.color)
		round(spot)
	end

	return g
end

--[[ A diamond with a coloured ring inside its outline and a glowing dot at
     its heart: the Mythic's corner and side jewels. ]]
local function jewel(parent: Instance, name: string, x: number, y: number, part: any)
	local d = diamond(parent, name, Z.frame + 2, x, y, part.size, part.fill, part.outline)
	if part.ring then
		local r = centred(parent, name .. "Ring", Z.frame + 3, x, y, part.size - 10, part.size - 10)
		r.Rotation = 45
		stroke(r, part.ring.paint.color, part.ring.width, part.ring.paint.transparency)
	end
	if part.innerDot then
		local dot = part.innerDot
		if dot.glow then
			glowAt(parent, Z.frame + 2, x, y, dot.size * 2.6, dot.color.color, 0.35)
		end
		local inner = centred(parent, name .. "Dot", Z.frame + 4, x, y, dot.size, dot.size)
		fill(inner, dot.color)
		inner.Rotation = 45
	end
	return d
end

local CORNERS = { { 0, 0, -1, -1 }, { 1, 0, 1, -1 }, { 0, 1, -1, 1 }, { 1, 1, 1, 1 } }

--[[ Draws one frame part. Returns anything that animates. ]]
local function drawPart(card: Frame, part: any, animated: { any })
	local kind = part.kind
	local w, h = SIZE.X, SIZE.Y

	if kind == "bezel" then
		bezel(card, part)
	elseif kind == "line" then
		ring(card, "Line", Z.frame + 1, part.inset, part.thickness, part.radius, part.color)
	elseif kind == "cornerDiamonds" then
		for _, c in CORNERS do
			local x = c[1] * w + c[3] * -part.centerOffset
			local y = c[2] * h + c[4] * -part.centerOffset
			if part.ring or part.innerDot then
				jewel(card, "CornerJewel", x, y, part)
			else
				diamond(
					card,
					"CornerDiamond",
					Z.frame + 2,
					x,
					y,
					part.size,
					part.fill,
					part.outline
				)
			end
		end
	elseif kind == "sideGems" then
		for _, x in { 0, w } do
			gem(card, "SideGem", Z.frame + 2, x + (part.centerOffset or 0), h / 2, part.size, part)
		end
	elseif kind == "sideDiamonds" then
		for _, x in { 0, w } do
			jewel(card, "SideJewel", x, h / 2, part)
		end
	elseif kind == "topGem" then
		gem(card, "TopGem", Z.frame + 3, w / 2, part.centerY, part.size, part)
	elseif kind == "bottomDiamond" then
		if part.glow then
			glowAt(
				card,
				Z.frame + 1,
				w / 2,
				part.centerY,
				part.glow.width * 3,
				part.glow.paint.color,
				0.3
			)
		end
		diamond(
			card,
			"BottomDiamond",
			Z.frame + 2,
			w / 2,
			part.centerY,
			part.size,
			part.fill,
			part.outline
		)
	elseif kind == "topEye" then
		local x, y, s = w / 2, part.centerY, part.size
		if part.glow then
			glowAt(card, Z.frame + 1, x, y, s + part.glow.width * 2.5, part.glow.paint.color, 0.2)
		end
		-- Rings outermost first: ink, then red, then the dark eye itself.
		local radius = s
		for index = #part.rings, 1, -1 do
			local r = part.rings[index]
			local band = centred(card, "EyeRing", Z.frame + 2, x, y, radius, radius)
			round(band)
			stroke(band, r.paint.color, r.width, r.paint.transparency)
			radius -= r.width * 2
		end
		local eye = centred(
			card,
			"Eye",
			Z.frame + 3,
			x,
			y,
			s - part.outline.width * 2,
			s - part.outline.width * 2
		)
		fill(eye, part.fill)
		round(eye)
		stroke(eye, part.outline.paint.color, part.outline.width)
		local iris = centred(card, "Iris", Z.frame + 4, x, y, part.iris.size, part.iris.size)
		fill(iris, part.iris.color)
		round(iris)
		local pupil = centred(card, "Pupil", Z.frame + 5, x, y, part.pupil.w, part.pupil.h)
		fill(pupil, part.pupil.color)
		round(pupil)
	elseif kind == "sparkles" then
		for _, item in part.items do
			local cx, cy = item.x + item.size / 2, item.y + item.size / 2
			glowAt(card, Z.frame, cx, cy, item.size * 3, part.glow.color, 0.35)
			local s = centred(card, "Sparkle", Z.frame + 1, cx, cy, item.size, item.size)
			fill(s, part.fill)
			s.Rotation = if part.rotated45 then 45 else 0
		end
	elseif kind == "cardGlow" then
		local extend = part.extendsPx
		local left = if extend then extend.left else 54
		local right = if extend then extend.right else 54
		local top = if extend then extend.top else 54
		local bottom = if extend then extend.bottom else 54
		local glow = image(card, "CardGlow", Z.backGlow, CardAssets.glow, {
			color = part.color.color,
			transparency = 0.25,
		})
		glow.Position = UDim2.fromOffset(-left, -top)
		glow.Size = UDim2.new(1, left + right, 1, top + bottom)
		if part.pulse then
			table.insert(animated, { kind = "pulse", glow = glow })
		end
	elseif kind == "orbitEmbers" then
		local embers = {}
		for index = 1, part.count do
			local size = if index % 3 == 1 then 12 else 8
			local ember = centred(card, "Ember", Z.content + 1, 0, 0, size - 4, size - 4)
			fill(ember, part.fill)
			ember.Rotation = 45
			stroke(ember, part.outline.paint.color, part.outline.width)
			table.insert(embers, ember)
		end
		table.insert(animated, { kind = "embers", embers = embers, part = part })
	end
end

--[[ The pips along the bottom: one per level, owned white, the one this card
     would give half white, the rest dark. A skill with a single level says
     "UNIQUE" instead. ]]
local function pips(parent: Instance, ability: Abilities.Ability, level: number, maxed: boolean)
	local row = frame(parent, "Pips", Z.content)
	row.LayoutOrder = 99
	row.Size = UDim2.fromOffset(SIZE.X - 16, 14)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, CardTheme.card.pipGap)
	layout.Parent = row

	if #ability.levels == 1 then
		local unique = label(row, "Unique", "UNIQUE", CardTheme.fonts.display, 12, WHITE, 3)
		unique.Size = UDim2.fromOffset(80, 14)
		return
	end

	local pip = CardTheme.card.pip
	local width = CardTheme.card.pipStroke
	for index = 1, #ability.levels do
		local p = frame(row, "Pip", Z.content)
		p.LayoutOrder = index
		p.Size = UDim2.fromOffset(pip.X - width * 2, pip.Y - width * 2)
		corner(p, 4)
		stroke(p, INK, width)
		if maxed or index <= level then
			fill(p, { color = WHITE, transparency = 0 })
		elseif index == level + 1 then
			fill(p, { color = WHITE, transparency = 0.55 })
		else
			fill(p, { color = Color3.new(0, 0, 0), transparency = 0.75 })
		end
	end
end

--[[
	Builds the card for `abilityId` at the player's current `level` of it.

	The stat shown is the one the next level would give, as the design says:
	`stats[level + 1]`. A maxed card shows its top level.
]]
function CardBuilder.build(abilityId: string, options: Options): Card
	local ability = Abilities.byId[abilityId]
	assert(ability, `no ability {abilityId}`)

	local rarity = Rarities.byName[ability.rarity]
	local tier = CardFrames.tiers[ability.rarity]
	local level = options.level
	local state: State = options.state or "Default"
	local top = #ability.levels
	local maxed = state == "Maxed" or level >= top
	local nextLevel = math.min(level + 1, top)

	local root = frame(nil :: any, "Card", 1)
	root.Size = UDim2.fromOffset(SIZE.X, SIZE.Y)

	local animated: { any } = {}

	local margin = CardTheme.card.sideCrystalMargin
	for _, spec in tier.shards do
		local onSide = spec.baseY > margin and spec.baseY < SIZE.Y - margin
		if not onSide then
			shard(root, spec)
		end
	end

	-- The hard shadow: the card's shape in ink, seven pixels down.
	local shadow = frame(root, "Shadow", Z.shadow)
	shadow.Position = UDim2.fromOffset(0, CardTheme.card.shadowOffset)
	shadow.Size = UDim2.fromScale(1, 1)
	fill(shadow, { color = INK, transparency = 0 })
	corner(shadow, CardTheme.card.corner)

	local body = frame(root, "Body", Z.body)
	body.Size = UDim2.fromScale(1, 1)
	fill(body, { color = WHITE, transparency = 0 })
	corner(body, CardTheme.card.corner)
	stroke(body, INK, CardTheme.card.stroke)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rarity.light),
		ColorSequenceKeypoint.new(0.45, rarity.color),
		ColorSequenceKeypoint.new(1, rarity.dark),
	})
	gradient.Parent = body

	-- The bevel: a lit top lip and a shaded bottom one.
	local lip = frame(body, "TopLip", Z.body + 1)
	lip.Position = UDim2.fromOffset(6, 0)
	lip.Size = UDim2.new(1, -12, 0, 4)
	fill(lip, { color = WHITE, transparency = 0.65 })
	corner(lip, 2)
	local base = frame(body, "BottomLip", Z.body + 1)
	base.AnchorPoint = Vector2.new(0, 1)
	base.Position = UDim2.new(0, 6, 1, 0)
	base.Size = UDim2.new(1, -12, 0, 8)
	fill(base, { color = Color3.new(0, 0, 0), transparency = 0.82 })
	corner(base, 4)

	for _, part in tier.parts do
		drawPart(root, part, animated)
	end

	-- The shine: a white band across the card at 115°, faint until hovered.
	local shine = frame(root, "Shine", Z.shine)
	shine.Size = UDim2.fromScale(1, 1)
	fill(shine, { color = WHITE, transparency = 0 })
	corner(shine, 14)
	local band = Instance.new("UIGradient")
	band.Rotation = 115 - 90
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.58),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Parent = shine

	-- Content, top to bottom.
	local content = frame(root, "Content", Z.content)
	content.Size = UDim2.fromScale(1, 1)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, CardTheme.card.paddingTop)
	padding.PaddingBottom = UDim.new(0, CardTheme.card.paddingBottom)
	padding.PaddingLeft = UDim.new(0, CardTheme.card.paddingSide)
	padding.PaddingRight = UDim.new(0, CardTheme.card.paddingSide)
	padding.Parent = content
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 0)
	list.Parent = content

	local inner = SIZE.X - CardTheme.card.paddingSide * 2

	local rarityLabel = label(
		content,
		"Rarity",
		string.upper(ability.rarity),
		CardTheme.fonts.display,
		CardTheme.card.rarityText,
		WHITE,
		CardTheme.card.rarityStroke
	)
	rarityLabel.LayoutOrder = 1
	rarityLabel.Size = UDim2.fromOffset(inner, 18)

	-- The icon medallion: a white disc with an ink ring and the icon in it.
	local medallionSize = CardTheme.card.medallion
	local holder = frame(content, "MedallionHolder", Z.content)
	holder.LayoutOrder = 2
	holder.Size = UDim2.fromOffset(medallionSize, medallionSize + 8)
	local medallion = frame(holder, "Medallion", Z.content)
	medallion.AnchorPoint = Vector2.new(0.5, 1)
	medallion.Position = UDim2.fromScale(0.5, 1)
	local ringWidth = CardTheme.card.medallionStroke
	medallion.Size = UDim2.fromOffset(medallionSize - ringWidth * 2, medallionSize - ringWidth * 2)
	fill(medallion, { color = WHITE, transparency = 0 })
	round(medallion)
	stroke(medallion, INK, ringWidth)
	local icon = image(
		medallion,
		"Icon",
		Z.content + 1,
		CardAssets.icons[ability.icon] or "",
		{ color = WHITE, transparency = 0 }
	)
	icon.Size = UDim2.fromScale(1, 1)
	round(icon)

	--[[ The level chip, overlapping the medallion: what this pick takes you
	     from and to. Gold on the last level. ]]
	local hasChip = level > 0 and not maxed and state ~= "Locked"
	local chipHolder = frame(content, "ChipHolder", Z.content + 2)
	chipHolder.LayoutOrder = 3
	chipHolder.Size = UDim2.fromOffset(inner, if hasChip then 8 else 0)
	if hasChip then
		local last = level + 1 == top
		local chip = label(
			chipHolder,
			"Chip",
			`LVL {level} → {level + 1}{if last then " · MAX" else ""}`,
			CardTheme.fonts.display,
			11,
			INK,
			0
		)
		chip.AnchorPoint = Vector2.new(0.5, 0)
		chip.Position = UDim2.new(0.5, 0, 0, -12)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, 17)
		chip.TextWrapped = false
		chip.BackgroundTransparency = 0
		chip.BackgroundColor3 = if last then CardTheme.colors.gold else WHITE
		chip.ZIndex = Z.content + 3
		corner(chip, 8)
		stroke(chip, INK, 3)
		local chipPadding = Instance.new("UIPadding")
		chipPadding.PaddingLeft = UDim.new(0, 8)
		chipPadding.PaddingRight = UDim.new(0, 8)
		chipPadding.Parent = chip
	end

	local name = label(
		content,
		"Name",
		lines(ability.name, CardTheme.fonts.display, CardTheme.card.nameText, inner - 6),
		CardTheme.fonts.display,
		CardTheme.card.nameText,
		WHITE,
		CardTheme.card.nameStroke
	)
	name.TextWrapped = false
	name.LayoutOrder = 4
	name.Size = UDim2.fromOffset(inner, 46)

	-- The stat pill: what the next level gives.
	local statHolder = frame(content, "StatHolder", Z.content)
	statHolder.LayoutOrder = 5
	statHolder.Size = UDim2.fromOffset(inner, 26)
	local stat = label(
		statHolder,
		"Stat",
		ability.stats[if maxed then top else nextLevel],
		CardTheme.fonts.body,
		CardTheme.card.statText,
		WHITE,
		0
	)
	stat.AnchorPoint = Vector2.new(0.5, 0.5)
	stat.Position = UDim2.fromScale(0.5, 0.5)
	stat.AutomaticSize = Enum.AutomaticSize.X
	stat.Size = UDim2.fromOffset(0, 22)
	stat.TextWrapped = false
	stat.BackgroundTransparency = 0
	stat.BackgroundColor3 = INK
	round(stat)
	local statPadding = Instance.new("UIPadding")
	statPadding.PaddingLeft = UDim.new(0, 10)
	statPadding.PaddingRight = UDim.new(0, 10)
	statPadding.Parent = stat

	local description = label(
		content,
		"Description",
		lines(ability.description, CardTheme.fonts.body, CardTheme.card.descText, 112),
		CardTheme.fonts.body,
		CardTheme.card.descText,
		WHITE,
		CardTheme.card.descStroke,
		0.15
	)
	description.TextWrapped = false
	description.LayoutOrder = 6
	description.Size = UDim2.fromOffset(118, 64)
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.LineHeight = 1.15

	-- Pips sit on the bottom edge, whatever the text above them took.
	local pipsHolder = frame(root, "PipsHolder", Z.content)
	pipsHolder.AnchorPoint = Vector2.new(0.5, 1)
	pipsHolder.Position = UDim2.new(0.5, 0, 1, -CardTheme.card.paddingBottom + 2)
	pipsHolder.Size = UDim2.fromOffset(SIZE.X - 16, 14)
	pips(pipsHolder, ability, level, maxed)

	-- A new skill wears a NEW! sticker.
	if level == 0 and state == "Default" and not ability.filler then
		local sticker = label(root, "New", "NEW!", CardTheme.fonts.display, 13, WHITE, 0)
		sticker.ZIndex = Z.sticker
		sticker.AnchorPoint = Vector2.new(1, 0)
		sticker.Position = UDim2.new(1, 34, 0, -28)
		sticker.Size = UDim2.fromOffset(52, 24)
		sticker.Rotation = 10
		sticker.BackgroundTransparency = 0
		sticker.BackgroundColor3 = CardTheme.colors.danger
		corner(sticker, 10)
		stroke(sticker, INK, 3)
	end

	if state == "Maxed" then
		local scrim = frame(root, "Maxed", Z.scrim)
		scrim.Size = UDim2.fromScale(1, 1)
		fill(scrim, { color = INK, transparency = 0.62 })
		corner(scrim, 14)
		local stamp = label(scrim, "Stamp", "MAXED", CardTheme.fonts.display, 26, INK, 0)
		stamp.ZIndex = Z.scrim + 1
		stamp.AnchorPoint = Vector2.new(0.5, 0.5)
		stamp.Position = UDim2.fromScale(0.5, 0.5)
		stamp.Size = UDim2.fromOffset(112, 40)
		stamp.Rotation = -14
		stamp.BackgroundTransparency = 0
		stamp.BackgroundColor3 = CardTheme.colors.gold
		corner(stamp, 10)
		stroke(stamp, INK, 4)
	elseif state == "Locked" then
		local scrim = frame(root, "Locked", Z.scrim)
		scrim.Size = UDim2.fromScale(1, 1)
		fill(scrim, { color = Color3.fromRGB(20, 22, 40), transparency = 0.18 })
		corner(scrim, 14)
		local word = label(scrim, "Word", "LOCKED", CardTheme.fonts.display, 20, WHITE, 4)
		word.ZIndex = Z.scrim + 1
		word.AnchorPoint = Vector2.new(0.5, 0.5)
		word.Position = UDim2.fromScale(0.5, 0.5)
		word.Size = UDim2.fromOffset(120, 26)
		local why = label(
			scrim,
			"Why",
			options.lockText or "",
			CardTheme.fonts.body,
			12,
			Color3.fromRGB(217, 222, 240),
			0
		)
		why.ZIndex = Z.scrim + 1
		why.AnchorPoint = Vector2.new(0.5, 0)
		why.Position = UDim2.new(0.5, 0, 0.5, 20)
		why.Size = UDim2.fromOffset(114, 40)
	end

	--[[ Selected: a white ring outside the card with an ink edge, hidden
	     until the card is picked. ]]
	local selection = frame(root, "Selection", Z.selection)
	selection.Size = UDim2.fromScale(1, 1)
	corner(selection, CardTheme.card.corner)
	stroke(selection, INK, 8)
	local selectionRing = frame(selection, "Ring", Z.selection + 1)
	selectionRing.Size = UDim2.fromScale(1, 1)
	corner(selectionRing, CardTheme.card.corner)
	stroke(selectionRing, WHITE, 4)
	selection.Visible = false

	local card: Card
	card = {
		root = root,
		setSelected = function(selected: boolean)
			selection.Visible = selected
		end,
		setShine = function(offset: number, strength: number)
			band.Offset = Vector2.new(offset, 0)
			shine.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
		end,
		step = function(time: number)
			for _, entry in animated do
				if entry.kind == "pulse" then
					-- 0.55 + 0.40·sin(3.2t) opacity, from the design.
					entry.glow.ImageTransparency = 1 - (0.55 + 0.4 * math.sin(3.2 * time))
				elseif entry.kind == "embers" then
					local part = entry.part
					local ellipse = part.ellipse
					for index, ember in entry.embers do
						local angle = time * part.speedRadPerSec
							+ (index - 1) / #entry.embers * 2 * math.pi
						local depth = math.sin(angle)
						ember.Position = UDim2.fromOffset(
							ellipse.center[1] + math.cos(angle) * ellipse.rx,
							ellipse.center[2] + depth * ellipse.ry
						)
						-- Behind the card on the far side of the orbit.
						ember.ZIndex = if depth < 0 then Z.backGlow else Z.content + 1
						local scale = 0.75 + 0.35 * (depth + 1) / 2
						ember.BackgroundTransparency = 0.45 * (1 - (depth + 1) / 2)
						local s = if index % 3 == 1 then 8 else 4
						ember.Size = UDim2.fromOffset(s * scale, s * scale)
					end
				end
			end
		end,
		destroy = function()
			root:Destroy()
		end,
	}

	card.setShine(0, 0.3)
	card.step(0)
	return card
end

return CardBuilder
