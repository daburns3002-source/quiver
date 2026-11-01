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
	--[[ The Dex Hall's two books are the only imported models in the lobby
	     (`Config/Lobby.dex`), so they are the only places an asset id can
	     be wrong and leave a hole where a book should be. ]]
	t.test("the Dex Hall's books name real assets and keep their own shape", function()
		local dex = LobbyConfig.dex
		for _, book in { dex.roofBook, dex.standBook } do
			t.isTrue(book.mesh:match("^rbxassetid://%d+$") ~= nil, book.mesh)
			t.isTrue(book.texture:match("^rbxassetid://%d+$") ~= nil, book.texture)
			--[[ The scale comes off `across` over the import's own width,
			     so a native size of nought would divide by zero and a
			     book would come out infinitely large. ]]
			t.isTrue(book.native.X > 0 and book.native.Y > 0 and book.native.Z > 0, book.mesh)
			t.isTrue(book.across > 0, book.mesh)
		end
		t.isTrue(dex.roofBook.mesh ~= dex.standBook.mesh, "two different books")
	end)

	--[[ The roof book stands astride the ridge of the hall it belongs to,
	     not floating over the lawn: drawn wider than the building it would
	     hang past the eaves. ]]
	t.test("the roof book fits across its own roof", function()
		local hall = LobbyConfig.buildings.DexHall
		t.isTrue(LobbyConfig.dex.roofBook.across < hall.size.X, "wider than the hall")
		t.isTrue(LobbyConfig.dex.roofBook.across > hall.size.X / 4, "lost on the roof")
	end)

	--[[ The lecterns stand out front, clear of the steps and of each
	     other, and inside the hall's own width so they read as its pair. ]]
	t.test("the lecterns flank the steps without meeting them", function()
		local dex = LobbyConfig.dex
		local hall = LobbyConfig.buildings.DexHall
		local gap = dex.lectern.out * 2 - dex.lectern.base.X
		t.isTrue(gap > dex.carpet.X, "the carpet runs between them")
		t.isTrue(dex.lectern.out * 2 + dex.lectern.base.X <= hall.size.X + 6, "wider than the hall")
		t.isTrue(dex.lectern.forward > 0, "in front")
	end)

	t.test("the working portals are Mossy Glade, Thornwood and Endless", function()
		local open = {}
		for _, portal in LobbyConfig.portals do
			if portal.levels then
				t.isTrue(#portal.levels >= 1, `{portal.name}'s portal has no levels`)
				for _, index in portal.levels do
					local stage = Balance.Stages[index]
					t.notNil(stage, `{portal.name}'s portal names a stage that does not exist`)
					t.isTrue(not stage.tutorial, `{portal.name}'s portal plays the tutorial`)
				end
				-- more than the cards hold are a grid, its rows full but the last
				if #portal.levels > LobbyConfig.levelSlots then
					t.isTrue(LobbyConfig.levelColumns >= 1, "a grid needs columns")
				end
				table.insert(open, portal.name)
			end
		end
		t.equal(table.concat(open, ","), "Mossy Glade,Thornwood,Endless")
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
			local spec = LobbyConfig.buildings[station.piece]
			if spec then
				-- the foundation reaches a stud past the walls
				local size = spec.size + Vector3.new(2, 0, 2)
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

	t.test("every egg and crate stand keeps clear of every building", function()
		for owner, spots in LobbyConfig.stands do
			local home, found = Vector2.zero, false
			for _, station in LobbyConfig.stations do
				if station.piece == owner then
					home, found = station.at, true
				end
			end
			t.isTrue(found, `the {owner}'s stands have no station`)
			for _, spot in spots do
				local at = home + spot.at
				local reach = LobbyConfig.standSize / 2
				for _, station in LobbyConfig.stations do
					local spec = LobbyConfig.buildings[station.piece]
					if spec then
						local apartX = math.abs(at.X - station.at.X) - spec.size.X / 2 - 1 - reach
						local apartZ = math.abs(at.Y - station.at.Y) - spec.size.Z / 2 - 1 - reach
						t.isTrue(
							math.max(apartX, apartZ) >= 0,
							`the {spot.key} stand stands in the {station.piece}`
						)
					end
				end
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

	t.test("Mossy Glade's portal holds its ten levels, two rows of five", function()
		local glade = LobbyConfig.portals[1]
		t.equal(glade.name, "Mossy Glade")
		local levels = glade.levels :: { number }
		t.equal(#levels, 10)
		t.equal(LobbyConfig.levelColumns, 5)
		t.isTrue(#levels > LobbyConfig.levelSlots, "Mossy Glade's ten are not a grid")
		for position, index in levels do
			t.equal(Balance.Stages[index].level, `1-{position}`)
		end
	end)

	--[[ Endless is its own arch, open to everyone while the game is in
	     playtest (owner, 2026-10-28). Before launch it takes `requires =
	     "1-10"` back and this test flips with it (`docs/ENDLESS.md`: with
	     no cards and no gear it is a death at floor 6). The server is the
	     one that decides, so this goes through `Lobby.startFor` rather
	     than the screen. ]]
	t.test("Endless is open in playtest, and only from its own mouth", function()
		local index, portal = nil, nil
		for i, p in LobbyConfig.portals do
			if p.name == "Endless" then
				index, portal = i, p
			end
		end
		assert(index and portal, "no Endless portal")
		t.equal(portal.requires, nil)
		local levels = portal.levels :: { number }
		t.equal(#levels, 1)
		t.equal(Balance.Stages[levels[1]].mode, "Endless")

		local at = mouthOf(index)
		t.equal(Lobby.startFor(at, index, 1, nil), levels[1])
		t.equal(Lobby.startFor(at, index, 1, { ["1-1"] = true }), levels[1])
		t.equal(Lobby.startFor(at, index, 1, { ["1-10"] = true }), levels[1])
		-- and still only from its own mouth
		local spawn = origin + Vector3.new(LobbyConfig.spawn.X, 3, LobbyConfig.spawn.Y)
		t.isTrue(Lobby.startFor(spawn, index, 1, nil) == nil, "Endless started from the campfire")
	end)

	t.test("START is granted only for a level the player has opened", function()
		local glade = LobbyConfig.portals[1]
		local levels = glade.levels :: { number }
		local at = mouthOf(1)
		-- nothing beaten: 1-1 only
		t.equal(Lobby.startFor(at, 1, 1, {}), levels[1])
		t.equal(Lobby.startFor(at, 1, 1, nil), levels[1])
		t.isTrue(Lobby.startFor(at, 1, 2, {}) == nil, "started 1-2 with 1-1 unbeaten")
		t.isTrue(Lobby.startFor(at, 1, 10, nil) == nil, "started 1-10 with nothing beaten")
		-- 1-1 to 1-3 beaten: up to 1-4
		local beaten = { ["1-1"] = true, ["1-2"] = true, ["1-3"] = true }
		t.equal(Lobby.startFor(at, 1, 4, beaten), levels[4])
		t.equal(Lobby.startFor(at, 1, 2, beaten), levels[2])
		t.isTrue(Lobby.startFor(at, 1, 5, beaten) == nil, "started 1-5 with 1-4 unbeaten")
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
