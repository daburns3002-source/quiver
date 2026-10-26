--!strict
--[[
	The lobby (`Config/Lobby`, `Run/Lobby`; owner, 2026-10-25): its two
	working portals lead to Mossy Glade's and Thornwood's runs, the rest are
	locked, ten or more in two rows; the campfire spawn stands in the clearing clear of the stations;
	the stations stand apart (2026-10-26: the gear station "almost overlaps with the blacksmith");
	only a portal's mouth opens its screen, never the spawn or the lawn; and START on it is
	the server's to grant (`Lobby.startFor`): only that portal, only its levels, only while
	the player stands there.
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
			if portal.levels then
				t.isTrue(#portal.levels >= 1, `{portal.name}'s portal has no levels`)
				for _, index in portal.levels do
					local stage = Balance.Stages[index]
					t.notNil(stage, `{portal.name}'s portal names a stage that does not exist`)
					t.equal(stage.mode, "Rooms")
					t.isTrue(not stage.tutorial, `{portal.name}'s portal plays the tutorial`)
				end
				t.isTrue(
					#portal.levels <= LobbyConfig.levelSlots,
					`{portal.name} has more levels than its screen has slots`
				)
				table.insert(open, portal.name)
			end
		end
		t.equal(table.concat(open, ","), "Mossy Glade,Thornwood")
	end)

	t.test("at least ten portals, in two rows, every mouth on the lawn", function()
		t.isTrue(#LobbyConfig.portals >= 10, "fewer than ten portals")
		t.equal(Lobby.rowOf(#LobbyConfig.portals), 2)
		local half = LobbyConfig.size / 2
		for index in LobbyConfig.portals do
			local at = Lobby.archAt(index)
			t.isTrue(
				math.abs(at.X) < half.X and math.abs(at.Y) < half.Y,
				`portal {index} stands outside the clearing`
			)
			for other in LobbyConfig.portals do
				if other ~= index then
					t.isTrue(
						(Lobby.archAt(other) - at).Magnitude > LobbyConfig.portalReach * 2,
						`portals {index} and {other} overlap`
					)
				end
			end
		end
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

	t.test("every station's footprint stands clear of every other's", function()
		local GAP = 6
		local placed = {}
		for _, station in LobbyConfig.stations do
			local spec = LobbyConfig.pieces[station.piece]
			if spec then
				local size = spec.size * LobbyConfig.scale
				table.insert(placed, { name = station.piece, at = station.at, size = size })
			end
		end
		for i, a in placed do
			for j = i + 1, #placed do
				local b = placed[j]
				-- apart along X or along Z, by at least GAP studs
				local apartX = math.abs(a.at.X - b.at.X) - (a.size.X + b.size.X) / 2
				local apartZ = math.abs(a.at.Y - b.at.Y) - (a.size.Z + b.size.Z) / 2
				t.isTrue(
					math.max(apartX, apartZ) >= GAP,
					`the {a.name} and the {b.name} are {math.max(apartX, apartZ)} studs apart`
				)
			end
		end
	end)

	local origin = LobbyConfig.origin
	local function mouthOf(index: number, ahead: number?): Vector3
		local at = Lobby.archAt(index)
		return origin + Vector3.new(at.X, 3, at.Y + LobbyConfig.mouthAhead + (ahead or 0))
	end

	t.test("only a portal's mouth opens its screen", function()
		local spawn = origin + Vector3.new(LobbyConfig.spawn.X, 3, LobbyConfig.spawn.Y)
		t.isTrue(Lobby.portalAt(spawn) == nil, "the spawn is inside a portal")
		for index, portal in LobbyConfig.portals do
			local found = Lobby.portalAt(mouthOf(index))
			if portal.levels then
				t.equal(found, index)
			else
				t.isTrue(found == nil, `locked portal {index} opens a screen`)
			end
		end
	end)

	t.test("START is granted only at that portal, for one of its levels", function()
		local open: number? = nil
		local other: number? = nil
		for index, portal in LobbyConfig.portals do
			if portal.levels then
				if open == nil then
					open = index
				elseif other == nil then
					other = index
				end
			end
		end
		assert(open and other, "two working portals")
		local levels = LobbyConfig.portals[open].levels :: { number }
		local at = mouthOf(open)

		t.equal(Lobby.startFor(at, open, 1), levels[1])
		-- a moment's walk on since the screen opened still counts
		t.equal(Lobby.startFor(mouthOf(open, LobbyConfig.portalReach + 1), open, 1), levels[1])
		-- another portal, from here
		t.isTrue(Lobby.startFor(at, other, 1) == nil, "started a portal the player is not at")
		-- from across the lobby
		local spawn = origin + Vector3.new(LobbyConfig.spawn.X, 3, LobbyConfig.spawn.Y)
		t.isTrue(Lobby.startFor(spawn, open, 1) == nil, "started from the campfire")
		-- a level it does not have, or not a level at all
		t.isTrue(Lobby.startFor(at, open, #levels + 1) == nil, "started a locked level")
		t.isTrue(Lobby.startFor(at, open, 0) == nil, "started level 0")
		t.isTrue(Lobby.startFor(at, open, 1.5) == nil, "started level 1.5")
		t.isTrue(Lobby.startFor(at, open, "1") == nil, "started a string level")
		t.isTrue(Lobby.startFor(at, open, 0 / 0) == nil, "started a NaN level")
		t.isTrue(Lobby.startFor(at, tostring(open), 1) == nil, "started a string portal")
		t.isTrue(Lobby.startFor(at, 99, 1) == nil, "started a portal that does not exist")
		-- a locked arch, stood in front of
		for index, portal in LobbyConfig.portals do
			if not portal.levels then
				t.isTrue(Lobby.startFor(mouthOf(index), index, 1) == nil, `started locked {index}`)
			end
		end
	end)
end
