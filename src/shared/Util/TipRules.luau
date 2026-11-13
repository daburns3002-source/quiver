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

--[[ Where a tip stands on a screen `w` x `h` points with `insetY` of
     Roblox's top bar: centred, under the run's top HUD, `gutter` clear of
     each side on a phone, no wider than `maxWidth`. ]]
TipRules.layout = {
	gutter = 16,
	maxWidth = 560,
	height = 84,
	-- under the top bar, clear of the run's XP bar and the lobby's pills
	below = 76,
}

function TipRules.place(w: number, h: number, insetY: number): Box
	local layout = TipRules.layout
	local width = math.min(layout.maxWidth, w - layout.gutter * 2)
	local height = layout.height
	local y = math.min(insetY + layout.below, math.max(0, h - height - layout.gutter))
	return { x = math.floor((w - width) / 2), y = y, w = width, h = height }
end

return TipRules
