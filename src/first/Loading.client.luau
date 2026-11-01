--!strict
--[[
	The loading screen (owner, 2026-10-26: "i need a loading screen created
	so it doesnt show the player when there is supposed to be a cutscene";
	then "have codex make another loading screen ... with one of the tips").

	Runs from ReplicatedFirst, so a black cover with LOADING is up in the
	first frame on join, before the rest of the game has arrived, Roblox's
	own loading screen removed. Once the game's shared modules are in, one
	of Codex's spotlight screens goes over it (`Config/LoadingScreen`
	`spotlights`), chosen from the spotlit enemies the player has met
	(`Util/LoadingPick`, from their save if it comes in time).

	A spotlight is a finished picture: backdrop, enemy, title and line are
	painted into it, so this draws only the live furniture over it — one of
	the tips (`Config/LoadingTips`) and a bar that fills.

	Four of them exist (owner, 2026-10-31: "the 4 new ones should be the
	only ones in the game so far"). Until 2026-10-31 an entry without one
	fell back to a shared piece of art with the picture, name and line
	composed over it; that path is gone, and an enemy with no spotlight is
	simply not shown.

	It lifts when the client has its intro up (`Main.client` sets the
	player's `ClientReady`), and says so if that takes too long.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 196, 64)
--[[ Seconds before the screen says loading is taking long. ]]
local SLOW = 45

type Box = { x: number, y: number, w: number, h: number }

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

local function text(parent: Instance, name: string, words: string, colour: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.Text = words
	label.TextColor3 = colour
	label.TextScaled = true
	label.Parent = parent
	return label
end

-- the cover, at once
local title = text(back, "Title", "ARCHER LEGENDS", GOLD)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.44)
title.Size = UDim2.fromScale(0.8, 0.09)
local loading = text(back, "Loading", "LOADING", WHITE)
loading.AnchorPoint = Vector2.new(0.5, 0.5)
loading.Position = UDim2.fromScale(0.5, 0.56)
loading.Size = UDim2.fromScale(0.8, 0.04)
local note = text(back, "Note", "", Color3.fromRGB(170, 170, 170))
note.AnchorPoint = Vector2.new(0.5, 1)
note.Position = UDim2.fromScale(0.5, 0.97)
note.Size = UDim2.fromScale(0.8, 0.03)
note.ZIndex = 5

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local fill: Frame? = nil

--[[ The player's save, if it arrives within `wait` seconds. ]]
local function awaitProfile(wait: number): any
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local changed = remotes and remotes:FindFirstChild("ProfileChanged")
	if not changed or not changed:IsA("RemoteEvent") then
		return nil
	end
	local profile = nil
	local connection = changed.OnClientEvent:Connect(function(next)
		if type(next) == "table" then
			profile = next
		end
	end)
	local deadline = os.clock() + wait
	while profile == nil and os.clock() < deadline do
		task.wait(0.1)
	end
	connection:Disconnect()
	return profile
end

--[[ The designed screen, once the game's modules have arrived. ]]
local function build()
	local shared = ReplicatedStorage:WaitForChild("Shared", 30)
	if not shared or not gui.Parent then
		return
	end
	-- arrived before they are required, so the plain paths below are safe
	shared:WaitForChild("Config"):WaitForChild("LoadingScreen")
	shared:WaitForChild("Config"):WaitForChild("LoadingTips")
	shared:WaitForChild("Util"):WaitForChild("LoadingPick")
	local LoadingScreen = require(ReplicatedStorage.Shared.Config.LoadingScreen)
	local LoadingTips = require(ReplicatedStorage.Shared.Config.LoadingTips)
	local LoadingPick = require(ReplicatedStorage.Shared.Util.LoadingPick)

	-- what the player has met, from their save if it comes in time
	local profile = awaitProfile(LoadingScreen.profileWait)
	local ok, pool = pcall(LoadingPick.pool, profile)
	if not ok then
		pool = LoadingPick.pool(nil)
	end
	if not gui.Parent then
		return
	end

	local size: Vector2 = LoadingScreen.size
	local screen = Instance.new("Frame")
	screen.Name = "Screen"
	screen.BackgroundTransparency = 1
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Size = UDim2.fromScale(1, 1)
	screen.ZIndex = 2
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = size.X / size.Y
	aspect.Parent = screen
	screen.Parent = back

	local function place(item: GuiObject, box: Box)
		item.Position = UDim2.fromScale(box.x / size.X, box.y / size.Y)
		item.Size = UDim2.fromScale(box.w / size.X, box.h / size.Y)
	end

	--[[ Only Codex's spotlights are shown (owner, 2026-10-31: "the old
	     loading screens need to be removed, the 4 new ones should be the
	     only ones in the game so far"), so what the player has met is
	     narrowed to the entries that have one. Each is a finished picture
	     — backdrop, enemy, title and line already painted in — which is why
	     the composed window that used to draw those over the shared art is
	     gone with them.

	     None met leaves `entry` nil and the screen is the bar, LOADING and
	     a tip on black. That is a real state only if every spotlit enemy is
	     benched, since the tutorial meets the Mossy Glade's. ]]
	local spotlit: { LoadingPick.Entry } = {}
	for _, candidate in pool do
		if LoadingScreen.spotlights[candidate.name] then
			table.insert(spotlit, candidate)
		end
	end
	local entry = if #spotlit > 0 then spotlit[math.random(1, #spotlit)] else nil
	local art: string? = if entry then LoadingScreen.spotlights[entry.name] else nil
	if art then
		local image = Instance.new("ImageLabel")
		image.Name = "Art"
		image.BackgroundTransparency = 1
		image.Image = art
		image.Size = UDim2.fromScale(1, 1)
		image.ZIndex = 2
		image.Parent = screen
	end
	title.Visible = false
	loading.Visible = false

	-- one of the tips
	local tip =
		text(screen, "Tip", LoadingTips[math.random(1, #LoadingTips)], LoadingScreen.tipText)
	place(tip, LoadingScreen.tip)
	tip.TextWrapped = true
	tip.ZIndex = 3
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 40
	limit.Parent = tip
	local tipPad = Instance.new("UIPadding")
	tipPad.PaddingLeft = UDim.new(0.07, 0)
	tipPad.PaddingRight = UDim.new(0.07, 0)
	tipPad.PaddingTop = UDim.new(0.1, 0)
	tipPad.PaddingBottom = UDim.new(0.1, 0)
	tipPad.Parent = tip

	-- the bar
	local trough = Instance.new("Frame")
	trough.Name = "Bar"
	trough.BackgroundTransparency = if art then 1 else 0
	trough.BackgroundColor3 = Color3.fromRGB(24, 32, 26)
	trough.BorderSizePixel = 0
	place(trough, LoadingScreen.bar)
	trough.ZIndex = 3
	trough.Parent = screen
	local bar = Instance.new("Frame")
	bar.Name = "Fill"
	bar.BackgroundColor3 = LoadingScreen.barFill
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(0, 1)
	bar.ZIndex = 4
	bar.Parent = trough
	fill = bar
end

task.spawn(build)

local started = os.clock()
local connection: RBXScriptConnection
connection = RunService.RenderStepped:Connect(function()
	local elapsed = os.clock() - started
	local ready = player:GetAttribute("ClientReady") == true
	local bar = fill
	if bar then
		-- creeps toward the end while loading, full once ready
		local progress = if ready then 1 else 0.9 * (1 - math.exp(-elapsed / 6))
		bar.Size = UDim2.fromScale(progress, 1)
	end
	loading.Text = "LOADING" .. string.rep(".", math.floor(elapsed * 2) % 4)
	if elapsed > SLOW and not ready then
		note.Text = "TAKING A WHILE... IF IT STAYS HERE, REJOIN"
	end
	if ready then
		connection:Disconnect()
		task.delay(0.25, function()
			gui:Destroy()
		end)
	end
end)
