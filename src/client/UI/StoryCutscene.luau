--!strict
--[[
	The story cutscene after BEGIN ADVENTURE (owner, 2026-10-25; `Config/Story`):
	King Bloblin in Mossy Glade gets the WANTED poster, roars, and the heroes run
	into the forest; then black, then the run.

	Frame by frame: each shot shows its Codex frames in turn (`Util/StoryTimeline`
	says which, and where the view pans, pushes in or shakes), the whole 16:9
	frame shown as large as fits with black bars round it. One RenderStepped loop
	poses everything from the time since the start, so `StoryCutscene.hold(t)`
	freezes it at a moment for a Studio capture.

	The player stays held (`RunPaused.setStory`) and the server keeps them on the
	title until `finish` runs once the black has held, which asks it to start
	(`Remotes.IntroBegin`, through the callback). SKIP fades to black at once.
	Presentation only.
]]

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Story = require(ReplicatedStorage.Shared.Config.Story)
local StoryTimeline = require(ReplicatedStorage.Shared.Util.StoryTimeline)

local Device = require(script.Parent.Parent.Device)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local StoryCutscene = {}

local FONT = Font.fromEnum(Enum.Font.Arcade)
local INK = Color3.fromRGB(20, 14, 6)
local FACE = Color3.fromRGB(46, 40, 34)
local FACE_HOVER = Color3.fromRGB(78, 70, 60)

local c = Story :: any

type Parts = {
	gui: ScreenGui,
	safe: ScreenGui,
	window: Frame,
	stage: Frame,
	pictures: { [string]: Frame },
	cover: Frame,
	skip: TextButton,
	skipGroup: Frame,
	skipFace: Frame,
}

local parts: Parts? = nil
local startedAt: number? = nil
local skippedAt: number? = nil
local held: number? = nil
local connection: RBXScriptConnection? = nil
local onDone: (() -> ())? = nil
local played: { [number]: boolean } = {}
--[[ The frame on screen, and how long the clock has waited on each frame. ]]
local showing: Frame? = nil
local stalled: { [string]: number } = {}

local function rect(parent: Instance, name: string, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.ZIndex = z
	f.Parent = parent
	return f
end

--[[ Every frame the cutscene shows, once each. ]]
local function pictureNames(): { string }
	local seen, out = {}, {}
	for _, shot in Story.shots do
		for _, frame in shot.frames do
			if not seen[frame.picture] then
				seen[frame.picture] = true
				table.insert(out, frame.picture)
			end
		end
	end
	return out
end

--[[ Starts loading every frame now (while the title is up), so none pops in
     late. ]]
function StoryCutscene.preload()
	local ids = {}
	for _, name in pictureNames() do
		local halves = Story.pictures[name]
		if halves then
			table.insert(ids, halves.left)
			table.insert(ids, halves.right)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(ids)
		end)
	end)
end

local function buildSkip(safe: ScreenGui): (Frame, TextButton, Frame)
	local phone = Device.isPhone()
	local group = Instance.new("Frame")
	group.Name = "Skip"
	group.AnchorPoint = Vector2.new(1, 0)
	group.Position = UDim2.new(1, -16, 0, 16)
	group.Size = UDim2.fromOffset(if phone then 96 else 120, if phone then 40 else 46)
	group.BackgroundTransparency = 1
	group.Visible = false
	group.Parent = safe

	local ink = rect(group, "Ink", INK, 1)
	ink.Size = UDim2.fromScale(1, 1)
	local face = rect(group, "Face", FACE, 2)
	face.Position = UDim2.fromOffset(3, 3)
	face.Size = UDim2.new(1, -6, 1, -6)

	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.Position = UDim2.fromScale(0.5, 0.5)
	words.Size = UDim2.fromScale(0.8, 0.56)
	words.FontFace = FONT
	words.Text = Story.skip .. " >>"
	words.TextColor3 = Color3.new(1, 1, 1)
	words.TextScaled = true
	words.ZIndex = 3
	words.Parent = group

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.AutoButtonColor = false
	button.ZIndex = 5
	button.Parent = group
	return group, button, face
end

local function build(playerGui: PlayerGui): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "StoryCutscene"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	-- under the title (110), which fades away over it, over everything else
	gui.DisplayOrder = 109
	gui.Parent = playerGui

	local safe = Instance.new("ScreenGui")
	safe.Name = "StorySkip"
	safe.ResetOnSpawn = false
	safe.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	safe.DisplayOrder = 109
	safe.Parent = playerGui

	local black = rect(gui, "Black", Color3.new(0, 0, 0), 1)
	black.Size = UDim2.fromScale(1, 1)
	black.Active = true

	local window = rect(gui, "Window", Color3.new(0, 0, 0), 2)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.ClipsDescendants = true

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.ZIndex = 3
	stage.Parent = window

	local p = Story.picture
	local middle = p.width / 2
	local pictures = {}
	for _, name in pictureNames() do
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Visible = false
		holder.ZIndex = 3
		holder.Parent = stage
		local halves = Story.pictures[name]
		for _, side in { "Left", "Right" } do
			local image = Instance.new("ImageLabel")
			image.Name = side
			image.BackgroundTransparency = 1
			image.Image = if halves
				then (if side == "Left" then halves.left else halves.right)
				else ""
			-- each half shows only its own side of the middle, so no seam doubles
			image.ImageRectOffset =
				Vector2.new(if side == "Left" then 0 else middle - p.rightFrom, 0)
			image.ImageRectSize = Vector2.new(middle, p.height)
			image.ZIndex = 3
			image.Parent = holder
		end
		pictures[name] = holder
	end

	local cover = rect(gui, "Cover", Color3.new(0, 0, 0), 10)
	cover.Size = UDim2.fromScale(1, 1)

	local group, button, face = buildSkip(safe)
	return {
		gui = gui,
		safe = safe,
		window = window,
		stage = stage,
		pictures = pictures,
		cover = cover,
		skip = button,
		skipGroup = group,
		skipFace = face,
	}
end

local function finish()
	local callback = onDone
	onDone = nil
	StoryCutscene.stop()
	if callback then
		callback()
	end
end

local function playSounds(t: number)
	if skippedAt then
		return
	end
	local starts = StoryTimeline.starts(c)
	for i, cue in Story.sounds do
		if not played[i] then
			for s, shot in Story.shots do
				if shot.name == cue.shot and t >= starts[s] + cue.at then
					played[i] = true
					SoundFx.play(cue.sound)
				end
			end
		end
	end
end

local function pose(t: number)
	local p = parts
	if not p then
		return
	end
	local now = StoryTimeline.pose(c, t, skippedAt)

	-- the 16:9 frame, as large as fits
	local screen = p.gui.AbsoluteSize
	local source = Story.picture
	local fit = math.min(screen.X / source.width, screen.Y / source.height)
	local winW = math.floor(source.width * fit + 0.5)
	local winH = math.floor(source.height * fit + 0.5)
	p.window.Size = UDim2.fromOffset(winW, winH)
	p.window.Position = UDim2.new(0.5, now.shake.X * screen.Y, 0.5, now.shake.Y * screen.Y)

	local stageW = math.floor(winW * now.zoom + 0.5)
	local stageH = math.floor(winH * now.zoom + 0.5)
	p.stage.Size = UDim2.fromOffset(stageW, stageH)
	p.stage.Position = UDim2.fromOffset(
		-math.floor((stageW - winW) * now.pan + 0.5),
		-math.floor((stageH - winH) / 2 + 0.5)
	)
	local split = math.floor(stageW / 2)
	showing = nil
	for name, holder in p.pictures do
		local on = name == now.picture
		holder.Visible = on
		if on then
			showing = holder
			local left = holder:FindFirstChild("Left") :: ImageLabel
			local right = holder:FindFirstChild("Right") :: ImageLabel
			left.Size = UDim2.fromOffset(split, stageH)
			right.Position = UDim2.fromOffset(split, 0)
			right.Size = UDim2.fromOffset(stageW - split, stageH)
		end
	end

	p.cover.BackgroundTransparency = 1 - now.black

	local skippable = t >= Story.skipAt and not skippedAt and now.black < 1
	p.skipGroup.Visible = skippable
	local hover = p.skip.GuiState == Enum.GuiState.Hover
		or p.skip.GuiState == Enum.GuiState.Press
		or GuiService.SelectedObject == p.skip
	p.skipFace.BackgroundColor3 = if hover then FACE_HOVER else FACE

	if held == nil then
		playSounds(t)
		if now.done then
			finish()
		end
	end
end

-- Seconds since the clock started; 0 while it waits for the frames to load.
local function clock(): number
	local started = startedAt
	return if started then os.clock() - started else 0
end

--[[ Holds on black until every frame has loaded (at most `Story.loadWait`;
     they have been loading since the title came up), so none shows black. ]]
local function startClock(built: Parts)
	local deadline = os.clock() + Story.loadWait
	while os.clock() < deadline and parts == built do
		local ready = true
		for _, holder in built.pictures do
			for _, image in holder:GetChildren() do
				if image:IsA("ImageLabel") and not image.IsLoaded then
					ready = false
				end
			end
		end
		if ready then
			break
		end
		task.wait(0.1)
	end
	if parts ~= built then
		return
	end
	startedAt = os.clock()
	-- a gamepad lands on SKIP once it is up
	task.delay(Story.skipAt, function()
		if parts == built and not skippedAt and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = built.skip
		end
	end)
end

local function skip()
	local t = clock()
	if skippedAt or held or not startedAt or t < Story.skipAt then
		return
	end
	skippedAt = t
	if parts and GuiService.SelectedObject == parts.skip then
		GuiService.SelectedObject = nil
	end
end

--[[ Plays the story from its first frame. `done` runs once, after the black
     has held (or SKIP's has): it asks the server to start the run. ]]
function StoryCutscene.start(done: () -> ())
	if parts then
		return
	end
	onDone = done
	RunPaused.setStory(true)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local built = build(playerGui)
	parts = built
	built.skip.Activated:Connect(skip)
	startedAt = nil
	skippedAt = nil
	played = {}
	stalled = {}
	connection = RunService.RenderStepped:Connect(function(dt: number)
		--[[ A frame still loading holds the clock (at most `Story.stall` on
		     each), so a slow connection pauses briefly rather than showing
		     black. ]]
		local frame = showing
		if frame and held == nil and startedAt and not skippedAt then
			local left = frame:FindFirstChild("Left") :: ImageLabel
			local right = frame:FindFirstChild("Right") :: ImageLabel
			local waited = stalled[frame.Name] or 0
			if (not left.IsLoaded or not right.IsLoaded) and waited < Story.stall then
				stalled[frame.Name] = waited + dt
				startedAt = (startedAt :: number) + dt
			end
		end
		pose(held or clock())
	end)
	pose(0)
	task.spawn(startClock, built)
end

--[[ Studio captures: freeze the cutscene at `t` seconds (nil runs it on). ]]
function StoryCutscene.hold(t: number?)
	held = t
	if t then
		pose(t)
	end
end

function StoryCutscene.stop()
	local p = parts
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if p then
		if GuiService.SelectedObject == p.skip then
			GuiService.SelectedObject = nil
		end
		p.gui:Destroy()
		p.safe:Destroy()
	end
	parts = nil
	startedAt = nil
	showing = nil
	RunPaused.setStory(false)
end

return StoryCutscene
