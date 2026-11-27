--!strict
--[[
	Roblox Premium's perk (`Config/Rewards.premium`; owner, 2026-11-18):
	more coins on a run's kills and clears, added to the passes' scale as
	VIP's tenth is (`Util/RunBonus.scale`), and a free egg once a reward
	day. Pure: `Data/Premium` decides with it, `tests/Premium.spec` pins
	it. Whether a player has Premium is Roblox's word
	(`Player.MembershipType`), read on the server only.
]]

local Rewards = require(script.Parent.Parent.Config.Rewards)

local PremiumRules = {}

--[[ The Player attribute that tells the screens (the name tag's mark, the
     GIFTS tab's panel). What the perk pays is the server's own reading. ]]
PremiumRules.ATTRIBUTE = "Premium"

--[[ The share Premium adds to a run's coins: 0 without it. ]]
function PremiumRules.coinShare(premium: boolean?): number
	return if premium == true then Rewards.premium.coins else 0
end

--[[ Whether the day's free egg is owed: Premium, and not paid on `today`
     (whole UTC days since 1970; `eggDay` the last day it was). ]]
function PremiumRules.eggDue(eggDay: number, today: number, premium: boolean?): boolean
	return premium == true and eggDay < today
end

--[[ A stored egg day read back: a whole day, 0 for never. ]]
function PremiumRules.read(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return 0
	end
	return math.max(0, math.floor(value))
end

return PremiumRules
