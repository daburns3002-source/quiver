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
local CameraFit = require(ReplicatedStorage.Shared.Util.CameraFit)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)

local Device = require(script.Parent.Parent.Device)

local TopDownCamera = {}

local connection: RBXScriptConnection? = nil
local currentFocus: Vector3? = nil

local shakeMagnitude = 0
local shakeDecay = 0

--[[
	Where the camera sits relative to its focus, solved for this screen by
	`CameraFit` — a phone with its own, closer numbers. Recomputed every
	frame rather than cached, because the viewport changes when a phone
	rotates or a window is resized, and the maths is four trig calls.
]]
local function cameraOffset(camera: Camera): Vector3
	local config = Balance.Camera
	local viewport = camera.ViewportSize
	local phone = Device.isPhone()
	return CameraFit.offset(viewport, {
		pitch = config.pitch,
		fieldOfView = config.fieldOfView,
		fitWidth = if phone then config.phone.fitWidth else config.fitWidth,
		minVisibleDepth = if phone then config.phone.minVisibleDepth else config.minVisibleDepth,
	})
end

--[[
	How far the view reaches along the floor, ahead of and behind its focus,
	for a camera `offset` from it. The screen's top and bottom edges are rays
	at the pitch plus and minus half the vertical field of view; where they
	meet the floor is where the view ends. Ahead is negative Z, the way the
	camera faces.
]]
local function viewSpan(camera: Camera, offset: Vector3): (number, number)
	local height = offset.Y
	local back = offset.Z
	local pitch = math.atan2(height, back)
	local half = math.rad(camera.FieldOfView) / 2

	local near = back - height / math.tan(pitch + half)
	--[[ A top edge at or above the horizon never meets the floor; treat the
	     view as reaching arbitrarily far. ]]
	local far = if pitch - half > 1e-3 then back - height / math.tan(pitch - half) else -math.huge

	return far, near
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
	--[[ Bounded so the view stays inside the room and its end walls: the
	     focus may go no nearer an end than the view reaches past it. When
	     the view is longer than the room — an upright phone — it still
	     follows, about the room's middle and no further than
	     `Camera.longViewFollow` either way, showing the forest past the end
	     the player is not at (owner, 2026-10-22: "the camera should move to
	     follow the player just like it does on the desktop version"). ]]
	local offset = cameraOffset(camera)
	local far, near = viewSpan(camera, offset)
	local half = Balance.Arena.size.Z / 2
	-- Further past the north wall (−Z), where the exit gate stands.
	local lowest = -(half + Balance.Camera.gateMargin) - far
	local highest = half + Balance.Camera.wallMargin - near
	local reach = Balance.Camera.longViewFollow
	local target = if lowest > highest
		then Vector3.new(0, 0, (lowest + highest) / 2 + math.clamp(root.Position.Z, -reach, reach))
		else Vector3.new(0, 0, math.clamp(root.Position.Z, lowest, highest))
	--[[ In the lobby (`Config/Lobby`): it is wider and deeper than a room,
	     so the camera follows the player both ways, kept over the clearing. ]]
	if Workspace:GetAttribute("InLobby") == true then
		local centre = LobbyConfig.origin
		local halfX, halfZ = LobbyConfig.size.X / 2 - 18, LobbyConfig.size.Y / 2
		target = Vector3.new(
			math.clamp(root.Position.X, centre.X - halfX, centre.X + halfX),
			0,
			math.clamp(root.Position.Z, centre.Z - halfZ - far, centre.Z + halfZ - near)
		)
		-- a jump between the room and the lobby is a cut, not a pan
		if currentFocus and (currentFocus - target).Magnitude > 200 then
			currentFocus = target
		end
	elseif currentFocus and (currentFocus - target).Magnitude > 200 then
		currentFocus = target
	end

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
