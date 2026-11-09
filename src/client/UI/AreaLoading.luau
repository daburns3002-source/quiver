--!strict
--[[
	The loading screen into an area's first level (owner, 2026-11-08: "use one
	of the loading screens until the first rooms models and textures are
	loaded in. the new enemy cards are part of that as well").

	The server parks the first room and fires `AreaLoading`
	(`Run/Party`). `Fx/RoomPreload` fetches it, its enemies' meshes and textures
	and their NEW ENEMY! cards; this holds a screen over all that, says
	`AreaLoaded`, and lifts once the run has really started.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassScreen = require(script.Parent.ClassScreen)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RoomPreload = require(script.Parent.Parent.Fx.RoomPreload)

--[[ The bar's fill, the longest this waits for the room, the longest it then
     waits for the run to start, and the beat the room gets to draw. ]]
local BAR_SECONDS = 6
local FETCH_LIMIT = 18
local START_LIMIT = 6
local SETTLE = 0.35

local AreaLoading = {}

local function show()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AreaLoading"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 900
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	ClassScreen.loadingCover(gui, BAR_SECONDS)

	RoomPreload.awaitNext(FETCH_LIMIT)
	Remotes.event(Remotes.AreaLoaded):FireServer()

	local deadline = os.clock() + START_LIMIT
	while Workspace:GetAttribute("InLobby") == true and os.clock() < deadline do
		task.wait(0.05)
	end
	task.wait(SETTLE)
	gui:Destroy()
end

function AreaLoading.start()
	Remotes.event(Remotes.AreaLoading).OnClientEvent:Connect(function()
		task.spawn(show)
	end)
end

return AreaLoading
