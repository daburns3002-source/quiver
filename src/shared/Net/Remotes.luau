--!strict
--[[
	Remote accessor.

	The server creates the remotes; the client waits for them. Both sides name
	them through this module so a typo is a missing key rather than a silent
	`WaitForChild` that hangs forever.

	Nothing here grants authority. The ones marked client → server are
	listened to in `Net/Inbound` only, rate limited, with the `Debug*` ones
	connected in Studio alone; what they carry is a request the server
	checks, never a result it takes.
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

--[[ Leave the run and go back to the lobby, from the HUD mid-room or from
     an end screen (owner, 2026-10-29: "there needs to be a back to lobby
     button ... while you are mid room and also on the defeat and victory
     screens"). The server decides: `RoomController.requestLobby` refuses
     unless the asker is in a run that is not already the lobby. Abandoning
     a run keeps nothing -- the stage is not counted beaten. ]]
Remotes.RunLobby = "RunLobby"

--[[ Into an area's first level (owner, 2026-11-08): the server parks the first
     room and says `AreaLoading`; each client holds a loading screen until that
     room and its NEW ENEMY! cards are fetched, and says `AreaLoaded`. ]]
Remotes.AreaLoading = "AreaLoading"
Remotes.AreaLoaded = "AreaLoaded"

--[[
	Client → server. MENU's LEAVE THE RUN? panel opened (true) or shut (false).
	The world holds while it is open, for at most `CombatTuning.menuHold`
	(`RunSession.setInMenu`).
]]
Remotes.RunMenu = "RunMenu"

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
--[[ Server → one client: coins were paid (how many, and the world point a
     kill dropped them at, else nil). The run's coin counter and
     `Fx/CoinDrops` draw it; the wallet itself is the `Coins` attribute. ]]
Remotes.CoinsGained = "CoinsGained"
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
--[[ Client -> server: the item card's MERGE ("weapon" or "pet", its key,
     the tier to merge from); the server checks there are three
     (`Data/Shop`, `Util/MergeRules`) and answers with `ProfileChanged`. ]]
Remotes.MergeItem = "MergeItem"
--[[ Client -> server: the gear sheet's TRAILS tab (`Server/Data/Trails`):
     buy a trail (its key), or wear one held (its key, or nil for none).
     The price and what is held are the server's. ]]
Remotes.TrailBuy = "TrailBuy"
Remotes.TrailEquip = "TrailEquip"
--[[ Client → server, Studio only: coins, gems and boss items into the
     wallet (`Data/Shop`), to test the shop without playing for them. ]]
Remotes.DebugWallet = "DebugWallet"
--[[ Client → server: claim a reward (`Data/Rewards`): "login", or "quest" /
     "starter" with its key. Carries no progress and no day; the server
     judges the claim from the saved profile and its own clock. ]]
Remotes.RewardClaim = "RewardClaim"
--[[ Server → client: a reward just landed by itself (a new Dex entry):
     its words, gems and coins, for the toast (`UI/RewardsScreen`). ]]
Remotes.RewardToast = "RewardToast"
--[[ Client → server, Studio only: move this player's reward day on by a
     number of days (1 if none), to see a day roll (`Data/Rewards`). ]]
Remotes.DebugDay = "DebugDay"

--[[
	Client → server. The intro's BEGIN ADVENTURE button: this player has
	left the title screen, so the run may move. Carries nothing; the server
	only clears its own hold for this player (`RunSession.leaveTitle`).
]]
Remotes.IntroBegin = "IntroBegin"
--[[ Client → server: the title ("Title") or the story ("Story") is on
     this player's screen, for the onboarding funnel (`Data/Analytics`).
     Only a step of `Analytics.CLIENT_STEPS`, only from a player still on
     the title; it changes nothing but what is logged. ]]
Remotes.FunnelStep = "FunnelStep"

--[[
	Client → server. A story beat (`Config/StoryBeats`) has been watched or
	skipped: the area key whose beat it was. The server writes it down
	(`Wallet.sawStory`) only for an area with a beat whose boss this player
	has beaten, so it can never mark one owed later.
]]
Remotes.StorySeen = "StorySeen"

--[[
	Client → server. A first-time tip (`Config/Tips`) has been on screen:
	its key. The server keeps it (`Wallet.sawTip`) only for a tip, once, so
	it never shows again (`Util/TipRules`).
]]
Remotes.TipSeen = "TipSeen"

--[[
	Client → server. OK on a first-time tip: a run it held goes on
	(`RunSession.tipClosed`). Carries nothing.
]]
Remotes.TipClosed = "TipClosed"

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
	Client → server. The lobby's PLAY button (`UI/LobbyHud`), no payload. The
	server picks the player's frontier portal (`Util/PlayPortal`) and walks
	them to its mouth, where its screen opens as any portal's does; START is
	still checked by `Run/Lobby.startFor` there.
]]
Remotes.LobbyPlay = "LobbyPlay"

--[[
	Server → one client. A party portal's word on the run it is starting
	(`Run/Party`): "TRAVELLING..." while the teleport is under way, or why it
	failed. Shown on the portal screen (`UI/PortalScreen`).
]]
Remotes.PartyNotice = "PartyNotice"

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
	Server → one client. An Endless milestone was claimed and its eggs and
	crates opened (`Server/Data/EndlessPrizes`): the floor, what the
	milestone is called, and what came out, `{ pet, new }` and
	`{ weapon, new }` lists. Already granted; this is only to show it.
	Floor 0 is a Soulstone shop purchase, shown the same way; floor -1 the
	eggs a Robux product hatched (the starter pack, `Server/Data/Purchases`).
]]
Remotes.EndlessPrize = "EndlessPrize"

--[[
	Client → server. "I pressed BUY on this": a `Config/RobuxStore` key and
	where it was offered ("Store", "Defeat", "Starter", "GearSlot"). A
	request: the server checks it may be sold to this player and opens
	Roblox's own prompt (`Server/Data/Purchases`), or spends a revive held.
	Nothing is granted until Roblox's receipt arrives.
]]
Remotes.StoreBuy = "StoreBuy"
--[[ Server → one client: a Robux grant landed (a product's key and its
     gems, or "VIPDaily" and the day's gems), for the STORE's thank-you. ]]
Remotes.StoreGranted = "StoreGranted"
--[[ Client → server, Studio only: a made-up receipt for a product key and a
     purchase id (`Server/Data/Purchases`), and a pass on or off
     (`Server/Data/Passes`), to test the store without Robux. ]]
Remotes.DebugReceipt = "DebugReceipt"
Remotes.DebugPass = "DebugPass"

--[[
	Client → server. "Buy `count` of this from the Soulstone shop": the
	offer's kind ("Egg" or "Crate") and key (`Util/SoulstoneShopRules`).
	A request: the server checks the offer, the count and the Soulstones
	(`Server/Data/SoulstoneShop`), and answers with `EndlessPrize`, floor 0.
]]
Remotes.SoulstoneBuy = "SoulstoneBuy"

--[[
	Client → server. "Keep this setting": its name ("music", "sound",
	"haptics") and its value (`Config/Settings`). A request: the server
	cleans both (`Util/SettingsRules.clean`) and drops anything else.
]]
Remotes.SettingSet = "SettingSet"

--[[ Client → server, Studio only: Soulstones into the wallet
     (`Server/Data/SoulstoneShop`), to test the Soulstone shop without
     playing Endless for them. ]]
Remotes.DebugSoulstones = "DebugSoulstones"

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

--[[ Server → all clients. A Soul Chain link, drawn as a fireball: where the
     enemy hit stood, then the linked enemies in the order it leaps to them,
     where each stood, and the seconds from now it lands on each. ]]
Remotes.SoulLink = "SoulLink"

--[[ Server → all clients. A Warden's Parry knocked the enemy shots within
     `radius` of `centre` out of the air: stop drawing them. ]]
Remotes.ShotsParried = "ShotsParried"

--[[ Server → all clients. A class upgrade's moment to draw
     (`Combat/ClassUpgrades`, `Fx/Upgrades/*BuildFx`): its kind
     ("ArrowRain", "BlackHole", "BlackHoleImplode", "TitanSlam"), the player
     it is theirs, then that kind's own values. ]]
Remotes.UpgradeFx = "UpgradeFx"

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

--[[ Server → all clients. Grandmother Gulp's Big Gulp drags whoever stands
     in its cone toward her mouth: the mouth, the way the cone faces, its
     reach and half angle (radians), the pull in studs a second, and for
     how many seconds; 0 seconds lets go. Each client tests its own
     character against the cone and adds the pull to its walking. ]]
Remotes.PlayerDragged = "PlayerDragged"

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
--[[ Client → server, Studio only: a killing blow past every save, so a
     co-op probe can test downed and revive (`Shared/Util/Coop`). ]]
Remotes.DebugDown = "DebugDown"
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
