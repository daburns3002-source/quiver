--!strict
--[[
	When Roblox's own favourite prompt is shown (`UI/FavouritePrompt`,
	`Data/Favourite`; owner, 2026-11-18): once ever, after a boss win (the
	player's first, for anyone who started after it was built), and never
	again. **No reward is attached**, and nothing on screen asks for it:
	Roblox's prompt is the whole of it. Pure, so `tests/FavouriteRules.spec`
	pins it.
]]

local FavouriteRules = {}

--[[ Owed after a boss win, until it has been asked once. ]]
function FavouriteRules.owed(asked: boolean, bossesBeaten: { [string]: boolean }): boolean
	return not asked and next(bossesBeaten) ~= nil
end

--[[ Whether the client may show it now: owed, in the lobby, and nothing
     else on screen (no end screen, story beat, reveal or menu). ]]
function FavouriteRules.ready(owed: boolean, inLobby: boolean, covered: boolean): boolean
	return owed and inLobby and not covered
end

return FavouriteRules
