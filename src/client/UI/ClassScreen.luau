--!strict
--[[ The owner's approved class cutouts: select a look, then CHOOSE (2026-10-27). ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Assets = require(ReplicatedStorage.Shared.Config.ClassSelectAssets)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Hit = require(ReplicatedStorage.Shared.Util.ClassSelectHit)
local Kit = require(script.Parent.Kit)
local LoadingPick = require(ReplicatedStorage.Shared.Util.LoadingPick)
local LoadingScreen = require(ReplicatedStorage.Shared.Config.LoadingScreen)
local LoadingTips = require(ReplicatedStorage.Shared.Config.LoadingTips)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunPaused = require(script.Parent.Parent.RunPaused)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local SpotlightArt = require(ReplicatedStorage.Shared.Util.SpotlightArt)
local ClassScreen = {}
local started = false
--[[ Seconds the loading screen stays up after CHOOSE. ]]
local LOAD_SECONDS = 1.8

--[[ The game's loading screen over everything in `parent`: one of Codex's
     spotlights, a tip, and a bar filling over `LOAD_SECONDS`. ]]
function ClassScreen.loadingCover(parent: Instance, seconds: number?): Frame
	local cover = Instance.new("Frame")
	cover.Name = "Loading"
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.ZIndex = 50
	cover.Parent = parent
	local screen = Instance.new("Frame")
	screen.BackgroundTransparency = 1
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Size = UDim2.fromScale(1, 1)
	screen.ZIndex = 50
	screen.Parent = cover
	--[[
		One of Codex's spotlights, drawn from the same four the join
		screen uses (owner, 2026-11-01: "the old loading screens need to
		be removed from the game").

		This was the last place the old shared art appeared: it drew that
		backdrop with the chosen class's weapon composed over it -- a
		picture, a line and a name plaque. A spotlight is a finished
		picture instead, so only the tip and the bar go over it, exactly
		as on the join screen.
	]]
	local spotlit: { string } = {}
	for _, entry in LoadingPick.pool(nil) do
		if LoadingScreen.spotlights[entry.name] then
			table.insert(spotlit, entry.name)
		end
	end
	--[[ Upright on a phone held portrait (owner, 2026-11-05: "make new
	     loading screens for mobile"). ]]
	local camera = Workspace.CurrentCamera
	local layout, art = LoadingScreen.pick(
		if camera then camera.ViewportSize else Vector2.new(16, 9),
		if #spotlit > 0 then spotlit[math.random(1, #spotlit)] else ""
	)
	local size = layout.size
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = size.X / size.Y
	aspect.Parent = screen
	local function place(object: GuiObject, box: LoadingScreen.Box)
		object.Position = UDim2.fromScale(box.x / size.X, box.y / size.Y)
		object.Size = UDim2.fromScale(box.w / size.X, box.h / size.Y)
		object.ZIndex = 51
		object.Parent = screen
	end
	if art then
		SpotlightArt.draw(screen, art, 50, size, LoadingScreen.tileOverlap, layout.columns)
	end
	local tip = Instance.new("TextLabel")
	tip.BackgroundTransparency = 1
	tip.Font = Enum.Font.Arcade
	tip.Text = LoadingTips[math.random(1, #LoadingTips)]
	tip.TextColor3 = LoadingScreen.tipText
	tip.TextScaled = true
	tip.TextWrapped = true
	tip.TextXAlignment = Enum.TextXAlignment.Left
	place(tip, layout.tip)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 40
	limit.Parent = tip
	local trough = Instance.new("Frame")
	trough.BackgroundTransparency = 1
	place(trough, layout.bar)
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = LoadingScreen.barFill
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(0, 1)
	bar.ZIndex = 52
	bar.Parent = trough
	TweenService
		:Create(bar, TweenInfo.new((seconds or LOAD_SECONDS) - 0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(1, 1),
		})
		:Play()
	return cover
end

function ClassScreen.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClassScreen"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local connections: { RBXScriptConnection } = {}
	local tweens: { [Instance]: Tween } = {}
	local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
		table.insert(connections, signal:Connect(callback))
	end
	local function tween(
		object: Instance,
		duration: number,
		properties: { [string]: any },
		back: boolean?
	)
		if tweens[object] then
			tweens[object]:Cancel()
		end
		local motion = TweenService:Create(
			object,
			TweenInfo.new(
				duration,
				if back then Enum.EasingStyle.Back else Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			properties
		)
		tweens[object] = motion
		motion:Play()
	end
	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Active = true
	dim.Parent = gui
	local canvas = Kit.canvas(dim)
	canvas.Size = UDim2.fromScale(1, 1)
	local function piece(data: Assets.Piece, z: number): ImageLabel
		local image = Kit.image(canvas, data.image)
		image.ScaleType = Enum.ScaleType.Stretch
		image.ResampleMode = Enum.ResamplerMode.Default
		Kit.put(image, data.box.x, data.box.y, data.box.w, data.box.h)
		image.ZIndex = z
		return image
	end
	piece(Assets.base, 1)
	local panels: { ImageLabel } = {}
	local scales: { UIScale } = {}
	local shakes: { [number]: number } = {}
	local glows: { ImageLabel } = {}
	for i, section in Assets.sections do
		local panel = piece(section.piece, 3)
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		local box = section.piece.box
		panel.Position = UDim2.fromScale((box.x + box.w / 2) / 1920, (box.y + box.h / 2) / 1080)
		panels[i] = panel
		local scale = Instance.new("UIScale")
		scale.Parent = panel
		scales[i] = scale
		local glow = Kit.image(canvas, GearAssets.fx.glow)
		glow.ScaleType = Enum.ScaleType.Stretch
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = panel.Position
		glow.Size = UDim2.fromScale(box.w / 1920 * 1.2, 1.15)
		glow.ImageColor3 = Color3.fromRGB(255, 206, 85)
		glow.ImageTransparency = 0.35
		glow.ZIndex = 9
		glow.Visible = false
		glows[i] = glow
	end
	piece(Assets.title, 20)
	for _, data in
		{ Assets.plateRanger, Assets.plateArcanist, Assets.plateWarden, Assets.plateAssassin }
	do
		piece(data, 20)
	end
	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.Font = Enum.Font.Arcade
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 25
	hit.Parent = canvas
	local choose = Instance.new("ImageButton")
	choose.BackgroundTransparency = 1
	choose.AutoButtonColor = false
	choose.Image = Assets.choose
	choose.ScaleType = Enum.ScaleType.Stretch
	choose.AnchorPoint = Vector2.new(0.5, 0.5)
	choose.Position = UDim2.fromScale(0.5, 820 / 1080)
	choose.Size = UDim2.fromScale(480 / 1920, 126 / 1080)
	choose.ZIndex = 30
	choose.Visible = false
	choose.Parent = canvas
	local chooseScale = Instance.new("UIScale")
	chooseScale.Parent = choose

	--[[ The upright screen, shown instead on a screen taller than wide
	     (owner, 2026-11-05: "make the character select screen the classes on
	     top of eachother instead of next to eachother horizontally"): the
	     classes stacked in bands, male left and female right. The picked
	     half is outlined in gold and the rest darkened, as the landscape
	     panels grow and grey. ]]
	local upright = Assets.portrait
	local tall = Instance.new("Frame")
	tall.Name = "UprightCanvas"
	tall.BackgroundTransparency = 1
	tall.AnchorPoint = Vector2.new(0.5, 0.5)
	tall.Position = UDim2.fromScale(0.5, 0.5)
	tall.Size = UDim2.fromScale(1, 1)
	tall.Visible = false
	tall.Parent = dim
	local tallAspect = Instance.new("UIAspectRatioConstraint")
	tallAspect.AspectRatio = upright.size.X / upright.size.Y
	tallAspect.AspectType = Enum.AspectType.FitWithinMaxSize
	tallAspect.Parent = tall
	if #upright.tiles > 0 then
		SpotlightArt.draw(tall, upright.tiles, 1, upright.size, upright.overlap, upright.columns)
	end
	local halves: { Frame } = {}
	local outlines: { UIStroke } = {}
	for i in Assets.sections do
		local edges = upright.bands[math.ceil(i / 2)]
		local left = i % 2 == 1
		local half = Instance.new("Frame")
		half.Name = "Half" .. i
		half.BackgroundColor3 = Color3.new(0, 0, 0)
		half.BackgroundTransparency = 1
		half.BorderSizePixel = 0
		half.Position = UDim2.fromScale(
			(if left then 0 else upright.split) / upright.size.X,
			edges.top / upright.size.Y
		)
		half.Size = UDim2.fromScale(
			(if left then upright.split else upright.size.X - upright.split) / upright.size.X,
			(edges.bottom - edges.top) / upright.size.Y
		)
		half.ZIndex = 5
		half.Parent = tall
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Color = Color3.fromRGB(255, 206, 85)
		outline.Thickness = 5
		outline.Enabled = false
		outline.Parent = half
		halves[i] = half
		outlines[i] = outline
	end
	local tallHit = hit:Clone()
	tallHit.Parent = tall
	--[[ Which screen shows, and where CHOOSE sits on it, for the screen's
	     shape now; again whenever it changes, as when a phone turns. ]]
	local isUpright = false
	local chooseY, chooseOf = 820, 1080
	local function arrange()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(16, 9)
		isUpright = viewport.Y > viewport.X and #upright.tiles > 0
		tall.Visible = isUpright
		canvas.Visible = not isUpright
		choose.Parent = if isUpright then tall else canvas
		choose.Size = if isUpright
			then UDim2.fromScale(480 / upright.size.X, 126 / upright.size.Y)
			else UDim2.fromScale(480 / 1920, 126 / 1080)
		chooseY = if isUpright then upright.choose else 820
		chooseOf = if isUpright then upright.size.Y else 1080
	end
	arrange()
	if Workspace.CurrentCamera then
		connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), arrange)
	end
	local selected: number? = nil
	local hovered: number? = nil
	local closing = false
	local shown = false
	local hasProfile = false
	local hasLook = false
	local function tint()
		for i, glow in glows do
			local isSelected = selected == i
			glow.Visible = isSelected or (hovered == i and selected == nil)
			glow.ZIndex = if isSelected then 9 else 11
			glow.ImageTransparency = if isSelected then 0.35 else 0.9
		end
		for i, panel in panels do
			local colour = if selected and selected ~= i
				then Color3.fromRGB(90, 90, 90)
				else (if hovered == i then Color3.new(1, 1, 1) else Color3.new(1, 1, 1))
			tween(panel, 0.2, { ImageColor3 = colour })
		end
		for i, half in halves do
			local isSelected = selected == i
			outlines[i].Enabled = isSelected or (hovered == i and selected == nil)
			outlines[i].Transparency = if isSelected then 0 else 0.5
			tween(half, 0.2, {
				BackgroundTransparency = if selected and not isSelected then 0.55 else 1,
			})
		end
	end
	local function sectionAt(position: Vector3): number?
		if isUpright then
			local size = tall.AbsoluteSize
			if size.X <= 0 or size.Y <= 0 then
				return nil
			end
			return Hit.upright(
				upright,
				(position.X - tall.AbsolutePosition.X) / size.X * upright.size.X,
				(position.Y - tall.AbsolutePosition.Y) / size.Y * upright.size.Y
			)
		end
		local size = canvas.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return nil
		end
		return Hit.section(
			(position.X - canvas.AbsolutePosition.X) / size.X * 1920,
			(position.Y - canvas.AbsolutePosition.Y) / size.Y * 1080
		)
	end
	local function press(input: InputObject)
		if
			closing
			or (
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			)
		then
			return
		end
		local index = sectionAt(input.Position)
		if not index then
			return
		end
		if Assets.sections[index].locked then
			shakes[index] = os.clock()
			-- a red flash on the upright screen, whose halves cannot shake
			local half = halves[index]
			half.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
			half.BackgroundTransparency = 0.5
			tween(half, 0.35, { BackgroundTransparency = 1 })
			task.delay(0.36, function()
				half.BackgroundColor3 = Color3.new(0, 0, 0)
			end)
			return
		end
		if selected == index then
			return
		end
		selected = index
		SoundFx.play("class_select")
		for i, panel in panels do
			panel.ZIndex = if i == index then 10 else 3
			glows[i].Visible = i == index
			tween(scales[i], 0.25, { Scale = if i == index then 1.1 else 1 }, true)
		end
		tint()
		if not choose.Visible then
			choose.Visible = true
			chooseScale.Scale = 0
			tween(chooseScale, 0.25, { Scale = 1 }, true)
		end
	end
	local function move(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local index = sectionAt(input.Position)
			if index ~= hovered then
				hovered = index
				tint()
			end
		end
	end
	local function leave()
		hovered = nil
		tint()
	end
	for _, button in { hit, tallHit } do
		connect(button.InputEnded, press)
		connect(button.InputChanged, move)
		connect(button.MouseLeave, leave)
	end
	connect(choose.InputBegan, function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			choose.Image = Assets.choosePressed
			tween(chooseScale, 0.08, { Scale = 0.94 })
		end
	end)
	connect(choose.InputEnded, function()
		if not closing then
			choose.Image = Assets.choose
			tween(chooseScale, 0.15, { Scale = 1 }, true)
		end
	end)
	connect(choose.Activated, function()
		local index = selected
		if not index or closing then
			return
		end
		closing = true
		choose.Image = Assets.choosePressed
		tween(chooseScale, 0.08, { Scale = 0.94 })
		local section = Assets.sections[index]
		Remotes.event(Remotes.ChooseClass):FireServer(section.class, section.look)
		SoundFx.play("class_choose")
		local flash = Instance.new("Frame")
		flash.BorderSizePixel = 0
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 60
		flash.Parent = dim
		tween(flash, 0.3, { BackgroundTransparency = 1 })
		--[[ Then into the lobby (owner, 2026-10-27: "then it should load
		     the player into the lobby"): the game's loading screen while the
		     server puts the player at the lobby's spawn, then a fade. ]]
		task.delay(0.15, function()
			if not gui.Parent then
				return
			end
			local cover = ClassScreen.loadingCover(dim)
			task.delay(LOAD_SECONDS, function()
				if not gui.Parent then
					return
				end
				for _, d in cover:GetDescendants() do
					if d:IsA("ImageLabel") then
						tween(d, 0.4, { ImageTransparency = 1 })
					elseif d:IsA("TextLabel") then
						tween(d, 0.4, { TextTransparency = 1 })
					elseif d:IsA("Frame") then
						tween(d, 0.4, { BackgroundTransparency = 1 })
					end
				end
				tween(cover, 0.4, { BackgroundTransparency = 1 })
				for _, d in dim:GetChildren() do
					if d ~= cover and d:IsA("GuiObject") then
						d.Visible = false
					end
				end
				tween(dim, 0.4, { BackgroundTransparency = 1 })
				task.delay(0.45, function()
					if gui.Parent then
						gui:Destroy()
					end
				end)
			end)
		end)
	end)
	local function maybeOpen()
		if
			not shown
			and hasProfile
			and not hasLook
			and not RunPaused.beforeArrival()
			and Workspace:GetAttribute("InLobby") == true
		then
			shown = true
			player:SetAttribute("ClassSelecting", true)
			player:SetAttribute("InStation", true)
			gui.Enabled = true
		end
	end
	connect(Remotes.event(Remotes.ProfileChanged).OnClientEvent, function(profile)
		if type(profile) ~= "table" then
			return
		end
		hasProfile = true
		hasLook = profile.look ~= nil
		maybeOpen()
	end)
	connect(Workspace:GetAttributeChangedSignal("InLobby"), maybeOpen)
	--[[ The story's end asks the server for the tutorial, and the lobby stays
	     `InLobby` until the answer arrives. Asking again a moment later keeps
	     this screen from flashing up before a tutorial starts; after the
	     tutorial, `InLobby` itself opens it. ]]
	table.insert(
		connections,
		RunPaused.onChanged(function()
			if not RunPaused.beforeArrival() then
				task.delay(2, maybeOpen)
			end
		end)
	)
	connect(RunService.RenderStepped, function()
		if not gui.Enabled then
			return
		end
		local now = os.clock()
		choose.Position = UDim2.fromScale(0.5, (chooseY + math.sin(now * 2) * 4) / chooseOf)
		for i, began in shakes do
			local elapsed = now - began
			panels[i].Rotation = if elapsed < 0.35
				then math.sin(elapsed * 65) * 1.2 * (1 - elapsed / 0.35)
				else 0
			if elapsed >= 0.35 then
				shakes[i] = nil
			end
		end
	end)
	gui.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, motion in tweens do
			motion:Cancel()
		end
		if shown then
			player:SetAttribute("ClassSelecting", false)
			player:SetAttribute("InStation", false)
		end
	end)
	task.spawn(function()
		for _ = 1, 20 do
			if hasProfile or not gui.Parent then
				return
			end
			Remotes.event(Remotes.ProfileRequest):FireServer()
			task.wait(1)
		end
	end)
end
return ClassScreen
