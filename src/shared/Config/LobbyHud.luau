--!strict
--[[
	The lobby HUD's sizes on a touch layout (a phone, or any screen held
	upright), in points (Fable's loop review item 3, owner-approved
	2026-11-11): PLAY across the bottom (`UI/LobbyHud`) and the station
	button just above it (`UI/StationScreen`), each a finger's target, the
	pair standing under the phone's JUMP button (`Input/LobbyButtons`, at
	`UI/HudLayout`'s lifted dash corner). `tests/LobbyHud.spec` pins both.
]]

local LobbyHud = {
	-- kept clear at the screen's edges
	gutter = 16,
	playHeight = 64,
	stationHeight = 60,
	-- between PLAY and the station button
	stackGap = 10,
	-- the widest a bar grows, on a phone held sideways
	barWidth = 520,
	-- the smallest a button may be for a finger
	minTouch = 56,
	--[[ The coin and gem pills' height, pinned to the top. ]]
	pillHeight = 44,
}

return table.freeze(LobbyHud)
