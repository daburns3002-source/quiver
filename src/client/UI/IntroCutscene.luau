--!strict
--[[
	The intro cutscene as the game starts (owner, 2026-10-25; `Config/Intro`),
	after Pixel Lineage's intro: a black screen where DYL.DEVS PRESENTS fades
	in in dark gold, then, on the intro music's hit at 5.0 s, a cut to the
	title screen: "The World Tree at night" (owner, 2026-11-12; `UI/TitleScene`,
	built by hand from flat blocks, no painted picture), which stands still
	once it is up but for its slow motes, with the kit's green BEGIN ADVENTURE
	button, gently pulsing, at the bottom.

	The music (`Config/Music.intro`) starts on the cutscene's first frame,
	which waits on the black screen until the track has loaded, so its hit
	lands on the cut;
	the run's own music waits (`MusicFx.setQuiet`). The player is held
	still (`RunPaused.setTitle`) and the server holds the world; the press
	fades the title away into the story cutscene (`UI/StoryCutscene`), whose
	end asks the server to start (`Remotes.IntroBegin`).

	One RenderStepped loop poses everything from the time since the start
	(`Util/IntroTimeline`), so `IntroCutscene.hold(t)` can freeze it at a
	moment for a Studio capture, and `IntroCutscene.preview(w, h)` shows the
	title alone in a phone-sized frame. Presentation only.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Intro = require(ReplicatedStorage.Shared.Config.Intro)
local IntroTimeline = require(ReplicatedStorage.Shared.Util.IntroTimeline)
local Music = require(ReplicatedStorage.Shared.Config.Music)
local Options = require(script.Parent.Parent.Options)

local Device = require(script.Parent.Parent.Device)
local Preload = require(script.Parent.Parent.Preload)
local RunPaused = require(script.Parent.Parent.RunPaused)
local TitleScene = require(script.Parent.TitleScene)

local IntroCutscene = {}

local FONT = Font.fromEnum(Enum.Font.FredokaOne)

type Parts = {
	gui: ScreenGui,
	safe: ScreenGui,
	black: Frame,
	presents: TextLabel,
	presentsSub: TextLabel,
	presentsScale: UIScale,
	--[[ The picture and the button, built for the screen's shape and built
	     again when that changes (a phone turned over, a window resized). ]]
	scene: TitleScene.Scene,
	button: TitleScene.Button,
	flash: Frame,
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

--[[ Whether this play skips the intro: in Studio, by the `SkipIntro`
     attribute on Workspace (the server reads the same one); and anywhere
     for a player the game itself teleported here — a party portal's run
     server, or back from one — who has seen it already (`Run/Party`). ]]
function IntroCutscene.skipped(): boolean
	if RunService:IsStudio() and Workspace:GetAttribute("SkipIntro") == true then
		return true
	end
	local ok, data = pcall(function()
		return TeleportService:GetLocalPlayerTeleportData()
	end)
	return ok
		and type(data) == "table"
		and (data :: any).arrowborne == true
		-- sent to the tutorial on join, before the title: it plays here
		and (data :: any).story ~= true
end

--[[ The screen's size. Read from the camera rather than from the ScreenGui:
     one that has not been drawn yet reports 800 by 600, which would call a
     phone held upright a landscape screen. ]]
local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
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

--[[ BEGIN ADVENTURE was pressed: forward-declared, since the button is
     built before it. ]]
local press: () -> ()

local function build(playerGui: PlayerGui): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroCutscene"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- over everything, the notch and the corners too
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 110
	-- the picture is stacked blocks: each layer sorts inside its own parent
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- the button stays inside the device's safe area
	local safe = Instance.new("ScreenGui")
	safe.Name = "IntroButton"
	safe.ResetOnSpawn = false
	safe.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	safe.DisplayOrder = 111
	safe.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	safe.Parent = playerGui

	-- under everything, the picture too, until the title leaves
	local black = rect(gui, "Black", Color3.new(0, 0, 0), 0)
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

	--[[ The title picture, for the screen as it is now (`pose` builds it
	     again if the screen changes shape), hidden until the cut. ]]
	local view = viewport()
	local scene = TitleScene.build(gui, view)
	scene.root.Visible = false

	local flash = rect(gui, "Flash", Color3.new(1, 1, 1), 15)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1

	local button = TitleScene.button(safe, view, Intro.button, function()
		press()
	end)
	button.group.Visible = false

	return {
		gui = gui,
		safe = safe,
		black = black,
		presents = presents,
		presentsSub = sub,
		presentsScale = presentsScale,
		scene = scene,
		button = button,
		flash = flash,
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
	sound.Volume = Music.volume * Options.music()
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
	--[[ The title's one picture (its soft glow) and the music both load
	     during the black screen, and the clock waits for both: the cut at
	     `revealAt` is counted from here, so holding the clock holds the
	     music's hit with it and the two still land together. ]]
	local artIn = false
	task.spawn(function()
		artIn = Preload.await(TitleScene.images, Intro.artWait)
	end)

	local sound = loadMusic()
	local began = os.clock()
	while parts == built do
		local waited = os.clock() - began
		local musicIn = sound == nil or sound.IsLoaded or waited >= Intro.musicWait
		if (artIn or waited >= Intro.artWait) and musicIn then
			break
		end
		task.wait(0.05)
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
			GuiService.SelectedObject = built.button.hit
		end
	end)
end

local function fadeMusic(level: number)
	local sound = music
	if sound then
		sound.Volume = Music.volume * level * Options.music()
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
	p.black.BackgroundTransparency = fade

	--[[ A screen that has changed shape (a phone turned over, a window
	     resized) gets the picture and the button built again for it. ]]
	local view = viewport()
	if (view - p.scene.view).Magnitude > 0.5 then
		local focused = GuiService.SelectedObject == p.button.hit
		p.scene.root:Destroy()
		p.button.group:Destroy()
		p.scene = TitleScene.build(p.gui, view)
		p.button = TitleScene.button(p.safe, view, Intro.button, function()
			press()
		end)
		if focused then
			GuiService.SelectedObject = p.button.hit
		end
	end

	-- the picture and its motes, from the moment it appears
	local sinceCut = t - Intro.revealAt
	p.scene.root.Visible = now.revealed
	TitleScene.step(p.scene, sinceCut, now.shown)

	p.flash.BackgroundTransparency = 1 - now.flash * 0.85

	--[[ The button rises in after the cut and pulses gently until it is
	     pressed; the kit gives it its swell under the pointer, its squash
	     and its click. ]]
	local ready = now.button >= 1 and not pressedAt
	TitleScene.poseButton(p.button, sinceCut, now.button, now.shown, ready)

	if pressedAt then
		fadeMusic(now.shown)
	end
	if now.done and held == nil then
		IntroCutscene.stop()
	end
end

function press()
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

--[[ Studio looks: the title alone, as it stands once it is up, in a frame
     `width` by `height` points in the middle of the screen (390 by 844 is
     a phone held upright, 844 by 390 one on its side), over whatever is
     showing. Returns the ScreenGui; destroy it to take the preview away. ]]
function IntroCutscene.preview(width: number, height: number): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local old = playerGui:FindFirstChild("TitlePreview")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TitlePreview"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	local backdrop = rect(gui, "Backdrop", Color3.fromRGB(40, 40, 46), 0)
	backdrop.Size = UDim2.fromScale(1, 1)
	local phone = rect(gui, "Phone", Color3.new(0, 0, 0), 1)
	phone.AnchorPoint = Vector2.new(0.5, 0.5)
	phone.Position = UDim2.fromScale(0.5, 0.5)
	phone.Size = UDim2.fromOffset(width, height)
	phone.ClipsDescendants = true
	local view = Vector2.new(width, height)
	local scene = TitleScene.build(phone, view)
	local button = TitleScene.button(phone, view, Intro.button, function() end)
	local began = os.clock()
	local step = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		TitleScene.step(scene, t, 1)
		TitleScene.poseButton(button, t, 1, 1, true)
	end)
	gui.Destroying:Once(function()
		step:Disconnect()
	end)
	return gui
end

function IntroCutscene.stop()
	local p = parts
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if p then
		if GuiService.SelectedObject == p.button.hit then
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
