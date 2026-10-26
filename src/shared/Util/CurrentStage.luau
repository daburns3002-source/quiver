--!strict
--[[
	Which stage the run is playing (`Balance.Stages`), read the same on both
	sides. The server's `RoomController` decides it, moving along
	`Balance.campaign` as each stage is won, and publishes it as the `Stage`
	attribute on Workspace; until it has, it is `Balance.stage`.

	`nextAfter` is pure, so `tests/Campaign.spec` pins the order.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local CurrentStage = {}

CurrentStage.ATTRIBUTE = "Stage"

function CurrentStage.index(): number
	local published = Workspace:GetAttribute(CurrentStage.ATTRIBUTE)
	if type(published) == "number" and Balance.Stages[published] then
		return published
	end
	return Balance.stage
end

function CurrentStage.config(): Balance.StageConfig
	return Balance.Stages[CurrentStage.index()]
end

--[[ The stage after `current` is won: the next one in `campaign`, or the
     last one again once the campaign is through (there is nothing past it
     yet). A stage that is not in the campaign is played again. ]]
function CurrentStage.nextAfter(campaign: { number }, current: number): number
	for position, index in campaign do
		if index == current then
			return campaign[math.min(position + 1, #campaign)]
		end
	end
	return current
end

return CurrentStage
