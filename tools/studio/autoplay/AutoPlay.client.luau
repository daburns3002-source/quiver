--[[
	Studio-only autopilot for bug hunts, never part of the game (see README.md).
	Goes under StarterPlayerScripts in Edit before Play, so it shares the game's
	module cache. It plays through the real screens and remotes, moves through
	the Humanoid, and writes what looks wrong to ReplicatedStorage.BotLog.
]]
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Remotes"))
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local DraftScreen = require(Client.UI.Cards.DraftScreen)
local EndScreen = require(Client.UI.EndScreen)
local NewEnemyScreen = require(Client.UI.NewEnemyScreen)
local EndlessCheckpoint = require(Client.UI.EndlessCheckpoint)

local log = ReplicatedStorage:FindFirstChild("BotLog") or Instance.new("StringValue")
log.Name = "BotLog"
log.Parent = ReplicatedStorage
local seenErrors: { [string]: number } = {}
local label, roomStart, kills, worstFrame = "start", os.clock(), 0, 0
local function say(text: string)
	log.Value ..= string.format("%6.0f %s | %s\n", os.clock() % 100000, label, text)
end

LogService.MessageOut:Connect(function(message, kind)
	if kind ~= Enum.MessageType.MessageError and kind ~= Enum.MessageType.MessageWarning then
		return
	end
	if message:find("Invalid mesh collision", 1, true) or message:find("DataStore", 1, true) then
		return
	end
	local key = message:sub(1, 200)
	seenErrors[key] = (seenErrors[key] or 0) + 1
	if seenErrors[key] == 1 then
		say("LOG " .. key)
	end
end)
RunService.RenderStepped:Connect(function(dt)
	worstFrame = math.max(worstFrame, dt)
end)
Remotes.event(Remotes.EnemyDied).OnClientEvent:Connect(function()
	kills += 1
end)

local state, progress, total = "?", 0, 0
Remotes.event(Remotes.RunStateChanged).OnClientEvent:Connect(function(p, t, s, name)
	if p ~= progress or s ~= state then
		if s == "Fighting" and p ~= progress then
			say(string.format("room done in %.0fs, kills %d, worst frame %.2fs, parts %d", os.clock() - roomStart, kills, worstFrame, #workspace:GetDescendants()))
			roomStart, kills, worstFrame = os.clock(), 0, 0
		end
		label = tostring(name) .. " " .. tostring(p) .. "/" .. tostring(t)
		say("state " .. tostring(s))
	end
	progress, total, state = p, t, s
end)

-- walking: through the hook in MoveController (README.md); it reads this each frame
local heading: Vector3? = nil
local MoveController = require(Client.Input.MoveController) :: any
RunService.RenderStepped:Connect(function()
	MoveController.__heading = heading
end)
local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function screens(): string
	local on = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "Freecam" then
			table.insert(on, g.Name)
		end
	end
	return table.concat(on, ",")
end

local Plan = { { 1, 1 }, { 2, 1 }, { 11, 1 } }
local planAt = 1
local endlessFloors = workspace:GetAttribute("BotEndlessFloors") or 12
local stuckSince = os.clock()
local lastSpot = Vector3.zero
local rng = Random.new(7)
local draftSince: number? = nil

local function lobbyTurn()
	local at = Plan[planAt]
	if not at then
		if planAt == #Plan + 1 then
			say("PLAN DONE")
			planAt += 1
			workspace:SetAttribute("BotDone", true)
		end
		return
	end
	local r = root()
	if not r or player:GetAttribute("ClassSelecting") == true then
		return
	end
	local index, level = at[1], at[2]
	-- the arch's mouth, by the same sums as Run/Lobby.archAt
	local perRow = LobbyConfig.perRow
	local row = math.ceil(index / perRow)
	local count = math.clamp(#LobbyConfig.portals - (row - 1) * perRow, 0, perRow)
	local x = (((index - 1) % perRow + 1) - (count + 1) / 2) * LobbyConfig.archSpacing
	local z = LobbyConfig.terrace.Y - (row - 1) * LobbyConfig.rowDepth + LobbyConfig.mouthAhead
	local y = 4 + LobbyConfig.ledge + (row - 1) * LobbyConfig.rowRise
	player.Character:PivotTo(CFrame.new(LobbyConfig.origin + Vector3.new(x, y, z)))
	task.wait(1)
	say(string.format("starting portal %d level %d", index, level))
	Remotes.event(Remotes.PortalStart):FireServer(index, level)
	planAt += 1
	task.wait(4)
	if workspace:GetAttribute("InLobby") == true then
		say("PORTAL START REFUSED, screens " .. screens())
	end
end

while true do
	task.wait(0.4)
	local r = root()
	if not r then
		continue
	end
	local now = os.clock()
	local pos = r.Position

	if label:find("Floor", 1, true) == nil and workspace:GetAttribute("InLobby") ~= true and total >= 100 and progress >= endlessFloors then
		say("endless cap reached, leaving")
		Remotes.event(Remotes.RunLobby):FireServer()
		task.wait(5)
		continue
	end
	local draft = player.PlayerGui:FindFirstChild("DraftScreen")
	if draft and draft.Enabled then
		draftSince = draftSince or now
		if now - draftSince > 45 then
			say("DRAFT STUCK UP, screens " .. screens())
			draftSince = now
		end
	else
		draftSince = nil
	end
	if draft and draft.Enabled and DraftScreen.__bot and DraftScreen.__bot() then
		roomStart += 3
		task.wait(3.5)
		continue
	end
	if NewEnemyScreen.__bot and NewEnemyScreen.__bot() then
		task.wait(1)
		continue
	end
	local picks = player.PlayerGui:FindFirstChild("EndlessCheckpoint")
	if picks and picks.Enabled then
		task.wait(1)
		EndlessCheckpoint.__bot(1)
		say("endless checkpoint pick")
		task.wait(1)
		continue
	end
	if state == "Complete" or state == "Dead" then
		heading = nil
		say("run over: " .. state .. ", screens " .. screens())
		task.wait(3)
		if EndScreen.__bot then
			EndScreen.__bot()
		end
		task.wait(6)
		if state == "Complete" or state == "Dead" then
			say("END SCREEN DID NOT LEAVE, screens " .. screens())
			Remotes.event(Remotes.RunLobby):FireServer()
			task.wait(4)
		end
		continue
	end
	if workspace:GetAttribute("InLobby") == true then
		heading = nil
		label = "lobby"
		task.wait(2)
		lobbyTurn()
		roomStart = os.clock()
		continue
	end

	-- sanity: where the player is
	if pos.Y < -3 or math.abs(pos.X) > 40 or math.abs(pos.Z) > 60 then
		say(string.format("PLAYER OUT OF BOUNDS %.0f %.0f %.0f", pos.X, pos.Y, pos.Z))
	end
	if state == "Fighting" and now - roomStart > 240 then
		say("STUCK ROOM over 240s, kills " .. kills .. ", enemies " .. #workspace.Enemies:GetChildren() .. ", screens " .. screens())
		Remotes.event(Remotes.DebugRoom):FireServer(progress + 1)
		roomStart = now
	end

	if workspace:GetAttribute("ExitOpen") == true then
		-- to the gate, sidestepping cover when straight stops working
		local want = Vector3.new(if pos.Z < -21 then -pos.X * 0.15 else 0, 0, -1)
		if (pos - lastSpot).Magnitude < 0.6 then
			if now - stuckSince > 1 then
				want = Vector3.new(rng:NextNumber() < 0.5 and -1 or 1, 0, 0.2)
				heading = want.Unit
				task.wait(0.9)
			end
		else
			stuckSince = now
		end
		heading = want.Unit
		lastSpot = pos
		if now - roomStart > 120 then
			say(string.format("CANNOT REACH GATE at %.0f %.0f", pos.X, pos.Z))
			roomStart = now
		end
	else
		heading = nil
		-- a melee class walks up to the nearest enemy, then stands and swings
		if player:GetAttribute("Class") == "Warden" and state == "Fighting" then
			local best, bestAt = math.huge, nil
			for _, e in workspace.Enemies:GetChildren() do
				if e:IsA("Model") then
					local at = e:GetPivot().Position
					local d = (at - pos).Magnitude
					if d < best then
						best, bestAt = d, at
					end
				end
			end
			if bestAt and best > 6 then
				heading = ((bestAt - pos) * Vector3.new(1, 0, 1)).Unit
				task.wait(0.5)
				heading = nil
				task.wait(0.5)
			end
		end
		-- a stand-off (nothing dying for 25 s): go somewhere else and shoot again
		if now - stuckSince > 25 and state == "Fighting" then
			stuckSince = now
			heading = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 0.3)).Unit
			task.wait(1.5)
			heading = nil
		end
		if kills > 0 and state == "Fighting" and pos ~= lastSpot then
			lastSpot = pos
		end
	end
	if endlessFloors and label:find("Endless", 1, true) and progress >= endlessFloors then
		say("endless cap reached, leaving")
		Remotes.event(Remotes.RunLobby):FireServer()
		task.wait(4)
	end
end
