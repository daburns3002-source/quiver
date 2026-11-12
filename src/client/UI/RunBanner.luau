--!strict
--[[
	The run's top HUD: how close the next card is, where you are in the
	level, what you hold, and what the run wants from you next.

	It replaced a placeholder (a 6-pixel XP bar under a room line that came
	to about 11 points on a phone; the 2026-11-11 loop and UI review). Now,
	in the chunky UI's style (`UI/Chunky`: its rounded font, dark outlines,
	lit fills), sized in screen points so a phone reads it as a computer
	does (`Config/Hud` `top`, placed by `Util/RunHudRules.top`):

	- a thick XP bar with the hero's level on a gold badge at its left end.
	  A card screen that arrives out of nowhere cannot be planned for; this
	  is what says one more kill will bring it. The badge carries only the
	  number: "Level" is the stage's word (Mossy Glade 1-3), and the two
	  used to share it.
	- the coins, on the pill at the bar's right. Kill coins fly to its icon
	  (`Fx/CoinDrops`, which finds it by the `CoinCounter` tag and counts
	  the `CoinsShown` attribute up as they land); without that it shows
	  the wallet's own `Coins`.
	- the room counter and the stage's rooms as pips: lit behind you, white
	  where you stand, red for the last. A stage with too many rooms to draw
	  keeps the counter and names the room instead.
	- a line for what happens next, shown only when there is something to
	  say.

	Displays only. The server decides what room it is and whether it is
	cleared; this is told. `UI/LobbyHud` puts the whole ScreenGui away in
	the lobby by its name, `RunBanner`.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Hud = require(ReplicatedStorage.Shared.Config.Hud)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)

local Chunky = require(script.Parent.Chunky)
local Haptics = require(script.Parent.Parent.Fx.Haptics)
local HudLayout = require(script.Parent.HudLayout)

local RunBanner = {}

local T = Hud.top

--[[ The tag `Fx/CoinDrops` flies kill coins to, and the attribute it counts
     up as they land (the payouts' coin-counter contract). ]]
local COIN_TAG = "CoinCounter"
local COINS_SHOWN = "CoinsShown"

local XP_TOP = Color3.fromRGB(255, 226, 92)
local XP_BOTTOM = Chunky.orange
local GOOD = Color3.fromRGB(150, 255, 130)
local BAD = Color3.fromRGB(255, 120, 112)
local PIP_DARK = Chunky.trough
local PIP_LIT = Chunky.green
local PIP_LAST = Chunky.red

local root: Frame? = nil
local xpFill: Frame? = nil
local badgeScale: UIScale? = nil
local levelLabel: TextLabel? = nil
local coinScale: UIScale? = nil
local coinLabel: TextLabel? = nil
local counterLabel: TextLabel? = nil
local nameLabel: TextLabel? = nil
local pipRow: Frame? = nil
local statusLabel: TextLabel? = nil

local shownLevel = 1
local shownCoins: number? = nil
local pips: { Frame } = {}

local function round(item: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = item
end

local function outline(item: GuiObject, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = Chunky.navy
	stroke.Thickness = thickness
	stroke.Parent = item
	return stroke
end

local function lit(item: GuiObject, top: Color3, bottom: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Parent = item
end

--[[ Words in the chunky font: white with a navy stroke, `size` points
     tall, never wrapped. ]]
local function words(parent: Instance, name: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Chunky.font
	label.TextSize = size
	label.TextColor3 = Chunky.white
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = Chunky.navy
	stroke.Thickness = 2
	stroke.Parent = label
	return label
end

--[[ A quick swell that settles: a level gained, coins landed. ]]
local function pop(scale: UIScale?, to: number)
	if not scale then
		return
	end
	scale.Scale = to
	TweenService:Create(
		scale,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

local function coinsNow(): number
	local player = Players.LocalPlayer
	local shown = player:GetAttribute(COINS_SHOWN)
	if type(shown) == "number" then
		return shown
	end
	local coins = player:GetAttribute("Coins")
	return if type(coins) == "number" then coins else 0
end

local function showCoins()
	local label = coinLabel
	if not label then
		return
	end
	local coins = math.max(0, math.floor(coinsNow()))
	if shownCoins and coins > shownCoins then
		-- earned: the number runs up and the pill swells
		Chunky.count(label, coins)
		pop(coinScale, 1.18)
	else
		label:SetAttribute("CountTo", nil)
		label.Text = Chunky.commas(coins)
	end
	shownCoins = coins
end

local function build(gui: ScreenGui)
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	top.Parent = gui
	root = top

	-- The XP row: badge, bar, coins.
	local xpRow = Instance.new("Frame")
	xpRow.Name = "Xp"
	xpRow.BackgroundTransparency = 1
	xpRow.Size = UDim2.new(1, 0, 0, T.badge)
	xpRow.Parent = top

	local trough = Instance.new("Frame")
	trough.Name = "Track"
	trough.AnchorPoint = Vector2.new(0, 0.5)
	trough.Position = UDim2.new(0, T.badge / 2, 0.5, 0)
	trough.Size = UDim2.new(1, -(T.badge / 2 + T.coinWidth + T.edge), 0, T.xpHeight)
	trough.BackgroundColor3 = Chunky.trough
	trough.BorderSizePixel = 0
	trough.Parent = xpRow
	round(trough, T.xpHeight / 2)
	outline(trough, 2.5)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = trough
	round(fill, T.xpHeight / 2)
	lit(fill, XP_TOP, XP_BOTTOM)
	xpFill = fill

	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.7
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, T.badge / 2, 0.14, 0)
	gloss.Size = UDim2.new(1, -(T.badge / 2 + 6), 0.28, 0)
	gloss.ZIndex = 2
	gloss.Parent = trough
	round(gloss, T.xpHeight / 4)

	local plate = Instance.new("Frame")
	plate.Name = "Level"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.new(0, T.badge / 2, 0.5, 0)
	plate.Size = UDim2.fromOffset(T.badge, T.badge)
	plate.BackgroundColor3 = Color3.new(1, 1, 1)
	plate.BorderSizePixel = 0
	plate.ZIndex = 3
	plate.Parent = xpRow
	round(plate, T.badge * 0.3)
	outline(plate, 2.5)
	lit(plate, Color3.fromRGB(255, 232, 110), Chunky.gold)
	local plateScale = Instance.new("UIScale")
	plateScale.Parent = plate
	badgeScale = plateScale

	local level = words(plate, "Number", T.badge * 0.62)
	level.Size = UDim2.fromScale(1, 1)
	level.TextScaled = true
	level.ZIndex = 4
	level.Text = "1"
	local levelCap = Instance.new("UITextSizeConstraint")
	levelCap.MaxTextSize = math.floor(T.badge * 0.62)
	levelCap.Parent = level
	local levelPad = Instance.new("UIPadding")
	levelPad.PaddingLeft, levelPad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
	levelPad.Parent = level
	levelLabel = level

	local coins = Instance.new("Frame")
	coins.Name = "Coins"
	coins.AnchorPoint = Vector2.new(1, 0.5)
	coins.Position = UDim2.fromScale(1, 0.5)
	coins.Size = UDim2.fromOffset(T.coinWidth, T.coinHeight)
	coins.BackgroundTransparency = 1
	coins.Parent = xpRow
	local coinsScale = Instance.new("UIScale")
	coinsScale.Parent = coins
	coinScale = coinsScale

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0, 0.5)
	pill.Position = UDim2.new(0, T.coinHeight * 0.4, 0.5, 0)
	pill.Size = UDim2.new(1, -T.coinHeight * 0.4, 0.8, 0)
	pill.BackgroundColor3 = Chunky.panelTop
	pill.BorderSizePixel = 0
	pill.Parent = coins
	round(pill, T.coinHeight / 2)
	outline(pill, 2.5)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Size = UDim2.fromOffset(T.coinHeight + 2, T.coinHeight + 2)
	icon.Image = ShopAssets.coin
	icon.ZIndex = 3
	icon.Parent = coins
	CollectionService:AddTag(icon, COIN_TAG)

	local amount = words(pill, "Amount", T.coinHeight * 0.58)
	amount.Position = UDim2.fromOffset(T.coinHeight * 0.7, 0)
	amount.Size = UDim2.new(1, -(T.coinHeight * 0.7 + 8), 1, 0)
	amount.TextScaled = true
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.TextColor3 = Chunky.coinText
	amount.ZIndex = 2
	local amountCap = Instance.new("UITextSizeConstraint")
	amountCap.MaxTextSize = math.floor(T.coinHeight * 0.58)
	amountCap.Parent = amount
	coinLabel = amount

	-- The room row: the counter, then the pips or the room's name.
	local roomRow = Instance.new("Frame")
	roomRow.Name = "Room"
	roomRow.BackgroundTransparency = 1
	roomRow.Position = UDim2.fromOffset(0, T.badge + T.rowGap)
	roomRow.Size = UDim2.new(1, 0, 0, T.roomHeight)
	roomRow.Parent = top
	local across = Instance.new("UIListLayout")
	across.FillDirection = Enum.FillDirection.Horizontal
	across.VerticalAlignment = Enum.VerticalAlignment.Center
	across.SortOrder = Enum.SortOrder.LayoutOrder
	across.Padding = UDim.new(0, 8)
	across.Parent = roomRow

	local counter = words(roomRow, "Counter", T.roomHeight * 0.85)
	counter.LayoutOrder = 1
	counter.AutomaticSize = Enum.AutomaticSize.X
	counter.Size = UDim2.fromScale(0, 1)
	counter.TextTruncate = Enum.TextTruncate.None
	counterLabel = counter

	local row = Instance.new("Frame")
	row.Name = "Pips"
	row.LayoutOrder = 2
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(0, 1)
	row.Parent = roomRow
	local rowFlex = Instance.new("UIFlexItem")
	rowFlex.FlexMode = Enum.UIFlexMode.Fill
	rowFlex.Parent = row
	local pipsAcross = Instance.new("UIListLayout")
	pipsAcross.FillDirection = Enum.FillDirection.Horizontal
	pipsAcross.VerticalAlignment = Enum.VerticalAlignment.Center
	pipsAcross.HorizontalFlex = Enum.UIFlexAlignment.Fill
	pipsAcross.SortOrder = Enum.SortOrder.LayoutOrder
	pipsAcross.Padding = UDim.new(0, 4)
	pipsAcross.Parent = row
	pipRow = row

	local name = words(roomRow, "Name", T.roomHeight * 0.8)
	name.LayoutOrder = 3
	name.Size = UDim2.fromScale(0, 1)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.fromRGB(255, 236, 200)
	name.Visible = false
	local nameFlex = Instance.new("UIFlexItem")
	nameFlex.FlexMode = Enum.UIFlexMode.Fill
	nameFlex.Parent = name
	nameLabel = name

	local status = words(top, "Status", T.statusHeight * 0.85)
	status.Position = UDim2.fromOffset(0, T.badge + T.rowGap + T.roomHeight + T.rowGap)
	status.Size = UDim2.new(1, 0, 0, T.statusHeight)
	status.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel = status
end

--[[ Draws `count` pips, reusing the ones already there. ]]
local function drawPips(shape: RunHudRules.Pips)
	local row = pipRow
	if not row then
		return
	end
	for i = #pips + 1, shape.count do
		local pip = Instance.new("Frame")
		pip.Name = "Pip"
		pip.LayoutOrder = i
		pip.BorderSizePixel = 0
		pip.Size = UDim2.fromOffset(0, T.roomHeight * 0.56)
		pip.Parent = row
		round(pip, 3)
		outline(pip, 1.5)
		pips[i] = pip
	end
	for i, pip in pips do
		pip.Visible = i <= shape.count
		if i <= shape.count then
			local last = i == shape.count
			pip.BackgroundColor3 = if i <= shape.lit
				then PIP_LIT
				elseif i == shape.current then Chunky.white
				elseif last then PIP_LAST:Lerp(PIP_DARK, 0.45)
				else PIP_DARK
			local stroke = pip:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if last and i > shape.lit then PIP_LAST else Chunky.navy
			end
		end
	end
end

function RunBanner.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("RunBanner")
	if existing then
		existing:Destroy()
	end
	table.clear(pips)
	shownCoins = nil
	shownLevel = 1

	local gui = Instance.new("ScreenGui")
	gui.Name = "RunBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	build(gui)
	gui.Parent = playerGui

	HudLayout.bindTop(function(layout)
		local top = root
		if top then
			local at = layout.banner
			top.Position = UDim2.fromOffset(at.x, at.y)
			top.Size = UDim2.fromOffset(at.w, at.h)
		end
	end)

	showCoins()
	player:GetAttributeChangedSignal(COINS_SHOWN):Connect(showCoins)
	player:GetAttributeChangedSignal("Coins"):Connect(showCoins)
end

--[[ Argument order matches the remote. `toNext` is what is still owed, not the
     level's total cost, so the bar is drawn from the two numbers the server
     already had rather than from a third it would have to derive. ]]
function RunBanner.onXpChanged(xp: number, toNext: number, level: number)
	local fill = xpFill
	local label = levelLabel
	if not fill or not label then
		return
	end

	local total = xp + toNext
	local share = if total > 0 then math.clamp(xp / total, 0, 1) else 0
	if level ~= shownLevel then
		--[[ A new level starts its bar again: snapped, not run backwards,
		     and the badge swells so the eye catches the number change. ]]
		fill.Size = UDim2.fromScale(share, 1)
		if level > shownLevel then
			pop(badgeScale, 1.35)
			Haptics.play("level")
		end
		shownLevel = level
	else
		TweenService:Create(
			fill,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(share, 1) }
		):Play()
	end
	label.Text = tostring(level)
end

--[[ Argument order matches the remote: the server sends what it knows and the
     client does not reorder or reinterpret it. ]]
function RunBanner.onRunStateChanged(
	index: number,
	total: number,
	state: string,
	name: string,
	unit: string?
)
	local counter = counterLabel
	local status = statusLabel
	local roomName = nameLabel
	local row = pipRow
	if not counter or not status or not roomName or not row then
		return
	end

	if state == "Lobby" then
		counter.Text = ""
		status.Text = ""
		roomName.Visible = false
		row.Visible = false
		return
	end

	counter.Text = RunHudRules.counter(index, total, unit)
	local shape = RunHudRules.pips(index, total, state)
	row.Visible = shape ~= nil
	roomName.Visible = shape == nil
	if shape then
		drawPips(shape)
	else
		roomName.Text = string.upper(name)
	end

	local next_ = RunHudRules.status(state, unit)
	status.Text = next_.words
	status.TextColor3 = if next_.tone == "Good"
		then GOOD
		elseif next_.tone == "Bad" then BAD
		else Chunky.white

	--[[ A short pulse on every change. The row is small and still, so
	     without it a player fighting at the other end of the room will not
	     notice that the room state moved at all. ]]
	counter.TextTransparency = 0.5
	TweenService:Create(counter, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
end

return RunBanner
