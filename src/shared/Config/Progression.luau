--!strict
--[[
	Levelling inside a single run.

	This is run-local progression, not the meta loop — it resets every run and
	is the thing that makes two runs feel different. The permanent side lives
	in `docs/PROGRESSION.md` and is Phase 6 onwards.

	Pure data. `Loadout` reads these; nothing here knows what an ability is.
]]

export type Progression = {
	--[[ XP needed to reach level 2. Every later level costs this times
	     `levelCostGrowth` to the power of the levels already gained. ]]
	baseLevelCost: number,
	--[[
		Geometric, not linear.

		A linear curve means the back half of a run levels constantly, because
		enemy XP rises with area while the cost does not. Geometric keeps the
		number of cards a run hands out roughly fixed however long it is, which
		is what the draft needs to stay a sequence of meaningful choices rather
		than a slot machine.
	]]
	levelCostGrowth: number,
	--[[ Cards offered per level. Three is the draft; two is a coin flip and
	     four is a menu. ]]
	offerCount: number,
	--[[ Hard ceiling on levels in one run, so the XP curve cannot be outrun by
	     a long run and hand out every ability in the game. ]]
	maxLevel: number,
}

local Progression: Progression = {
	baseLevelCost = 40,
	levelCostGrowth = 1.35,
	offerCount = 3,
	maxLevel = 20,
}

return table.freeze(Progression)
