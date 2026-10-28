--!strict
--[[
	The guaranteed Mythic (owner, 2026-10-28: "we are going to add a
	guaranteed mythic on the player's 100th roll of any chest or egg").
	Crates and eggs each keep a count of rolls since the last Mythic
	(`SaveSchema` `pity`); the roll that would make it `EVERY` is a Mythic
	whatever the dice say, and any Mythic, lucky or forced, sets it back to
	0. Pure, so `tests/Pity.spec` pins it.
]]

local Pity = {}

--[[ The roll that is always a Mythic. ]]
Pity.EVERY = 100

--[[ Whether the next roll is forced, with `count` rolls since the last
     Mythic already made. ]]
function Pity.forced(count: number): boolean
	return count + 1 >= Pity.EVERY
end

--[[ The count after a roll: 0 after a Mythic, one more otherwise. ]]
function Pity.after(count: number, mythic: boolean): number
	return if mythic then 0 else count + 1
end

--[[ The Mythics of a pool (crate or egg entries, by their `rarity`). ]]
function Pity.mythics<T>(pool: { T }): { T }
	local out: { T } = {}
	for _, entry in pool do
		if (entry :: any).rarity == "Mythic" then
			table.insert(out, entry)
		end
	end
	return out
end

return Pity
