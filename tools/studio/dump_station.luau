--!strict
--[[
	Print one lobby station's parts in the building's OWN frame, for
	`tools/lobby_views.py` to draw flat against its reference sheet.

	Run it in the **Server** datamodel with the game playing, over MCP, with
	`STATION` set to the piece you want ("EggHatchery", "Blacksmith", ...).

	It exists because Studio's `screen_capture` cannot always be had -- it
	returned a timeout on every call on 2026-11-02 and empty frames during
	the Angel's build -- and a station still has to be looked at, not just
	measured (CLAUDE.md 13).
]]

local STATION = "EggHatchery"

local LobbyConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Lobby)

local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "the lobby is not built: start Play first")
local model = lobby:FindFirstChild(STATION)
assert(model, `no station called {STATION}`)

local at: Vector2? = nil
for _, station in LobbyConfig.stations do
	if station.piece == STATION then
		at = station.at
	end
end
assert(at, `{STATION} stands nowhere`)
local base = CFrame.new(LobbyConfig.origin + Vector3.new(at.X, 0.1, at.Y))
	* CFrame.Angles(0, LobbyConfig.facing(at), 0)

local rows = {}
for _, p in model:GetDescendants() do
	if p:IsA("BasePart") then
		local local_ = base:ToObjectSpace(p.CFrame)
		local rx, ry, rz = local_:ToOrientation()
		local shape = if p:IsA("Part") then p.Shape.Name else "Block"
		local mesh = p:FindFirstChildOfClass("SpecialMesh")
		if mesh and mesh.MeshType == Enum.MeshType.Sphere then
			shape = "Sphere"
		end
		table.insert(
			rows,
			string.format(
				"%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|%.3f,%.3f,%.3f|%d,%d,%d|%s|%s|%.2f",
				p.Name,
				p.Size.X,
				p.Size.Y,
				p.Size.Z,
				local_.Position.X,
				local_.Position.Y,
				local_.Position.Z,
				rx,
				ry,
				rz,
				math.floor(p.Color.R * 255 + 0.5),
				math.floor(p.Color.G * 255 + 0.5),
				math.floor(p.Color.B * 255 + 0.5),
				shape,
				p.Material.Name,
				p.Transparency
			)
		)
	end
end
return table.concat(rows, "\n")
