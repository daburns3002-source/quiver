--!strict
--[[
	The settings: music volume, sound volume, vibration (`Config/Settings`,
	`client/Options`; the 2026-11-11 loop and UI review found none of them).

	A SETTINGS button on the lobby's left edge, drawn as the owner's
	reference draws its rail (a cream tile with the picture on it and the
	word under it), opens a chunky panel (`UI/Chunky`): each volume as pips
	between a minus and a plus, vibration as one button that says ON or OFF.
	A press changes the setting at once (`Options.set`) and the server keeps
	it in the save. The button shows only in the lobby; in a run the pause
	menu is the one button on screen.

	Under them, the CODES box (`Config/Codes`, 2026-11-18): the player types
	a code and presses REDEEM; the server checks it against its own list
	(`Data/Codes`) and the answer shows under the box, green or red.

	Sized in screen points, so a phone held upright gets buttons a thumb can
	press: the panel is `WIDTH` points wide at most and fitted to the screen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CodeConfig = require(ReplicatedStorage.Shared.Config.Codes)
local CodeRules = require(ReplicatedStorage.Shared.Util.CodeRules)
local Config = require(ReplicatedStorage.Shared.Config.Settings)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)

local Chunky = require(script.Parent.Chunky)
local Options = require(script.Parent.Parent.Options)

local SettingsScreen = {}

--[[ The panel, in points, and how clear of the screen's edges it stays. ]]
local WIDTH = 440
local HEIGHT = 400
local MARGIN = 12
--[[ The rail button: a tile this many points square with its word under
     it, this far from the left edge and above the screen's middle (the
     REWARDS button has the middle). ]]
local TILE = 52
local LEFT = 8
local RISE = 112

local panel: Frame? = nil
local isOpen = false
--[[ The CODES box: what is typed (kept across a redraw), the last answer
     and whether it was a yes, and when REDEEM last sent. ]]
local typed = ""
local answer = ""
local answerOk = false
local sentAt = -math.huge
--[[ Seconds between two REDEEM presses; the server has its own limit. ]]
local PRESS_GAP = 1

--[[ A cog, drawn: four bars through a disc, a hole in its middle. ]]
local function cog(parent: GuiObject)
	local metal = Color3.fromRGB(150, 160, 178)
	local dark = Chunky.shade(metal)
	for turn = 0, 3 do
		local tooth = Instance.new("Frame")
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.BorderSizePixel = 0
		tooth.BackgroundColor3 = dark
		tooth.Position = UDim2.fromScale(0.5, 0.5)
		tooth.Size = UDim2.fromScale(0.24, 0.84)
		tooth.Rotation = turn * 45
		tooth.ZIndex = 7
		tooth.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = tooth
	end
	local discs: { { share: number, colour: Color3 } } = {
		{ share = 0.62, colour = dark },
		{ share = 0.5, colour = metal },
		{ share = 0.22, colour = Chunky.panelTop },
	}
	for layer, part in discs do
		local disc = Instance.new("Frame")
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.BorderSizePixel = 0
		disc.BackgroundColor3 = part.colour
		disc.Position = UDim2.fromScale(0.5, 0.5)
		disc.Size = UDim2.fromScale(part.share, part.share)
		disc.ZIndex = 7 + layer
		disc.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = disc
	end
end

local function close()
	isOpen = false
	local box = panel
	if box then
		box.Visible = false
		box:ClearAllChildren()
	end
end

local function draw()
	local box = panel
	if not box then
		return
	end
	box:ClearAllChildren()
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local fit = RunHudRules.fit(view, WIDTH, HEIGHT, MARGIN)
	box.Size = UDim2.fromOffset(WIDTH * fit, HEIGHT * fit)

	local sheet = Chunky.pointSheet(box, WIDTH, HEIGHT)
	local w, h = sheet.w, sheet.h
	Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "SETTINGS", 0, 0, w, 104)
	Chunky.close(sheet, 0, 0, 0, close)

	local steps = Config.steps
	local rowH = 128
	local function label(words: string, y: number)
		local t = Chunky.text(box, words, Chunky.ink, 0)
		t.Position = UDim2.fromScale(40 / w, (y + 34) / h)
		t.Size = UDim2.fromScale(270 / w, 56 / h)
		t.TextXAlignment = Enum.TextXAlignment.Left
	end
	local function volume(words: string, name: string, level: number, y: number)
		label(words, y)
		local now = math.floor(level * steps + 0.5)
		Chunky.button(sheet, "-", Chunky.blue, 330, y + 14, 110, 100, function()
			Options.set(name, math.max(0, now - 1) / steps)
		end)
		local pipW, pipGap = 52, 10
		for n = 1, steps do
			local pip = Instance.new("Frame")
			pip.BorderSizePixel = 0
			pip.BackgroundColor3 = if n <= now then Chunky.green else Chunky.trough
			pip.ZIndex = 6
			Chunky.put(sheet, pip, 458 + (n - 1) * (pipW + pipGap), y + 34, pipW, 60)
			Chunky.round(pip, 10)
			Chunky.outline(pip, 4)
		end
		Chunky.button(sheet, "+", Chunky.blue, 726, y + 14, 110, 100, function()
			Options.set(name, math.min(steps, now + 1) / steps)
		end)
	end
	volume("MUSIC", "music", Options.music(), 128)
	volume("SOUND", "sound", Options.sound(), 128 + rowH)
	local shake = Options.haptics()
	label("VIBRATION", 128 + 2 * rowH)
	Chunky.button(
		sheet,
		if shake then "ON" else "OFF",
		if shake then Chunky.green else Chunky.grey,
		330,
		128 + 2 * rowH + 14,
		506,
		100,
		function()
			Options.set("haptics", not shake)
		end
	)

	local codeY = 128 + 3 * rowH
	label("CODES", codeY)
	local field = Instance.new("TextBox")
	field.Name = "CodeBox"
	field.BackgroundColor3 = Chunky.white
	field.BorderSizePixel = 0
	field.ClearTextOnFocus = false
	field.Font = Chunky.font
	field.PlaceholderText = CodeConfig.hint
	field.PlaceholderColor3 = Chunky.grey
	field.Text = typed
	field.TextColor3 = Chunky.ink
	field.TextScaled = true
	field.ZIndex = 30
	Chunky.put(sheet, field, 330, codeY + 14, 316, 100)
	Chunky.round(field, 14)
	Chunky.outline(field, 4)
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft, inset.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	inset.PaddingTop, inset.PaddingBottom = UDim.new(0.2, 0), UDim.new(0.2, 0)
	inset.Parent = field
	field:GetPropertyChangedSignal("Text"):Connect(function()
		if #field.Text > CodeConfig.maxLength then
			field.Text = string.sub(field.Text, 1, CodeConfig.maxLength)
		end
		typed = field.Text
	end)
	Chunky.button(sheet, "REDEEM", Chunky.green, 660, codeY + 14, 176, 100, function()
		if os.clock() - sentAt < PRESS_GAP then
			return
		end
		sentAt = os.clock()
		Remotes.event(Remotes.CodeRedeem):FireServer(typed)
	end)
	if answer ~= "" then
		local said = Chunky.text(box, answer, if answerOk then Chunky.green else Chunky.red, 3)
		said.Position = UDim2.fromScale(40 / w, (codeY + 120) / h)
		said.Size = UDim2.fromScale((w - 80) / w, 44 / h)
	end
	-- the like goal (`Data/LikeGoal`): the next goal and the newest code
	local goal = Workspace:GetAttribute("LikeGoalNext")
	local newest = Workspace:GetAttribute("LikeGoalCode")
	local line = CodeRules.likeLine(
		if type(goal) == "number" then goal else nil,
		if type(newest) == "string" then newest else nil
	)
	if line ~= "" then
		local said = Chunky.text(box, line, Chunky.gold, 3)
		said.Position = UDim2.fromScale(40 / w, (codeY + 176) / h)
		said.Size = UDim2.fromScale((w - 80) / w, 44 / h)
	end
	box.Visible = true
end

local function open()
	if isOpen then
		close()
		return
	end
	isOpen = true
	-- which screens are used (`Data/Analytics.opened`)
	Remotes.event(Remotes.ScreenOpened):FireServer("Settings")
	draw()
	local box = panel
	if box then
		Chunky.pop(box)
	end
end

--[[ Opens the panel, for a look from Studio (a probe cannot press the
     rail button). ]]
function SettingsScreen.preview()
	if not isOpen then
		open()
	end
end

function SettingsScreen.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("SettingsScreen")
	if existing then
		existing:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "SettingsScreen"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 45
	screen.Parent = playerGui

	-- The rail button: a cream tile with a cog, and the word under it.
	local tall = TILE + 16
	local rail = Instance.new("Frame")
	rail.Name = "Button"
	rail.BackgroundTransparency = 1
	rail.Position = UDim2.new(0, LEFT, 0.5, -RISE)
	rail.Size = UDim2.fromOffset(TILE + 8, tall)
	rail.Parent = screen
	local sheet = Chunky.pointSheet(rail, TILE + 8, tall)
	local tile = Chunky.card(sheet, 8, 0, TILE * 2, TILE * 2)
	local picture = Instance.new("Frame")
	picture.BackgroundTransparency = 1
	picture.Position, picture.Size = UDim2.fromScale(0.14, 0.08), UDim2.fromScale(0.72, 0.72)
	picture.ZIndex = 6
	picture.Parent = tile
	cog(picture)
	local word = Chunky.text(rail, "SETTINGS", nil, 5)
	word.Position = UDim2.fromScale(-0.1, TILE * 0.78 / tall)
	word.Size = UDim2.fromScale(1.2, 1 - TILE * 0.78 / tall)
	Chunky.press(rail, open)

	local box = Instance.new("Frame")
	box.Name = "Panel"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Visible = false
	box.ZIndex = 10
	box.Parent = screen
	panel = box

	local function inLobby()
		local lobby = Workspace:GetAttribute("InLobby") == true
		rail.Visible = lobby
		if not lobby then
			close()
		end
	end
	Workspace:GetAttributeChangedSignal("InLobby"):Connect(inLobby)
	inLobby()

	for _, name in { "LikeGoalNext", "LikeGoalCode" } do
		Workspace:GetAttributeChangedSignal(name):Connect(function()
			if isOpen then
				draw()
			end
		end)
	end

	Remotes.event(Remotes.CodeAnswer).OnClientEvent:Connect(function(ok: unknown, words: unknown)
		if type(words) ~= "string" then
			return
		end
		answer, answerOk = words, ok == true
		if answerOk then
			typed = ""
		end
		if isOpen then
			draw()
		end
	end)

	for _, name in { "music", "sound", "haptics" } do
		Options.watch(name, function()
			if isOpen then
				draw()
			end
		end)
	end
end

return SettingsScreen
