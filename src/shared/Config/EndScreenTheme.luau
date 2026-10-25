--!strict
--[[
	The end screens' colours, words and type sizes, sampled off their
	blocky reference sheets (`assets/concepts/blocky/ui/end_victory.jpg`,
	`end_defeat.jpg`; owner's yes 2026-10-25). Flat colour only: every
	block is a fill with a lighter strip along its top and a darker band
	along its bottom, inside an ink outline. No gradients, no rounding.

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

local INK = rgb(27, 27, 43)

local EndScreenTheme = {
	ink = INK,
	white = rgb(255, 255, 255),

	--[[ Every word: Press Start 2P (CLAUDE.md rule 11). ]]
	font = Enum.Font.Arcade,

	victory = {
		titleText = "VICTORY!",
		subText = "LEVEL COMPLETE",
		buttonText = "NEXT LEVEL",
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
		},
		--[[ The title's letters: white over a gold lower half. ]]
		title = rgb(255, 255, 255),
		titleLow = rgb(253, 190, 30),
		subTextColour = rgb(255, 255, 255),
		panel = {
			ink = INK,
			inkW = 7,
			rim = rgb(48, 157, 255),
			rimW = 8,
			fill = rgb(4, 96, 246),
			bottom = rgb(2, 47, 148),
			bottomH = 16,
		} :: Block,
		sub = {
			ink = INK,
			inkW = 8,
			fill = rgb(54, 214, 73),
			top = rgb(143, 246, 100),
			topH = 10,
			bottom = rgb(18, 136, 39),
			bottomH = 12,
		} :: Block,
		studs = rgb(160, 236, 140),
		tab = {
			ink = INK,
			inkW = 7,
			fill = rgb(19, 127, 254),
			top = rgb(97, 182, 253),
			topH = 10,
			bottom = rgb(4, 80, 196),
			bottomH = 8,
		} :: Block,
		tabStuds = rgb(121, 195, 254),
		stats = {
			ink = INK,
			inkW = 8,
			rim = rgb(35, 134, 247),
			rimW = 8,
			fill = rgb(1, 62, 190),
			bottom = rgb(2, 35, 112),
			bottomH = 11,
		} :: Block,
		row = {
			ink = rgb(3, 10, 40),
			inkW = 6,
			fill = rgb(1, 30, 100),
			top = rgb(0, 55, 164),
			topH = 9,
			bottom = rgb(1, 58, 173),
			bottomH = 9,
		} :: Block,
		rewards = {
			ink = rgb(3, 10, 40),
			inkW = 6,
			fill = rgb(0, 51, 158),
			top = rgb(0, 66, 200),
			topH = 10,
			bottom = rgb(1, 69, 194),
			bottomH = 9,
		} :: Block,
		slot = {
			ink = rgb(3, 10, 40),
			inkW = 6,
			rim = rgb(1, 64, 182),
			rimW = 8,
			fill = rgb(1, 27, 89),
		} :: Block,
		button = {
			ink = INK,
			inkW = 9,
			fill = rgb(49, 200, 68),
			top = rgb(154, 250, 118),
			topH = 13,
			bottom = rgb(19, 130, 45),
			bottomH = 46,
		} :: Block,
		--[[ The button's segmented foot: its band and the lines across it. ]]
		buttonFoot = rgb(10, 114, 35),
		buttonFootLine = rgb(4, 56, 22),
		buttonShine = rgb(170, 244, 163),
		buttonStuds = rgb(160, 236, 140),
		cubes = rgb(255, 208, 40),
		rays = rgb(255, 255, 255),
		raysTransparency = 0.55,
		confetti = { rgb(255, 210, 63), rgb(255, 230, 128), rgb(245, 166, 35), rgb(255, 244, 184) },
		flash = rgb(255, 255, 255),
	},

	defeat = {
		titleText = "DEFEAT",
		subText = "SO CLOSE! TRY AGAIN",
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
		},
		title = rgb(232, 236, 246),
		titleLow = rgb(188, 198, 220),
		subTextColour = rgb(219, 228, 244),
		panel = {
			ink = INK,
			inkW = 7,
			rim = rgb(95, 122, 179),
			rimW = 9,
			fill = rgb(46, 61, 95),
			bottom = rgb(26, 36, 60),
			bottomH = 18,
		} :: Block,
		--[[ The darker band just inside the panel's edge: the gloom. ]]
		vignette = rgb(35, 48, 79),
		vignetteW = 34,
		sub = {
			ink = INK,
			inkW = 7,
			fill = rgb(41, 54, 88),
			top = rgb(58, 74, 112),
			topH = 9,
			bottom = rgb(30, 40, 66),
			bottomH = 9,
		} :: Block,
		tab = {
			ink = INK,
			inkW = 7,
			fill = rgb(70, 96, 157),
			top = rgb(128, 157, 211),
			topH = 8,
			bottom = rgb(48, 68, 118),
			bottomH = 7,
		} :: Block,
		stats = {
			ink = INK,
			inkW = 7,
			rim = rgb(68, 96, 155),
			rimW = 7,
			fill = rgb(36, 58, 103),
			bottom = rgb(25, 43, 82),
			bottomH = 10,
		} :: Block,
		row = {
			ink = rgb(10, 14, 28),
			inkW = 5,
			fill = rgb(19, 33, 62),
			top = rgb(35, 56, 101),
			topH = 9,
			bottom = rgb(32, 51, 91),
			bottomH = 9,
		} :: Block,
		rewards = {
			ink = rgb(10, 14, 28),
			inkW = 6,
			fill = rgb(25, 40, 74),
			top = rgb(40, 62, 108),
			topH = 9,
			bottom = rgb(36, 53, 92),
			bottomH = 8,
		} :: Block,
		rewardsTabBlock = {
			ink = INK,
			inkW = 6,
			fill = rgb(52, 80, 141),
			top = rgb(99, 126, 186),
			topH = 6,
		} :: Block,
		slot = {
			ink = rgb(10, 14, 28),
			inkW = 6,
			rim = rgb(51, 71, 113),
			rimW = 6,
			fill = rgb(21, 32, 57),
		} :: Block,
		button = {
			ink = INK,
			inkW = 8,
			fill = rgb(249, 196, 67),
			top = rgb(255, 226, 104),
			topH = 12,
			bottom = rgb(194, 97, 6),
			bottomH = 24,
		} :: Block,
		--[[ The lower half of the button's face, a shade deeper. ]]
		buttonLow = rgb(246, 172, 34),
		buttonShine = rgb(255, 236, 160),
		buttonStuds = rgb(254, 226, 87),
		cubes = rgb(150, 160, 186),
		--[[ The segmented progress bar. ]]
		barOn = rgb(81, 231, 120),
		barOnTop = rgb(144, 248, 162),
		barOff = rgb(37, 52, 88),
		rain = rgb(150, 178, 222),
		rainTransparency = 0.45,
		flash = rgb(190, 205, 235),
	},
}

return table.freeze(EndScreenTheme)
