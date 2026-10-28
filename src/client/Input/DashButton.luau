--!strict
--[[
	The on-screen dash button.

	Touch only. A keyboard player has the spacebar and a gamepad player has a
	face button, and putting a permanent control on their screen would be
	clutter they cannot dismiss.

	It sits bottom-right because the thumbstick is driven with the left thumb
	and this has to be reachable without crossing hands or looking down. Being
	a real `TextButton` matters for more than hit-testing: Roblox marks a touch
	it handles as processed, and `Thumbstick` refuses processed touches, so a
	finger landing here cannot also drag the movement stick out from under it.

	The ring is the cooldown. It is a fill rather than a number because the
	player reads it in peripheral vision while looking at a fan of projectiles
	somewhere else on the screen.

	**The ring carries readiness; the face never does.** The face used to be
	painted the ready colour — a saturated light blue at near-full opacity —
	the whole time the dash was off cooldown, which is most of a fight. A
	round button sitting permanently lit under the thumb does not read as
	"ready", it reads as held down (owner, 2026-10-27: "the dash button in
	game is highlighted blue and the highlight never clears"). So the face
	stays dark and only the ring and the chevron brighten.

	The press is the one thing allowed to change the face, and it is tracked
	here rather than read off `GuiState`: a finger that leaves the button
	before it lifts can leave Roblox's own state at `Press` for good, so every
	way a press can end clears it — the lift, the touch ending anywhere on the
	screen, the finger sliding off, the window losing focus, and the button
	being taken away when the lobby hides it.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Dash = require(script.Parent.Dash)
local HudLayout = require(script.Parent.Parent.UI.HudLayout)

local DashButton = {}

--[[ Studs of screen, not of world. Sized for a thumb: Roblox's own guidance
     and every mobile action game land near this, and smaller is a miss. ]]
local SIZE = 92
local MARGIN = 28

local gui: ScreenGui? = nil
local connections: { RBXScriptConnection } = {}

--[[ The ring and the chevron, which brighten as the dash comes back. ]]
local READY_COLOUR = Color3.fromRGB(120, 210, 255)
--[[ The face, which does not: one dark disc, a little more solid when the
     dash is in, and darker still while it is held. ]]
local FACE_COLOUR = Color3.fromRGB(44, 54, 68)
local PRESS_COLOUR = Color3.fromRGB(26, 32, 42)
local FACE_COOLING = 0.5
local FACE_READY = 0.34
local FACE_PRESSED = 0.16

--[[ Set by `start`, called when the button is pressed. Kept as a hook rather
     than calling Dash directly so MoveController stays the only thing that
     knows what a dash does to a character. ]]
local onPressed: (() -> ())? = nil

--[[ Whether a finger is down on the button right now. Only the face's look
     depends on it; the dash itself has already fired by then. ]]
local pressing = false

function DashButton.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)

	if gui then
		gui:Destroy()
		gui = nil
	end

	onPressed = nil
	pressing = false
end

--[[ `pressed` is invoked on every tap, ready or not. Whether a dash is
     actually available is Dash's decision, not this module's — asking twice
     is how the two drift apart. ]]
function DashButton.start(pressed: () -> ())
	DashButton.stop()

	if not UserInputService.TouchEnabled then
		return
	end

	onPressed = pressed
	pressing = false

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local created = Instance.new("ScreenGui")
	created.Name = "DashButton"
	--[[ Inside the phone's safe area, clear of the home bar and rounded
	     corners: ignoring it, the bottom of the HUD ran under them and was
	     cut off (owner, 2026-10-22). ]]
	created.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	created.ResetOnSpawn = false
	--[[ Under the hit vignette, which is a full-screen flash, and over the
	     world. ]]
	created.DisplayOrder = 20
	created.Parent = playerGui
	gui = created

	local button = Instance.new("TextButton")
	button.Name = "Dash"
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -MARGIN, 1, -MARGIN)
	--[[ Lifted above the HUD stack on a narrow phone, where the stack
	     reaches under the corner. ]]
	local layoutConnection = HudLayout.bind(function(layout)
		button.Position = layout.dashButtonPosition
	end)
	if layoutConnection then
		table.insert(connections, layoutConnection)
	end
	button.BackgroundColor3 = FACE_COLOUR
	button.BackgroundTransparency = FACE_COOLING
	--[[ Off, as it has always been: Roblox's own press tint is a grey wash
	     over the whole disc, and the ring would wash with it. ]]
	button.AutoButtonColor = false
	--[[ No gamepad adornment on a touch control. Left on, a pad plugged into
	     a phone can put Roblox's own light blue selection box round this
	     button and leave it there. ]]
	button.Selectable = false
	button.Text = ""
	button.Parent = created

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = READY_COLOUR
	stroke.Transparency = 0.5
	stroke.Parent = button

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.Text = "»"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0.1
	label.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = label

	--[[ Fired on the way down, not on release: a dash that waits for the
	     finger to lift is a dash that arrives after the thing it was dodging
	     (CLAUDE.md, "Feel beats correctness in the input path"). ]]
	table.insert(
		connections,
		button.MouseButton1Down:Connect(function()
			pressing = true
			local handler = onPressed
			if handler then
				handler()
			end
		end)
	)

	--[[ Every way a press can end. The first two are the button's own and
	     cover the ordinary cases; the rest are the ones that left the old
	     visual stuck, where Roblox never tells the button anything because
	     the finger is no longer over it. ]]
	local function release()
		pressing = false
	end
	table.insert(connections, button.MouseButton1Up:Connect(release))
	table.insert(connections, button.MouseLeave:Connect(release))
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

	--[[ Repainted every frame from the single source of truth rather than
	     tweened on press, so a dash triggered by the spacebar on a device that
	     also has touch still shows the right state here. ]]
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			-- the lobby has no dash: its JUMP and SPRINT stand here instead
			local showing = Workspace:GetAttribute("InLobby") ~= true
			created.Enabled = showing
			local readiness = Dash.readiness(os.clock())
			local ready = readiness >= 1

			--[[ A press cannot outlive the button. Hidden by the lobby
			     mid-press, no input event is ever coming for that finger —
			     Roblox has nothing left to report it to — so the press is
			     dropped here or it would still be dark on the way back. ]]
			if pressing and not showing then
				pressing = false
			end

			button.BackgroundColor3 = if pressing then PRESS_COLOUR else FACE_COLOUR
			button.BackgroundTransparency = if pressing
				then FACE_PRESSED
				elseif ready then FACE_READY
				else FACE_COOLING
			stroke.Transparency = 1 - readiness * 0.7
			label.TextTransparency = if ready then 0.1 else 0.55

			--[[ And no selection box left on it, however it got there. ]]
			if GuiService.SelectedObject == button then
				GuiService.SelectedObject = nil
			end
		end)
	)
end

return DashButton
