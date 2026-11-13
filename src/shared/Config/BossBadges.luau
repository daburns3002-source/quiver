--!strict
--[[
	The boss badges (owner, 2026-11-12: "i also want there to be a badge
	system in the game for each boss, there should be a blocky circular icon
	created for each boss indicating the player has beaten them like how
	they do in pokemon with gym badges").

	One badge an area boss, in the order the areas are played. It is earned
	the first time that boss falls, which the profile already keeps
	(`profile.bossesBeaten[area]`, `Data/Wallet.beatBoss`), and shown in the
	BADGES case (`UI/BadgeCase`). The boss's name is its item's
	(`Config/Economy.items`), the area's name the Dex's (`Config/Dex.areas`).

	The art is Codex's version A, the bosses' faces on a gold-rimmed medal
	in the area's colour, which the owner picked on 2026-11-12 over B, a
	sign for each boss (`assets/concepts/blocky/ui/badges/badges_sheet.png`).
	Cut by `assets/ui/badges/cutout.py`, 512 px each.

	An area built later adds its badge here: `tests/BossBadges.spec` fails
	until every area with a boss has one.
]]

export type Badge = {
	--[[ The area's key, as `Config/Economy.areas` and `bossesBeaten` name it. ]]
	area: string,
	image: string,
}

local BossBadges = {
	order = {
		{ area = "MossyGlade", image = "rbxassetid://120348250927391" },
		{ area = "Thornwood", image = "rbxassetid://140147962511698" },
		{ area = "DrownedVillage", image = "rbxassetid://128643943546396" },
		{ area = "BogheartCaverns", image = "rbxassetid://129454169242172" },
	} :: { Badge },
}

return table.freeze(BossBadges)
