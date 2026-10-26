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
	--[[ The longest the black screen waits for the music to load before
	     the clock starts anyway (seconds), so the hit lands on the cut. ]]
	musicWait = 3,
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

	--[[ DYL.DEVS in dark gold, PRESENTS smaller and white under it (owner,
	     2026-10-25). ]]
	presents = "DYL.DEVS",
	presentsSub = "PRESENTS",
	presentsSubColour = Color3.fromRGB(255, 255, 255),
	--[[ Dark gold (owner's brief), on black. ]]
	presentsColour = Color3.fromRGB(176, 132, 36),
	--[[ The words start this much larger and settle to 1 as they fade in. ]]
	presentsPop = 1.18,

	button = "BEGIN ADVENTURE",

	--[[ The title picture (`assets/concepts/blocky/ui/intro/title.png`,
	     Codex, the owner's pick, 2026-10-25: the three heroes on a Mossy
	     Glade hill, Thornwood beyond, the World Tree; logo painted in),
	     cut into two halves under Roblox's 1024 px limit by
	     `assets/ui/intro/cut.py` and uploaded through Studio's MCP. ]]
	picture = {
		left = "rbxassetid://94680822162414",
		right = "rbxassetid://79601534977043",
		--[[ The source's size, each half's width and where the right half
		     starts (the halves overlap by 8 px, so no seam shows). ]]
		width = 1670,
		height = 941,
		half = 839,
		rightFrom = 831,
	},

	--[[ How dark the side bars are on a screen wider than the picture
	     (the picture stretched to cover behind it): 0 black, 1 not dimmed. ]]
	sidesDim = 0.45,
	--[[ Once the picture is up nothing on it moves (owner, 2026-10-25: "the
	     screen should not move at all after it fully appears"): no zoom,
	     drift, light shafts or motes; only the cut's flash and the button
	     rising in. ]]

	--[[ The button's colours: the end screens' green. ]]
	buttonColour = Color3.fromRGB(70, 176, 58),
	buttonEdge = Color3.fromRGB(28, 96, 30),
	buttonText = Color3.fromRGB(255, 255, 255),
	--[[ The button stays still until the player reaches for it (owner,
	     2026-10-25: "static until hovered over and clicked on"): under the
	     mouse or a gamepad's focus it brightens and grows a little; held
	     down it darkens and presses in. ]]
	buttonHover = { colour = Color3.fromRGB(98, 206, 80), scale = 1.05 },
	buttonPress = { colour = Color3.fromRGB(46, 136, 40), scale = 0.96 },
}

return table.freeze(Intro)
