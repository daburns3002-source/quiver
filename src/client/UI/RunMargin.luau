--!strict
--[[
	The run's screen as `Util/ArenaMargin` reads it: the arena's floor
	corners where the camera shows them, the run HUD's pieces
	(`UI/HudLayout.pieces`), the first row under Roblox's top bar and where
	the player stands, all in the points of a ScreenGui whose top-left is
	`origin` on the viewport. Nil in the lobby, or with no room built.

	Used by what puts a tip up during a run (`UI/TutorialPrompts`,
	`UI/FirstTips`) to keep it off the arena (owner, 2026-11-19: "the
	tutorial tips need to be on the outer arena so they do not block the
	arena").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaMargin = require(ReplicatedStorage.Shared.Util.ArenaMargin)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local HudLayout = require(script.Parent.HudLayout)

local RunMargin = {}

--[[ Whether a room is built and the player is in it, not in the lobby. ]]
function RunMargin.inRun(): boolean
	return Workspace:GetAttribute("InLobby") ~= true and Workspace:FindFirstChild("Arena") ~= nil
end

--[[ The screen `size` points big at `origin` on the viewport, and the
     arena on it; nil, nil outside a run. ]]
function RunMargin.read(origin: Vector2, size: Vector2): (ArenaMargin.Screen?, ArenaMargin.Quad?)
	local camera = Workspace.CurrentCamera
	if not camera or not RunMargin.inRun() then
		return nil, nil
	end
	local arena = Balance.Arena
	--[[ The floor and its walls where they stand: a wall's top leans out in
	     the view and would make the room look bigger than what is played
	     on. The room is centred on the world's origin (`TopDownCamera`). ]]
	local quad = ArenaMargin.quad(
		arena.size.X / 2 + arena.wallThickness,
		arena.size.Z / 2 + arena.wallThickness,
		function(x: number, z: number): ArenaMargin.Point
			local point = camera:WorldToViewportPoint(Vector3.new(x, 0, z))
			return { x = point.X - origin.X, y = point.Y - origin.Y }
		end
	)
	local hud = {}
	for _, piece in HudLayout.pieces() do
		table.insert(hud, {
			x = piece.x - origin.X,
			y = piece.y - origin.Y,
			w = piece.w,
			h = piece.h,
		})
	end
	local player: ArenaMargin.Point? = nil
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local point, inFront = camera:WorldToViewportPoint(root.Position)
		if inFront then
			player = { x = point.X - origin.X, y = point.Y - origin.Y }
		end
	end
	-- the exit gate, in the middle of the north wall
	local gate = camera:WorldToViewportPoint(Vector3.new(0, 0, -arena.size.Z / 2))
	return {
		w = size.X,
		h = size.Y,
		top = math.max(0, HudLayout.topBar() - origin.Y) + ArenaMargin.GUTTER,
		hud = hud,
		player = player,
		gate = { x = gate.X - origin.X, y = gate.Y - origin.Y },
	},
		quad
end

return RunMargin
