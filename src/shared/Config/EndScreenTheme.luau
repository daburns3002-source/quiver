--!strict
--[[
	The end screens' tokens: colours, gradients, fonts and type sizes
	(design_handoff_end_screens, README "Screens"). Sizes are design pixels
	on the 540 × 624 panel, which is built at that size and scaled as a whole.

	Gradients are ColorSequences, top to bottom, drawn by a UIGradient
	turned 90°.
]]

local rgb = Color3.fromRGB
local stop = ColorSequenceKeypoint.new

local EndScreenTheme = {
	panelSize = Vector2.new(540, 624),
	ink = rgb(27, 27, 43),
	white = rgb(255, 255, 255),

	--[[ Both blocky: Press Start 2P (CLAUDE.md rule 11, owner 2026-10-24). ]]
	fonts = {
		--[[ Headings, values, buttons. ]]
		display = Enum.Font.Arcade,
		--[[ Row labels. ]]
		body = Enum.Font.Arcade,
	},

	victory = {
		background = ColorSequence.new({
			stop(0, rgb(74, 155, 255)),
			stop(0.42, rgb(31, 98, 224)),
			stop(1, rgb(18, 62, 158)),
		}),
		band = ColorSequence.new({
			stop(0, rgb(255, 242, 122)),
			stop(0.45, rgb(255, 210, 31)),
			stop(1, rgb(247, 163, 12)),
		}),
		tails = ColorSequence.new({ stop(0, rgb(255, 180, 31)), stop(1, rgb(224, 138, 6)) }),
		title = rgb(255, 225, 77),
		titleText = "VICTORY!",
		sub = ColorSequence.new({ stop(0, rgb(95, 224, 106)), stop(1, rgb(34, 168, 58)) }),
		subText = "LEVEL COMPLETE",
		button = ColorSequence.new({
			stop(0, rgb(142, 240, 106)),
			stop(0.5, rgb(57, 196, 58)),
			stop(1, rgb(31, 154, 44)),
		}),
		buttonText = "NEXT LEVEL",
		rays = rgb(255, 240, 170),
		raysTransparency = 0.45,
		glow = rgb(255, 236, 150),
		confetti = { rgb(255, 210, 63), rgb(255, 230, 128), rgb(245, 166, 35), rgb(255, 244, 184) },
	},

	defeat = {
		background = ColorSequence.new({
			stop(0, rgb(47, 99, 208)),
			stop(0.45, rgb(23, 70, 176)),
			stop(1, rgb(11, 38, 112)),
		}),
		band = ColorSequence.new({
			stop(0, rgb(255, 107, 107)),
			stop(0.45, rgb(240, 50, 63)),
			stop(1, rgb(184, 24, 42)),
		}),
		tails = ColorSequence.new({ stop(0, rgb(232, 50, 60)), stop(1, rgb(165, 20, 31)) }),
		title = rgb(244, 246, 251),
		titleText = "DEFEAT",
		sub = ColorSequence.new({ stop(0, rgb(42, 92, 200)), stop(1, rgb(20, 47, 122)) }),
		subText = "SO CLOSE! TRY AGAIN",
		button = ColorSequence.new({
			stop(0, rgb(255, 227, 106)),
			stop(0.5, rgb(255, 191, 31)),
			stop(1, rgb(240, 138, 6)),
		}),
		buttonText = "TRY AGAIN",
		glow = rgb(255, 40, 60),
		ember = rgb(255, 59, 71),
		rock = ColorSequence.new({ stop(0, rgb(107, 117, 144)), stop(1, rgb(58, 65, 88)) }),
	},

	panel = {
		fill = ColorSequence.new({ stop(0, rgb(15, 58, 168)), stop(1, rgb(10, 42, 128)) }),
		innerLine = rgb(31, 139, 255),
		corner = 20,
	},
	tab = {
		fill = ColorSequence.new({ stop(0, rgb(63, 164, 255)), stop(1, rgb(10, 94, 245)) }),
		accent = rgb(127, 227, 255),
	},
	row = {
		fill = rgb(6, 36, 102),
		border = rgb(4, 26, 77),
		height = 30,
		gap = 4,
		corner = 10,
	},
	rewards = {
		fill = rgb(6, 26, 85),
		border = rgb(4, 19, 64),
	},
	progress = {
		track = rgb(2, 22, 73),
		fill = ColorSequence.new({ stop(0, rgb(125, 255, 114)), stop(1, rgb(31, 194, 58)) }),
	},
	home = {
		fill = ColorSequence.new({ stop(0, rgb(29, 79, 196)), stop(1, rgb(15, 47, 134)) }),
	},

	--[[ Type sizes, and the design's CSS text-stroke widths. A CSS stroke is
	     centred on the glyph edge and the fill is painted over its inner
	     half, so the outline that shows is half the number here. ]]
	text = {
		banner = 64,
		bannerStroke = 8,
		sub = 21,
		subDefeat = 20,
		subStroke = 4,
		level = 28,
		levelStroke = 5,
		rowLabel = 15,
		rowLabelSmall = 13,
		rowValue = 19,
		rowValueStroke = 3,
		reward = 30,
		rewardStroke = 5,
		button = 34,
		buttonStroke = 6,
		home = 16,
	},
}

return table.freeze(EndScreenTheme)
