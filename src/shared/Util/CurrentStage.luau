--!strict
--[[
	Which stage the run is playing (`Balance.Stages`), read the same on both
	sides. The server's `RoomController` decides it, moving along
	`Balance.campaign` as each stage is won, and publishes it as the `Stage`
	attribute on Workspace; until it has, it is `Balance.stage`.

	An Endless run also publishes the floor it is on (`FLOOR_ATTRIBUTE`),
	for the same reason: the enemies need the floor's curve
	(`Enemies/EnemyManager`) and the client needs to draw it, and neither
	should be told by the other. The server sets it and nothing else does
	(non-negotiable 2: a client that could claim a floor could claim a
	Mythic).

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

--[[ The floor an Endless run is on, published by `Run/RoomController`. ]]
CurrentStage.FLOOR_ATTRIBUTE = "EndlessFloor"

--[[ Which floor the run is on, or nil when it is not an Endless run: a
     whole floor between 1 and the hard cap, so a missing or nonsense
     attribute reads as "not Endless" rather than as floor 0. ]]
function CurrentStage.endlessFloor(): number?
	if CurrentStage.config().mode ~= "Endless" then
		return nil
	end
	local published = Workspace:GetAttribute(CurrentStage.FLOOR_ATTRIBUTE)
	if type(published) ~= "number" or published ~= published then
		return nil
	end
	local floor = math.floor(published)
	if floor < 1 or floor > Balance.Endless.maxFloor then
		return nil
	end
	return floor
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
