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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Dash = require(script.Parent.Dash)
local DashButton = require(script.Parent.DashButton)
local PlayerStats = require(script.Parent.Parent.PlayerStats)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunPaused = require(script.Parent.Parent.RunPaused)
local Shove = require(script.Parent.Shove)
local SoundFx = require(script.Parent.Parent.Fx.SoundFx)
local Thumbstick = require(script.Parent.Thumbstick)
local WeaponPose = require(script.Parent.Parent.Fx.WeaponPose)

local MoveController = {}

local player = Players.LocalPlayer
local dashStarted = Remotes.event(Remotes.DashStarted)

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

--[[
	Asks for a dash in whichever direction the player is currently expressing,
	falling back to where the character is pointed.

	Reads input at the moment of the press rather than being handed a
	direction, because the press and the input read have to be the same frame
	— a dash that uses last frame's heading goes somewhere the player did not
	ask for, and at 89 studs a second that is very visible.
]]
local function requestDash()
	--[[ No dashing out from behind the cards either. The dash is the one
	     input that would move the player far enough to matter. ]]
	if RunPaused.get() then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	if Dash.request(os.clock(), desiredDirection(), root.CFrame.LookVector) then
		SoundFx.play("dash")
		--[[ The server's Earthbreaker slams where this dash ends; it is told
		     the dash began, and decides for itself whether it counts. ]]
		dashStarted:FireServer()
		if (PlayerStats.get().abilities.Earthbreaker or 0) > 0 then
			--[[ The leap and slam (the owner's RubySword kit), as the dash
			     ends; its arc is in the animation, and the server's slam lands
			     on its Impact marker. ]]
			task.delay(Balance.Player.dash.duration, WeaponPose.playSpecial, "earthbreaker")
		end
	end
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

	--[[
		Frozen while a card screen is up.

		The server has already stopped the world, so walking here moves the
		player through a room nothing else in is running — they reappear
		somewhere else when they choose, having crossed ground that was never
		contested. `Move(zero)` rather than an early return, so the Humanoid
		is actively told to stop instead of coasting on its last direction.
	]]
	if RunPaused.get() then
		humanoid.WalkSpeed = PlayerStats.get().moveSpeed
		humanoid:Move(Vector3.zero, false)
		return
	end

	--[[ A boss's grab holds the player still, and its shove carries them,
	     ahead of anything they or a dash ask for: being hit is not optional.
	     Driven through the Humanoid like the dash, so walls still stop it. ]]
	local now = os.clock()
	if Shove.isHeld(now) then
		humanoid:Move(Vector3.zero, false)
		return
	end
	local pushed, pushSpeed = Shove.current(now)
	if pushed then
		humanoid.WalkSpeed = pushSpeed
		humanoid:Move(pushed, false)
		return
	end

	local heading, speed = Dash.current(now)

	--[[
		A dash drives the same Humanoid at a higher speed rather than moving
		the character directly.

		That is the whole reason it cannot clip: walls, pillars and the arena
		boundary are already solved for walking, and a dash that teleported or
		set CFrame would have to solve them again and would get it wrong at
		89 studs a second. It also means the server sees a dash as ordinary
		movement, so the archer stops firing while it happens without anything
		being taught about dashing.
	]]
	if heading then
		humanoid.WalkSpeed = speed
		humanoid:Move(heading, false)
		return
	end

	--[[ From the replicated stats, not from config: Agility raises it, and
	     this line runs every frame so it would otherwise undo the ability
	     the moment it was drafted. Faster while the cleared room's gate is
	     open, which the server says (`ExitOpen`). ]]
	local rush = if workspace:GetAttribute("ExitOpen") == true then Balance.Player.exitRush else 1
	humanoid.WalkSpeed = PlayerStats.get().moveSpeed * rush

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
	DashButton.start(requestDash)

	--[[ A dash in flight must not survive a death: the cooldown belongs to the
	     life that spent it, and a heading captured before a respawn points
	     somewhere that no longer means anything. ]]
	table.insert(
		connections,
		player.CharacterAdded:Connect(function()
			Dash.reset()
			Shove.reset()
		end)
	)

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end

			if KEY_VECTORS[input.KeyCode] then
				held[input.KeyCode] = true
				return
			end

			--[[ Space and the gamepad's bottom face button. Jumping was taken
			     out of the run, which is what leaves space free — it is the
			     key every player already reaches for to get out of the way. ]]
			if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
				requestDash()
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
	DashButton.stop()
	Dash.reset()
	Shove.reset()
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
