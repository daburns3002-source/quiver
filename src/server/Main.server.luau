--!strict
--[[
	Server entry point.

	Builds the Phase 1 room, binds a run session per player, and drives the
	three systems from one loop so their order is explicit rather than emergent:

		enemies move and swing
		players fire
		projectiles travel and resolve

	Projectiles step last so a shot fired this frame starts from where the
	player actually is, and an enemy that moved this frame is where the raycast
	expects it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--[[ Every remote, before anything else loads or builds: a client waits only
     so long for one, and the lobby's meshes keep a fresh live server busy
     for longer than that (`Net/Remotes.createAll`). ]]
require(ReplicatedStorage.Shared.Net.Remotes).createAll()

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AreaStrikes = require(script.Parent.Combat.AreaStrikes)
local Arena = require(script.Parent.Arena.Arena)
local Atmosphere = require(script.Parent.Arena.Atmosphere)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Burning = require(script.Parent.Combat.Burning)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local EnemyFiring = require(script.Parent.Combat.EnemyFiring)
local EnemyManager = require(script.Parent.Enemies.EnemyManager)
local EnemyModel = require(script.Parent.Enemies.EnemyModel)
local FiringSystem = require(script.Parent.Combat.FiringSystem)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local HeldWeapon = require(script.Parent.Combat.HeldWeapon)
local Lobby = require(script.Parent.Run.Lobby)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local MeleeSystem = require(script.Parent.Combat.MeleeSystem)
local PetCombat = require(script.Parent.Combat.PetCombat)
local PetCombatConfig = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetPreview = require(script.Parent.Dev.PetPreview)
local PlayerData = require(script.Parent.Data.PlayerData)
local ProjectileSystem = require(script.Parent.Combat.ProjectileSystem)
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Net.Remotes)
local RoomController = require(script.Parent.Run.RoomController)
local RunSession = require(script.Parent.Run.RunSession)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local StoryLeaderboard = require(script.Parent.Run.StoryLeaderboard)
local UpgradeEffects = require(script.Parent.Fx.UpgradeEffects)
local Wallet = require(script.Parent.Data.Wallet)
local WeaponShop = require(script.Parent.Data.Shop)

local log = Log.forTag("Server")

log.info("%s v%s booting", Game.Name, Game.Version)

--[[ Saved data first, so a profile is loading while everything else boots;
     each player is told their wallet once it is in. ]]
PlayerData.onLoaded(Wallet.send)
PlayerData.start()
WeaponShop.start()

--[[
	Where Roblox drops a character on join and on respawn.

	Reads the same `spawnPosition` the run controller uses when it moves
	players into a new room, so arriving and advancing put you in the same
	place. Two sources of truth for "the start of a room" would drift the first
	time either moved.
]]
local function buildSpawn(parent: Instance)
	local existing = parent:FindFirstChild("ArenaSpawn")
	if existing then
		existing:Destroy()
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "ArenaSpawn"
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = Balance.Arena.spawnPosition
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.CastShadow = false
	spawnLocation.Transparency = 1
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = parent
end

buildSpawn(workspace)

--[[ The run controller owns the arena now: it builds a room on entry, so
     there is nothing to build here. ]]
RunSession.onDeath = function()
	RoomController.onPlayerDied()
end

RunSession.onRevive = function(_session, position: Vector3)
	ProjectileSystem.clearEnemyShotsNear(position, Balance.Revive.clearRadius)
end

Atmosphere.apply()
-- Uploaded enemy meshes, made once before anything spawns.
EnemyModel.preload()
-- Uploaded arena meshes, likewise, before the first room is built.
Arena.preload()
-- The archer's bow.
HeldWeapon.preload()
-- The upgrade cards' effects, built in the background for clients to copy.
UpgradeEffects.start()
-- The lobby, where players arrive after BEGIN ADVENTURE.
Lobby.build(workspace)
RoomController.start()
-- The FARTHEST ADVENTURERS board's store (`Run/StoryLeaderboard`).
StoryLeaderboard.start()
do
	-- written on the lobby's board, each area named as its portal is
	local face = Lobby.leaderboardFace()
	if face then
		local areaNames: { [number]: string } = {}
		for _, portal in LobbyConfig.portals do
			local levels: { number } = portal.levels or {}
			for _, stage in levels do
				if portal.name then
					areaNames[stage] = portal.name
				end
			end
		end
		StoryLeaderboard.attach(face, areaNames)
	end
end

--[[ The weapon in the player's hand: the one `RunSession.applyLoadout`
     recorded, which a drafted card can change (the Dual Bows Mythic), or
     the class's own before any loadout has been applied. ]]
local function weaponFor(player: Player): string
	local recorded = player:GetAttribute("Weapon")
	if type(recorded) == "string" then
		return recorded
	end
	local session = RunSession.get(player)
	return Classes[if session then session.loadout.class else "Ranger"].weapon
end

--[[ The weapon in hand during a run, nothing in the lobby (owner,
     2026-10-25); and jumping in the lobby only (2026-10-26,
     `RunSession.allowJump`). Called whenever either can change. ]]
local function refreshWeapon(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local session = RunSession.get(player)
	if session then
		RunSession.allowJump(session, RoomController.inLobby())
	end
	if RoomController.inLobby() then
		HeldWeapon.unequip(character)
	else
		HeldWeapon.equip(character, weaponFor(player))
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local session = RunSession.get(player) or RunSession.create(player)
	RunSession.bindCharacter(session, character)
	refreshWeapon(player)
	-- in the lobby, a new body appears at the lobby's campfire
	if RoomController.inLobby() and not session.atTitle then
		task.defer(Lobby.place, character)
	end
	--[[ Enemy projectiles raycast against player characters, so the filter has
	     to learn about each new body. Without this a respawned player is
	     invisible to every enemy shot. ]]
	ProjectileSystem.refreshFilters()
end

local function onPlayerAdded(player: Player)
	local session = RunSession.create(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	player.CharacterRemoving:Connect(function()
		RunSession.unbindCharacter(session)
	end)

	--[[ A drafted card (the Dual Bows Mythic) or a class change can swap
	     the weapon mid-run. ]]
	player:GetAttributeChangedSignal("Weapon"):Connect(function()
		refreshWeapon(player)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- into the lobby and out of it: the weapon goes away and comes back
workspace:GetAttributeChangedSignal("InLobby"):Connect(function()
	for _, player in Players:GetPlayers() do
		refreshWeapon(player)
	end
end)

--[[
	The client picks a card.

	The only thing it is trusted with is an index into an offer this server
	sent it moments ago, and `Loadout.choose` checks even that. Anything else
	arriving here — a string, a float, an index out of range, a choice with no
	offer open — changes nothing.
]]
Remotes.event(Remotes.AbilityChosen).OnServerEvent:Connect(function(player, index)
	if typeof(index) ~= "number" then
		return
	end

	local session = RunSession.get(player)
	if not session then
		return
	end

	RunSession.chooseAbility(session, index)
end)

--[[ The client asks for a redeal. It sends nothing else: whether there is a
     hand to redeal and a reroll to spend is the server's to decide. ]]
--[[ Testing only: the next hand includes a Mythic. Honoured only when the
     game is running in Studio, so nothing a live client sends can use it. ]]
local FORCEABLE = { Mythic = true, Legendary = true }

Remotes.event(Remotes.DebugForceMythic).OnServerEvent:Connect(function(player, rarity)
	if not RunService:IsStudio() then
		return
	end
	local wanted = if typeof(rarity) == "string" and FORCEABLE[rarity] then rarity else "Mythic"
	local session = RunSession.get(player)
	if session then
		session.loadout.forceRarity = wanted
		log.info("%s queued a %s for the next hand (Studio)", player.Name, wanted)
	end
end)

--[[ Testing only: switch class, the order fixed so the key cycles. Honoured
     only in Studio, like the Mythic key. The run's drafted skills stay; a
     skill the new class cannot be dealt keeps working if already held. ]]
local CLASS_ORDER = { "Ranger", "Arcanist", "Warden" }

Remotes.event(Remotes.DebugNextClass).OnServerEvent:Connect(function(player)
	if not RunService:IsStudio() then
		return
	end
	local session = RunSession.get(player)
	if not session then
		return
	end
	local at = table.find(CLASS_ORDER, session.loadout.class) or 0
	local class = CLASS_ORDER[at % #CLASS_ORDER + 1]
	session.loadout.class = class
	-- the class's own weapon, not one the sandbox put in hand
	session.loadout.weapon = nil
	RunSession.applyLoadout(session)
	log.info("%s is now a %s (Studio)", player.Name, class)
end)

--[[ Testing only: one more level of a named card, within its levels.
     Honoured only in Studio, like the keys above. ]]
Remotes.event(Remotes.DebugGrant).OnServerEvent:Connect(function(player, id)
	if not RunService:IsStudio() or typeof(id) ~= "string" then
		return
	end
	local session = RunSession.get(player)
	local ability = Abilities.byId[id]
	if not session or not ability then
		return
	end
	local counts = session.loadout.counts
	counts[id] = math.min((counts[id] or 0) + 1, #ability.levels)
	RunSession.applyLoadout(session)
	log.info("%s was granted %s (Studio)", player.Name, id)
end)

--[[ Testing only: straight into a room. Honoured only in Studio. ]]
Remotes.event(Remotes.DebugRoom).OnServerEvent:Connect(function(player, position)
	if not RunService:IsStudio() or type(position) ~= "number" or not RunSession.get(player) then
		return
	end
	RoomController.debugEnterRoom(math.floor(position))
	log.info("%s jumped to room %d (Studio)", player.Name, math.floor(position))
end)

Remotes.event(Remotes.DebugSpawnEnemy).OnServerEvent:Connect(function(_player, name)
	if not RunService:IsStudio() or type(name) ~= "string" then
		return
	end
	local config = (Balance.Enemies :: any)[name]
	if config then
		EnemyManager.spawn(config)
	end
end)

--[[ Testing only: build the imported pets so the client can preview them
     following the player. Honoured only in Studio. ]]
Remotes.event(Remotes.DebugPetPreview).OnServerEvent:Connect(function(player)
	if not RunService:IsStudio() then
		return
	end
	local count = PetPreview.build()
	log.info("%s previews %d pets (Studio)", player.Name, count)
end)

--[[ Testing only: the playtest sandbox (`Config/Sandbox`). In, the room
     becomes training dummies; out, the stage starts again. Honoured only in
     Studio. ]]
Remotes.event(Remotes.DebugSandbox).OnServerEvent:Connect(function(player, on)
	if not RunService:IsStudio() or type(on) ~= "boolean" or not RunSession.get(player) then
		return
	end
	if on then
		local dummy =
			table.clone((Balance.Enemies :: any)[Sandbox.dummy.archetype]) :: Balance.EnemyConfig
		dummy.dummy = true
		dummy.health = Sandbox.dummy.health
		dummy.xpReward = 0
		RoomController.enterSandbox(dummy, Sandbox.dummy.spots)
	else
		RoomController.leaveSandbox()
	end
	log.info("%s %s the sandbox (Studio)", player.Name, if on then "entered" else "left")
end)

--[[ Testing only: hold a weapon from the sandbox's list, as its class.
     Honoured only in Studio. ]]
--[[ Testing only: the pet at heel in a run (`Config/PetCombat`), as the
     sandbox picks it, until Phase 6 brings equipping. Honoured only in
     Studio. ]]
Remotes.event(Remotes.DebugPet).OnServerEvent:Connect(function(player, key)
	if not RunService:IsStudio() then
		return
	end
	if key == nil or (type(key) == "string" and PetCombatConfig.pets[key]) then
		player:SetAttribute("Pet", key)
		log.info("%s has %s at heel (Studio)", player.Name, tostring(key))
	end
end)

Remotes.event(Remotes.DebugWeapon).OnServerEvent:Connect(function(player, name)
	if not RunService:IsStudio() or type(name) ~= "string" then
		return
	end
	local session = RunSession.get(player)
	if not session then
		return
	end
	for _, entry in Sandbox.weapons do
		if entry.weapon == name then
			session.loadout.class = entry.class
			session.loadout.weapon = entry.weapon
			RunSession.applyLoadout(session)
			log.info("%s holds the %s as a %s (Studio)", player.Name, name, entry.class)
			return
		end
	end
end)

--[[
	Earthbreaker (the Warden's Mythic): a dash ends in a leap and a slam
	where he comes down, and the ground there erupts for a while. Only for
	a session holding the card, and no sooner than the dash's own cooldown
	allows (less a little for the trip), so a client cannot fire slams at
	will. Where he lands is his character's, as every position is.
]]
Remotes.event(Remotes.DashStarted).OnServerEvent:Connect(function(player)
	local session = RunSession.get(player)
	local root = session and session.root
	if not session or not root or not session.alive or session.earthbreaker <= 0 then
		return
	end
	local now = os.clock()
	local dash = Balance.Player.dash
	if now - session.lastDashAt < dash.cooldown * 0.8 then
		return
	end
	session.lastDashAt = now
	local quake = Balance.Player.earthbreaker
	local damage = session.damage
	AreaStrikes.strike({
		owner = player,
		at = root.Position,
		follow = root,
		radius = quake.slamRadius,
		damage = damage * quake.slamDamage,
		delay = dash.duration + quake.leap,
		now = now,
		impact = "GroundSlam",
		landed = function(at: Vector3)
			AreaStrikes.zone(
				player,
				at,
				quake.crackRadius,
				damage * quake.crackDamage,
				quake.crackEvery,
				quake.crackDuration,
				os.clock(),
				"Cracks"
			)
		end,
	})
end)

Remotes.event(Remotes.AbilityReroll).OnServerEvent:Connect(function(player)
	local session = RunSession.get(player)
	if session then
		RunSession.reroll(session)
	end
end)

--[[ The end screen's button. Only a player in the run may ask, and
     `requestRestart` ignores the request unless the run is over. ]]
Remotes.event(Remotes.RunRestart).OnServerEvent:Connect(function(player)
	if RunSession.get(player) then
		RoomController.requestRestart()
	end
end)

--[[ The intro's BEGIN ADVENTURE: this player has left the title screen.
     It can only clear the hold, never set one, so a repeat changes nothing. ]]
Remotes.event(Remotes.IntroBegin).OnServerEvent:Connect(function(player)
	local session = RunSession.get(player)
	--[[ Off the title and the story cutscene and into the tutorial
	     (`Config/Tutorial`), which is won into the lobby. Only a player who
	     was still on the title starts it, so a repeat, or a client in the
	     lobby, cannot pull everyone back into it. ]]
	if not session or not session.atTitle then
		return
	end
	RunSession.leaveTitle(session)
	if RoomController.inLobby() then
		RoomController.beginStage(Balance.tutorialStage)
	end
end)

--[[ START on a portal's screen (`UI/PortalScreen`): which portal and which
     of its levels. The server decides: only in the lobby, off the title, and
     only for the portal the player stands at (`Lobby.startFor`). ]]
Remotes.event(Remotes.PortalStart).OnServerEvent:Connect(function(player, index, level)
	local session = RunSession.get(player)
	local root = session and session.root
	if not session or session.atTitle or not root or not RoomController.inLobby() then
		return
	end
	local stage = Lobby.startFor(root.Position, index, level)
	if stage then
		RoomController.beginStage(stage)
	end
end)

--[[ Which portal's screen each player has open (`Remotes.PortalOpen`), so
     it is sent only as they step in or out. ]]
local portalShown: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	portalShown[player] = nil
end)

--[[ GOT IT! on a NEW ENEMY! screen. Only clears a screen the server opened. ]]
Remotes.event(Remotes.NewEnemySeen).OnServerEvent:Connect(function(player, kind)
	local session = RunSession.get(player)
	if session then
		RunSession.metEnemy(session, kind)
	end
end)

--[[ Whether last frame's step was skipped because the world was held. The
     first frame it runs again, every attack starts over
     (`RunSession.resumeAttacks`). ]]
local wasHeld = false

RunService.Heartbeat:Connect(function(deltaTime: number)
	local now = os.clock()

	--[[ The world holds still while a card screen is up. A draft read under
	     fire is not a choice, and a player who takes damage while reading one
	     will stop reading them. ]]
	if RunSession.anyChoosing() then
		wasHeld = true
		return
	end

	--[[ And while a boss's entry banner plays: nobody moves or attacks until
	     it has gone (`EnemyManager.introHolding`). ]]
	if EnemyManager.introHolding(now) then
		wasHeld = true
		return
	end

	--[[ And while anyone is still on the intro's title screen
	     (`UI/IntroCutscene`): the run starts on BEGIN ADVENTURE. ]]
	if RunSession.anyAtTitle() then
		wasHeld = true
		return
	end

	--[[ In the lobby: nothing fights; stepping into an active portal opens
	     its screen, whose START asks for the run (`Remotes.PortalStart`;
	     owner, 2026-10-26: "need screen for portal entry with the level
	     selector"), and stepping out closes it. ]]
	if RoomController.inLobby() then
		for player, session in RunSession.all() do
			local root = session.root
			local index = if root and not session.atTitle
				then Lobby.portalAt(root.Position)
				else nil
			local shown = index or 0
			if portalShown[player] ~= shown then
				portalShown[player] = shown
				Remotes.event(Remotes.PortalOpen):FireClient(player, shown)
			end
		end
		wasHeld = true
		return
	end
	-- out of the lobby, every portal screen is shut
	if next(portalShown) then
		for player, shown in portalShown do
			if shown ~= 0 then
				Remotes.event(Remotes.PortalOpen):FireClient(player, 0)
			end
		end
		table.clear(portalShown)
	end

	--[[ And while anyone reads a NEW ENEMY! screen, until GOT IT!
	     (`Config/NewEnemies`). ]]
	if RunSession.anyMeeting() then
		wasHeld = true
		return
	end

	--[[ And behind the end screen, which now waits for its button rather
	     than a 2.5 s timer. A character respawns after five seconds; left
	     running, the arena killed it again behind the screen, every time. ]]
	if RoomController.isOver() then
		wasHeld = true
		return
	end

	if wasHeld then
		wasHeld = false
		RunSession.resumeAttacks(now)
		MeleeSystem.resume()
	end

	EnemyManager.step(deltaTime, now)
	--[[ Straight after the enemies decide, so a volley never waits a frame
	     between its telegraph ending and the projectiles existing. ]]
	EnemyFiring.step(now)
	FiringSystem.step(deltaTime, now)
	MeleeSystem.step(now)
	--[[ The pets' attacks (`Config/PetCombat`). ]]
	PetCombat.step(deltaTime, now)
	ProjectileSystem.step(deltaTime, now)
	--[[ After projectiles, so a burn lit this frame does not tick in it. ]]
	Burning.step(now)
	--[[ Meteors landing and cracked ground erupting (the Mythics). ]]
	AreaStrikes.step(now)
	--[[ After projectiles, because a hit's knockback moves its enemy and can
	     push it into another. Overlaps are resolved once everything that can
	     move a body this frame has done so. ]]
	EnemyManager.resolveOverlaps()
	--[[ Crystals and hearts are taken by walking over them, so after
	     everything that moves the player this frame. ]]
	RunSession.pickUpFloor()
	--[[ And credited as they arrive, which may level the player up. ]]
	RunSession.landXp(now)
	--[[ Mending. ]]
	RunSession.regenerate(deltaTime, now)

	--[[ Last, so a room is only ever declared clear after everything that
	     could still kill something has had its turn this frame. ]]
	RoomController.step(now)
end)

log.info("ready")
