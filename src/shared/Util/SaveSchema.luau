--!strict
--[[
	A player's saved data (`Data/PlayerData`), and how any older copy of it
	becomes the current shape. Pure, so `tests/SaveSchema.spec` pins every
	migration (CLAUDE.md non-negotiable 7: never a schema change without one).

	Version 1 (2026-10-25, the first saved data): the wallet (coins, gems,
	boss items), the weapons owned, the one equipped, and which bosses have
	been beaten (for first-time gems).
]]

local SaveSchema = {}

SaveSchema.VERSION = 1

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
}

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
	return profile
end

return SaveSchema
