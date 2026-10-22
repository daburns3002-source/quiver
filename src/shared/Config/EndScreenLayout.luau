--!strict
--[[
	Where everything on the end screens sits, in design pixels from the top
	left of the 540 × 624 panel (design_handoff_end_screens, Layout.luau).
	Each box is { x, y, w, h }.
]]

local EndScreenLayout = {
	--[[ The whole ribbon: tails at x 0 and 386 (y 34, 90 × 54 with their
	     outline), the band between x 57 and 413 at y 9, 70 tall. ]]
	banner = { x = 35, y = 12, w = 470, h = 96 },
	sub = { x = 140, y = 86, w = 260, h = 40 },
	subDefeat = { x = 120, y = 86, w = 300, h = 40 },
	rays = { x = 270 - 380, y = 196 - 380, w = 760, h = 760 },
	heroVictory = { x = 270 - 165, y = 190 - 78, w = 330, h = 157 },
	heroDefeat = { x = 270 - 168, y = 194 - 76, w = 336, h = 153 },
	panel = { x = 52, y = 280, w = 436, h = 226 },
	levelTab = { x = 52 + 218 - 140, y = 280 - 22, w = 280, h = 44 },
	--[[ First row's top left, inside the stats panel. ]]
	rowsOrigin = Vector2.new(12, 32),
	rowWidth = 412,
	--[[ Inside the stats panel. ]]
	rewards = { x = 12, y = 152, w = 412, h = 58 },
	rewardsTab = { x = 12 + 206 - 65, y = 152 - 14, w = 130, h = 24 },
	button = { x = 95, y = 516, w = 350, h = 60 },
	home = { x = 180, y = 588, w = 180, h = 30 },
}

return table.freeze(EndScreenLayout)
