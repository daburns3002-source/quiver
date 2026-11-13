--!strict
--[[
	The BADGES case (owner, 2026-11-12: a badge for each boss, "like how
	they do in pokemon with gym badges"): every area boss's badge
	(`Config/BossBadges`) set in a case, in the chunky kit, opened from a
	BADGES button in the lobby under REWARDS.

	**It opens like a case** (owner, 2026-11-13: "make it open up like a
	case too"). Each opening starts with the lid shut over the tray; it
	folds up at its hinge and its velvet inside rises above the case,
	carrying the gold plate with the count. Inside, a round velvet slot per
	badge, the boss's name and the area's under it.

	**A badge pops up the first time its boss falls** (owner, 2026-11-13:
	"Yes, add it", to showing it on the spot). A won run whose summary
	carries a boss's item (`Remotes.RunSummary`), for a boss the player had
	not beaten when they joined, earns its badge (`Util/BadgeRules.fromWin`).
	It waits until the player is back in the lobby with nothing else up (no
	station, portal, cutscene, story beat or end screen), then the case opens by itself,
	the plate reads NEW BADGE!, and that badge drops into its empty slot
	with sparks and the reveal sound. Opening the case by hand while one
	waits shows it the same way.

	A badge is earned the first time its boss is beaten, which the server
	already keeps (`profile.bossesBeaten`); the screen only reads the profile
	the server sent. An earned badge is drawn in full with sparkles on it;
	one still to earn is dimmed, its boss's face just showing, with NOT
	BEATEN YET under the name.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BadgeRules = require(ReplicatedStorage.Shared.Util.BadgeRules)
local BossBadges = require(ReplicatedStorage.Shared.Config.BossBadges)
local Chunky = require(script.Parent.Chunky)
local Dex = require(ReplicatedStorage.Shared.Config.Dex)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local StationScreen = require(script.Parent.StationScreen)

local BadgeCase = {}

local player = Players.LocalPlayer
local screen: StationScreen.Screen? = nil

--[[ The case's colours, all from the kit's own: a sea-blue shell like the
     panels' headers, a navy velvet inside, darker round slots. ]]
local VELVET_TOP = Chunky.navy:Lerp(Chunky.headerBottom, 0.4)
local VELVET_BOTTOM = Chunky.navy
local SLOT = Chunky.navy:Lerp(Color3.new(0, 0, 0), 0.4)
--[[ The tint on a badge still to earn, and the words under it. ]]
local LOCKED = Chunky.navy:Lerp(Chunky.white, 0.4)
local MUTED = Chunky.white:Lerp(Chunky.navy, 0.4)

--[[ The lid: when it starts to move after the panel pops in, how long it
     takes to fold shut-side up, and how long its inside takes to rise. ]]
local LID_WAIT = 0.25
local LID_FOLD = 0.2
local LID_RISE = 0.3

--[[ The badge that drops into its slot on the case's next opening. ]]
local reveal: string? = nil
--[[ Badges earned since this client first saw the profile, not yet shown. ]]
local waiting: { string } = {}

function BadgeCase.open()
	local s = screen
	if s then
		if not reveal and #waiting > 0 then
			reveal = table.remove(waiting, 1)
		end
		StationScreen.openShortcut(s.open)
	end
end

function BadgeCase.isOpen(): boolean
	return screen ~= nil and screen.isOpen()
end

--[[ The boss an area's badge stands for, as its item names it. ]]
local function bossOf(area: string): string
	local config = Economy.areas[area]
	local item = if config then Economy.items[config.bossItem] else nil
	return if item then string.upper(item.boss) else area
end

--[[ A plain piece of `colour`, filling its parent unless sized after. ]]
local function piece(parent: Instance, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = parent
	return f
end

--[[ An empty box on the sheet, in sheet pixels, for a piece to move in. ]]
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

--[[ Lights `item` from `top` down to `bottom`. ]]
local function shade(item: GuiObject, top: Color3, bottom: Color3)
	item.BackgroundColor3 = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = item
end

local function circle(item: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = item
end

--[[ Words on the sheet, in sheet pixels, centred: white with the navy
     stroke unless told otherwise. ]]
local function words(
	sheet: Chunky.Sheet,
	text: string,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3?,
	stroke: number?
): TextLabel
	local t = Chunky.text(sheet.canvas, text, colour, stroke)
	Chunky.put(sheet, t, x, y, w, h)
	t.ZIndex = 12
	return t
end

--[[ A badge dropping into its slot: from large and clear to its place,
     then sparks, the reveal sound and its sparkles. ]]
local function dropIn(holder: Frame, medal: ImageLabel, at: number)
	local grow = Instance.new("UIScale")
	grow.Scale = 2.4
	grow.Parent = holder
	medal.ImageTransparency = 1
	task.delay(at, function()
		if not holder.Parent then
			return
		end
		local land = TweenService:Create(
			grow,
			TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		TweenService:Create(medal, TweenInfo.new(0.2), { ImageTransparency = 0 }):Play()
		land.Completed:Once(function()
			if holder.Parent then
				SoundFx.play("reveal_rare")
				Chunky.burst(holder)
				Chunky.twinkle(holder)
			end
		end)
		land:Play()
	end)
end

--[[ The shut lid over the case, gold-trimmed with its clasp, folding up at
     its hinge; then the lid's inside rises above the case. ]]
local function openLid(
	sheet: Chunky.Sheet,
	x: number,
	y: number,
	w: number,
	h: number,
	inside: Frame
)
	local hinge = box(sheet, x, y, w, h, 40)
	local lid = piece(hinge, Color3.new(1, 1, 1), 40)
	lid.Name = "Lid"
	shade(lid, Chunky.headerTop, Chunky.headerBottom)
	Chunky.round(lid, 26)
	Chunky.outline(lid, 6)
	local trim = piece(lid, Color3.new(1, 1, 1), 41)
	trim.BackgroundTransparency = 1
	trim.Position, trim.Size = UDim2.fromScale(0.025, 0.06), UDim2.fromScale(0.95, 0.88)
	Chunky.round(trim, 18)
	Chunky.outline(trim, 5, Chunky.gold)
	local clasp = piece(lid, Color3.new(1, 1, 1), 42)
	clasp.AnchorPoint = Vector2.new(0.5, 1)
	clasp.Position = UDim2.fromScale(0.5, 1.03)
	clasp.Size = UDim2.fromScale(if sheet.upright then 0.16 else 0.09, 0.12)
	Chunky.light(clasp, Chunky.gold)
	Chunky.round(clasp, 10)
	Chunky.outline(clasp, 5, Chunky.shade(Chunky.gold))
	task.delay(LID_WAIT, function()
		if not lid.Parent then
			return
		end
		SoundFx.play("card_choose")
		local fold = TweenService:Create(
			lid,
			TweenInfo.new(LID_FOLD, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = UDim2.fromScale(1, 0) }
		)
		fold.Completed:Once(function()
			hinge:Destroy()
			if inside.Parent then
				TweenService:Create(
					inside,
					TweenInfo.new(LID_RISE, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(1, 1) }
				):Play()
			end
		end)
		fold:Play()
	end)
end

local function draw(s: StationScreen.Screen)
	-- the panel's first draw since it was shown is an opening
	local opening = s.canvas:GetAttribute("Shown") == nil
	local area = HatchStand.chrome(s, "BADGES")
	local sheet = area.sheet
	local profile = s.profile
	if not profile then
		words(sheet, "LOADING...", area.x, area.y + 200, area.w, 80, Chunky.ink, 0)
		return
	end
	local beaten = profile.bossesBeaten
	local dropping = if opening then reveal else nil
	if opening then
		reveal = nil
	end
	local count, total = BadgeRules.count(beaten), #BossBadges.order
	local up = sheet.upright

	-- the lid's velvet inside, standing open above the case, and its plate
	local lidH = if up then 230 else 170
	local hinge = area.y + lidH
	local inset = if up then 24 else 40
	local insideBox = box(sheet, area.x + inset, area.y, area.w - 2 * inset, lidH, 6)
	local inside = piece(insideBox, Color3.new(1, 1, 1), 6)
	inside.Name = "LidInside"
	inside.AnchorPoint = Vector2.new(0.5, 1)
	inside.Position = UDim2.fromScale(0.5, 1)
	inside.Size = UDim2.fromScale(1, if opening then 0 else 1)
	shade(inside, VELVET_BOTTOM, VELVET_TOP)
	Chunky.round(inside, 22)
	Chunky.outline(inside, 6)
	local plate = piece(inside, Color3.new(1, 1, 1), 7)
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromScale(if up then 0.64 else 0.4, 0.56)
	Chunky.light(plate, Chunky.gold)
	Chunky.round(plate, 16)
	Chunky.outline(plate, 5, Chunky.shade(Chunky.gold))
	local label = Chunky.textOn(
		plate,
		if dropping then "NEW BADGE!" else `EARNED {count} / {total}`,
		Chunky.gold,
		4
	)
	label.Position, label.Size = UDim2.fromScale(0.06, 0.16), UDim2.fromScale(0.88, 0.68)
	label.ZIndex = 8

	-- the case and its velvet tray
	local caseH = area.bottom - hinge
	local shell = box(sheet, area.x, hinge, area.w, caseH, 5)
	shell.BackgroundTransparency = 0
	shade(shell, Chunky.headerTop, Chunky.headerBottom)
	Chunky.round(shell, 26)
	Chunky.outline(shell, 6)
	local pad = 24
	local tx, ty, tw, th = area.x + pad, hinge + pad, area.w - 2 * pad, caseH - 2 * pad
	local tray = box(sheet, tx, ty, tw, th, 6)
	tray.BackgroundTransparency = 0
	shade(tray, VELVET_TOP, VELVET_BOTTOM)
	Chunky.round(tray, 18)
	Chunky.outline(tray, 4)

	-- a slot per badge: four across, or two by two upright
	local cols = if up then 2 else math.min(total, 4)
	local rows = math.ceil(total / cols)
	local cellW, cellH = tw / cols, th / rows
	local d = math.floor(math.min(cellW * 0.74, cellH * 0.66))
	local tall = d * 1.34
	for i, badge in BossBadges.order do
		local col, line = (i - 1) % cols, (i - 1) // cols
		local cx = tx + cellW * (col + 0.5)
		local top = ty + cellH * line + (cellH - tall) / 2
		local earned = beaten[badge.area] == true
		local slot = box(sheet, cx - d / 2, top, d, d, 7)
		slot.BackgroundTransparency = 0
		slot.BackgroundColor3 = SLOT
		circle(slot)
		local rim = Instance.new("UIStroke")
		rim.Color = Chunky.headerBottom
		rim.Thickness = 3
		rim.Parent = slot
		local holder = box(sheet, cx - d * 0.47, top + d * 0.03, d * 0.94, d * 0.94, 8)
		holder.Name = "Badge"
		local medal = Kit.image(holder, badge.image)
		medal.ZIndex = 9
		if dropping == badge.area then
			dropIn(holder, medal, LID_WAIT + LID_FOLD + LID_RISE + 0.1)
		elseif earned then
			Chunky.twinkle(holder)
		else
			--[[ Dimmed, not black: every badge is round, so a silhouette
			     would be the same plain disc four times. ]]
			medal.ImageColor3 = LOCKED
			medal.ImageTransparency = 0.2
		end
		local nameY = top + d * 1.05
		words(sheet, bossOf(badge.area), cx - cellW * 0.46, nameY, cellW * 0.92, d * 0.15)
		local place = Dex.areas[badge.area]
		words(
			sheet,
			if earned then (if place then place.name else badge.area) else "NOT BEATEN YET",
			cx - cellW * 0.4,
			nameY + d * 0.17,
			cellW * 0.8,
			d * 0.1,
			if earned then Chunky.gold else MUTED,
			0
		)
	end

	if opening then
		openLid(sheet, area.x, hinge, area.w, caseH, inside)
	end
end

--[[ The lobby's BADGES button, under REWARDS (`UI/RewardsScreen`), shown
     whenever the REWARDS one is; and the case opening by itself for a
     badge just earned. ]]
local function startButton()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BadgesButton"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	local canvas = Kit.canvas(gui)
	local built: boolean? = nil

	local function build()
		for _, child in canvas:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local sheet = Chunky.sheet(canvas)
		built = sheet.upright
		-- REWARDS stands at 24, 230 (150 on a wide screen), 250 x 92
		local by = (if sheet.upright then 230 else 150) + 92 + 24
		Chunky.button(
			sheet,
			"BADGES",
			Chunky.blue,
			24,
			by,
			250,
			92,
			BadgeCase.open,
			BossBadges.order[1].image
		)
	end

	--[[ Which bosses the first profile had beaten, and which badges have
	     popped up since: a boss's first win in a run queues its badge
	     (`Util/BadgeRules.fromWin`). ]]
	local atJoin: { [string]: boolean }? = nil
	local shown: { [string]: boolean } = {}
	StationScreen.onProfile(function(profile)
		if not atJoin then
			atJoin = table.clone(profile.bossesBeaten)
		end
	end)
	Remotes.event(Remotes.RunSummary).OnClientEvent:Connect(function(summary)
		local before = atJoin
		if type(summary) ~= "table" or not before then
			return
		end
		local item = summary.item
		local area = BadgeRules.fromWin(
			summary.won == true,
			if type(item) == "string" then item else nil,
			before,
			shown
		)
		if area then
			shown[area] = true
			table.insert(waiting, area)
		end
	end)

	-- half-second ticks with the lobby clear before a waiting badge shows
	local calm = 0
	task.spawn(function()
		while gui.Parent do
			local playerGui = player:FindFirstChild("PlayerGui")
			local free = Workspace:GetAttribute("InLobby") == true
				and player:GetAttribute("ClassSelecting") ~= true
				and not RunPaused.beforeArrival()
				and playerGui ~= nil
				and playerGui:FindFirstChild("IntroCutscene") == nil
				and playerGui:FindFirstChild("StoryCutscene") == nil
				and player:GetAttribute("InStation") ~= true
			gui.Enabled = free
			if free then
				local upright = gui.AbsoluteSize.Y > gui.AbsoluteSize.X
				if built ~= upright then
					build()
				end
			end
			local clear = free
				and player:GetAttribute("Arrived") == true
				and player:GetAttribute("Portal") == nil
				and playerGui ~= nil
				and playerGui:FindFirstChild("StoryBeat") == nil
				and playerGui:FindFirstChild("EndScreen") == nil
			if clear and #waiting > 0 then
				calm += 1
				if calm >= 3 then
					calm = 0
					BadgeCase.open()
				end
			else
				calm = 0
			end
			task.wait(0.5)
		end
	end)
end

function BadgeCase.start()
	if screen then
		return
	end
	-- no station of its own: it opens from its button, never from a prompt
	local s = StationScreen.new("BadgeCase", "Badges", "BADGES")
	screen = s
	s.draw = function()
		draw(s)
	end
	startButton()
end

return BadgeCase
