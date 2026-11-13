--!strict
--[[
	What the trails cost, who has earned which, and what a locked one says
	(`Config/Trails`). Pure: the server grants and sells by it
	(`Server/Data/Wallet`, `Server/Data/Trails`), the gear sheet draws by it,
	and `tests/Trails.spec` pins it.
]]
local Economy = require(script.Parent.Parent.Config.Economy)
local Shop = require(script.Parent.Parent.Config.Shop)
local ShopRules = require(script.Parent.ShopRules)
local Trails = require(script.Parent.Parent.Config.Trails)

local TrailRules = {}

--[[ The Player attribute holding the trail worn (a `Config/Trails` key),
     set by the server (`Data/Wallet`) and drawn by every client. ]]
TrailRules.ATTRIBUTE = "Trail"

--[[ What the rules read of a profile (`SaveSchema.Profile` has them all). ]]
export type Held = {
	trails: { [string]: boolean },
	bossesBeaten: { [string]: boolean },
	endlessClassBest: { [string]: number },
}

function TrailRules.get(key: unknown): Trails.Trail?
	return if type(key) == "string" then Trails.trails[key] else nil
end

--[[ Mossy Glade 1 up to Bogheart Caverns 4; nil for Starfall. ]]
function TrailRules.areaNumber(area: string): number?
	return table.find(Trails.areas, area)
end

--[[ Where a trail is from, for its card: "FROM MOSSY GLADE", "FROM ENDLESS". ]]
function TrailRules.from(key: string): string
	local trail = Trails.trails[key]
	if not trail then
		return ""
	end
	for _, crate in Shop.crates do
		if crate.area == trail.area then
			return "FROM " .. crate.name
		end
	end
	return "FROM " .. string.upper(trail.area)
end

--[[ A bought trail's price in gems; nil for one that is earned. ]]
function TrailRules.price(key: string): number?
	local trail = Trails.trails[key]
	local n = trail and TrailRules.areaNumber(trail.area)
	local each = trail and Trails.gemPrices[trail.rarity]
	if not trail or trail.earn ~= "Gems" or not n or not each then
		return nil
	end
	return each * n
end

local function crateIndex(area: string): number?
	for index, crate in Shop.crates do
		if crate.area == area then
			return index
		end
	end
	return nil
end

--[[ Whether an area's trails are on sale: when its crates are, so a
     launch-locked area sells nothing early (`ShopRules.crateOpen`). ]]
function TrailRules.onSale(
	key: string,
	bossesBeaten: { [string]: boolean }?,
	locks: boolean?
): boolean
	local trail = Trails.trails[key]
	local index = trail and crateIndex(trail.area)
	return trail ~= nil
		and trail.earn == "Gems"
		and index ~= nil
		and ShopRules.crateOpen(index, bossesBeaten, locks)
end

--[[ How many of Starfall's classes have reached its floor. ]]
function TrailRules.endlessClasses(classBest: { [string]: number }): number
	local n = 0
	for _, class in Trails.endless.classes do
		if (classBest[class] or 0) >= Trails.endless.floor then
			n += 1
		end
	end
	return n
end

--[[ Whether a trail has been earned, owned or not: a boss trail once its
     boss is beaten, Starfall once every class has its floor. Bought ones
     never are. ]]
function TrailRules.earned(key: string, held: Held): boolean
	local trail = Trails.trails[key]
	if not trail then
		return false
	end
	if trail.earn == "Boss" then
		return held.bossesBeaten[trail.area] == true
	elseif trail.earn == "Endless" then
		return TrailRules.endlessClasses(held.endlessClassBest) >= #Trails.endless.classes
	end
	return false
end

--[[ The trails earned and not yet held, in the tab's order. ]]
function TrailRules.due(held: Held): { string }
	local out = {}
	for _, key in Trails.order do
		if not held.trails[key] and TrailRules.earned(key, held) then
			table.insert(out, key)
		end
	end
	return out
end

--[[ What a trail not held says gets it: "BEAT KING BLOBLIN", "REACH FLOOR
     50 IN ENDLESS WITH EVERY CLASS (1/3)", a shut area's "BEAT THE
     BROODMOTHER"; nil for one on sale, whose price shows instead. ]]
function TrailRules.howTo(key: string, held: Held, locks: boolean?): string?
	local trail = Trails.trails[key]
	if not trail then
		return nil
	end
	if trail.earn == "Boss" then
		local area = Economy.areas[trail.area]
		local item = area and Economy.items[area.bossItem]
		return "BEAT " .. string.upper(if item then item.boss else trail.area)
	elseif trail.earn == "Endless" then
		return string.format(
			"REACH FLOOR %d IN ENDLESS WITH EVERY CLASS (%d/%d)",
			Trails.endless.floor,
			TrailRules.endlessClasses(held.endlessClassBest),
			#Trails.endless.classes
		)
	end
	local index = crateIndex(trail.area)
	return if index then ShopRules.crateWords(index, held.bossesBeaten, locks) else nil
end

return TrailRules
