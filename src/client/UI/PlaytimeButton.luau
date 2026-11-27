--!strict
--[[
	The lobby's gift button (owner, 2026-11-18): the playtime gifts
	(`Util/PlaytimeRules`) at a glance, under REWARDS and BADGES. A round
	gold button with the gift on it, a ring of blocks round it that fills as
	the next gift comes nearer, and under it the time left; once a gift has
	opened the ring is gold, the words say GIFT READY! and the whole button
	pulses. A press opens REWARDS on its GIFTS tab, where gifts are claimed.
	Once the session's six are claimed it goes away until the next session.

	It only draws: the clock is the server's (`Workspace:GetServerTimeNow`)
	read against the session the server keeps in the profile
	(`SaveSchema.playtime`), and nothing is claimed from here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Chunky = require(script.Parent.Chunky)
local HookAssets = require(ReplicatedStorage.Shared.Config.HookAssets)
local Kit = require(script.Parent.Kit)
local PlaytimeRules = require(ReplicatedStorage.Shared.Util.PlaytimeRules)
local PortalScreen = require(script.Parent.PortalScreen)
local RewardsScreen = require(script.Parent.RewardsScreen)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local StationScreen = require(script.Parent.StationScreen)

local PlaytimeButton = {}

--[[ Blocks in the ring, and the button's size in sheet pixels: the disc,
     the ring's blocks and their distance out, the words' pill. ]]
local PIPS = 20
local DISC = 130
local PIP = 16
local RING = DISC / 2 + 18
local LABEL_W, LABEL_H = 230, 54
--[[ The REWARDS and BADGES buttons it sits under (`UI/RewardsScreen`
     `startButton`, `UI/BadgeCase`): REWARDS at 24, 230 (150 on a wide
     screen), 250 x 92, BADGES 24 below it, as tall. ]]
local REWARDS_X, REWARDS_W, REWARDS_H = 24, 250, 92
local BADGES_GAP, BADGES_H = 24, 92

local started = false

function PlaytimeButton.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "PlaytimeButton"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = playerGui
	local canvas = Kit.canvas(gui)

	local profile: SaveSchema.Profile? = nil
	StationScreen.onProfile(function(next)
		profile = next
	end)

	local built: boolean? = nil
	local holder: Frame? = nil
	local pips: { Frame } = {}
	local words: TextLabel? = nil
	local pill: Frame? = nil
	local pulse: UIScale? = nil

	local function build()
		for _, child in canvas:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(pips)
		local sheet = Chunky.sheet(canvas)
		built = sheet.upright
		local cx = REWARDS_X + REWARDS_W / 2
		local top = (if sheet.upright then 230 else 150) + REWARDS_H + BADGES_GAP + BADGES_H + 36
		local cy = top + RING + PIP / 2
		local bw, bh = LABEL_W, (RING + PIP / 2) * 2 + 8 + LABEL_H
		local bx, by = cx - LABEL_W / 2, top
		local box = Instance.new("Frame")
		box.Name = "PlaytimeGift"
		box.BackgroundTransparency = 1
		box.ZIndex = 10
		Chunky.put(sheet, box, bx, by, bw, bh)
		holder = box
		-- what pulses, inside what a press squeezes
		local body = Instance.new("Frame")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Size = UDim2.fromScale(1, 1)
		body.ZIndex = 10
		body.Parent = box
		local scale = Instance.new("UIScale")
		scale.Parent = body
		pulse = scale
		-- a part placed in sheet pixels, inside the body
		local function into(item: GuiObject, x: number, y: number, w: number, h: number)
			item.Position = UDim2.fromScale((x - bx) / bw, (y - by) / bh)
			item.Size = UDim2.fromScale(w / bw, h / bh)
			item.Parent = body
		end
		for index = 1, PIPS do
			local angle = math.rad(-90 + (index - 1) * 360 / PIPS)
			local dot = Instance.new("Frame")
			dot.Name = "Pip"
			dot.BorderSizePixel = 0
			dot.BackgroundColor3 = Chunky.trough
			dot.ZIndex = 12
			into(
				dot,
				cx + math.cos(angle) * RING - PIP / 2,
				cy + math.sin(angle) * RING - PIP / 2,
				PIP,
				PIP
			)
			Chunky.round(dot, PIP)
			Chunky.outline(dot, 3)
			table.insert(pips, dot)
		end
		local disc = Instance.new("Frame")
		disc.Name = "Disc"
		disc.BorderSizePixel = 0
		disc.BackgroundColor3 = Chunky.gold
		disc.ZIndex = 11
		into(disc, cx - DISC / 2, cy - DISC / 2, DISC, DISC)
		Chunky.round(disc, DISC)
		Chunky.outline(disc, 6)
		local light = Instance.new("UIGradient")
		light.Rotation = 90
		light.Color = ColorSequence.new(Chunky.lit(Chunky.gold), Chunky.shade(Chunky.gold))
		light.Parent = disc
		local picture = Kit.image(disc, HookAssets.gift)
		picture.Position, picture.Size = UDim2.fromScale(0.12, 0.1), UDim2.fromScale(0.76, 0.76)
		picture.ZIndex = 13
		local plate = Instance.new("Frame")
		plate.Name = "Time"
		plate.BorderSizePixel = 0
		plate.BackgroundColor3 = Chunky.navy
		plate.ZIndex = 14
		into(plate, cx - LABEL_W / 2, cy + RING + PIP / 2 + 8, LABEL_W, LABEL_H)
		Chunky.round(plate, LABEL_H / 2)
		Chunky.outline(plate, 5, Chunky.gold)
		local t = Chunky.text(plate, "", Chunky.white, 3)
		t.Position, t.Size = UDim2.fromScale(0.06, 0.14), UDim2.fromScale(0.88, 0.72)
		t.ZIndex = 15
		pill, words = plate, t
		Chunky.press(box, function()
			RewardsScreen.open("GIFTS")
		end)
	end

	local wasReady = false
	RunService.RenderStepped:Connect(function()
		local inLobby = Workspace:GetAttribute("InLobby") == true
			and player:GetAttribute("ClassSelecting") ~= true
			and not RunPaused.beforeArrival()
			and playerGui:FindFirstChild("IntroCutscene") == nil
			and playerGui:FindFirstChild("StoryCutscene") == nil
		local p = profile
		local clock = if p and (p :: any).playtime then p.playtime else nil
		local show = inLobby
			and player:GetAttribute("InStation") ~= true
			and not PortalScreen.isOpen()
			and clock ~= nil
			and not PlaytimeRules.finished(clock)
		gui.Enabled = show == true
		if not show or not clock then
			return
		end
		local upright = gui.AbsoluteSize.Y > gui.AbsoluteSize.X
		if built ~= upright then
			build()
		end
		local now = Workspace:GetServerTimeNow()
		local ready = PlaytimeRules.ready(clock, now) > 0
		local nextGift, left = PlaytimeRules.upcoming(clock, now)
		local share = if ready
			then 1
			elseif nextGift then PlaytimeRules.progress(clock, now, nextGift)
			else 0
		local lit = math.floor(share * PIPS + 1e-6)
		for index, dot in pips do
			dot.BackgroundColor3 = if ready
				then Chunky.gold
				elseif index <= lit then Chunky.lime
				else Chunky.trough
		end
		local label = words
		if label then
			label.Text = if ready
				then "GIFT READY!"
				elseif nextGift then PlaytimeRules.clockText(left)
				else ""
			label.TextColor3 = if ready then Chunky.gold else Chunky.white
		end
		if ready and not wasReady then
			local plate = pill
			if plate then
				Chunky.pop(plate)
			end
		end
		wasReady = ready
		local scale = pulse
		if scale then
			scale.Scale = if ready then 1 + 0.06 * math.sin(os.clock() * 6) else 1
		end
		local box = holder
		if box then
			box.Rotation = if ready then 3 * math.sin(os.clock() * 3) else 0
		end
	end)
end

return PlaytimeButton
