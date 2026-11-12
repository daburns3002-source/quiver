--!strict
--[[
	The arithmetic behind the run's top HUD, the MENU button and the draft's
	phone buttons (`Config/Hud` `top` and `draftUpright`), kept apart from the
	screens that draw them so it can be tested without a screen
	(`tests/RunHud.spec`). Screen points throughout.

	Presentation only: nothing here is told to the server.
]]

local Hud = require(script.Parent.Parent.Config.Hud)

local RunHudRules = {}

export type Box = { x: number, y: number, w: number, h: number }

export type Top = {
	--[[ The MENU icon, on a phone; nil on a computer, whose MENU button
	     keeps its place on the left edge. ]]
	menu: Box?,
	banner: Box,
	--[[ How much larger than its points the HUD is drawn: 1 on a phone,
	     more on a computer's big screen, where a point is small. The
	     banner's box is already that much larger. ]]
	scale: number,
	--[[ The MENU's confirm panel, centred and fitted to the screen. ]]
	panel: Box,
}

--[[ How much a panel `w` by `h` points is scaled to suit a screen: down to
     fit a small one with `margin` clear at each edge, up on a big one, to
     `Hud.top.panelGrow` at most. ]]
function RunHudRules.fit(view: Vector2, w: number, h: number, margin: number): number
	return math.max(
		0.2,
		math.min(Hud.top.panelGrow, (view.X - 2 * margin) / w, (view.Y - 2 * margin) / h)
	)
end

--[[ How tall the top HUD stands with its status line showing. ]]
function RunHudRules.height(): number
	local t = Hud.top
	return t.badge + t.rowGap + t.roomHeight + t.rowGap + t.statusHeight
end

--[[ Where the top HUD and the MENU icon go on a screen `view` points in
     size, whose Roblox top bar ends `topBar` points down. ]]
function RunHudRules.top(view: Vector2, phone: boolean, topBar: number): Top
	local t = Hud.top
	local y = topBar + t.gap
	local height = RunHudRules.height()
	local panelH = t.panelWidth * t.panelShape
	if not phone then
		--[[ A point is small on a big screen: the HUD grows with the
		     screen's height, from `desktopTall` up. ]]
		local scale = math.clamp(view.Y / t.desktopTall, 1, t.desktopGrow)
		local w = math.clamp(view.X * t.desktopShare, t.desktopMin, t.desktopMax) * scale
		w = math.min(w, view.X - 2 * t.edge)
		local grow = RunHudRules.fit(view, t.panelWidth, panelH, t.panelMargin)
		return {
			banner = { x = (view.X - w) / 2, y = y, w = w, h = height * scale },
			scale = scale,
			panel = {
				x = (view.X - t.panelWidth * grow) / 2,
				y = (view.Y - panelH * grow) / 2,
				w = t.panelWidth * grow,
				h = panelH * grow,
			},
		}
	end

	local left = t.edge + t.menuIcon + t.edge
	local room = view.X - left - t.edge
	local w = math.min(room, t.phoneMax)
	--[[ A phone held sideways has more width than the HUD wants: centred,
	     unless that would put it under the MENU icon. ]]
	local x = math.max(left, (view.X - w) / 2)
	local shrink = math.min(1, RunHudRules.fit(view, t.panelWidth, panelH, t.panelMargin))
	return {
		menu = { x = t.edge, y = y, w = t.menuIcon, h = t.menuIcon },
		banner = { x = x, y = y, w = w, h = height },
		scale = 1,
		panel = {
			x = (view.X - t.panelWidth * shrink) / 2,
			y = (view.Y - panelH * shrink) / 2,
			w = t.panelWidth * shrink,
			h = panelH * shrink,
		},
	}
end

export type Pips = {
	count: number,
	--[[ Rooms behind the player. ]]
	lit: number,
	--[[ The room being fought, or nil between rooms and after the last. ]]
	current: number?,
}

--[[ The stage's rooms as pips, or nil when there are too many to draw (or
     none): the counter says it then. A room is lit once it is cleared. ]]
function RunHudRules.pips(index: number, total: number, state: string): Pips?
	if total < 1 or total > Hud.top.maxPips then
		return nil
	end
	local at = math.clamp(index, 0, total)
	if state == "Fighting" or state == "Dead" then
		return { count = total, lit = math.max(0, at - 1), current = if at >= 1 then at else nil }
	end
	return { count = total, lit = at, current = nil }
end

--[[ "ROOM 4/10", "WAVE 2/5", "FLOOR 17/100". ]]
function RunHudRules.counter(index: number, total: number, unit: string?): string
	return `{string.upper(unit or "Room")} {index}/{total}`
end

export type Status = { words: string, tone: "Neutral" | "Good" | "Bad" }

--[[ What the run wants from the player next, under the room row. A death
     says only that: the end screen offers the retry, and nothing restarts
     by itself (it used to read "You died - restarting"). ]]
function RunHudRules.status(state: string, unit: string?): Status
	if state == "Cleared" then
		--[[ Only a Rooms stage has an exit; a Waves stage brings the next
		     wave to you. ]]
		return {
			words = if unit == "Wave"
				then "CLEARED! NEXT WAVE INCOMING"
				else "CLEARED! TAKE THE EXIT",
			tone = "Good",
		}
	elseif state == "Dead" then
		return { words = "DEFEATED", tone = "Bad" }
	elseif state == "Complete" then
		return { words = "RUN COMPLETE!", tone = "Good" }
	end
	return { words = "", tone = "Neutral" }
end

export type DraftTray = {
	--[[ The tray's size on screen, and how tall its two buttons stand. ]]
	width: number,
	height: number,
	buttonHeight: number,
}

--[[ The tray under the draft on a phone held upright, `viewWidth` points
     wide (`Config/Hud` `draftUpright`): scaled as one piece to the width. ]]
function RunHudRules.draftTray(viewWidth: number): DraftTray
	local d = Hud.draftUpright
	local width = math.max(1, math.min(viewWidth - 2 * d.margin, d.maxWidth))
	local unit = width / d.sheet.X
	return { width = width, height = d.sheet.Y * unit, buttonHeight = d.buttonsHeight * unit }
end

return RunHudRules
