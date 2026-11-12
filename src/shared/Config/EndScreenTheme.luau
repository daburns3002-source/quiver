--!strict
--[[
	The end screens' colours, words and type sizes. The blocks, their sizes
	and the words are the blocky sheets' (`assets/concepts/blocky/ui/
	end_victory.jpg`, `end_defeat.jpg`; owner's yes 2026-10-25); the font is
	the owner's UI reference of 2026-11-11 and **the colours are Lagoon**
	(owner, 2026-11-12; `Config/UiPalette`, which every colour here is read
	from): a mint-white panel inked in deep sea, sea-blue plates for the
	titles, teal rows under white words, a green or sunny main button (the
	sunny one with dark words, `buttonWords`) and a red way out. Flat colour
	only: every block is a fill with a lighter strip along its top and a
	darker band along its bottom, inside an ink outline.

	A block's look: `ink` outline `inkW` thick, then an optional `rim`
	`rimW` thick inside it, then `fill`, with `top` (`topH` tall) and
	`bottom` (`bottomH` tall) bands. Sizes are sheet pixels.
]]

local P = require(script.Parent.UiPalette)

local rgb = Color3.fromRGB
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)

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

local INK = P.edge
--[[ The palette's colours a step lighter (a block's top strip, its studs)
     and a step deeper (its bottom band). Words sit on the fill between. ]]
local MINT_LOW = P.panelBottom:Lerp(P.edge, 0.14)
local HEADER_HIGH = P.header.top:Lerp(WHITE, 0.45)
local HEADER_LOW = P.header.bottom:Lerp(BLACK, 0.25)
local TEAL_HIGH = P.secondary.top:Lerp(WHITE, 0.3)
local TEAL_LOW = P.secondary.bottom:Lerp(BLACK, 0.3)
local GO_HIGH = P.go.top:Lerp(WHITE, 0.35)
local GO_LOW = P.go.bottom:Lerp(BLACK, 0.25)
local GOLD_HIGH = P.primary.top:Lerp(WHITE, 0.4)
local GOLD_LOW = P.primary.bottom:Lerp(BLACK, 0.25)
local RED_HIGH = P.danger.top:Lerp(WHITE, 0.3)
local RED_LOW = P.danger.bottom:Lerp(BLACK, 0.3)

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
		buttonWords = P.go.text,
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
		titleLow = P.primary.bottom,
		subTextColour = rgb(255, 255, 255),
		panel = {
			ink = INK,
			inkW = 7,
			rim = rgb(255, 255, 255),
			rimW = 8,
			fill = P.panelTop,
			bottom = MINT_LOW,
			bottomH = 16,
		} :: Block,
		sub = {
			ink = INK,
			inkW = 8,
			fill = P.header.bottom,
			top = P.header.top,
			topH = 10,
			bottom = HEADER_LOW,
			bottomH = 12,
		} :: Block,
		studs = HEADER_HIGH,
		tab = {
			ink = INK,
			inkW = 7,
			fill = P.header.bottom,
			top = P.header.top,
			topH = 10,
			bottom = HEADER_LOW,
			bottomH = 8,
		} :: Block,
		tabStuds = HEADER_HIGH,
		stats = {
			ink = INK,
			inkW = 8,
			rim = P.white,
			rimW = 8,
			fill = P.panelBottom,
			bottom = MINT_LOW,
			bottomH = 11,
		} :: Block,
		row = {
			ink = P.secondary.edge,
			inkW = 6,
			fill = P.secondary.top,
			top = TEAL_HIGH,
			topH = 9,
			bottom = P.secondary.bottom,
			bottomH = 9,
		} :: Block,
		rewards = {
			ink = P.secondary.edge,
			inkW = 6,
			fill = P.secondary.top,
			top = TEAL_HIGH,
			topH = 10,
			bottom = P.secondary.bottom,
			bottomH = 9,
		} :: Block,
		slot = {
			ink = P.secondary.edge,
			inkW = 6,
			rim = P.secondary.bottom,
			rimW = 8,
			fill = TEAL_LOW,
		} :: Block,
		button = {
			ink = INK,
			inkW = 9,
			fill = P.go.top,
			top = GO_HIGH,
			topH = 13,
			bottom = GO_LOW,
			bottomH = 46,
		} :: Block,
		--[[ BACK TO LOBBY, under the main button: the same block, red so it
		     reads as leaving and never as the way on. ]]
		lobbyButton = {
			ink = INK,
			inkW = 8,
			fill = P.danger.top,
			top = RED_HIGH,
			topH = 11,
			bottom = RED_LOW,
			bottomH = 22,
		} :: Block,
		--[[ The button's segmented foot: its band and the lines across it. ]]
		buttonFoot = P.go.bottom:Lerp(BLACK, 0.35),
		buttonFootLine = P.go.edge,
		buttonShine = P.go.top:Lerp(WHITE, 0.6),
		buttonStuds = GO_HIGH,
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
		--[[ Dark on the sunny button, where white words are lost. ]]
		buttonWords = P.primary.text,
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
			-- none: the words are dark here, and an outline only smears them
			buttonStroke = 0,
			lobbyButton = 50,
			lobbyButtonStroke = 5,
		},
		title = rgb(255, 255, 255),
		titleLow = RED_HIGH,
		subTextColour = rgb(255, 255, 255),
		panel = {
			ink = INK,
			inkW = 7,
			rim = rgb(255, 255, 255),
			rimW = 9,
			fill = P.panelTop,
			bottom = MINT_LOW,
			bottomH = 18,
		} :: Block,
		--[[ The darker band just inside the panel's edge: the gloom. ]]
		vignette = P.panelBottom,
		vignetteW = 34,
		sub = {
			ink = INK,
			inkW = 7,
			fill = P.danger.top,
			top = RED_HIGH,
			topH = 9,
			bottom = RED_LOW,
			bottomH = 9,
		} :: Block,
		tab = {
			ink = INK,
			inkW = 7,
			fill = P.danger.top,
			top = RED_HIGH,
			topH = 8,
			bottom = RED_LOW,
			bottomH = 7,
		} :: Block,
		stats = {
			ink = INK,
			inkW = 7,
			rim = P.white,
			rimW = 7,
			fill = P.panelBottom,
			bottom = MINT_LOW,
			bottomH = 10,
		} :: Block,
		row = {
			ink = P.secondary.edge,
			inkW = 5,
			fill = P.secondary.top,
			top = TEAL_HIGH,
			topH = 9,
			bottom = P.secondary.bottom,
			bottomH = 9,
		} :: Block,
		rewards = {
			ink = P.secondary.edge,
			inkW = 6,
			fill = P.secondary.top,
			top = TEAL_HIGH,
			topH = 9,
			bottom = P.secondary.bottom,
			bottomH = 8,
		} :: Block,
		rewardsTabBlock = {
			ink = INK,
			inkW = 6,
			fill = P.danger.top,
			top = RED_HIGH,
			topH = 6,
		} :: Block,
		slot = {
			ink = P.secondary.edge,
			inkW = 6,
			rim = P.secondary.bottom,
			rimW = 6,
			fill = TEAL_LOW,
		} :: Block,
		button = {
			ink = INK,
			inkW = 8,
			fill = P.primary.top,
			top = GOLD_HIGH,
			topH = 12,
			bottom = GOLD_LOW,
			bottomH = 24,
		} :: Block,
		--[[ BACK TO LOBBY, under the main button: the same block, red so it
		     reads as leaving and never as the way on. ]]
		lobbyButton = {
			ink = INK,
			inkW = 8,
			fill = P.danger.top,
			top = RED_HIGH,
			topH = 11,
			bottom = RED_LOW,
			bottomH = 22,
		} :: Block,
		--[[ The lower half of the button's face, a shade deeper. ]]
		buttonLow = P.primary.bottom,
		buttonShine = P.primary.top:Lerp(WHITE, 0.6),
		buttonStuds = GOLD_HIGH,
		cubes = rgb(150, 160, 186),
		--[[ The segmented progress bar. ]]
		barOn = P.barFill,
		barOnTop = P.barFill:Lerp(WHITE, 0.35),
		barOff = TEAL_LOW,
		rain = rgb(150, 178, 222),
		rainTransparency = 0.45,
		flash = rgb(190, 205, 235),
	},
}

return table.freeze(EndScreenTheme)
