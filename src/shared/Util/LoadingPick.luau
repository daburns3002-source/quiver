--!strict
--[[
	What the loading screen may show (`first/Loading`, owner, 2026-10-26:
	"an enemy or weapon that the player has run into already"): every Mossy
	Glade enemy (the tutorial meets them all), Thornwood's once the player has
	beaten an area's boss there or before it, and every weapon the player
	owns. Read from the saved profile (`Util/SaveSchema`); with none yet, a
	new player's. Pure, so `tests/LoadingPick.spec` pins it.
]]

local NewEnemies = require(script.Parent.Parent.Config.NewEnemies)
local Sandbox = require(script.Parent.Parent.Config.Sandbox)
local SaveSchema = require(script.Parent.SaveSchema)
local ShopAssets = require(script.Parent.Parent.Config.ShopAssets)

export type Entry = { name: string, picture: string }

local LoadingPick = {}

--[[ Areas whose enemies a player has met, given the bosses they have beaten:
     Mossy Glade always, and Thornwood after either area's boss. ]]
local function metAreas(profile: SaveSchema.Profile): { [string]: boolean }
	local beaten = profile.bossesBeaten
	return {
		MossyGlade = true,
		Thornwood = beaten.MossyGlade == true or beaten.Thornwood == true,
	}
end

local function weaponName(weapon: string): string
	for _, entry in Sandbox.weapons do
		if entry.weapon == weapon then
			return entry.label
		end
	end
	return string.upper((weapon:gsub("(%l)(%u)", "%1 %2")))
end

function LoadingPick.pool(profile: SaveSchema.Profile?): { Entry }
	local saved = profile or SaveSchema.default()
	local areas = metAreas(saved)
	local pool: { Entry } = {}
	for _, enemy in NewEnemies.enemies do
		if areas[enemy.area] and enemy.picture then
			table.insert(pool, { name = enemy.name, picture = enemy.picture })
		end
	end
	for weapon, owned in saved.weapons do
		local picture = ShopAssets.weapons[weapon]
		if owned and picture then
			table.insert(pool, { name = weaponName(weapon), picture = picture })
		end
	end
	table.sort(pool, function(a, b)
		return a.name < b.name
	end)
	return pool
end

return LoadingPick
