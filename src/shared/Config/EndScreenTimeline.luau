--!strict
--[[
	The end screens' motion: per element, milliseconds from the moment the
	screen is shown (design_handoff_end_screens, Timeline.luau). Easings:
	BackOut is Enum.EasingStyle.Back, Out; CubicOut and CubicIn likewise.
]]

local EndScreenTimeline = {
	victory = {
		banner = {
			start = 100,
			dur = 560,
			ease = "BackOut",
			fromOffsetY = -220,
			fromScale = 1.25,
			idleBob = 2,
		},
		sub = { start = 480, dur = 420, ease = "BackOut", fromScale = 0, fromRotation = -6 },
		rays = {
			start = 500,
			dur = 600,
			ease = "CubicOut",
			toTransparency = 0.15,
			spinDegPerSec = 12,
			fromScale = 0.6,
		},
		hero = {
			start = 650,
			dur = 620,
			ease = "BackOut",
			fromScale = 0.2,
			fromRotation = -10,
			idleFloat = 4,
			idleRadPerSec = 1.6,
		},
		flash = { peak = 820, halfWidth = 260, maxOpacity = 0.85 },
		sparks = { start = 800, dur = 650, count = 12, radius = { 120, 190 } },
		confetti = {
			start = 900,
			count = 38,
			staggerMax = 1800,
			fallPxPerSec = { 90, 170 },
			sway = { 10, 32 },
		},
		panel = { start = 1150, dur = 450, ease = "CubicOut", fromOffsetY = 60 },
		rows = {
			start = 1400,
			stagger = 170,
			dur = 340,
			fromOffsetX = -40,
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
		home = { start = 3000, dur = 320, ease = "CubicOut", fromOffsetY = 20 },
	},
	defeat = {
		banner = { start = 100, dur = 420, ease = "CubicIn", fromScale = 2.3, fromRotation = -4 },
		shake = { start = 520, dur = 430, amplitude = 9 },
		sub = { start = 680, dur = 400, ease = "BackOut", fromScale = 0 },
		hero = {
			start = 780,
			dur = 520,
			ease = "BackOut",
			fromOffsetY = -140,
			fromRotation = 8,
			idleFloat = 3,
			idleRadPerSec = 1.3,
		},
		glow = { start = 900, dur = 500, pulseRadPerSec = 3 },
		vignette = { start = 500, dur = 600, opacity = { 0.22, 0.54 }, pulseRadPerSec = 2.5 },
		flash = { peak = 1200, halfWidth = 220, maxOpacity = 0.9 },
		rocks = { start = 1180, life = 1500, count = 9, gravityPxPerSec2 = 900 },
		embers = { start = 900, count = 20, risePxPerSec = { 35, 75 }, sway = { 8, 26 } },
		panel = { start = 1350, dur = 450, ease = "CubicOut", fromOffsetY = 60 },
		rows = {
			start = 1600,
			stagger = 170,
			dur = 340,
			fromOffsetX = -40,
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
		home = { start = 3400, dur = 320, ease = "CubicOut", fromOffsetY = 20 },
	},
}

return table.freeze(EndScreenTimeline)
