--!strict
--[[
	Where you are in the run, and what the run wants from you next.

	Phase 2 asks whether a room-to-room loop holds up, and a loop the player
	cannot see is not a loop — "room 4 of 10" is most of what makes clearing a
	room feel like progress rather than like the same fight again. This is the
	cheapest possible version of that and is expected to be replaced by the
	real HUD in Phase 4.

	Displays only. The server decides what room it is and whether it is
	cleared; this is told.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RunBanner = {}

local roomLabel: TextLabel? = nil
local xpFillBar: Frame? = nil
local levelLabel: TextLabel? = nil
local stateLabel: TextLabel? = nil

local NEUTRAL = Color3.fromRGB(236, 240, 248)
local CLEARED = Color3.fromRGB(120, 220, 160)
local DEAD = Color3.fromRGB(236, 92, 84)

function RunBanner.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("RunBanner")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RunBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	--[[ Top centre, clear of the thumbstick and the health bar. In portrait
	     there is vertical room to spare and almost none horizontally, so the
	     two lines stack rather than sitting side by side. ]]
	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, 52)
	container.Size = UDim2.new(0.7, 0, 0, 46)
	container.BackgroundTransparency = 1
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local room = Instance.new("TextLabel")
	room.Name = "Room"
	room.LayoutOrder = 1
	room.Size = UDim2.new(1, 0, 0, 24)
	room.BackgroundTransparency = 1
	room.Font = Enum.Font.Arcade
	room.TextScaled = true
	room.TextColor3 = NEUTRAL
	room.TextStrokeTransparency = 0.5
	room.Text = ""
	room.Parent = container

	local status = Instance.new("TextLabel")
	status.Name = "State"
	status.LayoutOrder = 2
	status.Size = UDim2.new(1, 0, 0, 18)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Arcade
	status.TextScaled = true
	status.TextColor3 = NEUTRAL
	status.TextStrokeTransparency = 0.6
	status.Text = ""
	status.Parent = container

	--[[
		The draft's progress bar.

		Without it a card screen arrives out of nowhere, and a player who
		cannot see one coming cannot decide whether to push for one more kill
		before stepping through a door. It sits under the room line because
		that is where the eye already goes between fights.
	]]
	local xpTrack = Instance.new("Frame")
	xpTrack.Name = "XpTrack"
	xpTrack.LayoutOrder = 3
	xpTrack.Size = UDim2.new(1, 0, 0, 6)
	xpTrack.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
	xpTrack.BackgroundTransparency = 0.25
	xpTrack.BorderSizePixel = 0
	xpTrack.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = xpTrack

	local xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = Color3.fromRGB(255, 212, 120)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpTrack

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = xpFill

	local levelText = Instance.new("TextLabel")
	levelText.Name = "Level"
	levelText.LayoutOrder = 4
	levelText.Size = UDim2.new(1, 0, 0, 14)
	levelText.BackgroundTransparency = 1
	levelText.Font = Enum.Font.Arcade
	levelText.TextScaled = true
	levelText.TextColor3 = Color3.fromRGB(226, 206, 170)
	levelText.TextStrokeTransparency = 0.7
	levelText.Text = "Level 1"
	levelText.Parent = container

	gui.Parent = playerGui

	roomLabel = room
	stateLabel = status
	xpFillBar = xpFill
	levelLabel = levelText
end

--[[ Argument order matches the remote. `toNext` is what is still owed, not the
     level's total cost, so the bar is drawn from the two numbers the server
     already had rather than from a third it would have to derive. ]]
function RunBanner.onXpChanged(xp: number, toNext: number, level: number)
	local fill = xpFillBar
	local label = levelLabel

	if not fill or not label then
		return
	end

	local total = xp + toNext
	fill.Size = UDim2.fromScale(if total > 0 then math.clamp(xp / total, 0, 1) else 0, 1)
	label.Text = `Level {level}`
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
	local room = roomLabel
	local status = stateLabel

	if not room or not status then
		return
	end

	room.Text = `{unit or "Room"} {index} / {total}  ·  {name}`

	if state == "Cleared" then
		--[[ Only a Rooms stage has an exit; a Waves stage brings the next
		     wave to you. ]]
		status.Text = if unit == "Wave"
			then "Cleared — next wave incoming"
			else "Cleared — take the exit"
		status.TextColor3 = CLEARED
	elseif state == "Dead" then
		status.Text = "You died — restarting"
		status.TextColor3 = DEAD
	elseif state == "Complete" then
		status.Text = "Run complete"
		status.TextColor3 = CLEARED
	else
		status.Text = ""
		status.TextColor3 = NEUTRAL
	end

	--[[ A short pulse on every change. The banner is small and static, so
	     without it a player fighting at the other end of the room will not
	     notice that the room state moved at all. ]]
	room.TextTransparency = 0.5
	TweenService:Create(room, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
end

return RunBanner
