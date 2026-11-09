--!strict
--[[
	Co-op parties (`docs/COOP.md`): one party per server.

	The lobby is the public server. START at a portal takes the starter and
	whoever else stands in that portal (up to `Coop.maxParty`), reserves a
	private server of this same place (`TeleportService:ReserveServer`) and
	sends them there together. Solo runs go the same way, so a run never
	pulls in a stranger who happens to share the lobby.

	A **run server** (a reserved one) waits for its party to arrive, up to
	`Coop.arrivalWait`, then starts the stage they asked for, with the
	party's size locked at the players present (`Coop.ATTRIBUTE`). Nobody
	joins once it has started. LOBBY, or the end of an area, sends the whole
	party back to a public lobby together.

	What a teleport carries passes through the client, so the run server
	checks the level again against the leader's own saved profile
	(`Lobby.levelOpen`) before playing it.

	**In Studio** there are no teleports: START plays the run in place, with
	every player in the server in it, which is what Studio's multi-client
	test exercises.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Coop = require(ReplicatedStorage.Shared.Util.Coop)
local Lobby = require(script.Parent.Lobby)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RoomController = require(script.Parent.RoomController)
local RunSession = require(script.Parent.RunSession)

local log = Log.forTag("Party")

local Party = {}

local notice = Remotes.event(Remotes.PartyNotice)

--[[ Whether this server is a party's run server: a reserved server, which
     has a private id but no owner. ]]
function Party.isRunServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

--[[ Whether START teleports: everywhere but Studio, which cannot. ]]
local function teleports(): boolean
	return not RunService:IsStudio()
end

--[[ The players a run in place takes in: everyone off the title. ]]
local function inPlace(): number
	local count = 0
	for _, session in RunSession.all() do
		if not session.atTitle and session.character then
			count += 1
		end
	end
	return math.clamp(count, 1, Coop.maxParty)
end

--[[ Locks the party size for the run about to start. ]]
local function lock(size: number)
	Workspace:SetAttribute(Coop.ATTRIBUTE, math.clamp(size, 1, Coop.maxParty))
end

--[[ The longest an area's loading screen holds the run for one slow client. ]]
local AREA_LOAD_LIMIT = 20
local areaLoading = false

--[[ An area's first level: the first room is sent ahead and everyone holds on
     a loading screen until they have it, or until `AREA_LOAD_LIMIT`. ]]
local function loadArea(stage: number)
	if not Lobby.isFirstLevel(stage) or not RoomController.prepareFirstRoom(stage) then
		return
	end
	local waiting: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		waiting[player] = true
	end
	local connection = Remotes.event(Remotes.AreaLoaded).OnServerEvent:Connect(function(player)
		waiting[player] = nil
	end)
	Remotes.event(Remotes.AreaLoading):FireAllClients()
	local deadline = os.clock() + AREA_LOAD_LIMIT
	while next(waiting) and os.clock() < deadline do
		task.wait(0.1)
		for player in waiting do
			if player.Parent == nil then
				waiting[player] = nil
			end
		end
	end
	connection:Disconnect()
end

--[[ Starts `stage` here, with the party size locked first so the first
     fight is built for it. ]]
local function startHere(stage: number, size: number)
	if areaLoading then
		return
	end
	areaLoading = true
	lock(size)
	local ok, problem = pcall(function()
		loadArea(stage)
	end)
	if not ok then
		log.warn("area load failed: %s", tostring(problem))
	end
	areaLoading = false
	RoomController.beginStage(stage)
end

local busy: { [Player]: boolean } = {}

--[[ Sends `members` to a fresh reserved server to play portal `index`'s
     level `level`. Retried once; a failure is told to each member. ]]
local function send(members: { Player }, index: number, level: number, leader: Player)
	local ids = {}
	for _, member in members do
		busy[member] = true
		table.insert(ids, member.UserId)
		notice:FireClient(member, "TRAVELLING...")
	end
	local ok, err = pcall(function()
		local code = TeleportService:ReserveServer(game.PlaceId)
		local options = Instance.new("TeleportOptions")
		-- through `any`: CI's type definitions predate this property
		local untyped: any = options
		untyped.ReservedServerAccessCode = code
		options:SetTeleportData({
			arrowborne = true,
			portal = index,
			level = level,
			leader = leader.UserId,
			party = ids,
		})
		TeleportService:TeleportAsync(game.PlaceId, members, options)
	end)
	if not ok then
		log.warn("party teleport failed: %s", tostring(err))
		for _, member in members do
			busy[member] = nil
			notice:FireClient(member, "COULD NOT START. TRY AGAIN")
		end
	end
end

--[[
	START at portal `index`, level `level`, from `starter` (already checked
	by `Lobby.startFor`, which gave `stage`). The party is the starter and
	whoever else stands at that portal and has the level open too.
]]
function Party.start(starter: Player, index: number, level: number, stage: number)
	if busy[starter] then
		return
	end
	if not teleports() then
		startHere(stage, inPlace())
		return
	end
	local standing: { number } = {}
	local byId: { [number]: Player } = {}
	for player, session in RunSession.all() do
		local root = session.root
		if player ~= starter and root and not session.atTitle and not busy[player] then
			local profile = PlayerData.get(player)
			local beaten = if profile then profile.levelsBeaten else nil
			if Lobby.startFor(root.Position, index, level, beaten) == stage then
				table.insert(standing, player.UserId)
				byId[player.UserId] = player
			end
		end
	end
	byId[starter.UserId] = starter
	local members: { Player } = {}
	for _, id in Coop.pickParty(starter.UserId, standing) do
		table.insert(members, byId[id])
	end
	log.info("%s starts portal %d level %d with %d", starter.Name, index, level, #members)
	task.spawn(send, members, index, level, starter)
end

--[[ The tutorial, owed on BEGIN ADVENTURE: always solo. ]]
function Party.startTutorial(player: Player, stage: number)
	if not teleports() then
		startHere(stage, 1)
		return
	end
	if busy[player] then
		return
	end
	-- the tutorial is not behind a portal: portal 0 says so
	task.spawn(function()
		busy[player] = true
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			local options = Instance.new("TeleportOptions")
			-- through `any`: CI's type definitions predate this property
			local untyped: any = options
			untyped.ReservedServerAccessCode = code
			options:SetTeleportData({
				arrowborne = true,
				tutorial = stage,
				leader = player.UserId,
				party = { player.UserId },
			})
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if not ok then
			-- a tutorial that cannot travel plays here instead
			busy[player] = nil
			log.warn("tutorial teleport failed, playing in place: %s", tostring(err))
			startHere(stage, 1)
		end
	end)
end

--[[ Back to a public lobby, every player here together. ]]
local function sendToLobby(): boolean
	local everyone = Players:GetPlayers()
	if #everyone == 0 then
		return true
	end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ arrowborne = true })
		TeleportService:TeleportAsync(game.PlaceId, everyone, options)
	end)
	if not ok then
		log.warn("teleport to the lobby failed: %s", tostring(err))
	end
	-- the lobby here stands in until the teleport lands, or if it failed
	return false
end

--[[ A run server: wait for the party, check the level, play it. ]]
local function runServer()
	local started = false
	local expected: { number }? = nil
	local leaderData: { [string]: any }? = nil
	local deadline = os.clock() + Coop.arrivalWait

	local function joinData(player: Player): { [string]: any }?
		local ok, data = pcall(function()
			return player:GetJoinData().TeleportData
		end)
		return if ok and type(data) == "table" then data :: any else nil
	end

	local function onAdded(player: Player)
		if started then
			-- no joining a run already under way
			log.info("%s arrived after the run started: to the lobby", player.Name)
			pcall(function()
				local options = Instance.new("TeleportOptions")
				options:SetTeleportData({ arrowborne = true })
				TeleportService:TeleportAsync(game.PlaceId, { player }, options)
			end)
			return
		end
		local data = joinData(player)
		if data and type(data.party) == "table" and not expected then
			expected = data.party
		end
		if data and data.leader == player.UserId then
			leaderData = data
		end
	end
	for _, player in Players:GetPlayers() do
		onAdded(player)
	end
	Players.PlayerAdded:Connect(onAdded)

	local function allHere(): boolean
		local list = expected
		if not list then
			return false
		end
		for _, id in list do
			if not Players:GetPlayerByUserId(id) then
				return false
			end
		end
		return true
	end

	local function ready(): boolean
		for _, player in Players:GetPlayers() do
			local session = RunSession.get(player)
			if not session or not session.character or not PlayerData.get(player) then
				return false
			end
		end
		return #Players:GetPlayers() > 0
	end

	task.spawn(function()
		while not started do
			task.wait(0.25)
			if not (allHere() or os.clock() >= deadline) or not ready() then
				continue
			end
			local data = leaderData
			if not data then
				-- the leader never came: whoever did goes back
				if os.clock() >= deadline + 5 then
					started = true
					sendToLobby()
				end
				continue
			end
			local leader = Players:GetPlayerByUserId(data.leader)
			local profile = leader and PlayerData.get(leader)
			local beaten = if profile then profile.levelsBeaten else nil
			-- only ever the tutorial: the number came through the client
			local stage = if data.tutorial ~= nil
				then (if data.tutorial == Balance.tutorialStage then Balance.tutorialStage else nil)
				else Lobby.levelOpen(data.portal, data.level, beaten)
			started = true
			if not stage then
				log.warn("the leader may not play that level: to the lobby")
				sendToLobby()
				return
			end
			log.info("run server: %d of the party here, stage %d", #Players:GetPlayers(), stage)
			startHere(stage, #Players:GetPlayers())
		end
	end)
end

function Party.init()
	if Party.isRunServer() then
		RoomController.leaveServer = sendToLobby
		runServer()
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return Party
