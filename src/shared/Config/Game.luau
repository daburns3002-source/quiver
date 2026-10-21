--!strict
--[[
	Game-wide constants. Pure data only — no logic, no requires.

	Everything tunable lives in a Config module so balance changes are a diff a
	reviewer can read, not a hunt through gameplay code.
]]

local Game = {
	Name = "Quiver",

	--[[
		Phase 0 placeholder. Real balance tables arrive with Phase 1.
	]]
	Version = "0.1.0",
}

return table.freeze(Game)
