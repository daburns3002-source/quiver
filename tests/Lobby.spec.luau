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
local BlacksmithDesign = require(ReplicatedStorage.Shared.Config.BlacksmithDesign)
local HatcheryDesign = require(ReplicatedStorage.Shared.Config.HatcheryDesign)
local Lobby = require(ServerScriptService.Server.Run.Lobby)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	--[[ The Dex Hall's three models are the only imported meshes in the
	     lobby (`Config/Lobby.dex`), so they are the only places an asset
	     id can be wrong and leave a hole where the hall should be. ]]
	--[[ Owner, 2026-11-01: a building to each corner, every one of them
	     facing the middle. Both halves matter -- a corner each is what
	     makes the lawn a circuit rather than a line, and facing the
	     middle is what makes the four read as one place. ]]
	t.test("the four stations stand one to a corner", function()
		local corners = {
			GearStation = Vector2.new(-1, -1),
			Blacksmith = Vector2.new(1, -1),
			DexHall = Vector2.new(-1, 1),
			EggHatchery = Vector2.new(1, 1),
		}
		local found = 0
		for _, station in LobbyConfig.stations do
			local want = corners[station.piece]
			if want then
				found += 1
				t.equal(math.sign(station.at.X), want.X, `{station.piece} east/west`)
				t.equal(math.sign(station.at.Y), want.Y, `{station.piece} north/south`)
			end
		end
		t.equal(found, 4, "all four placed")
	end)

	t.test("every building faces the middle", function()
		for _, station in LobbyConfig.stations do
			if not LobbyConfig.buildings[station.piece] then
				continue
			end
			local yaw = LobbyConfig.facing(station.at)
			--[[ Its front is local +Z, which a turn about Y sends to
			     (sin, cos). Pointed at the middle, that is the way from
			     the building to the origin. ]]
			local front = Vector2.new(math.sin(yaw), math.cos(yaw))
			local toMiddle = -station.at.Unit
			t.isTrue((front - toMiddle).Magnitude < 1e-4, station.piece)
		end
	end)

	--[[ An egg or crate stand sits in front of its station, and has to
	     stay in front of it now the station can be turned any way. ]]
	t.test("every stand stays out front of its own station, whichever corner it is on", function()
		for owner, spots in LobbyConfig.stands do
			local home: Vector2? = nil
			for _, station in LobbyConfig.stations do
				if station.piece == owner then
					home = station.at
				end
			end
			t.notNil(home, owner)
			if not home then
				continue
			end
			local yaw = LobbyConfig.facing(home)
			local front = Vector2.new(math.sin(yaw), math.cos(yaw))
			for _, spot in spots do
				local turned = LobbyConfig.turnedOffset(home, spot.at)
				--[[ Turning moves it, never stretches it. Vector2 holds
				     single-precision floats, so a 24-stud offset carries
				     a few millionths of slack. ]]
				t.isTrue(math.abs(turned.Magnitude - spot.at.Magnitude) < 1e-3, spot.key)
				--[[ And it lands on the side the building looks at. ]]
				t.isTrue(turned:Dot(front) > 0, `{spot.key} is behind the {owner}`)
			end
		end
	end)

	--[[ The Dex Hall is parts now, bar the two books the owner modelled,
	     so those two are the only places an asset id can be wrong and
	     leave a hole where a book should be. ]]
	t.test("the Dex Hall's two book imports name real meshes", function()
		local dex = LobbyConfig.dex
		local seen: { [string]: boolean } = {}
		local pieces: { LobbyConfig.DexPiece } = { dex.roofBook, dex.standBook }
		for _, piece in pieces do
			t.isTrue(piece.mesh:match("^rbxassetid://%d+$") ~= nil, piece.mesh)
			t.isTrue(piece.texture:match("^rbxassetid://%d+$") ~= nil, piece.texture)
			t.isTrue(not seen[piece.mesh], "each is its own mesh")
			seen[piece.mesh] = true
			--[[ The scale is `across` over the import's own width, so a
			     native size of nought would divide by zero. ]]
			t.isTrue(piece.native.X > 0 and piece.native.Y > 0 and piece.native.Z > 0, piece.mesh)
			t.isTrue(piece.across > 0, piece.mesh)
		end
	end)

	--[[ The book rests on the roof rather than floating over it: its own
	     box reaches down past its covers to the tip of the ribbon, so its
	     foot drops below the roof by more than nothing and less than the
	     whole building. ]]
	t.test("the roof book seats on the roof, over the hall it belongs to", function()
		local dex = LobbyConfig.dex
		t.isTrue(dex.roofBook.seat > 0, "floats over the roof")
		t.isTrue(dex.roofBook.seat < dex.hall.ridge, "sunk into the hall")
		t.isTrue(dex.roofBook.across < dex.hall.across, "wider than the hall")
		t.isTrue(dex.roofBook.across > dex.hall.across / 4, "lost on the roof")
		t.isTrue(math.abs(dex.roofBook.forward) < dex.hall.deep / 2, "off the roof")
	end)

	--[[ The stands go on the two pads the hall builds for them: out past
	     its steps, and each one wide enough to hold its stand. ]]
	t.test("the stands stand on their pads, clear of each other", function()
		local dex = LobbyConfig.dex
		t.isTrue(dex.pads.out * 2 > dex.standBook.across * 2, "the two stands meet")
		t.isTrue(dex.pads.forward > dex.hall.deep / 2, "inside the building")
		t.isTrue(dex.pads.top > 0, "sunk into the lawn")
		t.isTrue(dex.pads.size.X >= dex.standBook.across, "the stand overhangs its pad")
	end)

	--[[ The hall's own shape has to be what `buildings.DexHall` says, or
	     the spacing between the stations is measured against a building
	     that is not there. ]]
	t.test("the Dex Hall's footprint matches the building it builds", function()
		local dex = LobbyConfig.dex
		local spec = LobbyConfig.buildings.DexHall
		t.equal(spec.size.X, dex.hall.across, "width")
		t.equal(spec.size.Z, dex.hall.deep, "depth")
		t.isTrue(math.abs(spec.size.Y - dex.hall.ridge) < 0.5, "height")
	end)

	--[[
		The Egg Hatchery and the Blacksmith were rebuilt from their sheets
		on 2026-11-02 (`Config/HatcheryDesign`, `Config/BlacksmithDesign`).
		What follows holds the things the sheets actually decide, which
		two earlier passes of this lobby got wrong by eye: not the
		numbers, which are meant to be retuned, but the shapes they have
		to come out as.
	]]
	t.test("each rebuilt station's footprint matches the building it builds", function()
		local hatchery = LobbyConfig.buildings.EggHatchery
		t.equal(hatchery.size.X, HatcheryDesign.across, "the hatchery's width")
		t.equal(hatchery.size.Z, HatcheryDesign.deep, "the hatchery's depth")
		local H = HatcheryDesign
		local bloom = H.plaza.tall - H.pool.drop + H.bloom.tall
		t.isTrue(math.abs(hatchery.size.Y - bloom) < 1.5, "the hatchery's height")

		local smith = LobbyConfig.buildings.Blacksmith
		t.equal(smith.size.X, BlacksmithDesign.across, "the blacksmith's width")
		t.equal(smith.size.Z, BlacksmithDesign.deep, "the blacksmith's depth")
		local B = BlacksmithDesign.house
		--[[ Summed in single-precision floats, so a few millionths of
		     slack, as the turned stand offsets carry. ]]
		t.isTrue(
			math.abs(smith.size.Y - (B.tall + B.lintel + B.gable)) < 1e-3,
			"the blacksmith's height"
		)
	end)

	--[[ Neither is a cottage on its sheet, so neither may ask `building`
	     for one: a `rise`, a roof or an emblem here would put a gable and
	     a giant egg or sword back on top of the rebuilt shapes. ]]
	t.test("neither rebuilt station is built as a cottage", function()
		for _, name in { "EggHatchery", "Blacksmith" } do
			local spec = LobbyConfig.buildings[name]
			t.equal(spec.rise, 0, `{name} has a gable`)
			t.equal(spec.emblem, nil, `{name} has an emblem on its ridge`)
			t.equal(spec.chimney, nil, `{name} builds the cottage chimney`)
			t.equal(spec.columns, nil, `{name} builds the cottage porch`)
			t.isTrue(spec.title ~= nil and spec.title ~= "", `{name} has no floating name`)
		end
	end)

	--[[ The deck is something a player walks up onto: the steps have to
	     climb the whole of it, and it has to leave room behind itself for
	     the pool and the balustrade. ]]
	t.test("the hatchery is a raised plaza you can walk up", function()
		local D = HatcheryDesign
		local climb = D.steps.count * D.steps.rise
		t.isTrue(math.abs(climb - D.plaza.tall) < 0.5, "the steps do not reach the deck")
		t.isTrue(D.steps.across < D.across, "the steps are wider than the plaza")
		t.isTrue(D.parapet.tall > 0, "the deck has no parapet")
		t.isTrue(D.plaza.chamfer * 2 < D.across, "the deck is all corner")
		t.isTrue(D.plaza.deep < D.deep, "the deck fills the whole footprint")
		t.isTrue(
			D.plaza.deep + D.pool.reach <= D.deep,
			"the pool runs off the back of the footprint"
		)
	end)

	--[[ The pool, the bloom, the pillars and the balustrade all stand
	     behind the deck, and all of them inside the footprint the lobby
	     spaces the stations by. ]]
	t.test("the hatchery's pool and bloom stand behind the deck, inside its footprint", function()
		local D = HatcheryDesign
		local half = D.deep / 2
		local deckBack = half - D.plaza.deep
		local poolBack = deckBack - D.pool.reach
		t.isTrue(D.pool.reach > 0, "there is no pool")
		t.isTrue(poolBack >= -half, "the pool runs past the back of the footprint")
		t.isTrue(D.bloom.back > 0, "the bloom stands on the deck")
		t.isTrue(deckBack - D.bloom.back > poolBack, "the bloom stands behind the pool")
		t.isTrue(deckBack - D.pillar.back >= poolBack - 1, "a pillar stands behind the pool")
		t.isTrue(
			D.fence.centre - D.fence.radius >= -half,
			"the balustrade runs past the back of the footprint"
		)
		t.isTrue(D.fence.radius <= D.across / 2, "the balustrade runs past the sides")
		t.isTrue(D.pillar.out + D.pillar.cap / 2 <= D.across / 2, "a pillar stands off the plaza")
	end)

	--[[ The bloom is the thing the whole station is built round: a pale
	     spire inside a ring of magenta petals over a fan of green leaves,
	     every one of them shorter than the spire. ]]
	t.test("the hatchery's bloom is a spire in a ring of petals over its leaves", function()
		local D = HatcheryDesign
		t.equal(D.petals.count, 6, "six petals")
		t.equal(D.leaves.count, 6, "six leaves")
		t.isTrue(D.spire.tall > D.petals.tall, "a petal stands over the spire")
		t.isTrue(D.petals.out > D.spire.wide / 2, "the petals stand inside the spire")
		t.isTrue(D.leaves.across > D.bloom.across, "the leaves do not reach past the petals")
		t.isTrue(D.leaves.long < D.spire.tall, "a leaf stands over the spire")
		local built = D.bloom.base + D.spire.tall + D.spire.point
		t.isTrue(math.abs(built - D.bloom.tall) < 1.5, "the bloom is not the height it says")
	end)

	--[[ One egg on its own lit pedestal each side, both standing on the
	     deck rather than off the front of it. ]]
	t.test("the hatchery's two eggs stand on lit pedestals on the deck", function()
		local D = HatcheryDesign
		t.isTrue(D.pedestal.bands >= 1, "the pedestal carries no light")
		t.isTrue(D.pedestal.out > D.pedestal.across / 2, "the two pedestals run into each other")
		t.isTrue(
			D.pedestal.out + D.pedestal.across / 2 < D.across / 2,
			"a pedestal hangs off the plaza"
		)
		t.isTrue(math.abs(D.pedestal.forward) < D.plaza.deep / 2, "a pedestal stands off the deck")
		t.isTrue(D.egg.tall > D.pedestal.tall, "the egg is shorter than what it stands on")
		t.isTrue(D.egg.wide < D.pedestal.across, "the egg is wider than its pedestal")
		t.isTrue(D.egg.spots >= 4, "the shell has no spots")
	end)

	--[[ The forge house is a timber front in a shell of stone, and the
	     whole of it has to sit inside the footprint the lobby spaces the
	     stations by. ]]
	t.test("the blacksmith's forge house stands inside its own footprint", function()
		local D = BlacksmithDesign
		local H = D.house
		t.isTrue(
			math.abs(H.side) + H.across / 2 + D.shell.out <= D.across / 2,
			"the stone shell runs off the side of the footprint"
		)
		t.isTrue(H.back + H.deep <= D.deep, "the house runs off the back of the footprint")
		t.isTrue(H.tall > D.hearth.base + D.hearth.tall, "the hearth is taller than the opening")
		t.isTrue(H.gable > 0 and H.lintel > 0, "the front has no gable over its lintel")
		t.isTrue(D.counter.tall < H.tall, "the counter fills the opening")
		t.isTrue(D.shell.courses >= 2, "the shell is one block high")
	end)

	--[[ The gold hammer is the shop's sign here -- there is no nameboard
	     on either sheet any more -- and the two banners hang beside it,
	     not over the opening the hammer sits above. ]]
	t.test("the blacksmith's hammer and banners hang on the gable", function()
		local D = BlacksmithDesign
		t.isTrue(D.hammer.head > 0 and D.hammer.haft > 0, "there is no hammer")
		t.isTrue(D.banner.out > D.hammer.head / 2, "a banner hangs over the hammer")
		t.isTrue(
			D.banner.out + D.banner.wide / 2 <= D.house.across / 2 + D.shell.out,
			"a banner hangs off the end of the house"
		)
		t.isTrue(
			D.banner.long < D.house.tall,
			"a banner hangs down past the lintel into the opening"
		)
	end)

	--[[ The sheet is drawn from the front-left: the rock and its lava are
	     on the viewer's LEFT, which is negative X, and the three chests
	     on the right. The first rebuild of this shop came out mirrored,
	     so this is held rather than left to the eye. ]]
	t.test("the blacksmith's lava is on the left and its chests on the right", function()
		local D = BlacksmithDesign
		t.isTrue(D.rock.side < 0, "the rock stands on the chests' side")
		t.isTrue(D.anvil.side < 0, "the anvil stands on the chests' side")
		t.isTrue(D.chest.side > 0, "the chests stand on the rock's side")
		t.isTrue(D.lava.wide < D.rock.across, "the lava is wider than the rock it runs down")
		t.isTrue(D.rock.steps >= 2, "the rock does not step down")
		t.isTrue(
			math.abs(D.rock.side) + D.rock.across / 2 <= D.across / 2 + 2,
			"the rock runs off the side of the footprint"
		)
		t.isTrue(
			D.chest.side + D.chest.apart + D.chest.across / 2 <= D.across / 2 + 2,
			"the chests run off the side of the footprint"
		)
	end)

	--[[ Three chests, one for each of the three classes the shop sells
	     for, and the anvil out clear of the house on the paving. ]]
	t.test(
		"the blacksmith's three chests are its three classes, and the anvil stands clear",
		function()
			local D = BlacksmithDesign
			t.equal(#D.marks, 3, "three chests")
			local seen = {}
			for _, mark in D.marks do
				t.isTrue(
					mark == "bow" or mark == "wand" or mark == "sword",
					`{mark} is not a class the shop sells for`
				)
				t.equal(seen[mark], nil, `two chests for {mark}`)
				seen[mark] = true
			end
			t.isTrue(
				D.anvil.forward > D.house.back + D.house.deep,
				"the anvil stands inside the forge house"
			)
			t.isTrue(D.anvil.forward < D.deep, "the anvil stands off the paving")
			t.isTrue(D.chest.forward < D.deep, "a chest stands off the paving")
		end
	)

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

	--[[ Measured as each one is actually turned (owner, 2026-11-01: every
	     building faces the middle). A box turned off the square covers
	     more lawn than its own width and depth, so taking `spec.size` as
	     it stands would say two buildings were clear of each other when
	     their corners overlap. ]]
	t.test("every station's footprint stands clear of every other's", function()
		local GAP = 6
		local placed = {}
		for _, station in LobbyConfig.stations do
			local spec = LobbyConfig.buildings[station.piece]
			if spec then
				-- the foundation reaches a stud past the walls
				local size = spec.size + Vector3.new(2, 0, 2)
				local yaw = LobbyConfig.facing(station.at)
				local s, c = math.abs(math.sin(yaw)), math.abs(math.cos(yaw))
				local turned = Vector3.new(size.X * c + size.Z * s, size.Y, size.X * s + size.Z * c)
				table.insert(placed, { name = station.piece, at = station.at, size = turned })
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
