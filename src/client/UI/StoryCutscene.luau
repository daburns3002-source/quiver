--!strict
--[[
	The story cutscene after BEGIN ADVENTURE (owner, 2026-10-25; `Config/Story`):
	King Bloblin in Mossy Glade gets the WANTED poster, roars, and the heroes run
	into the forest; then black, then the run.

	Animated as the owner approved it in Claude Design (owner, 2026-11-10: "ok
	i like this cutscene"; `Config/StoryMotion`): the Codex frames pan, zoom,
	shake and dissolve on the Design's stage, under crisp pixel overlays, as
	large as fits with black bars round it. The landscape stage on a wide
	screen, the portrait one (the same frames, reframed) on a tall one. The
	frames still come in on `Util/StoryTimeline`'s clock, so the music and
	sound cues land where they always did. One RenderStepped loop draws the
	moment since the start (`Util/StoryMotion`), so `StoryCutscene.hold(t)`
	freezes it for a Studio capture.

	The player stays held (`RunPaused.setStory`) and the server keeps them on the
	title until `finish` runs once the black has held, which asks it to start
	(`Remotes.IntroBegin`, through the callback). SKIP cuts to black.
	Presentation only.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Music = require(ReplicatedStorage.Shared.Config.Music)
local Options = require(script.Parent.Parent.Options)
local Story = require(ReplicatedStorage.Shared.Config.Story)
local StoryMotion = require(ReplicatedStorage.Shared.Util.StoryMotion)
local StoryMotionConfig = require(ReplicatedStorage.Shared.Config.StoryMotion)
local StoryTimeline = require(ReplicatedStorage.Shared.Util.StoryTimeline)

local Device = require(script.Parent.Parent.Device)
local Preload = require(script.Parent.Parent.Preload)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)

local StoryCutscene = {}

local log = Log.forTag("StoryCutscene")

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromRGB(20, 14, 6)
local FACE = Color3.fromRGB(46, 40, 34)
local FACE_HOVER = Color3.fromRGB(78, 70, 60)

local c = Story :: any

--[[ Pixel blocks drawn by `StoryMotion`, reused frame to frame: `shown` of
     them are up. ]]
type Pool = { parent: Frame, frames: { Frame }, shown: number }

type Parts = {
	gui: ScreenGui,
	safe: ScreenGui,
	window: Frame,
	--[[ Each camera group's layer (by group number): its frames' two halves
	     (by frame number) under its overlay blocks. ]]
	groups: { Frame },
	frames: { [number]: Frame },
	groupFx: { Pool },
	screenFx: Pool,
	flash: Frame,
	fade: Frame,
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
--[[ What `StoryMotion` fills every frame, kept so nothing is made per frame. ]]
local scene = StoryMotion.newScene()
--[[ Whether `preload` has run, and which frames are down (by `Story.shots`
     picture name). A frame is "in" once its halves have been fetched —
     downloaded and decoded — which is a firmer answer than asking a label
     whether it has drawn yet. One that is not in never draws: the frame
     before it stays up (`StoryMotion.draw`). ]]
local preloaded = false
local framesIn: { [string]: boolean } = {}
--[[ The warm set's name in `Preload`, and the frames currently held in video
     memory. The window slides with the cutscene
     (`DeviceTiers.warmStoryFrames`). ]]
local WARM = "Story"
local warmHeld: { [string]: boolean } = {}
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

--[[ Every frame the cutscene shows, once each, in order — and where each one
     stands in that order.

     Worked out once and kept: `pose` asks for the order every frame to slide
     the warm window along it, and walking twenty-two shots and allocating two
     tables sixty times a second, inside the code meant to stop the cutscene
     stuttering, would be its own small version of the problem. ]]
local frameOrder: { string }? = nil
local indexOf: { [string]: number } = {}

local function pictureNames(): { string }
	local known = frameOrder
	if known then
		return known
	end
	local seen, out = {}, {}
	for _, shot in Story.shots do
		for _, frame in shot.frames do
			if not seen[frame.picture] then
				seen[frame.picture] = true
				table.insert(out, frame.picture)
				indexOf[frame.picture] = #out
			end
		end
	end
	frameOrder = out
	return out
end

--[[ When each frame starts from the first one (`StoryMotion.cues`), worked
     out once from the holds, in the same order as `pictureNames`. ]]
local cuesKnown: StoryMotion.Cues? = nil

local function cues(): StoryMotion.Cues
	local known = cuesKnown
	if known then
		return known
	end
	local holds = {}
	for _, shot in Story.shots do
		for _, frame in shot.frames do
			table.insert(holds, frame.hold)
		end
	end
	local made = StoryMotion.cues(holds)
	cuesKnown = made
	return made
end

--[[ A frame's two halves. Both stages draw the same landscape frames (the
     portrait one crops and pans across them), so only they are loaded. ]]
local function halfIds(name: string): { string }
	local wide = Story.pictures[name]
	return if wide then { wide.left, wide.right } else {}
end

--[[ The frames of the first `Story.leadShots` shots, then all the rest, both
     in the order they are shown. The split is the point of this: the first
     list is what the black screen waits for, the second is what loads behind
     the cutscene while it plays. ]]
local function leadAndRest(): ({ string }, { string })
	local lead: { string } = {}
	local rest: { string } = {}
	local seen: { [string]: boolean } = {}
	for index, shot in Story.shots do
		for _, frame in shot.frames do
			if seen[frame.picture] then
				continue
			end
			seen[frame.picture] = true
			table.insert(if index <= Story.leadShots then lead else rest, frame.picture)
		end
	end
	return lead, rest
end

--[[ Starts loading the frames while the title is up.

     The first few shots are fetched first and are all the black screen waits
     for; everything after them is fetched in shot order behind the playing
     cutscene, so the picture always has frames in hand without the black
     screen paying for all forty. Asking for every frame in both orientations
     up front was eighty-odd downloads before the first one could show, and on
     a phone the cutscene began before they were in and skipped its way
     through them (owner: "it keeps cutting out and back in"; "the King
     Bloblin story cutscene loads very slowly").

     Fetching is all that correctness needs — a fetched frame draws without
     the network. Warming, which also costs video memory, is separate and
     bounded (`warmFor`). ]]
function StoryCutscene.preload()
	if preloaded then
		return
	end
	preloaded = true
	local lead, rest = leadAndRest()

	--[[ A frame at a time, not one batch of eighty: each `fetch` returns when
	     that frame's two halves are in, so `framesIn` fills in shot order and
	     the cutscene can start on frame one while frame thirty is still
	     coming. One batch would land them all at the end, which is the
	     behaviour this replaces. ]]
	local function take(names: { string })
		for _, name in names do
			local ids = halfIds(name)
			if #ids > 0 then
				Preload.fetch(ids)
			end
			framesIn[name] = true
		end
	end

	task.spawn(function()
		local began = os.clock()
		take(lead)
		log.info("%d lead frames in %.2f s", #lead, os.clock() - began)
		take(rest)
		log.info("all %d frames in %.2f s", #lead + #rest, os.clock() - began)
	end)
end

--[[ Whether every frame of the lead is down. ]]
local function leadIn(): boolean
	local lead = leadAndRest()
	for _, name in lead do
		if not framesIn[name] then
			return false
		end
	end
	return true
end

--[[ Where the warm window was last placed, and when. `pose` asks on every
     frame; the window itself only moves on a cut, but a frame that was still
     coming down when it last moved has to be picked up when it lands, so it
     is also redone a few times a second. ]]
local warmAt: number? = nil
local warmedAt = 0
local WARM_RECHECK = 0.25

--[[ Keeps the frames from `at` onward warm, up to the tier's window, and
     drops the ones behind, so a frame's decode has already happened by its
     turn without the whole cutscene sitting in video memory at once. ]]
local function warmFor(at: number)
	local now = os.clock()
	if warmAt == at and now - warmedAt < WARM_RECHECK then
		return
	end
	warmAt, warmedAt = at, now
	local order = pictureNames()
	local window = Device.tier().warmStoryFrames
	local wanted: { [string]: boolean } = {}
	for index = at, math.min(at + window - 1, #order) do
		wanted[order[index]] = true
	end
	for name in wanted do
		if not warmHeld[name] and framesIn[name] then
			warmHeld[name] = true
			Preload.warm(WARM, halfIds(name))
		end
	end
	for name in warmHeld do
		if not wanted[name] then
			warmHeld[name] = nil
			Preload.cool(WARM, halfIds(name))
		end
	end
end

--[[ Whether frame number `n` (in show order) is down. ]]
local function ready(n: number): boolean
	local name = pictureNames()[n]
	return name ~= nil and framesIn[name] == true
end

--[[ A frame's two halves side by side, `Left` and `Right`, each showing only
     its own side of the middle, so no seam doubles. ]]
local function halvesOf(parent: Frame, name: string, ids: { string }, z: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.ZIndex = z
	holder.Parent = parent
	local source = Story.picture
	local middle = source.width / 2
	for index, side in { "Left", "Right" } do
		local image = Instance.new("ImageLabel")
		image.Name = side
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Image = ids[index] or ""
		image.ImageRectOffset = Vector2.new(if index == 1 then 0 else middle - source.rightFrom, 0)
		image.ImageRectSize = Vector2.new(middle, source.height)
		image.ZIndex = z
		image.Parent = holder
	end
	return holder
end

local function pool(parent: Frame): Pool
	return { parent = parent, frames = {}, shown = 0 }
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
	-- layers stack by their parents' order (groups, then overlays, flash, fade)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

	--[[ One layer per camera group, later groups over earlier ones as they
	     dissolve in; within it the group's frames in order, then its overlay
	     blocks. Both stages share them (their groups are the same frames). ]]
	local names = pictureNames()
	local groups, frames, groupFx = {}, {}, {}
	for i, group in StoryMotionConfig.landscape.groups do
		local layer = Instance.new("Frame")
		layer.Name = "Group" .. i
		layer.BackgroundTransparency = 1
		layer.Size = UDim2.fromScale(1, 1)
		layer.Visible = false
		layer.ZIndex = i
		layer.Parent = window
		groups[i] = layer
		for j, n in group.f do
			local name = names[n]
			local wide = if name then Story.pictures[name] else nil
			frames[n] = halvesOf(
				layer,
				name or tostring(n),
				if wide then { wide.left, wide.right } else {},
				j
			)
		end
		local fx = Instance.new("Frame")
		fx.Name = "Fx"
		fx.BackgroundTransparency = 1
		fx.Size = UDim2.fromScale(1, 1)
		fx.ZIndex = 50
		fx.Parent = layer
		groupFx[i] = pool(fx)
	end
	local screenFx = Instance.new("Frame")
	screenFx.Name = "ScreenFx"
	screenFx.BackgroundTransparency = 1
	screenFx.Size = UDim2.fromScale(1, 1)
	screenFx.ZIndex = 1000
	screenFx.Parent = window
	local flash = rect(window, "Flash", StoryMotionConfig.flashColour, 1001)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	local fade = rect(window, "Fade", Color3.new(0, 0, 0), 1002)
	fade.Size = UDim2.fromScale(1, 1)

	local group, button, face = buildSkip(safe)
	return {
		gui = gui,
		safe = safe,
		window = window,
		groups = groups,
		frames = frames,
		groupFx = groupFx,
		screenFx = pool(screenFx),
		flash = flash,
		fade = fade,
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

--[[ Puts `r`'s blocks up, from stage pixels to the screen at `k` per pixel,
     each on whole pixels, `fade` times as opaque; hides the ones left over. ]]
local function drawRects(into: Pool, r: StoryMotion.Rects, k: number, fade: number)
	local frames = into.frames
	for i = 1, r.n do
		local f = frames[i]
		if not f then
			local made = Instance.new("Frame")
			made.Name = "Block"
			made.BorderSizePixel = 0
			made.ZIndex = 1
			made.Parent = into.parent
			frames[i] = made
			f = made
		end
		local x0, y0 = math.floor(r.x[i] * k + 0.5), math.floor(r.y[i] * k + 0.5)
		local x1 = math.floor((r.x[i] + r.w[i]) * k + 0.5)
		local y1 = math.floor((r.y[i] + r.h[i]) * k + 0.5)
		f.Position = UDim2.fromOffset(x0, y0)
		f.Size = UDim2.fromOffset(math.max(1, x1 - x0), math.max(1, y1 - y0))
		f.BackgroundColor3 = r.colour[i]
		f.BackgroundTransparency = 1 - r.alpha[i] * fade
		f.Visible = true
	end
	for i = r.n + 1, into.shown do
		frames[i].Visible = false
	end
	into.shown = r.n
end

local function pose(t: number)
	local p = parts
	if not p then
		return
	end
	local now = StoryTimeline.pose(c, t, skippedAt)
	local name = now.picture
	if name then
		--[[ Keep this frame and the next few warm, and drop the ones already
		     shown (`DeviceTiers.warmStoryFrames`). ]]
		pictureNames()
		local at = indexOf[name]
		if at then
			warmFor(at)
		end
	end

	--[[ The stage for the screen's shape, as large as fits. ]]
	local screen = p.gui.AbsoluteSize
	local layout = if screen.Y > screen.X
		then StoryMotionConfig.portrait
		else StoryMotionConfig.landscape
	local stage = layout.stage
	local k = math.min(screen.X / stage.X, screen.Y / stage.Y)
	p.window.Size = UDim2.fromOffset(math.floor(stage.X * k + 0.5), math.floor(stage.Y * k + 0.5))
	p.window.Visible = name ~= nil

	local shownGroups: { [number]: boolean } = {}
	local shownFrames: { [number]: boolean } = {}
	if name then
		StoryMotion.draw(scene, layout, cues(), t - Story.lead, ready)
		local image = StoryMotionConfig.image
		for li = 1, scene.count do
			local layer = scene.layers[li]
			shownGroups[layer.group] = true
			local x0, y0 = math.floor(layer.tx * k + 0.5), math.floor(layer.ty * k + 0.5)
			local w = math.floor((layer.tx + image.X * layer.s) * k + 0.5) - x0
			local h = math.floor((layer.ty + image.Y * layer.s) * k + 0.5) - y0
			local split = math.floor(w / 2)
			for fi = 1, layer.count do
				local n = layer.frames[fi]
				local holder = p.frames[n]
				if holder then
					shownFrames[n] = true
					holder.Position = UDim2.fromOffset(x0, y0)
					holder.Size = UDim2.fromOffset(w, h)
					local alpha = 1 - layer.alphas[fi] * layer.opacity
					local left = holder:FindFirstChild("Left") :: ImageLabel
					local right = holder:FindFirstChild("Right") :: ImageLabel
					left.Size = UDim2.fromOffset(split, h)
					left.ImageTransparency = alpha
					right.Position = UDim2.fromOffset(split, 0)
					right.Size = UDim2.fromOffset(w - split, h)
					right.ImageTransparency = alpha
				end
			end
			drawRects(p.groupFx[layer.group], layer.rects, k, layer.opacity)
		end
		drawRects(p.screenFx, scene.screen, k, 1)
		p.flash.BackgroundTransparency = 1 - scene.flash
		p.fade.BackgroundTransparency = 1 - scene.black
	end
	for i, layer in p.groups do
		local on = shownGroups[i] == true
		if layer.Visible ~= on then
			layer.Visible = on
		end
		local fx = p.groupFx[i]
		if not on and fx.shown > 0 then
			for b = 1, fx.shown do
				fx.frames[b].Visible = false
			end
			fx.shown = 0
		end
	end
	for n, holder in p.frames do
		local on = shownFrames[n] == true
		if holder.Visible ~= on then
			holder.Visible = on
		end
	end

	local skippable = t >= Story.skipAt and not skippedAt and name ~= nil
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

--[[ Holds on black until the first `Story.leadShots` shots have loaded (at
     most `Story.loadWait`; they have been loading since the title came up),
     so none of them shows black.

     It waited for all forty frames before, which on a phone meant it always
     hit the cap and started anyway with most of them still coming — so the
     cutscene ran ahead of its own pictures and held each frame up until the
     next one that happened to be in. Waiting for the opening shots instead
     costs the same black screen at worst and leaves the remaining twenty
     seconds of running time to fetch the other thirty frames. ]]
local function startClock(built: Parts)
	local deadline = os.clock() + Story.loadWait
	while os.clock() < deadline and parts == built do
		if (music == nil or (music :: Sound).IsLoaded) and leadIn() then
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
	if Music.story.id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Music_Story"
		sound.SoundId = Music.story.id
		sound.Volume = Music.volume * Options.music()
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
			sound.Volume = Music.volume
				* math.max(0, 1 - (clock() - skipped) / MUSIC_OUT)
				* Options.music()
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
	--[[ The frames' video memory goes back as the cutscene leaves. What was
	     fetched stays fetched, so a second play of it costs no network. ]]
	Preload.coolAll(WARM)
	table.clear(warmHeld)
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
