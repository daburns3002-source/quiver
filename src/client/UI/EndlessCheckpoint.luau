--!strict
--[[
	The Endless checkpoint screen (`docs/ENDLESS.md`, owner 2026-10-27).

	After every boss floor comes a beat with no fight in it. The server sends
	the floor just cleared and the Soulstones banked so far
	(`Remotes.EndlessCheckpoint`) and holds the world; this draws the three
	picks from `Balance.Endless.checkpoint.picks` and BANK & LEAVE beside
	them, and sends back an index (`Remotes.EndlessPick`, 0 to bank).

	Which area comes next is sent too, rather than worked out here: the
	floor schedule is `Run/Waves`, a server module, and it stays one copy on
	one side.

	**The screen decides nothing.** What the picks are is config both sides
	have, what each one does is the server's, and the index is checked
	against a checkpoint the server itself opened
	(`RoomController.endlessPick`) — a client that lies can only take a
	different one of the three it was already allowed to take. The banked
	total is drawn, never trusted: it arrives from the server.

	Bank or push is the mode's one real decision, so the two sides of it are
	drawn apart: the three gifts on their own row, and leaving as a
	deliberately separate, quieter button under them.

	For a Studio capture, set the ScreenGui's `Preview` attribute to a floor
	number to show the screen without the server. Presentation only: a
	preview's pick sends nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)

local RunPaused = require(script.Parent.Parent.RunPaused)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local EndlessCheckpoint = {}

local FONT = Font.fromEnum(Enum.Font.Arcade)

--[[ The blocky palette, as the other screens use it. ]]
local INK = Color3.fromRGB(22, 24, 38)
local PLANK = Color3.fromRGB(44, 48, 70)
local CYAN = Color3.fromRGB(70, 220, 224)
local GOLD = Color3.fromRGB(255, 204, 64)
local WHITE = Color3.fromRGB(240, 236, 220)
local GREY = Color3.fromRGB(130, 134, 152)

--[[ How much of the screen the shade takes, and how long the cards take to
     land. Held here rather than in `Balance` because they are presentation
     only — nothing about them changes an outcome. ]]
local SHADE = 0.55
local ENTER = 0.28

type Card = {
	frame: Frame,
	button: TextButton,
	name: TextLabel,
	words: TextLabel,
}

type Parts = {
	gui: ScreenGui,
	shade: Frame,
	panel: Frame,
	title: TextLabel,
	subtitle: TextLabel,
	cards: { Card },
	bank: TextButton,
	bankLabel: TextLabel,
}

local parts: Parts? = nil
local shownAt = 0
--[[ True while this screen was opened by the server, so a pick answers it;
     a Studio preview's does not. ]]
local fromServer = false
--[[ Set the moment a pick is sent, so a second press cannot send twice. ]]
local sent = false

local function outQuad(x: number): number
	return 1 - (1 - x) ^ 2
end

local function text(name: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Text = ""
	label.Parent = parent
	return label
end

--[[ Sends the pick and closes the screen. `choice` is an index into the
     picks, or 0 to bank and leave. ]]
local function pick(choice: number)
	local p = parts
	if not p or not p.gui.Enabled or sent then
		return
	end
	sent = true
	p.gui.Enabled = false
	RunPaused.setCheckpoint(false)
	SoundFx.play("card_pick")
	if fromServer then
		Remotes.event(Remotes.EndlessPick):FireServer(choice)
	end
end

local function build(playerGui: PlayerGui): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "EndlessCheckpoint"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	--[[ Over the HUD and the card screen (100, 101), under the boss banner
	     (102): a checkpoint has no boss in it, so the two never show
	     together. ]]
	gui.DisplayOrder = 101
	gui.Enabled = false

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.86, 0.62)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	local title = text("Title", panel)
	title.Position = UDim2.fromScale(0, 0)
	title.Size = UDim2.fromScale(1, 0.16)
	title.TextColor3 = CYAN
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = title

	local subtitle = text("Subtitle", panel)
	subtitle.Position = UDim2.fromScale(0, 0.17)
	subtitle.Size = UDim2.fromScale(1, 0.08)
	subtitle.TextColor3 = GOLD

	--[[ The three gifts, evenly across one row. ]]
	local picks = Balance.Endless.checkpoint.picks
	local count = math.max(#picks, 1)
	local gap = 0.03
	local width = (1 - gap * (count - 1)) / count
	local cards: { Card } = {}
	for index = 1, #picks do
		local frame = Instance.new("Frame")
		frame.Name = `Pick{index}`
		frame.Position = UDim2.fromScale((index - 1) * (width + gap), 0.3)
		frame.Size = UDim2.fromScale(width, 0.46)
		frame.BackgroundColor3 = INK
		frame.BorderSizePixel = 0
		frame.Parent = panel

		local face = Instance.new("Frame")
		face.Name = "Face"
		face.Position = UDim2.fromScale(0.03, 0.03)
		face.Size = UDim2.fromScale(0.94, 0.94)
		face.BackgroundColor3 = PLANK
		face.BorderSizePixel = 0
		face.Parent = frame

		local name = text("Name", face)
		name.Position = UDim2.fromScale(0.06, 0.2)
		name.Size = UDim2.fromScale(0.88, 0.26)
		name.TextColor3 = GOLD

		local words = text("Words", face)
		words.Position = UDim2.fromScale(0.06, 0.52)
		words.Size = UDim2.fromScale(0.88, 0.26)
		words.TextWrapped = true

		local button = Instance.new("TextButton")
		button.Name = "Press"
		button.BackgroundTransparency = 1
		button.Size = UDim2.fromScale(1, 1)
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = frame

		cards[index] = { frame = frame, button = button, name = name, words = words }
	end

	--[[ Leaving, under the three and quieter than them: the other half of
	     bank or push, and never something to press by accident. ]]
	local bank = Instance.new("TextButton")
	bank.Name = "Bank"
	bank.AnchorPoint = Vector2.new(0.5, 0)
	bank.Position = UDim2.fromScale(0.5, 0.82)
	bank.Size = UDim2.fromScale(0.4, 0.13)
	bank.BackgroundColor3 = INK
	bank.BorderSizePixel = 0
	bank.Text = ""
	bank.AutoButtonColor = false
	bank.Parent = panel

	local bankLabel = text("Label", bank)
	bankLabel.Size = UDim2.fromScale(1, 1)
	bankLabel.TextColor3 = GREY

	gui.Parent = playerGui
	return {
		gui = gui,
		shade = shade,
		panel = panel,
		title = title,
		subtitle = subtitle,
		cards = cards,
		bank = bank,
		bankLabel = bankLabel,
	}
end

--[[ Fills the screen for a checkpoint after `floor`, with `banked`
     Soulstones paid to this run so far and `area` the area the next floor
     is in — both the server's numbers and words, drawn and never
     recomputed. ]]
local function fill(p: Parts, floor: number, banked: number, area: string)
	p.title.Text = `FLOOR {floor} CLEARED`
	p.subtitle.Text = `{banked} {SaveSchema.SOULSTONES} BANKED · NEXT: {string.upper(area)}`

	local picks = Balance.Endless.checkpoint.picks
	for index, card in p.cards do
		local entry = picks[index]
		card.name.Text = entry.name
		local words = entry.words
		if entry.key == "Shop" then
			-- the bundle's size, so the pick says what it is actually worth
			words = `{Balance.Endless.checkpoint.shopBundle} {SaveSchema.SOULSTONES}`
		end
		card.words.Text = string.upper(words)
	end
	p.bankLabel.Text = "BANK & LEAVE"
end

--[[ Poses the screen from the time since it opened: the shade fades up and
     the panel rises into place. ]]
local function pose(p: Parts, now: number)
	local enter = math.clamp((now - shownAt) / ENTER, 0, 1)
	local eased = outQuad(enter)
	p.shade.BackgroundTransparency = 1 - SHADE * eased
	p.panel.Position = UDim2.fromScale(0.5, 0.56 - 0.06 * eased)
end

function EndlessCheckpoint.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("EndlessCheckpoint")
	if existing then
		existing:Destroy()
	end
	local made = build(playerGui)
	parts = made

	local function open(floor: number, banked: number, area: string, server: boolean)
		fromServer = server
		sent = false
		fill(made, floor, banked, area)
		shownAt = os.clock()
		made.gui.Enabled = true
		RunPaused.setCheckpoint(true)
	end

	for index, card in made.cards do
		card.button.Activated:Connect(function()
			pick(index)
		end)
	end
	made.bank.Activated:Connect(function()
		pick(0)
	end)

	--[[ 1, 2, 3 take a gift and Escape banks, so the screen can be answered
	     without the pointer (a gamepad's D-pad still moves the pointer). ]]
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if not made.gui.Enabled then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.One then
			pick(1)
		elseif key == Enum.KeyCode.Two then
			pick(2)
		elseif key == Enum.KeyCode.Three then
			pick(3)
		end
	end)

	Remotes.event(Remotes.EndlessCheckpoint).OnClientEvent
		:Connect(function(floor: unknown, banked: unknown, area: unknown)
			if type(floor) == "number" and type(banked) == "number" and type(area) == "string" then
				open(floor, banked, area, true)
			end
		end)
	made.gui:GetAttributeChangedSignal("Preview"):Connect(function()
		local floor = made.gui:GetAttribute("Preview")
		if type(floor) == "number" and floor >= 1 then
			open(floor, 0, Balance.Endless.areas[1].name, false)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if made.gui.Enabled then
			pose(made, os.clock())
		end
	end)
end

return EndlessCheckpoint
