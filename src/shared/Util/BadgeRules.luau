--!strict
--[[
	Which boss badge a win has just earned (`Config/BossBadges`,
	`UI/BadgeCase`). Pure, so `tests/BossBadges.spec` can pin it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossBadges = require(ReplicatedStorage.Shared.Config.BossBadges)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local BadgeRules = {}

--[[
	The area whose badge a run's end earned, or nil: the run was won with a
	boss's item in it (`Remotes.RunSummary`'s `item`, only on a boss win),
	that boss had not been beaten when the player joined (`atJoin`, the
	first profile's `bossesBeaten`) and its badge has not been shown since
	(`shown`). Read off the win itself, not off the profile changing, so a
	boss marked beaten in the lobby (Studio's test unlock) never pops up.
]]
function BadgeRules.fromWin(
	won: boolean,
	item: string?,
	atJoin: { [string]: boolean },
	shown: { [string]: boolean }
): string?
	if not won or not item then
		return nil
	end
	local boss = Economy.items[item]
	if not boss or atJoin[boss.area] or shown[boss.area] then
		return nil
	end
	for _, badge in BossBadges.order do
		if badge.area == boss.area then
			return boss.area
		end
	end
	return nil
end

--[[ How many of the case's badges `beaten` has earned. ]]
function BadgeRules.count(beaten: { [string]: boolean }): number
	local count = 0
	for _, badge in BossBadges.order do
		if beaten[badge.area] then
			count += 1
		end
	end
	return count
end

return BadgeRules
