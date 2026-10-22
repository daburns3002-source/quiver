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

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local CardBuilder = require(script.Parent.CardBuilder)
local CardTheme = require(ReplicatedStorage.Shared.Config.CardTheme)
local DetailPanel = require(script.Parent.DetailPanel)
local Device = require(script.Parent.Parent.Parent.Device)
local Motion = require(script.Parent.Motion)
local MythicReveal = require(script.Parent.MythicReveal)
local PlayerStats = require(script.Parent.Parent.Parent.PlayerStats)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local SkillBar = require(script.Parent.SkillBar)

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
--[[ Screen kept clear at the bottom for the skill bar. ]]
local BAR_ROOM = 110

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
	--[[ Balatro's "juice": a scale pop and a wobble that die away, started
	     on hover, select and confirm. ]]
	juice: { at: number, scale: number, rot: number }?,
	--[[ How much of the idle float is on, easing to 0 under the pointer so
	     the card settles rather than snapping straight. ]]
	float: number,
	scaleSpring: Motion.Spring,
	--[[ Balatro's follow: where the card is and how fast it is going, in
	     row pixels, chasing where it wants to be on a spring; and the lean
	     that speed puts on it. ]]
	pos: Vector2,
	vel: Vector2,
	lean: number,
	--[[ Its soft shadow on the table, which falls away as the card rises. ]]
	shadow: Frame,
	dealAt: number,
	--[[ A Mythic is dealt face down: its back, when its reveal starts, and
	     the lightning round its face once it is up. ]]
	mythic: { back: Frame, start: number, lightning: MythicReveal.Lightning? }?,
}

--[[ How the player is pointing: a mouse, a finger, or a gamepad. Decided
     when a hand is dealt, from the input they last used. ]]
type Mode = "Mouse" | "Touch" | "Gamepad"

local gui: ScreenGui? = nil
local panel: Frame? = nil
local panelScale: UIScale? = nil
local buttonsFrame: Frame? = nil
local buttonsList: UIListLayout? = nil
--[[ On a phone the Choose and Reroll buttons stand to the right of the
     hand, not under it, and the skill bar stays off the draft until a pick
     is confirmed: a phone held sideways has width to spare and no height,
     and both of those were costing the cards their size. ]]
local PHONE_BUTTON_COLUMN = 210
local PHONE_MARGIN = 8
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
local leaving: { kind: "Reroll" | "Celebrate", at: number, picked: number? }? = nil
local locked = false
local mode: Mode = "Mouse"
--[[ With a gamepad, the card the stick is on. ]]
local focused = 1

--[[ Full-screen effects over the panel: the rays, flash, ring and words of
     a celebration or a reveal, and the strip and prompts for a gamepad. ]]
local rays: ImageLabel? = nil
local flash: Frame? = nil
local shockwave: Frame? = nil
local headline: TextLabel? = nil
local tagline: TextLabel? = nil
local flyer: Frame? = nil
local ghosts: { Frame } = {}
local strip: Frame? = nil
local stripText: TextLabel? = nil
local prompts: Frame? = nil

local ACTIONS = { "DraftLeft", "DraftRight", "DraftChoose", "DraftReroll" }

--[[ The panel's colour for this hand: blue, or gold when a Legendary is
     dealt, or red when a Mythic is — the rarest card in the hand sets it,
     so a big card announces itself before it is read. ]]
local PANEL_LEGENDARY = Color3.fromRGB(226, 160, 34)
local PANEL_MYTHIC = Color3.fromRGB(196, 32, 48)
local panelBase = CardTheme.colors.panel

local stepOverlay: (now: number) -> ()

local onChosen: ((number) -> ())? = nil
local onReroll: (() -> ())? = nil

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local GAMEPADS = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
}

local function currentMode(): Mode
	if GAMEPADS[UserInputService:GetLastInputType()] then
		return "Gamepad"
	end
	return if isTouch() then "Touch" else "Mouse"
end

local function gap(): number
	return if mode == "Touch" then 12 else 96
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
--[[
	A button's feel, Balatro-style: it rises a little and brightens under the
	pointer, sinks into its shadow while held, and springs back with a small
	wobble when it fires. One that cannot be pressed shakes its head instead.
	Nothing is scaled, so its label never reflows.
]]
type ButtonFeel = {
	button: TextButton,
	hovered: boolean,
	pressed: boolean,
	lift: number,
	wobbleAt: number?,
	wobbleAmp: number,
	shakeAt: number?,
}

local buttonFeels: { ButtonFeel } = {}

local REST_LIFT = -5
local HOVER_LIFT = -8
local PRESS_LIFT = -1

local function feelOf(b: TextButton): ButtonFeel?
	for _, feel in buttonFeels do
		if feel.button == b then
			return feel
		end
	end
	return nil
end

--[[ Sets a button's colour and whether it can be pressed. The colour is
     kept as an attribute so hover and press can shade it each frame. ]]
local function setButton(b: TextButton, enabled: boolean, colour: Color3)
	b:SetAttribute("BaseColor", colour)
	b.Active = enabled
	b.AutoButtonColor = false
end

local function wobble(b: TextButton, amp: number)
	local feel = feelOf(b)
	if feel then
		feel.wobbleAt = os.clock()
		feel.wobbleAmp = amp
	end
end

local function stepButtons(deltaTime: number)
	local now = os.clock()
	local blend = math.min(1, deltaTime * 22)
	for _, feel in buttonFeels do
		local b = feel.button
		local enabled = b.Active
		local target = if feel.pressed and enabled
			then PRESS_LIFT
			elseif feel.hovered and enabled then HOVER_LIFT
			else REST_LIFT
		feel.lift += (target - feel.lift) * blend

		local x, rotation = 0, 0
		local w = feel.wobbleAt
		if w then
			local e = now - w
			if e > 0.4 then
				feel.wobbleAt = nil
			else
				rotation = feel.wobbleAmp * math.sin(40.8 * e) * (1 - e / 0.4) ^ 2
			end
		end
		local sh = feel.shakeAt
		if sh then
			local e = now - sh
			if e > 0.3 then
				feel.shakeAt = nil
			else
				x = 6 * math.sin(60 * e) * (1 - e / 0.3)
			end
		end

		b.Position = UDim2.fromOffset(x, feel.lift)
		b.Rotation = rotation

		local base = b:GetAttribute("BaseColor")
		if typeof(base) == "Color3" then
			local shade = if not enabled
				then 1
				elseif feel.pressed then 0.86
				elseif feel.hovered then 1.12
				else 1
			b.BackgroundColor3 = Color3.new(
				math.clamp(base.R * shade, 0, 1),
				math.clamp(base.G * shade, 0, 1),
				math.clamp(base.B * shade, 0, 1)
			)
		end
	end
end

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

	setButton(b, true, colour)
	local feel: ButtonFeel = {
		button = b,
		hovered = false,
		pressed = false,
		lift = REST_LIFT,
		wobbleAt = nil,
		wobbleAmp = 0,
		shakeAt = nil,
	}
	table.insert(buttonFeels, feel)

	b.MouseEnter:Connect(function()
		feel.hovered = true
	end)
	b.MouseLeave:Connect(function()
		feel.hovered = false
		feel.pressed = false
	end)
	b.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if b.Active then
			feel.pressed = true
		else
			-- Not yet: a quick shake rather than a press that does nothing.
			feel.shakeAt = os.clock()
		end
	end)
	b.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			feel.pressed = false
		end
	end)
	b.Activated:Connect(function()
		if b.Active then
			wobble(b, 5)
		end
	end)

	return b
end

local function clearSlots()
	for _, slot in slots do
		slot.group:Destroy()
		slot.shadow:Destroy()
	end
	table.clear(slots)
	selected = nil
end

local function setChooseEnabled(enabled: boolean)
	local b = chooseButton
	if b then
		local was = b.Active
		setButton(
			b,
			enabled,
			if enabled then CardTheme.colors.choose else CardTheme.colors.disabled
		)
		-- Lighting up gets a wiggle, so the eye goes to it.
		if enabled and not was then
			wobble(b, 6)
		end
	end
end

--[[
	Balatro's hand. Cards chase their places on a spring per 60 Hz frame
	(`v = (v + (target − x)·K)·D; x += v`), and lean into their sideways
	speed, so a dealt card swings in and rights itself and a lifted card
	settles with a little give. Sizes never spring — a card's words must
	not throb — only places and leans do.
]]
local FOLLOW_K = 0.16
local FOLLOW_D = 0.64
--[[ Degrees of lean per pixel a frame of sideways speed, and its cap. ]]
local LEAN_PER_PX = 0.55
local LEAN_MAX = 18
--[[ The fan: degrees each card turns per place from the middle, and pixels
     it drops per place squared, so the hand curves like one held. ]]
local FAN_TURN = 3
local FAN_DROP = 7
local CARD_HOVER_LIFT = -10
local CARD_SELECT_LIFT = -28
--[[ How dark a card's shadow on the table is while the card lies on it. ]]
local SHADOW_OPACITY = 0.35

--[[ Starts a card's juice: a scale pop of `scale` and a wobble of `rot`
     degrees, both dying away over `JUICE_TIME`. ]]
local JUICE_TIME = 0.4
local function juiceUp(slot: Slot, scale: number, rot: number)
	slot.juice = { at = os.clock(), scale = scale, rot = rot }
end

local function pick(index: number?)
	local previous = selected
	selected = index
	for _, slot in slots do
		local on = slot.index == index
		slot.card.setSelected(on)
		--[[ Hover only lifts the card: it is not scaled or turned, so not a
		     word on it moves relative to the card. ]]
		slot.scaleSpring.target = if on then 1.1 else 1
		--[[ A card taken up pops and wobbles; one put back down, a little. ]]
		if on and previous ~= slot.index then
			juiceUp(slot, 0, 6)
		elseif not on and previous == slot.index then
			juiceUp(slot, 0, 3)
		end
	end
	setChooseEnabled(index ~= nil)
end

local function confirm()
	local index = selected
	if locked or not index then
		return
	end

	locked = true
	local chosen = slots[index]
	if chosen then
		juiceUp(chosen, 0, 8)
	end

	--[[ Every pick is a celebration: the card takes the stage, and its icon
	     flies into the skill bar before the pick is applied. The design drew
	     this for phones; the owner asked for it on every device. ]]
	leaving = { kind = "Celebrate", at = os.clock(), picked = index }
	-- A phone's bar was kept off the draft; it comes up now for the icon.
	if Device.isPhone() then
		SkillBar.toCombat()
	end

	local slot = slots[index]
	local words, tag, icon = headline, tagline, flyer
	if slot and words and tag and icon then
		local ability = Abilities.byId[slot.id]
		local level = (PlayerStats.get().abilities[slot.id] or 0) + 1
		words.TextSize = 40
		words.Text = if level > 1 then "UPGRADED!" else "NEW SKILL!"
		words.TextColor3 = CardTheme.colors.choose
		tag.Text = `{ability.name} · LVL {level}`
		for _, child in icon:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local medallion = DetailPanel.medallion(icon, ability, 72)
		medallion.AnchorPoint = Vector2.new(0.5, 0.5)
		medallion.Position = UDim2.fromScale(0.5, 0.5)
	end

	--[[ The pick is applied as the cards finish leaving, as the design
	     times it, so the screen never closes on a frame still moving. ]]
	task.delay(TIMING.pickApplyAt, function()
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

	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local phone = Device.isPhone()
	--[[ Held sideways the buttons go beside the hand, for height; held
	     upright they stay under it, for width. ]]
	local column = phone and viewport.X >= viewport.Y
	-- A phone keeps little padding at the panel's sides (room for the NEW
	-- sticker over the last card); a computer 70.
	local sidePad = if phone then 36 else 70
	local width = count * CARD.X + (count - 1) * gap() + 2 * sidePad
	local panelWidth = math.max(width, if phone then 400 else 460)
		+ (if column then PHONE_BUTTON_COLUMN else 0)
	local height = 40 + 70 + CROWN_ROOM + CARD.Y + (if column then 40 else 50 + 76 + 30)
	p.Size = UDim2.fromOffset(panelWidth, height)
	row.Size = UDim2.fromOffset(width, CARD.Y)
	row.Position =
		UDim2.new(0.5, if column then -PHONE_BUTTON_COLUMN / 2 else 0, 0, 40 + 70 + CROWN_ROOM)
	rowWidth = width

	local b, list = buttonsFrame, buttonsList
	if b and list then
		if column then
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, -30, 0, 40 + 70 + CROWN_ROOM + CARD.Y / 2)
			b.Size = UDim2.fromOffset(170, 52 * 2 + 20)
			list.FillDirection = Enum.FillDirection.Vertical
			list.VerticalAlignment = Enum.VerticalAlignment.Center
		else
			b.AnchorPoint = Vector2.new(0.5, 1)
			b.Position = UDim2.new(0.5, 0, 1, -30)
			b.Size = UDim2.fromOffset(400, 52)
			list.FillDirection = Enum.FillDirection.Horizontal
		end
	end

	-- Fit the whole panel to the screen, never above design size.
	local margin = if phone then PHONE_MARGIN else 32
	local barRoom = if phone then 0 else BAR_ROOM
	local scale =
		math.min(1, (viewport.X - margin) / panelWidth, (viewport.Y - margin - barRoom) / height)
	scale = math.max(scale, 0.3)
	local s = panelScale
	if s then
		s.Scale = scale
	end
	-- Lifted clear of the skill bar beneath it, where there is one.
	p.Position = UDim2.new(0.5, 0, 0.5, -barRoom * scale / 2)
	if phone then
		SkillBar.setVisible(false)
	else
		SkillBar.setVisible(true, scale)
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

	-- Its soft shadow on the table, under every card.
	local shadow = Instance.new("Frame")
	shadow.Name = `Shadow{index}`
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 1
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = row
	corner(shadow, CardTheme.card.corner)

	-- Dealt from the deck: off to the right, or from below on a phone.
	local deck = if mode == "Touch" then Vector2.new(0, 420) else Vector2.new(560, 120)
	local dealAt = now + (index - 1) * TIMING.dealStagger

	local mythic = nil
	if ability and ability.rarity == "Mythic" then
		local back = MythicReveal.buildBack()
		back.AnchorPoint = Vector2.new(0.5, 0.5)
		back.Position = UDim2.fromScale(0.5, 0.5)
		back.Parent = group
		local backScale = Instance.new("UIScale")
		backScale.Parent = back
		card.root.Visible = false
		mythic = { back = back, start = dealAt + TIMING.dealDuration + 0.2, lightning = nil }
	end

	local slot: Slot = {
		index = index,
		id = id,
		card = card,
		group = group,
		scale = scale,
		base = base,
		hovered = false,
		juice = nil,
		float = 1,
		scaleSpring = Motion.spring(1, 0.2, 0.7),
		pos = base + deck,
		vel = Vector2.zero,
		lean = 0,
		shadow = shadow,
		dealAt = dealAt,
		mythic = mythic,
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
		if mode ~= "Mouse" or locked then
			return
		end
		slot.hovered = true
		pick(selected)
	end)
	hit.MouseLeave:Connect(function()
		slot.hovered = false
		pick(selected)
	end)
	--[[ On a touch screen, holding a card opens its detail as a sheet, with
	     a white bar filling under the card while the finger is down. ]]
	local holdBar = Instance.new("Frame")
	holdBar.Name = "HoldBar"
	holdBar.AnchorPoint = Vector2.new(0, 0)
	holdBar.Position = UDim2.new(0.5, -CARD.X / 2, 0.5, CARD.Y / 2 + 14)
	holdBar.Size = UDim2.fromOffset(0, 6)
	holdBar.BackgroundColor3 = WHITE
	holdBar.BorderSizePixel = 0
	holdBar.Parent = group
	corner(holdBar, 3)

	local holding: number? = nil
	local heldOpen = false
	hit.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch or locked then
			return
		end
		local started = os.clock()
		holding = started
		heldOpen = false
		task.spawn(function()
			while holding == started do
				local p = math.clamp((os.clock() - started) / TIMING.holdToOpen, 0, 1)
				holdBar.Size = UDim2.fromOffset(CARD.X * p, 6)
				if p >= 1 then
					heldOpen = true
					holding = nil
					DetailPanel.show(id, PlayerStats.get().abilities[id] or 0, true)
					break
				end
				RunService.RenderStepped:Wait()
			end
			holdBar.Size = UDim2.fromOffset(0, 6)
		end)
	end)
	hit.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			holding = nil
		end
	end)

	hit.Activated:Connect(function()
		local hidden = slot.mythic ~= nil
			and os.clock() < (slot.mythic :: any).start + MythicReveal.flipEnd
		if locked or heldOpen or hidden then
			heldOpen = false
			return
		end
		--[[ With a mouse, clicking the selected card again confirms it. On
		     a touch screen only Choose! confirms: a tap is too easy to
		     land twice by accident. ]]
		if selected == index and mode == "Mouse" then
			confirm()
		else
			pick(index)
		end
	end)

	return slot
end

local function setFocus(index: number)
	focused = math.clamp(index, 1, math.max(#slots, 1))
	pick(focused)
	local slot = slots[focused]
	local label = stripText
	if slot and label then
		local ability = Abilities.byId[slot.id]
		local level = PlayerStats.get().abilities[slot.id] or 0
		local top = #ability.levels
		label.Text = `{ability.name}  ·  {ability.rarity}  ·  {if level > 0
			then `LVL {level} → {level + 1}`
			else "NEW"}  ·  {ability.stats[math.min(level + 1, top)]}\n{ability.description}`
	end
end

--[[ The overlay's moments: a phone's celebration of a pick, or a Mythic
     being revealed. Everything here is drawn over the panel in screen
     space. ]]
stepOverlay = function(now: number)
	local away = leaving
	local raysImage, flashFrame, ring, words, tag, icon =
		rays, flash, shockwave, headline, tagline, flyer
	if not raysImage or not flashFrame or not ring or not words or not tag or not icon then
		return
	end

	local raysAlpha, flashAlpha, ringP, wordsAlpha, wordsPop = 0, 0, -1, 0, 0
	local mythicTitle = false
	local centre: Vector2? = nil

	if away and away.kind == "Celebrate" and away.picked then
		local t = now - away.at
		local slot = slots[away.picked]
		if slot then
			centre = slot.group.AbsolutePosition + slot.group.AbsoluteSize / 2
		end

		raysAlpha = if t < 0.3
			then 0
			elseif t < 0.5 then (t - 0.3) / 0.2
			elseif t < 1.0 then 1
			elseif t < 1.3 then 1 - (t - 1.0) / 0.3
			else 0
		flashAlpha = math.max(0, 0.65 * (1 - math.abs(t - 0.33) / 0.22))
		ringP = if t >= 0.3 and t <= 0.75 then (t - 0.3) / 0.45 else -1
		wordsPop = Motion.backOut(math.clamp((t - 0.42) / 0.36, 0, 1))
		wordsAlpha = if t < 0.42
			then 0
			elseif t < 1.05 then 1
			else math.max(0, 1 - (t - 1.05) / 0.25)

		-- The icon's flight into the bar.
		local f = (t - 1.04) / 0.5
		if slot and centre and f >= 0 and f <= 1 then
			local target = SkillBar.slotPosition(slot.id) or centre
			local e = Motion.quadInOut(f)
			local control =
				Vector2.new((centre.X + target.X) / 2 + 60, math.min(centre.Y, target.Y) - 150)
			local point = centre:Lerp(control, e):Lerp(control:Lerp(target, e), e)
			icon.Visible = true
			icon.Position = UDim2.fromOffset(point.X, point.Y)
			icon.Rotation = 540 * e;
			(icon:FindFirstChildOfClass("UIScale") :: UIScale).Scale = 1.7 + (0.6 - 1.7) * e
			for index, ghost in ghosts do
				local g = math.clamp(f - index * 0.09, 0, 1)
				local ge = Motion.quadInOut(g)
				local gp = centre:Lerp(control, ge):Lerp(control:Lerp(target, ge), ge)
				ghost.Visible = g > 0 and g < 1
				ghost.Position = UDim2.fromOffset(gp.X, gp.Y)
				ghost.BackgroundTransparency = 1 - ({ 0.45, 0.35, 0.25 })[index]
			end
		else
			icon.Visible = false
			for _, ghost in ghosts do
				ghost.Visible = false
			end
		end
	else
		icon.Visible = false
		for _, ghost in ghosts do
			ghost.Visible = false
		end

		-- A Mythic reveal's flash, rays and title.
		for _, slot in slots do
			local mythic = slot.mythic
			if not mythic then
				continue
			end
			local t = now - mythic.start
			if t < 0 or t > MythicReveal.settleEnd + 1.5 then
				continue
			end
			centre = slot.group.AbsolutePosition + slot.group.AbsoluteSize / 2
			flashAlpha = math.max(0, 0.8 * (1 - math.abs(t - MythicReveal.flashAt) / 0.28))
			raysAlpha = if t < MythicReveal.raysAt
				then 0
				else math.min(0.9, (t - MythicReveal.raysAt) / 0.3)
			if t > MythicReveal.settleEnd + 1 then
				raysAlpha *= math.max(0, 1 - (t - MythicReveal.settleEnd - 1) / 0.5)
			end
			wordsPop = Motion.backOut(math.clamp((t - MythicReveal.titleAt) / 0.45, 0, 1))
			--[[ Across the card itself, briefly: above it would sit on the
			     panel's own title. ]]
			wordsAlpha = if t < MythicReveal.titleAt
				then 0
				elseif t < MythicReveal.settleEnd + 0.3 then 1
				else math.max(0, 1 - (t - MythicReveal.settleEnd - 0.3) / 0.4)
			mythicTitle = true
			words.TextSize = 64
			words.Text = "MYTHIC!"
			words.TextColor3 = CardTheme.colors.mythicTitle
			tag.Text = ""
			break
		end
	end

	if centre then
		raysImage.Position = UDim2.fromOffset(centre.X, centre.Y)
		ring.Position = UDim2.fromOffset(centre.X, centre.Y)
		words.Position =
			UDim2.fromOffset(centre.X, if mythicTitle then centre.Y else centre.Y - 230)
		tag.Position = UDim2.fromOffset(centre.X, centre.Y - 184)
	end
	raysImage.ImageTransparency = 1 - raysAlpha * 0.9
	raysImage.Rotation = (now * 30) % 360
	flashFrame.BackgroundTransparency = 1 - flashAlpha
	ring.Visible = ringP >= 0
	if ringP >= 0 then
		local size = 160 * (0.3 + 2.2 * ringP)
		ring.Size = UDim2.fromOffset(size, size);
		(ring:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = ringP
	end
	words.TextTransparency = 1 - wordsAlpha
	-- The panel's own title steps aside while a celebration's words are up.
	local heading, sub = title, subtitle
	local celebrating = away ~= nil and away.kind == "Celebrate"
	for _, label in { heading, sub } do
		if label then
			local hidden = if celebrating then wordsAlpha else 0
			label.TextTransparency = hidden;
			(label:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = hidden
		end
	end
	(words:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 1 - wordsAlpha;
	(words:FindFirstChildOfClass("UIScale") :: UIScale).Scale = math.max(wordsPop, 0.01)
	tag.TextTransparency = 1 - wordsAlpha
	tag.BackgroundTransparency = if tag.Text == "" then 1 else 1 - wordsAlpha;
	(tag:FindFirstChildOfClass("UIScale") :: UIScale).Scale = math.max(wordsPop, 0.01)

	-- The panel darkens to crimson while a Mythic is revealed.
	local p = panel
	if p then
		local crimson = 0
		for _, slot in slots do
			local mythic = slot.mythic
			if mythic then
				local t = now - mythic.start
				crimson = math.max(
					crimson,
					if t < 0
						then 0
						elseif t < MythicReveal.settleEnd + 1 then math.min(t / 0.6, 1)
						else math.max(0, 1 - (t - MythicReveal.settleEnd - 1) / 0.6)
				)
			end
		end
		p.BackgroundColor3 = panelBase:Lerp(Color3.fromRGB(58, 8, 18), crimson)
	end
end

local function step(deltaTime: number)
	local now = os.clock()
	local away = leaving

	for _, slot in slots do
		local i = slot.index
		--[[ A card under the pointer, or picked, holds still, so its words
		     can be read; only the cards left alone float. ]]
		local still = slot.hovered or selected == i
		slot.float += ((if still then 0 else 1) - slot.float) * math.min(1, deltaTime * 14)
		local calm = slot.float

		--[[ Size eases to where it is going and stops — no spring, no pop.
		     A size that overshoots and settles throbs the card's words,
		     which read as the text pulsing for a second after a click. ]]
		local sizeTarget = slot.scaleSpring.target
		slot.scaleSpring.x += (sizeTarget - slot.scaleSpring.x) * math.min(1, deltaTime * 16)
		slot.scaleSpring.v = 0

		-- Where the card wants to be: its place in the fanned hand, lifted
		-- under the pointer or when picked, floating a little when let be.
		local fan = i - (#slots + 1) / 2
		local raise = if selected == i
			then CARD_SELECT_LIFT
			elseif slot.hovered then CARD_HOVER_LIFT
			else 0
		local bob = math.sin(now * 1.8 + i * 1.1) * 3 * calm
		local table_ = slot.base + Vector2.new(0, fan * fan * FAN_DROP)
		local target = table_ + Vector2.new(0, raise + bob)

		-- Held in the deck until dealt, then chasing its place.
		if now >= slot.dealAt then
			local frames = math.clamp(math.floor(deltaTime * 60 + 0.5), 1, 4)
			for _ = 1, frames do
				slot.vel = (slot.vel + (target - slot.pos) * FOLLOW_K) * FOLLOW_D
				slot.pos += slot.vel
			end
		end
		local leanTarget = math.clamp(slot.vel.X * LEAN_PER_PX, -LEAN_MAX, LEAN_MAX)
		slot.lean += (leanTarget - slot.lean) * math.min(1, deltaTime * 14)

		local rotation = fan * FAN_TURN + math.sin(now * 1.3 + i * 1.7) * 1.4 * calm + slot.lean
		local offset = slot.pos - slot.base
		local scale = slot.scaleSpring.x

		--[[ Balatro's juice, the wobble only: a turn on a square fall-off.
		     No size pop — the owner found the card's words pulsing. ]]
		local juice = slot.juice
		if juice then
			local e = now - juice.at
			if e >= JUICE_TIME then
				slot.juice = nil
			else
				local left = 1 - e / JUICE_TIME
				rotation += juice.rot * math.sin(40.8 * e) * left ^ 2
			end
		end
		local transparency = if now < slot.dealAt then 1 else 0

		-- A gamepad's focused card stands forward; the others step back.
		if mode == "Gamepad" and not away then
			if focused == i then
				scale += 0.07
				offset += Vector2.new(0, -16)
			else
				scale -= 0.06
				transparency = math.max(transparency, 0.18)
			end
		end

		-- A Mythic's reveal: shake, the squeeze through its swap, a settle.
		local mythic = slot.mythic
		if mythic then
			local t = now - mythic.start
			if t < 0 then
				mythic.back.Visible = true
				slot.card.root.Visible = false
			else
				local shake, swell, lift, faceUp = MythicReveal.pose(t)
				offset += shake + Vector2.new(0, lift)
				scale *= swell
				mythic.back.Visible = not faceUp
				slot.card.root.Visible = faceUp;
				(mythic.back:FindFirstChildOfClass("UIScale") :: UIScale).Scale = scale

				if
					t >= MythicReveal.lightningStart
					and not mythic.lightning
					and t < MythicReveal.lightningEnd
				then
					mythic.lightning = MythicReveal.lightning(slot.card.root)
				end
				local bolts = mythic.lightning
				if bolts then
					if t >= MythicReveal.lightningEnd then
						bolts.destroy()
						mythic.lightning = nil
					else
						bolts.step(t - MythicReveal.lightningStart)
					end
				end
			end
		end

		if away then
			if away.kind == "Celebrate" then
				local t = now - away.at
				if away.picked == i then
					-- To the middle, bigger, then into its icon.
					local e = Motion.backOut(math.clamp(t / 0.38, 0, 1))
					offset += Vector2.new(-slot.base.X * e, -24 * e)
					scale += 0.38 * e
					local shrink = math.clamp((t - 1.0) / 0.14, 0, 1)
					scale *= 1 - 0.7 * shrink
					transparency = math.max(transparency, shrink)
				else
					local e = Motion.quadIn(math.clamp(t / 0.42, 0, 1))
					offset += Vector2.new(0, 520 * e)
					rotation += (if i < (away.picked or 0) then -40 else 40) * e
					transparency = math.max(transparency, e)
				end
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

		--[[ The shadow stays on the table while the card rises: it falls
		     further below and to the side, and fades, the higher the card
		     is. Off while the hand is leaving or the card is off the table. ]]
		local height = math.max(0, table_.Y - slot.pos.Y)
		local shadowAt = Vector2.new(slot.pos.X + height * 0.15, table_.Y + 10 + height * 0.45)
		local shade = SHADOW_OPACITY * (1 - math.min(0.6, height * 0.012))
		slot.shadow.Position = UDim2.fromOffset(shadowAt.X + rowWidth / 2, CARD.Y / 2 + shadowAt.Y)
		slot.shadow.Rotation = rotation
		slot.shadow.Size = UDim2.fromOffset(CARD.X * scale, CARD.Y * scale)
		slot.shadow.BackgroundTransparency = if away or slot.mythic
			then 1
			else 1 - shade * (1 - transparency)

		-- The shine brightens on hover but stays put, like the card.
		slot.card.setShine(0, if slot.hovered or selected == i then 0.8 else 0.3)
		slot.card.step(now)
	end

	stepOverlay(now)
	stepButtons(deltaTime)
end

function DraftScreen.stop()
	clearSlots()
	table.clear(buttonFeels)
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
	buttonsFrame = buttons
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
	buttonsList = list

	local rerollB = button(buttons, "Reroll", "Reroll 2", CardTheme.colors.reroll, 150);
	(rerollB.Parent :: Frame).LayoutOrder = 1
	rerollB.Activated:Connect(reroll)
	rerollButton = rerollB

	local chooseB = button(buttons, "Choose", "Choose!", CardTheme.colors.disabled, 170);
	(chooseB.Parent :: Frame).LayoutOrder = 2
	chooseB.Activated:Connect(confirm)
	chooseButton = chooseB

	-- The overlay: rays, a flash, a shockwave ring, words and a flying icon.
	local over = Instance.new("Frame")
	over.Name = "Overlay"
	over.BackgroundTransparency = 1
	over.Size = UDim2.fromScale(1, 1)
	over.ZIndex = 50
	over.Parent = created

	local rayImage = Instance.new("ImageLabel")
	rayImage.Name = "Rays"
	rayImage.BackgroundTransparency = 1
	rayImage.Image = CardAssets.rays
	rayImage.ImageColor3 = CardTheme.colors.paleGold
	rayImage.ImageTransparency = 1
	rayImage.AnchorPoint = Vector2.new(0.5, 0.5)
	rayImage.Size = UDim2.fromOffset(720, 720)
	rayImage.ZIndex = 1
	rayImage.Parent = created
	rays = rayImage

	local flashFrame = Instance.new("Frame")
	flashFrame.Name = "Flash"
	flashFrame.BackgroundColor3 = WHITE
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.ZIndex = 60
	flashFrame.Parent = over
	flash = flashFrame

	local ring = Instance.new("Frame")
	ring.Name = "Shockwave"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Visible = false
	ring.ZIndex = 55
	ring.Parent = over
	corner(ring, 999)
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = WHITE
	ringStroke.Thickness = 6
	ringStroke.Parent = ring
	shockwave = ring

	local words =
		stroked(over, "UPGRADED!", CardTheme.fonts.display, 40, CardTheme.colors.choose, 7)
	words.Name = "Headline"
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.Size = UDim2.fromOffset(420, 52)
	words.TextTransparency = 1
	words.ZIndex = 58
	Instance.new("UIScale").Parent = words
	headline = words

	local tag = stroked(over, "", CardTheme.fonts.display, 16, WHITE, 3)
	tag.Name = "Tag"
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, 28)
	tag.BackgroundColor3 = INK
	tag.BackgroundTransparency = 1
	tag.TextTransparency = 1
	tag.ZIndex = 58
	corner(tag, 14)
	local tagPad = Instance.new("UIPadding")
	tagPad.PaddingLeft = UDim.new(0, 12)
	tagPad.PaddingRight = UDim.new(0, 12)
	tagPad.Parent = tag
	Instance.new("UIScale").Parent = tag
	tagline = tag

	local flying = Instance.new("Frame")
	flying.Name = "Flyer"
	flying.BackgroundTransparency = 1
	flying.AnchorPoint = Vector2.new(0.5, 0.5)
	flying.Size = UDim2.fromOffset(72, 72)
	flying.Visible = false
	flying.ZIndex = 59
	flying.Parent = over
	Instance.new("UIScale").Parent = flying
	flyer = flying

	table.clear(ghosts)
	for index = 1, 3 do
		local ghost = Instance.new("Frame")
		ghost.Name = `Ghost{index}`
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.Size = UDim2.fromOffset(56, 56)
		ghost.BackgroundColor3 = WHITE
		ghost.Visible = false
		ghost.ZIndex = 57
		ghost.Parent = over
		corner(ghost, 999)
		ghosts[index] = ghost
	end

	-- The gamepad's strip: the focused card's name, level, stat and words,
	-- and the button prompts.
	local band = Instance.new("Frame")
	band.Name = "Strip"
	band.AnchorPoint = Vector2.new(0.5, 1)
	band.Position = UDim2.new(0.5, 0, 1, -100)
	band.Size = UDim2.new(1, -60, 0, 34)
	band.BackgroundColor3 = INK
	band.BackgroundTransparency = 0.2
	band.Visible = false
	band.Parent = root
	corner(band, 12)
	local bandText = stroked(band, "", CardTheme.fonts.body, 13, WHITE, 0)
	bandText.Size = UDim2.fromScale(1, 1)
	bandText.TextWrapped = true
	strip = band
	stripText = bandText

	local promptRow = Instance.new("Frame")
	promptRow.Name = "Prompts"
	promptRow.BackgroundTransparency = 1
	promptRow.AnchorPoint = Vector2.new(0.5, 1)
	promptRow.Position = UDim2.new(0.5, 0, 1, -8)
	promptRow.Size = UDim2.fromOffset(420, 22)
	promptRow.Visible = false
	promptRow.Parent = root
	local promptList = Instance.new("UIListLayout")
	promptList.FillDirection = Enum.FillDirection.Horizontal
	promptList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	promptList.VerticalAlignment = Enum.VerticalAlignment.Center
	promptList.SortOrder = Enum.SortOrder.LayoutOrder
	promptList.Padding = UDim.new(0, 6)
	promptList.Parent = promptRow
	local keys = {
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonX,
	}
	local captions = { "", "Move", "Choose", "Reroll" }
	for index, key in keys do
		local glyph = Instance.new("ImageLabel")
		glyph.BackgroundTransparency = 1
		glyph.LayoutOrder = index * 2 - 1
		glyph.Size = UDim2.fromOffset(22, 22)
		glyph.Image = UserInputService:GetImageForKeyCode(key)
		glyph.Parent = promptRow
		if captions[index] ~= "" then
			local word = stroked(promptRow, captions[index], CardTheme.fonts.display, 14, WHITE, 3)
			word.LayoutOrder = index * 2
			word.AutomaticSize = Enum.AutomaticSize.X
			word.Size = UDim2.fromOffset(0, 22)
		end
	end
	prompts = promptRow

	connection = RunService.RenderStepped:Connect(step)
end

local function unbindGamepad()
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
end

--[[ While a hand is up on a gamepad: left and right move the focus, A
     chooses the focused card and X rerolls. ]]
local function bindGamepad()
	unbindGamepad()
	local function onMove(
		_name: string,
		state: Enum.UserInputState,
		input: InputObject
	): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin or locked then
			return Enum.ContextActionResult.Sink
		end
		local left = input.KeyCode == Enum.KeyCode.DPadLeft
			or (input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.X < -0.5)
		local right = input.KeyCode == Enum.KeyCode.DPadRight
			or (input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.X > 0.5)
		if left then
			setFocus(focused - 1)
		elseif right then
			setFocus(focused + 1)
		end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindActionAtPriority(
		"DraftLeft",
		onMove,
		false,
		3000,
		Enum.KeyCode.DPadLeft
	)
	ContextActionService:BindActionAtPriority(
		"DraftRight",
		onMove,
		false,
		3000,
		Enum.KeyCode.DPadRight
	)
	ContextActionService:BindActionAtPriority(
		"DraftChoose",
		function(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				confirm()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		3000,
		Enum.KeyCode.ButtonA
	)
	ContextActionService:BindActionAtPriority(
		"DraftReroll",
		function(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				reroll()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		3000,
		Enum.KeyCode.ButtonX
	)
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
	mode = currentMode()
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
		setButton(
			rerollB,
			left > 0,
			if left > 0 then CardTheme.colors.reroll else CardTheme.colors.disabled
		)
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

	local rarest = 0
	for _, id in offer do
		local ability = Abilities.byId[id]
		local rarity = if ability then Rarities.byName[ability.rarity] else nil
		if rarity then
			rarest = math.max(rarest, rarity.tier)
		end
	end
	panelBase = if rarest >= 6
		then PANEL_MYTHIC
		elseif rarest == 5 then PANEL_LEGENDARY
		else CardTheme.colors.panel

	local isPad = mode == "Gamepad"
	if strip then
		strip.Visible = isPad
	end
	if prompts then
		prompts.Visible = isPad
	end
	if isPad then
		bindGamepad()
		setFocus(math.min(2, #slots))
	else
		unbindGamepad()
	end

	-- The overlay's words belong to whoever uses them next.
	local banner, tag = headline, tagline
	if banner then
		banner.Text = "UPGRADED!"
		banner.TextColor3 = CardTheme.colors.choose
	end
	if tag then
		tag.Text = ""
	end

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
	--[[ The bar stays up through the fight, back at its combat size; after
	     a pick it waits a moment first, so the icon landing and its slot
	     popping are seen at the size they were aimed at. ]]
	local token = dealToken
	task.delay(0.8, function()
		if dealToken == token and not (gui and gui.Enabled) then
			SkillBar.toCombat()
		end
	end)
	unbindGamepad()
	if flyer then
		flyer.Visible = false
	end
end

return DraftScreen
