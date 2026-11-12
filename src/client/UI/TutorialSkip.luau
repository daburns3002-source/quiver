--!strict
--[[
	SKIP TUTORIAL (owner, 2026-11-11): the tutorial plays on every join until
	Mossy Glade 1-1 is beaten (`Config/Tutorial.untilBeaten`), and a player who
	has already won it once (`SaveSchema` `tutorialDone`) gets this button in
	its top right corner. It asks for the lobby the way BACK TO LOBBY does
	(`Remotes.RunLobby`); the server decides, and nothing is credited.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local Kit = require(script.Parent.Kit)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local TutorialSkip = {}

-- pixels: at least a thumb's 48 tall on a phone
local WIDTH = 230
local HEIGHT = 52
local MARGIN = 12

local done = false
local asked = false
-- the tutorial is over (won or lost): its end screen has the way on
local over = false
local refresh: (() -> ())? = nil

Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(profile)
	if type(profile) == "table" then
		done = (profile :: any).tutorialDone == true
		if refresh then
			refresh()
		end
	end
end)

function TutorialSkip.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialSkip"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- with the fight's HUD: under the draft (100) and every covering screen
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = playerGui

	local button = Kit.button(gui, "SKIP TUTORIAL", Kit.slate, function()
		if asked then
			return
		end
		asked = true
		gui.Enabled = false
		Remotes.event(Remotes.RunLobby):FireServer()
	end)
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -MARGIN, 0, MARGIN)
	button.Size = UDim2.fromOffset(WIDTH, HEIGHT)

	local function update()
		local inTutorial = CurrentStage.index() == Balance.tutorialStage
			and Workspace:GetAttribute("InLobby") ~= true
		if not inTutorial then
			asked = false
		end
		gui.Enabled = inTutorial and done and not asked and not over
	end
	refresh = update
	Workspace:GetAttributeChangedSignal("Stage"):Connect(update)
	Workspace:GetAttributeChangedSignal("InLobby"):Connect(update)
	update()
end

--[[ The run's state, as `Remotes.RunStateChanged` tells it. ]]
function TutorialSkip.onRunStateChanged(state: string)
	over = state == "Complete" or state == "Dead"
	if refresh then
		refresh()
	end
end

return TutorialSkip
