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

--[[
	Where the camera sits relative to its focus, solved for this screen.

	The distance is whatever makes `fitWidth` studs of ground span the screen
	side to side, from the screen's own aspect — so a tall phone, a short
	phone and a tablet all show the room's full width, which a fixed offset
	can only do for one of them. On a landscape screen that would zoom right
	in, so it never shows less depth than `minVisibleDepth`.

	Recomputed every frame rather than cached, because the viewport changes
	when a phone rotates or a window is resized, and the maths is four trig
	calls.
]]
local function cameraOffset(camera: Camera): Vector3
	local config = Balance.Camera
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 9 / 16

	local halfVertical = math.rad(config.fieldOfView) / 2
	local tanHalfHorizontal = math.tan(halfVertical) * aspect

	local toFitWidth = (config.fitWidth / 2) / tanHalfHorizontal
	local toFitDepth = (config.minVisibleDepth / 2) / math.tan(halfVertical)
	local distance = math.max(toFitWidth, toFitDepth)

	local pitch = math.rad(config.pitch)
	return Vector3.new(0, math.sin(pitch), math.cos(pitch)) * distance
end

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

	--[[
		Locked to the room's centre line sideways, and following the player
		only in depth, clamped short of the back and front walls.

		That is Archero 2's camera, measured: the wall lamp posts in the
		footage shift together up and down as the player moves and never
		sideways. Locking X is also what keeps the room's full width framed —
		a camera that followed the player left would push the far wall off the
		screen, which is precisely what fitting the width exists to prevent.
	]]
	local limit = math.max(0, Balance.Arena.size.Z / 2 - Balance.Camera.edgeMargin)
	local target = Vector3.new(0, 0, math.clamp(root.Position.Z, -limit, limit))

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

	local offset = cameraOffset(camera)

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
	shakeMagnitude = 0
	shakeDecay = 0
end

--[[ Snaps the camera to the character, for respawns. ]]
function TopDownCamera.reset()
	currentFocus = nil
	--[[ Dropped too: a shake still running from the hit that killed the player
	     would otherwise carry into the respawn. ]]
	shakeMagnitude = 0
	shakeDecay = 0
end

function TopDownCamera.shake(magnitude: number, duration: number)
	if duration <= 0 or magnitude <= 0 then
		return
	end

	shakeMagnitude = math.max(shakeMagnitude, magnitude)

	--[[
		Derived from the magnitude actually in play, not the incoming one. A
		weaker shake landing part way through a stronger one used to overwrite
		the rate with its own, far smaller, value — which stretched the
		stronger shake's tail instead of shortening it. Deriving it from the
		result guarantees whatever is on screen clears within `duration`.

		`magnitude <= 0` returns early for the same reason: a zero-magnitude
		call produced a zero decay rate, and any shake already running then
		never decayed at all.
	]]
	shakeDecay = shakeMagnitude / duration
end

return TopDownCamera
