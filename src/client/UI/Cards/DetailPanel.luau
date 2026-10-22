--!strict
--[[
	A skill's full story: every level and what it gives, which ones are
	owned and which comes next (design_handoff_upgrade_cards; README "Skill
	bar + long-press detail" and "Touch").

	Opened by holding a skill — on the skill bar, or on a card in a phone
	draft — and closed with its X, its "Got it" button, or a tap on the
	dimmed screen behind. As a centred panel with a mouse; as a sheet rising
	from the bottom on a touch screen. Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local CardTheme = require(ReplicatedStorage.Shared.Config.CardTheme)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local DetailPanel = {}

local INK = CardTheme.colors.ink
local WHITE = CardTheme.colors.white
local WIDTH = 480

local GROUP_NAMES = {
	arrow = "Arrow",
	power = "Power",
	element = "Element",
	mobility = "Mobility",
	vital = "Vital",
}

local gui: ScreenGui? = nil

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(
	parent: Instance,
	colour: Color3,
	thickness: number,
	mode: Enum.ApplyStrokeMode?
)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
end

local function text(
	parent: Instance,
	value: string,
	font: Enum.Font,
	size: number,
	colour: Color3,
	outline: number
): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = font
	t.Text = value
	t.TextSize = size
	t.TextColor3 = colour
	t.TextWrapped = true
	t.Parent = parent
	if outline > 0 then
		stroke(t, INK, outline, Enum.ApplyStrokeMode.Contextual)
	end
	return t
end

--[[ A skill's icon in a white disc with its rarity's ring and an ink edge. ]]
function DetailPanel.medallion(parent: Instance, ability: Abilities.Ability, size: number): Frame
	local rarity = Rarities.byName[ability.rarity]

	local disc = Instance.new("Frame")
	disc.Name = "Medallion"
	disc.BackgroundColor3 = WHITE
	disc.Size = UDim2.fromOffset(size - 14, size - 14)
	disc.Parent = parent
	corner(disc, 999)
	-- Rarity ring inside an ink ring.
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	ring.Parent = disc
	corner(ring, 999)
	stroke(ring, rarity.color, 4)
	local inkRing = Instance.new("Frame")
	inkRing.Name = "InkRing"
	inkRing.BackgroundTransparency = 1
	inkRing.Position = UDim2.fromOffset(-4, -4)
	inkRing.Size = UDim2.new(1, 8, 1, 8)
	inkRing.Parent = disc
	corner(inkRing, 999)
	stroke(inkRing, INK, 3)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = CardAssets.icons[ability.icon] or ""
	icon.Size = UDim2.fromScale(1, 1)
	icon.Parent = disc
	corner(icon, 999)

	--[[ Legendary and Mythic shine a little. ]]
	if rarity.tier >= 5 then
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.Image = CardAssets.glow
		glow.ImageColor3 = rarity.color
		glow.ImageTransparency = 0.35
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromScale(2, 2)
		glow.ZIndex = disc.ZIndex - 1
		glow.Parent = disc
	end

	return disc
end

local function row(
	parent: Instance,
	order: number,
	ability: Abilities.Ability,
	index: number,
	level: number
)
	local rarity = Rarities.byName[ability.rarity]
	local maxed = level >= #ability.levels
	local owned = index <= level
	local isNext = not maxed and index == level + 1

	local r = Instance.new("Frame")
	r.Name = `Level{index}`
	r.LayoutOrder = order
	r.Size = UDim2.new(1, 0, 0, 36)
	r.BackgroundColor3 = if owned then rarity.color elseif isNext then WHITE else WHITE
	r.BackgroundTransparency = if owned or isNext then 0 else 0.92
	r.Parent = parent
	corner(r, 10)
	if isNext then
		stroke(r, rarity.color, 3)
	end

	local box = text(r, `LVL {index}`, CardTheme.fonts.display, 14, WHITE, 0)
	box.BackgroundTransparency = 0
	box.BackgroundColor3 = INK
	box.Position = UDim2.fromOffset(6, 5)
	box.Size = UDim2.fromOffset(62, 26)
	corner(box, 8)

	local stat = text(
		r,
		ability.stats[index],
		CardTheme.fonts.body,
		16,
		if isNext then INK else WHITE,
		if isNext then 0 else 3
	)
	stat.TextXAlignment = Enum.TextXAlignment.Left
	stat.Position = UDim2.fromOffset(80, 0)
	stat.Size = UDim2.new(1, -170, 1, 0)

	local tagText = if owned then "OWNED" elseif isNext then "NEXT" else ""
	if tagText ~= "" then
		local tag = text(r, tagText, CardTheme.fonts.display, 13, if isNext then WHITE else INK, 0)
		tag.BackgroundTransparency = 0
		tag.BackgroundColor3 = if isNext then rarity.color else WHITE
		tag.AnchorPoint = Vector2.new(1, 0.5)
		tag.Position = UDim2.new(1, -8, 0.5, 0)
		tag.Size = UDim2.fromOffset(72, 24)
		corner(tag, 8)
		stroke(tag, INK, 2)
	end
end

function DetailPanel.close()
	local created = gui
	gui = nil
	if created then
		created:Destroy()
	end
end

--[[ Opens the detail for `abilityId` at the player's `level` of it. `sheet`
     rises from the bottom, as on a phone, with a "Got it" button. ]]
function DetailPanel.show(abilityId: string, level: number, sheet: boolean?)
	DetailPanel.close()

	local ability = Abilities.byId[abilityId]
	if not ability then
		return
	end
	local rarity = Rarities.byName[ability.rarity]
	local top = #ability.levels
	local maxed = level >= top

	local created = Instance.new("ScreenGui")
	created.Name = "SkillDetail"
	created.IgnoreGuiInset = true
	created.ResetOnSpawn = false
	created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	created.DisplayOrder = 120
	created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = created

	local scrim = Instance.new("TextButton")
	scrim.Name = "Scrim"
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.new(0, 0, 0)
	scrim.BackgroundTransparency = 0.45
	scrim.Parent = created
	scrim.Activated:Connect(DetailPanel.close)

	local height = 300 + top * 42
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = CardTheme.colors.detailPanel
	panel.Size = UDim2.fromOffset(WIDTH, height)
	panel.AnchorPoint = if sheet then Vector2.new(0.5, 1) else Vector2.new(0.5, 0.5)
	panel.Position = if sheet then UDim2.new(0.5, 0, 1, height) else UDim2.fromScale(0.5, 0.5)
	panel.Active = true
	panel.Parent = created
	corner(panel, 24)
	stroke(panel, INK, 5)

	-- Fit to the screen, never above design size.
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local fit = Instance.new("UIScale")
	fit.Scale = math.min(1, (viewport.X - 24) / WIDTH, (viewport.Y - 24) / (height + 40))
	fit.Parent = panel

	local medallion = DetailPanel.medallion(panel, ability, 104)
	medallion.AnchorPoint = Vector2.new(0.5, 0)
	medallion.Position = UDim2.fromOffset(WIDTH / 2, 20)

	local pill = text(panel, string.upper(ability.rarity), CardTheme.fonts.display, 14, WHITE, 3)
	pill.BackgroundTransparency = 0
	pill.BackgroundColor3 = rarity.color
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromOffset(WIDTH / 2, 120)
	pill.Size = UDim2.fromOffset(120, 24)
	corner(pill, 12)
	stroke(pill, INK, 3)

	local kind = text(
		panel,
		`{GROUP_NAMES[ability.group] or "Arrow"} skill`,
		CardTheme.fonts.body,
		14,
		WHITE,
		3
	)
	kind.AnchorPoint = Vector2.new(0.5, 0)
	kind.Position = UDim2.fromOffset(WIDTH / 2, 148)
	kind.Size = UDim2.fromOffset(WIDTH - 40, 18)

	local name = text(panel, ability.name, CardTheme.fonts.display, 32, WHITE, 6)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromOffset(WIDTH / 2, 168)
	name.Size = UDim2.fromOffset(WIDTH - 40, 38)

	local status = text(
		panel,
		if level <= 0 then "Not owned" elseif maxed then "MAX LEVEL" else `Level {level} of {top}`,
		CardTheme.fonts.display,
		16,
		CardTheme.colors.titleYellow,
		3
	)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.fromOffset(WIDTH / 2, 208)
	status.Size = UDim2.fromOffset(WIDTH - 40, 20)

	local description = text(panel, ability.description, CardTheme.fonts.body, 16, WHITE, 3)
	description.AnchorPoint = Vector2.new(0.5, 0)
	description.Position = UDim2.fromOffset(WIDTH / 2, 232)
	description.Size = UDim2.fromOffset(WIDTH - 60, 40)

	local rows = Instance.new("Frame")
	rows.Name = "Levels"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(24, 280)
	rows.Size = UDim2.new(1, -48, 0, top * 42)
	rows.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = rows
	for index = 1, top do
		row(rows, index, ability, index, level)
	end

	if sheet then
		local button = Instance.new("TextButton")
		button.Name = "GotIt"
		button.BackgroundColor3 = CardTheme.colors.choose
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -16)
		button.Size = UDim2.fromOffset(200, 50)
		button.Font = CardTheme.fonts.display
		button.Text = "Got it"
		button.TextSize = 20
		button.TextColor3 = WHITE
		button.Parent = panel
		corner(button, 14)
		stroke(button, INK, 4)
		stroke(button, INK, 4, Enum.ApplyStrokeMode.Contextual)
		button.Activated:Connect(DetailPanel.close)
		panel.Size = UDim2.fromOffset(WIDTH, height + 70)

		TweenService
			:Create(panel, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 1, -12),
			})
			:Play()
	else
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.BackgroundColor3 = CardTheme.colors.danger
		close.AnchorPoint = Vector2.new(0.5, 0.5)
		close.Position = UDim2.new(1, -8, 0, 8)
		close.Size = UDim2.fromOffset(44, 44)
		close.Font = CardTheme.fonts.display
		close.Text = "X"
		close.TextSize = 22
		close.TextColor3 = WHITE
		close.Parent = panel
		corner(close, 999)
		stroke(close, INK, 4)
		close.Activated:Connect(DetailPanel.close)
	end
end

function DetailPanel.isOpen(): boolean
	return gui ~= nil
end

return DetailPanel
