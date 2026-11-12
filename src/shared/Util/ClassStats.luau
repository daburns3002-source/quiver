--!strict
--[[
	A class's three bars on its card (`UI/ClassScreen`): damage a hit,
	attack speed, health. Read straight off `Config/Classes`, each as a
	share of the most any card's class has, so the card says what the
	numbers say and never needs retyping when they are tuned.
]]

local ClassCards = require(script.Parent.Parent.Config.ClassSelect)
local Classes = require(script.Parent.Parent.Config.Classes)

local ClassStats = {}

export type Bars = { damage: number, speed: number, health: number }

--[[ A class's raw three: its damage scale, how often it attacks (the
     inverse of its cooldown scale) and its health scale. ]]
local function raw(class: string): Bars?
	local config = Classes[class]
	if not config then
		return nil
	end
	return {
		damage = config.damageScale,
		speed = 1 / math.max(config.cooldownScale, 0.01),
		health = config.healthScale,
	}
end

--[[ The bars for `class`, each 0 to 1 against the best of the classes on
     the cards. All zero for a class that does not exist. ]]
function ClassStats.bars(class: string): Bars
	local mine = raw(class)
	if not mine then
		return { damage = 0, speed = 0, health = 0 }
	end
	local best: Bars = { damage = 0, speed = 0, health = 0 }
	for _, card in ClassCards do
		local other = raw(card.class)
		if other and not card.locked then
			best.damage = math.max(best.damage, other.damage)
			best.speed = math.max(best.speed, other.speed)
			best.health = math.max(best.health, other.health)
		end
	end
	return {
		damage = if best.damage > 0 then math.min(1, mine.damage / best.damage) else 0,
		speed = if best.speed > 0 then math.min(1, mine.speed / best.speed) else 0,
		health = if best.health > 0 then math.min(1, mine.health / best.health) else 0,
	}
end

return ClassStats
