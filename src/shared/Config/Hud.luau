--!strict
--[[
	Where the fight's HUD sits at the bottom of the screen: the health and
	dash bars and the skill bar, per device and, on a phone, per way it is
	held (owner, 2026-10-22: "make the phone UI bigger"). Pixels are screen
	points; `client/UI/HudLayout` turns these into positions for the
	screen's actual size.

	A computer stacks them in the bottom centre: the skill bar, then health,
	then dash.

	A phone, held either way, stacks them centred at the bottom of the
	screen too, larger, inside the phone's safe area; the dash button moves
	up above the stack when it would otherwise sit on it.
]]

local Hud = {
	desktop = {
		--[[ The skill bar's size against its full size under the draft:
		     ~62 points tall (104 full). ]]
		skillBarScale = 0.6,
		skillBarBottom = 16,
		barsWidthShare = 0.34,
		healthHeight = 22,
		dashHeight = 12,
		-- Above the skill bar's 16 + 62.
		healthBottom = 86,
		dashBottom = 114,
	},
	--[[ A phone, either way it is held (owner, 2026-10-22: "the health and
	     dash bar should be right above it and all of them should be
	     centered"): the skill bar centred at the bottom, health and dash
	     right above it, the dash button lifted clear when the stack would
	     reach under it. ]]
	phone = {
		-- ~77 points tall (86 full), unless the screen is too narrow.
		skillBarScale = 0.9,
		skillBarBottom = 10,
		-- Points kept clear at each side of the screen.
		edge = 12,
		barsWidth = 300,
		healthHeight = 30,
		dashHeight = 16,
		barsGap = 6,
		--[[ The dash button: 92 points, this far from the right and bottom
		     edges, or this far above the stack when the stack would reach
		     under it. ]]
		dashButtonSize = 92,
		dashButtonMargin = 28,
		dashButtonAboveStack = 14,
	},
	--[[ The skill bar's full width and height on a touch screen: six 44-point
	     slots, 10 apart, 14 of padding a side; 44 + 18 + 24 tall. ]]
	touchTray = Vector2.new(342, 86),
}

return table.freeze(Hud)
