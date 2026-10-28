--!strict
--[[
	The run loop, in either of Archero 2's two stage shapes.

	- **Rooms:** fight → clear → the door opens → walk onto it → the next room
	  is built. The Phase 2 loop, unchanged.
	- **Waves:** one arena for the whole stage. A wave clears, a beat passes,
	  the next arrives in place. Some waves are not fights: a Valkyrie offers
	  one of two skills, an Angel a stat or a heal, and a boss wave closes each
	  block of ten. See `Waves` for the schedule.
	- **Endless:** the Waves loop with no last wave (`docs/ENDLESS.md`). A
	  floor clears, a beat passes, the next arrives; every tenth floor the
	  rotation moves on and the arena is rebuilt for the new area; every
	  tenth floor is also a boss, and after it a checkpoint beat with no
	  fight in it. The schedule, the curve and the rotation are all
	  `Waves`'s pure functions over `Balance.Endless` — this module decides
	  nothing about a floor but when to play it.

	Which shape a run takes is the current stage's `mode` — data,
	because it depends on where in the game a stage sits, not on anything the
	code should decide.

	Die, and the run goes back to the start of the stage. Win, and the
	level is saved as beaten (`Wallet.beatLevel`, which opens the next one),
	and NEXT LEVEL starts the next level of its portal (Mossy Glade 1-3, then
	1-4), upgrades reset, or goes back to the lobby after the last; a stage
	behind no portal follows `Balance.campaign`. The server owns all
	of it: the client is told where it is and what state the run is in, and
	never reports either. Stage progress is what areas unlock on in Phase 5,
	so a client that could claim a wave could claim an area.

	**Endless Soulstones vest at each boss floor** and are written to the
	profile there, not at the end of the run (`vestFloor`): a death or a
	disconnect costs the run but never what is already banked. Banking at a
	checkpoint keeps the block just cleared as well. The one-time milestones
	go with the best floor instead, every floor — see `clearedFloor`. The
	floor is the
	server's throughout — the client is told which floor it is on and never
	reports one, because the floor is what the board and the milestones pay
	on, and a client that could claim a floor could claim a Mythic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AreaStrikes = require(script.Parent.Parent.Combat.AreaStrikes)
local Arena = require(script.Parent.Parent.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Burning = require(script.Parent.Parent.Combat.Burning)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local EndlessLeaderboard = require(script.Parent.EndlessLeaderboard)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local LevelUnlocks = require(ReplicatedStorage.Shared.Util.LevelUnlocks)
local Lobby = require(script.Parent.Lobby)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
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
local Wallet = require(script.Parent.Parent.Data.Wallet)
local Waves = require(script.Parent.Waves)

local log = Log.forTag("Run")

local RoomController = {}

--[[ `Lobby`: before a run, everyone in the lobby (`Run/Lobby`), nothing
     fighting; a portal starts the next run (`beginStage`).
     `Checkpoint`: an Endless boss floor is cleared and the screen is up,
     waiting on every living player to pick (`docs/ENDLESS.md`). ]]
export type State =
	"Lobby"
	| "Fighting"
	| "Cleared"
	| "Choosing"
	| "Checkpoint"
	| "Dead"
	| "Complete"

local runStateChanged = Remotes.event(Remotes.RunStateChanged)
local runSummary = Remotes.event(Remotes.RunSummary)
local endlessCheckpoint = Remotes.event(Remotes.EndlessCheckpoint)

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

--[[
	Endless (`docs/ENDLESS.md`). All of it is cleared by `startStage`, so a
	new run never inherits a lap, a debt or a banked total from the last.
]]
--[[ Which `Balance.Endless.areas` entry the arena standing was built for,
     so it is rebuilt when the rotation moves on and not every floor. 0
     before the first floor of a run. ]]
local endlessArea = 0
--[[ Soulstones this run has paid each player, for the per-run cap. Per
     player rather than one number, because the cap is each player's
     (co-op-shaped from day one, non-negotiable 3). ]]
local endlessBanked: { [Player]: number } = {}
--[[ The cleared floor owes a draft (every third floor). Kept apart from
     `checkpointOwed` because the two are orthogonal: floor 30 owes both,
     and the draft is never displaced by the checkpoint or deferred past
     it. ]]
local draftOwed = false
--[[ The cleared floor was a boss floor, so a checkpoint beat is owed. ]]
local checkpointOwed = false
--[[ A checkpoint's EXTRA CARD, owed once its screen has closed. ]]
local extraDraftOwed = false
--[[ Which pick each player has made at the checkpoint now open; a living
     player missing from it is still being waited on. ]]
local picked: { [Player]: boolean } = {}

local function total(): number
	local current = stage()
	if current.mode == "Endless" then
		--[[ The hard cap. Endless has no last floor the player is working
		     towards, but the counter and the summary still want a total, and
		     the cap is the honest one. ]]
		return Waves.floorsTotal()
	end
	if current.mode == "Waves" then
		return current.waves or 1
	end
	return #(current.rooms or {})
end

local function unit(): string
	local mode = stage().mode
	if mode == "Endless" then
		return "Floor"
	end
	return if mode == "Waves" then "Wave" else "Room"
end

--[[ What the HUD prints beside the counter: the room's name, or what kind
     of wave this is. ]]
local function label(): string
	local current = stage()
	if current.mode == "Endless" then
		--[[ The area on a fight floor (the rotation is the thing worth
		     knowing), the kind of fight otherwise. ]]
		local kind = Waves.floorKind(progress)
		if kind == "Boss" then
			return "Boss"
		elseif kind == "Elite" then
			return "Mini-Boss"
		end
		return Balance.Endless.areas[Waves.floorArea(progress)].name
	end
	if current.mode == "Waves" then
		local kind = Waves.kindIn(current, progress, total())
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

	local description = Waves.describe(wave, total(), stage())

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

--[[
	Starts floor `floor` of an Endless run.

	The arena is rebuilt only when the rotation moves on to another area —
	through `Arena.build` (inside `buildArena`), which is the one path that
	tears a room down and bumps `layoutVersion` so the pathing grids
	rebuild. There is deliberately no second way to change the arena.

	The floor is published before anything spawns, because the enemies read
	the floor's curve as they are built (`EnemyManager`'s `difficulty`).
]]
local function startFloor(floor: number)
	progress = floor
	resumeAt = nil
	state = "Fighting"
	workspace:SetAttribute(CurrentStage.FLOOR_ATTRIBUTE, floor)

	local index = Waves.floorArea(floor)
	if index ~= endlessArea then
		endlessArea = index
		local area = Balance.Endless.areas[index]
		buildArena(Balance.Rooms[area.arena])
		--[[ Endless has no door to walk through, so its gate stays shut and
		     unnumbered for the whole run. ]]
		Arena.setDoorLabel("")
	end

	local description = Waves.describeFloor(floor)
	EnemyManager.spawnWave(description.count, description.roster)
	-- the Mossback Snail's shell is up once a floor
	PetCombat.newRoom()

	log.info(
		"floor %d — %s in %s, lap %d (%d enemies)",
		floor,
		description.kind,
		Balance.Endless.areas[index].name,
		Waves.floorLap(floor),
		description.count
	)
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

	if current.mode == "Endless" then
		jumped = false
		endlessArea = 0
		table.clear(endlessBanked)
		table.clear(picked)
		draftOwed = false
		checkpointOwed = false
		extraDraftOwed = false
		startFloor(1)
	elseif current.mode == "Waves" then
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
	if state == "Lobby" or state == "Dead" or state == "Complete" then
		return
	end
	if position ~= math.floor(position) or position < 1 or position > total() then
		return
	end
	RunSession.holdOffers(false)
	jumped = true
	if stage().mode == "Endless" then
		--[[ Straight to a floor, so a lap's modifiers and a deep curve can
		     be tested without playing twenty minutes up to them. Its clears
		     record nothing (`jumped`). ]]
		endlessArea = 0
		draftOwed = false
		checkpointOwed = false
		extraDraftOwed = false
		startFloor(position)
		return
	end
	if stage().mode == "Waves" then
		-- the arena built afresh (whatever is fighting goes), then that wave
		buildArena(Balance.Rooms[stage().arena or 1])
		startWave(position)
		return
	end
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

--[[ Seconds a clear is held before the run moves on, so a clear reads as
     its own moment: the stage's own beat, and a longer one after an Endless
     boss floor, whose checkpoint should not arrive on top of the boss
     falling. ]]
local function clearPause(): number
	local mode = stage().mode
	if mode == "Endless" then
		return if checkpointOwed then Balance.Endless.checkpoint.pause else Balance.Endless.pause
	end
	return if mode == "Waves" then Balance.Waves.pause else Balance.Run.clearPause
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

--[[ Whether the stage's last fight has a boss in it: its last room, or a
     Waves stage's last wave. The tutorial pays no boss. ]]
local function endsInBoss(): boolean
	local current = stage()
	if current.tutorial then
		return false
	end
	--[[ Endless never pays a boss this way: it has no `area`, so there is
	     no boss item or gems to pay, and its depth pays Soulstones at every
	     boss floor instead (`vestFloor`). ]]
	if current.mode == "Endless" then
		return false
	end
	local roster: { Balance.EnemyConfig }
	if current.mode == "Waves" then
		roster = Waves.describe(total(), total(), current).roster
	else
		local rooms = current.rooms or {}
		local last = Balance.Rooms[rooms[#rooms]]
		roster = if last then last.roster else {}
	end
	for _, config in roster do
		if config.boss then
			return true
		end
	end
	return false
end

local function complete(now: number)
	state = "Complete"
	local level = stage().level
	-- the area's clear bonus, before the summary that shows it
	for _, session in RunSession.all() do
		RunSession.payCoins(session, RunSession.areaPay().clearCoins)
		--[[ The level is won, for everyone in the run: saved, and the next
		     one opens. Decided here, never asked for. A Studio jump
		     (`debugEnterRoom`) counts, so unlocking can be tested there. ]]
		if level then
			Wallet.beatLevel(session.player, level)
		end
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

--[[
	An Endless boss floor is cleared: the block's Soulstones are written to
	the profile **here**, at the checkpoint, and not at the end of the run
	(`docs/ENDLESS.md`, "Bank or push").

	Lose it all on death and nobody pushes; lose nothing and there is no
	tension. Vesting every ten floors is the middle, and writing it at the
	checkpoint means a disconnect costs the run but never the rewards.

	Paid through `Data/Wallet`, which keeps each player's total under the
	run cap (non-negotiable 2). A Studio jump pays nothing — its clears are
	not a real run.
]]
local function vestFloor(floor: number)
	if jumped or sandbox then
		return
	end
	local pay = Waves.floorPay(floor)
	for _, session in RunSession.all() do
		local player = session.player
		local banked = endlessBanked[player] or 0
		endlessBanked[player] = banked + Wallet.addSoulstones(player, pay, banked)
	end
	log.info(
		"floor %d vested: %d Soulstones each (capped at %d a run)",
		floor,
		pay,
		Balance.Endless.runCap
	)
end

--[[
	An Endless floor is cleared: its best is recorded for every player and
	the board, any milestone it reached is claimed, what the floor owes is
	noted (a draft, a checkpoint), and a boss floor's Soulstones vest.
	Nothing here reads a client.

	**A milestone is claimed on reaching its floor, not at the next boss
	floor.** `docs/ENDLESS.md` lists one at floor 75 and also vests rewards
	at boss floors — but 75 is a mini-boss floor, so vesting them together
	would quietly hold that reward back to floor 80. The doc is inconsistent
	there, so the two are split: the one-time milestones go with the best
	floor, which is already written every floor and already survives a
	death, and the repeatable Soulstones keep the boss-floor vesting that
	the bank-or-push decision needs.
]]
local function clearedFloor(floor: number)
	draftOwed = Waves.floorDrafts(floor)
	checkpointOwed = Waves.floorKind(floor) == "Boss"

	if not jumped and not sandbox then
		for _, session in RunSession.all() do
			local player = session.player
			Wallet.recordEndlessFloor(player, floor)
			EndlessLeaderboard.record(player, floor)
			for _, milestone in Wallet.claimEndlessMilestones(player, floor) do
				log.info(
					"floor %d milestone for %s: %s",
					milestone.floor,
					player.Name,
					milestone.name
				)
			end
		end
	end

	if checkpointOwed then
		vestFloor(floor)
	end
end

--[[ The three a checkpoint offers, and a bank-and-leave beside them. The
     world holds still while it is up (`atCheckpoint`, read by `Main`'s
     loop), exactly as it does for a card screen. ]]
local function openCheckpoint()
	state = "Checkpoint"
	resumeAt = nil
	table.clear(picked)
	--[[ The area the next floor is in goes with it: the floor schedule is
	     this side's (`Waves`), so the screen is told rather than asked to
	     work it out. ]]
	local ahead = math.min(progress + 1, total())
	local area = Balance.Endless.areas[Waves.floorArea(ahead)].name
	for _, session in RunSession.all() do
		endlessCheckpoint:FireClient(
			session.player,
			progress,
			endlessBanked[session.player] or 0,
			area
		)
	end
	log.info("checkpoint after floor %d", progress)
	broadcast()
end

--[[ Endless: hold the pause after a clear, then settle what the floor owes
     before the next one arrives.

	The order is the contract: **the draft first**, because a draft is never
	displaced and never deferred (floor 30 is a boss that drafts); then the
	checkpoint; then the extra card a checkpoint granted; then the next
	floor, or the hard cap, which ends the run as a win.
]]
local function stepEndless(now: number)
	if resumeAt and now < resumeAt then
		return
	end

	if draftOwed then
		draftOwed = false
		state = "Choosing"
		for _, session in RunSession.all() do
			RunSession.offerEndlessDraft(session)
		end
		broadcast()
		return
	end

	if checkpointOwed then
		checkpointOwed = false
		openCheckpoint()
		return
	end

	if extraDraftOwed then
		extraDraftOwed = false
		state = "Choosing"
		for _, session in RunSession.all() do
			RunSession.offerEndlessDraft(session)
		end
		broadcast()
		return
	end

	--[[ The hard cap (`Balance.Endless.maxFloor`): nothing overflows and the
	     board stays bounded, and reaching it is a win rather than a stop. ]]
	if progress >= total() then
		complete(now)
		return
	end

	startFloor(progress + 1)
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

--[[ Whether an Endless checkpoint is open. `Main`'s loop holds the world
     still while it is, as it does for a card screen: nothing moves, nothing
     fires, and the run only goes on once every living player has picked. ]]
function RoomController.atCheckpoint(): boolean
	return state == "Checkpoint"
end

--[[
	A player picked at the checkpoint: `choice` is an index into
	`Balance.Endless.checkpoint.picks`, or 0 to bank and leave.

	Everything about it is checked here, because it all comes from a client
	(non-negotiable 2): that a checkpoint is actually open, that this player
	is in the run and has not picked already, and that the index is one of
	the picks. A client that lies can only take a different one of the three
	it was already going to be allowed to take — it can never name a floor,
	a payout or an amount.

	Banking ends the run as a win, with everything already vested kept: it
	is the "leave at a checkpoint" half of the mode's one real decision.
	The run goes on once every living player has picked.
]]
function RoomController.endlessPick(player: Player, choice: unknown): boolean
	if state ~= "Checkpoint" then
		return false
	end
	local session = RunSession.get(player)
	if not session or picked[player] then
		return false
	end
	if type(choice) ~= "number" or choice ~= math.floor(choice) then
		return false
	end
	local picks = Balance.Endless.checkpoint.picks
	if choice ~= 0 and not picks[choice] then
		return false
	end

	--[[ BANK & LEAVE: the run ends here, a win, and everything vested at
	     this and every earlier boss floor is already in the profile. ]]
	if choice == 0 then
		picked[player] = true
		log.info("%s banks at floor %d", player.Name, progress)
		complete(os.clock())
		return true
	end

	picked[player] = true
	local pick = picks[choice]
	if pick.key == "Heal" then
		RunSession.heal(session, session.maxHealth, true)
	elseif pick.key == "Card" then
		extraDraftOwed = true
	elseif pick.key == "Shop" then
		--[[ **The Endless shop is not built yet** (`Balance.Endless.checkpoint`):
		     this pays its stand-in bundle, still under the run's cap, and is
		     the one place to swap when the shop lands. ]]
		local banked = endlessBanked[player] or 0
		local paid = Wallet.addSoulstones(player, Balance.Endless.checkpoint.shopBundle, banked)
		endlessBanked[player] = banked + paid
	end
	log.info("%s takes %s at floor %d", player.Name, pick.name, progress)

	--[[ Still waiting on somebody. A dead player is not waited on — the run
	     is over for them anyway. ]]
	for _, other in RunSession.all() do
		if other.alive and not picked[other.player] then
			return true
		end
	end

	--[[ Everybody has picked: on with the run, through `stepEndless`, so the
	     extra card a pick granted is dealt in the one place that deals
	     them. ]]
	table.clear(picked)
	state = "Cleared"
	resumeAt = nil
	broadcast()
	return true
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
	local layout
	if current.mode == "Endless" then
		layout = Balance.Rooms[Balance.Endless.areas[1].arena]
	elseif current.mode == "Waves" then
		layout = Balance.Rooms[current.arena or 1]
	else
		layout = Balance.Rooms[(current.rooms or {})[1]]
	end
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

--[[ Everyone back to the lobby's campfire, the run put away: after the
     tutorial, and after an area's last level. ]]
local function toLobby()
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
end

--[[ The level after stage `index`, by the portal whose levels hold it
     (`Config/Lobby`): its next, nil after its last, and whether any portal
     holds it (a stage behind none follows `Balance.campaign`). ]]
local function nextLevel(index: number): (number?, boolean)
	for _, portal in LobbyConfig.portals do
		local levels = portal.levels
		if levels then
			local after, found = LevelUnlocks.nextAfter(levels, index)
			if found then
				return after, true
			end
		end
	end
	return nil, false
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
		toLobby()
		log.info("tutorial won: to the lobby")
		return true
	end

	if state == "Complete" then
		--[[ NEXT LEVEL: the portal's next level, or the lobby after its
		     last (owner, 2026-10-26: Mossy Glade 1-1 to 1-10). ]]
		local nextIndex, behindPortal = nextLevel(stageIndex)
		if behindPortal and not nextIndex then
			toLobby()
			log.info("%s won, its area's last level: to the lobby", stage().name)
			return true
		end
		stageIndex = nextIndex or CurrentStage.nextAfter(Balance.campaign, stageIndex)
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

	--[[ And an Endless checkpoint waits on its screen, not on a clock, so
	     the run stands still until every living player has picked
	     (`endlessPick`). `Main`'s loop already holds for it; this is the
	     backstop, so nothing here can advance a floor under the screen. ]]
	if state == "Checkpoint" then
		return
	end

	--[[ A Valkyrie or an Angel. The world is already frozen while anyone is
	     choosing; once nobody is, the encounter counts as cleared. ]]
	if state == "Choosing" then
		if RunSession.anyChoosing() then
			return
		end

		state = "Cleared"
		resumeAt = now + clearPause()
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
		--[[ Endless: the floor's best, what it owes, and a boss floor's
		     rewards, before anything moves the run on. ]]
		if stage().mode == "Endless" then
			clearedFloor(progress)
		end
		--[[ The area's last fight (its boss) is won: no card for the levels
		     its crystals bring; they are dealt in the next stage. ]]
		if progress >= total() then
			RunSession.holdOffers(true)
			--[[ Its item and gems, as the boss falls (owner, 2026-10-25:
			     "the boss drop is guaranteed every time"): only a stage
			     whose last fight is a boss (Thornwood's, Mossy Glade
			     1-10's), never 1-1..1-9's elite fights. ]]
			if endsInBoss() then
				RunSession.payBoss()
			end
		end
		--[[ Held for a beat after the last kill, so a clear reads as its own
		     moment rather than being swallowed by what comes next. ]]
		resumeAt = now + clearPause()
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

	local mode = stage().mode
	if mode == "Endless" then
		stepEndless(now)
	elseif mode == "Waves" then
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
