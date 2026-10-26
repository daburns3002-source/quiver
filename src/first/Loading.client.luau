--!strict
--[[
	The loading screen (owner, 2026-10-26: "i need a loading screen created
	so it doesnt show the player when there is supposed to be a cutscene").

	Runs from ReplicatedFirst, so it is up in the first frame on join, before
	the rest of the game has arrived: a black screen, the game's name and a
	LOADING line, over everything, Roblox's own loading screen removed. It
	lifts when the client has its intro cutscene up (`Main.client` sets the
	player's `ClientReady`), and says so if that takes too long.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 196, 64)
--[[ Seconds before the screen says loading is taking long. ]]
local SLOW = 45

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local back = Instance.new("Frame")
back.Name = "Back"
back.BackgroundColor3 = BLACK
back.BorderSizePixel = 0
back.Size = UDim2.fromScale(1, 1)
back.Parent = gui

local function text(
	name: string,
	words: string,
	colour: Color3,
	y: number,
	height: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromScale(0.8, height)
	label.Font = Enum.Font.Arcade
	label.Text = words
	label.TextColor3 = colour
	label.TextScaled = true
	label.Parent = back
	return label
end

text("Title", "ARCHER LEGENDS", GOLD, 0.44, 0.09)
local loading = text("Loading", "LOADING", WHITE, 0.56, 0.04)
local note = text("Note", "", Color3.fromRGB(170, 170, 170), 0.64, 0.03)

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local started = os.clock()
local connection: RBXScriptConnection
connection = RunService.RenderStepped:Connect(function()
	if player:GetAttribute("ClientReady") == true then
		connection:Disconnect()
		gui:Destroy()
		return
	end
	local elapsed = os.clock() - started
	loading.Text = "LOADING" .. string.rep(".", math.floor(elapsed * 2) % 4)
	if elapsed > SLOW then
		note.Text = "TAKING A WHILE... IF IT STAYS HERE, REJOIN"
	end
end)
