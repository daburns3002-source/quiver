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
	room.Font = Enum.Font.GothamBold
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
	status.Font = Enum.Font.Gotham
	status.TextScaled = true
	status.TextColor3 = NEUTRAL
	status.TextStrokeTransparency = 0.6
	status.Text = ""
	status.Parent = container

	gui.Parent = playerGui

	roomLabel = room
	stateLabel = status
end

--[[ Argument order matches the remote: the server sends what it knows and the
     client does not reorder or reinterpret it. ]]
function RunBanner.onRunStateChanged(index: number, total: number, state: string, name: string)
	local room = roomLabel
	local status = stateLabel

	if not room or not status then
		return
	end

	room.Text = `Room {index} / {total}  ·  {name}`

	if state == "Cleared" then
		status.Text = "Cleared — take the exit"
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
