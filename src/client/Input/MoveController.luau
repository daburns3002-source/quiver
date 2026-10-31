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

	In the lobby there is no dash (owner, 2026-10-26: "let players sprint and
	jump in the lobby instead of dash"): Shift, a gamepad's X (or a click of
	its left stick) or the phone's SPRINT button runs, and Space, A or JUMP
	jumps (`Config/Lobby.sprint`, `jumpHeight`; `Input/LobbyButtons`). The
	server allows the jump only there (`RunSession.allowJump`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Dash = require(script.Parent.Dash)
local DashButton = require(script.Parent.DashButton)
local LobbyButtons = require(script.Parent.LobbyButtons)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
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

--[[ The lobby's sprint: held keys, and a toggle (the gamepad's stick click,
     the phone's SPRINT) that lasts until pressed again. ]]
local SPRINT_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.LeftShift] = true,
	[Enum.KeyCode.RightShift] = true,
	[Enum.KeyCode.ButtonX] = true,
}
local sprintToggled = false
--[[ The character whose Jumping state was last set here, and to what. ]]
local jumpSetFor: Humanoid? = nil
local jumpSetTo: boolean? = nil

local function inLobby(): boolean
	return Workspace:GetAttribute("InLobby") == true
end

local function sprinting(): boolean
	if sprintToggled then
		return true
	end
	for keyCode in SPRINT_KEYS do
		if held[keyCode] then
			return true
		end
	end
	return false
end

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
	local up, right = SCREEN_UP, SCREEN_RIGHT
	--[[ In the lobby the camera is Roblox's own and turns (`TopDownCamera`),
	     so up the screen is wherever it looks, flattened. ]]
	local camera = Workspace.CurrentCamera
	if Workspace:GetAttribute("InLobby") == true and camera then
		local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 1e-3 then
			up = look.Unit
			right = Vector3.new(-up.Z, 0, up.X)
		end
	end
	local flat = (right * axis.X + up * axis.Y)
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
	     input that would move the player far enough to matter. Nor in the
	     lobby, which jumps instead. ]]
	if RunPaused.get() or inLobby() then
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

--[[ A jump, in the lobby only: Roblox's own, through the Humanoid.

     Through `ChangeState`, not `Humanoid.Jump`. `Jump` is a request flag that
     Roblox's own control scripts write every frame from whatever their jump
     input is doing, and on a touch screen that input is live: the flag set
     here was read back as false before the physics step ever saw it, so the
     phone's JUMP button did nothing while the spacebar — which goes through
     those same control scripts — worked (owner, 2026-10-27: "jump did not
     work"). `ChangeState` is not a flag and nothing overwrites it.

     `SetStateEnabled(Jumping, ...)` is still the gate, switched in `step`, so
     this cannot jump in a run. ]]
local function requestJump()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		humanoid
		and inLobby()
		and not RunPaused.get()
		and player:GetAttribute("ClassSelecting") ~= true
	then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

--[[ Space, A and the phone's button: a jump in the lobby, a dash in a run. ]]
local function pressAction()
	if inLobby() then
		requestJump()
	else
		requestDash()
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

	--[[ The character's physics are this client's, so the Jumping state is
	     switched here too, as the server switches the jump's height. ]]
	local lobby = inLobby()
	if jumpSetFor ~= humanoid or jumpSetTo ~= lobby then
		jumpSetFor, jumpSetTo = humanoid, lobby
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, lobby)
	end
	if not lobby then
		sprintToggled = false
	end

	--[[
		Frozen while a card screen is up.

		The server has already stopped the world, so walking here moves the
		player through a room nothing else in is running — they reappear
		somewhere else when they choose, having crossed ground that was never
		contested. `Move(zero)` rather than an early return, so the Humanoid
		is actively told to stop instead of coasting on its last direction.
	]]
	if RunPaused.get() or player:GetAttribute("ClassSelecting") == true then
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
	if lobby and sprinting() then
		rush = LobbyConfig.sprint
	end
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
	sprintToggled = false
end

function MoveController.start()
	MoveController.stop()

	Thumbstick.start()
	DashButton.start(requestDash)
	LobbyButtons.start(requestJump, function()
		sprintToggled = not sprintToggled
	end, sprinting)

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

			if KEY_VECTORS[input.KeyCode] or SPRINT_KEYS[input.KeyCode] then
				held[input.KeyCode] = true
				return
			end

			if input.KeyCode == Enum.KeyCode.ButtonL3 and inLobby() then
				sprintToggled = not sprintToggled
				return
			end

			--[[ Space and the gamepad's bottom face button. Jumping was taken
			     out of the run, which is what leaves space free — it is the
			     key every player already reaches for to get out of the way.
			     In the lobby, where nothing needs dodging, it jumps. ]]
			if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
				pressAction()
			end
		end)
	)

	--[[ Deliberately ignores `processed`: a key released while the chat bar has
	     focus still has to clear, or the archer stays stuck walking. ]]
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if KEY_VECTORS[input.KeyCode] or SPRINT_KEYS[input.KeyCode] then
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
	LobbyButtons.stop()
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
