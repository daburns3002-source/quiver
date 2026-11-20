--!strict
--[[
	Where a tip or a tutorial prompt stands during a run: outside the arena,
	in what the run camera shows round it (owner, 2026-11-19: "the tutorial
	tips need to be on the outer arena so they do not block the arena").
	Pure, in screen points, so `tests/ArenaMargin.spec` holds it for every
	screen shape: Studio cannot be a phone over MCP.

	The arena reaches the screen as a trapezoid. The run camera looks down
	the room's length and never moves sideways (`Camera/TopDownCamera`), so
	the side walls are two fixed lines, further apart at the foot of the
	screen, and only the end walls slide as it follows the player. So:

	- **Beside** the arena (`Right`, else `Left`): a landscape screen's
	  margin, where a card is measured against those two lines alone and
	  stays put for the whole run. The right one first: a computer's MENU is
	  on the left edge, and a phone's MENU icon and thumb are on the left.
	- **Above** or **below** it (`Above`, `Below`): an upright phone, whose
	  floor fills the width. The card rides on the end wall it stands by,
	  between the run's top HUD and its bottom one, and keeps its end until
	  the other one is clearly better (`SWITCH`), so it does not hop. Where
	  neither band holds it, it takes the one that covers the least of the
	  floor, over the end wall, never over a HUD piece.
]]

local ArenaMargin = {}

export type Point = { x: number, y: number }
export type Box = { x: number, y: number, w: number, h: number }
--[[ The arena's floor corners, walls included, where they stand on the
     screen: `far` is the room's north end, up the screen. ]]
export type Quad = {
	farLeft: Point,
	farRight: Point,
	nearLeft: Point,
	nearRight: Point,
}
export type Form = "Right" | "Left" | "Above" | "Below"
--[[ The screen: its size, the first row under Roblox's top bar, the run
     HUD's pieces a card must not cover, and where the player and the exit
     gate stand on it (a card above or below the arena keeps off them when
     it can). ]]
export type Screen = {
	w: number,
	h: number,
	top: number,
	hud: { Box },
	player: Point?,
	gate: Point?,
}
--[[ What is being placed: how wide a card beside the arena may be, how wide
     one above or below it, and how tall it comes out at a width. ]]
export type Want = {
	sideMin: number,
	sideMax: number,
	bandMax: number,
	height: (width: number, form: Form) -> number,
}
export type Spot = {
	box: Box,
	form: Form,
	--[[ Square points of the floor under it: 0 when it is clear. ]]
	covers: number,
}

--[[ Points kept between a card and the arena, a HUD piece or the screen's
     edge. ]]
ArenaMargin.GUTTER = 16
--[[ Points a card moves at a time looking for a clear place beside the
     arena. ]]
local STEP = 4
--[[ How much less of the floor the other band must cover, as a share of
     the card, before a card above or below the arena changes end. ]]
local SWITCH = 0.25
--[[ Rows of a card measured for how much of the floor it covers. ]]
local SAMPLES = 6

--[[ Where the line through `a` and `b` crosses screen row `y`, extended past
     both. ]]
local function lineX(a: Point, b: Point, y: number): number
	local dy = b.y - a.y
	if math.abs(dy) < 1e-6 then
		return if y < a.y then a.x else b.x
	end
	return a.x + (b.x - a.x) * (y - a.y) / dy
end

local function apart(a: Box, b: Box): boolean
	return a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y
end

local function hudCovered(box: Box, screen: Screen): number
	local total = 0
	for _, piece in screen.hud do
		if not apart(box, piece) then
			local w = math.min(box.x + box.w, piece.x + piece.w) - math.max(box.x, piece.x)
			local h = math.min(box.y + box.h, piece.y + piece.h) - math.max(box.y, piece.y)
			total += math.max(0, w) * math.max(0, h)
		end
	end
	return total
end

--[[ Square points of the floor `box` covers. With `sides` the arena is the
     strip between its side lines, top to bottom of the screen (what a card
     beside it is measured against, so it stays put as the end walls move);
     else only the rows between its end walls. ]]
function ArenaMargin.covers(box: Box, arena: Quad, sides: boolean?): number
	local y0, y1 = box.y, box.y + box.h
	if not sides then
		local far = math.min(arena.farLeft.y, arena.farRight.y)
		local near = math.max(arena.nearLeft.y, arena.nearRight.y)
		y0, y1 = math.max(y0, far), math.min(y1, near)
	end
	if y1 <= y0 then
		return 0
	end
	local total = 0
	local rows = y1 - y0
	for i = 0, SAMPLES - 1 do
		local y = y0 + rows * (i + 0.5) / SAMPLES
		local left = lineX(arena.farLeft, arena.nearLeft, y)
		local right = lineX(arena.farRight, arena.nearRight, y)
		total += math.max(0, math.min(box.x + box.w, right) - math.max(box.x, left))
	end
	return total * rows / SAMPLES
end

--[[ The widest the arena is across rows `y0` to `y1`, beside it: the side
     lines' furthest out over those rows. ]]
local function sideEdges(arena: Quad, y0: number, y1: number): (number, number)
	local left =
		math.min(lineX(arena.farLeft, arena.nearLeft, y0), lineX(arena.farLeft, arena.nearLeft, y1))
	local right = math.max(
		lineX(arena.farRight, arena.nearRight, y0),
		lineX(arena.farRight, arena.nearRight, y1)
	)
	return left, right
end

--[[ A card beside the arena on side `form`, or nil when none fits there:
     as wide as the margin allows up to `sideMax`, centred in it, as near
     the screen's middle row as it stands clear of the floor and the HUD. ]]
local function beside(screen: Screen, arena: Quad, want: Want, form: Form): Spot?
	local g = ArenaMargin.GUTTER
	local function margin(y0: number, y1: number): number
		local left, right = sideEdges(arena, y0, y1)
		return if form == "Right" then screen.w - right - g * 2 else left - g * 2
	end
	-- the widest it can be: up against the top, where the margin is widest
	local width =
		math.min(want.sideMax, margin(screen.top, screen.top + want.height(want.sideMax, form)))
	width = math.floor(width)
	--[[ Narrower words wrap to more lines and a taller card reaches lower,
	     where the margin is narrower: narrowed until the card at its own
	     height fits. ]]
	local height = want.height(width, form)
	for _ = 1, 8 do
		local room = math.floor(margin(screen.top, screen.top + height))
		if room >= width then
			break
		end
		width = room
		height = want.height(width, form)
	end
	if width < want.sideMin or margin(screen.top, screen.top + height) < width then
		return nil
	end
	local lowest = screen.h - g - height
	if lowest < screen.top then
		return nil
	end
	local function at(y: number): Box
		local left, right = sideEdges(arena, y, y + height)
		local x = if form == "Right"
			then right + g + (screen.w - right - g * 2 - width) / 2
			else g + (left - g * 2 - width) / 2
		return { x = math.floor(x), y = math.floor(y), w = width, h = height }
	end
	local middle = math.clamp((screen.top + screen.h) / 2 - height / 2, screen.top, lowest)
	-- outward from the middle row, a step at a time, the first clear place
	-- (the top and the foot themselves included, where a step would pass them)
	local reach = math.max(middle - screen.top, lowest - middle) + STEP
	for offset = 0, reach, STEP do
		for _, y in { math.max(middle - offset, screen.top), math.min(middle + offset, lowest) } do
			local box = at(y)
			if
				margin(y, y + height) >= width - 1e-6
				and hudCovered(box, screen) == 0
				and ArenaMargin.covers(box, arena, true) == 0
			then
				return { box = box, form = form, covers = 0 }
			end
		end
	end
	return nil
end

--[[ A card above or below the arena: on the end wall it stands by, kept
     on the screen and off the HUD, even where that takes it over the
     floor. ]]
local function band(screen: Screen, arena: Quad, want: Want, form: Form): Spot
	local g = ArenaMargin.GUTTER
	local width = math.floor(math.min(want.bandMax, screen.w - g * 2))
	local height = want.height(width, form)
	local x = math.floor((screen.w - width) / 2)
	local lowest = math.max(screen.top, screen.h - g - height)
	local y = if form == "Above"
		then math.min(arena.farLeft.y, arena.farRight.y) - g - height
		else math.max(arena.nearLeft.y, arena.nearRight.y) + g
	y = math.clamp(y, screen.top, lowest)
	--[[ Off each HUD piece it would sit on: under one in the screen's top
	     half (the top HUD, MENU), over one in its bottom half (the bars, the
	     dash button). ]]
	for _ = 1, #screen.hud + 1 do
		local moved = false
		for _, piece in screen.hud do
			if not apart({ x = x, y = y, w = width, h = height }, piece) then
				if piece.y + piece.h / 2 < screen.h / 2 then
					y = math.min(piece.y + piece.h + g, lowest)
				else
					y = math.max(piece.y - g - height, screen.top)
				end
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	local box = { x = x, y = math.floor(y), w = width, h = height }
	local covers = ArenaMargin.covers(box, arena)
	--[[ Never over the player when the other end will do, and then not over
	     the exit gate (where "ROOM CLEAR!" sends them): a card on the player
	     counts as covering the whole of itself twice more, on the gate once. ]]
	local function on(point: Point?): boolean
		return point ~= nil
			and point.x >= box.x
			and point.x <= box.x + box.w
			and point.y >= box.y - g
			and point.y <= box.y + box.h + g
	end
	if on(screen.player) then
		covers += box.w * box.h * 2
	end
	if on(screen.gate) then
		covers += box.w * box.h
	end
	return { box = box, form = form, covers = covers }
end

--[[ Where a card stands on `screen` with the arena at `arena`: beside it if
     it fits there, else above or below it. `last` is the form it had a
     moment ago, so a card above or below keeps its end while the other is
     only a little better. ]]
function ArenaMargin.place(screen: Screen, arena: Quad, want: Want, last: Form?): Spot
	local right = beside(screen, arena, want, "Right")
	if right then
		return right
	end
	local left = beside(screen, arena, want, "Left")
	if left then
		return left
	end
	local above = band(screen, arena, want, "Above")
	local below = band(screen, arena, want, "Below")
	local area = above.box.w * above.box.h
	local slack = area * SWITCH
	if last == "Above" then
		return if below.covers + slack < above.covers then below else above
	elseif last == "Below" then
		return if above.covers + slack < below.covers then above else below
	end
	return if above.covers < below.covers then above else below
end

--[[ The arena's floor where a camera shows it: its four corners on the
     screen, from `project` (a world point to a screen point). `half` is
     half the floor's size with the walls, X across and Z along. ]]
function ArenaMargin.quad(
	halfX: number,
	halfZ: number,
	project: (x: number, z: number) -> Point
): Quad
	return {
		farLeft = project(-halfX, -halfZ),
		farRight = project(halfX, -halfZ),
		nearLeft = project(-halfX, halfZ),
		nearRight = project(halfX, halfZ),
	}
end

return table.freeze(ArenaMargin)
