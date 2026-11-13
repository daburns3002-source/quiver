--!strict
--[[
	The way to the first egg (Fable's loop review, 2026-11-11, approved): the
	tutorial's win pays for the Mossy Egg (`Util/FirstEgg`), and in the lobby,
	while the player can afford it and owns no pet, a blocky gold arrow bobs
	over the Hatchery with HATCH YOUR FIRST EGG! under it, and a row of gold
	tiles on the floor runs from the player toward it (drawn by `Fx/GoldPointer`,
	which the open exit gate's pointer shares). Only on this client, a look
	only: the hatch itself is the server's (`Data/Hatchery`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FirstEgg = require(ReplicatedStorage.Shared.Util.FirstEgg)
local GoldPointer = require(script.Parent.GoldPointer)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local HatcheryPointer = {}

-- the arrow's tip, over the station's foot
local TIP_HEIGHT = 56

local player = Players.LocalPlayer
local pets: { [string]: number }? = nil
local profileSeen = false

Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(profile)
	if type(profile) == "table" then
		profileSeen = true
		pets = (profile :: any).pets
	end
end)

local function hatchery(): Vector3?
	for _, entry in LobbyConfig.stations do
		if entry.piece == "EggHatchery" then
			return LobbyConfig.origin + Vector3.new(entry.at.X, 0, entry.at.Y)
		end
	end
	return nil
end

local function wanted(): boolean
	if Workspace:GetAttribute("InLobby") ~= true or not profileSeen then
		return false
	end
	local coins = player:GetAttribute("Coins")
	return FirstEgg.pointWanted(if type(coins) == "number" then coins else 0, pets)
end

function HatcheryPointer.start()
	local station = hatchery()
	if not station then
		return
	end
	local pointer: GoldPointer.Pointer? = nil

	RunService.RenderStepped:Connect(function()
		if not wanted() then
			if pointer then
				pointer:destroy()
				pointer = nil
			end
			return
		end
		local shown = pointer
			or GoldPointer.new({ name = "HatcheryPointer", words = "HATCH YOUR FIRST EGG!" })
		pointer = shown
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		shown:pose(station + Vector3.new(0, TIP_HEIGHT, 0), root, os.clock())
	end)
end

return HatcheryPointer
