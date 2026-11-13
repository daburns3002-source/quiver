--!strict
--[[
	A class's three bars on its card (`UI/ClassScreen`): RANGE, how far off it
	picks a target; POWER, damage a hit; SPEED, how often it attacks. Read
	straight off `Config/Classes` (and `Balance.Player.attackRange` for a class
	with no reach of its own), each as a share of the most any open card's
	class has, so the card says what the numbers say and never needs retyping
	when they are tuned.
]]

local Balance = require(script.Parent.Parent.Config.Balance)
local ClassSelect = require(script.Parent.Parent.Config.ClassSelect)
local Classes = require(script.Parent.Parent.Config.Classes)

local ClassStats = {}

export type Bars = { range: number, power: number, speed: number }

local NONE: Bars = table.freeze({ range = 0, power = 0, speed = 0 })

--[[ A class's raw three: its targeting reach, its damage scale and how
     often it attacks (the inverse of its cooldown scale). ]]
local function raw(class: string): Bars?
	local config = Classes[class]
	if not config then
		return nil
	end
	return {
		range = config.reach or Balance.Player.attackRange,
		power = config.damageScale,
		speed = 1 / math.max(config.cooldownScale, 0.01),
	}
end

local function share(mine: number, best: number): number
	return if best > 0 then math.min(1, mine / best) else 0
end

--[[ The bars for `class`, each 0 to 1 against the best of the open classes
     on the cards. All zero for a class that does not exist. ]]
function ClassStats.bars(class: string): Bars
	local mine = raw(class)
	if not mine then
		return NONE
	end
	local best: Bars = { range = 0, power = 0, speed = 0 }
	for _, card in ClassSelect.cards do
		local other = raw(card.class)
		if other and not card.locked then
			best.range = math.max(best.range, other.range)
			best.power = math.max(best.power, other.power)
			best.speed = math.max(best.speed, other.speed)
		end
	end
	return {
		range = share(mine.range, best.range),
		power = share(mine.power, best.power),
		speed = share(mine.speed, best.speed),
	}
end

return ClassStats
