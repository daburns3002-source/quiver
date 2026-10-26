--!strict
--[[
	What the loading screen may show (`first/Loading`, owner, 2026-10-26:
	"an enemy or weapon that the player has run into already", then "add
	pictures and descriptions for the area weapon skins as well that the
	player is currently on"), each with a line about it:

	- every enemy of the areas the player has met, Mossy Glade's always (the
	  tutorial meets them all) and Thornwood's once a boss is beaten, but
	  never a benched one (`NewEnemies` `benched`);
	- every weapon of the areas up to the one the player is on
	  (`WeaponStats` `area`), owned or not, described by its rarity, damage
	  and effect.

	Read from the saved profile (`Util/SaveSchema`); with none yet, a new
	player's. Pure, so `tests/LoadingPick.spec` pins it.
]]

local NewEnemies = require(script.Parent.Parent.Config.NewEnemies)
local Sandbox = require(script.Parent.Parent.Config.Sandbox)
local SaveSchema = require(script.Parent.SaveSchema)
local ShopAssets = require(script.Parent.Parent.Config.ShopAssets)
local WeaponStats = require(script.Parent.Parent.Config.WeaponStats)

export type Entry = { name: string, picture: string, description: string }

local LoadingPick = {}

--[[ The areas in order, as `WeaponStats` numbers them. ]]
local AREAS = { "MossyGlade", "Thornwood" }

--[[ The area the player is on: past Mossy Glade once either area's boss is
     beaten. ]]
local function currentArea(profile: SaveSchema.Profile): number
	local beaten = profile.bossesBeaten
	if beaten.MossyGlade == true or beaten.Thornwood == true then
		return 2
	end
	return 1
end

local function weaponName(weapon: string): string
	for _, entry in Sandbox.weapons do
		if entry.weapon == weapon then
			return entry.label
		end
	end
	return string.upper((weapon:gsub("(%l)(%u)", "%1 %2")))
end

--[[ A weapon's line: its rarity, its damage over a Common's, and its
     effect if it has one. ]]
function LoadingPick.describeWeapon(weapon: string): string
	local stats = WeaponStats.weapons[weapon]
	if not stats then
		return ""
	end
	local rarity = string.upper(stats.rarity)
	local bonus = math.floor((WeaponStats.bonus[stats.rarity] or 0) * 100 + 0.5)
	local line = if bonus > 0 then `{rarity}. +{bonus}% damage.` else `{rarity}. A trusty starting weapon.`
	if stats.effect then
		line ..= " " .. stats.effect
	end
	return line
end

function LoadingPick.pool(profile: SaveSchema.Profile?): { Entry }
	local saved = profile or SaveSchema.default()
	local area = currentArea(saved)
	local met: { [string]: boolean } = {}
	for index = 1, area do
		met[AREAS[index]] = true
	end

	local pool: { Entry } = {}
	for _, enemy in NewEnemies.enemies do
		if met[enemy.area] and enemy.picture and not enemy.benched then
			table.insert(pool, { name = enemy.name, picture = enemy.picture, description = enemy.description })
		end
	end
	for weapon, stats in WeaponStats.weapons do
		local picture = ShopAssets.weapons[weapon]
		if picture and stats.area <= area then
			table.insert(pool, {
				name = weaponName(weapon),
				picture = picture,
				description = LoadingPick.describeWeapon(weapon),
			})
		end
	end
	table.sort(pool, function(a, b)
		return a.name < b.name
	end)
	return pool
end

return LoadingPick
