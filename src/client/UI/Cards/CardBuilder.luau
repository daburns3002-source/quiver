--!strict
--[[
	Builds one upgrade card from the owner's Glow Toy set (2026-10-24,
	arrow-legends-upgrade-cards.zip, uploaded into `Config/CardAssets`).

	Built at the card's design size, 134 x 330, and scaled as a whole by
	whoever places it. Layers back to front:

	1. a pulsing glow behind Legendary and Mythic cards;
	2. the crystal body of the card's rarity;
	3. a shine band, faint until hovered;
	4. the content: the icon on its rarity tile, the level chip, the stat
	   and description from `Config/Abilities` (the set's own stat lines are
	   placeholders), the level pips;
	5. the card's name banner across the top, its name and rarity drawn in;
	6. the NEW! sticker, the Maxed or Locked overlay, the selection ring.

	Presentation only: a card does not know what an ability does, only what
	it says.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
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

--[[ The Glow Toy art's own pixel sizes, and where it sits on a card (in
     the card's 134 x 330): the banner wider than the card, across its top;
     room under it, then the icon tile. ]]
local GLOW_TOY = {
	--[[ The body art, and the crystal in it (measured from its alpha): it
	     is that crystal that fills the card, its spikes standing proud. ]]
	body = Vector2.new(398, 960),
	crystalWidth = 326,
	crystalMidY = 497.5,
	--[[ The banner art, and its ribbon's width and middle. ]]
	banner = Vector2.new(984, 558),
	ribbonWidth = 726,
	ribbonMidY = 298,
	--[[ The ribbon this wide on the card, its middle this far down. ]]
	bannerRibbon = 168,
	bannerY = 34,
	bannerRoom = 56,
	tile = 104,
}

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
	local level = options.level
	local state: State = options.state or "Default"
	local top = #ability.levels
	local maxed = state == "Maxed" or level >= top
	local nextLevel = math.min(level + 1, top)

	local root = frame(nil :: any, "Card", 1)
	root.Size = UDim2.fromOffset(SIZE.X, SIZE.Y)

	local animated: { any } = {}

	--[[ The owner's Glow Toy set (2026-10-24): the crystal body of the
	     card's rarity, its own name banner across the top (its name and
	     rarity drawn in), and its icon on its rarity tile. The art keeps
	     its padding, so each piece is anchored at its centre. ]]
	if ability.rarity == "Legendary" or ability.rarity == "Mythic" then
		local glow = image(root, "CardGlow", Z.backGlow, CardAssets.glow, {
			color = rarity.color,
			transparency = 0.45,
		})
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromOffset(SIZE.X * 1.9, SIZE.Y * 1.35)
		table.insert(animated, { kind = "pulse", glow = glow })
	end

	local body = image(
		root,
		"Body",
		Z.body,
		CardAssets.bodies[ability.rarity] or "",
		{ color = WHITE, transparency = 0 }
	)
	local bodyScale = SIZE.X / GLOW_TOY.crystalWidth
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.new(0.5, 0, 0.5, (GLOW_TOY.body.Y / 2 - GLOW_TOY.crystalMidY) * bodyScale)
	body.Size = UDim2.fromOffset(GLOW_TOY.body.X * bodyScale, GLOW_TOY.body.Y * bodyScale)

	local banner = image(
		root,
		"Banner",
		Z.content + 1,
		CardAssets.banners[ability.icon] or "",
		{ color = WHITE, transparency = 0 }
	)
	local bannerScale = GLOW_TOY.bannerRibbon / GLOW_TOY.ribbonWidth
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromOffset(
		SIZE.X / 2,
		GLOW_TOY.bannerY + (GLOW_TOY.banner.Y / 2 - GLOW_TOY.ribbonMidY) * bannerScale
	)
	banner.Size = UDim2.fromOffset(GLOW_TOY.banner.X * bannerScale, GLOW_TOY.banner.Y * bannerScale)

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

	--[[ Room for the banner above the icon. ]]
	local bannerRoom = frame(content, "BannerRoom", Z.content)
	bannerRoom.LayoutOrder = 1
	bannerRoom.Size = UDim2.fromOffset(inner, GLOW_TOY.bannerRoom)

	-- The icon on its rarity tile.
	local tileSize = GLOW_TOY.tile
	local holder = frame(content, "TileHolder", Z.content)
	holder.LayoutOrder = 2
	holder.Size = UDim2.fromOffset(tileSize, tileSize)
	local icon = image(
		holder,
		"Icon",
		Z.content,
		CardAssets.icons[ability.icon] or "",
		{ color = WHITE, transparency = 0 }
	)
	icon.Size = UDim2.fromScale(1, 1)

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
