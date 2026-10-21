--!strict
--[[
	Movement input.

	Roblox's default PlayerModule is camera-relative, which is the wrong model
	for a fixed-yaw top-down camera: it would also fight the scripted camera
	for CameraType every time a character spawns. This drives the Humanoid
	directly in world space instead, so W, a thumbstick push and a gamepad
	stick all mean the same world direction on every device. Combined with
	auto-aim that means no platform has an advantage — see
	docs/RESEARCH-archero.md, "Cross-platform input parity".

	Nothing here is authoritative. The server reads the replicated
	Humanoid.MoveDirection and decides whether a volley goes out; this module
	only decides where the character walks.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Thumbstick = require(script.Parent.Thumbstick)

local MoveController = {}

local player = Players.LocalPlayer

--[[
	World-space screen axes. The camera's yaw never changes, so -Z is always
	"up the screen" and these never have to be rebuilt from the camera.
]]
local SCREEN_UP = Vector3.new(0, 0, -1)
local SCREEN_RIGHT = Vector3.new(1, 0, 0)

--[[
	Below this magnitude a stick counts as released. A thumbstick idles noisy,
	and a resting stick that reads as movement would mean the archer never
	fires at all.
]]
local STICK_DEADZONE = 0.12

local KEY_VECTORS: { [Enum.KeyCode]: Vector2 } = {
	[Enum.KeyCode.W] = Vector2.new(0, 1),
	[Enum.KeyCode.Up] = Vector2.new(0, 1),
	[Enum.KeyCode.S] = Vector2.new(0, -1),
	[Enum.KeyCode.Down] = Vector2.new(0, -1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
}

local held: { [Enum.KeyCode]: boolean } = {}
local stick = Vector2.zero
local connections: { RBXScriptConnection } = {}

--[[ Keyboard and stick are summed rather than prioritised, so a player on a
     laptop with a controller plugged in is never fighting a dead input. ]]
local function desiredDirection(): Vector3
	local axis = Vector2.zero

	for keyCode, vector in KEY_VECTORS do
		if held[keyCode] then
			axis += vector
		end
	end

	if stick.Magnitude > STICK_DEADZONE then
		axis += stick
	end

	--[[ Already dead-zoned and rescaled in pixel space by Thumbstick, so it is
	     added as it comes rather than gated a second time here. ]]
	local touch = Thumbstick.direction()

	if touch.Magnitude > 0 then
		axis += touch
	end

	if axis.Magnitude < 1e-3 then
		return Vector3.zero
	end

	--[[
		Normalised, so holding W and D is not faster than holding W. Diagonal
		speed-up would quietly change how long a player can afford to stand
		still, which is the one thing this whole game is tuned around.
	]]
	local flat = (SCREEN_RIGHT * axis.X + SCREEN_UP * axis.Y)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
end

local function step()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- World space, not camera-relative: the second argument must stay false.
	humanoid:Move(desiredDirection(), false)
end

--[[ Clears every held key. Called on focus loss, because a key whose release
     we never saw would otherwise pin the archer in "moving" for ever and it
     would never fire again. ]]
local function releaseAll()
	table.clear(held)
	stick = Vector2.zero
end

function MoveController.start()
	MoveController.stop()

	Thumbstick.start()

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end

			if KEY_VECTORS[input.KeyCode] then
				held[input.KeyCode] = true
			end
		end)
	)

	--[[ Deliberately ignores `processed`: a key released while the chat bar has
	     focus still has to clear, or the archer stays stuck walking. ]]
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if KEY_VECTORS[input.KeyCode] then
				held[input.KeyCode] = nil
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input, processed)
			if processed or input.KeyCode ~= Enum.KeyCode.Thumbstick1 then
				return
			end

			stick = Vector2.new(input.Position.X, input.Position.Y)
		end)
	)

	table.insert(connections, UserInputService.WindowFocusReleased:Connect(releaseAll))

	--[[ Fire resumes within one frame of release, so the input read has to sit
	     on the render step alongside the firing prediction, not on Heartbeat. ]]
	table.insert(connections, RunService.RenderStepped:Connect(step))
end

function MoveController.stop()
	for _, connection in connections do
		connection:Disconnect()
	end

	table.clear(connections)
	Thumbstick.stop()
	releaseAll()
end

--[[ Whether this device has any way to drive the controller above: keyboard,
     gamepad, or the on-screen thumbstick. Kept so the caller can say so out
     loud rather than silently shipping a player who cannot move. ]]
function MoveController.hasSupportedInput(): boolean
	return UserInputService.KeyboardEnabled
		or UserInputService.GamepadEnabled
		or UserInputService.TouchEnabled
end

return MoveController
