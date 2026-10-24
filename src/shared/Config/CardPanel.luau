--!strict
--[[
	The draft panel's look: 8c "Glow Recess" from the owner's draft panel
	design (Arrow Legends Card UI Exporter, owner chose 8c on 2026-10-24).

	The design draws it as a 500 x 400 SVG: a chamfered blue frame with a
	stepped bevel, a deep near-black recess inside it, a glowing line just
	inside the recess, and a glowing cube at each of the recess's corners.

	Measurements are design pixels taken from that SVG, and they are **edge
	insets, not fractions** — the design exports as a 9-slice, so the frame,
	the recess border and the cubes keep their size at any panel size and only
	the middle stretches. Keeping them as offsets here reproduces that.

	Pure data, no logic. The panel is built from this by `UI/Cards/DraftScreen`.
]]

export type Paint = { colour: Color3, transparency: number }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CardPanel = {
	--[[ The size the measurements below were taken at. Kept so a future
	     change can be checked against the design without re-deriving it. ]]
	designSize = Vector2.new(500, 400),

	colours = {
		--[[ The dark outline every piece is drawn against, the design's
		     #1b1b2b. The same ink the cards and buttons use. ]]
		ink = rgb(27, 27, 43),

		--[[ The frame's three faces, which together make the stepped bevel:
		     a light top face, a mid front face, and the darker base that
		     shows as the outer lip. ]]
		frameTop = rgb(134, 174, 245),
		frameFront = rgb(58, 111, 216),
		frameBase = rgb(29, 58, 138),

		--[[ The recess. Nearly black and distinctly blue, so the cards sit in
		     a hole rather than on a surface — that is the whole point of 8c. ]]
		recess = rgb(16, 19, 46),

		--[[ The glowing line inside the recess: a soft wide pass under a
		     crisp narrow one. Roblox UI has no blur, so the soft pass is a
		     second, thicker, mostly-transparent stroke. ]]
		glowSoft = rgb(95, 180, 255),
		glowCore = rgb(167, 214, 255),

		--[[ The corner cubes, lit like the icon tiles: bright top, mid left
		     face, shaded right face. ]]
		cubeTop = rgb(167, 214, 255),
		cubeLeft = rgb(95, 180, 255),
		cubeRight = rgb(62, 117, 166),

		--[[ The highlight streak along the top of the frame. ]]
		highlight = rgb(255, 255, 255),
	},

	--[[ How see-through each soft pass is. The design gives these as opacity,
	     so they are inverted here. ]]
	transparency = {
		-- design opacity 0.75
		glowSoft = 0.25,
		-- design opacity 0.8, spread over a thicker stroke in Roblox
		cubeGlow = 0.45,
		-- design opacity 0.55
		highlight = 0.45,
	},

	metrics = {
		--[[ The chamfer is three 8px steps in the design. A rounded corner of
		     that radius reads the same at the sizes the panel is actually
		     drawn, and Roblox has no cheap chamfer. ]]
		cornerRadius = 24,
		recessCornerRadius = 16,

		-- The dark outline around the frame.
		inkThickness = 6,
		-- The dark outline around the recess.
		recessInkThickness = 3,

		--[[ The frame's outer lip: how far the base shows below the front
		     face. The design offsets the front face down by 9px and ends it
		     13px short of the base. ]]
		bevelDrop = 9,
		baseLip = 13,

		--[[ The recess's inset from the panel's edge. Wider at the bottom,
		     where the design leaves room for the buttons' shadow. ]]
		recessInset = { left = 20, right = 20, top = 22, bottom = 26 },

		--[[ The glowing line's inset inside the recess. ]]
		glowInset = 10,
		glowSoftThickness = 5.2,
		glowCoreThickness = 2,

		--[[ The corner cubes sit centred on the recess's corners. ]]
		cubeSize = 14,
		cubeGlowThickness = 6,

		--[[ The highlight streak: its height, its inset from the top, and how
		     much of the panel's width it runs across. ]]
		highlightHeight = 6,
		highlightTop = 8,
		highlightWidthScale = 0.5,
	},
}

return table.freeze(CardPanel)
