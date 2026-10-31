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
]]

local SaveSchema = {}

SaveSchema.VERSION = 6

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
	--[[ The pets in runs, by slot (1 and 2); a slot may be empty. ]]
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
}

--[[ The looks the class select screen offers. ]]
SaveSchema.LOOKS = { "male", "female" }

--[[ Pets a player can take into a run (`Config/Eggs.slots`). ]]
SaveSchema.PET_SLOTS = 2

--[[ What the Endless currency is called on screen (owner, 2026-10-27:
     "Soulstones"), in caps as the HUD draws the others. Every screen that
     prints it reads this one string. ]]
SaveSchema.SOULSTONES = "SOULSTONES"

function SaveSchema.default(): Profile
	local weapons = {}
	for _, name in STARTERS do
		weapons[name] = true
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
		for slot = 1, SaveSchema.PET_SLOTS do
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
	return profile
end

return SaveSchema
