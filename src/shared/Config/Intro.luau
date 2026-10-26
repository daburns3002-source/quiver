--!strict
--[[
	The intro cutscene as the game starts (owner, 2026-10-25), drawn by
	`UI/IntroCutscene` and posed by `Util/IntroTimeline`, after Pixel
	Lineage's intro: a black screen where DYL.DEVS PRESENTS fades in in
	dark gold, then a cut to the full-screen title picture, with gentle
	motion over it, and a BEGIN ADVENTURE button that plays the story
	cutscene (`UI/StoryCutscene`, `Config/Story`), whose end starts the run.

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
	--[[ The picture itself never moves (owner, 2026-10-25: "the screen should
	     not move at all after it fully appears"), but a couple of things on
	     it do, very minimally (owner, 2026-10-26: "i want the water in the
	     river to be moving, leaves falling from the ... mossy glade part",
	     the left side). Drawn by `UI/TitleMotion` in the picture's own
	     pixels (`picture.width` x `picture.height`), so they sit on the art
	     at any screen size. ]]
	motion = {
		--[[ The ponds' own pixels, brightened (`assets/ui/intro/water.py`),
		     shown through a soft band of light that slides across them, and
		     small glints that drift along the water from `spots`. ]]
		water = {
			image = "rbxassetid://105351049677009",
			box = { x = 640, y = 547, w = 855, h = 175 },
			-- seconds for the band to cross, and how strong it is at its middle
			period = 5,
			strength = 0.7,
			glintEvery = 0.7,
			glintLife = 1.4,
			glintDrift = 10,
			spots = {
				{ 655, 601 },
				{ 674, 590 },
				{ 677, 582 },
				{ 686, 610 },
				{ 689, 606 },
				{ 691, 567 },
				{ 693, 591 },
				{ 699, 607 },
				{ 706, 610 },
				{ 712, 616 },
				{ 1205, 690 },
				{ 1246, 686 },
				{ 1355, 678 },
				{ 1361, 683 },
				{ 1365, 675 },
				{ 1374, 707 },
				{ 1377, 703 },
				{ 1402, 697 },
				{ 1409, 694 },
				{ 1414, 701 },
				{ 1425, 696 },
				{ 1483, 699 },
			},
		},
		--[[ Blocky leaves (Codex, `assets/ui/intro/leaves.py`: a 2x2 sheet of
		     `cell` px frames) dropping from the left side's tree and bushes,
		     drifting right and down with a sway, then fading. ]]
		leaves = {
			sheet = "rbxassetid://102598124345595",
			cell = 128,
			spawnEvery = 1.1,
			most = 7,
			size = { 34, 48 },
			life = { 5, 7.5 },
			fall = { 55, 85 },
			drift = { 18, 40 },
			sway = { 10, 22 },
			-- where they start: boxes of title pixels (the tree top-left, the bushes)
			from = {
				{ x = 0, y = 20, w = 240, h = 170 },
				{ x = 0, y = 440, w = 180, h = 160 },
			},
		},
	},

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
