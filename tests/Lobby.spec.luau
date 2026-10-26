--!strict
--[[
	The lobby (`Config/Lobby`, `Run/Lobby`; owner, 2026-10-25): its two
	working portals lead to Mossy Glade's and Thornwood's runs, the rest are
	locked; the campfire spawn stands in the clearing clear of the stations;
	and only a portal's mouth starts a run, never the spawn or the lawn.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Lobby = require(ServerScriptService.Server.Run.Lobby)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("the two working portals are Mossy Glade and Thornwood, the rest locked", function()
		local open = {}
		for _, portal in LobbyConfig.portals do
			if portal.stage then
				local stage = Balance.Stages[portal.stage]
				t.notNil(stage, `{portal.name}'s portal names a stage that does not exist`)
				t.equal(stage.mode, "Rooms")
				table.insert(open, portal.name)
			end
		end
		t.equal(table.concat(open, ","), "Mossy Glade,Thornwood")
	end)

	t.test("the spawn is in the clearing, clear of every station", function()
		local half = LobbyConfig.size / 2
		local spawn = LobbyConfig.spawn
		t.isTrue(math.abs(spawn.X) < half.X and math.abs(spawn.Y) < half.Y, "the spawn is outside")
		for _, station in LobbyConfig.stations do
			t.isTrue(
				(station.at - spawn).Magnitude >= 10,
				`the spawn stands on the {station.piece}`
			)
		end
	end)

	t.test("only a portal's mouth starts a run", function()
		local origin = LobbyConfig.origin
		local spawn = origin + Vector3.new(LobbyConfig.spawn.X, 3, LobbyConfig.spawn.Y)
		t.isTrue(Lobby.portalFor(spawn) == nil, "the spawn is inside a portal")
		for index, portal in LobbyConfig.portals do
			local at = Lobby.archAt(index)
			local mouth = origin + Vector3.new(at.X, 3, at.Y + 2)
			t.equal(Lobby.portalFor(mouth), portal.stage)
		end
	end)
end
