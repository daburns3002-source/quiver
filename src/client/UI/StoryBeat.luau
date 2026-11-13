--!strict
--[[
	A story beat (`Config/StoryBeats`): what a boss's first defeat uncovered,
	in four Codex stills that pan and zoom slowly, each with its words on a
	panel under it, the last the next boss's WANTED poster.

	The run's summary says which beat a win owes (`owe`, from
	`Remotes.RunSummary`'s `story`), and its pictures load then, while
	Victory is up. When the player leaves Victory, `after` plays the beat
	first and then does what they pressed (NEXT, RETRY or LOBBY), under the
	black at its end. A tap (click, A, Return, Space) moves on once a still
	has been up `tapAfter`; SKIP (or a gamepad's B) ends it. Watched or
	skipped, the server is told (`Remotes.StorySeen`), so it plays once.
	Presentation only.
]]

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local StoryBeatRules = require(ReplicatedStorage.Shared.Util.StoryBeatRules)
local StoryBeats = require(ReplicatedStorage.Shared.Config.StoryBeats)
local UiPalette = require(ReplicatedStorage.Shared.Config.UiPalette)

local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local StoryBeat = {}

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local ASPECT = 16 / 9

type Layer = { frame: Frame, picture: Frame, halves: { ImageLabel } }
type Parts = {
	gui: ScreenGui,
	safe: ScreenGui,
	black: Frame,
	window: Frame,
	layers: { Layer },
	panel: Frame,
	panelScale: UIScale,
	words: TextLabel,
	sub: TextLabel,
	hint: TextLabel,
	skip: TextButton,
	skipGroup: Frame,
	tap: TextButton,
}

--[[ The beat the last summary owed, nil when none. ]]
local owed: string? = nil
local parts: Parts? = nil
local connections: { RBXScriptConnection } = {}
--[[ Studio captures: the beat's clock frozen at this many seconds. ]]
local held: number? = nil

local function idsOf(still: StoryBeats.Still): { string }
	local wide = StoryBeats.pictures[still.picture]
	return if wide then { wide.left, wide.right } else {}
end

--[[ The beat `area` owes is up next (nil for none), and its pictures load
     now, behind Victory. ]]
function StoryBeat.owe(area: string?)
	owed = if area and StoryBeats.beats[area] then area else nil
	if owed then
		local images: { string } = {}
		for _, still in StoryBeats.beats[owed].stills do
			for _, id in idsOf(still) do
				table.insert(images, id)
			end
		end
		task.spawn(function()
			ContentProvider:PreloadAsync(images)
		end)
	end
end

local function rect(parent: Instance, name: string, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, colour: Color3, z: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.TextColor3 = colour
	t.TextWrapped = true
	t.ZIndex = z
	t.Parent = parent
	return t
end

local function layer(window: Frame, i: number): Layer
	local frame = Instance.new("Frame")
	frame.Name = "Still" .. i
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = i
	frame.Parent = window
	local picture = Instance.new("Frame")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ZIndex = i
	picture.Parent = frame
	local source = StoryBeats.picture
	local middle = source.width / 2
	local halves = {}
	for index, side in { "Left", "Right" } do
		local image = Instance.new("ImageLabel")
		image.Name = side
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.ImageRectOffset = Vector2.new(if index == 1 then 0 else middle - source.rightFrom, 0)
		image.ImageRectSize = Vector2.new(middle, source.height)
		-- a hair over half, so no seam shows between them
		image.Position = UDim2.fromScale(if index == 1 then 0 else 0.4995, 0)
		image.Size = UDim2.fromScale(0.5005, 1)
		image.ZIndex = i
		image.Parent = picture
		halves[index] = image
	end
	return { frame = frame, picture = picture, halves = halves }
end

local function build(): Parts
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "StoryBeat"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- over Victory (130), under the reveals (140)
	gui.DisplayOrder = 135
	gui.Parent = playerGui

	local safe = Instance.new("ScreenGui")
	safe.Name = "StoryBeatSkip"
	safe.ResetOnSpawn = false
	safe.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	safe.DisplayOrder = 136
	safe.Parent = playerGui

	local black = rect(gui, "Black", Color3.new(0, 0, 0), 1)
	black.Size = UDim2.fromScale(1, 1)
	black.Active = true

	local window = rect(gui, "Window", Color3.new(0, 0, 0), 2)
	window.ClipsDescendants = true
	local layers = { layer(window, 1), layer(window, 2) }

	local panel = rect(gui, "Words", UiPalette.white, 3)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(UiPalette.panelTop, UiPalette.panelBottom)
	gradient.Rotation = 90
	gradient.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = UiPalette.edge
	stroke.Thickness = 4
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = panel
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local words = label(panel, "Line", UiPalette.ink, 4)
	words.LayoutOrder = 1
	words.Size = UDim2.fromScale(1, 0)
	words.AutomaticSize = Enum.AutomaticSize.Y
	local sub = label(panel, "Sub", UiPalette.inkSoft, 4)
	sub.LayoutOrder = 2
	sub.Size = UDim2.fromScale(1, 0)
	sub.AutomaticSize = Enum.AutomaticSize.Y
	local hint = label(panel, "Hint", UiPalette.inkSoft, 4)
	hint.LayoutOrder = 3
	hint.Size = UDim2.fromScale(1, 0)
	hint.AutomaticSize = Enum.AutomaticSize.Y
	hint.TextXAlignment = Enum.TextXAlignment.Right

	-- the whole screen is the tap that moves on (SKIP sits over it, on its own gui)
	local tapButton = Instance.new("TextButton")
	tapButton.Name = "Tap"
	tapButton.BackgroundTransparency = 1
	tapButton.Size = UDim2.fromScale(1, 1)
	tapButton.Text = ""
	tapButton.AutoButtonColor = false
	tapButton.Selectable = false
	tapButton.ZIndex = 10
	tapButton.Parent = gui

	local skipGroup = Instance.new("Frame")
	skipGroup.Name = "Skip"
	skipGroup.AnchorPoint = Vector2.new(1, 0)
	skipGroup.Position = UDim2.new(1, -16, 0, 16)
	skipGroup.Size = UDim2.fromOffset(112, 44)
	skipGroup.BackgroundColor3 = UiPalette.off.top
	skipGroup.Visible = false
	skipGroup.Parent = safe
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skipGroup
	local skipEdge = Instance.new("UIStroke")
	skipEdge.Color = UiPalette.off.edge
	skipEdge.Thickness = 3
	skipEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	skipEdge.Parent = skipGroup
	local skip = Instance.new("TextButton")
	skip.Name = "Button"
	skip.BackgroundTransparency = 1
	skip.Size = UDim2.fromScale(1, 1)
	skip.FontFace = FONT
	skip.Text = StoryBeats.skip .. " >>"
	skip.TextColor3 = UiPalette.off.text
	skip.TextSize = 22
	skip.AutoButtonColor = false
	skip.Parent = skipGroup
	local skipWords = Instance.new("UIStroke")
	skipWords.Color = UiPalette.off.stroke or UiPalette.edge
	skipWords.Thickness = 2
	skipWords.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	skipWords.Parent = skip

	return {
		gui = gui,
		safe = safe,
		black = black,
		window = window,
		layers = layers,
		panel = panel,
		panelScale = panelScale,
		words = words,
		sub = sub,
		hint = hint,
		skip = skip,
		skipGroup = skipGroup,
		tap = tapButton,
	}
end

--[[ The window as large as fits at 16:9; the words over its foot, or under
     it when the screen has room below (a phone held upright). ]]
local function lay(p: Parts)
	local screen = p.gui.AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end
	local w = math.min(screen.X, screen.Y * ASPECT)
	local h = w / ASPECT
	local tall = screen.Y > screen.X
	local top = if tall then math.max(0, screen.Y * 0.42 - h / 2) else (screen.Y - h) / 2
	p.window.Position = UDim2.fromOffset((screen.X - w) / 2, top)
	p.window.Size = UDim2.fromOffset(w, h)

	local short = math.min(screen.X, screen.Y)
	local size = math.clamp(math.floor(short * 0.055), 18, 40)
	p.words.TextSize = size
	p.sub.TextSize = math.max(14, math.floor(size * 0.72))
	p.hint.TextSize = math.max(12, math.floor(size * 0.5))
	local width = math.min(w * 0.86, 920, screen.X - 32)
	p.panel.Size = UDim2.fromOffset(width, 0)
	local room = screen.Y - (top + h)
	local below = room >= size * 4.5
	p.panel.Position = if below
		then UDim2.fromOffset(screen.X / 2, top + h + 16)
		else UDim2.new(0.5, 0, 0, top + h - math.max(size * 3.6, h * 0.24))
end

local function playing(): boolean
	return parts ~= nil
end

local function hintWords(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return StoryBeats.hints.touch
	end
	if string.find(last.Name, "^Gamepad") then
		return StoryBeats.hints.gamepad
	end
	return StoryBeats.hints.mouse
end

--[[ Plays `area`'s beat now; `done` runs once, as the black at its end
     comes down (watched, tapped through or skipped). ]]
function StoryBeat.play(area: string, done: () -> ())
	local beat = StoryBeats.beats[area]
	if not beat or parts then
		done()
		return
	end
	local p = build()
	parts = p
	held = nil
	lay(p)
	table.insert(
		connections,
		p.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			lay(p)
		end)
	)
	if GuiService.SelectedObject then
		GuiService.SelectedObject = nil
	end

	local stills = beat.stills
	local startedAt = os.clock()
	local function now(): number
		return held or (os.clock() - startedAt)
	end
	--[[ The still showing and when it came in; each layer's still and start. ]]
	local index = 0
	local shownAt = 0
	local layerStill: { StoryBeats.Still? } = { nil, nil }
	local layerAt = { 0, 0 }
	local ending: number? = nil
	local finished = false

	local function finish()
		if finished then
			return
		end
		finished = true
		Remotes.event(Remotes.StorySeen):FireServer(area)
		task.spawn(done)
	end

	local function show(i: number, at: number)
		index = i
		shownAt = at
		local still = stills[i]
		local slot = if i % 2 == 1 then 1 else 2
		local l = p.layers[slot]
		local ids = idsOf(still)
		for n, image in l.halves do
			image.Image = ids[n] or ""
			image.ImageTransparency = 1
		end
		l.frame.ZIndex = 10 + i
		layerStill[slot] = still
		layerAt[slot] = at
		p.panel.Visible = false
		if still.sound then
			SoundFx.play(still.sound)
		end
	end

	local function nextStill(at: number)
		if index >= #stills then
			if not ending then
				ending = at
			end
			return
		end
		show(index + 1, at)
	end

	local function tap()
		local t = now()
		if ending or index == 0 or t - shownAt < StoryBeats.tapAfter then
			return
		end
		nextStill(t)
	end

	local function skip()
		if ending or now() < StoryBeats.skipAt then
			return
		end
		ending = now()
	end

	table.insert(connections, p.skip.Activated:Connect(skip))
	table.insert(connections, p.tap.Activated:Connect(tap))
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input)
			local key = input.KeyCode
			if key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Escape then
				skip()
			elseif
				key == Enum.KeyCode.ButtonA
				or key == Enum.KeyCode.Return
				or key == Enum.KeyCode.Space
			then
				tap()
			end
		end)
	)

	local finishedAt: number? = nil
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local t = now()
			if index == 0 and t >= StoryBeats.lead then
				show(1, StoryBeats.lead)
			elseif index > 0 and not ending and t - shownAt >= stills[index].hold then
				nextStill(shownAt + stills[index].hold)
			end

			-- each layer's picture along its move, the newer dissolving in
			for slot, l in p.layers do
				local still = layerStill[slot]
				if still then
					local since = t - layerAt[slot]
					local pos, size =
						StoryBeatRules.place(still, since / (still.hold + StoryBeats.dissolve))
					l.picture.Position = UDim2.fromScale(pos.X, pos.Y)
					l.picture.Size = UDim2.fromScale(size.X, size.Y)
					local isCurrent = index > 0 and still == stills[index]
					local fade = if isCurrent
						then math.clamp(since / StoryBeats.dissolve, 0, 1)
						else 1
					for _, image in l.halves do
						image.ImageTransparency = 1 - fade
					end
				end
			end

			-- the words, a beat after their still
			if index > 0 and not ending then
				local still = stills[index]
				local since = t - shownAt - StoryBeats.wordsAfter
				if since >= 0 then
					if not p.panel.Visible then
						p.words.Text = still.words
						p.words.TextColor3 = if still.poster
							then UiPalette.action.bottom
							else UiPalette.ink
						p.sub.Text = still.sub or ""
						p.sub.Visible = still.sub ~= nil
						p.hint.Text = hintWords()
						p.panel.Visible = true
					end
					local k = math.clamp(since / StoryBeats.wordsIn, 0, 1)
					p.panelScale.Scale = 0.9 + 0.1 * (1 - (1 - k) ^ 2)
					p.panel.BackgroundTransparency = 0
					p.hint.Visible = t - shownAt >= StoryBeats.tapAfter
				end
			end
			p.skipGroup.Visible = not ending and t >= StoryBeats.skipAt

			-- the end: everything under black, then what the player pressed
			if ending then
				p.panel.Visible = false
				local k = math.clamp((t - ending) / StoryBeats.tail, 0, 1)
				for _, l in p.layers do
					for _, image in l.halves do
						image.ImageTransparency = math.max(image.ImageTransparency, k)
					end
				end
				if k >= 1 and not finishedAt then
					finishedAt = t
					finish()
				end
				-- the black lifts once the lobby (or the next run) is under it
				if finishedAt then
					local lift = math.clamp((t - finishedAt - 0.6) / 0.4, 0, 1)
					p.black.BackgroundTransparency = lift
					p.window.BackgroundTransparency = 1
					if lift >= 1 then
						StoryBeat.stop()
					end
				end
			end
		end)
	)
end

--[[ Does `action` once the owed beat (if any) has played; with none owed,
     at once. A second press while a beat plays is dropped. ]]
function StoryBeat.after(action: () -> ())
	if playing() then
		return
	end
	local area = owed
	owed = nil
	if not area then
		action()
		return
	end
	StoryBeat.play(area, action)
end

--[[ Studio captures: freeze the playing beat at `t` seconds (nil runs on). ]]
function StoryBeat.hold(t: number?)
	held = t
end

function StoryBeat.stop()
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
	local p = parts
	parts = nil
	if p then
		p.gui:Destroy()
		p.safe:Destroy()
	end
end

return StoryBeat
