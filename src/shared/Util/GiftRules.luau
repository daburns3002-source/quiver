--!strict
--[[
	The gift box (`Config/Rewards.gift`; owner, 2026-11-14: "there should be
	more rewards for players"): every three campaign levels won fills a
	gift, a free egg one time and a free weapon crate the next, opened on
	the REWARDS screen. Pure, so the server decides with it (`Data/Rewards`)
	and the screen draws with the same answers; `tests/Gifts.spec` pins it.

	**No clock anywhere in it.** A gift is earned by playing and waits as
	long as it likes: no timer, no energy, nothing lost by being away. The
	box holds a few gifts (`hold`); wins past a full box are not counted, so
	it is opened rather than hoarded.

	The server counts the wins as levels are really won (`Rewards.note`),
	and a claim says only "open the gift".
]]

local Rewards = require(script.Parent.Parent.Config.Rewards)

local GiftRules = {}

--[[ What the save keeps: wins counted towards gifts and not yet spent on
     one, and how many gifts have ever been opened. ]]
export type Gift = { wins: number, opened: number }

local NEED = Rewards.gift.wins
local FULL = Rewards.gift.wins * Rewards.gift.hold

local function whole(value: unknown): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.floor(value))
end

--[[ A saved gift box read back, whatever was stored (`SaveSchema`). ]]
function GiftRules.read(value: unknown): Gift
	local stored: { [any]: any } = if type(value) == "table" then value :: any else {}
	return { wins = math.min(whole(stored.wins), FULL), opened = whole(stored.opened) }
end

--[[ A level was won. Returns whether it was counted: not once the box is
     full. ]]
function GiftRules.won(gift: Gift): boolean
	if gift.wins >= FULL then
		return false
	end
	gift.wins += 1
	return true
end

--[[ How many gifts wait to be opened. ]]
function GiftRules.ready(gift: Gift): number
	return gift.wins // NEED
end

--[[ Wins towards the gift being filled, and how many it takes: all of
     them while one waits. ]]
function GiftRules.progress(gift: Gift): (number, number)
	if GiftRules.ready(gift) > 0 then
		return NEED, NEED
	end
	return gift.wins % NEED, NEED
end

--[[ What the next gift is: "Egg" first, then "Crate", turn about. ]]
function GiftRules.kind(gift: Gift): string
	return if gift.opened % 2 == 0 then "Egg" else "Crate"
end

--[[ Opens a waiting gift: marked, and what it is returned for the server
     to give. Nil when none waits. ]]
function GiftRules.claim(gift: Gift): string?
	if GiftRules.ready(gift) < 1 then
		return nil
	end
	local kind = GiftRules.kind(gift)
	gift.wins -= NEED
	gift.opened += 1
	return kind
end

return GiftRules
