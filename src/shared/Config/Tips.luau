--!strict
--[[
	First-time tips (owner, 2026-11-13: "there should be a tutorial for
	everything new that the player has not done yet. if they have already
	seen that certain tutorial tip then dont play it anymore").

	One short tip for each thing a player meets for the first time, shown
	once ever: the moment it is on screen the server writes it down
	(`Remotes.TipSeen`, `SaveSchema` v13 `tipsSeen`) and `Util/TipRules.due`
	never lets it show again. `UI/FirstTips` draws them on the loading tip's
	plate (`Util/TipPlate`), one at a time, never holding the run.

	A key is saved, so never rename one; drop a tip by removing it. `[..]`
	marks a button or control and `*..*` an action, as in the tutorial's
	prompts (`Util/PromptText`). `tests/Tips.spec` holds every tip short
	and well marked.

	What already teaches itself is not repeated here: the tutorial (moving,
	shooting, the crystals, the dash, the gate, the first card draft), the
	NEW ENEMY! card, the story beats, a first badge's pop-up and the
	Hatchery pointer.
]]

local Tips = {}

export type Tip = {
	--[[ The words, at most `Tips.maxLength` read. ]]
	text: string,
}

--[[ The longest a tip may read (its marks dropped), so it fits two lines
     on an upright phone. ]]
Tips.maxLength = 84

--[[ Seconds a tip stays up unless tapped away, and the pause before the
     next one waiting. ]]
Tips.seconds = 7
Tips.gap = 0.6

Tips.tips = {
	-- the lobby's stations, the first time each screen opens (`UI/StationScreen`)
	Blacksmith = {
		text = "[OPEN] a crate for a random weapon, or buy one outright in the [STORE].",
	},
	EggHatchery = {
		text = "[HATCH] eggs for pets. Your pets *fight beside you* in every run.",
	},
	GearStation = {
		text = "Pick your weapon and up to two pets. Three of a tier [MERGE] into the next.",
	},
	DexHall = {
		text = "Every enemy, weapon and pet you find goes in the Dex, and each new one *pays gems*.",
	},
	Rewards = {
		text = "Come back every day for a gift, and finish quests to [CLAIM] more.",
	},
	Badges = {
		text = "Beat an area's boss to *win its badge* for this case.",
	},
	-- the lobby's other screens
	Portal = {
		text = "Pick a level and press [START]. *Win it* to open the next one.",
	},
	SoulstoneShop = {
		text = "Soulstones come from Endless runs. Spend them here on eggs and crates.",
	},
	-- the class select screen (`UI/ClassScreen`, hooked once its rebuild lands)
	ClassSelect = {
		text = "Each class *fights its own way*. Tap a class to see it, then choose.",
	},
	-- what the profile says is new, shown in the lobby
	FirstPet = {
		text = "Your pets *fight beside you* in runs. Choose who comes along at [GEAR].",
	},
	NewWeapon = {
		text = "A new weapon! Equip it at [GEAR]. Each class holds its own kind.",
	},
	Merge = {
		text = "You have three of one tier! [MERGE] them at [GEAR] for a stronger one.",
	},
	Gems = {
		text = "Gems buy weapons in the Blacksmith's [STORE].",
	},
	BossItem = {
		text = "Boss items and coins buy *Legendary weapons* at the Blacksmith.",
	},
	-- in a run
	Boss = {
		text = "A boss! Watch for its *warnings* and [DASH] out of the way.",
	},
	Reroll = {
		text = "Not keen on these cards? [REROLL] deals a new hand, a few times a run.",
	},
	NewArea = {
		text = "A new area! New enemies, a new boss, and *new pets and weapons* to find.",
	},
	Defeat = {
		text = "Every coin you picked up is *yours to keep*. Grow stronger and try again!",
	},
	EndlessCheckpoint = {
		text = "Take a gift and *push deeper*, or [BANK & LEAVE] with your Soulstones.",
	},
} :: { [string]: Tip }

return Tips
