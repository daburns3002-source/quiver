--!strict
--[[
	The class levels' rules (`Config/ClassLevels`), pure, so the server that
	pays and the screens that show agree and `tests/ClassLevels.spec` pins
	them: what a run pays, how XP becomes levels, what each level gives.

	A class's standing is its level and the XP into that level, never one
	running total: a level once reached is kept even if `toNext` is retuned.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassLevels = require(ReplicatedStorage.Shared.Config.ClassLevels)

local ClassLevelRules = {}

export type Standing = { level: number, xp: number }
export type Levels = { [string]: Standing }

--[[ What `add` did: the levels reached in order (empty for none), their
     gifts summed, and the golden weapon if this is what earned it. ]]
export type Gain = {
	class: string,
	xp: number,
	--[[ The standing before and after, for the end screen's bar. ]]
	before: Standing,
	after: Standing,
	reached: { number },
	coins: number,
	gems: number,
	--[[ Free eggs and weapon crates the levels reached give: how many, for
	     the server to open (`Run/RoomController`), which then puts what
	     came out in `prizes` for the end screen's reveals. ]]
	eggs: number,
	crates: number,
	prizes: { any }?,
	weapon: string?,
}

local CLASSES = { Ranger = true, Arcanist = true, Warden = true }

--[[ Whether `class` is one that levels. ]]
function ClassLevelRules.levels(class: unknown): boolean
	return type(class) == "string" and CLASSES[class] == true
end

--[[ XP level `level` needs to become the next, nil at the top. ]]
function ClassLevelRules.need(level: number): number?
	if level >= ClassLevels.cap then
		return nil
	end
	return ClassLevels.toNext[level]
end

--[[ A class's standing in `levels`, level 1 with nothing for one never
     played. A copy: changing it changes nothing saved. ]]
function ClassLevelRules.standing(levels: Levels?, class: string): Standing
	local held = levels and levels[class]
	if held then
		return { level = held.level, xp = held.xp }
	end
	return { level = 1, xp = 0 }
end

--[[ How full the bar is, 0 to 1; full at the top level. ]]
function ClassLevelRules.fraction(standing: Standing): number
	local need = ClassLevelRules.need(standing.level)
	if not need then
		return 1
	end
	return math.clamp(standing.xp / need, 0, 1)
end

--[[ What a run pays the class played: `clearXp` for each room, wave or
     floor cleared, `winXp` more for a win. Nothing for nothing cleared. ]]
function ClassLevelRules.runXp(cleared: number, won: boolean): number
	if cleared ~= cleared then
		return 0
	end
	local rooms = math.max(0, math.floor(cleared))
	return rooms * ClassLevels.clearXp + (if won then ClassLevels.winXp else 0)
end

--[[ The golden weapon of `class`, nil for a class with none. ]]
function ClassLevelRules.weapon(class: string): string?
	return ClassLevels.weapons[class]
end

--[[ Whether a class at `level` has earned its golden weapon. ]]
function ClassLevelRules.earned(level: number): boolean
	return level >= ClassLevels.weaponLevel
end

--[[ Every golden weapon `levels` has earned, by weapon: what a profile is
     owed even if it was not given at the time (the weapon was added later,
     a grant that failed). ]]
function ClassLevelRules.owed(levels: Levels): { string }
	local out = {}
	for class, weapon in ClassLevels.weapons do
		local held = levels[class]
		if held and ClassLevelRules.earned(held.level) then
			table.insert(out, weapon)
		end
	end
	table.sort(out)
	return out
end

--[[ Adds `xp` to `class` in `levels`, in place, levelling as far as it
     carries; XP past the top is not kept. Returns what happened, for the
     server to pay and the end screen to show; nil for no such class or
     nothing to add. ]]
function ClassLevelRules.add(levels: Levels, class: string, xp: number): Gain?
	if not ClassLevelRules.levels(class) or xp ~= xp or xp <= 0 then
		return nil
	end
	local standing = ClassLevelRules.standing(levels, class)
	local gain: Gain = {
		class = class,
		xp = math.floor(xp),
		before = { level = standing.level, xp = standing.xp },
		after = standing,
		reached = {},
		coins = 0,
		gems = 0,
		eggs = 0,
		crates = 0,
		prizes = nil,
		weapon = nil,
	}
	standing.xp += gain.xp
	while true do
		local need = ClassLevelRules.need(standing.level)
		if not need then
			standing.xp = 0
			break
		end
		if standing.xp < need then
			break
		end
		standing.xp -= need
		standing.level += 1
		table.insert(gain.reached, standing.level)
		local gift = ClassLevels.gifts[standing.level]
		if gift then
			gain.coins += gift.coins or 0
			gain.gems += gift.gems or 0
			gain.eggs += gift.eggs or 0
			gain.crates += gift.crates or 0
		end
		if standing.level == ClassLevels.weaponLevel then
			gain.weapon = ClassLevels.weapons[class]
		end
	end
	levels[class] = { level = standing.level, xp = standing.xp }
	return gain
end

--[[ A stored `classLevels` as a clean one: only the classes that level, a
     whole level from 1 to the top, XP whole and short of the next level. ]]
function ClassLevelRules.read(value: unknown): Levels
	local out: Levels = {}
	if type(value) ~= "table" then
		return out
	end
	for class, held in value :: { [any]: any } do
		if ClassLevelRules.levels(class) and type(held) == "table" then
			local level, xp = held.level, held.xp
			if type(level) == "number" and level == level and level >= 1 then
				local clean = math.min(math.floor(level), ClassLevels.cap)
				local need = ClassLevelRules.need(clean)
				local into = if type(xp) == "number" and xp == xp
					then math.max(0, math.floor(xp))
					else 0
				out[class] = {
					level = clean,
					xp = if need then math.min(into, need - 1) else 0,
				}
			end
		end
	end
	return out
end

--[[ "LEVEL 4", "MAX LEVEL" at the top: what the badges print. ]]
function ClassLevelRules.words(level: number): string
	return if level >= ClassLevels.cap then "MAX LEVEL" else "LEVEL " .. level
end

return ClassLevelRules
