--!strict
--[[
	The way out of a cleared room (owner, 2026-11-13: "the same way theres an
	arrow in the lobby pointing to eggs, there should be an arrow pointing to
	the open door when a player clears a room"): while the exit gate is open
	(`ExitOpen` on Workspace, the server's word, `Run/RoomController`), the
	lobby's gold arrow (`Fx/GoldPointer`, smaller for the room's closer
	camera) bobs over the gate's plaque and its row of gold tiles runs along
	the floor from the player toward the doorway. It goes when this player
	reaches the door, and with the gate when the next room starts or the run
	ends. Each player in a co-op run sees their own row. A look only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local GoldPointer = require(script.Parent.GoldPointer)
local WayPointer = require(ReplicatedStorage.Shared.Util.WayPointer)

local DoorPointer = {}

-- the room's camera is far closer than the lobby's
local SCALE = 0.5
-- the arrow's tip: over the plaque's top, and out from the gate's face
local OVER_PLAQUE = 2
local OUT_FROM_FACE = 1.2
-- the tiles ride just over the lawn, where the gate's own GO arrow lies
local TILE_Y = 1
-- with no plaque found (it is built with every gate), over a plain gate
local FALLBACK_TIP_Y = 11

local player = Players.LocalPlayer

--[[ The arrow's tip for the room on screen: the gate is the north wall's,
     on the room's centre line (`Arena/ExitGate`); its height follows the
     plaque, which a kit's own taller door raises. ]]
local function tipFor(): Vector3
	local front = -Balance.Arena.size.Z / 2 + 0.2
	local arena = Workspace:FindFirstChild("Arena")
	local gate = arena and arena:FindFirstChild("ExitGate")
	local plaque = gate and gate:FindFirstChild("Plaque")
	local y = if plaque and plaque:IsA("BasePart")
		then plaque.Position.Y + plaque.Size.Y / 2 + OVER_PLAQUE
		else FALLBACK_TIP_Y
	return Vector3.new(0, y, front + OUT_FROM_FACE)
end

function DoorPointer.start()
	local door = Balance.Run.doorOffset
	local pointer: GoldPointer.Pointer? = nil

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local distance = if root
			then Vector2.new(root.Position.X - door.X, root.Position.Z - door.Y).Magnitude
			else nil
		local show = WayPointer.doorWanted(
			Workspace:GetAttribute("InLobby") == true,
			Workspace:GetAttribute("ExitOpen") == true,
			distance,
			Balance.Run.doorRadius
		)
		if not show then
			if pointer then
				pointer:destroy()
				pointer = nil
			end
			return
		end
		local shown = pointer
			or GoldPointer.new({ name = "DoorPointer", scale = SCALE, tileY = TILE_Y })
		pointer = shown
		shown:pose(tipFor(), root, os.clock())
	end)
end

return DoorPointer
