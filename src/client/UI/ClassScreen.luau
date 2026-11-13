--!strict
--[[ Class select: pick a class on its card, BOY or GIRL, then CHOOSE; and
     the game's loading cover, which the area loading screen shares. ]]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Chunky = require(script.Parent.Chunky)
local ClassSelect = require(ReplicatedStorage.Shared.Config.ClassSelect)
local ClassStats = require(ReplicatedStorage.Shared.Util.ClassStats)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Kit = require(script.Parent.Kit)
local LoadingPick = require(ReplicatedStorage.Shared.Util.LoadingPick)
local LoadingScreen = require(ReplicatedStorage.Shared.Config.LoadingScreen)
local LoadingTips = require(ReplicatedStorage.Shared.Config.LoadingTips)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local SpotlightArt = require(ReplicatedStorage.Shared.Util.SpotlightArt)
local TipPlate = require(ReplicatedStorage.Shared.Util.TipPlate)
local ClassScreen = {}
local started = false
--[[ Seconds the loading screen stays up after CHOOSE. ]]
local LOAD_SECONDS = 1.8

--[[ The game's loading screen over everything in `parent`: one of Codex's
     spotlights, a tip, and a bar filling over `LOAD_SECONDS`. ]]
function ClassScreen.loadingCover(parent: Instance, seconds: number?): Frame
	local cover = Instance.new("Frame")
	cover.Name = "Loading"
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.ZIndex = 50
	cover.Parent = parent
	local screen = Instance.new("Frame")
	screen.BackgroundTransparency = 1
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Size = UDim2.fromScale(1, 1)
	screen.ZIndex = 50
	screen.Parent = cover
	--[[
		One of Codex's spotlights, drawn from the same four the join
		screen uses (owner, 2026-11-01: "the old loading screens need to
		be removed from the game").

		This was the last place the old shared art appeared: it drew that
		backdrop with the chosen class's weapon composed over it -- a
		picture, a line and a name plaque. A spotlight is a finished
		picture instead, so only the tip and the bar go over it, exactly
		as on the join screen.
	]]
	local spotlit: { string } = {}
	for _, entry in LoadingPick.pool(nil) do
		if LoadingScreen.spotlights[entry.name] then
			table.insert(spotlit, entry.name)
		end
	end
	--[[ Upright on a phone held portrait (owner, 2026-11-05: "make new
	     loading screens for mobile"). ]]
	local camera = Workspace.CurrentCamera
	local layout, art = LoadingScreen.pick(
		if camera then camera.ViewportSize else Vector2.new(16, 9),
		if #spotlit > 0 then spotlit[math.random(1, #spotlit)] else ""
	)
	local size = layout.size
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = size.X / size.Y
	aspect.Parent = screen
	local function place(object: GuiObject, box: LoadingScreen.Box)
		object.Position = UDim2.fromScale(box.x / size.X, box.y / size.Y)
		object.Size = UDim2.fromScale(box.w / size.X, box.h / size.Y)
		object.ZIndex = 51
		object.Parent = screen
	end
	if art then
		SpotlightArt.draw(screen, art, 50, size, LoadingScreen.tileOverlap, layout.columns)
	end
	-- the tip, on its plate rather than on the picture (`Util/TipPlate`)
	TipPlate.draw(screen, size, layout.tip, LoadingTips[math.random(1, #LoadingTips)], 51)
	local trough = Instance.new("Frame")
	trough.BackgroundTransparency = 1
	place(trough, layout.bar)
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = LoadingScreen.barFill
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(0, 1)
	bar.ZIndex = 52
	bar.Parent = trough
	TweenService
		:Create(bar, TweenInfo.new((seconds or LOAD_SECONDS) - 0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(1, 1),
		})
		:Play()
	return cover
end

--[[ A picture that is drawn art rather than pixel art: smoothed when scaled. ]]
local function picture(parent: Instance, asset: string, z: number): ImageLabel
	local image = Kit.image(parent, asset)
	image.ResampleMode = Enum.ResamplerMode.Default
	image.ZIndex = z
	return image
end

local function square(item: GuiObject)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = item
end

local function circle(item: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = item
end

local function lines(words: string): number
	local _, breaks = string.gsub(words, "\n", "")
	return breaks + 1
end

--[[
	The screen itself, the owner's "option B" (2026-11-13; the mock-ups are
	`assets/concepts/blocky/ui/class_select_b/`, `Config/ClassSelect`): the
	CHOOSE YOUR CLASS plate over a mint panel, and on it four cards in a row,
	each a round medallion in the class's colour holding its hero's
	head-and-shoulders portrait (Codex's), the class's name on a tag of that
	colour, what it plays like, and three bars with icons, RANGE, POWER and
	SPEED, read off `Config/Classes` (`Util/ClassStats`). The picked card
	wears a thick yellow ring; a green CHOOSE sits under the row. A BOY / GIRL
	switch at the panel's top right swaps every portrait between the male and
	female heroes: pictures only, as every player wears their own avatar in
	game (PR #572). The look is saved with the class (`Data/Shop.chooseClass`,
	`SaveSchema` `look`). The Assassin is not playable yet: its card shows a
	blacked-out figure with a violet rim and a padlock, and empty bars, and
	shakes its head when tapped.

	A phone held upright gets the cards two by two on the kit's upright
	sheet; the screen is laid out again when it turns.
]]
function ClassScreen.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClassScreen"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local connections: { RBXScriptConnection } = {}
	local tweens: { [Instance]: Tween } = {}
	local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
		table.insert(connections, signal:Connect(callback))
	end
	local function tween(object: Instance, duration: number, properties: { [string]: any })
		if tweens[object] then
			tweens[object]:Cancel()
		end
		local motion = TweenService:Create(
			object,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			properties
		)
		tweens[object] = motion
		motion:Play()
	end
	--[[ The mock-up's pale mint round the panel, edge to edge. ]]
	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Chunky.pale
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Active = true
	dim.Parent = gui
	local canvas = Kit.canvas(dim)

	local cardList = ClassSelect.cards
	local selected = 1
	for index, card in cardList do
		if not card.locked then
			selected = index
			break
		end
	end
	local look = SaveSchema.LOOKS[1]
	local closing = false
	local shown = false
	local hasProfile = false
	local hasLook = false
	local cards: { { holder: Frame, ring: Frame, scale: UIScale, portrait: ImageLabel } } = {}
	local halves: { { face: Frame, ring: UIStroke, look: string } } = {}

	local function choose()
		local card = cardList[selected]
		if not card or card.locked or closing then
			return
		end
		closing = true
		Remotes.event(Remotes.ChooseClass):FireServer(card.class, look)
		SoundFx.play("class_choose")
		local flash = Instance.new("Frame")
		flash.BorderSizePixel = 0
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 60
		flash.Parent = dim
		tween(flash, 0.3, { BackgroundTransparency = 1 })
		--[[ Then into the lobby (owner, 2026-10-27: "then it should load
		     the player into the lobby"): the game's loading screen while the
		     server puts the player at the lobby's spawn, then a fade. ]]
		task.delay(0.15, function()
			if not gui.Parent then
				return
			end
			local cover = ClassScreen.loadingCover(dim)
			task.delay(LOAD_SECONDS, function()
				if not gui.Parent then
					return
				end
				for _, d in cover:GetDescendants() do
					if d:IsA("ImageLabel") then
						tween(d, 0.4, { ImageTransparency = 1 })
					elseif d:IsA("TextLabel") then
						tween(d, 0.4, { TextTransparency = 1 })
					elseif d:IsA("Frame") then
						tween(d, 0.4, { BackgroundTransparency = 1 })
					elseif d:IsA("UIStroke") then
						tween(d, 0.4, { Transparency = 1 })
					end
				end
				tween(cover, 0.4, { BackgroundTransparency = 1 })
				for _, d in dim:GetChildren() do
					if d ~= cover and d:IsA("GuiObject") then
						d.Visible = false
					end
				end
				tween(dim, 0.4, { BackgroundTransparency = 1 })
				task.delay(0.45, function()
					if gui.Parent then
						gui:Destroy()
					end
				end)
			end)
		end)
	end

	--[[ The picked card stands a touch forward in its yellow ring. ]]
	local function paint()
		for i, card in cards do
			local on = selected == i
			card.ring.Visible = on
			tween(card.scale, 0.18, { Scale = if on then 1.02 else 1 })
		end
	end

	--[[ Every portrait in the chosen look, and the switch's half lit. ]]
	local function paintLook()
		for i, card in cards do
			card.portrait.Image = cardList[i].portraits[look] or ""
		end
		for _, half in halves do
			local on = half.look == look
			half.face.BackgroundColor3 = if on then Chunky.gold else Chunky.panelBottom
			half.ring.Enabled = on
		end
	end

	local function pick(index: number)
		if closing then
			return
		end
		local card = cardList[index]
		if card.locked then
			-- a locked card shakes its head
			local holder = cards[index] and cards[index].holder
			if holder then
				holder.Rotation = 3
				tween(holder, 0.25, { Rotation = 0 })
			end
			return
		end
		if selected ~= index then
			selected = index
			SoundFx.play("class_select")
			paint()
		end
	end

	local function setLook(chosen: string)
		if closing or chosen == look then
			return
		end
		look = chosen
		paintLook()
	end

	--[[ One class's card at (`x`, `y`), `w` by `h` sheet pixels, laid out as
	     the mock-up's: everything placed as a share of the card, the
	     medallion as round as the card's width and height allow. ]]
	local function drawCard(
		sheet: Chunky.Sheet,
		index: number,
		x: number,
		y: number,
		w: number,
		h: number
	)
		local card = cardList[index]
		local tone = card.colour
		local holder = Instance.new("Frame")
		holder.Name = card.class
		holder.BackgroundTransparency = 1
		holder.ZIndex = 5
		Chunky.put(sheet, holder, x, y, w, h)
		local tile = Instance.new("Frame")
		tile.Name = "Tile"
		tile.BorderSizePixel = 0
		tile.BackgroundColor3 = Color3.new(1, 1, 1)
		--[[ Anchored at its middle: a UIScale grows a frame from its anchor,
		     and the picked card swelled from its top-left corner over its
		     neighbour (docs/FIXES.md). ]]
		tile.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.Position = UDim2.fromScale(0.5, 0.5)
		tile.Size = UDim2.fromScale(1, 1)
		tile.ZIndex = 5
		tile.Parent = holder
		local scale = Instance.new("UIScale")
		scale.Parent = tile
		local light = Instance.new("UIGradient")
		light.Rotation = 90
		light.Color = ColorSequence.new(Chunky.white, Chunky.white:Lerp(Chunky.panelBottom, 0.4))
		light.Parent = tile
		Chunky.round(tile, 22)
		Chunky.outline(tile, 5)
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.BackgroundTransparency = 1
		ring.Size = UDim2.fromScale(1, 1)
		ring.ZIndex = 50
		ring.Visible = false
		ring.Parent = tile
		Chunky.round(ring, 22)
		Chunky.outline(ring, 10, Chunky.gold)

		--[[ The medallion and the hero in it. The portrait is the
		     medallion's square with `portraitTop` more above it. ]]
		local d = math.min(w * 0.86, h * 0.553)
		local medallion = Instance.new("Frame")
		medallion.Name = "Medallion"
		medallion.BorderSizePixel = 0
		medallion.BackgroundColor3 = tone
		medallion.Position = UDim2.fromScale((w - d) / 2 / w, 0.025)
		medallion.Size = UDim2.fromScale(d / w, d / h)
		medallion.ZIndex = 6
		medallion.Parent = tile
		circle(medallion)
		Chunky.outline(medallion, 6, Chunky.shade(tone))
		local glow = picture(medallion, GearAssets.fx.glow, 7)
		glow.Name = "Glow"
		glow.ScaleType = Enum.ScaleType.Stretch
		glow.ImageColor3 = tone:Lerp(Chunky.white, 0.55)
		glow.ImageTransparency = 0.2
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position, glow.Size = UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.95, 0.95)
		local top = ClassSelect.portraitTop
		local portrait = picture(medallion, card.portraits[look] or "", 8)
		portrait.Name = "Portrait"
		portrait.ScaleType = Enum.ScaleType.Stretch
		portrait.Position, portrait.Size = UDim2.fromScale(0, -top), UDim2.fromScale(1, 1 + top)
		if card.locked then
			local lock = picture(medallion, ClassSelect.lock, 9)
			lock.Name = "Lock"
			lock.AnchorPoint = Vector2.new(0.5, 0.5)
			lock.Position, lock.Size = UDim2.fromScale(0.5, 0.72), UDim2.fromScale(0.3, 0.3)
			square(lock)
		end

		--[[ The name on a tag of the class's colour, over the medallion's foot. ]]
		local tag = Instance.new("Frame")
		tag.Name = "Tag"
		tag.BorderSizePixel = 0
		tag.Position, tag.Size = UDim2.fromScale(0.056, 0.534), UDim2.fromScale(0.888, 0.093)
		tag.ZIndex = 10
		tag.Parent = tile
		Chunky.light(tag, tone)
		Chunky.round(tag, h * 0.05)
		Chunky.outline(tag, 5, Chunky.shade(tone))
		local name = Chunky.textOn(tag, string.upper(card.class), tone, 5)
		name.Position, name.Size = UDim2.fromScale(0.06, 0.12), UDim2.fromScale(0.88, 0.76)
		name.ZIndex = 11

		--[[ What it plays like: every line the same height on every card. ]]
		local tall = 0.052 * lines(card.pitch)
		local pitch = Chunky.text(tile, card.pitch, Chunky.ink, 0)
		pitch.Name = "Pitch"
		pitch.Position, pitch.Size =
			UDim2.fromScale(0.05, 0.69 - tall / 2), UDim2.fromScale(0.9, tall)
		pitch.ZIndex = 10

		--[[ The three bars, each on its own white row: what `Config/Classes`
		     says, or an empty trough for a class not here yet. ]]
		local bars = ClassStats.bars(card.class) :: any
		for n, stat in ClassSelect.stats do
			local row = Instance.new("Frame")
			row.Name = stat.words
			row.BorderSizePixel = 0
			row.BackgroundColor3 = Chunky.white
			row.Position = UDim2.fromScale(0.037, 0.752 + (n - 1) * 0.077)
			row.Size = UDim2.fromScale(0.926, 0.066)
			row.ZIndex = 10
			row.Parent = tile
			Chunky.round(row, h * 0.033)
			Chunky.outline(row, 4)
			local icon = picture(row, stat.icon, 11)
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position, icon.Size = UDim2.fromScale(0.02, 0.5), UDim2.fromScale(0.12, 0.86)
			square(icon)
			local label = Chunky.text(row, stat.words, Chunky.ink, 0)
			label.Position, label.Size = UDim2.fromScale(0.15, 0.19), UDim2.fromScale(0.26, 0.62)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.ZIndex = 11
			local trough = Instance.new("Frame")
			trough.Name = "Trough"
			trough.BorderSizePixel = 0
			trough.BackgroundColor3 = Chunky.trough
			trough.Position, trough.Size = UDim2.fromScale(0.43, 0.2), UDim2.fromScale(0.545, 0.6)
			trough.ZIndex = 11
			trough.Parent = row
			circle(trough)
			local share = if card.locked then 0 else (bars[stat.key] or 0) :: number
			if share > 0 then
				local fill = Instance.new("Frame")
				fill.Name = "Fill"
				fill.BorderSizePixel = 0
				fill.BackgroundColor3 = Color3.new(1, 1, 1)
				fill.Size = UDim2.fromScale(math.clamp(share, 0.08, 1), 1)
				fill.ZIndex = 12
				fill.Parent = trough
				circle(fill)
				local shine = Instance.new("UIGradient")
				shine.Rotation = 90
				shine.Color = ColorSequence.new(Chunky.lime:Lerp(Chunky.white, 0.3), Chunky.lime)
				shine.Parent = fill
			end
		end

		cards[index] = { holder = holder, ring = ring, scale = scale, portrait = portrait }
		Chunky.press(holder, function()
			pick(index)
		end)
	end

	--[[ The BOY / GIRL pill: the chosen half sunny with a dark ring, the
	     other mint, each with its little face. ]]
	local function drawSwitch(sheet: Chunky.Sheet, x: number, y: number, w: number, h: number)
		local holder = Instance.new("Frame")
		holder.Name = "LookSwitch"
		holder.BorderSizePixel = 0
		holder.BackgroundColor3 = Chunky.panelBottom
		holder.ZIndex = 20
		Chunky.put(sheet, holder, x, y, w, h)
		circle(holder)
		Chunky.outline(holder, 6)
		table.clear(halves)
		local count = #ClassSelect.looks
		for n, entry in ClassSelect.looks do
			local half = Instance.new("Frame")
			half.Name = entry.words
			half.BorderSizePixel = 0
			half.BackgroundColor3 = Chunky.panelBottom
			half.Position = UDim2.fromScale((n - 1) / count + 0.012, 0.1)
			half.Size = UDim2.fromScale(1 / count - 0.024, 0.8)
			half.ZIndex = 21
			half.Parent = holder
			circle(half)
			local ring = Chunky.outline(half, 4)
			local face = picture(half, entry.icon, 22)
			face.AnchorPoint = Vector2.new(0, 0.5)
			face.Position, face.Size = UDim2.fromScale(0.1, 0.5), UDim2.fromScale(0.26, 0.86)
			square(face)
			local words = Chunky.text(half, entry.words, Chunky.ink, 0)
			words.Position, words.Size = UDim2.fromScale(0.4, 0.2), UDim2.fromScale(0.5, 0.6)
			words.ZIndex = 22
			table.insert(halves, { face = half, ring = ring, look = entry.look })
			Chunky.press(half, function()
				setLook(entry.look)
			end)
		end
	end

	--[[ Lays the whole screen out for the screen's shape now: the plate,
	     then the panel under it (so the plate stands on its own, as the
	     mock-up's does). ]]
	local function draw()
		canvas:ClearAllChildren()
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectType = Enum.AspectType.FitWithinMaxSize
		aspect.Parent = canvas
		table.clear(cards)
		local sheet = Chunky.sheet(canvas)
		local count = #cardList
		if sheet.upright then
			Chunky.ribbon(sheet, "CHOOSE YOUR CLASS", 40, 50, 1000, 130)
			local px, py, pw, ph = 30, 205, 1020, 1675
			Chunky.panel(sheet, px, py, pw, ph)
			drawSwitch(sheet, px + pw - 470, py + 18, 440, 78)
			local w, h, gap = 459, 690, 30
			local left = px + (pw - 2 * w - gap) / 2
			for index = 1, count do
				local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
				drawCard(sheet, index, left + column * (w + gap), py + 122 + row * (h + gap), w, h)
			end
			Chunky.button(
				sheet,
				"CHOOSE",
				Chunky.green,
				px + pw / 2 - 300,
				py + ph - 140,
				600,
				112,
				choose
			)
		else
			Chunky.ribbon(sheet, "CHOOSE YOUR CLASS", 32, 20, 1856, 118)
			local px, py, pw, ph = 30, 158, 1860, 900
			Chunky.panel(sheet, px, py, pw, ph)
			drawSwitch(sheet, 1340, py + 8, 530, 70)
			local gap = 20
			local w = (pw - 60 - (count - 1) * gap) / count
			for index = 1, count do
				drawCard(sheet, index, px + 30 + (index - 1) * (w + gap), 254, w, 668)
			end
			Chunky.button(sheet, "CHOOSE", Chunky.green, 657, 940, 606, 104, choose)
		end
		paint()
		paintLook()
	end

	local function maybeOpen()
		if
			not shown
			and hasProfile
			and not hasLook
			and not RunPaused.beforeArrival()
			and Workspace:GetAttribute("InLobby") == true
		then
			shown = true
			player:SetAttribute("ClassSelecting", true)
			player:SetAttribute("InStation", true)
			draw()
			gui.Enabled = true
			Chunky.pop(canvas)
		end
	end
	--[[ Every portrait and icon fetched before the screen is needed, so the
	     switch swaps them at once. ]]
	task.spawn(function()
		local assets: { string } = { ClassSelect.lock, GearAssets.fx.glow }
		for _, card in cardList do
			for _, asset in card.portraits do
				table.insert(assets, asset)
			end
		end
		for _, entry in ClassSelect.looks do
			table.insert(assets, entry.icon)
		end
		for _, stat in ClassSelect.stats do
			table.insert(assets, stat.icon)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, assets)
	end)
	--[[ Laid out again when the screen changes shape, as when a phone
	     turns. ]]
	local wasUpright: boolean? = nil
	connect(dim:GetPropertyChangedSignal("AbsoluteSize"), function()
		local upright = dim.AbsoluteSize.Y > dim.AbsoluteSize.X
		if shown and not closing and upright ~= wasUpright then
			wasUpright = upright
			draw()
		end
	end)
	connect(Remotes.event(Remotes.ProfileChanged).OnClientEvent, function(profile)
		if type(profile) ~= "table" then
			return
		end
		hasProfile = true
		hasLook = profile.look ~= nil
		if not shown and table.find(SaveSchema.LOOKS, profile.look) then
			look = profile.look
		end
		maybeOpen()
	end)
	connect(Workspace:GetAttributeChangedSignal("InLobby"), maybeOpen)
	--[[ The story's end asks the server for the tutorial, and the lobby stays
	     `InLobby` until the answer arrives. Asking again a moment later keeps
	     this screen from flashing up before a tutorial starts; after the
	     tutorial, `InLobby` itself opens it. ]]
	table.insert(
		connections,
		RunPaused.onChanged(function()
			if not RunPaused.beforeArrival() then
				task.delay(2, maybeOpen)
			end
		end)
	)
	gui.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, motion in tweens do
			motion:Cancel()
		end
		if shown then
			player:SetAttribute("ClassSelecting", false)
			player:SetAttribute("InStation", false)
		end
	end)
	task.spawn(function()
		for _ = 1, 20 do
			if hasProfile or not gui.Parent then
				return
			end
			Remotes.event(Remotes.ProfileRequest):FireServer()
			task.wait(1)
		end
	end)
end
return ClassScreen
