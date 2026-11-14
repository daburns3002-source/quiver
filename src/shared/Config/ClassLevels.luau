--!strict
--[[
	Class levels (owner, 2026-11-14: "i want there to be class specific
	leveling as well and when a player gets to level 10 on a certain class,
	they should unlock a golden weapon"). Each class has its own lasting
	level, apart from the level inside a run (`Config/Progression`), earned
	by playing that class and kept in the save (`SaveSchema.classLevels`).

	The owner's four calls (2026-11-14):
	- XP is paid by the server when a run ends, to the class played: some
	  for every room, wave or floor cleared and a bonus for a win. A loss
	  still pays for what was cleared. No timers, no energy.
	- 10 is the top for now; each level from 2 to 9 gives a small gift.
	- Level 10 gives the class's golden weapon: Legendary strength, a gold
	  glow, earned only (never sold, never rolled from a crate).
	- The level shows at class select, on the Gear screen's hero and on the
	  end screens, with a LEVEL UP moment.

	The rules that read this are `Util/ClassLevelRules`; `tests/
	ClassLevels.spec` pins them.
]]

--[[ `crates` are free opens of the best weapon crate for the class that
     levelled, and `eggs` free hatches of the best egg open to the player
     (`Util/PrizeRules`), each with its usual reveal on the end screen. ]]
export type Gift = { coins: number?, gems: number?, eggs: number?, crates: number? }

local ClassLevels = {
	--[[ The top level. ]]
	cap = 10,

	--[[ XP from level n to n + 1, for n = 1 to cap - 1: 3,750 in all. With
	     a won level of 10 to 25 rooms paying 150 to 300, the first win
	     reaches level 2 and level 10 is about 20 good runs. ]]
	toNext = { 100, 150, 200, 300, 400, 500, 600, 700, 800 },

	--[[ XP for each room, wave or Endless floor cleared, and the bonus on
	     top for winning the level. The same in every area: a later level
	     is longer, so it pays more by itself. ]]
	clearXp = 10,
	winXp = 50,

	--[[ What reaching each level gives, on top of the number. Level 10's
	     gift is the golden weapon (`weapons`). Level 3 opens a weapon crate
	     for the class and level 5 hatches an egg (owner, 2026-11-14:
	     "there should be more rewards for players"; they were 10 and 20
	     gems). Level 7 stays gems until the class trails are designed and
	     approved. ]]
	gifts = {
		[2] = { coins = 200 },
		[3] = { crates = 1 },
		[4] = { coins = 400 },
		[5] = { eggs = 1 },
		[6] = { coins = 600 },
		[7] = { gems = 30 },
		[8] = { coins = 800 },
		[9] = { gems = 40 },
	} :: { [number]: Gift },

	--[[ Gems paid in place of a crate or an egg there is none of to give
	     (no crate with a weapon for the class, no egg open). ]]
	insteadGems = 15,

	--[[ The level a class's golden weapon is given at, and which it is
	     (`Config/Weapons`, `Config/WeaponStats`). ]]
	weaponLevel = 10,
	weapons = {
		Ranger = "GoldenBow",
		Arcanist = "GoldenStaff",
		Warden = "GoldenBlade",
	} :: { [string]: string },
}

return table.freeze(ClassLevels)
