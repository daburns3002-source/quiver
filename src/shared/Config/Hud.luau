--!strict
--[[
	Where the fight's HUD sits at the bottom of the screen: the health and
	dash bars and the skill bar, per device and, on a phone, per way it is
	held (owner, 2026-10-22: "make the phone UI bigger"). Pixels are screen
	points; `client/UI/HudLayout` turns these into positions for the
	screen's actual size.

	A computer stacks them in the bottom centre: the skill bar, then health,
	then dash.

	A phone held sideways has too little height for that stack at a size a
	thumb can read — it would take over a third of the screen — so it puts
	them in one row: health and dash on the left, a larger skill bar on the
	right, clear of the dash button in the corner.

	A phone held upright has height and no width: the stack again, at the
	bottom of the screen in the room left of the dash button.
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
	phoneSideways = {
		-- ~77 points tall (86 full), against 62 before.
		skillBarScale = 0.9,
		skillBarBottom = 10,
		--[[ The skill bar's centre, right of the screen's: room for the
		     health and dash bars to its left. ]]
		skillBarShiftX = 130,
		--[[ The health and dash block: its right edge this far left of the
		     screen's centre, and its width. ]]
		barsRight = -36,
		barsWidth = 240,
		healthHeight = 30,
		dashHeight = 16,
		barsGap = 6,
		-- Lifts the block to sit level with the middle of the skill bar.
		barsBottom = 22,
	},
	phoneUpright = {
		-- As large as sideways, unless the screen is too narrow for it.
		skillBarScale = 0.9,
		--[[ At the bottom of the screen (owner, 2026-10-22: "on mobile the
		     upgrade bar needs to be lower like near the bottom"), beside the
		     dash button rather than above it. Was 128. ]]
		skillBarBottom = 10,
		-- Points kept clear at each side of the screen.
		edge = 12,
		--[[ Points kept clear at the right for the dash button: 92 wide,
		     28 from the edge, and a gap. ]]
		dashClear = 128,
		barsWidth = 300,
		healthHeight = 30,
		dashHeight = 16,
		barsGap = 6,
	},
	--[[ The skill bar's full width and height on a touch screen: six 44-point
	     slots, 10 apart, 14 of padding a side; 44 + 18 + 24 tall. ]]
	touchTray = Vector2.new(342, 86),
}

return table.freeze(Hud)
