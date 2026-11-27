--!strict
--[[
	The story through the four areas (owner, 2026-11-13: "ok now we gotta
	change the areas to actually progress as a story"; the outline "the bog
	is rising" approved the same day, `docs/STORY.md`).

	Deep under Bogheart Caverns, Grandmother Gulp has woken up hungry, and
	every gulp swells the bog: it drowned a village, and everything that
	lived down low is pushed uphill. The heroes follow the trouble down to
	where it starts. Each boss, the first time it is beaten, gives a **beat**:
	four stills that say what its defeat uncovered, the last a WANTED poster
	for the next boss, as the opening's poster was for King Bloblin.

	A beat plays once, when the player leaves the Victory screen of a run
	in which they beat that area's boss and have not yet watched it
	(`Util/StoryBeatRules.due`, the profile's `storySeen`), and then the
	button they pressed goes on. Drawn by `UI/StoryBeat`: each still pans
	and zooms slowly (`move`), its words come up under it, a tap moves on,
	SKIP ends the beat. No new music (owner's pick: "Codex stills +
	motion").

	The stills are Codex's (`assets/concepts/blocky/ui/story/beats.py`),
	their middle 16:9 band cut into two halves under Roblox's 1024 px limit
	by `assets/ui/story/cut_beats.py` (the same numbers as `Config/Story`'s
	`picture`), uploaded through Studio's MCP. A still with no ids shows
	black under its words.
]]

export type Move = {
	--[[ How far in (1 is the whole 16:9 picture filling the window). ]]
	zoom: number,
	--[[ Where the window's middle is on the picture, 0..1 across and down. ]]
	x: number,
	y: number,
}

export type Still = {
	picture: string,
	words: string,
	--[[ A second, smaller line under the words (the poster's). ]]
	sub: string?,
	--[[ The poster's still: its words are a heading. ]]
	poster: boolean?,
	--[[ Seconds on screen before the next comes in by itself. ]]
	hold: number,
	--[[ Start and end of its slow move. ]]
	from: Move,
	to: Move,
	--[[ A game sound (`Config/Sounds`) as it comes in. ]]
	sound: string?,
}

export type Beat = {
	--[[ The boss whose first defeat plays it. ]]
	boss: string,
	stills: { Still },
}

local WIDE = { zoom = 1.0, x = 0.5, y = 0.5 }

local StoryBeats = {}

--[[ The areas in story order, the order beats play in when more than one is
     owed at once. ]]
StoryBeats.order = { "MossyGlade", "Thornwood", "DrownedVillage", "BogheartCaverns" }

--[[ Seconds: black before the first still, a still dissolving into the
     next, the words coming up after their still, the black after the last. ]]
StoryBeats.lead = 0.4
StoryBeats.dissolve = 0.5
StoryBeats.wordsAfter = 0.25
StoryBeats.wordsIn = 0.25
StoryBeats.tail = 0.5
--[[ A tap moves on only after a still has been up this long, so the tap
     that left the Victory screen cannot skip the first. ]]
StoryBeats.tapAfter = 0.8
--[[ SKIP shows after this long. ]]
StoryBeats.skipAt = 1.0
StoryBeats.skip = "SKIP"
--[[ The small line at the bottom while a still waits, by the last input
     used. ]]
StoryBeats.hints = {
	touch = "TAP TO CONTINUE",
	gamepad = "PRESS A TO CONTINUE",
	mouse = "CLICK TO CONTINUE",
}

--[[ The still's source band and its halves, as `Config/Story.picture`. ]]
StoryBeats.picture = { width = 1536, height = 864, half = 772, rightFrom = 764 }

--[[ Uploaded halves, by still (2026-11-13); a still missing here shows
     black under its words. ]]
StoryBeats.pictures = {
	b1a = { left = "rbxassetid://138557325980978", right = "rbxassetid://85091952486506" },
	b1b = { left = "rbxassetid://76828720478147", right = "rbxassetid://79080051426606" },
	b1c = { left = "rbxassetid://94675756674260", right = "rbxassetid://109649411141870" },
	b1d = { left = "rbxassetid://91277185382621", right = "rbxassetid://101281729237958" },
	b2a = { left = "rbxassetid://131574553810055", right = "rbxassetid://106671397226931" },
	b2b = { left = "rbxassetid://135421635414260", right = "rbxassetid://139445748089563" },
	b2c = { left = "rbxassetid://115701140855999", right = "rbxassetid://119090372990338" },
	b2d = { left = "rbxassetid://114589400579978", right = "rbxassetid://104529172208163" },
	b3a = { left = "rbxassetid://120756277036362", right = "rbxassetid://111169326388584" },
	b3b = { left = "rbxassetid://112175673221780", right = "rbxassetid://116157907982078" },
	b3c = { left = "rbxassetid://74917416166259", right = "rbxassetid://106382710466179" },
	b3d = { left = "rbxassetid://90040191412625", right = "rbxassetid://110752945563643" },
	b4a = { left = "rbxassetid://92472544683346", right = "rbxassetid://116054423901005" },
	b4b = { left = "rbxassetid://82859706757050", right = "rbxassetid://139062074499777" },
	b4c = { left = "rbxassetid://107160632018196", right = "rbxassetid://127133838770273" },
	b4d = { left = "rbxassetid://92744465655031", right = "rbxassetid://88952928826693" },
} :: { [string]: { left: string, right: string } }

local glade: Beat = {
	boss = "King Bloblin",
	stills = {
		{
			picture = "b1a",
			words = "King Bloblin is beaten!",
			hold = 3.0,
			from = WIDE,
			to = { zoom = 1.12, x = 0.5, y = 0.55 },
			sound = "boss_king_goo",
		},
		{
			picture = "b1b",
			words = "But his chest holds no gold. Just bog water!",
			hold = 3.4,
			from = { zoom = 1.12, x = 0.5, y = 0.45 },
			to = WIDE,
			sound = "crate_open",
		},
		{
			picture = "b1c",
			words = "Somewhere, the bog is rising... and the slime trail leads into the Thornwood.",
			hold = 4.0,
			from = { zoom = 1.2, x = 0.42, y = 0.5 },
			to = { zoom = 1.2, x = 0.58, y = 0.5 },
		},
		{
			picture = "b1d",
			words = "WANTED: THE BROODMOTHER",
			sub = "She fled the rising water and webbed the Thornwood shut.",
			poster = true,
			hold = 4.2,
			from = WIDE,
			to = { zoom = 1.14, x = 0.55, y = 0.44 },
			sound = "new_item",
		},
	},
}

local thornwood: Beat = {
	boss = "The Broodmother",
	stills = {
		{
			picture = "b2a",
			words = "The Broodmother is beaten!",
			hold = 3.0,
			from = WIDE,
			to = { zoom = 1.12, x = 0.5, y = 0.55 },
			sound = "enemy_thornling_hatch",
		},
		{
			picture = "b2b",
			words = "Her great web falls away...",
			hold = 3.0,
			from = { zoom = 1.12, x = 0.5, y = 0.45 },
			to = { zoom = 1.04, x = 0.5, y = 0.515 },
			sound = "boss_brood_web_break",
		},
		{
			picture = "b2c",
			words = "...and a road runs downhill, to a village under water.",
			hold = 4.0,
			from = { zoom = 1.2, x = 0.5, y = 0.42 },
			to = { zoom = 1.2, x = 0.5, y = 0.58 },
		},
		{
			picture = "b2d",
			words = "WANTED: OLD TOLLCRAB",
			sub = "He lives in the sunken church bell. Every toll wakes the drowned.",
			poster = true,
			hold = 4.2,
			from = WIDE,
			to = { zoom = 1.14, x = 0.55, y = 0.44 },
			sound = "new_item",
		},
	},
}

local village: Beat = {
	boss = "Old Tollcrab",
	stills = {
		{
			picture = "b3a",
			words = "Old Tollcrab rings one last, clear toll.",
			hold = 3.2,
			from = WIDE,
			to = { zoom = 1.12, x = 0.5, y = 0.55 },
			sound = "reveal_glitter",
		},
		{
			picture = "b3b",
			words = "The flood drains away... down, under the church.",
			hold = 3.6,
			from = { zoom = 1.2, x = 0.5, y = 0.42 },
			to = { zoom = 1.2, x = 0.5, y = 0.58 },
		},
		{
			picture = "b3c",
			words = "GULP.",
			hold = 2.6,
			from = WIDE,
			to = { zoom = 1.2, x = 0.5, y = 0.5 },
			sound = "pet_fern_frog",
		},
		{
			picture = "b3d",
			words = "WANTED: GRANDMOTHER GULP",
			sub = "Every gulp she takes makes the bog rise.",
			poster = true,
			hold = 4.2,
			from = WIDE,
			to = { zoom = 1.14, x = 0.55, y = 0.44 },
			sound = "new_item",
		},
	},
}

local caverns: Beat = {
	boss = "Grandmother Gulp",
	stills = {
		{
			picture = "b4a",
			words = "Grandmother Gulp spits out the Bogheart Pearl!",
			hold = 3.4,
			from = WIDE,
			to = { zoom = 1.12, x = 0.5, y = 0.5 },
			sound = "reveal_glitter",
		},
		{
			picture = "b4b",
			words = "The bog sinks, and the village dries out in the sun.",
			hold = 3.6,
			from = { zoom = 1.2, x = 0.42, y = 0.5 },
			to = { zoom = 1.2, x = 0.58, y = 0.5 },
		},
		{
			picture = "b4c",
			words = "Then the wind turns...",
			hold = 2.8,
			from = WIDE,
			to = { zoom = 1.1, x = 0.54, y = 0.46 },
			sound = "fx_whirlwind",
		},
		{
			picture = "b4d",
			words = "WANTED: THE TEMPEST ROC",
			sub = "To be continued...",
			poster = true,
			hold = 4.2,
			from = WIDE,
			to = { zoom = 1.14, x = 0.5, y = 0.44 },
			sound = "new_item",
		},
	},
}

--[[ By `Config/Economy` area key. ]]
StoryBeats.beats = {
	MossyGlade = glade,
	Thornwood = thornwood,
	DrownedVillage = village,
	BogheartCaverns = caverns,
} :: { [string]: Beat }

return table.freeze(StoryBeats)
