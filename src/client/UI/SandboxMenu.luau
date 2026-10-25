--!strict
--[[
	The playtest sandbox's menu (`Config/Sandbox`), Studio only: the SANDBOX
	tab on the left edge, or the O key (`DevKeys`). From it: into the sandbox
	(the room's fight becomes training dummies that never die or hit back,
	and nobody can be hurt) and out again (the stage starts over), any weapon
	in hand, held as its class so it attacks the dummies, and any imported
	pet at heel (`Fx/PetPreview`).

	The server does the swapping and checks it is Studio; this only asks.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetPreview = require(script.Parent.Parent.Fx.PetPreview)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)

local SandboxMenu = {}

local FONT = Enum.Font.Arcade
local PANEL = Color3.fromRGB(27, 27, 43)
local BUTTON = Color3.fromRGB(52, 56, 92)
local ACCENT = Color3.fromRGB(255, 106, 85)
local CHOSEN = Color3.fromRGB(76, 209, 55)
local INK = Color3.fromRGB(240, 240, 250)
local DARK_INK = Color3.fromRGB(16, 34, 12)

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local panel: Frame? = nil
local refreshers: { () -> () } = {}
local pet: string? = nil
local petLoading = false

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, size: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextSize = size
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Size = UDim2.new(1, 0, 0, size + 8)
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = BUTTON
	b.Font = FONT
	b.TextSize = 11
	b.TextColor3 = INK
	b.TextWrapped = true
	b.Text = text
	b.Parent = parent
	corner(b, 8)
	b.Activated:Connect(onClick)
	return b
end

local function paint(b: TextButton, chosen: boolean)
	b.BackgroundColor3 = if chosen then CHOSEN else BUTTON
	b.TextColor3 = if chosen then DARK_INK else INK
end

--[[ "EmberWilfPet" → "EMBER WILF". ]]
local function petName(key: string): string
	local name = key:gsub("Pet$", ""):gsub("(%l)(%u)", "%1 %2")
	return name:upper()
end

local function grid(parent: Instance, order: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Size = UDim2.fromScale(1, 0)
	frame.LayoutOrder = order
	frame.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -4, 0, 40)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function refresh()
	for _, f in refreshers do
		f()
	end
end

local function build(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "SandboxMenu"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 150
	screen.IgnoreGuiInset = true
	screen.Parent = player:WaitForChild("PlayerGui")

	-- the tab that opens it
	local tab = button(screen, "SANDBOX", function()
		SandboxMenu.toggle()
	end)
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Position = UDim2.new(0, 8, 0.5, 0)
	tab.Size = UDim2.fromOffset(104, 34)
	tab.BackgroundColor3 = PANEL
	tab.TextColor3 = ACCENT

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -12, 0.5, 0)
	frame.Size = UDim2.new(0, 380, 0.86, 0)
	frame.BackgroundColor3 = PANEL
	frame.BackgroundTransparency = 0.05
	frame.Visible = false
	frame.Parent = screen
	corner(frame, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Thickness = 2
	stroke.Parent = frame
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(380, 720)
	cap.Parent = frame
	panel = frame

	local title = label(frame, "SANDBOX", 22, ACCENT)
	title.Position = UDim2.fromOffset(16, 14)
	title.Size = UDim2.new(1, -70, 0, 30)

	local close = button(frame, "X", function()
		SandboxMenu.toggle()
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(34, 34)

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(16, 56)
	body.Size = UDim2.new(1, -32, 1, -68)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = ACCENT
	body.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = body

	-- in or out
	local enter = button(body, "", function()
		Remotes.event(Remotes.DebugSandbox):FireServer(not Workspace:GetAttribute("Sandbox"))
	end)
	enter.LayoutOrder = 1
	enter.Size = UDim2.new(1, 0, 0, 46)
	enter.TextSize = 14
	table.insert(refreshers, function()
		local inside = Workspace:GetAttribute("Sandbox") == true
		enter.Text = if inside then "LEAVE SANDBOX" else "ENTER SANDBOX"
		enter.BackgroundColor3 = if inside then BUTTON else ACCENT
	end)
	local hint = label(
		body,
		"DUMMIES NEVER DIE OR HIT BACK. STAND STILL TO ATTACK. LEAVING STARTS THE STAGE AGAIN.",
		9,
		INK
	)
	hint.LayoutOrder = 2
	hint.Size = UDim2.new(1, 0, 0, 34)

	label(body, "WEAPON", 14, ACCENT).LayoutOrder = 3
	local weapons = grid(body, 4)
	for i, entry in Sandbox.weapons do
		local b = button(weapons, entry.label, function()
			Remotes.event(Remotes.DebugWeapon):FireServer(entry.weapon)
		end)
		b.LayoutOrder = i
		table.insert(refreshers, function()
			paint(b, player:GetAttribute("Weapon") == entry.weapon)
		end)
	end

	label(body, "PET", 14, ACCENT).LayoutOrder = 5
	local pets = grid(body, 6)
	local function choosePet(key: string?)
		if petLoading then
			return
		end
		petLoading = true
		pet = key
		refresh()
		task.spawn(function()
			PetPreview.show(key)
			petLoading = false
			refresh()
		end)
	end
	local none = button(pets, "NONE", function()
		choosePet(nil)
	end)
	none.LayoutOrder = 0
	table.insert(refreshers, function()
		paint(none, pet == nil)
	end)
	for i, key in PetPreview.keys() do
		local b = button(pets, petName(key), function()
			choosePet(key)
		end)
		b.LayoutOrder = i
		table.insert(refreshers, function()
			paint(b, pet == key)
			b.Text = if pet == key and petLoading then "LOADING..." else petName(key)
		end)
	end

	player:GetAttributeChangedSignal("Weapon"):Connect(refresh)
	Workspace:GetAttributeChangedSignal("Sandbox"):Connect(refresh)
	refresh()
	return screen
end

--[[ Opens or closes the menu (building it the first time). ]]
function SandboxMenu.toggle()
	if not RunService:IsStudio() then
		return
	end
	if not gui then
		gui = build()
	end
	local frame = panel
	if frame then
		frame.Visible = not frame.Visible
	end
end

--[[ Puts the SANDBOX tab on screen, in Studio only. ]]
function SandboxMenu.start()
	if not RunService:IsStudio() or gui then
		return
	end
	gui = build()
end

return SandboxMenu
