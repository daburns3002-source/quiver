--!strict
--[[
	Where everything on the end screens sits, in pixels of their reference
	sheets (`assets/concepts/blocky/ui/end_victory.jpg`, `end_defeat.jpg`,
	1024 × 1536), measured off the sheets. Each box is { x, y, w, h } from
	the sheet's top left; the screen is built at the sheet's size and scaled
	as a whole.

	`steps` is a stair-stepped corner: that many steps, each `step` pixels
	across and down (`stepY` down when it differs).
]]

local EndScreenLayout = {
	canvas = Vector2.new(1024, 1536),

	victory = {
		panel = { x = 34, y = 44, w = 955, h = 1478 },
		panelSteps = 3,
		panelStep = 45,
		panelStepY = 36,
		ribbon = { x = 66, y = 60, w = 892, h = 246 },
		title = { x = 66, y = 92, w = 892, h = 110 },
		sub = { x = 252, y = 222, w = 520, h = 114 },
		hero = { x = 238, y = 326, w = 548, h = 428 },
		heroCentre = Vector2.new(512, 560),
		rays = { x = 512 - 820, y = 560 - 820, w = 1640, h = 1640 },
		tab = { x = 232, y = 718, w = 560, h = 92 },
		stats = { x = 68, y = 758, w = 888, h = 584 },
		--[[ Inside each row: the icon's left edge and size, where the label
		     starts and where the value ends. ]]
		rows = {
			x = 114,
			y = 818,
			w = 796,
			h = 96,
			pitch = 91,
			iconX = 44,
			icon = 70,
			labelX = 144,
			valueRight = 756,
		},
		rewards = { x = 112, y = 1120, w = 798, h = 190 },
		rewardsTab = { x = 322, y = 1098, w = 380, h = 62 },
		slots = {
			{ x = 146, y = 1150, w = 362, h = 136 },
			{ x = 516, y = 1150, w = 362, h = 136 },
		},
		--[[ Inside each slot: the icon's left edge and size, and where the
		     number starts. ]]
		slotIconX = 42,
		slotIcon = 86,
		slotTextX = 150,
		button = { x = 166, y = 1324, w = 692, h = 170 },
		--[[ The gold cubes floating round the trophy and the button:
		     { x, y, size }, their centres. ]]
		cubes = {
			{ 195, 410, 74 },
			{ 866, 415, 74 },
			{ 185, 553, 62 },
			{ 224, 622, 42 },
			{ 150, 735, 62 },
			{ 869, 660, 88 },
			{ 814, 598, 44 },
			{ 127, 1408, 44 },
			{ 908, 1385, 48 },
		},
	},

	defeat = {
		panel = { x = 40, y = 30, w = 942, h = 1452 },
		panelSteps = 2,
		panelStep = 14,
		ribbon = { x = 68, y = 80, w = 882, h = 266 },
		title = { x = 68, y = 132, w = 882, h = 116 },
		sub = { x = 210, y = 287, w = 604, h = 78 },
		hero = { x = 128, y = 360, w = 770, h = 452 },
		heroCentre = Vector2.new(512, 600),
		tab = { x = 316, y = 778, w = 392, h = 78 },
		stats = { x = 72, y = 796, w = 882, h = 500 },
		rows = {
			x = 104,
			y = 852,
			w = 818,
			h = 82,
			pitch = 78,
			iconX = 24,
			icon = 62,
			labelX = 124,
			valueRight = 790,
		},
		rewards = { x = 104, y = 1094, w = 818, h = 190 },
		rewardsTab = { x = 360, y = 1092, w = 306, h = 48 },
		slots = {
			{ x = 138, y = 1146, w = 364, h = 108 },
			{ x = 524, y = 1146, w = 364, h = 108 },
		},
		slotIconX = 48,
		slotIcon = 70,
		slotTextX = 140,
		button = { x = 146, y = 1288, w = 734, h = 172 },
		--[[ Defeat's third row: the segmented progress bar. ]]
		bar = { x = 428, y = 1020, w = 360, h = 44, segments = 12 },
		cubes = {
			{ 172, 44, 58 },
			{ 88, 104, 32 },
			{ 938, 124, 36 },
			{ 120, 388, 58 },
			{ 906, 412, 58 },
			{ 176, 578, 46 },
			{ 856, 596, 46 },
			{ 66, 1356, 54 },
			{ 104, 1408, 26 },
			{ 916, 1360, 36 },
			{ 950, 1416, 58 },
		},
	},
}

return table.freeze(EndScreenLayout)
