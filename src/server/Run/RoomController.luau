--!strict
--[[
	The run loop, in either of Archero 2's two stage shapes.

	- **Rooms:** fight → clear → the door opens → walk onto it → the next room
	  is built. The Phase 2 loop, unchanged.
	- **Waves:** one arena for the whole stage. A wave clears, a beat passes,
	  the next arrives in place. Some waves are not fights: a Valkyrie offers
	  one of two skills, an Angel a stat or a heal, and a boss wave closes each
	  block of ten. See `Waves` for the schedule.

	Which shape a run takes is the current stage's `mode` — data,
	because it depends on where in the game a stage sits, not on anything the
	code should decide.

	Die, and the run goes back to the start of the stage. Win, and NEXT
	LEVEL starts the next stage of `Balance.campaign`, upgrades reset. The server owns all
	of it: the client is told where it is and what state the run is in, and
	never reports either. Stage progress is what areas unlock on in Phase 5,
	so a client that could claim a wave could claim an area.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AreaStrikes = require(script.Parent.Parent.Combat.AreaStrikes)
local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Burning = require(script.Parent.Parent.Combat.Burning)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local Lobby = require(script.Parent.Lobby)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local MeleeSystem = require(script.Parent.Parent.Combat.MeleeSystem)
local PetCombat = require(script.Parent.Parent.Combat.PetCombat)
local Pickups = require(script.Parent.Pickups)
local ProjectileSystem = require(script.Parent.Parent.Combat.ProjectileSystem)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RunSession = require(script.Parent.RunSession)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local StoryLeaderboard = require(script.Parent.StoryLeaderboard)
local StoryProgress = require(ReplicatedStorage.Shared.Util.StoryProgress)
local Waves = require(script.Parent.Waves)

local log = Log.forTag("Run")

local RoomController = {}

--[[ `Lobby`: before a run, everyone in the lobby (`Run/Lobby`), nothing
     fighting; a portal starts the next run (`beginStage`). ]]
export type State = "Lobby" | "Fighting" | "Cleared" | "Choosing" | "Dead" | "Complete"

local runStateChanged = Remotes.event(Remotes.RunStateChanged)
local runSummary = Remotes.event(Remotes.RunSummary)

--[[ The stage being played, published for the clients and the enemies
     (`Util/CurrentStage`). ]]
local stageIndex = Balance.stage

local function stage(): Balance.StageConfig
	return Balance.Stages[stageIndex]
end

--[[ How far through the stage the run is: a position in its room list, or a
     wave number. One counter for both, because the HUD, the summary and the
     death message all only ever want "how far, out of how many". ]]
local progress = 1
--[[ The Studio sandbox (`enterSandbox`): the run stands still around
     training dummies until it is left. ]]
local sandbox = false
--[[ The stage was started part-way through, in Studio (`Sandbox.startRoom`,
     `debugEnterRoom`): its clears are not a real run, so the leaderboard
     is not told of them. ]]
local jumped = false
local state: State = "Lobby"
--[[ `os.clock()` at which the pending transition fires, or nil when the run is
     waiting on the player rather than on a clock. ]]
local resumeAt: number? = nil
--[[ `os.clock()` at which the crystals on the floor are drawn in, set when a
     fight clears. ]]
local collectAt: number? = nil

local function total(): number
	local current = stage()
	if current.mode == "Waves" then
		return current.waves or 1
	end
	return #(current.rooms or {})
end

local function unit(): string
	return if stage().mode == "Waves" then "Wave" else "Room"
end

--[[ What the HUD prints beside the counter: the room's name, or what kind
     of wave this is. ]]
local function label(): string
	local current = stage()
	if current.mode == "Waves" then
		local kind = Waves.kind(progress)
		return if kind == "Fight" then current.name else kind
	end
	local rooms = current.rooms or {}
	return Balance.Rooms[rooms[progress]].name
end

local function broadcast()
	--[[ For the client's camera, music and HUD (`Camera/TopDownCamera`). ]]
	workspace:SetAttribute("InLobby", state == "Lobby")
	if state == "Lobby" then
		runStateChanged:FireAllClients(0, 0, "Lobby", "Lobby", "Lobby")
		return
	end
	runStateChanged:FireAllClients(progress, total(), state, label(), unit())
end

--[[ Lights or puts out the exit gate, and tells every client whether it is
     open: while it is, players walk at `Balance.Player.exitRush` times
     their speed, so the walk to the gate after a clear is quick. ]]
--[[ How far through the story everyone in the run now is, for the
     FARTHEST ADVENTURERS board (`Run/StoryLeaderboard`): the campaign's
     earlier stages and this one's rooms up to the one just cleared. A stage
     outside the campaign, the sandbox and a Studio jump record nothing. ]]
local function recordStory()
	if sandbox or jumped then
		return
	end
	local score = StoryProgress.score(Balance.campaign, Balance.Stages, stageIndex, progress)
	if not score then
		return
	end
	--[[ A later area's portal can be walked into straight from the lobby:
	     its rooms count only for a player who has already come that far,
	     so nobody is credited with areas they skipped. ]]
	local start = StoryProgress.score(Balance.campaign, Balance.Stages, stageIndex, 0) or 0
	for _, session in RunSession.all() do
		StoryLeaderboard.record(session.player, score, start)
	end
end

local function setDoorOpen(open: boolean)
	Arena.setDoorOpen(open)
	workspace:SetAttribute("ExitOpen", open)
end

--[[
	Tears the arena down and builds `layout` in its place.

	Rebuilt rather than edited, so a room can never inherit a pillar from the
	last one, and the raycast filters are refreshed because both of them point
	at folders that no longer exist after this. Nothing in flight survives:
	an arrow fired at the last enemy of the old room would otherwise arrive in
	the new one.
]]
local function buildArena(layout: Balance.RoomConfig)
	Arena.build(workspace, layout.obstacles, layout.arena)
	--[[ A new room's gate is built shut. ]]
	workspace:SetAttribute("ExitOpen", false)
	EnemyManager.init(workspace)

	ProjectileSystem.clear()
	MeleeSystem.clear()
	Burning.clear()
	AreaStrikes.clear()
	Pickups.clear()
	collectAt = nil
	ProjectileSystem.refreshFilters()

	--[[ Players are put back at the start. Without this they would begin the
	     next fight standing on what used to be the door, the far end of the
	     room from where its enemies spawn. ]]
	for _, session in RunSession.all() do
		local root = session.root
		if root then
			root.CFrame = CFrame.new(Balance.Arena.spawnPosition)
		end
	end
end

--[[ The kinds of enemy a room brings, by `EnemyConfig.displayName`: its
     roster and what they split into or summon. ]]
local function rosterNames(room: Balance.RoomConfig): { string }
	local names: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(config: Balance.EnemyConfig?)
		if not config or seen[config.displayName] then
			return
		end
		seen[config.displayName] = true
		table.insert(names, config.displayName)
		add(config.split and config.split.into)
		local boss = config.boss
		add(boss and boss.summon and boss.summon.into)
	end
	for _, config in room.roster do
		add(config)
	end
	return names
end

--[[ Bumped on every room entered, so a preparation scheduled for a room
     left early (a death, a debug jump) never runs. ]]
local entered = 0

--[[ Builds the next room in the background while this one is played
     (`Arena.prepare`), after `Balance.Run.prepareDelay`, so the work and its
     replication land mid-fight rather than on the room's first frames or on
     the door. ]]
local function prepareNext(position: number)
	entered += 1
	local ticket = entered
	local rooms = stage().rooms or {}
	local nextRoom = Balance.Rooms[rooms[position + 1]]
	if not nextRoom then
		return
	end
	task.delay(Balance.Run.prepareDelay, function()
		if ticket ~= entered or progress ~= position then
			return
		end
		local began = os.clock()
		Arena.prepare(nextRoom.obstacles, nextRoom.arena, rosterNames(nextRoom))
		log.info(
			"prepared room %d (%s) in %.1f ms",
			position + 1,
			nextRoom.name,
			(os.clock() - began) * 1000
		)
	end)
end

local function enterRoom(position: number)
	progress = position
	state = "Fighting"
	resumeAt = nil

	local rooms = stage().rooms or {}
	local room = Balance.Rooms[rooms[position]]

	local began = os.clock()
	buildArena(room)
	RunSession.setRoom(position)
	Arena.setDoorLabel(if position < total() then tostring(position + 1) else "")
	EnemyManager.spawnWave(room.enemyCount, room.roster)
	-- the Mossback Snail's shell is up once a room
	PetCombat.newRoom()

	log.info(
		"entered room %d/%d — %s (%.1f ms)",
		position,
		total(),
		room.name,
		(os.clock() - began) * 1000
	)
	broadcast()
	prepareNext(position)
end

--[[
	Starts wave `wave` in the arena already standing. A fight spawns its
	roster behind the usual markers; a Valkyrie or an Angel opens its offer to
	every player and the run waits on their choice, paused like a level-up.
]]
local function startWave(wave: number)
	progress = wave
	resumeAt = nil

	local description = Waves.describe(wave, total())

	if description.kind == "Valkyrie" or description.kind == "Angel" then
		state = "Choosing"
		for _, session in RunSession.all() do
			RunSession.offerEncounter(session, description.kind)
		end

		--[[ A Valkyrie leaves hearts behind, in the middle of the arena where
		     whoever wants one has to go and get it. ]]
		if description.kind == "Valkyrie" then
			for index = 1, Balance.Waves.valkyrieHearts do
				local offset = Vector3.new((index - 1) * 3, 0, 0)
				Pickups.dropHeart(Arena.resolve(offset, 1))
			end
		end
	else
		state = "Fighting"
		EnemyManager.spawnWave(description.count, description.roster)
		PetCombat.newRoom()
	end

	log.info("wave %d/%d — %s", wave, total(), description.kind)
	broadcast()
end

local function startStage()
	local current = stage()
	RunSession.holdOffers(false)

	for _, session in RunSession.all() do
		RunSession.newStage(session)
	end
	-- the tutorial's fixed hands, class and pool (`Config/Tutorial`)
	RunSession.setTutorial(current.tutorial == true)

	if current.mode == "Waves" then
		jumped = false
		buildArena(Balance.Rooms[current.arena or 1])
		startWave(1)
	else
		--[[ In Studio, the room `Sandbox.startRoom` names, to test a late
		     room straight from Play. ]]
		local first = if RunService:IsStudio() and Sandbox.startRoom
			then math.clamp(Sandbox.startRoom, 1, total())
			else 1
		jumped = first > 1
		enterRoom(first)
	end
end

--[[ At boot: the lobby, until a portal starts a run. ]]
function RoomController.start()
	workspace:SetAttribute(CurrentStage.ATTRIBUTE, stageIndex)
	state = "Lobby"
	broadcast()
end

--[[ A portal: run stage `index` (a `Balance.Stages` entry), published as
     the Workspace's `Stage` so both sides read it (`Util/CurrentStage`).
     From there NEXT LEVEL follows `Balance.campaign` as before. ]]
function RoomController.beginStage(index: number)
	if state ~= "Lobby" or not Balance.Stages[index] then
		return
	end
	stageIndex = index
	workspace:SetAttribute(CurrentStage.ATTRIBUTE, stageIndex)
	for _, session in RunSession.all() do
		RunSession.resetRun(session)
	end
	startStage()
end

--[[ Everyone in the lobby, before a run. ]]
function RoomController.inLobby(): boolean
	return state == "Lobby"
end

--[[ Testing only, from `Remotes.DebugRoom` in Studio: straight into room
     `position` of a Rooms stage, so a late room (the boss) can be tested
     without fighting through the rest. ]]
function RoomController.debugEnterRoom(position: number)
	if stage().mode ~= "Rooms" or position < 1 or position > total() then
		return
	end
	RunSession.holdOffers(false)
	jumped = true
	enterRoom(position)
end

--[[
	Tells each player how the stage went, for the end screen: won or lost,
	which stage, this stage's kills and time, health left, and how far
	through it they got. Sent at the moment the run ends, so the time and
	health are the ones the player finished with.
]]
local function sendSummary(won: boolean)
	local finished = if won then progress else progress - 1
	local progressPercent =
		math.clamp(math.floor(finished / math.max(total(), 1) * 100 + 0.5), 0, 100)

	for _, session in RunSession.all() do
		local healthPercent = if session.maxHealth > 0
			then math.clamp(math.floor(session.health / session.maxHealth * 100 + 0.5), 0, 100)
			else 0

		runSummary:FireClient(session.player, {
			won = won,
			stage = stageIndex,
			kills = session.stageKills,
			seconds = math.floor(os.clock() - session.stageStartedAt),
			healthPercent = healthPercent,
			progressPercent = progressPercent,
			coins = session.stageCoins,
			gems = session.stageGems,
		})
	end
end

--[[ Called when a player dies. The run ends; it does not continue without
     them, because a run that carries on after death has no stakes. ]]
function RoomController.onPlayerDied()
	if state == "Dead" then
		return
	end

	state = "Dead"
	resumeAt = os.clock() + Balance.Run.deathPause
	setDoorOpen(false)

	log.info("run ended at %s %d/%d", unit():lower(), progress, total())
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

local function complete(now: number)
	state = "Complete"
	-- the area's clear bonus, before the summary that shows it
	for _, session in RunSession.all() do
		RunSession.payCoins(session, RunSession.areaPay().clearCoins)
	end
	resumeAt = now + Balance.Run.deathPause
	setDoorOpen(false)
	recordStory()
	log.info("run complete")
	broadcast()
	sendSummary(true)
end

--[[ Rooms: hold the pause after a clear, light the door, wait for a player
     to step on it. ]]
local function stepRooms(now: number)
	if resumeAt then
		if now < resumeAt then
			return
		end

		resumeAt = nil
		setDoorOpen(true)
	end

	if not anyPlayerAtDoor() then
		return
	end

	if progress >= total() then
		complete(now)
		return
	end

	enterRoom(progress + 1)
end

--[[ Waves: hold the pause after a clear, then bring the next wave in place —
     or finish, after the last. ]]
local function stepWaves(now: number)
	if resumeAt and now < resumeAt then
		return
	end

	if progress >= total() then
		complete(now)
		return
	end

	startWave(progress + 1)
end

--[[
	A player pressed the end screen's button. Honoured only once the run has
	ended and the end screen's guard time has passed, so a request sent at
	any other moment — or by a client that never showed the screen — does
	nothing. A loss costs the build; a win keeps it into the next run.
]]
--[[ Whether the run has ended and is waiting on the end screen. ]]
function RoomController.isOver(): boolean
	return state == "Dead" or state == "Complete"
end

--[[
	Testing only, Studio: the playtest sandbox (`Config/Sandbox`). The room
	is rebuilt as the stage's first, with training dummies where its fight
	would be (`dummy` built from `Sandbox.dummy` by the caller), every player
	untouchable, and the run standing still: no clear, no next room, no
	wave. Leaving starts the stage again from the top.
]]
function RoomController.enterSandbox(dummy: Balance.EnemyConfig, spots: { Vector3 })
	sandbox = true
	progress = 1
	state = "Fighting"
	resumeAt = nil
	RunSession.holdOffers(true)

	local current = stage()
	local layout = if current.mode == "Waves"
		then Balance.Rooms[current.arena or 1]
		else Balance.Rooms[(current.rooms or {})[1]]
	buildArena(layout)
	Arena.setDoorLabel("")

	local radius = math.max(dummy.hitboxSize.X, dummy.hitboxSize.Z) / 2
	for _, spot in spots do
		local at = Arena.resolve(Vector3.new(spot.X, dummy.hitboxSize.Y / 2, spot.Z), radius)
		EnemyManager.spawn(dummy, 0, at)
	end
	for _, session in RunSession.all() do
		session.invulnerableUntil = math.huge
	end
	workspace:SetAttribute("Sandbox", true)
	log.info("sandbox: %d training dummies", #spots)
	broadcast()
end

function RoomController.leaveSandbox()
	if not sandbox then
		return
	end
	sandbox = false
	workspace:SetAttribute("Sandbox", false)
	startStage()
	log.info("left the sandbox")
end

function RoomController.inSandbox(): boolean
	return sandbox
end

function RoomController.requestRestart(): boolean
	if not RoomController.isOver() then
		return false
	end
	if resumeAt and os.clock() < resumeAt then
		return false
	end

	--[[ The tutorial won: on to the lobby, where the portals start the
	     campaign's runs (`Config/Tutorial`). ]]
	if state == "Complete" and stage().tutorial then
		for _, session in RunSession.all() do
			RunSession.resetRun(session)
		end
		RunSession.setTutorial(false)
		resumeAt = nil
		state = "Lobby"
		broadcast()
		for _, session in RunSession.all() do
			local character = session.character
			if character then
				Lobby.place(character)
			end
		end
		log.info("tutorial won: to the lobby")
		return true
	end

	if state == "Complete" then
		stageIndex = CurrentStage.nextAfter(Balance.campaign, stageIndex)
		workspace:SetAttribute(CurrentStage.ATTRIBUTE, stageIndex)
		log.info("on to stage %d, %s", stageIndex, stage().name)
	end

	log.info("restarting the run")

	--[[ Levels and abilities are run-local by design: a death costs the
	     build and nothing else, because the meta loop that would soften
	     that is Phase 6, and a new area starts from level one too (owner,
	     2026-10-25: "reset upgrades and go into thornwood"). Reset before
	     the stage is built, so the first wave meets a level-one archer. ]]
	for _, session in RunSession.all() do
		RunSession.resetRun(session)
	end

	resumeAt = nil
	startStage()
	return true
end

function RoomController.step(now: number)
	--[[ The sandbox holds the run where it is: its dummies never die. ]]
	if sandbox then
		return
	end
	--[[ Nothing runs in the lobby. ]]
	if state == "Lobby" then
		return
	end

	--[[ Over: the end screen is up, and the next run starts when a player
	     asks for it (`requestRestart`), not on a timer. ]]
	if state == "Dead" or state == "Complete" then
		return
	end

	--[[ A Valkyrie or an Angel. The world is already frozen while anyone is
	     choosing; once nobody is, the encounter counts as cleared. ]]
	if state == "Choosing" then
		if RunSession.anyChoosing() then
			return
		end

		state = "Cleared"
		resumeAt = now + Balance.Waves.pause
		recordStory()
		broadcast()
		return
	end

	if state == "Fighting" then
		if EnemyManager.aliveCount() > 0 then
			return
		end

		state = "Cleared"
		recordStory()
		--[[ The area's last fight (its boss) is won: no card for the levels
		     its crystals bring; they are dealt in the next stage. ]]
		if progress >= total() then
			RunSession.holdOffers(true)
			--[[ Its item and gems, as the boss falls (owner, 2026-10-25:
			     "the boss drop is guaranteed every time"). A Rooms stage
			     ends in its boss. ]]
			if stage().mode == "Rooms" and not stage().tutorial then
				RunSession.payBoss()
			end
		end
		--[[ Held for a beat after the last kill, so a clear reads as its own
		     moment rather than being swallowed by what comes next. ]]
		resumeAt = now
			+ (if stage().mode == "Waves" then Balance.Waves.pause else Balance.Run.clearPause)
		collectAt = now + Balance.Pickups.collectDelay
		broadcast()

		return
	end

	--[[ The fight's crystals, drawn in during the pause after it. Ahead of
	     everything that moves the run on, because the level-up they may bring
	     opens a card screen and pauses the world, and the next wave must wait
	     for it rather than arrive under it. ]]
	if collectAt then
		if now < collectAt then
			return
		end

		collectAt = nil
		RunSession.collectCrystals()
		-- a tutorial room that must level up does, before its gate opens
		RunSession.levelUpIfOwed()
		return
	end

	if stage().mode == "Waves" then
		stepWaves(now)
	else
		stepRooms(now)
	end
end

--[[ So a client joining mid-run is not left with an empty HUD. ]]
function RoomController.sendStateTo(player: Player)
	if state == "Lobby" then
		runStateChanged:FireClient(player, 0, 0, "Lobby", "Lobby", "Lobby")
		return
	end
	runStateChanged:FireClient(player, progress, total(), state, label(), unit())
end

Players.PlayerAdded:Connect(RoomController.sendStateTo)

return RoomController
