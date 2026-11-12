--!strict
--[[
	The end screens' colours, words and type sizes. The blocks, their sizes
	and the words are the blocky sheets' (`assets/concepts/blocky/ui/
	end_victory.jpg`, `end_defeat.jpg`; owner's yes 2026-10-25); **the
	colours and the font are the owner's UI reference of 2026-11-11** ("use
	this as the major reference image"): a cream panel inked in dark brown,
	orange plates for the titles, bright cyan rows under white words, a
	green or gold main button and a red way out. Flat colour only: every
	block is a fill with a lighter strip along its top and a darker band
	along its bottom, inside an ink outline.

	A block's look: `ink` outline `inkW` thick, then an optional `rim`
	`rimW` thick inside it, then `fill`, with `top` (`topH` tall) and
	`bottom` (`bottomH` tall) bands. Sizes are sheet pixels.
]]

local rgb = Color3.fromRGB

export type Block = {
	ink: Color3,
	inkW: number,
	rim: Color3?,
	rimW: number?,
	fill: Color3,
	top: Color3?,
	topH: number?,
	bottom: Color3?,
	bottomH: number?,
}

local INK = rgb(86, 44, 16)

local EndScreenTheme = {
	ink = INK,
	white = rgb(255, 255, 255),

	--[[ Every word: the chunky kit's rounded font (CLAUDE.md rule 11's
	     exception), since the owner's UI reference of 2026-11-11. ]]
	font = Enum.Font.FredokaOne,

	victory = {
		titleText = "VICTORY!",
		subText = "LEVEL COMPLETE",
		--[[ In its place when the player's coins buy an open egg (review
		     item 9, owner 2026-11-11). ]]
		hatchText = "YOU CAN HATCH AN EGG!",
		buttonText = "NEXT LEVEL",
		--[[ On the tutorial's Victory, whose button goes to the lobby and
		     the class screen, not to a level (`Util/EndScreenRules`). ]]
		lobbyText = "CONTINUE",
		labels = { "ENEMIES DEFEATED", "TIME", "HEALTH LEFT" },
		--[[ Type sizes (TextSize, sheet pixels) and the ink outline round
		     the words, each matched to its sheet's lettering. ]]
		text = {
			title = 140,
			titleStroke = 8,
			sub = 47,
			subStroke = 4,
			tab = 67,
			tabStroke = 5,
			rewardsTab = 46,
			rowLabel = 44,
			rowValue = 52,
			rowStroke = 3,
			reward = 78,
			rewardStroke = 5,
			button = 78,
			buttonStroke = 6,
			lobbyButton = 50,
			lobbyButtonStroke = 5,
		},
		--[[ The title's letters: white over a gold lower half. ]]
		title = rgb(255, 255, 255),
		titleLow = rgb(253, 190, 30),
		subTextColour = rgb(255, 255, 255),
		panel = {
			ink = INK,
			inkW = 7,
			rim = rgb(255, 255, 255),
			rimW = 8,
			fill = rgb(255, 246, 228),
			bottom = rgb(232, 208, 168),
			bottomH = 16,
		} :: Block,
		sub = {
			ink = INK,
			inkW = 8,
			fill = rgb(250, 152, 40),
			top = rgb(255, 198, 96),
			topH = 10,
			bottom = rgb(204, 108, 20),
			bottomH = 12,
		} :: Block,
		studs = rgb(255, 222, 160),
		tab = {
			ink = INK,
			inkW = 7,
			fill = rgb(250, 152, 40),
			top = rgb(255, 198, 96),
			topH = 10,
			bottom = rgb(204, 108, 20),
			bottomH = 8,
		} :: Block,
		tabStuds = rgb(255, 222, 160),
		stats = {
			ink = INK,
			inkW = 8,
			rim = rgb(255, 250, 238),
			rimW = 8,
			fill = rgb(250, 232, 198),
			bottom = rgb(222, 194, 150),
			bottomH = 11,
		} :: Block,
		row = {
			ink = rgb(10, 74, 140),
			inkW = 6,
			fill = rgb(28, 168, 255),
			top = rgb(110, 206, 255),
			topH = 9,
			bottom = rgb(16, 128, 214),
			bottomH = 9,
		} :: Block,
		rewards = {
			ink = rgb(10, 74, 140),
			inkW = 6,
			fill = rgb(28, 168, 255),
			top = rgb(110, 206, 255),
			topH = 10,
			bottom = rgb(16, 128, 214),
			bottomH = 9,
		} :: Block,
		slot = {
			ink = rgb(10, 74, 140),
			inkW = 6,
			rim = rgb(16, 128, 214),
			rimW = 8,
			fill = rgb(12, 100, 180),
		} :: Block,
		button = {
			ink = INK,
			inkW = 9,
			fill = rgb(104, 214, 46),
			top = rgb(176, 244, 120),
			topH = 13,
			bottom = rgb(52, 138, 22),
			bottomH = 46,
		} :: Block,
		--[[ BACK TO LOBBY, under the main button: the same block, red so it
		     reads as leaving and never as the way on. ]]
		lobbyButton = {
			ink = INK,
			inkW = 8,
			fill = rgb(238, 60, 60),
			top = rgb(255, 132, 120),
			topH = 11,
			bottom = rgb(150, 30, 34),
			bottomH = 22,
		} :: Block,
		--[[ The button's segmented foot: its band and the lines across it. ]]
		buttonFoot = rgb(44, 122, 18),
		buttonFootLine = rgb(24, 74, 10),
		buttonShine = rgb(204, 250, 172),
		buttonStuds = rgb(176, 244, 120),
		--[[ How faded the chest is while the run gave none. ]]
		chestDim = 0.55,
		cubes = rgb(255, 208, 40),
		rays = rgb(255, 255, 255),
		raysTransparency = 0.55,
		confetti = { rgb(255, 210, 63), rgb(255, 230, 128), rgb(245, 166, 35), rgb(255, 244, 184) },
		flash = rgb(255, 255, 255),
	},

	defeat = {
		titleText = "DEFEAT",
		--[[ One line on getting stronger (review item 9; was "SO CLOSE!
		     TRY AGAIN"). ]]
		subText = "HATCH PETS TO GET STRONGER",
		buttonText = "TRY AGAIN",
		labels = { "ENEMIES DEFEATED", "TIME SURVIVED", "PROGRESS" },
		--[[ Type sizes (TextSize, sheet pixels) and the ink outline round
		     the words, each matched to its sheet's lettering. ]]
		text = {
			title = 160,
			titleStroke = 8,
			sub = 47,
			subStroke = 4,
			tab = 52,
			tabStroke = 5,
			rewardsTab = 40,
			rowLabel = 34,
			rowValue = 46,
			rowStroke = 3,
			reward = 78,
			rewardStroke = 5,
			button = 78,
			buttonStroke = 6,
			lobbyButton = 50,
			lobbyButtonStroke = 5,
		},
		title = rgb(255, 255, 255),
		titleLow = rgb(255, 170, 160),
		subTextColour = rgb(255, 255, 255),
		panel = {
			ink = INK,
			inkW = 7,
			rim = rgb(255, 255, 255),
			rimW = 9,
			fill = rgb(255, 246, 228),
			bottom = rgb(232, 208, 168),
			bottomH = 18,
		} :: Block,
		--[[ The darker band just inside the panel's edge: the gloom. ]]
		vignette = rgb(244, 226, 196),
		vignetteW = 34,
		sub = {
			ink = INK,
			inkW = 7,
			fill = rgb(238, 60, 60),
			top = rgb(255, 132, 120),
			topH = 9,
			bottom = rgb(150, 30, 34),
			bottomH = 9,
		} :: Block,
		tab = {
			ink = INK,
			inkW = 7,
			fill = rgb(238, 60, 60),
			top = rgb(255, 132, 120),
			topH = 8,
			bottom = rgb(150, 30, 34),
			bottomH = 7,
		} :: Block,
		stats = {
			ink = INK,
			inkW = 7,
			rim = rgb(255, 250, 238),
			rimW = 7,
			fill = rgb(250, 232, 198),
			bottom = rgb(222, 194, 150),
			bottomH = 10,
		} :: Block,
		row = {
			ink = rgb(10, 74, 140),
			inkW = 5,
			fill = rgb(28, 168, 255),
			top = rgb(110, 206, 255),
			topH = 9,
			bottom = rgb(16, 128, 214),
			bottomH = 9,
		} :: Block,
		rewards = {
			ink = rgb(10, 74, 140),
			inkW = 6,
			fill = rgb(28, 168, 255),
			top = rgb(110, 206, 255),
			topH = 9,
			bottom = rgb(16, 128, 214),
			bottomH = 8,
		} :: Block,
		rewardsTabBlock = {
			ink = INK,
			inkW = 6,
			fill = rgb(238, 60, 60),
			top = rgb(255, 132, 120),
			topH = 6,
		} :: Block,
		slot = {
			ink = rgb(10, 74, 140),
			inkW = 6,
			rim = rgb(16, 128, 214),
			rimW = 6,
			fill = rgb(12, 100, 180),
		} :: Block,
		button = {
			ink = INK,
			inkW = 8,
			fill = rgb(255, 196, 38),
			top = rgb(255, 228, 124),
			topH = 12,
			bottom = rgb(196, 124, 10),
			bottomH = 24,
		} :: Block,
		--[[ BACK TO LOBBY, under the main button: the same block, red so it
		     reads as leaving and never as the way on. ]]
		lobbyButton = {
			ink = INK,
			inkW = 8,
			fill = rgb(238, 60, 60),
			top = rgb(255, 132, 120),
			topH = 11,
			bottom = rgb(150, 30, 34),
			bottomH = 22,
		} :: Block,
		--[[ The lower half of the button's face, a shade deeper. ]]
		buttonLow = rgb(246, 176, 30),
		buttonShine = rgb(255, 236, 160),
		buttonStuds = rgb(254, 226, 87),
		cubes = rgb(150, 160, 186),
		--[[ The segmented progress bar. ]]
		barOn = rgb(81, 231, 120),
		barOnTop = rgb(144, 248, 162),
		barOff = rgb(12, 100, 180),
		rain = rgb(150, 178, 222),
		rainTransparency = 0.45,
		flash = rgb(190, 205, 235),
	},
}

return table.freeze(EndScreenTheme)
