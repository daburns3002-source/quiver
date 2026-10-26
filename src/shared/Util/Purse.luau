--!strict
--[[
	Prices against a profile (`SaveSchema.Profile`): whether it can pay,
	and paying. Pure, so `tests/Purse.spec` pins that nothing is ever
	taken that a profile does not have, and that a price is paid whole or
	not at all.
]]

local SaveSchema = require(script.Parent.SaveSchema)

export type Cost = {
	coins: number?,
	gems: number?,
	--[[ Boss items by id, how many of each. ]]
	items: { [string]: number }?,
}

local Purse = {}

local NONE: { [string]: number } = {}

function Purse.canAfford(profile: SaveSchema.Profile, cost: Cost): boolean
	if profile.coins < (cost.coins or 0) or profile.gems < (cost.gems or 0) then
		return false
	end
	for id, n in cost.items or NONE do
		if (profile.items[id] or 0) < n then
			return false
		end
	end
	return true
end

--[[ Pays the whole price, or nothing and false. ]]
function Purse.pay(profile: SaveSchema.Profile, cost: Cost): boolean
	if not Purse.canAfford(profile, cost) then
		return false
	end
	profile.coins -= cost.coins or 0
	profile.gems -= cost.gems or 0
	for id, n in cost.items or NONE do
		local left = (profile.items[id] or 0) - n
		if left > 0 then
			profile.items[id] = left
		else
			profile.items[id] = nil
		end
	end
	return true
end

return Purse
