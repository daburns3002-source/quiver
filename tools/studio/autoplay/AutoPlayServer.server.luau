--[[
	The autopilot's server half (see README.md). Goes under ServerScriptService in
	Edit before Play. Keeps the player alive unless `BotMortal` is set on Workspace,
	and reports enemies that leave the room or a room holding an enemy that never
	moves and cannot be reached. Writes to ReplicatedStorage.BotServerLog.
]]
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RunSession = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Run"):WaitForChild("RunSession"))

local log = Instance.new("StringValue")
log.Name = "BotServerLog"
log.Parent = ReplicatedStorage
local function say(text: string)
	log.Value ..= string.format("%6.0f st%s | %s\n", os.clock() % 100000, tostring(workspace:GetAttribute("Stage")), text)
end

local seen: { [string]: boolean } = {}
LogService.MessageOut:Connect(function(message, kind)
	if kind ~= Enum.MessageType.MessageError and kind ~= Enum.MessageType.MessageWarning then
		return
	end
	if message:find("Invalid mesh collision", 1, true) or message:find("DataStore", 1, true) then
		return
	end
	local key = message:sub(1, 240)
	if not seen[key] then
		seen[key] = true
		say("LOG " .. key)
	end
end)

local reported: { [Instance]: boolean } = {}
while true do
	task.wait(0.5)
	for _, player in Players:GetPlayers() do
		local session = RunSession.get(player)
		if session and workspace:GetAttribute("BotMortal") ~= true then
			session.health = session.maxHealth
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies and workspace:GetAttribute("InLobby") ~= true then
		for _, enemy in enemies:GetChildren() do
			local at = if enemy:IsA("Model") then enemy:GetPivot().Position elseif enemy:IsA("BasePart") then enemy.Position else nil
			if at and not reported[enemy] and (math.abs(at.X) > 22 or math.abs(at.Z) > 34 or at.Y < -3 or at.X ~= at.X) then
				reported[enemy] = true
				say(string.format("ENEMY OUT OF ROOM %s at %.1f %.1f %.1f", enemy.Name, at.X, at.Y, at.Z))
			end
		end
	end
end
