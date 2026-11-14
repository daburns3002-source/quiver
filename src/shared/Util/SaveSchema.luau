--!strict
--[[
	A player's saved data (`Data/PlayerData`), and how any older copy of it
	becomes the current shape. Pure, so `tests/SaveSchema.spec` pins every
	migration (CLAUDE.md non-negotiable 7: never a schema change without one).

	Version 1 (2026-10-25, the first saved data): the wallet (coins, gems,
	boss items), the weapons owned, the one equipped, and which bosses have
	been beaten (for first-time gems).

	Version 2 (2026-10-26, Mossy Glade's ten levels): `levelsBeaten`, the
	levels won, keyed by each stage's `level` ("1-3"), which open the next
	level (`Util/LevelUnlocks`) and end the tutorial once 1-1 is beaten. A
	version 1 profile starts with none, except that one which had beaten
	King Bloblin (the end of the old twenty-room Mossy Glade run) counts
	1-1 as beaten, so its player is not sent back through the tutorial.

	Version 3 (2026-10-26, eggs and the gear screen): `pets`, how many of
	each pet the player has hatched (a second is kept for fusing later), and
	`equippedPets`, the pets taken into runs, slot by slot (`Config/Eggs`
	slots, at most two, each owned). An older profile has none.

	Version 4 (2026-10-27, the class select screen): `look`, the model the
	player picked with their class ("male" or "female"); nil until they have
	chosen, which is what shows them the screen. An older profile has none,
	so it is shown the screen once.

	Version 5 (2026-10-28, the guaranteed Mythic): `pity`, the crate and
	egg rolls made since the last Mythic of each (`Util/Pity`). An older
	profile starts both at 0.

	Version 6 (2026-10-27, Endless mode — `docs/ENDLESS.md`): `endlessBest`,
	the deepest floor ever reached (0 until the first run, and what the
	`endlessBest` board scores); `endlessMilestones`, the one-time milestone
	rewards already claimed, keyed by their floor as a string ("10", "50");
	and `soulstones`, the mode's own currency (owner, 2026-10-27), **kept
	apart from `coins` and `gems` on purpose** so depth can never inflate
	the story economy (`Config/Economy`). An older profile has a best of 0,
	no milestones and no Soulstones, which is also exactly what a new one
	has — nothing of an older save is interpreted as Endless progress,
	because there was none.

	Version 7 (the Dex Hall): `enemiesSeen`, the enemies ever met. An older
	profile has met none.

	Version 8 (2026-11-11, SKIP TUTORIAL): `tutorialDone`, set once the
	tutorial has been won. The tutorial still plays on every join until 1-1
	is beaten; a player who has won it before may skip it. An older profile
	has it only if it has beaten 1-1 (who must have been through it).

	Version 9 (2026-11-11, the settings screen): `settings`, the player's
	own music and sound volume and whether the device shakes
	(`Config/Settings`). An older profile has the defaults: nobody had
	chosen anything. Read through `Util/SettingsRules.read`, so a stored
	value that is not a volume step or a yes/no is its default.

	Version 10 (2026-11-11, merge tiers — owner, 2026-10-28): `tiers`, the
	copies of each weapon and pet held at each merge tier C, B, A and S
	(`Util/MergeRules`). Every crate or egg duplicate is one more C copy,
	and three of a tier merge into one of the next. Before this a weapon
	was only owned or not, so a duplicate saved nothing; an older profile
	holds every owned weapon at one C and every pet's count at C, and a
	pet's `pets` count is from now on the total of its copies.

	Version 11 (2026-11-11, reasons to come back — `Config/Rewards`):
	`rewards`, the login calendar's last day and count, today's quest
	progress and claims, the starter list's claims, the crates ever opened
	(the starter list's "open a crate") and the Dex entries already paid
	for. An older profile starts with nothing claimed, so its next login
	takes day 1 and the starter list pays what it has already done. Its
	crates count from its pity counter (a lower bound, nothing invented),
	and everything it already owns or has met counts as a Dex entry paid,
	so the update is no windfall.

	Version 12 (2026-11-13, the story through the areas -- `Config/StoryBeats`):
	`storySeen`, the areas whose story beat the player has watched, by
	`Config/Economy` area key. An older profile has watched none, so a boss
	it has beaten before plays its beat the next time it is beaten.

	Version 13 (2026-11-13, first-time tips -- `Config/Tips`): `tipsSeen`,
	the tips ever shown, by tip key (`Util/TipRules`). An older profile has
	seen none, so it sees each tip once, the next time it meets that thing.

	Version 14 (2026-11-13, the trails -- `Config/Trails`): `trails`, the
	trails held, by key; `equippedTrail`, the one worn, nil for none; and
	`endlessClassBest`, the deepest Endless floor reached as each class
	(Starfall's). An older profile holds none and wears none; the trails
	its beaten bosses earned are given on its next join
	(`Wallet.settleTrails`). Nobody's class was written beside a floor
	before, so every class counts from 0: nothing is invented.

	Version 15 (2026-11-13, the Robux store -- `Config/RobuxStore`):
	`purchases`, the receipt ids already granted (newest last, so a receipt
	Roblox retries is never granted twice), whether the starter pack has
	been bought and offered, revives bought and not yet used, and the last
	day VIP's gems were paid (`Util/StoreRules`). And a third pet slot, the
	Extra Pet Slot pass's: `equippedPets[3]` is read from version 15 on. An
	older profile has bought nothing, been offered nothing and holds two
	slots, which is all an older game had.
]]

local MergeRules = require(script.Parent.MergeRules)
local SettingsRules = require(script.Parent.SettingsRules)
local StoreRules = require(script.Parent.StoreRules)

local SaveSchema = {}

SaveSchema.VERSION = 15

--[[ The classes' own weapons, owned from the start. ]]
local STARTERS = { "TwigBow", "BranchStaff", "TimberBlade" }

export type Profile = {
	version: number,
	coins: number,
	gems: number,
	items: { [string]: number },
	weapons: { [string]: boolean },
	--[[ The weapon to hold in runs, nil for the class's own. ]]
	equipped: string?,
	bossesBeaten: { [string]: boolean },
	--[[ Levels won, by `StageConfig.level` (version 2). ]]
	levelsBeaten: { [string]: boolean },
	--[[ Pets hatched, by `Config/Pets` key, and how many of each. ]]
	pets: { [string]: number },
	--[[ The pets in runs, by slot (1 to 3, the third the Extra Pet Slot
	     pass's); a slot may be empty. ]]
	equippedPets: { [number]: string },
	--[[ The model picked on the class select screen, nil until chosen. ]]
	look: string?,
	--[[ Rolls since the last Mythic, crates and eggs apart (version 5). ]]
	pity: { crates: number, eggs: number },
	--[[ The deepest Endless floor ever reached, 0 until the first run
	     (version 6). Server-decided (`Run/RoomController`), never reported
	     by a client: it is what the board and the milestones pay on. ]]
	endlessBest: number,
	--[[ Endless milestones claimed, keyed by their floor ("10", "50"). ]]
	endlessMilestones: { [string]: boolean },
	--[[ Soulstones, the Endless currency (owner, 2026-10-27), spent only in
	     the Endless shop. Never folded into `coins` or `gems`. ]]
	soulstones: number,
	--[[ Enemies this player has ever met, by `Config/NewEnemies` key
	     (version 7), for the Dex Hall's enemy dex. Weapons and pets are
	     already kept above, so the dex reads those; an enemy is met rather
	     than owned and had nowhere to be written down before.

	     A run's own `seenEnemies` is per visit -- it decides whether to
	     show the NEW ENEMY! card -- and this is the lasting copy: the card
	     shows once ever, and the dex remembers. ]]
	enemiesSeen: { [string]: boolean },
	--[[ The tutorial has been won once (version 8): later joins may skip
	     it (`UI/TutorialPrompts`' SKIP TUTORIAL). ]]
	tutorialDone: boolean,
	--[[ The player's own settings (version 9): volumes and vibration. ]]
	settings: SettingsRules.Settings,
	--[[ Copies at each merge tier, by weapon and by pet (version 10); a
	     pet's `pets` count is their total, an owned weapon has at least one. ]]
	tiers: { weapons: { [string]: MergeRules.Counts }, pets: { [string]: MergeRules.Counts } },
	--[[ The login calendar, quests, starter list and Dex payouts
	     (version 11, `Util/RewardRules`). Days are whole UTC days since 1970. ]]
	rewards: RewardState,
	--[[ The areas whose story beat has been watched (version 12). ]]
	storySeen: { [string]: boolean },
	--[[ The first-time tips ever shown, by `Config/Tips` key (version 13). ]]
	tipsSeen: { [string]: boolean },
	--[[ The trails held and the one worn (version 14, `Config/Trails`). ]]
	trails: { [string]: boolean },
	equippedTrail: string?,
	--[[ The deepest Endless floor reached as each class (version 14). ]]
	endlessClassBest: { [string]: number },
	--[[ What Robux bought and what is still owed of it (version 15). ]]
	purchases: StoreRules.Purchases,
}

export type RewardState = {
	--[[ The last day the calendar paid, 0 never; and how many times. ]]
	loginDay: number,
	loginCount: number,
	--[[ The day the quest progress below belongs to. ]]
	questDay: number,
	questProgress: { [string]: number },
	questClaimed: { [string]: boolean },
	starterClaimed: { [string]: boolean },
	cratesOpened: number,
	--[[ Dex entries paid for, "Enemies:MossSlime", "Pets:EmberWilf". ]]
	dexPaid: { [string]: boolean },
}

--[[ The looks the class select screen offers. ]]
SaveSchema.LOOKS = { "male", "female" }

--[[ Pet slots a save can hold (`Config/Eggs.slots`): two for everyone, the
     third open with the Extra Pet Slot pass (`Util/StoreRules.petSlots`).
     A pet in the third without the pass is kept and simply not taken into
     a run. ]]
SaveSchema.PET_SLOTS = 3
--[[ The slots a save before version 15 could hold. ]]
local OLD_PET_SLOTS = 2

--[[ What the Endless currency is called on screen (owner, 2026-10-27:
     "Soulstones"), in caps as the HUD draws the others. Every screen that
     prints it reads this one string. ]]
SaveSchema.SOULSTONES = "SOULSTONES"

function SaveSchema.default(): Profile
	local weapons = {}
	local weaponTiers = {}
	for _, name in STARTERS do
		weapons[name] = true
		weaponTiers[name] = { C = 1 }
	end
	return {
		version = SaveSchema.VERSION,
		coins = 0,
		gems = 0,
		items = {},
		weapons = weapons,
		equipped = nil,
		bossesBeaten = {},
		levelsBeaten = {},
		pets = {},
		equippedPets = {},
		look = nil,
		pity = { crates = 0, eggs = 0 },
		endlessBest = 0,
		endlessMilestones = {},
		soulstones = 0,
		enemiesSeen = {},
		tutorialDone = false,
		rewards = {
			loginDay = 0,
			loginCount = 0,
			questDay = 0,
			questProgress = {},
			questClaimed = {},
			starterClaimed = {},
			cratesOpened = 0,
			dexPaid = {},
		},
		settings = SettingsRules.default(),
		tiers = { weapons = weaponTiers, pets = {} },
		storySeen = {},
		tipsSeen = {},
		trails = {},
		equippedTrail = nil,
		endlessClassBest = {},
		purchases = StoreRules.empty(),
	}
end

local function count(value: unknown): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.floor(value))
end

local function counts(value: unknown): { [string]: number }
	local out = {}
	if type(value) == "table" then
		for key, n in value :: { [any]: any } do
			if type(key) == "string" and count(n) > 0 then
				out[key] = count(n)
			end
		end
	end
	return out
end

local function flags(value: unknown): { [string]: boolean }
	local out = {}
	if type(value) == "table" then
		for key, on in value :: { [any]: any } do
			if type(key) == "string" and on == true then
				out[key] = true
			end
		end
	end
	return out
end

--[[ Whether this server can read it: a copy written by a newer version of
     the game is left alone rather than squeezed into an older shape. ]]
function SaveSchema.readable(raw: unknown): boolean
	if type(raw) ~= "table" then
		return true
	end
	local version = (raw :: any).version
	return type(version) ~= "number" or version <= SaveSchema.VERSION
end

--[[ Any stored copy (nothing for a new player) as a current profile.
     Missing or broken fields take their defaults; nothing is lost that
     reads as valid. ]]
function SaveSchema.migrate(raw: unknown): Profile
	local profile = SaveSchema.default()
	if type(raw) ~= "table" then
		return profile
	end
	local data = raw :: any
	profile.coins = count(data.coins)
	profile.gems = count(data.gems)
	profile.items = counts(data.items)
	for name in flags(data.weapons) do
		profile.weapons[name] = true
	end
	if type(data.equipped) == "string" and profile.weapons[data.equipped] then
		profile.equipped = data.equipped
	end
	profile.bossesBeaten = flags(data.bossesBeaten)
	profile.levelsBeaten = flags(data.levelsBeaten)
	--[[ 1 → 2: no levels existed; the old Mossy Glade run, won, stands in
	     for the first of them. A stored copy with no version is a 1. ]]
	local version = if type(data.version) == "number" then data.version else 1
	if version < 2 and profile.bossesBeaten.MossyGlade then
		profile.levelsBeaten["1-1"] = true
	end
	profile.pets = counts(data.pets)
	if type(data.equippedPets) == "table" then
		local slots = if version >= 15 then SaveSchema.PET_SLOTS else OLD_PET_SLOTS
		for slot = 1, slots do
			local pet = data.equippedPets[slot]
			if type(pet) == "string" and profile.pets[pet] then
				profile.equippedPets[slot] = pet
			end
		end
	end
	if type(data.look) == "string" and table.find(SaveSchema.LOOKS, data.look) then
		profile.look = data.look
	end
	if type(data.pity) == "table" then
		for _, kind in { "crates", "eggs" } do
			local rolls = data.pity[kind]
			if type(rolls) == "number" and rolls >= 0 then
				(profile.pity :: any)[kind] = math.floor(rolls)
			end
		end
	end
	--[[ 5 → 6: Endless did not exist, so an older profile's best is 0 and
	     no milestone is claimed — there is nothing to read across, and
	     nothing is invented either. A stored best is kept as it is, never
	     clamped to today's `Balance.Endless.maxFloor`: lowering the cap must
	     not erase a record somebody set under the old one. ]]
	profile.endlessBest = count(data.endlessBest)
	profile.endlessMilestones = flags(data.endlessMilestones)
	profile.soulstones = count(data.soulstones)
	--[[ 6 → 7: nobody's met enemies were written down before, so an older
	     profile's dex starts empty rather than guessing from the bosses it
	     has beaten. A player meets them again as they play, and the dex
	     fills in; inventing entries would show creatures somebody has
	     never seen. ]]
	profile.enemiesSeen = flags(data.enemiesSeen)
	--[[ 7 → 8: nobody's tutorial win was written down. Whoever has beaten
	     1-1 came through it; anyone else plays it once more before they
	     may skip. ]]
	profile.tutorialDone = data.tutorialDone == true or profile.levelsBeaten["1-1"] == true
	--[[ 8 → 9: no settings were kept, so an older profile has the defaults. ]]
	profile.settings = SettingsRules.read(data.settings)
	--[[ 9 -> 10: what was owned is held at C -- one copy of each weapon
	     (duplicates were never saved), each pet's count as that many C.
	     A stored pet's tiers are its count from then on. ]]
	local stored = if type(data.tiers) == "table" then data.tiers else {}
	local storedWeapons = if type(stored.weapons) == "table" then stored.weapons else {}
	local storedPets = if type(stored.pets) == "table" then stored.pets else {}
	for name in profile.weapons do
		local held = MergeRules.clean(storedWeapons[name])
		profile.tiers.weapons[name] = if MergeRules.total(held) > 0 then held else { C = 1 }
	end
	for pet, n in profile.pets do
		local held = MergeRules.clean(storedPets[pet])
		if MergeRules.total(held) == 0 then
			held = { C = n }
		end
		profile.tiers.pets[pet] = held
		profile.pets[pet] = MergeRules.total(held)
	end
	--[[ 10 → 11: the rewards. A stored copy is read field by field; an older
	     one has none, so nothing is claimed, its crates are its pity count,
	     and what it already has counts as paid for in the Dex. ]]
	local storedRewards = if type(data.rewards) == "table" then data.rewards else nil
	local rewards = profile.rewards
	if storedRewards then
		rewards.loginDay = count(storedRewards.loginDay)
		rewards.loginCount = count(storedRewards.loginCount)
		rewards.questDay = count(storedRewards.questDay)
		rewards.questProgress = counts(storedRewards.questProgress)
		rewards.questClaimed = flags(storedRewards.questClaimed)
		rewards.starterClaimed = flags(storedRewards.starterClaimed)
		rewards.cratesOpened = count(storedRewards.cratesOpened)
		rewards.dexPaid = flags(storedRewards.dexPaid)
	else
		rewards.cratesOpened = profile.pity.crates
		for kind in profile.enemiesSeen do
			rewards.dexPaid["Enemies:" .. kind] = true
		end
		for weapon in profile.weapons do
			rewards.dexPaid["Weapons:" .. weapon] = true
		end
		for pet in profile.pets do
			rewards.dexPaid["Pets:" .. pet] = true
		end
	end
	--[[ 11 -> 12: no beat was ever shown, so an older profile has watched
	     none; a stored copy keeps its yes flags. ]]
	profile.storySeen = flags(data.storySeen)
	--[[ 12 -> 13: no tip was ever shown, so an older profile has seen none;
	     a stored copy keeps its yes flags. ]]
	profile.tipsSeen = flags(data.tipsSeen)
	--[[ 13 -> 14: no trail existed, so none is held or worn and no class
	     has a floor; a stored copy keeps its own, and wears only one it
	     holds. ]]
	profile.trails = flags(data.trails)
	if type(data.equippedTrail) == "string" and profile.trails[data.equippedTrail] then
		profile.equippedTrail = data.equippedTrail
	end
	profile.endlessClassBest = counts(data.endlessClassBest)
	--[[ 14 -> 15: nothing was ever bought, so an older profile has no
	     receipts, no starter pack, no revive held; a stored copy is read
	     field by field (`StoreRules.read`). ]]
	profile.purchases = StoreRules.read(data.purchases)
	return profile
end

return SaveSchema
