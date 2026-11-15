--!strict
--[[
	Level stars (`Config/Rewards.stars`; owner, 2026-11-14: "there should be
	more rewards for players"): every campaign level has three stars, each
	its own thing to do, and an area's stars open chests at 10, 20 and 30.

	- the first star for winning the level,
	- the second for finishing it with more than half health left,
	- the third for finishing it inside its time (`par`).

	A star once earned is kept: a level's stars are the stars of all its
	wins together, so the health star from one run and the time star from
	another make three. They are kept as a small number, one bit a star
	(`SaveSchema.levelStars`, version 21).

	Pure, so the server decides with it as a level is won
	(`Run/RoomController`, from the health and the time it measured itself)
	and the screens draw with the same answers; `tests/Stars.spec` pins it.
	No client reports a star.
]]

local Balance = require(script.Parent.Parent.Config.Balance)
local Dex = require(script.Parent.Parent.Config.Dex)
local Goals = require(script.Parent.Parent.Config.Goals)
local Rewards = require(script.Parent.Parent.Config.Rewards)
local SaveSchema = require(script.Parent.SaveSchema)

local StarRules = {}

--[[ The three stars, as bits, in the order the screens show them. ]]
StarRules.WIN = 1
StarRules.HEALTH = 2
StarRules.TIME = 4
StarRules.ALL = { StarRules.WIN, StarRules.HEALTH, StarRules.TIME }

export type Chest = {
	--[[ "Area:Stars", as it is saved. ]]
	key: string,
	area: string,
	--[[ What the screen says: "MOSSY GLADE: 10 STARS". ]]
	words: string,
	need: number,
	have: number,
	claimed: boolean,
	prize: Goals.Prize,
}

--[[ The seconds a level's time star allows: so many a room, or a wave. ]]
function StarRules.par(stage: Balance.StageConfig): number
	local config = Rewards.stars
	if stage.mode == "Waves" then
		return (stage.waves or 1) * config.secondsPerWave
	end
	return #(stage.rooms or {}) * config.secondsPerRoom
end

--[[ The stars a win earns: with `healthPercent` of health left (0 to 100),
     in `seconds`. Always the first; a broken number earns only that. ]]
function StarRules.earned(
	stage: Balance.StageConfig,
	healthPercent: number,
	seconds: number
): number
	local mask = StarRules.WIN
	if healthPercent == healthPercent and healthPercent > Rewards.stars.health then
		mask += StarRules.HEALTH
	end
	if seconds == seconds and seconds >= 0 and seconds <= StarRules.par(stage) then
		mask += StarRules.TIME
	end
	return mask
end

--[[ How many stars a level's number holds. ]]
function StarRules.count(mask: number?): number
	local n = 0
	for _, bit in StarRules.ALL do
		if bit32.band(mask or 0, bit) ~= 0 then
			n += 1
		end
	end
	return n
end

--[[ Whether a level's number holds star `bit`. ]]
function StarRules.has(mask: number?, bit: number): boolean
	return bit32.band(mask or 0, bit) ~= 0
end

--[[ Adds a win's stars to `level`'s. Returns what it had before and what
     it has now. ]]
function StarRules.add(stars: { [string]: number }, level: string, mask: number): (number, number)
	local had = stars[level] or 0
	local now = bit32.band(bit32.bor(had, mask), 7)
	if now ~= 0 then
		stars[level] = now
	end
	return had, now
end

local byArea: { [string]: { string } } = {}
for _, stage in Balance.Stages do
	if stage.level and stage.area and not stage.tutorial then
		local list = byArea[stage.area] or {}
		byArea[stage.area] = list
		table.insert(list, stage.level)
	end
end

--[[ The levels of `area` that carry stars. ]]
function StarRules.levels(area: string): { string }
	return byArea[area] or {}
end

--[[ How many stars are held in `area`, and how many it has. ]]
function StarRules.area(stars: { [string]: number }, area: string): (number, number)
	local have = 0
	local levels = StarRules.levels(area)
	for _, level in levels do
		have += StarRules.count(stars[level])
	end
	return have, #levels * #StarRules.ALL
end

function StarRules.key(area: string, need: number): string
	return area .. ":" .. tostring(need)
end

--[[ Every star chest, area by area in the order the game plays them, as
     `profile` stands on it. Only the chests an area has stars enough for:
     an area of one level has none yet. ]]
function StarRules.chests(profile: SaveSchema.Profile): { Chest }
	local out: { Chest } = {}
	for area, theme in Dex.areas do
		local have, most = StarRules.area(profile.levelStars, area)
		for _, chest in Rewards.stars.chests do
			if chest.stars <= most then
				local key = StarRules.key(area, chest.stars)
				table.insert(out, {
					key = key,
					area = area,
					words = `{theme.name}: {chest.stars} STARS`,
					need = chest.stars,
					have = math.min(have, chest.stars),
					claimed = profile.starChests[key] == true,
					prize = chest.prize,
				})
			end
		end
	end
	table.sort(out, function(a, b)
		if a.area ~= b.area then
			local la, lb = StarRules.levels(a.area)[1] or "", StarRules.levels(b.area)[1] or ""
			return la < lb
		end
		return a.need < b.need
	end)
	return out
end

--[[ Whether `chest` is reached and not yet opened. ]]
function StarRules.ready(chest: Chest): boolean
	return not chest.claimed and chest.have >= chest.need
end

--[[ Opens star chest `key`: marked, and its prize returned for the server
     to give. Nil when it is no chest, not reached, or opened. ]]
function StarRules.claim(profile: SaveSchema.Profile, key: unknown): Goals.Prize?
	if type(key) ~= "string" then
		return nil
	end
	for _, chest in StarRules.chests(profile) do
		if chest.key == key then
			if not StarRules.ready(chest) then
				return nil
			end
			profile.starChests[key] = true
			return chest.prize
		end
	end
	return nil
end

--[[ How many star chests wait to be opened. ]]
function StarRules.tally(profile: SaveSchema.Profile): number
	local waiting = 0
	for _, chest in StarRules.chests(profile) do
		if StarRules.ready(chest) then
			waiting += 1
		end
	end
	return waiting
end

--[[ A time as the screens say it: 250 is "4:10". ]]
function StarRules.clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

--[[ What each star asks, in the order of `ALL`, for a level of `par`
     seconds. ]]
function StarRules.words(par: number): { string }
	return { "WIN", "OVER HALF HEALTH", "UNDER " .. StarRules.clock(par) }
end

return StarRules
