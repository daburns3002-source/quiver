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
	--[[ The same frames drawn for a phone held upright (`Story.portraits`),
	     shown instead while the screen is taller than wide. ]]
	portraits: { [string]: Frame },
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
	local view = workspace.CurrentCamera.ViewportSize
	local upright = view.Y > view.X or Device.isPhone()
	for _, name in pictureNames() do
		local halves = Story.pictures[name]
		if halves then
			table.insert(ids, halves.left)
			table.insert(ids, halves.right)
		end
		local tall = Story.portraits[name]
		if tall and upright then
			table.insert(ids, tall.top)
			table.insert(ids, tall.bottom)
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
	for _, half in holder:GetChildren() do
		local copy = if half:IsA("ImageLabel") then warmed[half.Image] else nil
		if copy and not copy.IsLoaded then
			return false
		end
	end
	return true
end

--[[ A frame's two halves side by side (landscape, `Left` and `Right`) or one
     above the other (portrait, `Top` and `Bottom`), each showing only its own
     side of the middle, so no seam doubles. ]]
local function halvesOf(window: Frame, name: string, ids: { string }, portrait: boolean): Frame
	local holder = Instance.new("Frame")
	holder.Name = if portrait then name .. "_Tall" else name
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Visible = false
	holder.ZIndex = 3
	holder.Parent = window
	local source: any = if portrait then Story.portrait else Story.picture
	local sides: { string } = if portrait then { "Top", "Bottom" } else { "Left", "Right" }
	for index, side in sides do
		local image = Instance.new("ImageLabel")
		image.Name = side
		image.BackgroundTransparency = 1
		image.Image = ids[index]
		if portrait then
			local middle = source.height / 2
			image.ImageRectOffset =
				Vector2.new(0, if index == 1 then 0 else middle - source.bottomFrom)
			image.ImageRectSize = Vector2.new(source.width, middle)
		else
			local middle = source.width / 2
			image.ImageRectOffset =
				Vector2.new(if index == 1 then 0 else middle - source.rightFrom, 0)
			image.ImageRectSize = Vector2.new(middle, source.height)
		end
		image.ZIndex = 3
		image.Parent = holder
	end
	return holder
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

	local pictures, portraits = {}, {}
	for _, name in pictureNames() do
		local wide = Story.pictures[name]
		pictures[name] =
			halvesOf(window, name, if wide then { wide.left, wide.right } else { "", "" }, false)
		local tall = Story.portraits[name]
		if tall then
			portraits[name] = halvesOf(window, name, { tall.top, tall.bottom }, true)
		end
	end

	local group, button, face = buildSkip(safe)
	return {
		gui = gui,
		safe = safe,
		window = window,
		pictures = pictures,
		portraits = portraits,
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

	--[[ The frame the clock asks for, in the shape of the screen (a portrait
	     frame while it is taller than wide, if that frame has one), once its
	     warm copies are in; until then the one before it stays up, and on the
	     cut it stays underneath until the new one's own halves are in. Black is
	     only ever the story's own black. ]]
	local screen = p.gui.AbsoluteSize
	local upright = screen.Y > screen.X
	local wanted: Frame? = nil
	local name = now.picture
	if name then
		-- a portrait frame only if it was warmed (the screen was tall when the
		-- title came up); otherwise the landscape one, which always is
		local tall = p.portraits[name]
		if upright and tall and warmed[(tall:FindFirstChild("Top") :: ImageLabel).Image] then
			wanted = tall
		else
			wanted = p.pictures[name]
		end
	end
	if not wanted then
		showing = nil
		under = nil
	elseif wanted ~= showing and loaded(wanted) then
		under = showing
		showing = wanted
	end
	local current = showing
	if current and under then
		local ready = true
		for _, half in current:GetChildren() do
			if half:IsA("ImageLabel") and not half.IsLoaded then
				ready = false
			end
		end
		if ready then
			under = nil
		end
	end

	-- the frame, whole and as large as fits
	local tall = if current then current:FindFirstChild("Top") ~= nil else upright
	local source: any = if tall then Story.portrait else Story.picture
	local fit = math.min(screen.X / source.width, screen.Y / source.height)
	local winW = math.floor(source.width * fit + 0.5)
	local winH = math.floor(source.height * fit + 0.5)
	p.window.Size = UDim2.fromOffset(winW, winH)
	for _, set in { p.pictures, p.portraits } do
		for _, holder in set do
			local on = holder == showing or holder == under
			holder.Visible = on
			holder.ZIndex = if holder == showing then 4 else 3
			if on then
				local first = holder:FindFirstChild(if tall then "Top" else "Left") :: ImageLabel?
				local second =
					holder:FindFirstChild(if tall then "Bottom" else "Right") :: ImageLabel?
				if first and second then
					if tall then
						local split = math.floor(winH / 2)
						first.Size = UDim2.fromOffset(winW, split)
						second.Position = UDim2.fromOffset(0, split)
						second.Size = UDim2.fromOffset(winW, winH - split)
					else
						local split = math.floor(winW / 2)
						first.Size = UDim2.fromOffset(split, winH)
						second.Position = UDim2.fromOffset(split, 0)
						second.Size = UDim2.fromOffset(winW - split, winH)
					end
				end
			end
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
--[[ How far the picture's clock may drift from the music before it is put
     back on it (seconds). ]]
local DRIFT = 0.15

--[[ Seconds since the clock started; 0 while it waits for the frames to load.
     While the music plays the clock follows it (owner, 2026-10-26: "the
     bloblin cutscene audio did not match where the clip was at visually on
     the phone"): when the two drift apart by more than `DRIFT` the clock is
     put back on the music's position, so a phone that starts or stutters the
     music late holds the picture with it. ]]
local function clock(): number
	local started = startedAt
	if not started then
		return 0
	end
	local sound = music
	if sound and sound.IsPlaying and not skippedAt then
		local heard = sound.TimePosition
		if math.abs((os.clock() - started) - heard) > DRIFT then
			started = os.clock() - heard
			startedAt = started
		end
	end
	return os.clock() - started
end

--[[ Holds on black until every frame has loaded (at most `Story.loadWait`;
     they have been loading since the title came up), so none shows black. ]]
local function startClock(built: Parts)
	local deadline = os.clock() + Story.loadWait
	while os.clock() < deadline and parts == built do
		local ready = music == nil or (music :: Sound).IsLoaded
		for _, set in { built.pictures, built.portraits } do
			for _, holder in set do
				if not loaded(holder) then
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
	-- the music's first beat is the clock's first frame (`story_theme.py`); a
	-- track not loaded yet starts where the picture is when it is (`follow`)
	local sound = music
	if sound and sound.IsLoaded then
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
		-- a track that loaded late joins the picture where it is
		if sound and startedAt and not skipped and sound.IsLoaded and not sound.IsPlaying then
			local at = clock()
			if at < sound.TimeLength then
				sound.TimePosition = at
				sound:Play()
			end
		end
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
