--!strict
--[[
	On-screen thumbstick for touch devices.

	Dynamic rather than fixed: the stick appears wherever the finger lands.
	That is what Archero does, and move-or-shoot needs it — this game asks the
	player to start and stop moving constantly, and a fixed stick costs them a
	glance and a reach before every reposition. See CLAUDE.md, "Feel beats
	correctness in the input path".

	Presentation and input only. It reports a direction; MoveController decides
	what to do with it, and the server decides whether anything may be fired.

	Listens through UserInputService rather than a full-screen capture frame so
	it never sits on top of the HUD, and respects `gameProcessedEvent` so a
	touch the UI already consumed does not also walk the character.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Thumbstick = {}

local player = Players.LocalPlayer

--[[
	Travel from the touch origin, in pixels, that counts as full tilt. Derived
	from the screen's short edge so a tablet does not get a stick that feels
	cramped and a small phone does not get one that needs a whole thumb-reach.
]]
local RADIUS_FRACTION = 0.16
local MIN_RADIUS = 56
local MAX_RADIUS = 132

--[[
	Pixels of travel before the stick reports anything at all. This is not
	cosmetic: a stationary tap that registered as movement would stop the
	archer firing, which is the one thing the player would never forgive.
	Output is rescaled past this, so the first usable pixel still maps to a
	small push rather than a jump.
]]
local DEADZONE_PIXELS = 8

local BASE_COLOUR = Color3.fromRGB(232, 236, 245)
local KNOB_COLOUR = Color3.fromRGB(255, 255, 255)
local BASE_TRANSPARENCY = 0.72
local KNOB_TRANSPARENCY = 0.35
local FADE_DURATION = 0.12

--[[ Knob diameter as a fraction of the ring's. ]]
local KNOB_SCALE = 0.42

local gui: ScreenGui? = nil
local base: Frame? = nil
local knob: Frame? = nil

--[[ The radius the rings are currently drawn at. Tracked so the visual can
     follow a viewport change rather than keeping whatever `start` measured. ]]
local drawnRadius = 0

local activeTouch: InputObject? = nil
local origin = Vector2.zero
local direction = Vector2.zero
local connections: { RBXScriptConnection } = {}

local function radius(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local shortEdge = math.min(viewport.X, viewport.Y)

	return math.clamp(shortEdge * RADIUS_FRACTION, MIN_RADIUS, MAX_RADIUS)
end

local function circle(name: string, diameter: number, colour: Color3, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(diameter, diameter)
	frame.BackgroundColor3 = colour
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Visible = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	-- Stored so show() knows what to fade back to.
	frame:SetAttribute("RestTransparency", transparency)

	return frame
end

local function setVisible(visible: boolean)
	local baseFrame = base
	local knobFrame = knob

	if not baseFrame or not knobFrame then
		return
	end

	if visible then
		baseFrame.Visible = true
		knobFrame.Visible = true
	end

	local info = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local baseTarget = if visible then baseFrame:GetAttribute("RestTransparency") :: number else 1
	local knobTarget = if visible then knobFrame:GetAttribute("RestTransparency") :: number else 1

	TweenService:Create(baseFrame, info, { BackgroundTransparency = baseTarget }):Play()

	local knobTween = TweenService:Create(knobFrame, info, { BackgroundTransparency = knobTarget })
	knobTween:Play()

	if visible then
		return
	end

	--[[ Hidden only once faded, so a quick tap does not leave a circle behind
	     but a re-touch mid-fade can still cancel it. ]]
	knobTween.Completed:Once(function()
		if not activeTouch then
			baseFrame.Visible = false
			knobFrame.Visible = false
		end
	end)
end

local function layout(current: Vector2)
	local baseFrame = base
	local knobFrame = knob

	if not baseFrame or not knobFrame then
		return
	end

	local limit = radius()

	--[[
		Resized here rather than only in `start`, because the viewport can
		change under us — an orientation change, a device-simulator switch, a
		desktop window resize. `limit` below is recomputed every move, so a
		ring left at the radius measured at startup would no longer match where
		the knob actually clamps: it would escape the ring, and full tilt would
		sit outside the visual.
	]]
	if limit ~= drawnRadius then
		drawnRadius = limit
		baseFrame.Size = UDim2.fromOffset(limit * 2, limit * 2)
		knobFrame.Size = UDim2.fromOffset(limit * 2 * KNOB_SCALE, limit * 2 * KNOB_SCALE)
	end

	local delta = current - origin
	local distance = delta.Magnitude

	baseFrame.Position = UDim2.fromOffset(origin.X, origin.Y)

	if distance < 1e-3 then
		knobFrame.Position = UDim2.fromOffset(origin.X, origin.Y)
		direction = Vector2.zero
		return
	end

	local unit = delta / distance
	local clamped = math.min(distance, limit)
	local knobAt = origin + unit * clamped

	knobFrame.Position = UDim2.fromOffset(knobAt.X, knobAt.Y)

	if distance <= DEADZONE_PIXELS then
		direction = Vector2.zero
		return
	end

	--[[ Rescaled past the dead zone so control is continuous from the first
	     pixel that counts, and Y is flipped because screen space grows
	     downwards while the move axis grows up the screen. ]]
	local travel = (clamped - DEADZONE_PIXELS) / math.max(limit - DEADZONE_PIXELS, 1)
	direction = Vector2.new(unit.X, -unit.Y) * math.clamp(travel, 0, 1)
end

local function release()
	activeTouch = nil
	direction = Vector2.zero
	setVisible(false)
end

--[[ The current tilt: zero length when untouched, otherwise up to one, with
     +X right and +Y up the screen to match a gamepad thumbstick. ]]
function Thumbstick.direction(): Vector2
	return direction
end

function Thumbstick.start()
	Thumbstick.stop()

	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("Thumbstick")
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("ScreenGui")
	created.Name = "Thumbstick"
	created.ResetOnSpawn = false
	--[[ Coordinates have to match UserInputService touch positions, which are
	     viewport-relative, so the top inset must not shift this. ]]
	created.IgnoreGuiInset = true
	created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Below the HUD: the health bar must stay readable through a drag.
	created.DisplayOrder = -1

	drawnRadius = radius()

	local diameter = drawnRadius * 2
	local baseFrame = circle("Base", diameter, BASE_COLOUR, BASE_TRANSPARENCY)
	baseFrame.Parent = created

	local knobFrame = circle("Knob", diameter * KNOB_SCALE, KNOB_COLOUR, KNOB_TRANSPARENCY)
	knobFrame.Parent = created

	created.Parent = playerGui

	gui = created
	base = baseFrame
	knob = knobFrame

	table.insert(
		connections,
		UserInputService.TouchStarted:Connect(function(input, processed)
			-- One finger steers; a second touch is left for future buttons.
			if processed or activeTouch then
				return
			end

			if not input then
				return
			end

			-- Read before the assignment below: storing `input` into an
			-- optional upvalue drops the refinement that made it non-nil.
			local position = input.Position

			activeTouch = input
			origin = Vector2.new(position.X, position.Y)
			layout(origin)
			setVisible(true)
		end)
	)

	table.insert(
		connections,
		UserInputService.TouchMoved:Connect(function(input)
			if input ~= activeTouch then
				return
			end

			layout(Vector2.new(input.Position.X, input.Position.Y))
		end)
	)

	--[[ Deliberately ignores `processed` on release: a finger lifted over UI
	     still has to clear, or the archer walks for ever and never fires. ]]
	table.insert(
		connections,
		UserInputService.TouchEnded:Connect(function(input)
			if input ~= activeTouch then
				return
			end

			release()
		end)
	)

	table.insert(connections, UserInputService.WindowFocusReleased:Connect(release))
end

function Thumbstick.stop()
	for _, connection in connections do
		connection:Disconnect()
	end

	table.clear(connections)

	activeTouch = nil
	direction = Vector2.zero
	drawnRadius = 0

	if gui then
		gui:Destroy()
	end

	gui = nil
	base = nil
	knob = nil
end

return Thumbstick
