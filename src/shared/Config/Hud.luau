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
	--[[ How tall the numbers on the health and dash bars stand against
	     their bar, centred on it and outlined: the blocky font (CLAUDE.md
	     rule 11) is unreadable squeezed inside a bar's own height (owner,
	     2026-10-24: "make the small HUD labels … bigger"). ]]
	barText = { health = 1.6, dash = 2.6 },
	--[[ The "+N" a heart puts up on the health bar (owner, 2026-10-26:
	     "add heal number to the health bar whenever you pick up a heart"):
	     green, `height` bar heights tall, at `x` across the bar (its empty
	     right end, clear of the centred numbers and of the DASH label above),
	     rising `rise` bar heights over `seconds` and fading as it goes. ]]
	healNumber = {
		colour = Color3.fromRGB(140, 255, 140),
		edge = Color3.fromRGB(16, 48, 20),
		edgeWidth = 2.5,
		height = 2,
		x = 0.87,
		rise = 1.1,
		seconds = 0.9,
	},
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
		--[[ The lobby's JUMP and SPRINT, which stand where the dash button
		     does (`Input/LobbyButtons`). They were the dash button's own 92
		     and 76, and two square buttons stacked came to 182 points of a
		     phone's height — a fifth of the screen (owner, 2026-10-27: "the
		     lobby sprint and jump buttons are too big"). At 72 and 60 the
		     stack is 144, and both stay well clear of the 44-point floor a
		     thumb needs: JUMP is smaller than the dash button it replaces,
		     and SPRINT, pressed once in a while rather than in a fight, is
		     smaller again. ]]
		lobbyJumpSize = 72,
		lobbySprintSize = 60,
		lobbyGap = 12,
	},
	--[[ The skill bar's full width and height on a touch screen: six 44-point
	     slots, 10 apart, 14 of padding a side; 44 + 18 + 24 tall. ]]
	touchTray = Vector2.new(342, 86),
	--[[
		The run's top HUD (`UI/RunBanner`, placed by `Util/RunHudRules.top`):
		the level badge on a thick XP bar, the coins, the room pips and the
		line that says what the run wants next. It replaced a placeholder
		whose room line came to about 11 points on a phone over a 6-pixel XP
		bar (the 2026-11-11 loop and UI review).

		It hangs `gap` under Roblox's own top bar. On a phone the MENU icon
		(`UI/ControlMenu`) stands at its left, `menuIcon` square and `edge`
		from the screen's side, a thumb's 48 points and out of the way of
		the thumb that moves; the HUD takes the rest of the row, up to
		`phoneMax` wide, centred when the screen is wider than that. A
		computer centres it at `desktopShare` of the screen, between
		`desktopMin` and `desktopMax`.
	]]
	top = {
		gap = 6,
		edge = 8,
		menuIcon = 48,
		phoneMax = 460,
		desktopShare = 0.3,
		desktopMin = 420,
		desktopMax = 620,
		--[[ The XP row: the bar's height, the badge square that overlaps
		     its left end, and the coin pill at its right. ]]
		xpHeight = 18,
		badge = 34,
		coinHeight = 28,
		coinWidth = 104,
		--[[ The room row and the status line under it, and the space
		     between rows. ]]
		roomHeight = 18,
		statusHeight = 20,
		rowGap = 4,
		--[[ Rooms drawn as pips. A stage with more than this many (the
		     twenty and forty-room areas, Endless) keeps the counter and
		     adds the room's name where the pips would be. ]]
		maxPips = 12,
		--[[ The MENU panel on a phone: this wide at most, `panelMargin`
		     clear of the screen's sides, `panelShape` as tall as it is
		     wide. ]]
		panelWidth = 440,
		panelMargin = 16,
		panelShape = 0.62,
	},
	--[[
		The draft on a phone held upright (`UI/Cards/DraftScreen`). The hand
		is fitted to the screen's width, which left Choose! and Reroll about
		87 x 27 points and half the screen empty (the 2026-11-11 review).
		Now a tray stands under the panel: a box that reads out the selected
		card in large words, and under it REROLL and CHOOSE! as the chunky
		UI's fat buttons, across the whole width.

		The tray is a `UI/Chunky` sheet `sheet` pixels in size, two to a
		screen point on the narrowest phone, scaled as one piece to the
		screen's width less `margin` a side and never wider than `maxWidth`
		points: the box is its top `wordsHeight`, the buttons its bottom
		`buttonsHeight` (56 points on a 390-point phone), REROLL
		`rerollWidth` wide with `gap` between the two. `rowGap` points keep
		the tray off the panel, and `wordsSize` and `titleSize` are the
		tallest the box's words and the card's name are drawn, in points.
	]]
	draftUpright = {
		margin = 8,
		maxWidth = 460,
		sheet = Vector2.new(748, 340),
		wordsHeight = 208,
		buttonsHeight = 112,
		rerollWidth = 296,
		gap = 20,
		rowGap = 10,
		wordsSize = 18,
		titleSize = 22,
	},
}

return table.freeze(Hud)
