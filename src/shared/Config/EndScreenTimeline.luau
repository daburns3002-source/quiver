--!strict
--[[
	The end screens' motion: per element, milliseconds from the moment the
	screen is shown (design_handoff_end_screens, Timeline.luau). Easings:
	BackOut is Enum.EasingStyle.Back, Out; CubicOut and CubicIn likewise.

	Distances are pixels of the reference sheets (`Config/EndScreenLayout`),
	about 1.9 times the first design's, so the moves are the same share of
	the screen as they were.
]]

local EndScreenTimeline = {
	victory = {
		banner = {
			start = 100,
			dur = 560,
			ease = "BackOut",
			fromOffsetY = -420,
			fromScale = 1.25,
			idleBob = 4,
		},
		sub = { start = 480, dur = 420, ease = "BackOut", fromScale = 0, fromRotation = -6 },
		rays = {
			start = 500,
			dur = 600,
			ease = "CubicOut",
			toTransparency = 0.55,
			spinDegPerSec = 12,
			fromScale = 0.6,
		},
		hero = {
			start = 650,
			dur = 620,
			ease = "BackOut",
			fromScale = 0.2,
			fromRotation = -10,
			idleFloat = 8,
			idleRadPerSec = 1.6,
		},
		--[[ The floating cubes pop in round the trophy, then bob. ]]
		cubes = { start = 760, stagger = 45, dur = 300, idleBob = 6, idleRadPerSec = 1.8 },
		flash = { peak = 820, halfWidth = 260, maxOpacity = 0.6 },
		sparks = { start = 800, dur = 650, count = 12, radius = { 230, 360 } },
		confetti = {
			start = 900,
			count = 38,
			staggerMax = 1800,
			fallPxPerSec = { 170, 320 },
			sway = { 19, 61 },
		},
		panel = { start = 1150, dur = 450, ease = "CubicOut", fromOffsetY = 114 },
		rows = {
			start = 1400,
			stagger = 170,
			dur = 340,
			fromOffsetX = -76,
			countDelay = 100,
			countDur = 700,
		},
		rewards = {
			start = 2000,
			dur = 380,
			ease = "BackOut",
			fromScale = 0.85,
			coinsCount = { 2100, 2950 },
			gemsCount = { 2250, 2950 },
		},
		button = {
			start = 2700,
			dur = 460,
			ease = "BackOut",
			fromScale = 0,
			pulse = 0.035,
			pulseRadPerSec = 4,
			shineEvery = 2400,
			enableAt = 3200,
		},
	},
	defeat = {
		banner = { start = 100, dur = 420, ease = "CubicIn", fromScale = 2.3, fromRotation = -4 },
		shake = { start = 520, dur = 430, amplitude = 17 },
		sub = { start = 680, dur = 400, ease = "BackOut", fromScale = 0 },
		hero = {
			start = 780,
			dur = 520,
			ease = "BackOut",
			fromOffsetY = -260,
			fromRotation = 8,
			idleFloat = 4,
			idleRadPerSec = 1.0,
		},
		cubes = { start = 860, stagger = 45, dur = 300, idleBob = 5, idleRadPerSec = 1.2 },
		flash = { peak = 1200, halfWidth = 220, maxOpacity = 0.3 },
		--[[ Grey cubes knocked up off the broken shield, then falling. ]]
		rocks = { start = 1180, life = 1500, count = 9, gravityPxPerSec2 = 1700 },
		--[[ The rain: thin streaks falling on a slant, round and round. ]]
		rain = {
			start = 300,
			fadeIn = 600,
			count = 70,
			fallPxPerSec = { 700, 1000 },
			length = { 26, 48 },
			slantDeg = 14,
		},
		panel = { start = 1350, dur = 450, ease = "CubicOut", fromOffsetY = 114 },
		rows = {
			start = 1600,
			stagger = 170,
			dur = 340,
			fromOffsetX = -76,
			countDelay = 100,
			countDur = 700,
		},
		progress = { rowStart = 1940, fill = { 2050, 3000 } },
		rewards = {
			start = 2500,
			dur = 380,
			ease = "BackOut",
			fromScale = 0.85,
			coinsCount = { 2600, 3400 },
			gemsCount = { 2700, 3400 },
		},
		button = {
			start = 3100,
			dur = 460,
			ease = "BackOut",
			fromScale = 0,
			pulse = 0.035,
			pulseRadPerSec = 4,
			iconSpinEvery = 2400,
			iconSpinDur = 650,
			enableAt = 3600,
		},
	},
}

return table.freeze(EndScreenTimeline)
