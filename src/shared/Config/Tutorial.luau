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

	On screen (`UI/TutorialPrompts`, redone 2026-11-11): how to move, that
	standing still shoots, the crystals, the dash, the gate out of a cleared
	room, and picking a card, each in the words for the device in hand with
	its control and its action highlighted (`prompts`, `Util/TutorialSteps`).
	The music ducks while one is up.
]]

--[[ A prompt: its heading, and its words for each kind of device. ]]
export type Prompt = {
	title: string,
	keyboard: string,
	touch: string,
	gamepad: string,
}

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

	--[[ What the prompts say (owner, 2026-11-11: "highlight the important
	     words and have the tutorial clearly explain the controls"). One idea
	     each, in the words for the device in hand, and short enough to read
	     at a glance on a phone held upright. Two marks (`Util/PromptText`):
	     `[..]` is a control, the thing to press, drag or look for, and
	     `*..*` is the action; each is drawn in its own strong colour.
	     Which one shows when is `Util/TutorialSteps`; `tests/TutorialPrompts.spec`
	     holds every prompt to the rules. ]]
	prompts = {
		move = {
			title = "MOVE",
			keyboard = "*MOVE* WITH [W A S D] OR THE [ARROW KEYS]",
			touch = "*DRAG* YOUR [THUMB] ANYWHERE ON THE SCREEN TO *MOVE*",
			gamepad = "*MOVE* WITH THE [LEFT STICK]",
		},
		shoot = {
			title = "SHOOT",
			keyboard = "*STAND STILL* TO SHOOT: LET GO OF THE [KEYS] AND YOUR BOW FIRES BY ITSELF",
			touch = "*STAND STILL* TO SHOOT: LIFT YOUR [THUMB] AND YOUR BOW FIRES BY ITSELF",
			gamepad = "*STAND STILL* TO SHOOT: LET GO OF THE [STICK] AND YOUR BOW FIRES BY ITSELF",
		},
		crystals = {
			title = "COLLECT XP",
			keyboard = "*WALK OVER* THE [BLUE CRYSTALS] ENEMIES DROP TO FILL YOUR [XP BAR]",
			touch = "*WALK OVER* THE [BLUE CRYSTALS] ENEMIES DROP TO FILL YOUR [XP BAR]",
			gamepad = "*WALK OVER* THE [BLUE CRYSTALS] ENEMIES DROP TO FILL YOUR [XP BAR]",
		},
		--[[ Until the player dashes (owner, 2026-10-27: "there needs to be a
		     part in the tutorial that shows the player to dash"). ]]
		dash = {
			title = "DASH",
			keyboard = "PRESS [SPACE] TO *DASH* THROUGH DANGER",
			touch = "TAP THE [DASH] BUTTON TO *DASH* THROUGH DANGER",
			gamepad = "PRESS [A] TO *DASH* THROUGH DANGER",
		},
		gate = {
			title = "ROOM CLEAR!",
			keyboard = "*WALK* INTO THE GLOWING [GATE] AT THE TOP TO GO ON",
			touch = "*WALK* INTO THE GLOWING [GATE] AT THE TOP TO GO ON",
			gamepad = "*WALK* INTO THE GLOWING [GATE] AT THE TOP TO GO ON",
		},
		--[[ Over the first upgrade hand, until a card is picked. ]]
		card = {
			title = "LEVEL UP!",
			keyboard = "*PICK ONE* UPGRADE: CLICK A CARD, THEN [CHOOSE!]. YOU KEEP IT ALL RUN",
			touch = "*PICK ONE* UPGRADE: TAP A CARD, THEN [CHOOSE!]. YOU KEEP IT ALL RUN",
			gamepad = "*PICK ONE* UPGRADE: PICK A CARD WITH THE [LEFT STICK], THEN PRESS [A]",
		},
	} :: { [string]: Prompt },
	--[[ Studs the player walks before the move prompt goes, and how long the
	     shooting and crystal prompts stay on screen (seconds; their time only
	     runs while they show). ]]
	moveDistance = 8,
	shootFor = 7,
	crystalsFor = 6,
	--[[ Seconds the move and dash prompts stay on screen at least, even when
	     the player walks or dashes at once, so they can be read. ]]
	minShow = 3,
	--[[ The most letters a prompt's words may run to, marks left out: more
	     is not read mid-fight. ]]
	maxLetters = 76,
	--[[ The egg the tutorial's win pays for (Fable's loop review, 2026-11-11,
	     approved: players reached the lobby ~150 coins short of it): the win
	     tops the player's coins up to its price (`Util/FirstEgg`), and the
	     lobby points at the Hatchery until they own a pet. ]]
	firstEgg = "MossyEgg",
}

return table.freeze(Tutorial)
