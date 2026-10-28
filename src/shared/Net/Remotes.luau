--!strict
--[[
	Remote accessor.

	The server creates the remotes; the client waits for them. Both sides name
	them through this module so a typo is a missing key rather than a silent
	`WaitForChild` that hangs forever.

	Nothing here grants authority. Every remote listed below is server→client
	except RequestRespawn, and that one carries no payload the server trusts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
--[[ Seconds a client waits for a remote. The server makes every one at
     once (`createAll`), so this is only a backstop for a slow start; at 10
     a live server still loading the lobby's meshes outlasted it, and the
     client died before the title (a friend's playtest, 2026-10-26). ]]
local WAIT_TIMEOUT = 60

local Remotes = {}

--[[
	Server → clients. One packet per volley, carrying the whole shot description
	so clients can simulate the flight locally. See Types.ShotEvent.
]]
Remotes.ShotFired = "ShotFired"

--[[
	Server → clients. An enemy took damage: enough for a flash and a damage
	number. The client is told what happened, never asked to decide it.
]]
Remotes.EnemyHit = "EnemyHit"

--[[
	Server → clients. An enemy died, for the death effect. Carries the position
	and nothing else: the enemy instance is destroyed in the same step, so a
	reference to it would not reliably survive the trip. Anything a future
	effect needs — archetype, rarity, loot — travels as data, never as the
	instance it describes.
]]
Remotes.EnemyDied = "EnemyDied"

--[[
	Server → clients. An enemy began winding up a shot: origin, the direction
	it is committed to (or currently pointed), how long the wind-up lasts, and
	which tell to draw.

	Sent as data rather than as a part the server builds, for the same reason
	projectiles are: the client decides how to draw a warning, the server only
	decides that there is one. A `Line` tell is only truthful because the
	matching shot locks its aim — see Balance.EnemyShot.locksAim.
]]
Remotes.EnemyTelegraph = "EnemyTelegraph"

--[[
	Server → clients. The run moved on: which room, how many there are, and
	what state it is in ("Fighting", "Cleared", "Dead", "Complete").

	The client renders this and decides nothing. Room progress is exactly the
	kind of thing a client must never report — it is the gate the whole meta
	loop will hang off in Phase 5.
]]
Remotes.RunStateChanged = "RunStateChanged"

--[[ Server → one client. The local player took damage, for shake and vignette. ]]
Remotes.PlayerDamaged = "PlayerDamaged"

--[[ Server → one client. Health changed for any reason, including spawn:
     (health, maxHealth, shown?), `shown` a heal to put up by the bar as a
     "+N" (a heart's, so far). ]]
Remotes.HealthChanged = "HealthChanged"

--[[ Server → one client. Run XP and level, for the bar under the health. ]]
Remotes.XpChanged = "XpChanged"

--[[
	Server → one client. Here are the cards you may choose from.

	Ability *ids*, because the client has the same Config and can render names
	and descriptions itself. The server keeps the authoritative copy of what it
	offered, so the reply below can be checked rather than believed.
]]
Remotes.AbilityOffer = "AbilityOffer"

--[[
	Client → server. "I pick the nth card."

	An index into the offer the server itself just sent, and nothing else. A
	client that lies can only pick a different one of the three cards it was
	already going to be allowed to pick — it cannot name an ability, a stack
	count or a stat. See CLAUDE.md, non-negotiable 2.
]]
Remotes.AbilityChosen = "AbilityChosen"

--[[
	Server → one client. The stats the client needs in order to predict.

	Deliberately tiny, and deliberately not "the player's stats": the client
	pins WalkSpeed every frame and runs the dash timer locally, so those two
	numbers have to live there or prediction fights the server. Nothing that
	decides an outcome is ever sent here.
]]
Remotes.PlayerStats = "PlayerStats"

--[[
	Server → one client. The run is over: won or lost, and the numbers the
	end screen shows (stage, kills, time, health, progress).

	Sent on death and on finishing the stage. Plain numbers, so the client
	can draw them however it likes and the server never has to know what an
	end screen looks like.
]]
Remotes.RunSummary = "RunSummary"

--[[
	Client → server. The end screen's button: start the next run. Carries
	nothing; whether a run has ended and may restart is the server's to
	decide, and a request at any other time is ignored.
]]
Remotes.RunRestart = "RunRestart"

--[[
	Server → one client. That player's saved profile changed (coins, gems,
	boss items, weapons owned, the one equipped): the whole profile, for
	the shop and the wallet. Sent only from `Data/Wallet`.
]]
Remotes.ProfileChanged = "ProfileChanged"

--[[ Client → server: the shop (`Server/Data/Shop`). Each carries only what
     is asked for (a crate's index, a weapon's name); the price, the roll and
     the result are the server's. ]]
Remotes.ShopOpenCrate = "ShopOpenCrate"
Remotes.ShopBuy = "ShopBuy"
Remotes.ShopEquip = "ShopEquip"
--[[ Server → one client: what a crate gave (index, weapon, whether it is
     new, coins paid back for one already owned). ]]
Remotes.ShopCrateOpened = "ShopCrateOpened"
--[[ Client → server: the egg hatchery and the gear screen
     (`Server/Data/Hatchery`): an egg's key and how many to hatch; a pet
     slot (1 or 2) and the pet for it, or nil to empty it. ]]
Remotes.HatchEgg = "HatchEgg"
Remotes.EquipPet = "EquipPet"
--[[ Server → one client: what a hatch gave (the egg's key, then each
     pet's key and whether it was new, in order). ]]
Remotes.EggHatched = "EggHatched"
--[[ Client → server: send me my profile again (`Remotes.ProfileChanged`).
     The one sent on join can reach only whichever listener connected first
     (the loading screen), so the lobby's screens ask for it when they start. ]]
Remotes.ProfileRequest = "ProfileRequest"
--[[ Client → server: the class select screen's CHOOSE (a class's name and a
     look, "male" or "female"); the server checks both (`Data/Shop`). ]]
Remotes.ChooseClass = "ChooseClass"
--[[ Client → server: the gear screen's class switch (a class's name); the
     server puts that class's own weapon in hand and empties the pet slots
     (`Data/Shop`). ]]
Remotes.SwitchClass = "SwitchClass"
--[[ Client → server, Studio only: coins, gems and boss items into the
     wallet (`Data/Shop`), to test the shop without playing for them. ]]
Remotes.DebugWallet = "DebugWallet"

--[[
	Client → server. The intro's BEGIN ADVENTURE button: this player has
	left the title screen, so the run may move. Carries nothing; the server
	only clears its own hold for this player (`RunSession.leaveTitle`).
]]
Remotes.IntroBegin = "IntroBegin"

--[[
	Server → one client. The player has stepped into a lit portal's mouth in
	the lobby: open its screen (`UI/PortalScreen`) with that portal's index
	in `Config/Lobby.portals`, or 0 to shut it as they step out.
]]
Remotes.PortalOpen = "PortalOpen"

--[[
	Client → server. START on a portal's screen: the portal's index and the
	level picked. The server checks both and that the player stands at that
	portal (`Run/Lobby.startFor`) before starting the run.
]]
Remotes.PortalStart = "PortalStart"

--[[
	Server → one client. A kind of enemy this player has not met before has
	landed (its `EnemyConfig.displayName`): show its NEW ENEMY! screen
	(`Config/NewEnemies`). The server holds the run until it is closed.
]]
--[[
	Server → one client. An Endless checkpoint is open: the floor just
	cleared, the Soulstones the run has banked, and whether a bank-and-leave
	is offered (`docs/ENDLESS.md`). What the three picks are is config the
	client already has (`Balance.Endless.checkpoint.picks`).
]]
Remotes.EndlessCheckpoint = "EndlessCheckpoint"

--[[
	Client → server. "I pick the nth option at the checkpoint", or 0 to bank
	and leave.

	An index into `Balance.Endless.checkpoint.picks` and nothing else, checked
	against a checkpoint the server itself opened (non-negotiable 2): a client
	that lies can only pick a different one of the three it was already going
	to be allowed to pick, and can never name a floor or a payout.
]]
Remotes.EndlessPick = "EndlessPick"

Remotes.NewEnemy = "NewEnemy"

--[[
	Client → server. GOT IT! on a NEW ENEMY! screen, with the kind it showed.
	The server only clears a screen it opened (`RunSession.metEnemy`).
]]
Remotes.NewEnemySeen = "NewEnemySeen"

--[[
	Server → all clients. Something exploded here, this wide.

	The radius travels with it rather than being looked up, because what the
	player needs to learn from the effect is exactly how far the blast
	reaches — and that is a number the loadout changes. An effect drawn at a
	fixed size would teach them the wrong one.
]]
Remotes.Explosion = "Explosion"

--[[
	Server → all clients. Something dropped on the floor: an id, its kind
	("Crystal" or "Heart"), where it rests, and where it popped out from.
]]
Remotes.PickupDropped = "PickupDropped"

--[[ Server → all clients. These pickups were taken by this player; fly them
     to the player and drop them. ]]
Remotes.PickupsTaken = "PickupsTaken"

--[[ Server → all clients. The floor is bare: a new arena was built. ]]
Remotes.PickupsCleared = "PickupsCleared"

--[[ Server → all clients. This player was revived here, and cannot be hurt
     for this many seconds; and by what ("SecondWind" or "Revive"). ]]
Remotes.PlayerRevived = "PlayerRevived"

--[[ Server → all clients. A Soul Chain link: from the enemy hit, to each of
     these. ]]
Remotes.SoulLink = "SoulLink"

--[[ Server → all clients. A Warden's Parry knocked the enemy shots within
     `radius` of `centre` out of the air: stop drawing them. ]]
Remotes.ShotsParried = "ShotsParried"

--[[ Server → one client. A hit on this player missed, and why: "Agility"
     (a dodge) or "Guard" (a swing's guard caught it). ]]
Remotes.PlayerDodged = "PlayerDodged"

--[[ Server → one client. A boss's hit pushes this player: a flat
     direction and a distance in studs. The client drives its own character
     there over `Balance.Shove.duration`, as it does a dash, so walls stop it. ]]
Remotes.PlayerShoved = "PlayerShoved"

--[[ Server → one client. A boss holds this player still for the given
     seconds (the Slime Lash's grab); 0 lets go. Time-limited, so a boss
     that dies mid-grab cannot leave anyone stuck. ]]
Remotes.PlayerGrabbed = "PlayerGrabbed"

--[[ Client → server. This player's dash began (the dash itself is the
     client's movement). Only Earthbreaker cares; the server ignores it for
     anyone without the card and any sooner than the dash's cooldown. ]]
Remotes.DashStarted = "DashStarted"

--[[ Client → server. Redeal the open hand. The server checks there is a
     hand and a reroll left; the client says nothing else. ]]
Remotes.AbilityReroll = "AbilityReroll"

--[[ Client → server, testing only. Asks that the next hand include a
     Mythic (or a Legendary, if that is the one string sent), so its look
     can be seen. The server ignores it outside Studio. ]]
Remotes.DebugForceMythic = "DebugForceMythic"
--[[ Client → server, Studio only: switch to the next class (`Config/Classes`).
     Stands in for a lobby's class choice until one exists. ]]
Remotes.DebugNextClass = "DebugNextClass"
--[[ Client → server, Studio only: grant one level of the named card, so a
     probe can test its effect without drafting it by luck. ]]
Remotes.DebugGrant = "DebugGrant"
--[[ Client → server, Studio only: jump to a room of a Rooms stage. ]]
Remotes.DebugRoom = "DebugRoom"
--[[ Client → server, Studio only: spawn one enemy of the named archetype
     (a `Balance.Enemies` key), to test it without reaching its room. ]]
Remotes.DebugSpawnEnemy = "DebugSpawnEnemy"
--[[ Client → server, Studio only: build the pet preview's models
     (`Config/PetModels`) into ReplicatedStorage, so `Fx/PetPreview` can
     set the pets following the player. ]]
Remotes.DebugPetPreview = "DebugPetPreview"
--[[ Client → server, Studio only: into the playtest sandbox (true) or out
     of it (false), `Config/Sandbox`. ]]
Remotes.DebugSandbox = "DebugSandbox"
--[[ Client → server, Studio only: hold the named weapon (one of
     `Config/Sandbox.weapons`), as its class. ]]
Remotes.DebugWeapon = "DebugWeapon"
--[[ Client → server, Studio only: the pet at heel in a run (a
     `Config/PetCombat` key, or nil for none), until Phase 6's equipping. ]]
Remotes.DebugPet = "DebugPet"
--[[ Server → clients: a player's pet attacks (`Combat/PetCombat`), so
     that player's pet plays its Attack and pieces. ]]
Remotes.PetAttack = "PetAttack"

local function getFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing :: Folder
		end

		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
	assert(folder, `Remotes folder never replicated after {WAIT_TIMEOUT}s`)
	return folder :: Folder
end

--[[
	Returns the named RemoteEvent, creating it on the server and waiting for it
	on the client.
]]
function Remotes.event(name: string): RemoteEvent
	local folder = getFolder()

	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end

		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end

	local remote = folder:WaitForChild(name, WAIT_TIMEOUT)
	assert(remote, `Remote "{name}" never replicated after {WAIT_TIMEOUT}s`)
	return remote :: RemoteEvent
end

--[[ Server: makes every remote named above, at once. Called first thing
     at boot, before anything slow (the lobby loads dozens of meshes), so a
     client that joins early finds them all instead of waiting on remotes
     the server has not reached yet. ]]
function Remotes.createAll()
	assert(RunService:IsServer(), "Remotes.createAll is the server's")
	for key, value in Remotes :: { [string]: any } do
		if type(value) == "string" and key == value then
			Remotes.event(value)
		end
	end
end

return Remotes
