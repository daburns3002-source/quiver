--!strict
--[[
	The level-up draft, as the owner's card design has it
	(design_handoff_upgrade_cards; README "Draft", "Touch", "Motion spec").

	Three cards dealt in on a blue panel. Pick one: a click or tap selects
	it, and Choose! — or, with a mouse, clicking the selected card again —
	confirms. Reroll redeals the hand while the run has rerolls left.

	It decides nothing. The server dealt the hand; this sends back an index
	into it, or asks for a redeal, and the server checks both. See CLAUDE.md,
	non-negotiable 2.

	Built in design pixels and scaled as a whole to fit the screen. On a
	touch screen the cards sit closer together, as the design's phone layout
	does, and the lower rarities draw over the higher so the big crystal
	wings tuck behind their neighbours.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardBuilder = require(script.Parent.CardBuilder)
local CardTheme = require(ReplicatedStorage.Shared.Config.CardTheme)
local Motion = require(script.Parent.Motion)
local PlayerStats = require(script.Parent.Parent.Parent.PlayerStats)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local DraftScreen = {}

local INK = CardTheme.colors.ink
local WHITE = CardTheme.colors.white
local CARD = CardTheme.card.size
local TIMING = CardTheme.timing

--[[ Room around each card inside its fading group, for the crowns, wings,
     glows and stickers that reach past the card's edge. ]]
local BLEED = 120
--[[ Space above the cards for the tallest crown. ]]
local CROWN_ROOM = 96

local TITLES = {
	Level = { "LEVEL UP!", "Level %d · choose one skill" },
	Valkyrie = { "VALKYRIE!", "Choose a blessing" },
	Angel = { "ANGEL!", "Choose a gift" },
}

type Slot = {
	index: number,
	id: string,
	card: CardBuilder.Card,
	group: CanvasGroup,
	scale: UIScale,
	base: Vector2,
	hovered: boolean,
	pointer: number,
	scaleSpring: Motion.Spring,
	liftSpring: Motion.Spring,
	jiggle: Motion.Spring,
	dealAt: number,
}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local panelScale: UIScale? = nil
local cardRow: Frame? = nil
local title: TextLabel? = nil
local subtitle: TextLabel? = nil
local rerollButton: TextButton? = nil
local chooseButton: TextButton? = nil
local connection: RBXScriptConnection? = nil
--[[ Design-pixel width of the card row, which the cards are centred in. ]]
local rowWidth = 0
--[[ The hand on screen, so a redeal the server declines can put it back. ]]
local shown: { offer: { string }, level: number, source: string?, rerolls: number? }? = nil
local dealToken = 0

local slots: { Slot } = {}
local selected: number? = nil
--[[ While cards are flying off, nothing else may be pressed. ]]
local leaving: { kind: "Choose" | "Reroll", at: number, picked: number? }? = nil
local locked = false

local onChosen: ((number) -> ())? = nil
local onReroll: (() -> ())? = nil

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function gap(): number
	return if isTouch() then 12 else 96
end

local function stroked(
	parent: Instance,
	text: string,
	font: Enum.Font,
	size: number,
	colour: Color3,
	width: number
): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = font
	t.Text = text
	t.TextSize = size
	t.TextColor3 = colour
	t.Parent = parent
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = width
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	return t
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

--[[ A chunky button with an ink outline and a hard shadow five pixels down. ]]
local function button(
	parent: Instance,
	name: string,
	text: string,
	colour: Color3,
	width: number
): TextButton
	local shadow = Instance.new("Frame")
	shadow.Name = name .. "Shadow"
	shadow.Size = UDim2.fromOffset(width, 52)
	shadow.BackgroundColor3 = INK
	shadow.BorderSizePixel = 0
	shadow.Parent = parent
	corner(shadow, 14)

	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(width, 52)
	b.Position = UDim2.fromOffset(0, -5)
	b.BackgroundColor3 = colour
	b.AutoButtonColor = false
	b.Font = CardTheme.fonts.display
	b.Text = text
	b.TextSize = 20
	b.TextColor3 = WHITE
	b.Parent = shadow
	corner(b, 14)

	local edge = Instance.new("UIStroke")
	edge.Color = INK
	edge.Thickness = 4
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = b
	local textEdge = Instance.new("UIStroke")
	textEdge.Color = INK
	textEdge.Thickness = 4
	textEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textEdge.Parent = b

	return b
end

local function clearSlots()
	for _, slot in slots do
		slot.group:Destroy()
	end
	table.clear(slots)
	selected = nil
end

local function setChooseEnabled(enabled: boolean)
	local b = chooseButton
	if b then
		b.BackgroundColor3 = if enabled then CardTheme.colors.choose else CardTheme.colors.disabled
		b.Active = enabled
	end
end

local function pick(index: number?)
	selected = index
	for _, slot in slots do
		local on = slot.index == index
		slot.card.setSelected(on)
		slot.scaleSpring.target = if on then 1.1 elseif slot.hovered then 1.07 else 1
		slot.liftSpring.target = if on then -28 elseif slot.hovered then -10 else 0
	end
	setChooseEnabled(index ~= nil)
end

local function confirm()
	local index = selected
	if locked or not index then
		return
	end

	locked = true
	leaving = { kind = "Choose", at = os.clock(), picked = index }

	--[[ The pick is applied as the cards finish leaving, as the design
	     times it, so the screen never closes on a frame still moving. ]]
	task.delay(TIMING.chooseApplyAt, function()
		local handler = onChosen
		if handler then
			handler(index)
		end
	end)
end

local function reroll()
	if locked then
		return
	end

	local b = rerollButton
	if not b or not b.Active then
		return
	end

	locked = true
	leaving = { kind = "Reroll", at = os.clock(), picked = nil }

	local token = dealToken
	task.delay(TIMING.rerollDuration, function()
		local handler = onReroll
		if handler then
			handler()
		end

		--[[ The server answers a redeal with a new hand. If none comes —
		     it declined — the old hand is dealt back rather than leaving an
		     empty panel. ]]
		task.delay(1, function()
			local hand = shown
			if dealToken == token and hand then
				DraftScreen.show(hand.offer, hand.level, hand.source, hand.rerolls)
			end
		end)
	end)
end

local function layoutPanel(count: number)
	local p = panel
	local row = cardRow
	if not p or not row then
		return
	end

	local width = count * CARD.X + (count - 1) * gap() + 2 * 70
	local height = 40 + 70 + CROWN_ROOM + CARD.Y + 50 + 76 + 30
	p.Size = UDim2.fromOffset(math.max(width, 460), height)
	row.Size = UDim2.fromOffset(width, CARD.Y)
	rowWidth = width

	-- Fit the whole panel to the screen, never above design size.
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local scale = math.min(1, (viewport.X - 32) / math.max(width, 460), (viewport.Y - 32) / height)
	local s = panelScale
	if s then
		s.Scale = math.max(scale, 0.3)
	end
end

local function buildSlot(index: number, id: string, count: number, now: number): Slot
	local row = cardRow :: Frame
	local level = PlayerStats.get().abilities[id] or 0
	local card = CardBuilder.build(id, { level = level })

	local group = Instance.new("CanvasGroup")
	group.Name = `Slot{index}`
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Size = UDim2.fromOffset(CARD.X + BLEED * 2, CARD.Y + BLEED * 2)
	group.GroupTransparency = 1
	group.Parent = row

	--[[ Lower rarities over higher, so on a phone the wide wings of a
	     Legendary or Mythic tuck behind the card beside them. ]]
	local ability = Abilities.byId[id]
	local rarity = if ability then Rarities.byName[ability.rarity] else nil
	group.ZIndex = 10 - (if rarity then rarity.tier else 1)

	card.root.AnchorPoint = Vector2.new(0.5, 0.5)
	card.root.Position = UDim2.fromScale(0.5, 0.5)
	card.root.Parent = group
	local scale = Instance.new("UIScale")
	scale.Parent = card.root

	local x = (index - 1) * (CARD.X + gap()) - ((count - 1) * (CARD.X + gap())) / 2
	local base = Vector2.new(x, 0)

	local slot: Slot = {
		index = index,
		id = id,
		card = card,
		group = group,
		scale = scale,
		base = base,
		hovered = false,
		pointer = 0.5,
		scaleSpring = Motion.spring(1, 0.2, 0.7),
		liftSpring = Motion.spring(0, 0.14, 0.72),
		jiggle = Motion.spring(0, 0.12, 0.84),
		dealAt = now + (index - 1) * TIMING.dealStagger,
	}

	-- The whole card is the press target.
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	hit.ZIndex = 50
	hit.Parent = group

	hit.MouseEnter:Connect(function()
		if isTouch() or locked then
			return
		end
		slot.hovered = true
		slot.jiggle.v += if math.random() < 0.5 then -4.5 else 4.5
		pick(selected)
	end)
	hit.MouseLeave:Connect(function()
		slot.hovered = false
		pick(selected)
	end)
	hit.MouseMoved:Connect(function(mouseX: number)
		local left = hit.AbsolutePosition.X
		local width = math.max(hit.AbsoluteSize.X, 1)
		slot.pointer = math.clamp((mouseX - left) / width, 0, 1)
	end)
	hit.Activated:Connect(function()
		if locked then
			return
		end
		--[[ With a mouse, clicking the selected card again confirms it. On
		     a touch screen only Choose! confirms: a tap is too easy to
		     land twice by accident. ]]
		if selected == index and not isTouch() then
			confirm()
		else
			pick(index)
		end
	end)

	return slot
end

local function step(deltaTime: number)
	local now = os.clock()
	local away = leaving

	for _, slot in slots do
		local i = slot.index
		local calm = if slot.hovered or selected == i then 0.25 else 1

		Motion.step(slot.scaleSpring, deltaTime)
		Motion.step(slot.liftSpring, deltaTime)
		Motion.step(slot.jiggle, deltaTime)

		local tilt = if slot.hovered then (slot.pointer - 0.5) * 8 else 0
		local rotation = math.sin(now * 1.3 + i * 1.7) * 1.8 * calm + tilt + slot.jiggle.x
		local offset =
			Vector2.new(0, math.sin(now * 1.8 + i * 1.1) * 3.5 * calm + slot.liftSpring.x)
		local scale = slot.scaleSpring.x
		local transparency = 0

		-- Dealt in: from down and to the right, turned, settling with a kick.
		local dealt = (now - slot.dealAt) / TIMING.dealDuration
		if dealt < 0 then
			transparency = 1
		elseif dealt < 1 then
			local e = Motion.backOut(dealt)
			offset += Vector2.new(560, 120) * (1 - e)
			rotation += 28 * (1 - e)
		end

		if away then
			if away.kind == "Choose" then
				local e = Motion.quadIn(math.clamp((now - away.at) / TIMING.chooseDuration, 0, 1))
				if away.picked == i then
					offset += Vector2.new(0, -420 * e)
					scale += 0.2 * e
					rotation -= 8 * e
				else
					offset += Vector2.new(0, 460 * e)
					rotation += (if i < (away.picked or 0) then -34 else 34) * e
				end
				transparency = math.max(transparency, e)
			else
				local e = Motion.quadIn(math.clamp((now - away.at) / TIMING.rerollDuration, 0, 1))
				offset += Vector2.new(-760 * e, 0)
				rotation -= 24 * e
				transparency = math.max(transparency, e)
			end
		end

		slot.group.Position =
			UDim2.fromOffset(slot.base.X + offset.X + rowWidth / 2, CARD.Y / 2 + offset.Y)
		slot.group.Rotation = rotation
		slot.group.GroupTransparency = transparency
		slot.scale.Scale = scale

		if slot.hovered then
			slot.card.setShine((0.5 - slot.pointer) * 0.6, 1)
		else
			slot.card.setShine(0, 0.3)
		end
		slot.card.step(now)
	end
end

function DraftScreen.stop()
	clearSlots()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	onChosen = nil
	onReroll = nil
end

function DraftScreen.start(chosen: (number) -> (), rerolled: () -> ())
	DraftScreen.stop()
	onChosen = chosen
	onReroll = rerolled

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local created = Instance.new("ScreenGui")
	created.Name = "DraftScreen"
	created.IgnoreGuiInset = true
	created.ResetOnSpawn = false
	created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	--[[ Above everything: nothing behind this is actionable while it is up. ]]
	created.DisplayOrder = 100
	created.Enabled = false
	created.Parent = playerGui
	gui = created

	--[[ A dimmer, not a wall: the frozen fight behind is worth seeing. ]]
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Parent = created

	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.BackgroundColor3 = CardTheme.colors.panel
	root.BorderSizePixel = 0
	root.Parent = created
	corner(root, 26)
	local edge = Instance.new("UIStroke")
	edge.Color = INK
	edge.Thickness = 5
	edge.Parent = root
	local fit = Instance.new("UIScale")
	fit.Parent = root
	panel = root
	panelScale = fit

	local heading =
		stroked(root, "LEVEL UP!", CardTheme.fonts.display, 44, CardTheme.colors.titleYellow, 6)
	heading.Name = "Title"
	heading.AnchorPoint = Vector2.new(0.5, 0)
	heading.Position = UDim2.new(0.5, 0, 0, 30)
	heading.Size = UDim2.new(1, -40, 0, 48)
	title = heading

	local sub = stroked(root, "", CardTheme.fonts.body, 16, WHITE, 4)
	sub.Name = "Subtitle"
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0, 84)
	sub.Size = UDim2.new(1, -40, 0, 20)
	subtitle = sub

	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 40 + 70 + CROWN_ROOM)
	row.Parent = root
	cardRow = row

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.new(0.5, 0, 1, -30)
	buttons.Size = UDim2.fromOffset(400, 52)
	buttons.Parent = root
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 20)
	list.Parent = buttons

	local rerollB = button(buttons, "Reroll", "Reroll 2", CardTheme.colors.reroll, 150);
	(rerollB.Parent :: Frame).LayoutOrder = 1
	rerollB.Activated:Connect(reroll)
	rerollButton = rerollB

	local chooseB = button(buttons, "Choose", "Choose!", CardTheme.colors.disabled, 170);
	(chooseB.Parent :: Frame).LayoutOrder = 2
	chooseB.Activated:Connect(confirm)
	chooseButton = chooseB

	connection = RunService.RenderStepped:Connect(step)
end

--[[ Shows a hand the server dealt. `level` is the level just reached;
     `source` who is offering; `rerolls` how many redeals are left. ]]
function DraftScreen.show(offer: { string }, level: number, source: string?, rerolls: number?)
	local created = gui
	if not created then
		return
	end

	clearSlots()
	leaving = nil
	locked = false
	dealToken += 1
	shown = { offer = offer, level = level, source = source, rerolls = rerolls }

	local words = TITLES[source or "Level"] or TITLES.Level
	if title then
		title.Text = words[1]
	end
	if subtitle then
		subtitle.Text = string.format(words[2], level)
	end

	local left = rerolls or 0
	local rerollB = rerollButton
	if rerollB then
		local shadow = rerollB.Parent :: Frame
		shadow.Visible = source ~= "Angel"
		rerollB.Active = left > 0
		rerollB.BackgroundColor3 = if left > 0
			then CardTheme.colors.reroll
			else CardTheme.colors.disabled
		rerollB.Text = `Reroll {left}`
	end

	layoutPanel(#offer)

	local now = os.clock()
	for index, id in offer do
		if Abilities.byId[id] then
			table.insert(slots, buildSlot(index, id, #offer, now))
		end
	end

	pick(nil)
	created.Enabled = true
end

--[[ Hides the screen. Called once a pick is sent, and on death, so a draft
     can never outlive the run that owed it. ]]
function DraftScreen.hide()
	locked = true
	leaving = nil
	clearSlots()
	if gui then
		gui.Enabled = false
	end
end

return DraftScreen
