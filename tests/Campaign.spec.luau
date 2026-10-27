--!strict
--[[
	The order the stages are played in (`Balance.campaign`,
	`Util/CurrentStage.nextAfter`): Mossy Glade 1-1..1-10, then Thornwood,
	and the last one again once the campaign is through. Each area ends in
	its boss alone: King Bloblin is 1-10's last wave (owner, 2026-10-26), the
	Broodmother Thornwood's last room.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local CurrentStage = require(ReplicatedStorage.Shared.Util.CurrentStage)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local TestRunner = require(script.Parent.TestRunner)
local Waves = require(ServerScriptService.Server.Run.Waves)

--[[ The last fight of a stage: its last room's, or its last wave's. ]]
local function lastFight(stage: Balance.StageConfig): (number, { Balance.EnemyConfig })
	if stage.mode == "Waves" then
		local total = stage.waves or 0
		local wave = Waves.describe(total, total, stage)
		return wave.count, wave.roster
	end
	local rooms = stage.rooms or {}
	local last = Balance.Rooms[rooms[#rooms]]
	return last.enemyCount, last.roster
end

return function(t: TestRunner.Helper)
	t.test("the first run is the campaign's first stage", function()
		t.equal(Balance.stage, Balance.campaign[1])
	end)

	t.test("every campaign stage exists, and each area's last ends in its boss alone", function()
		for position, index in Balance.campaign do
			local stage = Balance.Stages[index]
			t.notNil(stage, `stage {index}`)
			local after = Balance.Stages[Balance.campaign[position + 1]]
			if not after or after.area ~= stage.area then
				local count, roster = lastFight(stage)
				t.equal(count, 1, `{stage.name} ends in one enemy`)
				t.isTrue(roster[1].boss ~= nil, `{stage.name} ends in its boss`)
			end
		end
	end)

	t.test("winning moves along the campaign, and the last is played again", function()
		local campaign = { 5, 4 }
		t.equal(CurrentStage.nextAfter(campaign, 5), 4)
		t.equal(CurrentStage.nextAfter(campaign, 4), 4)
		-- a stage outside it is played again
		t.equal(CurrentStage.nextAfter(campaign, 3), 3)
	end)

	t.test("Mossy Glade's ten levels, in its portal's order, then Thornwood", function()
		local glade = LobbyConfig.portals[1].levels :: { number }
		for position, index in glade do
			t.equal(Balance.campaign[position], index)
			t.equal(Balance.Stages[index].area, "MossyGlade")
		end
		local last = Balance.Stages[Balance.campaign[#Balance.campaign]]
		t.equal(last.area, "Thornwood")
		t.equal(#Balance.campaign, #glade + 1)
	end)
end
