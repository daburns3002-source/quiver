--!strict
--[[
	The lobby's PLAY screen, its first step: choose the area (owner,
	2026-11-14: "when the player clicks play it shouldnt just tp them
	instantly to the last portal they went to, there should be a screen
	where they can choose the area and then the level").

	PLAY (`UI/LobbyHud`) opens this list of every area with a portal
	(`Util/PlayPortal.areas`: the built areas in the arches' order, then
	Endless), one card each: the area's own portal turning in its window,
	its name and act, how many of its levels are beaten, and PLAY. The area
	to play next (`PlayPortal.pick`: the first with a level not beaten) is
	ringed in gold under a NEXT UP tag and its PLAY is the sunny one. An
	area still locked is greyed under a padlock and says what opens it
	("BEAT 1-10"); pressing it only shakes it.

	Pressing an open area goes on to that area's level screen
	(`UI/PortalScreen`, the same one its portal opens), which carries a
	`< AREAS` button back here and whose PLAY asks the server for the run.
	Nothing is asked of the server before that, and the character stays
	where it stands: the server checks the area and the level when the run
	is asked for (`Run/Lobby.levelOpen`). X, Escape or B closes the list;
	Return goes on into the ringed area.

	Redrawn whole by `fill` when the profile changes or the phone turns, on
	a 1920 x 1080 sheet (the cards in a row) or 1080 x 1920 upright (the
	cards in a column).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossBanners = require(ReplicatedStorage.Shared.Config.BossBanners)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local PlayPortal = require(ReplicatedStorage.Shared.Util.PlayPortal)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)

local Chunky = require(script.Parent.Chunky)
local FirstTips = require(script.Parent.FirstTips)
local Kit = require(script.Parent.Kit)
local PortalScreen = require(script.Parent.PortalScreen)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local StationScreen = require(script.Parent.StationScreen)

local AreaScreen = {}

local gui: ScreenGui? = nil
local canvas: Frame? = nil
local profile: SaveSchema.Profile? = nil
--[[ The ringed area's button, for a gamepad to land on. ]]
local nextButton: TextButton? = nil

--[[ Where the panel's pieces sit, in sheet pixels. `cards` is the box the
     area cards share, `most` how many stand side by side before a second
     line starts. Then one card's pieces, each a share of the card: its
     portal window, name, act, progress words and bar, and button. ]]
type Layout = {
	panel: { number },
	ribbon: { number },
	close: { number },
	--[[ CONTINUE, over the cards: the next level in one press. ]]
	continue: { number },
	cards: { number },
	most: number,
	gap: number,
	art: { number },
	name: { number },
	act: { number },
	progress: { number },
	bar: { number },
	button: { number },
}

local WIDE: Layout = {
	panel = { 150, 104, 1620, 940 },
	ribbon = { 520, 22, 880, 150 },
	close = { 1688, 66, 108 },
	continue = { 610, 190, 700, 112 },
	cards = { 184, 318, 1552, 698 },
	most = 5,
	gap = 20,
	art = { 0.07, 0.025, 0.86, 0.4 },
	name = { 0.06, 0.44, 0.88, 0.13 },
	act = { 0.08, 0.585, 0.84, 0.07 },
	progress = { 0.08, 0.675, 0.84, 0.055 },
	bar = { 0.1, 0.742, 0.8, 0.04 },
	button = { 0.08, 0.815, 0.84, 0.16 },
}

local TALL: Layout = {
	panel = { 30, 196, 1020, 1694 },
	ribbon = { 120, 116, 840, 150 },
	close = { 956, 150, 110 },
	continue = { 140, 290, 800, 124 },
	cards = { 60, 430, 960, 1436 },
	most = 1,
	gap = 20,
	art = { 0.02, 0.06, 0.25, 0.88 },
	name = { 0.3, 0.07, 0.42, 0.3 },
	act = { 0.3, 0.4, 0.4, 0.17 },
	progress = { 0.3, 0.62, 0.42, 0.14 },
	bar = { 0.3, 0.79, 0.4, 0.1 },
	button = { 0.74, 0.24, 0.24, 0.52 },
}

--[[ The boss banner (`Config/BossBanners`) of the area named `area`, for
     its act. ]]
local function bannerFor(area: string): BossBanners.Banner?
	for _, banner in BossBanners.bosses do
		if banner.area == area then
			return banner
		end
	end
	return nil
end

--[[ What the list shows now, from the profile. ]]
local function areas(): { PlayPortal.Area }
	local p = profile
	return PlayPortal.areas(
		LobbyConfig.portals,
		Balance.Stages,
		if p then p.levelsBeaten else nil,
		if p then p.bossesBeaten else nil,
		Balance.endlessStage
	)
end

local function close()
	local screen = gui
	if screen then
		screen.Enabled = false
	end
	if nextButton and GuiService.SelectedObject == nextButton then
		GuiService.SelectedObject = nil
	end
end

--[[ On into area `index`'s levels, if the list has it open. ]]
local function enter(index: number)
	if not PlayPortal.enter(areas(), index) then
		return
	end
	close()
	PortalScreen.open(index, AreaScreen.open)
end

--[[ CONTINUE: straight into the next level of the area next up, with no
     second screen (the run-through, 2026-11-14: "PLAY is three taps now, it
     was two"). The server checks the area and the level as for any start
     (`Run/Lobby.levelOpen`). ]]
local starting = false
local function continueOn()
	local p = profile
	local beaten = if p then p.levelsBeaten else nil
	local to = PlayPortal.next(areas(), LobbyConfig.portals, Balance.Stages, beaten)
	if not to or starting then
		return
	end
	starting = true
	task.delay(2, function()
		starting = false
	end)
	SoundFx.play("card_click")
	Remotes.event(Remotes.PortalStart):FireServer(to.index, to.level)
	close()
end

--[[ A locked card says no: a quick shake from side to side. ]]
local function shake(card: GuiObject)
	local home = card.Position
	local step = TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true)
	local tween = TweenService:Create(
		card,
		step,
		{ Position = home + UDim2.fromScale(card.Size.X.Scale * 0.03, 0) }
	)
	tween.Completed:Once(function()
		card.Position = home
	end)
	tween:Play()
end

--[[ A piece of a card `w` by `h` sheet pixels: `box` is its share of it. ]]
local function within(box: { number }, w: number, h: number): { number }
	return { box[1] * w, box[2] * h, box[3] * w, box[4] * h }
end

--[[ A pale pill with dark words (the act, what opens a locked area); in a
     `colour` of the kit's it takes that colour's own words. Returns the
     words, for a pill tall enough to wrap them. ]]
local function pill(sheet: Chunky.Sheet, words: string, box: { number }, colour: Color3?): TextLabel
	local p = Instance.new("Frame")
	p.Name = "Pill"
	p.BorderSizePixel = 0
	local ground = colour or Chunky.pale
	p.BackgroundColor3 = ground
	p.ZIndex = 6
	Chunky.put(sheet, p, box[1], box[2], box[3], box[4])
	Chunky.round(p, math.min(box[4], 60))
	local t = Chunky.textOn(p, words, ground, 4)
	t.Position, t.Size = UDim2.fromScale(0.06, 0.16), UDim2.fromScale(0.88, 0.68)
	t.ZIndex = 7
	return t
end

--[[ The area's portal in a dark window: its own vortex (`Config/Lobby`'s
     `portalModels`; an area with none, Endless, takes Bogheart Caverns's,
     the one every vortex is drawn from), turning a frame at a time as it
     does in the lobby. A locked area's stands still and dim under a lock. ]]
local function portalWindow(sheet: Chunky.Sheet, area: PlayPortal.Area, box: { number })
	local vortex = LobbyConfig.portalVortex
	local model = LobbyConfig.portalModels[area.name]
		or LobbyConfig.portalModels["Bogheart Caverns"]
	local window = Instance.new("Frame")
	window.Name = "Portal"
	window.BorderSizePixel = 0
	window.BackgroundColor3 = Chunky.edge
	window.ClipsDescendants = true
	window.ZIndex = 6
	Chunky.put(sheet, window, box[1], box[2], box[3], box[4])
	Chunky.round(window, 22)
	Chunky.outline(window, 5)
	if model then
		local image = Instance.new("ImageLabel")
		image.Name = "Vortex"
		image.BackgroundTransparency = 1
		image.Image = model.vortex
		image.ImageRectSize = vortex.cell
		image.ScaleType = Enum.ScaleType.Fit
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(0.94, 0.94)
		image.ZIndex = 7
		image.Parent = window
		if area.open then
			local shownFrame = -1
			Kit.animate(image, function(now)
				local frame = math.floor(now / vortex.step) % vortex.frames
				if frame ~= shownFrame then
					shownFrame = frame
					image.ImageRectOffset = Vector2.new(
						(frame % vortex.columns) * vortex.cell.X,
						math.floor(frame / vortex.columns) * vortex.cell.Y
					)
				end
			end)
		else
			image.ImageColor3 = Chunky.grey
			image.ImageTransparency = 0.55
		end
	end
	if not area.open then
		local lock = Kit.image(window, ShopAssets.lock)
		lock.AnchorPoint = Vector2.new(0.5, 0.5)
		lock.Position, lock.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		lock.ZIndex = 9
	end
end

--[[ One area's card at (`x`, `y`), `w` by `h` sheet pixels. Its pieces are
     laid out on the card itself (a sheet of its own, `w` by `h`), so the
     whole card bounces under a press and shakes when it is locked. Returns
     the button a gamepad lands on. ]]
local function card(
	sheet: Chunky.Sheet,
	L: Layout,
	area: PlayPortal.Area,
	x: number,
	y: number,
	w: number,
	h: number
): TextButton
	local frame = Chunky.card(sheet, x, y, w, h)
	frame.Name = `Area{area.index}`
	local on: Chunky.Sheet = {
		canvas = frame,
		w = w,
		h = h,
		upright = sheet.upright,
		panel = nil,
		panelFrame = nil,
		panelFoot = nil,
		header = nil,
	}
	if area.suggested then
		-- the gold ring of the picked level's button, round the whole card
		for ring, spread in { 16, 9 } do
			local halo = Instance.new("Frame")
			halo.Name = "Halo"
			halo.BackgroundTransparency = 1
			halo.ZIndex = 3
			Chunky.put(on, halo, -spread, -spread, w + spread * 2, h + spread * 2)
			Chunky.round(halo, 18 + spread)
			Chunky.outline(halo, spread, Chunky.gold).Transparency = ({ 0.6, 0 })[ring]
		end
	end

	local art = within(L.art, w, h)
	portalWindow(on, area, art)
	if area.suggested then
		local tw, th = math.min(art[3] * 0.86, 250), math.min(art[4] * 0.2, 60)
		pill(on, "NEXT UP", { art[1] + (art[3] - tw) / 2, art[2] - th * 0.3, tw, th }, Chunky.gold)
	end

	local name = Chunky.text(
		frame,
		string.upper(area.name),
		if area.open then Chunky.ink else Chunky.inkSoft,
		0
	)
	name.Name = "AreaName"
	name.ZIndex = 8
	Chunky.put(on, name, table.unpack(within(L.name, w, h)))

	local banner = bannerFor(area.name)
	local act = if area.mode
		then "ENDLESS FLOORS"
		elseif banner then string.upper(banner.act)
		else ""
	if act ~= "" then
		pill(on, act, within(L.act, w, h))
	end

	if not area.open then
		--[[ What opens it takes the room of the count and the bar together,
		     on two lines, so it can be read on a phone. ]]
		local top, bar = within(L.progress, w, h), within(L.bar, w, h)
		local words =
			pill(on, area.words, { top[1], top[2], top[3], bar[2] + bar[4] - top[2] }, Chunky.grey)
		words.TextWrapped = true
		words.Position, words.Size = UDim2.fromScale(0.06, 0.1), UDim2.fromScale(0.88, 0.8)
	elseif not area.mode and area.levels > 0 then
		local complete = area.beaten >= area.levels
		local words = Chunky.text(
			frame,
			if complete then "ALL CLEARED" else `{area.beaten} / {area.levels} LEVELS`,
			Chunky.ink,
			0
		)
		words.Name = "Progress"
		words.ZIndex = 8
		Chunky.put(on, words, table.unpack(within(L.progress, w, h)))
		local bar = within(L.bar, w, h)
		Chunky.bar(
			on,
			area.beaten / area.levels,
			if complete then Chunky.gold else Chunky.lime,
			bar[1],
			bar[2],
			bar[3],
			bar[4]
		)
	end

	--[[ The button is the part that looks pressable; the press itself is the
	     whole card's, so a finger anywhere on it goes on. ]]
	local box = within(L.button, w, h)
	local button = Chunky.button(
		on,
		if area.open then "PLAY" else "LOCKED",
		if not area.open then Chunky.grey elseif area.suggested then Chunky.gold else Chunky.green,
		box[1],
		box[2],
		box[3],
		box[4],
		function() end
	)
	button.Name = "Go"
	local own = button:FindFirstChildWhichIsA("TextButton", true)
	if own then
		own:Destroy()
	end
	Chunky.press(frame, function()
		if area.open then
			enter(area.index)
		else
			shake(frame)
		end
	end)
	return frame:FindFirstChildWhichIsA("TextButton") :: TextButton
end

--[[ Draws the whole list. ]]
local function fill()
	local c = canvas
	if not c then
		return
	end
	for _, child in c:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	nextButton = nil
	local sheet = Chunky.sheet(c)
	local L = if sheet.upright then TALL else WIDE
	Chunky.panel(sheet, table.unpack(L.panel))
	Chunky.ribbon(sheet, "CHOOSE AN AREA", table.unpack(L.ribbon))
	Chunky.close(sheet, L.close[1], L.close[2], L.close[3], close)

	local list = areas()
	local p = profile
	local to = PlayPortal.next(
		list,
		LobbyConfig.portals,
		Balance.Stages,
		if p then p.levelsBeaten else nil
	)
	if to then
		local at = L.continue
		local go = Chunky.button(
			sheet,
			if to.words ~= "" then `CONTINUE {to.words}` else "CONTINUE",
			Chunky.green,
			at[1],
			at[2],
			at[3],
			at[4],
			continueOn
		)
		go.Name = "Continue"
	end
	local count = math.max(#list, 1)
	local columns = math.min(count, L.most)
	local lines = math.ceil(count / columns)
	local bx, by, bw, bh = L.cards[1], L.cards[2], L.cards[3], L.cards[4]
	local w = (bw - L.gap * (columns - 1)) / columns
	local h = (bh - L.gap * (lines - 1)) / lines
	for position, area in list do
		local column = (position - 1) % columns
		local line = (position - 1) // columns
		local button =
			card(sheet, L, area, bx + column * (w + L.gap), by + line * (h + L.gap), w, h)
		if area.suggested then
			nextButton = button
		end
	end
end

function AreaScreen.isOpen(): boolean
	local screen = gui
	return screen ~= nil and screen.Enabled
end

--[[ Opens the list: for the lobby's PLAY button, for the level screen's way
     back, and for a Studio capture. ]]
function AreaScreen.open()
	local player = Players.LocalPlayer
	local screen = gui
	if
		not screen
		or Workspace:GetAttribute("InLobby") ~= true
		or player:GetAttribute("ClassSelecting") == true
	then
		return
	end
	local fresh = not screen.Enabled
	screen.Enabled = true
	fill()
	if fresh and canvas then
		Chunky.pop(canvas)
	end
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = nextButton
	end
end

AreaScreen.close = close

local function build(playerGui: PlayerGui)
	local screen = Instance.new("ScreenGui")
	screen.Name = "AreaScreen"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- as the level screen it leads to (`UI/PortalScreen`), over the stations'
	screen.DisplayOrder = 116
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	-- the lobby dimmed behind, as the other chunky screens stand over it
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BorderSizePixel = 0
	dim.BackgroundColor3 = Chunky.edge
	dim.BackgroundTransparency = 0.45
	dim.Size = UDim2.new(1, 0, 1, 200)
	dim.Position = UDim2.fromOffset(0, -100)
	dim.ZIndex = 1
	dim.Parent = screen

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 2
	holder.Parent = screen

	local c = Instance.new("Frame")
	c.Name = "Canvas"
	c.BackgroundTransparency = 1
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.5)
	c.Size = UDim2.fromScale(0.98, 0.98)
	c.ZIndex = 2
	c.Parent = holder
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 16 / 9
	aspect.Parent = c
	canvas = c

	-- lay out again when a phone turns between upright and landscape
	local upright = holder.AbsoluteSize.Y > holder.AbsoluteSize.X
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local now = holder.AbsoluteSize.Y > holder.AbsoluteSize.X
		if now ~= upright then
			upright = now
			if AreaScreen.isOpen() then
				fill()
			end
		end
	end)
end

function AreaScreen.start()
	local player = Players.LocalPlayer
	build(player:WaitForChild("PlayerGui") :: PlayerGui)
	-- the lobby's HUD and pop-ups ask the level screen whether a choice is up
	PortalScreen.setAreaStep(AreaScreen.isOpen)

	StationScreen.onProfile(function(next)
		profile = next
		if AreaScreen.isOpen() then
			fill()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not AreaScreen.isOpen() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			close()
		elseif
			not processed
			and not FirstTips.takesKeys()
			and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter)
		then
			for _, area in areas() do
				if area.suggested then
					SoundFx.play("card_click")
					enter(area.index)
					break
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not AreaScreen.isOpen() then
			return
		end
		--[[ Nothing to choose once the lobby is gone, in class select, or with
		     a portal walked into, whose own level screen is then up. ]]
		if
			Workspace:GetAttribute("InLobby") ~= true
			or player:GetAttribute("ClassSelecting") == true
			or PortalScreen.levelsOpen()
		then
			close()
		end
	end)
end

return AreaScreen
