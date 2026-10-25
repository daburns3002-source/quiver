--!strict
--[[
	The room sign (owner, 2026-10-24): as each room of a Rooms stage starts, a
	blocky sign saying which room it is comes out of the top of the exit
	door, hangs at the top of the screen, and goes back into the door. Drawn
	in squares, in the blocky design language (`Config/PixelFont`), by
	`UI/RoomSign`.
]]

local RoomSign = {
	--[[ Seconds: out of the door, hanging, back in. ]]
	outTime = 0.45,
	hold = 1.6,
	backTime = 0.35,
	--[[ Seconds after the room starts before it comes out. ]]
	delay = 0.25,
	--[[ Where it hangs: the top of its body, as a share of the screen's
	     height, centred across it. ]]
	hangY = 0.2,
	--[[ One pixel of the letters in screen pixels, as a share of the
	     screen's height, and the fewest and most it can be. ]]
	pixelShare = 0.0085,
	pixelMin = 4,
	pixelMax = 9,
	--[[ Pixels of body round the words, and the bevel's pixels. ]]
	padding = 3,
	bevel = 1,
	--[[ Its size as it leaves and re-enters the door. ]]
	startScale = 0.15,
	colors = {
		body = Color3.fromRGB(150, 156, 168),
		bodyTop = Color3.fromRGB(196, 200, 210),
		bodyBottom = Color3.fromRGB(98, 104, 118),
		outline = Color3.fromRGB(40, 44, 56),
		moss = Color3.fromRGB(104, 168, 64),
		mossTop = Color3.fromRGB(150, 206, 96),
		text = Color3.fromRGB(255, 244, 214),
		textShadow = Color3.fromRGB(58, 28, 86),
		--[[ The last room's number, the boss's. ]]
		bossText = Color3.fromRGB(255, 120, 96),
	},
}

return table.freeze(RoomSign)
