--!strict
--[[
	Tap Simulator Reborn's egg stand (owner, 2026-10-27: "replicated exactly
	1 to 1"; docs/EGG-HATCH-REFERENCE.md), shared by the Egg Hatchery and the
	Blacksmith's crates (owner, 2026-10-27: the weapon chests "changed exactly
	how you are changing the pets and with the same ui"): the name over a
	white card holding the price, the picker and the AUTO toggle, what is
	inside with its odds and the pity bar; the egg or crate beside it with
	its key prompts, E for one and R for three (T toggles AUTO).

	`controller` runs AUTO for a screen: presses follow one another until
	STOP, the screen closes or the coins run out; the stand hides while a
	reveal plays over the backdrop.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Kit = require(script.Parent.Kit)
local Pity = require(ReplicatedStorage.Shared.Util.Pity)
local Reveal = require(script.Parent.Reveal)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local StationScreen = require(script.Parent.StationScreen)
local HatchStand = {}

export type Tile = {
	rarity: string,
	icon: string,
	--[[ The pet's key (`Config/PetModels`), when the card should stand its
	     real model up rather than draw a picture. A weapon has none: its
	     card keeps the 2D art. ]]
	key: string?,
	chance: number,
	owned: boolean,
	--[[ Drawn black on its rarity's card, as Codex's screens draw a Mythic
	     nobody has pulled yet: the colour says how rare, the silhouette
	     keeps what it is a surprise. ]]
	silhouette: boolean?,
}
export type Spec = {
	title: string,
	price: number,
	picker: string,
	onPick: () -> (),
	tiles: { Tile },
	--[[ Why nothing can be opened, if so ("BEAT KING BLOBLIN", ...). ]]
	locked: string?,
	pity: number,
	picture: string,
	--[[ The scene washed in behind the cards (Codex put the Mossy Glade
	     behind his), empty for none. ]]
	backdrop: string,
	--[[ The press counts (1 and 3) and the word on their prompts. ]]
	counts: { number },
	verb: string,
	--[[ What the cards hold, for the line under them: "PETS", "WEAPONS". ]]
	noun: string,
}
export type Controller = {
	auto: boolean,
	toggle: () -> (),
}

local keys = UserInputService.KeyboardEnabled

function HatchStand.commas(n: number): string
	local text = tostring(n)
	repeat
		local formatted, changes = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = formatted
	until changes == 0
	return text
end

--[[
	Codex's grid. He drew the hatchery at 1200x720 and `UI/Kit` lays out
	against 1920x1080, which is the same shape at 1.5x with 60 pixels of
	margin each side, so every number below is one of his own, untouched.
]]
local function at(item: GuiObject, x: number, y: number, w: number, h: number)
	Kit.put(item, 60 + x * 1.5, y * 1.5, w * 1.5, h * 1.5)
end

--[[ A frame of nothing, to hang a panel and its words on. ]]
local function slot(c: Frame, x: number, y: number, w: number, h: number): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Parent = c
	at(holder, x, y, w, h)
	return holder
end

--[[
	Codex's action button: a leaf-green face lit from the top, a gloss bar
	across its head, a soft halo just outside it and the key in the middle
	at nearly the height of the button. Greyed when it cannot be afforded,
	and still pressable, so a player who cannot pay is told rather than
	ignored.
]]
local function prompt(
	c: Frame,
	x: number,
	y: number,
	w: number,
	h: number,
	key: string,
	words: string?,
	can: boolean,
	action: () -> ()
)
	local holder = slot(c, x, y, w, h)
	local face = if can then Color3.fromRGB(132, 245, 43) else Color3.fromRGB(120, 130, 120)

	local halo = Instance.new("Frame")
	halo.BackgroundTransparency = 1
	halo.Position = UDim2.fromScale(-8 / w, -8 / h)
	halo.Size = UDim2.fromScale(1 + 16 / w, 1 + 16 / h)
	halo.ZIndex = 7
	halo.Parent = holder
	local haloRound = Instance.new("UICorner")
	haloRound.CornerRadius = UDim.new(0, 22)
	haloRound.Parent = halo
	local haloEdge = Instance.new("UIStroke")
	haloEdge.Color = Color3.fromRGB(166, 255, 84)
	haloEdge.Thickness = 5
	haloEdge.Transparency = 0.55
	haloEdge.Parent = halo

	local button = Instance.new("Frame")
	button.BackgroundColor3 = face
	button.BorderSizePixel = 0
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 8
	button.Parent = holder
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 18)
	round.Parent = button
	local lit = Instance.new("UIGradient")
	lit.Rotation = 90
	lit.Color =
		ColorSequence.new(face:Lerp(Color3.new(1, 1, 1), 0.3), face:Lerp(Color3.new(0, 0, 0), 0.25))
	lit.Parent = button

	local gloss = Instance.new("Frame")
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.78
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.fromScale(0.09, 0.08)
	gloss.Size = UDim2.fromScale(0.82, 0.3)
	gloss.ZIndex = 10
	gloss.Parent = button
	local glossRound = Instance.new("UICorner")
	glossRound.CornerRadius = UDim.new(0, 10)
	glossRound.Parent = gloss
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	fade.Parent = gloss

	local letter = Kit.pixelText(button, if keys then key else "TAP", 80, Color3.new(1, 1, 1))
	letter.Position = UDim2.fromScale(0.1, if words then 0.06 else 0.16)
	letter.Size = UDim2.fromScale(0.8, if words then 0.56 else 0.68)
	letter.ZIndex = 11
	if words then
		local under = Kit.pixelText(button, words, 24, Color3.fromRGB(255, 224, 71))
		under.Position, under.Size = UDim2.fromScale(0.06, 0.64), UDim2.fromScale(0.88, 0.26)
		under.ZIndex = 11
	end
	Kit.pressFx(Kit.clickArea(holder, action), button, true)
end

--[[ Draws the stand onto `s`'s canvas; `press(count)` asks the server,
     `affordable(count)` says whether it may. ]]
function HatchStand.draw(
	s: StationScreen.Screen,
	spec: Spec,
	control: Controller,
	press: (number) -> (),
	affordable: (number) -> boolean
)
	local c = s.canvas

	--[[ Codex closes with the X inside the panel and carries no wallet at
	     all, so the station's own back arrow is a second close for the same
	     thing and its wallet sits exactly where his title hangs. The arrow
	     goes; the wallet moves into the empty air over his left column. ]]
	local layer = c:FindFirstAncestorWhichIsA("ScreenGui")
	if layer then
		--[[ The Blacksmith carries a second wallet of its own, over the
		     station rather than on the canvas; one of the two is enough. ]]
		for _, other in layer:GetDescendants() do
			if
				other.Name == "Wallet"
				and other:IsA("GuiObject")
				and not other:IsDescendantOf(c)
			then
				other.Visible = false
			end
		end
	end
	for _, child in c:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		elseif child.Name == "Wallet" and child:IsA("GuiObject") then
			local first = child.Position.X.Scale < 0.8
			Kit.put(child, if first then 202 else 482, 40, if first then 264 else 240, 100)
		end
	end

	--[[ The name, in plain outlined Arcade over the panel rather than on a
	     bar of its own: Codex hangs it in the air above everything, and a
	     bar behind it is the thing that made this screen stop being his. ]]
	local titleBox = slot(c, 500, -14, 700, 130)
	local title = Kit.pixelText(titleBox, spec.title, 100)
	title.ZIndex = 20

	--[[ His odds panel: the area's scene filling it corner to corner under
	     a rounded leaf-green edge, and a quiet dark pad over the middle so
	     the forest shows at the perimeter and the cards sit on calm. ]]
	local panelHolder = slot(c, 520, 110, 660, 552)
	local panel = Kit.pixelPanel(panelHolder, 990, 828, Kit.pixelForest)
	for _, part in panel:GetChildren() do
		if part:IsA("Frame") then
			part.BackgroundTransparency = 0.3
		end
	end
	if spec.backdrop ~= "" then
		local scene = Kit.image(panelHolder, spec.backdrop)
		scene.Position, scene.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
		scene.ScaleType = Enum.ScaleType.Crop
		scene.ImageTransparency = 0.38
		scene.ZIndex = 6
		local sceneRound = Instance.new("UICorner")
		sceneRound.CornerRadius = UDim.new(0, 24)
		sceneRound.Parent = scene
		local edge = Instance.new("UIStroke")
		edge.Thickness = 4
		edge.Transparency = 0.3
		edge.Color = Color3.fromRGB(123, 157, 73)
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = scene
	end
	local calm = Instance.new("Frame")
	calm.BackgroundColor3 = Color3.fromRGB(14, 34, 25)
	calm.BackgroundTransparency = 0.04
	calm.BorderSizePixel = 0
	calm.Position = UDim2.fromScale(4 / 660, 72 / 552)
	calm.Size = UDim2.fromScale(652 / 660, 438 / 552)
	calm.ZIndex = 7
	calm.Parent = panelHolder
	local calmRound = Instance.new("UICorner")
	calmRound.CornerRadius = UDim.new(0, 16)
	calmRound.Parent = calm

	-- the price, in his cream pill in the panel's top corner
	local priceHolder = slot(c, 536, 122, 174, 58)
	Kit.pixelPanel(priceHolder, 261, 87, Kit.pixelCream)
	local coin = Kit.image(priceHolder, ShopAssets.coin)
	coin.Position, coin.Size = UDim2.fromScale(0.07, 0.17), UDim2.fromScale(0.22, 0.66)
	coin.ZIndex = 10
	local cost =
		Kit.pixelText(priceHolder, HatchStand.commas(spec.price), 30, Color3.fromRGB(255, 213, 44))
	cost.Position, cost.Size = UDim2.fromScale(0.3, 0.2), UDim2.fromScale(0.64, 0.6)
	cost.ZIndex = 11

	--[[ The picker, as the tabs Codex drew along his chest's top strip:
	     he had one egg and so needed none, and this is where he put the
	     same control when he did need it. ]]
	local pickerHolder = slot(c, 726, 122, 330, 58)
	Kit.pixelPanel(pickerHolder, 495, 87, Color3.fromRGB(23, 43, 30))
	local pickerWords = Kit.pixelText(pickerHolder, `< {spec.picker} >`, 26)
	pickerWords.ZIndex = 11
	local pickerHit = Kit.clickArea(pickerHolder, function()
		if not Reveal.busy() then
			control.auto = false
			spec.onPick()
		end
	end)
	Kit.pressFx(pickerHit, pickerHolder, false)

	-- his close, a red X in the panel's own top corner
	local closeHolder = slot(c, 1114, 122, 50, 50)
	local close = Instance.new("Frame")
	close.BackgroundColor3 = Color3.fromRGB(220, 70, 85)
	close.BorderSizePixel = 0
	close.Size = UDim2.fromScale(1, 1)
	close.ZIndex = 14
	close.Parent = closeHolder
	local closeRound = Instance.new("UICorner")
	closeRound.CornerRadius = UDim.new(0, 12)
	closeRound.Parent = close
	local cross = Kit.pixelText(close, "X", 34, Color3.new(1, 1, 1))
	cross.ZIndex = 15
	Kit.pressFx(Kit.clickArea(closeHolder, s.close), close, false)

	--[[ What is inside, on his cards. The grid measures itself: an egg
	     holds eight in two rows and a crate twelve in three, so the row
	     pitch closes up as the rows grow rather than running off the pad. ]]
	local held = #spec.tiles
	local perRow = 4
	local rows = math.max(math.ceil(held / perRow), 1)
	--[[ The cards fill the quiet pad rather than a fixed pitch: eight pets
	     sit in two roomy rows and twelve weapons in three shorter ones, and
	     neither runs over the pad's edge. ]]
	local gap = 9
	local wide = math.min(153, (628 - (perRow - 1) * gap) // perRow)
	local tall = math.min(159, (414 - (rows - 1) * gap) // rows)
	for i, entry in spec.tiles do
		local col, row = (i - 1) % perRow, (i - 1) // perRow
		local holder = slot(c, 540 + col * (wide + gap), 206 + row * (tall + gap), wide, tall)
		holder.ZIndex = 8
		Kit.rarityCard(
			holder,
			entry.rarity,
			entry.icon,
			entry.chance,
			entry.silhouette == true or spec.locked ~= nil,
			entry.owned,
			entry.key
		)
	end

	-- how many are in there, then the pity bar, both along the panel's foot
	local tallyBox = slot(c, 536, 622, 628, 22)
	local tally = Kit.pixelText(tallyBox, `{held} {spec.noun}`, 24)
	tally.ZIndex = 11

	local track = Instance.new("Frame")
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Color3.fromRGB(14, 34, 25)
	track.ZIndex = 8
	track.Parent = c
	at(track, 536, 644, 628, 18)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = track
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Size = UDim2.fromScale(math.clamp(spec.pity / Pity.EVERY, 0.04, 1), 1)
	fill.ZIndex = 9
	fill.Parent = track
	local curve = Instance.new("UICorner")
	curve.CornerRadius = UDim.new(0.5, 0)
	curve.Parent = fill
	local colours = {}
	for n = 0, 6 do
		table.insert(colours, ColorSequenceKeypoint.new(n / 6, Color3.fromHSV(n / 7, 0.75, 1)))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colours)
	gradient.Parent = fill
	Kit.pityLine(c, spec.pity, 60 + 536 * 1.5, 645 * 1.5, 628 * 1.5, 16 * 1.5)

	--[[ Codex's left column: the verb in big soft letters with his one
	     green key under it. The second count and AUTO are the game's own
	     controls, in his button and sitting on his baseline. ]]
	local wordBox = slot(c, 95, 178, 400, 114)
	local word = Kit.pixelText(wordBox, spec.verb, 96, Color3.fromRGB(229, 255, 184))
	word.ZIndex = 20

	if spec.locked then
		local lock = Kit.image(c, ShopAssets.lock)
		at(lock, 790, 200, 120, 104)
		lock.ZIndex = 16
		local whyBox = slot(c, 620, 320, 460, 54)
		local why = Kit.pixelText(whyBox, spec.locked, 34, Color3.fromRGB(255, 213, 44))
		why.ZIndex = 16
	end

	--[[ Codex's one key, in the middle of his column (owner, 2026-10-31:
	     "take the R button away, the E should just be there in the
	     middle"). The other counts keep their keys — only the second
	     button goes. ]]
	local single = spec.counts[1]
	if single then
		prompt(c, 200, 290, 180, 154, "E", nil, affordable(single), function()
			press(single)
		end)
	end

	local autoHolder = slot(c, 95, 478, 390, 62)
	local autoFace = Instance.new("Frame")
	autoFace.BackgroundColor3 = if control.auto
		then Color3.fromRGB(132, 245, 43)
		else Color3.fromRGB(90, 110, 95)
	autoFace.BorderSizePixel = 0
	autoFace.Size = UDim2.fromScale(1, 1)
	autoFace.ZIndex = 8
	autoFace.Parent = autoHolder
	local autoRound = Instance.new("UICorner")
	autoRound.CornerRadius = UDim.new(0, 16)
	autoRound.Parent = autoFace
	local autoWords = Kit.pixelText(autoFace, "AUTO" .. (if keys then " [T]" else ""), 30)
	autoWords.Position, autoWords.Size = UDim2.fromScale(0.08, 0.22), UDim2.fromScale(0.84, 0.56)
	autoWords.ZIndex = 11
	Kit.pressFx(Kit.clickArea(autoHolder, control.toggle), autoFace, false)
end

--[[ AUTO, the keys and the STOP button for a stand screen. `active` says
     whether the stand is showing (a screen may have other tabs). ]]
function HatchStand.controller(
	s: StationScreen.Screen,
	counts: { number },
	press: (number) -> (),
	affordable: (number) -> boolean,
	active: () -> boolean
): Controller
	local control: Controller = { auto = false, toggle = function() end }
	control.toggle = function()
		control.auto = not control.auto and affordable(counts[1])
		if s.isOpen() and not Reveal.busy() then
			s.open()
		end
	end
	local openedAt = 0
	local dim = s.canvas.Parent :: GuiObject
	s.connect(dim:GetPropertyChangedSignal("Visible"), function()
		openedAt = os.clock()
		if not dim.Visible then
			control.auto = false
		end
	end)
	-- STOP, over the reveals (bottom left, as the reference's)
	local stopLayer = Instance.new("ScreenGui")
	stopLayer.Name = "AutoHatch"
	stopLayer.IgnoreGuiInset = true
	stopLayer.ResetOnSpawn = false
	stopLayer.DisplayOrder = 190
	stopLayer.Enabled = false
	stopLayer.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local stopCanvas = Kit.canvas(stopLayer)
	local words = Kit.label(stopCanvas, "AUTO", Kit.white)
	Kit.put(words, 24, 788, 320, 48)
	local stop = Kit.button(stopCanvas, "STOP", Color3.fromRGB(230, 60, 50), function()
		control.auto = false
		if s.isOpen() and not Reveal.busy() then
			s.open()
		end
	end)
	Kit.put(stop, 64, 844, 220, 172)
	s.gui.Destroying:Once(function()
		stopLayer:Destroy()
	end)
	s.connect(UserInputService.InputBegan, function(input, processed)
		if
			processed
			or not s.isOpen()
			or not active()
			or os.clock() - openedAt < 0.3
			or Reveal.busy()
		then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			press(counts[1])
		elseif input.KeyCode == Enum.KeyCode.R then
			press(counts[#counts])
		elseif input.KeyCode == Enum.KeyCode.T then
			control.toggle()
		end
	end)
	local wasBusy = false
	s.connect(RunService.RenderStepped, function()
		local busy = Reveal.busy()
		-- the reveal plays over the backdrop itself, the stand out of the way
		s.canvas.Visible = not busy
		stopLayer.Enabled = control.auto and s.isOpen()
		if control.auto and s.isOpen() and active() and not busy then
			-- as many at once as the coins allow
			local count = if affordable(counts[#counts]) then counts[#counts] else counts[1]
			if affordable(count) then
				press(count)
			else
				control.auto = false
				s.open()
			end
		elseif wasBusy and not busy and s.isOpen() then
			s.open()
		end
		wasBusy = busy
	end)
	return control
end

return HatchStand
