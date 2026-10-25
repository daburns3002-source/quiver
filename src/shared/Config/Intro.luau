--!strict
--[[
	The intro cutscene as the game starts (owner, 2026-10-25), drawn by
	`UI/IntroCutscene` and posed by `Util/IntroTimeline`, after Pixel
	Lineage's intro: a black screen where DYL.DEVS PRESENTS fades in in
	dark gold, then a cut to the full-screen title picture, with gentle
	motion over it, and a BEGIN ADVENTURE button that starts the run.

	The times are the shared contract with the intro music (side-session
	note `intro-cutscene-contract.md`): the music (`Config/Music.intro`)
	starts on the cutscene's first frame and its grandiose theme hits at
	`revealAt`. Change one only with the music.

	The run holds still until the player presses the button: the server
	skips its step while anyone is still on the title (`RunSession.anyAtTitle`).
	In Studio, a `SkipIntro` attribute on Workspace, set in Edit before Play,
	skips the intro on both sides, for probes that need the run going.
]]

local Intro = {
	--[[ Seconds from the cutscene starting. ]]
	presentsIn = 0.6,
	--[[ How long the words take to fade (and pop) in, and out. ]]
	presentsFadeIn = 0.5,
	presentsOut = 3.8,
	presentsFadeOut = 0.6,
	--[[ The cut to the picture, on the music's hit. ]]
	revealAt = 5.0,
	--[[ A white flash on the cut, fading over this long. ]]
	flash = 0.35,
	--[[ The button rises in after the cut. ]]
	buttonAt = 5.8,
	buttonIn = 0.45,
	--[[ After the press, the title fades off over this long. ]]
	leave = 0.7,

	presents = "DYL.DEVS PRESENTS",
	--[[ Dark gold (owner's brief), on black. ]]
	presentsColour = Color3.fromRGB(176, 132, 36),
	--[[ The words start this much larger and settle to 1 as they fade in. ]]
	presentsPop = 1.18,

	button = "BEGIN ADVENTURE",

	--[[ The title picture (`assets/concepts/blocky/ui/intro/title.png`,
	     Codex, the owner's pick A with its logo painted in, 2026-10-25),
	     cut into two halves under Roblox's 1024 px limit by
	     `assets/ui/intro/cut.py` and uploaded through Studio's MCP. ]]
	picture = {
		left = "rbxassetid://93694893016976",
		right = "rbxassetid://134918920655339",
		--[[ The source's size, each half's width and where the right half
		     starts (the halves overlap by 8 px, so no seam shows). ]]
		width = 1672,
		height = 941,
		half = 840,
		rightFrom = 832,
	},

	--[[ Ambience over the still. A slow zoom in and out from the
	     picture's top edge (where its logo is), over `period` seconds,
	     drifting sideways by up to `drift` of the room the zoom leaves, so
	     no edge ever shows. Kept small: on a screen wider than the picture
	     the zoom crops more of the heroes at the bottom. ]]
	zoom = { from = 1, to = 1.07, period = 28, drift = 0.8 },
	--[[ Light shafts from the upper right, as in the picture, breathing. ]]
	shafts = { count = 4, transparency = 0.7, breathe = 0.08, period = 6 },
	--[[ Blocky motes (gold sparks and leaf cubes) drifting up and across. A
	     phone draws fewer. ]]
	motes = {
		count = 26,
		phoneCount = 14,
		size = { 4, 10 },
		speed = { 0.02, 0.05 },
		colours = {
			Color3.fromRGB(255, 214, 110),
			Color3.fromRGB(255, 236, 170),
			Color3.fromRGB(126, 196, 64),
			Color3.fromRGB(88, 164, 48),
		},
	},

	--[[ The button's colours: the end screens' green. ]]
	buttonColour = Color3.fromRGB(70, 176, 58),
	buttonEdge = Color3.fromRGB(28, 96, 30),
	buttonText = Color3.fromRGB(255, 255, 255),
	--[[ The button's breathing scale while it waits. ]]
	buttonPulse = { size = 0.04, period = 1.6 },
}

return table.freeze(Intro)
