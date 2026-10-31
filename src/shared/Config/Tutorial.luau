--!strict
--[[
	The tutorial (owner, 2026-10-25): five Mossy Glade rooms played right after
	the story cutscene, before the lobby. Only Moss Slimes and Sprout Spitters,
	the player a Ranger. It is `Balance.Stages[Balance.tutorialStage]`, whose
	`tutorial` flag points the run here (`Run/RoomController`, `Run/RunSession`).

	**The upgrades are fixed** ("every player should get the same upgrades"):
	no hand is rolled. The first level-up deals a Common, an Uncommon and a Rare
	(left to right); a level-up in room 3 deals Multishot, a Legendary, in the
	middle (owner's pick, 2026-10-25); every other level-up deals the next of
	`hands`. `Util/TutorialHands` decides which, and `tests/Tutorial.spec`
	pins it. Legendaries and Mythics are out of the pool, so even a hand that
	ran out could never roll one, and rerolls are off so a hand is never swapped.

	XP is unchanged, and the rooms (`Balance` tutorial rooms) are sized so the
	level-ups land in rooms 1, 2 and 3 (level costs 28, 35, 44; a Moss Slime is
	worth 10, a Spitter 14). If room 3 clears without a level-up anyway, the
	XP still owed is granted so it gets one (`levelUpIn`).

	On screen (`UI/TutorialPrompts`): how to move until the player has, then
	that standing still shoots at the next fight, then how to dash until they
	have; and how levelling up works, over the first upgrade hand.
]]

local Tutorial = {
	--[[ The tutorial plays after the story cutscene on every join until the
	     player has beaten this level (`StageConfig.level`), then never
	     again: they go straight to the lobby (owner, 2026-10-26: "the
	     tutorial should play until they have beaten the first level of
	     mossy glade"; `Util/LevelUnlocks.tutorialOwed`, decided by the
	     server from the saved profile). ]]
	untilBeaten = "1-1",
	--[[ Everyone plays the tutorial as this class. ]]
	class = "Ranger",
	--[[ Rarities that can never be dealt in the tutorial. ]]
	bannedRarities = { "Legendary", "Mythic" },
	--[[ Redeals in the tutorial: none, so every player sees the same hands. ]]
	rerolls = 0,

	--[[ The first level-up: a Common, an Uncommon and a Rare. ]]
	firstHand = { "Strength", "RearArrow", "DoubleShot" },
	--[[ A level-up in these rooms deals this hand instead (once per room).
	     Room 3: Multishot, a Legendary, in the middle slot. ]]
	roomHands = {
		[3] = { "Lightfoot", "Multishot", "Precision" },
	} :: { [number]: { string } },
	--[[ Rooms that always level up: if one clears without a level-up, the
	     XP still owed is granted. ]]
	levelUpIn = { 3 },
	--[[ Every other level-up, in order. Only cards in rotation (none
	     `benched`). ]]
	hands = {
		{ "Vitality", "SideArrows", "Blaze" },
		{ "Heal", "BouncyWall", "DeadlyStrike" },
		{ "DiagonalArrows", "Bloodthirst", "Ricochet" },
	},

	--[[ What the prompts say. Each device is told its own controls. ]]
	prompts = {
		move = {
			keyboard = "MOVE WITH W A S D OR THE ARROW KEYS",
			touch = "DRAG ANYWHERE ON THE SCREEN TO MOVE",
			gamepad = "MOVE WITH THE LEFT STICK",
		},
		shoot = "STOP MOVING TO SHOOT! YOUR BOW FIRES BY ITSELF WHILE YOU STAND STILL",
		--[[ After the shooting one, until the player dashes (owner,
		     2026-10-27: "there needs to be a part in the tutorial that
		     shows the player to dash"). ]]
		dash = {
			keyboard = "PRESS SPACE TO DASH OUT OF DANGER!",
			touch = "TAP THE DASH BUTTON TO DASH OUT OF DANGER!",
			gamepad = "PRESS A TO DASH OUT OF DANGER!",
		},
		levelUp = {
			title = "LEVEL UP!",
			body = "DEFEAT ENEMIES AND COLLECT THEIR BLUE CRYSTALS TO FILL YOUR XP BAR. EVERY LEVEL, PICK ONE UPGRADE. UPGRADES LAST FOR THE WHOLE RUN AND STACK.",
		},
	},
	--[[ Studs the player walks before the move prompt goes, and how long the
	     shooting one stays at the next fight (seconds). ]]
	moveDistance = 8,
	shootFor = 5,
}

return table.freeze(Tutorial)
