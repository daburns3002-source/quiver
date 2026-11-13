--!strict
--[[ Class select: pick a class on its card, then CHOOSE; and the game's
     loading cover, which the area loading screen shares. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Chunky = require(script.Parent.Chunky)
local ClassCards = require(ReplicatedStorage.Shared.Config.ClassSelect)
local ClassStats = require(ReplicatedStorage.Shared.Util.ClassStats)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local GearScreen = require(script.Parent.GearScreen)
local Kit = require(script.Parent.Kit)
local LoadingPick = require(ReplicatedStorage.Shared.Util.LoadingPick)
local LoadingScreen = require(ReplicatedStorage.Shared.Config.LoadingScreen)
local LoadingTips = require(ReplicatedStorage.Shared.Config.LoadingTips)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
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

--[[
	The screen itself (owner, 2026-11-11: "the change class screen needs to
	be fixed. it looks too ai right now", and the major UI reference of the
	same day). It was four slanted panels of painted class art; now it is a
	chunky panel (`UI/Chunky`) over the lobby with a card for each class
	(`Config/ClassSelect`), and on every card the player's own character, as
	it stands in the game, holding that class's weapon (`GearScreen.portrait`;
	the class bodies were taken out on 2026-11-07 and the class armour sets on
	2026-11-13, owner: "scrap the models on the player entirely", so the
	character is the player's avatar). Under it the class's name, what it plays like, and
	three bars read off `Config/Classes` (`Util/ClassStats`), so the card
	says what the numbers say. Tap a card, then CHOOSE.

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
	--[[ The lobby shows through, dimmed: the game itself is the backdrop. ]]
	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Active = true
	dim.Parent = gui
	local canvas = Kit.canvas(dim)

	local selected: number? = nil
	local closing = false
	local shown = false
	local hasProfile = false
	local hasLook = false
	local chooseButton: Frame? = nil
	local cards: { { holder: Frame, shade: Frame, ring: UIStroke, scale: UIScale } } = {}

	local function choose()
		local index = selected
		local card = if index then ClassCards[index] else nil
		if not card or card.locked or closing then
			return
		end
		closing = true
		--[[ The look is only saved (`Data/Shop.chooseClass`): every player
		     wears their own avatar. ]]
		Remotes.event(Remotes.ChooseClass):FireServer(card.class, SaveSchema.LOOKS[1])
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

	--[[ The picked card stands forward with a gold ring; the rest step back. ]]
	local function paint()
		for i, card in cards do
			local on = selected == i
			card.ring.Enabled = on
			card.shade.BackgroundTransparency = if selected and not on then 0.5 else 1
			tween(card.scale, 0.18, { Scale = if on then 1.05 else 1 })
		end
		local button = chooseButton
		local picked = if selected then ClassCards[selected] else nil
		if button then
			Chunky.repaint(
				button,
				if picked then Chunky.gold else Chunky.grey,
				if picked then `PLAY AS {string.upper(picked.class)}` else "TAP A CLASS"
			)
		end
	end

	local function pick(index: number)
		if closing then
			return
		end
		local card = ClassCards[index]
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

	--[[ One class's card at (`x`, `y`), `w` by `h` sheet pixels. ]]
	local function drawCard(
		sheet: Chunky.Sheet,
		index: number,
		x: number,
		y: number,
		w: number,
		h: number
	)
		local card = ClassCards[index]
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
		tile.Size = UDim2.fromScale(1, 1)
		tile.ZIndex = 5
		tile.Parent = holder
		local scale = Instance.new("UIScale")
		scale.Parent = tile
		local light = Instance.new("UIGradient")
		light.Rotation = 90
		--[[ Lit pale behind the character, deepening under the name and the
		     pitch to a shade small white words stand 4.5:1 on. ]]
		local deep = Chunky.deep(tone)
		light.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, tone:Lerp(Color3.new(1, 1, 1), 0.45)),
			ColorSequenceKeypoint.new(0.42, tone),
			ColorSequenceKeypoint.new(0.57, deep),
			ColorSequenceKeypoint.new(1, deep),
		})
		light.Parent = tile
		Chunky.round(tile, 22)
		Chunky.outline(tile, 7, Chunky.shade(tone))
		local ring = Chunky.outline(holder, 12, Chunky.gold)
		ring.Enabled = false
		Chunky.round(holder, 22)

		--[[ The player's own character, holding this class's weapon. ]]
		local stage = Instance.new("Frame")
		stage.Name = "Stage"
		stage.BackgroundTransparency = 1
		stage.Position = UDim2.fromScale(0.04, 0.02)
		stage.Size = UDim2.fromScale(0.92, 0.56)
		stage.ZIndex = 6
		stage.Parent = tile
		if card.locked then
			local lock = Kit.image(stage, ShopAssets.lock)
			lock.AnchorPoint = Vector2.new(0.5, 0.5)
			lock.Position = UDim2.fromScale(0.5, 0.55)
			lock.Size = UDim2.fromScale(0.5, 0.5)
			lock.ZIndex = 7
			local square = Instance.new("UIAspectRatioConstraint")
			square.Parent = lock
		else
			GearScreen.portrait(stage, Classes[card.class].weapon)
		end

		local name = Chunky.text(tile, string.upper(card.class), nil, 6, Chunky.shade(tone))
		name.Position, name.Size = UDim2.fromScale(0.06, 0.585), UDim2.fromScale(0.88, 0.11)
		local pitch = Chunky.text(tile, card.pitch, nil, 4, Chunky.shade(tone))
		pitch.Position, pitch.Size = UDim2.fromScale(0.06, 0.7), UDim2.fromScale(0.88, 0.055)

		--[[ The three bars, on a pale plate: what `Config/Classes` says. ]]
		local plate = Instance.new("Frame")
		plate.Name = "Stats"
		plate.BorderSizePixel = 0
		plate.BackgroundColor3 = Chunky.panelTop
		plate.Position, plate.Size = UDim2.fromScale(0.06, 0.775), UDim2.fromScale(0.88, 0.2)
		plate.ZIndex = 6
		plate.Parent = tile
		Chunky.round(plate, 14)
		Chunky.outline(plate, 4, Chunky.shade(tone))
		if card.locked then
			local soon = Chunky.text(plate, "LOCKED", Chunky.ink, 0)
			soon.Position, soon.Size = UDim2.fromScale(0.1, 0.25), UDim2.fromScale(0.8, 0.5)
		else
			local bars = ClassStats.bars(card.class)
			local rows: { { name: string, share: number, colour: Color3 } } = {
				{ name = "DAMAGE", share = bars.damage, colour = Chunky.red },
				{ name = "SPEED", share = bars.speed, colour = Chunky.blue },
				{ name = "HEALTH", share = bars.health, colour = Chunky.green },
			}
			for n, row in rows do
				local top = 0.08 + (n - 1) * 0.3
				local label = Chunky.text(plate, row.name, Chunky.ink, 0)
				label.Position, label.Size = UDim2.fromScale(0.05, top), UDim2.fromScale(0.36, 0.25)
				label.TextXAlignment = Enum.TextXAlignment.Left
				local trough = Instance.new("Frame")
				trough.BorderSizePixel = 0
				trough.BackgroundColor3 = Chunky.trough
				trough.Position, trough.Size =
					UDim2.fromScale(0.43, top + 0.03), UDim2.fromScale(0.52, 0.19)
				trough.ZIndex = 7
				trough.Parent = plate
				Chunky.round(trough, 8)
				local fill = Instance.new("Frame")
				fill.BorderSizePixel = 0
				fill.BackgroundColor3 = Chunky.lit(row.colour)
				fill.Size = UDim2.fromScale(math.clamp(row.share, 0.06, 1), 1)
				fill.ZIndex = 8
				fill.Parent = trough
				Chunky.round(fill, 8)
			end
		end

		local shade = Instance.new("Frame")
		shade.Name = "Shade"
		shade.BorderSizePixel = 0
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 1
		shade.Size = UDim2.fromScale(1, 1)
		shade.ZIndex = 20
		shade.Parent = tile
		Chunky.round(shade, 22)

		cards[index] = { holder = holder, shade = shade, ring = ring, scale = scale }
		Chunky.press(holder, function()
			pick(index)
		end)
	end

	--[[ Lays the whole screen out for the screen's shape now. ]]
	local function draw()
		canvas:ClearAllChildren()
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectType = Enum.AspectType.FitWithinMaxSize
		aspect.Parent = canvas
		table.clear(cards)
		chooseButton = nil
		local sheet = Chunky.sheet(canvas)
		local count = #ClassCards
		if sheet.upright then
			local px, py, pw, ph = 40, 150, 1000, 1640
			Chunky.panel(sheet, px, py, pw, ph)
			Chunky.ribbon(sheet, "CHOOSE YOUR CLASS", px, py, pw, 120)
			local w, h, gap = 450, 640, 30
			local left = px + (pw - 2 * w - gap) / 2
			for index = 1, count do
				local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
				drawCard(sheet, index, left + column * (w + gap), py + 150 + row * (h + gap), w, h)
			end
			chooseButton = Chunky.button(
				sheet,
				"TAP A CLASS",
				Chunky.grey,
				px + 120,
				py + ph - 170,
				pw - 240,
				130,
				choose
			)
		else
			local px, py, pw, ph = 130, 70, 1660, 950
			Chunky.panel(sheet, px, py, pw, ph)
			Chunky.ribbon(sheet, "CHOOSE YOUR CLASS", px, py, pw, 110)
			local gap = 30
			local w = (pw - 80 - (count - 1) * gap) / count
			local h = 610
			for index = 1, count do
				drawCard(sheet, index, px + 40 + (index - 1) * (w + gap), py + 140, w, h)
			end
			chooseButton = Chunky.button(
				sheet,
				"TAP A CLASS",
				Chunky.grey,
				px + pw / 2 - 330,
				py + ph - 170,
				660,
				130,
				choose
			)
		end
		paint()
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
	--[[ Laid out again when the screen changes shape, as when a phone
	     turns, or when the character it draws arrives. ]]
	local wasUpright: boolean? = nil
	connect(dim:GetPropertyChangedSignal("AbsoluteSize"), function()
		local upright = dim.AbsoluteSize.Y > dim.AbsoluteSize.X
		if shown and not closing and upright ~= wasUpright then
			wasUpright = upright
			draw()
		end
	end)
	connect(player.CharacterAdded, function()
		task.delay(1, function()
			if shown and not closing and gui.Parent then
				draw()
			end
		end)
	end)
	connect(Remotes.event(Remotes.ProfileChanged).OnClientEvent, function(profile)
		if type(profile) ~= "table" then
			return
		end
		hasProfile = true
		hasLook = profile.look ~= nil
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
