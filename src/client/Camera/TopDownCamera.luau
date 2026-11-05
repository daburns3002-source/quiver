--!strict
--[[
	Fixed-angle top-down camera.

	The yaw never changes, which does two jobs at once. It keeps the arena
	readable so incoming projectiles can be seen early, and because Roblox's
	default controls are camera-relative, a fixed camera makes W mean the same
	world direction on every device. Thumbstick, WASD and gamepad all end up
	identical without a line of per-platform code.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CameraFit = require(ReplicatedStorage.Shared.Util.CameraFit)

local Device = require(script.Parent.Parent.Device)

local TopDownCamera = {}

local connection: RBXScriptConnection? = nil
local FLOOR_GUARD = "LobbyCameraFloor"
local currentFocus: Vector3? = nil
--[[ How far the lobby's camera zooms out, studs: near enough that the
     forest round the clearing fills the view rather than the world's edge
     (owner, 2026-10-27: "the player should not see this in the lobby"). ]]
local LOBBY_ZOOM = 45

local shakeMagnitude = 0
local shakeDecay = 0

--[[ How far above the ground the player last stood the lobby camera must
     stay, studs (owner, 2026-11-05: "make sure that the player cant look
     underneath the floor"). ]]
local FLOOR_CLEARANCE = 1.5
--[[ The height of the ground the player last stood on, kept through a jump
     so the guard does not lift with them. ]]
local lastGround: number? = nil

--[[
	Keeps Roblox's own lobby camera above the floor. The lobby's floor and
	scenery are built with CanQuery off, so the default camera's occlusion
	never sees them, and pitching the view up swung the camera under the
	courtyard, where the underside of everything showed. Run straight after
	Roblox's camera each frame: when the camera has gone below the ground the
	player stands on, it slides in along its line to the player until it is
	`FLOOR_CLEARANCE` above it, which reads as the camera resting on the
	ground the way a real one would.
]]
local function guardFloor(getRoot: () -> BasePart?)
	if Workspace:GetAttribute("InLobby") ~= true then
		lastGround = nil
		return
	end
	local camera = Workspace.CurrentCamera
	local root = getRoot()
	local humanoid = root and root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	if not camera or not root or not humanoid then
		return
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air or not lastGround then
		lastGround = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	end
	local least = (lastGround :: number) + FLOOR_CLEARANCE
	local at = camera.CFrame
	if at.Position.Y >= least then
		return
	end
	local focus = camera.Focus.Position
	local fromFocus = at.Position - focus
	local y = at.Position.Y
	if focus.Y > least and math.abs(focus.Y - y) > 1e-3 then
		-- along the line from the focus, to where it crosses the guard height
		local t = (focus.Y - least) / (focus.Y - y)
		camera.CFrame = at.Rotation + (focus + fromFocus * t)
	else
		camera.CFrame = at + Vector3.new(0, least - y, 0)
	end
end

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

	--[[ In the lobby the player has Roblox's own camera, turned and zoomed
	     as they like (owner, 2026-10-25: "have it be the normal roblox
	     camera angle"); `MoveController` walks relative to it there. The
	     next run takes the top-down camera back, cutting to the room. ]]
	if Workspace:GetAttribute("InLobby") == true then
		Players.LocalPlayer.CameraMaxZoomDistance = LOBBY_ZOOM
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
			local root = getRoot()
			local humanoid = root and root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
			if root and humanoid then
				camera.CameraSubject = humanoid
				--[[ Started at Roblox's own angle, behind the player and a
				     little above, rather than keeping the steep top-down
				     view it had. ]]
				local behind = root.CFrame.LookVector * Vector3.new(1, 0, 1)
				if behind.Magnitude < 1e-3 then
					behind = Vector3.new(0, 0, -1)
				end
				local head = root.Position + Vector3.new(0, 1.5, 0)
				camera.CFrame =
					CFrame.lookAt(head - behind.Unit * 12 + Vector3.new(0, 3.5, 0), head)
			end
		end
		currentFocus = nil
		return
	end

	--[[
		Re-asserted every frame rather than once in start(). Roblox's default
		camera script sets CameraType back to Custom when a character spawns,
		which would hand the player the over-the-shoulder camera mid-run.
	]]
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Balance.Camera.fieldOfView
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
	if currentFocus and (currentFocus - target).Magnitude > 200 then
		-- a jump from the lobby back to the room is a cut, not a pan
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
	RunService:UnbindFromRenderStep(FLOOR_GUARD)
	RunService:BindToRenderStep(FLOOR_GUARD, Enum.RenderPriority.Camera.Value + 1, function()
		guardFloor(getRoot)
	end)
end

function TopDownCamera.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	RunService:UnbindFromRenderStep(FLOOR_GUARD)
	lastGround = nil

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
