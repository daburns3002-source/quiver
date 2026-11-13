--!strict
--[[
	The way out of a cleared room (owner, 2026-11-13: "the same way theres an
	arrow in the lobby pointing to eggs, there should be an arrow pointing to
	the open door when a player clears a room"): while the exit gate is open
	(`ExitOpen` on Workspace, the server's word, `Run/RoomController`), the
	lobby's gold arrow (`Fx/GoldPointer`, half size for the room's closer
	camera) bobs low in front of the doorway, pointing down at it, and its
	row of gold tiles runs along the floor from the player toward it. Low,
	not over the plaque: the desktop camera stops with the gate's top under
	the run HUD's bars (measured 2026-11-13: the doorway's floor 197 points
	down a 1113-point screen, the HUD's bars to about 175), so an arrow over
	the plaque was hidden. It goes when this player reaches the door, and
	with the gate when the next room starts or the run ends. Each player in
	a co-op run sees their own row. A look only.
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
--[[ The arrow's tip: on the room's centre line (the gate's, `Arena/ExitGate`),
     this far in from the door's point and this high over the floor, so it
     stays clear of the floor at the bottom of its bob and its top stays
     under the HUD's bars at the top of a desktop screen. ]]
local IN_FROM_DOOR = 3
local TIP_HEIGHT = 1.8
-- the tiles ride just over the lawn, where the gate's own GO arrow lies
local TILE_Y = 1

local player = Players.LocalPlayer

function DoorPointer.start()
	local door = Balance.Run.doorOffset
	local tip = Vector3.new(door.X, TIP_HEIGHT, door.Y + IN_FROM_DOOR)
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
		shown:pose(tip, root, os.clock())
	end)
end

return DoorPointer
