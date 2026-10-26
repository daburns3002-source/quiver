--!strict
--[[
	The story cutscene after BEGIN ADVENTURE (owner, 2026-10-25; `Config/Story`):
	King Bloblin in Mossy Glade gets the WANTED poster, roars, and the heroes run
	into the forest; then black, then the run.

	One frame at a time (owner, 2026-10-25): each Codex frame shows once, whole
	and still, as large as fits with black bars round it, then cuts to the next
	(`Util/StoryTimeline` says which); no zoom, pan, shake or fade. One
	RenderStepped loop shows the frame for the time since the start, so
	`StoryCutscene.hold(t)` freezes it at a moment for a Studio capture.

	The player stays held (`RunPaused.setStory`) and the server keeps them on the
	title until `finish` runs once the black has held, which asks it to start
	(`Remotes.IntroBegin`, through the callback). SKIP cuts to black.
	Presentation only.
]]

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Music = require(ReplicatedStorage.Shared.Config.Music)
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
	pictures: { [string]: Frame },
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
--[[ The frame on screen. A frame whose images are not in yet never shows:
     the one before it stays up until they are, so nothing flashes blank. ]]
local showing: Frame? = nil
--[[ The frame before it, kept up underneath until the new one's own halves
     report loaded, so a cut never shows a blank frame even for one frame. ]]
local under: Frame? = nil
--[[ The frames' images, warmed while the title is up (`preload`), and each
     image's warm copy by its id. ]]
local warm: ScreenGui? = nil
local warmed: { [string]: ImageLabel } = {}
--[[ The story's music (`Config/Music.story`), or nil when it has no id. ]]
local music: Sound? = nil
--[[ How long SKIP takes the music down (the picture cuts to black at once). ]]
local MUSIC_OUT = 0.5

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

--[[ Starts loading every frame now, while the title is up, so all are in
     when the story starts. Roblox only loads an image it is drawing (not a
     hidden one, nor a fully transparent one), so each sits in a 2-pixel,
     nearly transparent label on a screen of its own until the story ends;
     the cutscene's own frame, hidden until its turn, then draws at once from
     the cache (owner: "it keeps cutting out and back in" was every frame
     loading only when it came on). ]]
function StoryCutscene.preload()
	if warm then
		return
	end
	local ids = {}
	for _, name in pictureNames() do
		local halves = Story.pictures[name]
		if halves then
			table.insert(ids, halves.left)
			table.insert(ids, halves.right)
		end
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "StoryWarm"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -100
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, id in ids do
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromOffset(2, 2)
		image.ImageTransparency = 0.99
		image.Image = id
		image.Parent = gui
		warmed[id] = image
	end
	warm = gui
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(ids)
		end)
	end)
end

--[[ Whether a frame's two halves are in: their warm copies have loaded
     (an image never warmed counts as in). ]]
local function loaded(holder: Frame): boolean
	for _, side in { "Left", "Right" } do
		local copy = warmed[(holder:FindFirstChild(side) :: ImageLabel).Image]
		if copy and not copy.IsLoaded then
			return false
		end
	end
	return true
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
		holder.Parent = window
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

	local group, button, face = buildSkip(safe)
	return {
		gui = gui,
		safe = safe,
		window = window,
		pictures = pictures,
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
	local split = math.floor(winW / 2)
	--[[ The frame the clock asks for, once both its halves are in; until then
	     the one before it stays up. Black is only ever the story's own black. ]]
	local wanted = if now.picture then p.pictures[now.picture] else nil
	if not wanted then
		showing = nil
		under = nil
	elseif wanted ~= showing and loaded(wanted) then
		under = showing
		showing = wanted
	end
	local current = showing
	if current and under then
		local left = current:FindFirstChild("Left") :: ImageLabel
		local right = current:FindFirstChild("Right") :: ImageLabel
		if left.IsLoaded and right.IsLoaded then
			under = nil
		end
	end
	for _, holder in p.pictures do
		local on = holder == showing or holder == under
		holder.Visible = on
		holder.ZIndex = if holder == showing then 4 else 3
		if on then
			local left = holder:FindFirstChild("Left") :: ImageLabel
			local right = holder:FindFirstChild("Right") :: ImageLabel
			left.Size = UDim2.fromOffset(split, winH)
			right.Position = UDim2.fromOffset(split, 0)
			right.Size = UDim2.fromOffset(winW - split, winH)
		end
	end

	local skippable = t >= Story.skipAt and not skippedAt and now.picture ~= nil
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
		local ready = music == nil or (music :: Sound).IsLoaded
		for _, holder in built.pictures do
			if not loaded(holder) then
				ready = false
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
	-- the music's first beat is the clock's first frame (`story_theme.py`)
	local sound = music
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
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
	showing = nil
	under = nil
	if Music.story.id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Music_Story"
		sound.SoundId = Music.story.id
		sound.Volume = Music.volume
		sound.Parent = SoundService
		music = sound
	end
	connection = RunService.RenderStepped:Connect(function()
		--[[ The clock and the music run on together and never stop (a frame
		     still loading keeps the last one up instead); SKIP takes the music
		     down over `MUSIC_OUT`. ]]
		local sound = music
		local skipped = skippedAt
		if sound and skipped then
			sound.Volume = Music.volume * math.max(0, 1 - (clock() - skipped) / MUSIC_OUT)
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
	under = nil
	if warm then
		warm:Destroy()
		warm = nil
		table.clear(warmed)
	end
	local sound = music
	music = nil
	if sound then
		-- the last chord rings on into the lobby rather than cutting off
		local left = if sound.IsPlaying then sound.TimeLength - sound.TimePosition else 0
		task.delay(math.clamp(left, 0, 3), function()
			sound:Destroy()
		end)
	end
	RunPaused.setStory(false)
end

return StoryCutscene
