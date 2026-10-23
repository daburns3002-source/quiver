--!strict
--[[
	The skills this run holds, in the order they were first taken
	(design_handoff_upgrade_cards; README "Skill bar + long-press detail").

	A dark tray of slots at the bottom of the screen, through the fight and
	larger under the draft: each held skill as its icon in a
	ring of its rarity, with its level beneath; the rest empty. Tap a slot
	for its name; hold it to open its whole story in the detail panel. A
	slot pops whenever its skill is taken or levelled.

	Ten slots of 62 with a mouse; on a phone six smaller ones, the last
	showing how many more are held. Presentation only — the order is the
	client's own memory of what arrived when, and nothing reads it back.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardTheme = require(ReplicatedStorage.Shared.Config.CardTheme)
local DetailPanel = require(script.Parent.DetailPanel)
local Device = require(script.Parent.Parent.Parent.Device)
local HudLayout = require(script.Parent.Parent.HudLayout)
local PlayerStats = require(script.Parent.Parent.Parent.PlayerStats)

local SkillBar = {}

local INK = CardTheme.colors.ink
local WHITE = CardTheme.colors.white

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local gui: ScreenGui? = nil
local tray: Frame? = nil
local trayScale: UIScale? = nil
--[[ Whether the bar is in its fight place (`HudLayout`), rather than under
     the draft. ]]
local inCombat = false

local function placeForCombat(layout: HudLayout.Layout)
	local t, s = tray, trayScale
	if inCombat and t and s then
		s.Scale = layout.skillBarScale
		t.Position = layout.skillBarPosition
	end
end
local connections: { RBXScriptConnection } = {}

--[[ First-pick order, and the level each skill was at last time. ]]
local order: { string } = {}
local known: { [string]: number } = {}
--[[ Slots popping: id → when the pop began. ]]
local pops: { [string]: number } = {}
local slotFrames: { [string]: Frame } = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = parent
end

local tooltip: TextLabel? = nil
local tooltipToken = 0

local function showTooltip(slot: Frame, name: string)
	local t = tooltip
	if not t then
		return
	end
	tooltipToken += 1
	local token = tooltipToken
	t.Text = `{name} · hold for more`
	t.Visible = true
	t.Position = UDim2.fromOffset(slot.Position.X.Offset + slot.Size.X.Offset / 2, -12)
	task.delay(CardTheme.timing.tooltipTime, function()
		if tooltipToken == token then
			t.Visible = false
		end
	end)
end

--[[ One held skill's slot. Holding it fills a white disc over the icon and
     sinks the slot a little; held long enough, the detail panel opens. ]]
local function heldSlot(
	parent: Frame,
	id: string,
	level: number,
	size: number,
	index: number
): Frame
	local ability = Abilities.byId[id]
	local slot = Instance.new("Frame")
	slot.Name = id
	slot.BackgroundTransparency = 1
	slot.LayoutOrder = index
	slot.Size = UDim2.fromOffset(size, size + 18)
	slot.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Parent = slot

	local medallion = DetailPanel.medallion(slot, ability, size)
	medallion.AnchorPoint = Vector2.new(0.5, 0)
	medallion.Position = UDim2.new(0.5, 0, 0, 7)

	local maxed = level >= #ability.levels
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(0.5, 0, 0, size + 4)
	badge.Size = UDim2.fromOffset(46, 18)
	badge.BackgroundColor3 = if maxed then CardTheme.colors.gold else INK
	badge.Font = CardTheme.fonts.body
	badge.TextSize = 12
	badge.TextColor3 = if maxed then INK else WHITE
	badge.Text = if maxed then "MAX" else `LVL {level}`
	badge.ZIndex = 5
	badge.Parent = slot
	corner(badge, 9)

	local fill = Instance.new("Frame")
	fill.Name = "Hold"
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.fromScale(0.5, 0.5)
	fill.Size = UDim2.fromScale(0, 0)
	fill.BackgroundColor3 = WHITE
	fill.BackgroundTransparency = 0.18
	fill.ZIndex = 6
	fill.Parent = medallion
	corner(fill, 999)

	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 10
	hit.Parent = slot

	local holdStarted: number? = nil
	local opened = false

	hit.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		holdStarted = os.clock()
		opened = false
		local started = holdStarted
		task.spawn(function()
			while holdStarted == started and not opened do
				local held = os.clock() - (started :: number)
				local p = math.clamp(held / CardTheme.timing.holdToOpen, 0, 1)
				fill.Size = UDim2.fromScale(p, p)
				scale.Scale = 1 - 0.08 * p
				if p >= 1 then
					opened = true
					DetailPanel.show(id, PlayerStats.get().abilities[id] or 0, isTouch())
				end
				RunService.RenderStepped:Wait()
			end
			fill.Size = UDim2.fromScale(0, 0)
			scale.Scale = 1
		end)
	end)

	hit.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if holdStarted and not opened then
			showTooltip(slot, ability.name)
		end
		holdStarted = nil
	end)

	slotFrames[id] = slot
	return slot
end

local function emptySlot(parent: Frame, size: number, index: number, overflow: number?)
	local slot = Instance.new("Frame")
	slot.Name = "Empty"
	slot.BackgroundTransparency = 1
	slot.LayoutOrder = index
	slot.Size = UDim2.fromOffset(size, size + 18)
	slot.Parent = parent

	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0)
	disc.Position = UDim2.new(0.5, 0, 0, 7)
	disc.Size = UDim2.fromOffset(size - 14, size - 14)
	disc.BackgroundColor3 = WHITE
	disc.BackgroundTransparency = 0.94
	disc.Parent = slot
	corner(disc, 999)
	stroke(disc, WHITE, 3, 0.82)

	if overflow then
		local more = Instance.new("TextLabel")
		more.BackgroundTransparency = 1
		more.Size = UDim2.fromScale(1, 1)
		more.Font = CardTheme.fonts.display
		more.TextSize = 18
		more.TextColor3 = WHITE
		more.Text = `+{overflow}`
		more.Parent = disc
	end
end

local function rebuild()
	local t = tray
	if not t then
		return
	end

	for _, child in t:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(slotFrames)

	--[[ The phone's tray by screen size, not by which inputs exist: Studio's
	     phone emulator, and some phones, report a mouse too, and the
	     ten-slot computer tray (738 points) then overflowed a 401-point
	     screen on both sides (owner, 2026-10-22: "not fully visible"). ]]
	local touch = Device.isPhone() or isTouch()
	local count = if touch then 6 else 10
	local size = if touch then 44 else 62
	local held = PlayerStats.get().abilities
	local shown = order
	local overflow = 0
	if #order > count then
		shown = table.move(order, 1, count - 1, 1, {})
		overflow = #order - (count - 1)
	end

	for index = 1, count do
		local id = shown[index]
		if id and Abilities.byId[id] then
			heldSlot(t, id, held[id] or 0, size, index)
		elseif index == count and overflow > 0 then
			emptySlot(t, size, index, overflow)
		else
			emptySlot(t, size, index)
		end
	end

	local gap = 10
	t.Size = UDim2.fromOffset(count * size + (count - 1) * gap + 28, size + 18 + 24)
end

--[[ Notes what is new since the last loadout: a new skill joins the end of
     the bar, and a new or levelled one pops. ]]
local function onLoadout()
	local held = PlayerStats.get().abilities
	local now = os.clock()

	for id, level in held do
		local ability = Abilities.byId[id]
		if not ability or ability.instant then
			continue
		end
		if not table.find(order, id) then
			table.insert(order, id)
		end
		if (known[id] or 0) < level then
			pops[id] = now
		end
		known[id] = level
	end

	-- A reset run holds nothing: start the bar again.
	if next(held) == nil then
		table.clear(order)
		table.clear(known)
	end

	rebuild()
end

local function step()
	local now = os.clock()
	for id, started in pops do
		local slot = slotFrames[id]
		local p = (now - started) / CardTheme.timing.slotPop
		if p >= 1 or not slot then
			pops[id] = nil
			if slot then
				(slot:FindFirstChildOfClass("UIScale") :: UIScale).Scale = 1
			end
			continue
		end
		-- The design's pop: 1 + sin(πp)·0.45·(1 − 0.6p).
		(slot:FindFirstChildOfClass("UIScale") :: UIScale).Scale = 1
			+ math.sin(math.pi * p) * 0.45 * (1 - 0.6 * p)
	end
end

function SkillBar.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if gui then
		gui:Destroy()
		gui = nil
	end
	tray = nil
end

function SkillBar.start()
	SkillBar.stop()

	local created = Instance.new("ScreenGui")
	created.Name = "SkillBar"
	--[[ Inside the phone's safe area, clear of the home bar and rounded
	     corners: ignoring it, the bottom of the HUD ran under them and was
	     cut off (owner, 2026-10-22). ]]
	created.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	created.ResetOnSpawn = false
	created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	created.DisplayOrder = 101
	created.Enabled = false
	created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = created

	local t = Instance.new("Frame")
	t.Name = "Tray"
	t.AnchorPoint = Vector2.new(0.5, 1)
	t.Position = UDim2.new(0.5, 0, 1, -16)
	t.BackgroundColor3 = INK
	t.BackgroundTransparency = 0.18
	t.Parent = created
	corner(t, 22)
	stroke(t, INK, 4)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = t
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 10)
	list.Parent = t
	local fit = Instance.new("UIScale")
	fit.Parent = t
	tray = t
	trayScale = fit

	local tip = Instance.new("TextLabel")
	tip.Name = "Tooltip"
	tip.Visible = false
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.AutomaticSize = Enum.AutomaticSize.X
	tip.Size = UDim2.fromOffset(0, 26)
	tip.BackgroundColor3 = INK
	tip.Font = CardTheme.fonts.body
	tip.TextSize = 14
	tip.TextColor3 = WHITE
	tip.ZIndex = 20
	tip.Parent = t
	corner(tip, 10)
	local tipPadding = Instance.new("UIPadding")
	tipPadding.PaddingLeft = UDim.new(0, 10)
	tipPadding.PaddingRight = UDim.new(0, 10)
	tipPadding.Parent = tip
	tooltip = tip

	onLoadout()
	table.insert(connections, PlayerStats.onChanged(onLoadout))
	table.insert(connections, RunService.RenderStepped:Connect(step))
	-- Re-placed when a phone turns mid-fight.
	local turned = HudLayout.bind(placeForCombat)
	if turned then
		table.insert(connections, turned)
	end
end

--[[ Shown under the draft, scaled to match it, in the bottom centre. ]]
function SkillBar.setVisible(visible: boolean, scale: number?)
	if gui then
		gui.Enabled = visible
	end
	local t = tray
	if t and scale then
		-- Under the draft: bottom centre, at the draft's scale.
		inCombat = false
		t.Position = UDim2.new(0.5, 0, 1, -16)
	end
	local s = trayScale
	if s and scale then
		s.Scale = scale
	end
	if not visible then
		DetailPanel.close()
	end
end

--[[ Back at the bottom of the screen at its small fighting size, as it sits
     between drafts. ]]
function SkillBar.toCombat()
	inCombat = true
	SkillBar.setVisible(true)
	placeForCombat(HudLayout.current())
end

--[[ The centre of a slot's icon disc on screen: the slot is square over
     its level badge, so the disc sits half a width down. ]]
local function discCentre(slot: GuiObject): Vector2
	local size = slot.AbsoluteSize
	return slot.AbsolutePosition + Vector2.new(size.X / 2, size.X / 2)
end

--[[
	Where a pick flies to: the skill's own slot when it is already held, or
	the next open slot when it is new — the one it will take, since a new
	skill joins the end of the bar. Never the middle of the bar, which a new
	skill used to aim at, landing between slots ("make sure it goes into the
	next open slot").
]]
function SkillBar.slotPosition(id: string): Vector2?
	local slot = slotFrames[id]
	if slot then
		return discCentre(slot)
	end
	local t = tray
	if not t then
		return nil
	end
	local open: GuiObject? = nil
	for _, child in t:GetChildren() do
		if
			child:IsA("GuiObject")
			and child.Name == "Empty"
			and (open == nil or child.LayoutOrder < (open :: GuiObject).LayoutOrder)
		then
			open = child
		end
	end
	if open then
		return discCentre(open)
	end
	return t.AbsolutePosition + t.AbsoluteSize / 2
end

return SkillBar
