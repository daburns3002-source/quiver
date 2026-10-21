--!strict
--[[
	Fixed-angle top-down camera.

	The yaw never changes, which does two jobs at once. It keeps the arena
	readable so incoming projectiles can be seen early, and because Roblox's
	default controls are camera-relative, a fixed camera makes W mean the same
	world direction on every device. Thumbstick, WASD and gamepad all end up
	identical without a line of per-platform code.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local TopDownCamera = {}

local connection: RBXScriptConnection? = nil
local currentFocus: Vector3? = nil

local shakeMagnitude = 0
local shakeDecay = 0

local function step(deltaTime: number, getRoot: () -> BasePart?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	--[[
		Re-asserted every frame rather than once in start(). Roblox's default
		camera script sets CameraType back to Custom when a character spawns,
		which would hand the player the over-the-shoulder camera mid-run.
	]]
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local root = getRoot()
	if not root then
		return
	end

	local target = root.Position

	if not currentFocus then
		currentFocus = target
	end

	--[[
		Framerate-independent smoothing. A plain lerp by a constant factor would
		make the camera lag more on a 30fps phone than on a 144Hz desktop, which
		changes how early a player can read a charge.
	]]
	local alpha = 1 - math.exp(-Balance.Camera.followSharpness * deltaTime)
	local focus = (currentFocus :: Vector3):Lerp(target, alpha)
	currentFocus = focus

	local offset = Balance.Camera.offset

	if shakeMagnitude > 0 then
		shakeMagnitude = math.max(0, shakeMagnitude - shakeDecay * deltaTime)

		offset += Vector3.new(
			(math.random() * 2 - 1) * shakeMagnitude,
			(math.random() * 2 - 1) * shakeMagnitude,
			0
		)
	end

	camera.CFrame = CFrame.lookAt(focus + offset, focus)
end

function TopDownCamera.start(getRoot: () -> BasePart?)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Balance.Camera.fieldOfView
	end

	if connection then
		connection:Disconnect()
	end

	connection = RunService.RenderStepped:Connect(function(deltaTime)
		step(deltaTime, getRoot)
	end)
end

function TopDownCamera.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end

	currentFocus = nil
end

--[[ Snaps the camera to the character, for respawns. ]]
function TopDownCamera.reset()
	currentFocus = nil
end

function TopDownCamera.shake(magnitude: number, duration: number)
	if duration <= 0 then
		return
	end

	shakeMagnitude = math.max(shakeMagnitude, magnitude)
	shakeDecay = magnitude / duration
end

return TopDownCamera
