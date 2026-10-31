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
	--[[ And the longest it waits for the title picture's own tiles (owner,
	     2026-10-27: "the title screen does not load on mobile"). The cut at
	     `revealAt` used to be timed off the music alone, so on a phone it
	     landed while the tiles were still coming down and cut to the black
	     underneath them; they arrived seconds later, or looked as though they
	     never did. Waiting here rather than moving the cut is what keeps the
	     music's hit on it: the clock and the track start on the same frame,
	     so holding one holds both.

	     Only the tiles of the orientation actually on screen are waited for —
	     half of them (`UI/IntroCutscene`). ]]
	tilesWait = 8,
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

	--[[ The title picture, two of the same art: `landscape` for a screen
	     wider than tall (computers, consoles), `portrait` for one taller than
	     wide (phones, which play the game upright; owner, 2026-10-26: "there
	     needs to be a mobile version of the title screen"). Codex, the owner's
	     picks (`assets/concepts/blocky/ui/intro/title.png`, `title_portrait.png`:
	     the three heroes on the Mossy Glade, Thornwood beyond, the World Tree,
	     logo painted in). Each is enlarged 2x and cut into a grid of tiles under
	     Roblox's 1024 px limit (`assets/ui/intro/tiles.py`; owner: "Resolution of
	     title screen needs to be higher"), `tiles` in row order. `width` and
	     `height` are the art's own pixels, which `water` and `leavesFrom` are in. ]]
	pictures = {
		landscape = {
			width = 1670,
			height = 941,
			cols = 4,
			rows = 2,
			tiles = {
				"rbxassetid://73283236117725",
				"rbxassetid://79625145319971",
				"rbxassetid://118420334678373",
				"rbxassetid://100688302403117",
				"rbxassetid://80972719598001",
				"rbxassetid://103915902604466",
				"rbxassetid://131692646369508",
				"rbxassetid://104553368268005",
			},
			--[[ The ponds' own pixels, brightened (`assets/ui/intro/water.py`),
			     and the spots glints start from. ]]
			water = {
				image = "rbxassetid://105351049677009",
				box = { x = 640, y = 547, w = 855, h = 175 },
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
			-- under the canopy of the Mossy Glade tree at the top left
			leavesFrom = { x = 10, y = 60, w = 230, h = 150 },
		},
		portrait = {
			width = 941,
			height = 1672,
			cols = 2,
			rows = 4,
			tiles = {
				"rbxassetid://108854052246374",
				"rbxassetid://116809946895414",
				"rbxassetid://90987120985881",
				"rbxassetid://114842959404665",
				"rbxassetid://81588607149523",
				"rbxassetid://81934830458044",
				"rbxassetid://98758801552720",
				"rbxassetid://88944366694585",
			},
			water = {
				image = "rbxassetid://100193523448159",
				box = { x = 243, y = 1000, w = 588, h = 173 },
				spots = {
					{ 275, 1067 },
					{ 308, 1064 },
					{ 318, 1063 },
					{ 323, 1045 },
					{ 346, 1043 },
					{ 348, 1057 },
					{ 357, 1034 },
					{ 361, 1020 },
					{ 691, 1093 },
					{ 728, 1098 },
					{ 736, 1109 },
					{ 740, 1137 },
					{ 743, 1070 },
					{ 765, 1145 },
					{ 772, 1138 },
					{ 778, 1115 },
					{ 783, 1149 },
					{ 815, 1133 },
				},
			},
			leavesFrom = { x = 5, y = 40, w = 140, h = 330 },
		},
	},

	--[[ How dark the side bars are on a screen wider than the picture
	     (the picture stretched to cover behind it): 0 black, 1 not dimmed. ]]
	sidesDim = 0.45,
	--[[ The picture fills the screen when that crops at most this share of
	     it (a 16:10 computer screen crops 10% of its sides), taking
	     `cropTop` of any height it loses from the top and the rest from the
	     bottom grass; a screen needing more shows it whole with bars
	     (`IntroTimeline.fit`). ]]
	maxCrop = 0.12,
	cropTop = 0.2,
	--[[ The picture itself never moves (owner, 2026-10-25: "the screen should
	     not move at all after it fully appears"), but a couple of things on
	     it do, very minimally (owner, 2026-10-26: "i want the water in the
	     river to be moving, leaves falling from the ... mossy glade part",
	     the left side). Drawn by `UI/TitleMotion` in the picture's own
	     pixels (`pictures`), so they sit on the art
	     at any screen size. ]]
	motion = {
		--[[ Each picture's `water`, shown through a soft band of light that
		     slides across it, and small glints that drift along the water. ]]
		water = {
			-- seconds for the band to cross, and how strong it is at its middle
			period = 5,
			strength = 0.7,
			glintEvery = 0.7,
			glintLife = 1.4,
			glintDrift = 10,
		},
		--[[ The Mossy Glade's own ambience leaves (`Fx/ForestAmbience`: small
		     flat leaves in `Balance.Ambience.Forest.leafColors`, fluttering),
		     a few at a time, falling straight down from the Mossy Glade tree
		     on the left (each picture's `leavesFrom`), then fading (owner, 2026-10-26: "they should just fall
		     straight down and it should be the leaves like the ambience in
		     mossy glade"). `size` is a leaf's length in title pixels; it is
		     0.45 / 0.7 as wide, as the ambience's leaf is. ]]
		leaves = {
			spawnEvery = 2.2,
			most = 4,
			size = { 12, 16 },
			life = { 5, 7 },
			fall = { 45, 65 },
			-- flips a second as it flutters
			flutter = { 1.2, 2 },
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
