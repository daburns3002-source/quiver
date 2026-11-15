--!strict
--[[
	A quest row's GO (`UI/RewardsScreen`; owner, 2026-11-14: "the quests need
	to be clearer"): a gold arrow over the place the quest is done, with a
	row of gold tiles from the player towards it, as the way to the first egg
	is shown (`Fx/GoldPointer`, `Fx/HatcheryPointer`). A station
	(`Config/Lobby.stations`), or the first portal for a quest done in a run.

	It goes when the player gets there, after `SECONDS`, when another GO is
	pressed, or when they leave the lobby. Only on this client, a look only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GoldPointer = require(script.Parent.GoldPointer)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)

local QuestPointer = {}

--[[ The arrow's tip, over a station's foot (`Fx/HatcheryPointer`'s), and
     how far over a portal's top it hangs: a portal is much lower than a
     station's roof, and an arrow at a roof's height is out of sight above
     it (seen in Studio, 2026-11-14). ]]
local TIP_HEIGHT = 56
local OVER_PORTAL = 5
--[[ How long it shows, and how near (studs, on the ground) counts as there. ]]
local SECONDS = 20
local NEAR = 24

local player = Players.LocalPlayer
local pointer: GoldPointer.Pointer? = nil
local target: Vector3? = nil
local tipHeight = TIP_HEIGHT
local untilAt = 0

--[[ Where `place` is, on the ground, and how high over it the arrow's tip
     hangs: a station's foot, or the first portal's. ]]
function QuestPointer.spot(place: string): (Vector3?, number)
	for _, entry in LobbyConfig.stations do
		if entry.piece == place then
			return LobbyConfig.origin + Vector3.new(entry.at.X, 0, entry.at.Y), TIP_HEIGHT
		end
	end
	if place == "Portal" then
		local lobby = Workspace:FindFirstChild("Lobby")
		local portal = lobby and lobby:FindFirstChild("Portal_1", true)
		if portal and portal:IsA("Model") then
			local box, size = portal:GetBoundingBox()
			local ground = LobbyConfig.origin.Y
			local top = box.Position.Y + size.Y / 2
			return Vector3.new(box.Position.X, ground, box.Position.Z), top - ground + OVER_PORTAL
		end
	end
	return nil, TIP_HEIGHT
end

local function clear()
	if pointer then
		pointer:destroy()
		pointer = nil
	end
	target = nil
end

--[[ Points the way to `place` with `words` under the arrow. False when the
     place cannot be found (nothing is shown). ]]
function QuestPointer.show(place: string, words: string): boolean
	clear()
	local spot, height = QuestPointer.spot(place)
	if not spot then
		return false
	end
	target = spot
	tipHeight = height
	untilAt = os.clock() + SECONDS
	pointer = GoldPointer.new({ name = "QuestPointer", words = words })
	return true
end

function QuestPointer.start()
	RunService.RenderStepped:Connect(function()
		local shown, spot = pointer, target
		if not shown or not spot then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local away = if root
			then (Vector3.new(root.Position.X, spot.Y, root.Position.Z) - spot).Magnitude
			else math.huge
		if Workspace:GetAttribute("InLobby") ~= true or os.clock() > untilAt or away < NEAR then
			clear()
			return
		end
		shown:pose(spot + Vector3.new(0, tipHeight, 0), root, os.clock())
	end)
end

return QuestPointer
