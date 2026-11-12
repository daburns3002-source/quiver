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

	Drawn in the chunky kit (`UI/Chunky`; the owner's UI reference of
	2026-11-11): a cream panel with the floor on its header, each gift a
	tile in its own colour that bounces under the thumb, and BANK & LEAVE a
	smaller blue button under them. Sized in screen points and fitted to
	the screen (`RunHudRules.fit`), so a phone held upright can read and
	press it.

	For a Studio capture, set the ScreenGui's `Preview` attribute to a floor
	number to show the screen without the server. Presentation only: a
	preview's pick sends nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunHudRules = require(ReplicatedStorage.Shared.Util.RunHudRules)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)

local Chunky = require(script.Parent.Chunky)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local EndlessCheckpoint = {}

--[[ The panel, in points, and how clear of the screen's edges it stays. ]]
local WIDTH = 560
local HEIGHT = 380
local MARGIN = 12
--[[ Each gift's colour, by its key in `Balance.Endless.checkpoint.picks`. ]]
local TONES: { [string]: Color3 } = {
	Heal = Chunky.green,
	Card = Chunky.gold,
	Shop = Chunky.purple,
}

--[[ How much of the screen the shade takes, and how long the cards take to
     land. Held here rather than in `Balance` because they are presentation
     only — nothing about them changes an outcome. ]]
local SHADE = 0.55
local ENTER = 0.28

type Card = {
	frame: Frame,
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
	bank: Frame,
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
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
	panel.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	panel.BackgroundTransparency = 1
	panel.Parent = gui
	local sheet = Chunky.pointSheet(panel, WIDTH, HEIGHT)
	local w, h = sheet.w, sheet.h
	local body = Chunky.panel(sheet, 0, 0, w, h - 12)
	Chunky.ribbon(sheet, "FLOOR CLEARED", 0, 0, w, 110)
	local title = body:FindFirstChild("Title", true) :: TextLabel
	title.Size = UDim2.fromScale(0.94, 0.66)

	local subtitle = Chunky.text(panel, "", Chunky.ink, 0)
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.fromScale(0.04, 124 / h)
	subtitle.Size = UDim2.fromScale(0.92, 44 / h)

	--[[ The three gifts, evenly across one row, each a tile in its colour. ]]
	local picks = Balance.Endless.checkpoint.picks
	local count = math.max(#picks, 1)
	local pad, gap = 36, 22
	local width = (w - 2 * pad - (count - 1) * gap) / count
	local cards: { Card } = {}
	for index, entry in picks do
		local tone = TONES[entry.key] or Chunky.blue
		local frame = Instance.new("Frame")
		frame.Name = `Pick{index}`
		frame.BackgroundTransparency = 1
		frame.ZIndex = 5
		Chunky.put(sheet, frame, pad + (index - 1) * (width + gap), 188, width, 330)
		local tile = Instance.new("Frame")
		tile.Name = "Tile"
		tile.BorderSizePixel = 0
		tile.BackgroundColor3 = Color3.new(1, 1, 1)
		tile.Size = UDim2.fromScale(1, 1)
		tile.ZIndex = 5
		tile.Parent = frame
		local light = Instance.new("UIGradient")
		light.Rotation = 90
		light.Color = ColorSequence.new(tone:Lerp(Color3.new(1, 1, 1), 0.4), tone)
		light.Parent = tile
		Chunky.round(tile, 20)
		Chunky.outline(tile, 7, Chunky.shade(tone))

		--[[ Its number, for the keys 1, 2 and 3. ]]
		local key = Chunky.text(tile, tostring(index), nil, 5, Chunky.shade(tone))
		key.Position, key.Size = UDim2.fromScale(0.36, 0.06), UDim2.fromScale(0.28, 0.2)
		local name = Chunky.text(tile, "", nil, 6, Chunky.shade(tone))
		name.Name = "Name"
		name.Position, name.Size = UDim2.fromScale(0.06, 0.3), UDim2.fromScale(0.88, 0.26)
		local words = Chunky.text(tile, "", nil, 4, Chunky.shade(tone))
		words.Name = "Words"
		words.Position, words.Size = UDim2.fromScale(0.08, 0.6), UDim2.fromScale(0.84, 0.3)
		words.TextWrapped = true

		Chunky.press(frame, function()
			pick(index)
		end)
		cards[index] = { frame = frame, name = name, words = words }
	end

	--[[ Leaving, under the three and quieter than them: the other half of
	     bank or push, and never something to press by accident. ]]
	local bank = Chunky.button(
		sheet,
		"BANK & LEAVE",
		Chunky.blue,
		w / 2 - 250,
		556,
		500,
		110,
		function()
			pick(0)
		end
	)

	gui.Parent = playerGui
	return {
		gui = gui,
		shade = shade,
		panel = panel,
		title = title,
		subtitle = subtitle,
		cards = cards,
		bank = bank,
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
	--[[ Fitted to the screen it is on now. ]]
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local fit = RunHudRules.fit(view, WIDTH, HEIGHT, MARGIN)
	p.panel.Size = UDim2.fromOffset(WIDTH * fit, HEIGHT * fit)
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

	--[[ 1, 2, 3 take a gift, so the screen can be answered without the pointer
	     (a gamepad's D-pad still moves the pointer). Banking takes the pointer:
	     Roblox keeps Escape for its own menu. ]]
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
