--!strict
--[[
	A class's own level, drawn (`Config/ClassLevels`; owner, 2026-11-14):
	the plate with its round level badge and XP bar that the Gear screen and
	the end screens show, the small LEVEL chip on a class select card, the
	LEVEL UP moment the plate plays when a run's XP arrives, and the card
	that shows a golden weapon the moment it is earned.

	Presentation only. The server decides the XP, the levels and the
	weapon (`Run/RoomController`, `Data/Wallet`); this draws what it sent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClassLevelRules = require(ReplicatedStorage.Shared.Util.ClassLevelRules)
local ClassLevels = require(ReplicatedStorage.Shared.Config.ClassLevels)
local ClassSelect = require(ReplicatedStorage.Shared.Config.ClassSelect)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local ItemIcons = require(ReplicatedStorage.Shared.Util.ItemIcons)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

local Chunky = require(script.Parent.Chunky)
local Kit = require(script.Parent.Kit)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local ClassLevelPlate = {}

--[[ The plate's shape, in screen points: lay its frame out this wide to
     this tall. ]]
ClassLevelPlate.W = 360
ClassLevelPlate.H = 84

export type Plate = {
	frame: Frame,
	--[[ Shows a standing as it is. ]]
	set: (ClassLevelRules.Standing) -> (),
	--[[ Plays a run's gain: the bar fills, each level reached pops with its
	     gift, and `done` is called at the end (not if the plate is gone). ]]
	play: (ClassLevelRules.Gain, (() -> ())?) -> (),
}

--[[ The class's colour (`Config/ClassSelect`), gold at the top level. ]]
local function tone(class: string, level: number): Color3
	if level >= ClassLevels.cap then
		return Chunky.gold
	end
	for _, card in ClassSelect.cards do
		if card.class == class then
			return card.colour
		end
	end
	return Chunky.green
end

local function box(
	sheet: Chunky.Sheet,
	x: number,
	y: number,
	w: number,
	h: number,
	z: number
): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.ZIndex = z
	Chunky.put(sheet, f, x, y, w, h)
	return f
end

local function circle(item: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = item
end

--[[ "120 / 300 XP", "MAX LEVEL" at the top. ]]
local function barWords(standing: ClassLevelRules.Standing): string
	local need = ClassLevelRules.need(standing.level)
	if not need then
		return "MAX LEVEL"
	end
	return Chunky.commas(standing.xp) .. " / " .. Chunky.commas(need) .. " XP"
end

--[[ The plate, filling `frame` (lay it out `W` to `H`): the badge with the
     level, the class's name, the bar and the XP on it. ]]
function ClassLevelPlate.build(
	frame: Frame,
	class: string,
	standing: ClassLevelRules.Standing
): Plate
	local sheet = Chunky.pointSheet(frame, ClassLevelPlate.W, ClassLevelPlate.H)
	Chunky.panel(sheet, 6, 4, 708, 144)

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BorderSizePixel = 0
	badge.ZIndex = 12
	Chunky.put(sheet, badge, 24, 20, 112, 112)
	circle(badge)
	local badgeEdge = Chunky.outline(badge, 6)
	local numberBox = Instance.new("Frame")
	numberBox.BackgroundTransparency = 1
	numberBox.Position, numberBox.Size = UDim2.fromScale(0.16, 0.16), UDim2.fromScale(0.68, 0.68)
	numberBox.ZIndex = 13
	numberBox.Parent = badge
	local number: TextLabel? = nil

	local name = Chunky.text(box(sheet, 154, 20, 300, 50, 12), string.upper(class), Chunky.ink, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local level = Chunky.text(box(sheet, 440, 20, 254, 50, 12), "", Chunky.ink, 0)
	level.TextXAlignment = Enum.TextXAlignment.Right

	local trough = Chunky.bar(sheet, 0, Chunky.lime, 154, 80, 540, 50)
	local fill = trough:FindFirstChildWhichIsA("Frame") :: Frame
	local words = Chunky.text(box(sheet, 174, 86, 500, 38, 14), "", Chunky.white, 4)
	--[[ A level's gift, over the bar: the one coin or diamond picture and
	     the number (rule 15), never the word. ]]
	local gift = box(sheet, 154, 80, 540, 50, 15)
	gift.Visible = false
	local giftIcon = Kit.image(gift, ShopAssets.coin)
	giftIcon.AnchorPoint = Vector2.new(1, 0.5)
	giftIcon.Position, giftIcon.Size = UDim2.fromScale(0.47, 0.5), UDim2.fromScale(0.12, 1.1)
	giftIcon.ZIndex = 16
	local giftBox = Instance.new("Frame")
	giftBox.BackgroundTransparency = 1
	giftBox.Position, giftBox.Size = UDim2.fromScale(0.49, 0.1), UDim2.fromScale(0.4, 0.8)
	giftBox.ZIndex = 16
	giftBox.Parent = gift
	local giftWords = Chunky.text(giftBox, "", Chunky.white, 4)
	giftWords.TextXAlignment = Enum.TextXAlignment.Left

	local shown = standing.level
	local function paintBadge(to: number)
		shown = to
		local colour = tone(class, to)
		local lit = badge:FindFirstChildOfClass("UIGradient")
		if lit then
			lit:Destroy()
		end
		Chunky.light(badge, colour)
		badgeEdge.Color = Chunky.shade(colour)
		if number then
			number:Destroy()
		end
		number = Chunky.textOn(numberBox, tostring(to), colour, 6)
		level.Text = ClassLevelRules.words(to)
	end
	local function setFill(share: number)
		fill.Size = UDim2.fromScale(math.clamp(share, 0.03, 1), 1)
	end
	local function set(to: ClassLevelRules.Standing)
		paintBadge(to.level)
		setFill(ClassLevelRules.fraction(to))
		words.Text = barWords(to)
		words.Visible = true
		gift.Visible = false
	end
	set(standing)

	local function alive(): boolean
		return frame.Parent ~= nil
	end
	local function fillTo(share: number, seconds: number)
		local motion = TweenService:Create(
			fill,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(math.clamp(share, 0.03, 1), 1) }
		)
		motion:Play()
		task.wait(seconds)
	end
	local function showGift(icon: string, amount: number)
		giftIcon.Image = icon
		giftWords.Text = "+" .. Chunky.commas(amount)
		words.Visible = false
		gift.Visible = true
		Chunky.pop(gift)
		task.wait(1)
		gift.Visible = false
		words.Visible = true
	end

	local function play(gain: ClassLevelRules.Gain, done: (() -> ())?)
		task.spawn(function()
			set(gain.before)
			words.Text = "+" .. Chunky.commas(gain.xp) .. " XP"
			Chunky.pop(frame)
			task.wait(0.7)
			for _, reached in gain.reached do
				if not alive() then
					return
				end
				fillTo(1, 0.45)
				if not alive() then
					return
				end
				SoundFx.play("level_up")
				paintBadge(reached)
				level.Text = "LEVEL UP!"
				Chunky.pop(badge)
				Chunky.burst(badge)
				setFill(0)
				local present = ClassLevels.gifts[reached]
				if present and (present.coins or 0) > 0 then
					showGift(ShopAssets.coin, present.coins or 0)
				elseif present and (present.gems or 0) > 0 then
					showGift(ShopAssets.gem, present.gems or 0)
				elseif present and (present.crates or 0) > 0 then
					-- opened with its own reveal once the bar has played
					showGift(GearAssets.areaPictures.chests.MossyGlade, present.crates or 0)
				elseif present and (present.eggs or 0) > 0 then
					showGift(GearAssets.areaPictures.eggs.MossyGlade, present.eggs or 0)
				else
					task.wait(0.6)
				end
				if not alive() then
					return
				end
				level.Text = ClassLevelRules.words(reached)
			end
			if not alive() then
				return
			end
			words.Text = barWords(gain.after)
			if shown ~= gain.after.level then
				paintBadge(gain.after.level)
			end
			fillTo(ClassLevelRules.fraction(gain.after), 0.5)
			if alive() and done then
				done()
			end
		end)
	end

	return { frame = frame, set = set, play = play }
end

--[[ The small chip on a class select card: "LEVEL 3", gold "MAX LEVEL" at
     the top. Fills `holder`. ]]
function ClassLevelPlate.chip(holder: Frame, class: string, level: number)
	local colour = if level >= ClassLevels.cap then Chunky.gold else Chunky.white
	holder.BorderSizePixel = 0
	holder.BackgroundTransparency = 0
	Chunky.light(holder, colour)
	circle(holder)
	Chunky.outline(holder, 4, if level >= ClassLevels.cap then Chunky.shade(colour) else nil)
	local words = Chunky.textOn(holder, ClassLevelRules.words(level), colour, 4)
	words.Name = class .. "Level"
	words.Position, words.Size = UDim2.fromScale(0.08, 0.14), UDim2.fromScale(0.84, 0.72)
	words.ZIndex = holder.ZIndex + 1
end

--[[ A golden weapon has just been earned: its card over `layer`, with its
     2D picture (rule 14) in its Legendary frame, its name, what it does and
     where it is kept (it goes on by itself when it is the stronger weapon,
     so the card does not say to put it on). A press anywhere closes it; `closed` is then called. ]]
function ClassLevelPlate.unlock(layer: ScreenGui, weapon: string, closed: (() -> ())?)
	local entry = ShopRules.find(weapon)
	local stats = WeaponStats.weapons[weapon]
	if not entry or not stats then
		if closed then
			closed()
		end
		return
	end
	local dim = Instance.new("TextButton")
	dim.Name = "GoldenWeapon"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BorderSizePixel = 0
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 200
	dim.Parent = layer
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.9, 0.9)
	card.ZIndex = 201
	card.Parent = dim
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 520)
	limit.Parent = card
	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = 420 / 520
	shape.Parent = card
	local sheet = Chunky.pointSheet(card, 420, 520)
	Chunky.panel(sheet, 10, 10, 820, 1000)
	Chunky.ribbon(sheet, "LEVEL " .. ClassLevels.weaponLevel .. " REWARD!", 30, 10, 780, 110)

	local glow = Kit.image(box(sheet, 140, 150, 560, 560, 203), GearAssets.fx.glow)
	glow.ScaleType = Enum.ScaleType.Stretch
	glow.ImageColor3 = Chunky.gold:Lerp(Chunky.white, 0.3)
	glow.ZIndex = 203
	local tile = box(sheet, 240, 250, 360, 360, 204)
	Chunky.tile(tile, stats.rarity, ItemIcons.weapon(weapon))
	local name = Chunky.textOn(box(sheet, 60, 640, 720, 86, 205), entry.label, Chunky.gold, 6)
	name.ZIndex = 205
	local effect =
		Chunky.text(box(sheet, 70, 740, 700, 110, 205), stats.effect or "", Chunky.ink, 0)
	effect.TextWrapped = true
	effect.ZIndex = 205
	local hint = Chunky.text(
		box(sheet, 70, 868, 700, 56, 205),
		"YOURS TO KEEP. FIND IT AT GEAR",
		Chunky.inkSoft,
		0
	)
	hint.ZIndex = 205

	SoundFx.play("level_up")
	Chunky.pop(card)
	task.delay(0.2, function()
		if tile.Parent then
			Chunky.burst(tile)
		end
	end)
	local shownAt = os.clock()
	dim.Activated:Connect(function()
		-- not by the tap that was already on its way to the end screen
		if os.clock() - shownAt < 0.6 then
			return
		end
		dim:Destroy()
		if closed then
			closed()
		end
	end)
end

return ClassLevelPlate
