--!strict
--[[
	The one rule for first-time tips (`Config/Tips`): **a tip shows once
	ever.** Both sides ask here and nowhere else. The client asks `due`
	before it puts a tip up; the server keeps it with `mark` once it has
	been on screen (`Remotes.TipSeen`, `Data/Wallet.sawTip`). Pure, so
	`tests/Tips.spec` pins it.

	`seen` is the save's `tipsSeen` (a tip ever shown); `shown` is the
	client's own this visit, so a tip asked for twice before the server's
	answer comes back is still shown once.
]]

local PromptText = require(script.Parent.PromptText)
local Tips = require(script.Parent.Parent.Config.Tips)

local TipRules = {}

--[[ Whether `key` names a tip: what the server may keep. ]]
function TipRules.isTip(key: unknown): boolean
	return type(key) == "string" and Tips.tips[key] ~= nil
end

--[[ Whether tip `key` may show now: a tip, never seen, not shown yet. ]]
function TipRules.due(
	key: unknown,
	seen: { [string]: boolean }?,
	shown: { [string]: boolean }?
): boolean
	if not TipRules.isTip(key) then
		return false
	end
	local name = key :: string
	return (seen or {})[name] ~= true and (shown or {})[name] ~= true
end

--[[ Keeps tip `key` as seen in `seen`. True only when that is news: a tip
     not kept before. ]]
function TipRules.mark(seen: { [string]: boolean }, key: unknown): boolean
	if not TipRules.due(key, seen, nil) then
		return false
	end
	seen[key :: string] = true
	return true
end

--[[ The tip's words as read, its marks dropped. ]]
function TipRules.plain(key: string): string
	local tip = Tips.tips[key]
	return if tip then PromptText.plain(tip.text) else ""
end

export type Box = { x: number, y: number, w: number, h: number }

--[[ Where a tip's card goes, in screen points (owner, 2026-11-13: "they
     should be in the outer arena area so it doesnt block the arena"). ]]
TipRules.layout = {
	gutter = 16,
	-- under Roblox's top bar, clear of the run's XP bar and the lobby's pills
	below = 76,
	-- an upright card in a margin beside the arena, as wide as it allows
	sideMin = 190,
	sideMax = 300,
	sideHeight = 250,
	-- a wide card above or below the arena, or on a screen with no arena
	wideWidth = 520,
	wideHeight = 160,
}

export type Placement = {
	box: Box,
	--[[ Beside the arena: the upright card. ]]
	side: boolean,
}

--[[ Where a tip's card stands on a screen `w` x `h` points with `insetY` of
     Roblox's top bar, given the arena's box on that screen (nil in the
     lobby, or on a screen with nothing behind it to keep clear). Beside the
     arena in the wider side margin if a card fits there, which a landscape
     screen has; else in the space above or below it, which an upright phone
     has; else where the most of it shows, overlapping its edge. With no
     arena, centred under the top HUD. Always whole on the screen. ]]
function TipRules.place(w: number, h: number, insetY: number, arena: Box?): Placement
	local layout = TipRules.layout
	local g = layout.gutter
	local top = insetY + layout.below
	local function onScreenY(y: number, height: number): number
		local lowest = math.max(0, h - height - g)
		return math.clamp(y, math.min(top, lowest), lowest)
	end
	local function wide(y: number): Placement
		local width = math.min(layout.wideWidth, w - g * 2)
		local height = layout.wideHeight
		return {
			box = {
				x = math.floor((w - width) / 2),
				y = math.floor(onScreenY(y, height)),
				w = width,
				h = height,
			},
			side = false,
		}
	end
	if not arena then
		return wide(top)
	end
	local left = arena.x
	local right = w - (arena.x + arena.w)
	local room = math.max(left, right) - g * 2
	if room >= layout.sideMin then
		local width = math.min(layout.sideMax, room)
		local height = math.min(layout.sideHeight, h - top - g)
		-- the right one unless the left is clearly wider: MENU is on the left edge
		local x = if right + layout.gutter >= left
			then arena.x + arena.w + (right - width) / 2
			else (left - width) / 2
		local y = top + (h - top - g - height) / 2
		return {
			box = { x = math.floor(x), y = math.floor(onScreenY(y, height)), w = width, h = height },
			side = true,
		}
	end
	local above = arena.y - top
	local under = h - g - (arena.y + arena.h)
	local height = layout.wideHeight
	if under >= height or (under >= above and above < height) then
		-- below the arena, centred in its space, or at the foot of the screen
		return wide(arena.y + arena.h + math.max(0, (under - height) / 2))
	end
	return wide(top + math.max(0, (above - height) / 2))
end

return TipRules
