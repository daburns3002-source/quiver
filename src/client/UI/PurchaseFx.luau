--!strict
--[[
	The burst on the buyer's screen whenever a purchase goes through (owner,
	2026-11-14: "i also want a big ui effect to play whenever someone
	purchases something").

	**The server says when.** It plays on `Remotes.Purchased`, which the
	server sends once it has taken the price (`Data/Wallet.pay`) or granted
	a Robux receipt or pass (`Data/Purchases`, `Data/Passes`): never on the
	button press, so a purchase that was refused plays nothing, and never
	for a gift (a chest's free egg takes no price).

	**What plays**, for about a second (`Config/PurchaseFx`, sized by
	`Util/PurchaseRules`): rings spread from the button that was pressed,
	the one coin or diamond picture bursts out of it with sparks and falls
	away, a punchy word pops over it, the price drops out of the wallet
	pill, the screen is washed for a moment on a big one, and the purchase
	sound and a shake of the phone. Bigger for a bigger price, biggest for
	Robux and a Legendary bought outright.

	**It is in nobody's way.** Its layer sits over everything a purchase
	shows (the reveal, the store's thank-you) and takes no input; an egg is
	still dropping in while it plays and has a second and more to go before
	it bursts. It is laid out in sheet pixels, so it is the same share of a
	landscape screen and a phone held upright. Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.PurchaseFx)
local PurchaseRules = require(ReplicatedStorage.Shared.Util.PurchaseRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)

local Chunky = require(script.Parent.Chunky)
local Haptics = require(script.Parent.Parent.Fx.Haptics)
local Kit = require(script.Parent.Kit)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local PurchaseFx = {}

local WHITE = Color3.new(1, 1, 1)
--[[ Seconds a piece takes to swell to its size, and the share of the burst
     after which the pieces, the word and the price fade. ]]
local SWELL = 0.07
local FADE_FROM = 0.62

local random = Random.new()
local layer: ScreenGui? = nil
--[[ The bursts playing now, oldest first. ]]
local live: { Frame } = {}
--[[ The last press of a mouse or a finger, in the screen's own pixels. ]]
local pressX: number?, pressY: number?, pressAt: number? = nil, nil, nil

--[[ The colour a purchase paid this way spreads in. ]]
local function colourOf(paid: PurchaseRules.Paid): Color3
	if paid == "gems" or paid == "soulstones" then
		return Chunky.purple
	end
	return Chunky.gold
end

--[[ The pictures a purchase paid this way throws: the one coin, the one
     diamond, both for Robux, and none for Soulstones, which have no
     picture and are thrown as violet diamonds drawn here. ]]
local function picturesOf(paid: PurchaseRules.Paid): { string }
	if paid == "coins" then
		return { ShopAssets.coin }
	elseif paid == "gems" then
		return { ShopAssets.gem }
	elseif paid == "robux" then
		return { ShopAssets.coin, ShopAssets.gem }
	end
	return {}
end

local function outBack(share: number): number
	local s = math.clamp(share, 0, 1) - 1
	return 1 + 2.70158 * s ^ 3 + 1.70158 * s ^ 2
end

local function outCubic(share: number): number
	return 1 - (1 - math.clamp(share, 0, 1)) ^ 3
end

--[[ A square on its corner, the kit's spark (`Chunky.burst`). ]]
local function diamond(parent: Instance, colour: Color3, z: number): Frame
	local piece = Instance.new("Frame")
	piece.Name = "Spark"
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.BorderSizePixel = 0
	piece.BackgroundColor3 = colour
	piece.Rotation = 45
	piece.ZIndex = z
	piece.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = piece
	return piece
end

--[[ The wallet pill on screen that holds what was paid (`Chunky.wallet`
     marks its pills), the topmost screen's if two are up; nil when none is
     showing. ]]
local function walletPill(paid: PurchaseRules.Paid): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local best: GuiObject? = nil
	local bestOrder = -math.huge
	for _, item in playerGui:GetDescendants() do
		if
			item.Name ~= "ChunkyWallet"
			or not item:IsA("GuiObject")
			or item:GetAttribute("Holds") ~= paid
		then
			continue
		end
		local screen = item:FindFirstAncestorWhichIsA("ScreenGui")
		if not screen or not screen.Enabled or screen.DisplayOrder < bestOrder then
			continue
		end
		local shown = true
		local at: Instance? = item
		while at and at ~= screen do
			if at:IsA("GuiObject") and not at.Visible then
				shown = false
				break
			end
			at = at.Parent
		end
		if shown and item.AbsoluteSize.X > 0 then
			best, bestOrder = item, screen.DisplayOrder
		end
	end
	return best
end

--[[ Ends a burst. It leaves `live` here and not on its `Destroying`, which
     may be told late: the loop that makes room would spin on it. ]]
local function finish(holder: Frame)
	local at = table.find(live, holder)
	if at then
		table.remove(live, at)
	end
	holder:Destroy()
end

--[[ Plays the burst for `receipt`. Only `Remotes.Purchased` calls it: the
     server has taken the price by then. ]]
function PurchaseFx.play(receipt: PurchaseRules.Receipt)
	local gui = layer
	if not gui then
		return
	end
	local view = gui.AbsoluteSize
	if view.X <= 0 or view.Y <= 0 then
		return
	end
	local corner = gui.AbsolutePosition
	local unit = PurchaseRules.unit(view.X, view.Y)
	local look = PurchaseRules.look(receipt)
	local colour = colourOf(receipt.paid)
	local pictures = picturesOf(receipt.paid)
	local originX, originY = PurchaseRules.origin(
		receipt,
		view.X,
		view.Y,
		if pressX then pressX - corner.X else nil,
		if pressY then pressY - corner.Y else nil,
		if pressAt then os.clock() - pressAt else nil
	)
	local reach = look.reach * unit
	local length = look.length

	while #live >= Config.most do
		finish(live[1])
	end
	local holder = Instance.new("Frame")
	holder.Name = "Burst"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	-- the kit's strokes are in sheet pixels of this frame (`Chunky.text`)
	holder:SetAttribute("SheetW", view.X / unit)
	holder.Parent = gui
	table.insert(live, holder)

	--[[ Each part of the burst, given the seconds since it began. ]]
	local parts: { (number) -> () } = {}

	if look.flash > 0 then
		local wash = Instance.new("Frame")
		wash.Name = "Wash"
		wash.BorderSizePixel = 0
		wash.BackgroundColor3 = colour
		wash.BackgroundTransparency = 1 - look.flash
		wash.Size = UDim2.fromScale(1, 1)
		wash.ZIndex = 1
		wash.Parent = holder
		table.insert(parts, function(t)
			wash.BackgroundTransparency = 1 - look.flash * math.max(0, 1 - t / 0.35)
		end)
	end

	for n = 1, look.rings do
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.BackgroundTransparency = 1
		ring.Position = UDim2.fromOffset(originX, originY)
		ring.Size = UDim2.fromOffset(0, 0)
		ring.ZIndex = 2
		ring.Parent = holder
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = if n % 2 == 1 then colour else WHITE
		stroke.Transparency = 1
		stroke.Parent = ring
		local wait = (n - 1) * 0.09
		local across = reach * (0.9 + 0.3 * (n - 1))
		table.insert(parts, function(t)
			local share = math.clamp((t - wait) / 0.5, 0, 1)
			local side = across * outCubic(share)
			ring.Size = UDim2.fromOffset(side, side)
			stroke.Thickness = math.max(1, 16 * unit * (1 - share))
			stroke.Transparency = if t < wait then 1 else share ^ 2
		end)
	end

	--[[ Something thrown from the button: out and up, then down under its
	     own weight, turning, and gone by the end. ]]
	local function throw(
		piece: GuiObject,
		side: number,
		speed: number,
		life: number,
		n: number,
		of: number
	)
		local angle = (n + random:NextNumber()) / of * math.pi * 2
		local push = reach * speed * random:NextNumber(0.75, 1.5)
		local vx, vy = math.cos(angle) * push, math.sin(angle) * push - reach * 0.9
		local weight = reach * 3.4
		local wait = random:NextNumber(0, 0.07)
		local turn = random:NextNumber(-420, 420)
		local from = piece.Rotation
		local image = if piece:IsA("ImageLabel") then piece :: ImageLabel else nil
		piece.Visible = false
		table.insert(parts, function(t)
			local age = t - wait
			if age < 0 then
				return
			end
			local share = math.clamp(age / life, 0, 1)
			local fade = math.clamp((share - FADE_FROM) / (1 - FADE_FROM), 0, 1)
			local now = side * math.min(1, age / SWELL) * (1 - fade * 0.5)
			piece.Visible = share < 1
			piece.Position =
				UDim2.fromOffset(originX + vx * age, originY + vy * age + weight * age * age / 2)
			piece.Size = UDim2.fromOffset(now, now)
			piece.Rotation = from + turn * age
			if image then
				image.ImageTransparency = fade
			else
				piece.BackgroundTransparency = fade
			end
		end)
	end

	for n = 1, look.pieces do
		local side = look.piece * unit * random:NextNumber(0.7, 1.15)
		local piece: GuiObject
		if #pictures > 0 then
			local image = Kit.image(holder, pictures[(n - 1) % #pictures + 1])
			image.Name = "Piece"
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.ResampleMode = Enum.ResamplerMode.Default
			image.ZIndex = 4
			piece = image
		else
			piece = diamond(holder, colour, 4)
			side *= 0.6
		end
		throw(piece, side, 1.25, length, n, look.pieces)
	end
	for n = 1, look.sparks do
		local spark = diamond(holder, if n % 2 == 0 then Chunky.gold else WHITE, 3)
		local side = unit * random:NextNumber(14, 30)
		throw(spark, side, 1.7, length * 0.6, n, look.sparks)
	end

	-- The word, over the button, kept on the screen.
	local wordH = look.wordHeight * unit
	local wordW = wordH * 5.4
	local wordX, wordY = PurchaseRules.keepIn(
		originX,
		originY - wordH * 1.5,
		wordW,
		wordH * 1.3,
		view.X,
		view.Y,
		24 * unit
	)
	local word = Instance.new("Frame")
	word.Name = "Word"
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.BackgroundTransparency = 1
	word.Position = UDim2.fromOffset(wordX, wordY)
	word.Size = UDim2.fromOffset(wordW, wordH)
	word.Rotation = -5
	word.ZIndex = 6
	word.Parent = holder
	local wordScale = Instance.new("UIScale")
	wordScale.Scale = 0.2
	wordScale.Parent = word
	local wordLabel = Chunky.text(word, look.word, Chunky.gold, 10)
	wordLabel.ZIndex = 6
	local wordStroke = wordLabel:FindFirstChildOfClass("UIStroke")
	table.insert(parts, function(t)
		local share = t / length
		local fade = math.clamp((share - FADE_FROM - 0.1) / (1 - FADE_FROM - 0.1), 0, 1)
		wordScale.Scale = 0.2 + 0.8 * outBack(t / 0.24)
		word.Position = UDim2.fromOffset(wordX, wordY - 46 * unit * fade)
		wordLabel.TextTransparency = fade
		if wordStroke then
			wordStroke.Transparency = fade
		end
	end)

	-- The price: out of the wallet pill if one is showing, else under the word.
	local words = PurchaseRules.tag(receipt)
	if words then
		local tagH = 68 * unit
		local tagW = tagH * 4.6
		local tagX, tagY =
			PurchaseRules.keepIn(wordX, wordY + wordH * 0.95, tagW, tagH, view.X, view.Y, 12 * unit)
		local drop = 0
		--[[ The pill is looked for a frame late: the price paid has just
		     redrawn the open screen's wallet (`Remotes.ProfileChanged`
		     arrives first), and a pill made this frame has no place yet. ]]
		local looked = false
		local function fromPill()
			looked = true
			local pill = walletPill(receipt.paid)
			if not pill then
				return
			end
			tagX, tagY = PurchaseRules.keepIn(
				pill.AbsolutePosition.X - corner.X + pill.AbsoluteSize.X / 2,
				pill.AbsolutePosition.Y - corner.Y + pill.AbsoluteSize.Y + tagH * 0.5,
				tagW,
				tagH,
				view.X,
				view.Y,
				12 * unit
			)
			drop = 90 * unit
		end
		local tag = Instance.new("Frame")
		tag.Name = "Price"
		tag.AnchorPoint = Vector2.new(0.5, 0.5)
		tag.BackgroundTransparency = 1
		tag.Position = UDim2.fromOffset(tagX, tagY)
		tag.Size = UDim2.fromOffset(tagW, tagH)
		tag.ZIndex = 7
		tag.Parent = holder
		local tagScale = Instance.new("UIScale")
		tagScale.Scale = 0.2
		tagScale.Parent = tag
		local icon: GuiObject
		if #pictures > 0 then
			local image = Kit.image(tag, pictures[1])
			image.ResampleMode = Enum.ResamplerMode.Default
			icon = image
		else
			icon = diamond(tag, colour, 7)
		end
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5 / 4.6, 0.5)
		icon.Size =
			UDim2.fromScale(if #pictures > 0 then 1 else 0.55, if #pictures > 0 then 1 else 0.55)
		icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
		icon.ZIndex = 7
		local amount = Chunky.text(tag, words, WHITE, 6)
		amount.Position, amount.Size =
			UDim2.fromScale(1.1 / 4.6, 0.08), UDim2.fromScale(3.5 / 4.6, 0.84)
		amount.TextXAlignment = Enum.TextXAlignment.Left
		amount.ZIndex = 7
		local amountStroke = amount:FindFirstChildOfClass("UIStroke")
		local image = if icon:IsA("ImageLabel") then icon :: ImageLabel else nil
		table.insert(parts, function(t)
			if not looked and t > 0 then
				fromPill()
			end
			local share = t / length
			local fade = math.clamp((share - FADE_FROM) / (1 - FADE_FROM), 0, 1)
			tagScale.Scale = 0.2 + 0.8 * outBack(t / 0.2)
			tag.Position = UDim2.fromOffset(tagX, tagY + drop * outCubic(share))
			amount.TextTransparency = fade
			if amountStroke then
				amountStroke.Transparency = fade
			end
			if image then
				image.ImageTransparency = fade
			else
				icon.BackgroundTransparency = fade
			end
		end)
	end

	local began = os.clock()
	local step: RBXScriptConnection
	step = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t >= length then
			finish(holder)
			return
		end
		for _, part in parts do
			part(t)
		end
	end)
	holder.Destroying:Once(function()
		step:Disconnect()
	end)
	for _, part in parts do
		part(0)
	end

	SoundFx.play(Config.sound)
	Haptics.play("level")
end

function PurchaseFx.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("PurchaseFx")
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PurchaseFx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = Config.displayOrder
	gui.Parent = playerGui
	layer = gui

	--[[ Where the button pressed was: a press the game's own buttons took
	     counts too, so this does not ask whether it was "processed". ]]
	UserInputService.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressX, pressY, pressAt = input.Position.X, input.Position.Y, os.clock()
		end
	end)
	Remotes.event(Remotes.Purchased).OnClientEvent:Connect(function(raw: unknown)
		local receipt = PurchaseRules.read(raw)
		if receipt then
			PurchaseFx.play(receipt)
		end
	end)
end

return PurchaseFx
