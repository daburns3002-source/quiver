--!strict
--[[
	The intro cutscene as the game starts (owner, 2026-10-25; `Config/Intro`),
	after Pixel Lineage's intro: a black screen where DYL.DEVS PRESENTS fades
	in in dark gold, then, on the intro music's hit at 5.0 s, a cut to the
	full-screen title picture (Codex, the owner's pick A, its logo painted
	in), which stands still once it is up (owner: "the screen should not
	move at all after it fully appears"),
	with a big BEGIN ADVENTURE button at the bottom.

	The music (`Config/Music.intro`) starts on the cutscene's first frame,
	which waits on the black screen until the track has loaded, so its hit
	lands on the cut;
	the run's own music waits (`MusicFx.setQuiet`). The player is held
	still (`RunPaused.setTitle`) and the server holds the world until the
	press, which asks it to start (`Remotes.IntroBegin`) and fades the title
	away as the room's music comes in.

	One RenderStepped loop poses everything from the time since the start
	(`Util/IntroTimeline`), so `IntroCutscene.hold(t)` can freeze it at a
	moment for a Studio capture. Presentation only.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Intro = require(ReplicatedStorage.Shared.Config.Intro)
local IntroTimeline = require(ReplicatedStorage.Shared.Util.IntroTimeline)
local Music = require(ReplicatedStorage.Shared.Config.Music)

local Device = require(script.Parent.Parent.Device)
local RunPaused = require(script.Parent.Parent.RunPaused)

local IntroCutscene = {}

local FONT = Font.fromEnum(Enum.Font.Arcade)
local INK = Color3.fromRGB(20, 14, 6)
local SHINE = Color3.fromRGB(140, 222, 110)
local FOOT = Color3.fromRGB(40, 120, 34)
local STUD = Color3.fromRGB(255, 210, 63)

type Parts = {
	gui: ScreenGui,
	safe: ScreenGui,
	black: Frame,
	presents: TextLabel,
	presentsSub: TextLabel,
	presentsScale: UIScale,
	picture: Frame,
	backdrop: Frame,
	shade: Frame,
	flash: Frame,
	button: TextButton,
	buttonGroup: Frame,
	buttonScale: UIScale,
	buttonFace: { Frame },
	buttonWords: TextLabel,
}

local parts: Parts? = nil
local music: Sound? = nil
--[[ When the clock started (os.clock), or nil while the black screen
     waits for the music to load. ]]
local startedAt: number? = nil
local pressedAt: number? = nil
local held: number? = nil
local connection: RBXScriptConnection? = nil
local onBegin: (() -> ())? = nil

--[[ Whether this play skips the intro: in Studio only, by the `SkipIntro`
     attribute on Workspace (the server reads the same one). ]]
function IntroCutscene.skipped(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute("SkipIntro") == true
end

local function rect(parent: Instance, name: string, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.ZIndex = z
	f.Parent = parent
	return f
end

--[[ A block with stepped corners: a wide bar and a tall bar, `step` (a
     share of the height) in from the edges, as the end screens' blocks. ]]
local function stepped(parent: Instance, name: string, colour: Color3, z: number, step: number)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = z
	holder.Parent = parent
	local wide = rect(holder, "Wide", colour, z)
	wide.Position = UDim2.fromScale(0, step)
	wide.Size = UDim2.fromScale(1, 1 - 2 * step)
	-- inset across by the same pixels as down, so the steps are square
	local tall = rect(holder, "Tall", colour, z)
	local function fit()
		local px = math.floor(holder.AbsoluteSize.Y * step + 0.5)
		tall.Position = UDim2.fromOffset(px, 0)
		tall.Size = UDim2.new(1, -2 * px, 1, 0)
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return holder
end

type ButtonParts = {
	group: Frame,
	button: TextButton,
	scale: UIScale,
	face: { Frame },
	words: TextLabel,
}

local function buildButton(safe: ScreenGui): ButtonParts
	local phone = Device.isPhone()
	local group = Instance.new("Frame")
	group.Name = "BeginAdventure"
	group.AnchorPoint = Vector2.new(0.5, 1)
	group.Position = UDim2.new(0.5, 0, 1, -16)
	group.Size = UDim2.fromScale(if phone then 0.5 else 0.3, 1)
	group.BackgroundTransparency = 1
	group.ZIndex = 20
	group.Parent = safe
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 5.2
	ratio.Parent = group
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(560, 108)
	size.Parent = group
	local scale = Instance.new("UIScale")
	scale.Parent = group

	stepped(group, "Ink", INK, 20, 0.12)
	local face = Instance.new("Frame")
	face.Name = "FaceHolder"
	face.BackgroundTransparency = 1
	face.Position = UDim2.fromScale(0.012, 0.06)
	face.Size = UDim2.fromScale(0.976, 0.88)
	face.ZIndex = 21
	face.Parent = group
	local faceBlock = stepped(face, "Face", Intro.buttonColour, 21, 0.1)
	local foot = rect(face, "Foot", FOOT, 22)
	foot.Position = UDim2.fromScale(0.03, 0.78)
	foot.Size = UDim2.fromScale(0.94, 0.12)
	local shine = rect(face, "Shine", SHINE, 22)
	shine.Position = UDim2.fromScale(0.06, 0.12)
	shine.Size = UDim2.fromScale(0.88, 0.07)
	-- four gold studs, as on the end screens' button
	for _, at in { { 0.04, 0.2 }, { 0.96, 0.2 }, { 0.04, 0.66 }, { 0.96, 0.66 } } do
		local stud = rect(face, "Stud", STUD, 23)
		stud.AnchorPoint = Vector2.new(0.5, 0)
		stud.Position = UDim2.fromScale(at[1], at[2])
		stud.Size = UDim2.fromScale(0.022, 0.13)
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = stud
	end

	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.Position = UDim2.fromScale(0.5, 0.47)
	words.Size = UDim2.fromScale(0.86, 0.5)
	words.FontFace = FONT
	words.Text = Intro.button
	words.TextColor3 = Intro.buttonText
	words.TextScaled = true
	words.ZIndex = 24
	words.Parent = face
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = if phone then 3 else 4
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = words
	-- a hard blocky shadow under the words, so they read on the green
	local shadow = words:Clone()
	shadow.Name = "Shadow"
	shadow.TextColor3 = INK
	shadow.Position = UDim2.new(0.5, 0, 0.47, if phone then 3 else 4)
	shadow.ZIndex = 23
	shadow.Parent = face

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.AutoButtonColor = false
	button.ZIndex = 30
	button.Parent = group
	local blocks = {}
	for _, block in faceBlock:GetChildren() do
		if block:IsA("Frame") then
			table.insert(blocks, block)
		end
	end
	return { group = group, button = button, scale = scale, face = blocks, words = words }
end

local function build(playerGui: PlayerGui): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroCutscene"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- over everything, the notch and the corners too
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 110
	gui.Parent = playerGui

	-- the button stays inside the device's safe area
	local safe = Instance.new("ScreenGui")
	safe.Name = "IntroButton"
	safe.ResetOnSpawn = false
	safe.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	safe.DisplayOrder = 111
	safe.Parent = playerGui

	local black = rect(gui, "Black", Color3.new(0, 0, 0), 1)
	black.Size = UDim2.fromScale(1, 1)
	black.Active = true

	local presents = Instance.new("TextLabel")
	presents.Name = "Presents"
	presents.BackgroundTransparency = 1
	presents.AnchorPoint = Vector2.new(0.5, 0.5)
	presents.Position = UDim2.fromScale(0.5, 0.5)
	presents.Size = UDim2.fromScale(if Device.isPhone() then 0.84 else 0.6, 0.08)
	presents.FontFace = FONT
	presents.Text = Intro.presents
	presents.TextColor3 = Intro.presentsColour
	presents.TextScaled = true
	presents.TextTransparency = 1
	presents.ZIndex = 10
	presents.Parent = gui
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 56
	fit.Parent = presents
	local presentsScale = Instance.new("UIScale")
	presentsScale.Parent = presents
	-- PRESENTS, smaller and white, under DYL.DEVS
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.fromScale(0.5, 1.25)
	sub.Size = UDim2.fromScale(0.5, 0.5)
	sub.FontFace = FONT
	sub.Text = Intro.presentsSub
	sub.TextColor3 = Intro.presentsSubColour
	sub.TextScaled = true
	sub.TextTransparency = 1
	sub.ZIndex = 10
	sub.Parent = presents
	local subFit = Instance.new("UITextSizeConstraint")
	subFit.MaxTextSize = 26
	subFit.Parent = sub

	--[[ The whole picture shows at the screen's height, so neither the logo
	     at its top nor the heroes at its bottom are ever cut off; on a screen
	     wider than it (most computers and phones), the bars at its sides are
	     the same picture stretched to cover and darkened. ]]
	local p = Intro.picture
	--[[ The halves meet at the source's middle, each showing only its own
	     side of it (the overlap is cut off by `ImageRect`), so they never
	     double up where they meet as they fade. `pose` sizes them in whole
	     pixels so no hairline shows between them. ]]
	local middle = p.width / 2
	local function halves(name: string, z: number): Frame
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.BackgroundTransparency = 1
		holder.Visible = false
		holder.ZIndex = z
		holder.Parent = gui
		for _, side in { "left", "right" } do
			local image = Instance.new("ImageLabel")
			image.Name = if side == "left" then "Left" else "Right"
			image.BackgroundTransparency = 1
			image.Image = (p :: any)[side]
			image.ImageRectOffset =
				Vector2.new(if side == "left" then 0 else middle - p.rightFrom, 0)
			image.ImageRectSize = Vector2.new(middle, p.height)
			image.ZIndex = z
			image.Parent = holder
		end
		return holder
	end
	local backdrop = halves("Backdrop", 1)
	local dim = rect(backdrop, "Dim", Color3.new(0, 0, 0), 2)
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundTransparency = Intro.sidesDim
	dim.ZIndex = 2
	local picture = halves("Picture", 3)

	-- the bottom darkens a little under the button
	local shade = rect(gui, "Shade", Color3.new(0, 0, 0), 6)
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.fromScale(0, 1)
	shade.Size = UDim2.fromScale(1, 0.3)
	shade.Visible = false
	local shadeFade = Instance.new("UIGradient")
	shadeFade.Rotation = 90
	shadeFade.Transparency = NumberSequence.new(1, 0.45)
	shadeFade.Parent = shade

	local flash = rect(gui, "Flash", Color3.new(1, 1, 1), 15)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1

	local made = buildButton(safe)
	made.group.Visible = false

	return {
		gui = gui,
		safe = safe,
		black = black,
		presents = presents,
		presentsSub = sub,
		presentsScale = presentsScale,
		picture = picture,
		backdrop = backdrop,
		shade = shade,
		flash = flash,
		button = made.button,
		buttonGroup = made.group,
		buttonScale = made.scale,
		buttonFace = made.face,
		buttonWords = made.words,
	}
end

-- Seconds since the cutscene's clock started; 0 while it waits to.
local function clock(): number
	local started = startedAt
	return if started then os.clock() - started else 0
end

--[[ The intro's music, loaded but not playing yet, or nil when it has no
     id. ]]
local function loadMusic(): Sound?
	local track = Music.intro
	if track.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music_Intro"
	sound.SoundId = track.id
	sound.Volume = Music.volume
	local from, to = track.loopStart, track.loopEnd
	sound.PlaybackRegionsEnabled = from ~= nil and to ~= nil
	if from and to then
		sound.LoopRegion = NumberRange.new(from, to)
	end
	sound.Looped = true
	sound.Parent = SoundService
	music = sound
	return sound
end

--[[ Holds on the black screen until the music has loaded (at most
     `Intro.musicWait`), so its hit lands on the cut, then starts the clock
     and the music on the same frame. ]]
local function startClock(built: Parts)
	local sound = loadMusic()
	if sound and not sound.IsLoaded then
		local deadline = os.clock() + Intro.musicWait
		while not sound.IsLoaded and os.clock() < deadline and parts == built do
			task.wait()
		end
	end
	if parts ~= built then
		return
	end
	startedAt = os.clock()
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
	-- a gamepad lands on the button once it is up
	task.delay(Intro.buttonAt, function()
		if parts == built and not pressedAt then
			GuiService.SelectedObject = built.button
		end
	end)
end

local function fadeMusic(level: number)
	local sound = music
	if sound then
		sound.Volume = Music.volume * level
	end
end

local function pose(t: number)
	local p = parts
	if not p then
		return
	end
	local now = IntroTimeline.pose(Intro :: any, t, pressedAt)
	local fade = 1 - now.shown

	p.presents.TextTransparency = 1 - now.presents
	p.presentsSub.TextTransparency = 1 - now.presents
	p.presentsScale.Scale = now.presentsScale
	p.black.BackgroundTransparency = if now.revealed then 1 else fade

	local size = p.gui.AbsoluteSize
	local c = Intro.picture
	local function place(holder: Frame, scale: number)
		local wide = math.floor(c.width * scale + 0.5)
		local tall = math.floor(c.height * scale + 0.5)
		holder.Visible = now.revealed
		holder.Size = UDim2.fromOffset(wide, tall)
		local left = holder:FindFirstChild("Left") :: ImageLabel
		local right = holder:FindFirstChild("Right") :: ImageLabel
		local split = math.floor(wide / 2)
		left.Size = UDim2.fromOffset(split, tall)
		right.Position = UDim2.fromOffset(split, 0)
		right.Size = UDim2.fromOffset(wide - split, tall)
		left.ImageTransparency = fade
		right.ImageTransparency = fade
	end
	-- the whole picture, as large as fits; the sides, covered
	place(p.picture, math.min(size.X / c.width, size.Y / c.height))
	place(p.backdrop, math.max(size.X / c.width, size.Y / c.height))
	local dim = p.backdrop:FindFirstChild("Dim") :: Frame
	dim.BackgroundTransparency = Intro.sidesDim + (1 - Intro.sidesDim) * fade

	p.shade.Visible = now.revealed
	p.shade.BackgroundTransparency = fade

	p.flash.BackgroundTransparency = 1 - now.flash * 0.85

	p.buttonGroup.Visible = now.button > 0 and now.shown > 0
	p.buttonGroup.Position = UDim2.new(0.5, 0, 1 + 0.25 * (1 - now.button), -16)
	--[[ Still until the player reaches for it: brighter and a little larger
	     under the mouse (or a gamepad's focus), darker and pressed in while
	     held. ]]
	local ready = now.button >= 1 and not pressedAt
	local state = p.button.GuiState
	local pressing = ready and state == Enum.GuiState.Press
	local hovering = ready
		and not pressing
		and (state == Enum.GuiState.Hover or GuiService.SelectedObject == p.button)
	local look = if pressing then Intro.buttonPress elseif hovering then Intro.buttonHover else nil
	for _, block in p.buttonFace do
		block.BackgroundColor3 = if look then look.colour else Intro.buttonColour
	end
	p.buttonWords.Position = UDim2.new(0.5, 0, 0.47, if pressing then 3 else 0)
	p.buttonScale.Scale = (if look then look.scale else 1) * (1 - 0.1 * fade)
	for _, piece in p.buttonGroup:GetDescendants() do
		if piece:IsA("Frame") then
			piece:SetAttribute("Base", piece:GetAttribute("Base") or piece.BackgroundTransparency)
			piece.BackgroundTransparency = 1
				- (1 - (piece:GetAttribute("Base") :: number)) * now.shown
		elseif piece:IsA("TextLabel") then
			piece.TextTransparency = fade
		elseif piece:IsA("UIStroke") then
			piece.Transparency = fade
		end
	end

	if pressedAt then
		fadeMusic(now.shown)
	end
	if now.done and held == nil then
		IntroCutscene.stop()
	end
end

local function press()
	local t = clock()
	if pressedAt or held or not IntroTimeline.canPress(Intro :: any, t) then
		return
	end
	pressedAt = t
	RunPaused.setTitle(false)
	local callback = onBegin
	if callback then
		callback()
	end
end

--[[ Plays the intro from its first frame. `begin` runs once, on the press:
     it asks the server to start the run and lets the run's music in. ]]
function IntroCutscene.start(begin: () -> ())
	if parts or IntroCutscene.skipped() then
		return
	end
	onBegin = begin
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local built = build(playerGui)
	parts = built
	built.button.Activated:Connect(press)
	RunPaused.setTitle(true)
	startedAt = nil
	pressedAt = nil
	connection = RunService.RenderStepped:Connect(function()
		pose(held or clock())
	end)
	pose(0)
	task.spawn(startClock, built)
end

--[[ Studio captures: freeze the cutscene at `t` seconds (nil runs it on). ]]
function IntroCutscene.hold(t: number?)
	held = t
	if t then
		pose(t)
	end
end

function IntroCutscene.stop()
	local p = parts
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if p then
		if GuiService.SelectedObject == p.button then
			GuiService.SelectedObject = nil
		end
		p.gui:Destroy()
		p.safe:Destroy()
	end
	parts = nil
	startedAt = nil
	if music then
		music:Destroy()
		music = nil
	end
	RunPaused.setTitle(false)
end

return IntroCutscene
