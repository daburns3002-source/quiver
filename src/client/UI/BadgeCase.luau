--!strict
--[[
	The BADGES case (owner, 2026-11-12: a badge for each boss, "like how
	they do in pokemon with gym badges"): every area boss's badge
	(`Config/BossBadges`) in one panel, in the chunky kit, opened from a
	BADGES button in the lobby under REWARDS.

	A badge is earned the first time its boss is beaten, which the server
	already keeps (`profile.bossesBeaten`); the screen only reads the profile
	the server sent. An earned badge is drawn in full with sparkles on it
	and its area's name under the boss's; one still to earn is its own
	picture tinted black, as the Dex draws an entry not yet found, so the
	shape is the hint.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossBadges = require(ReplicatedStorage.Shared.Config.BossBadges)
local Chunky = require(script.Parent.Chunky)
local Dex = require(ReplicatedStorage.Shared.Config.Dex)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local HatchStand = require(script.Parent.HatchStand)
local Kit = require(script.Parent.Kit)
local RunPaused = require(script.Parent.Parent.RunPaused)
local StationScreen = require(script.Parent.StationScreen)

local BadgeCase = {}

local player = Players.LocalPlayer
local screen: StationScreen.Screen? = nil

function BadgeCase.open()
	local s = screen
	if s then
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

--[[ Words on the sheet, in sheet pixels, centred: ink with no stroke
     unless a stroke is asked for. ]]
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
	local t = Chunky.text(sheet.canvas, text, colour or Chunky.ink, stroke or 0)
	Chunky.put(sheet, t, x, y, w, h)
	t.ZIndex = 12
	return t
end

--[[ One badge on its white card: the medal, the boss's name, and the
     area's name once it is earned. ]]
local function badgeCard(
	sheet: Chunky.Sheet,
	badge: BossBadges.Badge,
	earned: boolean,
	x: number,
	y: number,
	w: number,
	h: number
)
	Chunky.card(sheet, x, y, w, h)
	local side = math.floor(w * 0.8)
	local holder = Instance.new("Frame")
	holder.Name = "Badge"
	holder.BackgroundTransparency = 1
	holder.ZIndex = 8
	Chunky.put(sheet, holder, x + (w - side) / 2, y + w * 0.08, side, side)
	local medal = Kit.image(holder, badge.image, not earned)
	medal.ZIndex = 9
	if earned then
		Chunky.twinkle(holder)
	else
		-- an empty slot, not a dark coin
		medal.ImageTransparency = 0.45
	end
	local below = y + w * 0.08 + side + h * 0.03
	words(sheet, bossOf(badge.area), x + 16, below, w - 32, h * 0.085, Chunky.white, 4)
	local place = Dex.areas[badge.area]
	words(
		sheet,
		if earned then (if place then place.name else badge.area) else "NOT BEATEN YET",
		x + 24,
		below + h * 0.095,
		w - 48,
		h * 0.06,
		if earned then Chunky.ink else Chunky.ink:Lerp(Chunky.white, 0.45)
	)
end

local function draw(s: StationScreen.Screen)
	local area = HatchStand.chrome(s, "BADGES")
	local sheet = area.sheet
	local profile = s.profile
	if not profile then
		words(sheet, "LOADING...", area.x, area.y + 200, area.w, 80)
		return
	end
	local beaten = profile.bossesBeaten or {}
	local count = 0
	for _, badge in BossBadges.order do
		if beaten[badge.area] then
			count += 1
		end
	end
	local total = #BossBadges.order
	words(sheet, `EARNED {count} / {total}`, area.x, area.y, area.w, 56)

	local up = sheet.upright
	local cols = if up then 2 else math.min(total, 4)
	local rows = math.ceil(total / cols)
	local gap = if up then 30 else 24
	local top = area.y + 80
	local room = area.bottom - top
	local cw = (area.w - (cols - 1) * gap) / cols
	local ch = math.min(cw * 1.45, (room - (rows - 1) * gap) / rows)
	-- the cards sit in the middle of the room left
	local used = rows * ch + (rows - 1) * gap
	local y0 = top + math.max(0, (room - used) / 2)
	for i, badge in BossBadges.order do
		local col, line = (i - 1) % cols, (i - 1) // cols
		badgeCard(
			sheet,
			badge,
			beaten[badge.area] == true,
			area.x + col * (cw + gap),
			y0 + line * (ch + gap),
			cw,
			ch
		)
	end
end

--[[ The lobby's BADGES button, under REWARDS (`UI/RewardsScreen`), shown
     whenever the REWARDS one is. ]]
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
