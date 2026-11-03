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
		local deck = HatcheryDesign.postTall + HatcheryDesign.beam + HatcheryDesign.slab
		t.isTrue(math.abs(hatchery.size.Y - deck) < 0.5, "the hatchery's height")

		local smith = LobbyConfig.buildings.Blacksmith
		t.equal(smith.size.X, BlacksmithDesign.across, "the blacksmith's width")
		t.equal(smith.size.Z, BlacksmithDesign.deep, "the blacksmith's depth")
		t.equal(smith.size.Y, BlacksmithDesign.wallTall, "the blacksmith's height")
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

	--[[ The shelter is open to the front and closed at the back, and the
	     beam stands well over the tallest egg, so you look in at the
	     clutch against stone rather than through at the lawn. ]]
	t.test("the hatchery is a shelter with its eggs under it", function()
		local D = HatcheryDesign
		local tallest = D.nests[2].tall
		t.isTrue(D.postTall > tallest + D.nestTall, "the roof sits on the eggs")
		t.isTrue(D.across > D.deep, "the shelter is deeper than it is wide")
		t.isTrue(D.eaves > 0, "the deck stops at the posts")
		t.isTrue(D.back.thick > 0 and D.back.courses >= 2, "the back of the shelter is open")
		--[[ A post stands at each corner, half its thickness in; the
		     outermost nest may touch one but not pass it. ]]
		local post = D.across / 2 - D.postThick
		local outer = math.abs(D.nests[1].at) + D.nests[1].across / 2
		t.isTrue(outer <= post + 1, "the nests run through the posts")
		--[[ Set forward, so the eggs are in the open rather than back in
		     the shade of the deck. ]]
		t.isTrue(D.nestForward > 0, "the nests sit behind the middle")
		t.isTrue(
			D.nestForward + D.nests[2].across / 2 > D.deep / 2,
			"the nests are all under the roof"
		)
	end)

	--[[ Three nests, each with its own egg: one wide ring with the three
	     sunk in it is what the first build laid, and in game it read as a
	     plastic tub rather than the sheet's clover of stone. ]]
	t.test("the hatchery's three nests each hold one egg, the middle one tallest", function()
		local D = HatcheryDesign
		t.equal(#D.nests, 3, "three nests")
		t.isTrue(D.nests[2].tall > D.nests[1].tall, "the middle egg is the tallest")
		t.isTrue(D.nests[2].across > D.nests[1].across, "the middle nest is the widest")
		t.equal(D.nests[1].tall, D.nests[3].tall, "the outer two eggs match")
		t.equal(D.nests[1].across, D.nests[3].across, "the outer two nests match")
		t.isTrue(D.nests[2].back > D.nests[1].back, "the middle nest is not set back")
		for k, nest in D.nests do
			t.isTrue(nest.tall > nest.wide, `egg {k} is not egg-shaped`)
			--[[ The shell rests ON the gold rim and overhangs the hole,
			     which is what stops an egg reading as dropped in a cup. ]]
			local hole = nest.across - D.nestThick * 2
			t.isTrue(nest.wide > hole, `egg {k} drops through its nest`)
			t.isTrue(nest.wide < nest.across, `egg {k} swallows its nest`)
		end
		--[[ The eggs stand apart even where the nests overlap. ]]
		local gap = math.abs(D.nests[2].at - D.nests[1].at)
			- D.nests[2].wide / 2
			- D.nests[1].wide / 2
		t.isTrue(gap > 0, "the outer eggs run into the middle one")
	end)

	--[[ The forge is a hole in the wall with fire in it, under a stack
	     that stands BEHIND the wall: built on the wall line the chimney
	     put three studs of stone in front of its own hearth and hid the
	     fire from everywhere but dead in front. ]]
	t.test("the blacksmith's hearth is open under a chimney that stands clear of it", function()
		local D = BlacksmithDesign
		local head = D.hearth.base + D.hearth.tall
		t.isTrue(head + D.hearth.hood < D.wallTall, "the hearth is taller than the wall")
		t.isTrue(D.hearth.across < D.across, "the hearth is wider than the wall")
		--[[ The opening is cut to one side, with the stack over it. ]]
		t.equal(math.sign(D.chimney.side), math.sign(D.hearth.side), "the stack is off its hearth")
		t.isTrue(
			math.abs(D.hearth.side) + D.hearth.across / 2 <= D.across / 2,
			"the hearth is cut through the end of the wall"
		)
		--[[ Behind the wall: its front face is `across / 2 - back` from
		     the wall's own middle plane, which has to be behind it. ]]
		t.isTrue(D.chimney.back - D.chimney.across / 2 > 0, "the chimney stands in the shop")
		t.isTrue(D.chimney.rise > 0, "the chimney stops at the wall")
		t.isTrue(D.chimney.mouth < D.chimney.across, "the chimney is all mouth")
	end)

	--[[ The side wall down the left is what turns one wall into a shop,
	     and the arch has to be a hole in it rather than a hole off its
	     end. ]]
	t.test("the blacksmith's side wall carries an arch inside its own length", function()
		local D = BlacksmithDesign
		t.isTrue(D.side.long > D.arch.across, "the arch is wider than the wall it is cut in")
		t.isTrue(D.arch.forward - D.arch.across / 2 > 0, "the arch is cut behind the back wall")
		t.isTrue(
			D.arch.forward + D.arch.across / 2 < D.side.long,
			"the arch runs off the end of the side wall"
		)
		t.isTrue(D.arch.tall < D.wallTall, "the arch is taller than the wall")
		t.isTrue(D.arch.steps >= 1, "the arch has no head")
		--[[ The red cloth hangs in the arch, not over its head or on the
		     floor. ]]
		t.isTrue(D.cloth.wide < D.arch.across, "the cloth is wider than the arch")
		t.isTrue(D.cloth.top <= D.arch.tall, "the cloth hangs above the arch")
		t.isTrue(D.cloth.long < D.cloth.top, "the cloth reaches the floor")
	end)

	--[[ What the sheet puts out on the floor, in front of the wall and
	     clear of it, and the banner and rack outside the walls. ]]
	t.test("the blacksmith's floor furniture stands in front of its wall", function()
		local D = BlacksmithDesign
		for name, item in
			{ anvil = D.anvil, bench = D.bench, wares = D.table_ } :: {
				[string]: { forward: number },
			}
		do
			t.isTrue(item.forward > 0, `the {name} is inside the wall`)
			t.isTrue(item.forward < D.deep, `the {name} is off the apron`)
		end
		t.isTrue(D.apron.X >= D.across, "the apron is narrower than the shop")
		--[[ One anvil, out on the open floor clear of the side wall and
		     of the tables: the sheet draws a single anvil as the thing
		     the eye lands on, and a matched pair is what the first build
		     put there. ]]
		t.isTrue(
			math.abs(D.anvil.side) + D.anvil.long / 2 < D.across / 2 - D.wallThick,
			"the anvil stands in a wall"
		)
		t.isTrue(D.anvil.forward > D.bench.forward + D.bench.wide, "the anvil is on the bench")
		--[[ The banner hangs outside the walls, and the sword rack
		     outside the side wall, where the sheet stands them. ]]
		t.isTrue(math.abs(D.banner.out) > D.across / 2, "the banner hangs inside the shop")
		--[[ The sheet puts the fire on the viewer's right and the arch,
		     the rack and the board on the left; +X is the right of the
		     screen for a station facing +Z. ]]
		t.isTrue(D.hearth.side > 0, "the hearth is cut on the wrong side")
		t.isTrue(D.rack.side < 0, "the sword rack stands on the hearth's side")
		t.isTrue(D.bench.side < 0, "the work tables stand on the hearth's side")
		t.isTrue(D.banner.long < D.banner.top, "the banner reaches the floor")
		t.isTrue(math.abs(D.rack.side) > D.across / 2, "the sword rack stands in the shop")
		--[[ And the board hangs on the other side of the wall from the
		     hearth, with its bottom edge above the hood: drawn on the
		     hearth's own side it covered the fire. ]]
		local board = (D.across / 2 - D.sign.across / 2 - 1.5) * -math.sign(D.hearth.side)
		t.isTrue(board * D.hearth.side < 0, "the board hangs over the fire")
		t.isTrue(
			D.wallTall - D.sign.below - D.sign.tall > D.hearth.base + D.hearth.tall + D.hearth.hood,
			"the board meets the hood"
		)
		t.isTrue(D.sign.below + D.sign.tall < D.wallTall, "the board is off the top of the wall")
	end)

	--[[ Both sheets hang a DARK board with white letters in a timber
	     frame. The lobby's shared light-brown plank reads as a plank, and
	     that is what both of these were given first. ]]
	t.test("both rebuilt stations hang a dark nameboard with pale letters", function()
		for name, look in
			{ hatchery = HatcheryDesign.colours, blacksmith = BlacksmithDesign.colours } :: {
				[string]: { board: Color3, ink: Color3 },
			}
		do
			local board = look.board.R + look.board.G + look.board.B
			local ink = look.ink.R + look.ink.G + look.ink.B
			t.isTrue(board < 0.6, `the {name}'s board is not dark`)
			t.isTrue(ink > board + 1.5, `the {name}'s letters do not stand off its board`)
		end
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
