--!strict
--[[
	The room-to-room loop.

	Fight → clear → the door opens → walk onto it → the next room is built.
	Die, and the run goes back to room one. That cycle is the entire Phase 2
	question: after five rooms, do you want a sixth?

	The server owns every part of it. The client is told which room it is in
	and what state the run is in; it never reports either. Room progress is the
	gate the whole meta loop hangs off in Phase 5 — an area unlocks by clearing
	its last room — so a client that could claim a room could claim an area.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Burning = require(script.Parent.Parent.Combat.Burning)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Loadout = require(script.Parent.Loadout)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ProjectileSystem = require(script.Parent.Parent.Combat.ProjectileSystem)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.RunSession)

local log = Log.forTag("Run")

local RoomController = {}

export type State = "Fighting" | "Cleared" | "Dead" | "Complete"

local runStateChanged = Remotes.event(Remotes.RunStateChanged)
local runSummary = Remotes.event(Remotes.RunSummary)

local roomIndex = 1
local state: State = "Fighting"
--[[ `os.clock()` at which the pending transition fires, or nil when the run is
     waiting on the player rather than on a clock. ]]
local resumeAt: number? = nil

local function broadcast()
	runStateChanged:FireAllClients(roomIndex, #Balance.Rooms, state, Balance.Rooms[roomIndex].name)
end

--[[
	Tears the current room down and builds the next one.

	The arena is rebuilt rather than edited, so a room can never inherit a
	pillar from the last one, and the raycast filters are refreshed because
	both of them point at folders that no longer exist after this.
]]
local function enterRoom(index: number)
	roomIndex = index
	state = "Fighting"
	resumeAt = nil

	local room = Balance.Rooms[index]

	Arena.build(workspace, room.obstacles)
	EnemyManager.init(workspace)

	--[[ Nothing survives a room boundary. An arrow fired at the last enemy of
	     the old room would otherwise arrive in the new one, and both filters
	     point at folders that have just been destroyed. ]]
	ProjectileSystem.clear()
	Burning.clear()
	ProjectileSystem.refreshFilters()

	--[[ Players are put back at the start of the new room. Without this they
	     would begin the next fight standing on what used to be the door, which
	     is the far end of the room from where its enemies spawn. ]]
	for _, session in RunSession.all() do
		local root = session.root
		if root then
			root.CFrame = CFrame.new(Balance.Arena.spawnPosition)
		end
	end

	EnemyManager.spawnWave(room.enemyCount, room.roster)

	log.info("entered room %d/%d — %s", index, #Balance.Rooms, room.name)
	broadcast()
end

function RoomController.start()
	enterRoom(1)
end

--[[ Called when a player dies. The run ends; it does not continue without
     them, because a run that carries on after death has no stakes. ]]
--[[
	Tells each player what they built.

	Sent at the end of a run rather than accumulated as it goes, because the
	only moment the summary is worth anything is the one where the player is
	deciding whether to go again. Held abilities only: a heal they drank is
	not part of the build, and `Loadout.held` already draws that line.
]]
local function sendSummary(won: boolean)
	for _, session in RunSession.all() do
		local held = Loadout.held(session.loadout)

		local lines: { { id: string, count: number } } = {}
		for id, count in held do
			table.insert(lines, { id = id, count = count })
		end

		--[[ Sorted here so every client shows the same order, and so a build
		     reads as a list rather than as whatever order a hash landed in. ]]
		table.sort(lines, function(a, b)
			if a.count ~= b.count then
				return a.count > b.count
			end
			return a.id < b.id
		end)

		runSummary:FireClient(session.player, {
			won = won,
			roomsReached = roomIndex,
			totalRooms = #Balance.Rooms,
			level = session.loadout.level,
			abilities = lines,
		})
	end
end

function RoomController.onPlayerDied()
	if state == "Dead" then
		return
	end

	state = "Dead"
	resumeAt = os.clock() + Balance.Run.deathPause
	Arena.setDoorOpen(false)

	log.info("run ended in room %d/%d", roomIndex, #Balance.Rooms)
	broadcast()
	sendSummary(false)
end

local function anyPlayerAtDoor(): boolean
	for _, session in RunSession.all() do
		local root = session.root
		if root and session.alive and Arena.isAtDoor(root.Position) then
			return true
		end
	end

	return false
end

function RoomController.step(now: number)
	if state == "Dead" then
		if resumeAt and now >= resumeAt then
			log.info("restarting the run")

			--[[ Levels and abilities are run-local by design: a death costs
			     the build and nothing else, because the meta loop that would
			     soften that is Phase 6. Reset before the room is built, so the
			     first wave meets a level-one archer. ]]
			for _, session in RunSession.all() do
				RunSession.resetRun(session)
			end

			enterRoom(1)
		end

		return
	end

	if state == "Complete" then
		if resumeAt and now >= resumeAt then
			enterRoom(1)
		end

		return
	end

	if state == "Fighting" then
		if EnemyManager.aliveCount() > 0 then
			return
		end

		state = "Cleared"
		--[[ The door is held shut for a beat after the last kill, so clearing
		     a room reads as its own moment rather than being swallowed by the
		     next one opening underneath it. ]]
		resumeAt = now + Balance.Run.clearPause
		broadcast()

		return
	end

	-- Cleared: hold the pause, then light the door and wait for a player.
	if resumeAt then
		if now < resumeAt then
			return
		end

		resumeAt = nil
		Arena.setDoorOpen(true)
	end

	if not anyPlayerAtDoor() then
		return
	end

	if roomIndex >= #Balance.Rooms then
		state = "Complete"
		resumeAt = now + Balance.Run.deathPause
		Arena.setDoorOpen(false)
		log.info("run complete")
		broadcast()
		sendSummary(true)

		return
	end

	enterRoom(roomIndex + 1)
end

--[[ So a client joining mid-run is not left with an empty HUD. ]]
function RoomController.sendStateTo(player: Player)
	runStateChanged:FireClient(
		player,
		roomIndex,
		#Balance.Rooms,
		state,
		Balance.Rooms[roomIndex].name
	)
end

Players.PlayerAdded:Connect(RoomController.sendStateTo)

return RoomController
