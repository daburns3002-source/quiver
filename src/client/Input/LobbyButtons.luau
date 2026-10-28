--!strict
--[[
	The lobby's touch buttons (owner, 2026-10-26: "let players sprint and
	jump in the lobby instead of dash"): JUMP where the dash button stands in
	a run, and SPRINT above it, a toggle that glows gold while on. Touch only,
	and only in the lobby; the dash button hides there (`DashButton`).

	Real `TextButton`s, like the dash button, so a finger on one is processed
	and the movement stick (`Thumbstick`) never takes it.

	Their sizes are `Config/Hud.phone` (`lobbyJumpSize`, `lobbySprintSize`,
	`lobbyGap`), not constants here, because they are of a piece with the dash
	button they stand in for and with the stack above them.

	JUMP's held look is tracked here rather than read off `GuiState`, for the
	same reason as the dash button's: a finger that slides off the button
	before it lifts can leave Roblox's own state at `Press` for good, and this
	one did — it painted the face dark on `GuiState == Press` and nothing ever
	painted it back.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Hud = require(ReplicatedStorage.Shared.Config.Hud)

local HudLayout = require(script.Parent.Parent.UI.HudLayout)

local LobbyButtons = {}

--[[ Screen pixels, from `Config/Hud.phone`: JUMP where the dash button
     stands, SPRINT smaller above it. ]]
local JUMP_SIZE = Hud.phone.lobbyJumpSize
local SPRINT_SIZE = Hud.phone.lobbySprintSize
local GAP = Hud.phone.lobbyGap

local INK = Color3.fromRGB(24, 16, 10)
local JUMP_COLOUR = Color3.fromRGB(70, 176, 58)
local SPRINT_OFF = Color3.fromRGB(78, 52, 32)
local SPRINT_ON = Color3.fromRGB(255, 206, 74)

local gui: ScreenGui? = nil
local connections: { RBXScriptConnection } = {}
--[[ Whether a finger is down on JUMP. Its look only. ]]
local pressing = false

function LobbyButtons.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if gui then
		gui:Destroy()
		gui = nil
	end
	pressing = false
end

--[[ A blocky square button: an ink border, a face, its word. ]]
local function button(parent: Instance, name: string, text: string, size: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(size, size)
	b.AnchorPoint = Vector2.new(1, 1)
	b.BackgroundColor3 = INK
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	--[[ No gamepad adornment on a touch control: a pad plugged into a phone
	     would otherwise leave Roblox's own selection box round it. ]]
	b.Selectable = false
	b.Text = ""
	b.Parent = parent
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Position = UDim2.fromOffset(4, 4)
	face.Size = UDim2.new(1, -8, 1, -8)
	face.BorderSizePixel = 0
	face.Parent = b
	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.BackgroundTransparency = 1
	word.Position = UDim2.fromScale(0.1, 0.3)
	word.Size = UDim2.fromScale(0.8, 0.4)
	word.FontFace = Font.fromEnum(Enum.Font.Arcade)
	word.TextScaled = true
	word.TextColor3 = Color3.new(1, 1, 1)
	word.Text = text
	word.Parent = face
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Parent = word
	return b
end

--[[ `jump` on JUMP, `toggleSprint` on SPRINT; `sprinting` says whether the
     sprint is on, from whatever turned it on (Shift on a keyboard too). ]]
function LobbyButtons.start(jump: () -> (), toggleSprint: () -> (), sprinting: () -> boolean)
	LobbyButtons.stop()
	if not UserInputService.TouchEnabled then
		return
	end

	local created = Instance.new("ScreenGui")
	created.Name = "LobbyButtons"
	created.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	created.ResetOnSpawn = false
	created.DisplayOrder = 20
	created.Enabled = false
	created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = created

	local jumpButton = button(created, "Jump", "JUMP", JUMP_SIZE)
	local sprintButton = button(created, "Sprint", "SPRINT", SPRINT_SIZE)
	local jumpFace = jumpButton:FindFirstChild("Face") :: Frame
	local sprintFace = sprintButton:FindFirstChild("Face") :: Frame
	jumpFace.BackgroundColor3 = JUMP_COLOUR

	local function place(at: UDim2)
		jumpButton.Position = at
		-- SPRINT stands over JUMP, their right edges in line
		sprintButton.Position = at - UDim2.fromOffset(0, JUMP_SIZE + GAP)
	end
	place(UDim2.new(1, -28, 1, -28))
	local layoutConnection = HudLayout.bind(function(layout)
		place(layout.dashButtonPosition)
	end)
	if layoutConnection then
		table.insert(connections, layoutConnection)
	end

	table.insert(
		connections,
		jumpButton.MouseButton1Down:Connect(function()
			pressing = true
			jump()
		end)
	)
	table.insert(connections, sprintButton.MouseButton1Down:Connect(toggleSprint))

	--[[ Every way a press can end, as the dash button has them: the lift and
	     the finger sliding off, then the two that Roblox never reports to the
	     button at all. ]]
	local function release()
		pressing = false
	end
	table.insert(connections, jumpButton.MouseButton1Up:Connect(release))
	table.insert(connections, jumpButton.MouseLeave:Connect(release))
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				release()
			end
		end)
	)
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(release))

	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local showing = Workspace:GetAttribute("InLobby") == true
			created.Enabled = showing
			-- hidden mid-press, no input event is coming for that finger
			if pressing and not showing then
				pressing = false
			end
			local on = sprinting()
			sprintFace.BackgroundColor3 = if on then SPRINT_ON else SPRINT_OFF
			jumpFace.BackgroundColor3 = if pressing
				then JUMP_COLOUR:Lerp(Color3.new(0, 0, 0), 0.3)
				else JUMP_COLOUR
		end)
	)
end

return LobbyButtons
