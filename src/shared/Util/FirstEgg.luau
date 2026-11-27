--!strict
--[[
	The first egg (`Config/Tutorial.firstEgg`): the tutorial's win pays what
	the player is short of it, and the lobby points at the Hatchery while they
	can afford it and own no pet (Fable's loop review, 2026-11-11). Pure, so
	`tests/FirstEgg.spec` can pin it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local FirstEgg = {}

--[[ The first egg's price, or nil if `Config/Eggs` has no such egg. ]]
function FirstEgg.price(): number?
	for _, egg in Eggs.list do
		if egg.key == Tutorial.firstEgg then
			return egg.price
		end
	end
	return nil
end

--[[ Coins the tutorial's win adds so `coins` (after its own pay) buys the
     egg: never negative, nothing when they can already afford it. ]]
function FirstEgg.topUp(coins: number): number
	local price = FirstEgg.price()
	if not price then
		return 0
	end
	return math.max(0, price - coins)
end

--[[ Whether the lobby points the way to the Hatchery. ]]
function FirstEgg.pointWanted(coins: number, pets: { [string]: number }?): boolean
	local price = FirstEgg.price()
	if not price or coins < price then
		return false
	end
	return pets == nil or next(pets) == nil
end

return FirstEgg
