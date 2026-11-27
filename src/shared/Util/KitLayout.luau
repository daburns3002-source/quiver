--!strict
--[[
	Lays an arena kit (`Config/ArenaKits`) out to one room: where each
	piece stands and how big, worked out from the room's size and its cover
	boxes, so a kit fits every room without a model per room (the owner's
	blocky Mossy Glade, 2026-10-24).

	- The walls: blocks along every side, stretched to fit evenly, a gap in
	  the north wall for the exit gate, a pillar at each corner.
	- The cover: each obstacle box drawn by the piece its shape asks for: a
	  long box is a fallen log, a tall one a stone pillar, a squat one a
	  tree stump, scaled to the box; a flat one is water (a pond) or a
	  thicket of ferns, which block walking but not arrows.
	- The lawn: square tiles in a few shades; stepping stones up the middle
	  from the start to the gate; plants along the inside of the walls.
	- What a kit adds of its own (the Drowned Village and Bogheart
	  Caverns, 2026-11-05): houses set into the side walls with a lantern
	  by each, a causeway of path tiles up the middle, a centrepiece on a
	  box at the room's centre, its own door in each gate, a stream drawn
	  over its water boxes with a bridge and stepping stones in the gaps
	  between them, and reeds and moss on the floor.

	Pure and seeded, so a room is the same each time it is built and
	`tests/KitLayout.spec` can check that nothing but cover stands in the
	way. Positions are from the room's centre on the floor (y = 0).
]]

local ArenaKits = require(script.Parent.Parent.Config.ArenaKits)

local KitLayout = {}

--[[ The piece that plays `role` in this kit: a kit may draw a role
     (WallBlock, FallenLog, CornerPillar, TreeStump, TallCover, FernBush,
     SteppingStone) with another of its pieces (`Kit.roles`), or not at all
     (nil). ]]
function KitLayout.piece(kit: ArenaKits.Kit, role: string): ArenaKits.Piece?
	local roles = kit.roles
	local name = if roles and roles[role] then roles[role] else role
	return kit.pieces[name]
end

local function must(kit: ArenaKits.Kit, role: string): ArenaKits.Piece
	return KitLayout.piece(kit, role) or error(`kit has no {role}`)
end

--[[ A piece, standing with its base centre at `base`, turned `yaw` about
     Y, `size` studs in its own axes. `cover` marks what stands for an
     obstacle box. ]]
export type Placement = {
	piece: string,
	base: Vector3,
	yaw: number,
	size: Vector3,
	cover: boolean,
	--[[ Laid flat on the floor (a causeway tile, a bridge, stepping
	     stones): walked over, so it may cross the start and cover. ]]
	floor: boolean?,
	--[[ Part of the wall (a house, a lantern, a door), outside the room. ]]
	wall: boolean?,
}

--[[ A flat patch of floor: a lawn tile, water or its bank. ]]
export type Patch = {
	kind: "Tile" | "Water" | "Bank" | "Dirt" | "Moss" | "Reed",
	centre: Vector3,
	size: Vector3,
	colour: Color3,
}

export type Layout = { pieces: { Placement }, patches: { Patch } }

export type Obstacle = { offset: Vector2, size: Vector3 }

export type Room = {
	size: Vector3,
	wallThickness: number,
	--[[ Where the player starts, kept clear of plants and path stones. ]]
	spawn: Vector3,
	--[[ The exit gate's full width in the north wall. ]]
	gateWidth: number,
}

--[[ What a flat, low cover box is in this room. ]]
export type LowCover = "Water" | "Thicket"

--[[ Below this height a box is flat cover (water, thorns); from this one
     up, a tall stone. ]]
local FLAT = 0.6
local TALL = 1.7
--[[ A box this many times longer than it is wide is a log. ]]
local LONG = 2

local function inBox(point: Vector3, box: Obstacle, margin: number): boolean
	return math.abs(point.X - box.offset.X) < box.size.X / 2 + margin
		and math.abs(point.Z - box.offset.Y) < box.size.Z / 2 + margin
end

local function clearOf(point: Vector3, boxes: { Obstacle }, margin: number): boolean
	for _, box in boxes do
		if inBox(point, box, margin) then
			return false
		end
	end
	return true
end

--[[ The walls: blocks along each side, the north one split by the gate
     (and the south one too in a kit with `southGate`), and a pillar at
     every corner. ]]
local function walls(kit: ArenaKits.Kit, room: Room, out: { Placement })
	local block = must(kit, "WallBlock").size * kit.scale
	local pillar = must(kit, "CornerPillar").size * kit.scale
	local hx, hz = room.size.X / 2, room.size.Z / 2
	local line = room.wallThickness / 2
	--[[ In a kit whose walls face in (`Kit.wallsFaceIn`), every wall piece
	     turns its front (+Z) to the room: north 0, south pi, west pi/2,
	     east -pi/2. ]]
	local function run(from: number, to: number, fixed: number, alongX: boolean)
		local yaw = if not kit.wallsFaceIn
			then (if alongX then 0 else math.pi / 2)
			elseif alongX then (if fixed < 0 then 0 else math.pi)
			else (if fixed < 0 then math.pi / 2 else -math.pi / 2)
		local span = to - from
		if span <= 0.5 then
			return
		end
		local count = math.max(1, math.floor(span / block.X + 0.5))
		local length = span / count
		for i = 0, count - 1 do
			local along = from + length * (i + 0.5)
			table.insert(out, {
				piece = "WallBlock",
				base = if alongX
					then Vector3.new(along, 0, fixed)
					else Vector3.new(fixed, 0, along),
				yaw = yaw,
				size = Vector3.new(length, block.Y, block.Z),
				cover = false,
			})
		end
	end
	local x = hx + line
	local z = hz + line
	local inner = pillar.X / 2
	local gate = room.gateWidth / 2
	-- North (the gate's side), split round the gate; south whole, or split
	-- the same where the kit asks.
	run(-x + inner, -gate, -z, true)
	run(gate, x - inner, -z, true)
	if kit.southGate then
		run(-x + inner, -gate, z, true)
		run(gate, x - inner, z, true)
	else
		run(-x + inner, x - inner, z, true)
	end
	-- West and east, split round a pillar halfway along where the kit asks,
	-- or round the houses set into them.
	local houses = KitLayout.houses(kit, room)
	for _, side in { -x, x } do
		if houses then
			local house = must(kit, "SideHouse").size * kit.scale
			local half = house.X / 2
			local from = -z + inner
			for _, hz2 in houses do
				run(from, hz2 - half, side, false)
				from = hz2 + half
				--[[ Its front just inside the wall's inner face, the rest
				     behind it, facing into the room. ]]
				local inward = -math.sign(side)
				table.insert(out, {
					piece = "SideHouse",
					base = Vector3.new(side - inward * (house.Z / 2 - line - 0.5), 0, hz2),
					yaw = inward * math.pi / 2,
					size = house,
					cover = false,
					wall = true,
				})
				local lantern = KitLayout.piece(kit, "Lantern")
				if lantern then
					--[[ Just past the house's south end, its post (the
					     piece's -X end) against the wall's inner face and its
					     arm (+X) reaching into the room overhead. ]]
					local size = lantern.size * kit.scale
					local face = side + inward * line
					table.insert(out, {
						piece = "Lantern",
						base = Vector3.new(
							face + inward * (size.X / 2 - 0.3 * kit.scale),
							0,
							hz2 + half + 2
						),
						yaw = if inward > 0 then 0 else math.pi,
						size = size,
						cover = false,
						wall = true,
					})
				end
			end
			run(from, z - inner, side, false)
		elseif kit.midPillars then
			run(-z + inner, -inner, side, false)
			run(inner, z - inner, side, false)
			table.insert(out, {
				piece = "CornerPillar",
				base = Vector3.new(side, 0, 0),
				yaw = 0,
				size = pillar,
				cover = false,
			})
		else
			run(-z + inner, z - inner, side, false)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(out, {
				piece = "CornerPillar",
				base = Vector3.new(sx * x, 0, sz * z),
				--[[ Its front corner (+X, +Z) towards the room. ]]
				yaw = if not kit.wallsFaceIn
					then 0
					elseif sz < 0 then (if sx < 0 then 0 else -math.pi / 2)
					else (if sx < 0 then math.pi / 2 else math.pi),
				size = pillar,
				cover = false,
			})
		end
	end
	--[[ The kit's own door in each gate's gap, as wide as the gap: the
	     exit's doors (`Arena/ExitGate`) swing inside the north one. ]]
	local door = KitLayout.piece(kit, "Door")
	if door then
		local size = door.size * kit.scale
		size = Vector3.new(room.gateWidth, size.Y, size.Z)
		for _, sz in (if kit.southGate then { -1, 1 } else { -1 }) :: { number } do
			table.insert(out, {
				piece = "Door",
				base = Vector3.new(0, 0, sz * z),
				yaw = if sz < 0 then 0 else math.pi,
				size = size,
				cover = false,
				wall = true,
			})
		end
	end
end

--[[ Where the houses set into each side wall stand along it (Z), evenly
     spaced; nil for a kit with none. ]]
function KitLayout.houses(kit: ArenaKits.Kit, room: Room): { number }?
	local count = kit.sideHouses
	if not count or count < 1 or not KitLayout.piece(kit, "SideHouse") then
		return nil
	end
	local span = room.size.Z
	local list = {}
	for i = 1, count do
		table.insert(list, -span / 2 + span * (i - 0.5) / count)
	end
	return list
end

--[[ One obstacle box as the piece its shape asks for. ]]
local function cover(
	kit: ArenaKits.Kit,
	box: Obstacle,
	low: LowCover,
	rng: Random,
	pieces: { Placement },
	patches: { Patch }
)
	local w, h, d = box.size.X, box.size.Y, box.size.Z
	local at = Vector3.new(box.offset.X, 0, box.offset.Y)
	--[[ Scaled evenly to the box's footprint, so the piece keeps its shape
	     (it may stand a little taller or lower than its box). ]]
	local function evenly(role: string, yaw: number)
		local own = must(kit, role).size
		local s = math.min(w / own.X, d / own.Z)
		table.insert(pieces, { piece = role, base = at, yaw = yaw, size = own * s, cover = true })
	end
	if h < FLAT then
		local stream = KitLayout.piece(kit, "StreamTile")
		if low == "Water" and stream then
			--[[ A stream: its tiles in a row along the box, each stretched to
			     an even share of it, flattened to the floor. ]]
			local tile = stream.size * kit.scale
			local alongX = w >= d
			local long, short = math.max(w, d), math.min(w, d)
			local count = math.max(1, math.floor(long / tile.X + 0.5))
			local length = long / count
			for i = 0, count - 1 do
				local along = -long / 2 + length * (i + 0.5)
				table.insert(pieces, {
					piece = "StreamTile",
					base = at
						+ (if alongX then Vector3.new(along, 0, 0) else Vector3.new(0, 0, along)),
					yaw = if alongX then 0 else math.pi / 2,
					size = Vector3.new(length, tile.Y * (kit.streamFlatten or 1), short),
					cover = true,
				})
			end
			return
		end
		if low == "Water" then
			table.insert(patches, {
				kind = "Bank",
				centre = at + Vector3.new(0, 0.03, 0),
				size = Vector3.new(w * 1.12, 0.06, d * 1.12),
				colour = kit.bank,
			})
			table.insert(patches, {
				kind = "Water",
				centre = at + Vector3.new(0, 0.08, 0),
				size = Vector3.new(w, 0.06, d),
				colour = kit.water,
			})
			return
		end
		-- A thicket: ferns packed over the box.
		local fern = must(kit, "FernBush").size * kit.scale
		local across = math.max(1, math.floor(w / kit.thicketSpacing + 0.5))
		local deep = math.max(1, math.floor(d / kit.thicketSpacing + 0.5))
		for i = 0, across - 1 do
			for j = 0, deep - 1 do
				local px = at.X - w / 2 + w * (i + 0.5) / across
				local pz = at.Z - d / 2 + d * (j + 0.5) / deep
				local grow = 0.9 + rng:NextNumber() * 0.35
				table.insert(pieces, {
					piece = "FernBush",
					base = Vector3.new(px, 0, pz),
					yaw = rng:NextNumber() * math.pi * 2,
					size = fern * grow,
					cover = true,
				})
			end
		end
		return
	end
	if
		KitLayout.piece(kit, "Centrepiece")
		and math.abs(box.offset.X) < 0.5
		and math.abs(box.offset.Y) < 0.5
	then
		evenly("Centrepiece", 0)
		return
	end
	local long, short = math.max(w, d), math.min(w, d)
	if long >= short * LONG then
		table.insert(pieces, {
			piece = "FallenLog",
			base = at,
			yaw = if d > w then math.pi / 2 else 0,
			size = Vector3.new(long, h, short),
			cover = true,
		})
	elseif h >= TALL and kit.keepShape and kit.keepShape.TallCover then
		evenly("TallCover", 0)
	elseif h >= TALL then
		table.insert(pieces, {
			piece = if KitLayout.piece(kit, "TallCover") then "TallCover" else "CornerPillar",
			base = at,
			yaw = 0,
			size = Vector3.new(w, h, d),
			cover = true,
		})
	else
		--[[ Scaled evenly to its footprint: a stump keeps its shape, so it
		     may stand a little taller than its box. ]]
		local stump = must(kit, "TreeStump").size
		local s = math.min(w / stump.X, d / stump.Z)
		table.insert(pieces, {
			piece = "TreeStump",
			base = at,
			yaw = 0,
			size = stump * s,
			cover = true,
		})
	end
end

--[[ A seed from the arena's name, so a room is the same every time. ]]
function KitLayout.seed(name: string): number
	local seed = 7
	for i = 1, #name do
		seed = (seed * 31 + string.byte(name, i)) % 2147483647
	end
	return seed
end

--[[ A room's seed: its arena's, stirred by where its cover stands, so
     rooms that share an arena (Thornwood's forty) still differ in their
     lawn, plants and path. ]]
function KitLayout.roomSeed(arena: string, obstacles: { Obstacle }): number
	local key = arena
	for _, box in obstacles do
		key ..= `{math.floor(box.offset.X * 10)},{math.floor(box.offset.Y * 10)};`
	end
	return KitLayout.seed(key)
end

function KitLayout.build(
	kitName: string,
	room: Room,
	obstacles: { Obstacle },
	low: LowCover,
	seed: number
): Layout
	local kit = ArenaKits[kitName]
	local rng = Random.new(seed)
	local pieces: { Placement } = {}
	local patches: { Patch } = {}
	local hx, hz = room.size.X / 2, room.size.Z / 2

	-- The lawn.
	local across = math.max(1, math.floor(room.size.X / kit.tile + 0.5))
	local deep = math.max(1, math.floor(room.size.Z / kit.tile + 0.5))
	local tw, td = room.size.X / across, room.size.Z / deep
	for i = 0, across - 1 do
		for j = 0, deep - 1 do
			table.insert(patches, {
				kind = "Tile",
				centre = Vector3.new(-hx + tw * (i + 0.5), -0.25, -hz + td * (j + 0.5)),
				size = Vector3.new(tw, 0.5, td),
				colour = kit.lawn[rng:NextInteger(1, #kit.lawn)],
			})
		end
	end

	walls(kit, room, pieces)
	for _, box in obstacles do
		cover(kit, box, low, rng, pieces, patches)
	end

	-- Stepping stones from the start up to the gate, or a trail of dirt
	-- patches in a kit with no stones.
	--[[ Flatter than the piece, and only a little turned, so the path
	     reads as a path from above rather than scattered blocks. ]]
	local stonePiece = KitLayout.piece(kit, "SteppingStone")
	local dirt = kit.dirt
	local stone = if stonePiece
		then stonePiece.size * kit.scale * Vector3.new(0.9, 0.45, 0.9)
		else Vector3.new(kit.pathSpacing * 0.8, 0.06, kit.pathSpacing * 0.8)
	local phase = rng:NextNumber() * math.pi * 2
	local z = room.spawn.Z - kit.pathSpacing
	local path: { Vector3 } = {}
	while z > -hz + kit.pathSpacing * 0.5 do
		local at = Vector3.new(kit.pathSway * math.sin(z * 0.3 + phase), 0, z)
		if clearOf(at, obstacles, stone.X * 0.6) then
			table.insert(path, at)
			if stonePiece then
				table.insert(pieces, {
					piece = "SteppingStone",
					base = at,
					yaw = (rng:NextNumber() - 0.5) * 0.5,
					size = stone,
					cover = false,
				})
			elseif dirt then
				--[[ A few square blocks round each step, as the reference
				     sheet's dirt is pixels rather than ovals. ]]
				for _ = 1, 4 do
					local side = kit.tile * (0.35 + rng:NextNumber() * 0.3)
					local jitter = Vector3.new(
						(rng:NextNumber() - 0.5) * stone.X,
						0,
						(rng:NextNumber() - 0.5) * stone.Z
					)
					table.insert(patches, {
						kind = "Dirt",
						centre = at + jitter + Vector3.new(0, 0.02, 0),
						size = Vector3.new(side, stone.Y, side),
						colour = dirt[rng:NextInteger(1, #dirt)],
					})
				end
			end
		end
		z -= kit.pathSpacing
	end

	-- A causeway of path tiles from the south wall to the north, under
	-- everything that stands on it.
	local tilePiece = KitLayout.piece(kit, "PathTile")
	if tilePiece and kit.causeway then
		local tile = tilePiece.size * kit.scale
		local count = math.max(1, math.floor(room.size.Z / tile.Z + 0.5))
		local length = room.size.Z / count
		for i = 0, count - 1 do
			table.insert(pieces, {
				piece = "PathTile",
				base = Vector3.new(0, 0, -hz + length * (i + 0.5)),
				yaw = 0,
				size = Vector3.new(tile.X, tile.Y * kit.causeway, length),
				cover = false,
				floor = true,
			})
		end
	end

	--[[ Over a stream, the ways across: a bridge in a gap near the middle,
	     stepping stones in the others, each spanning the water. ]]
	if low == "Water" and KitLayout.piece(kit, "StreamTile") then
		local bands: { [number]: { Obstacle } } = {}
		for _, box in obstacles do
			if box.size.Y < FLAT and box.size.X >= box.size.Z then
				local key = math.floor(box.offset.Y * 10 + 0.5)
				bands[key] = bands[key] or {}
				table.insert(bands[key], box)
			end
		end
		local keys = {}
		for key in bands do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in keys do
			local band = bands[key]
			table.sort(band, function(a, b)
				return a.offset.X < b.offset.X
			end)
			for i = 1, #band - 1 do
				local a, b = band[i], band[i + 1]
				local left = a.offset.X + a.size.X / 2
				local right = b.offset.X - b.size.X / 2
				local gap = right - left
				if gap <= 0.5 then
					continue
				end
				local bandZ = (a.offset.Y + b.offset.Y) / 2
				local span = math.max(a.size.Z, b.size.Z)
				local mid = (left + right) / 2
				local bridge = KitLayout.piece(kit, "Bridge")
				local stones = KitLayout.piece(kit, "StreamStones")
				if bridge and math.abs(mid) < 3 then
					local own = bridge.size * kit.scale
					table.insert(pieces, {
						piece = "Bridge",
						base = Vector3.new(mid, 0, bandZ),
						yaw = 0,
						size = Vector3.new(gap, own.Y * (kit.bridgeFlatten or 1), span + 3),
						cover = false,
						floor = true,
					})
				elseif stones then
					local own = stones.size * kit.scale
					table.insert(pieces, {
						piece = "StreamStones",
						base = Vector3.new(mid, 0, bandZ),
						yaw = math.pi / 2,
						size = Vector3.new(span + 2, own.Y, math.min(gap * 0.85, own.Z * 1.3)),
						cover = false,
						floor = true,
					})
				end
			end
		end
	end

	--[[ Moss on the floor in short staircase runs of squares, as the
	     reference sheet's is drawn. ]]
	local moss = kit.moss
	if moss then
		for _ = 1, moss.count do
			local x = (rng:NextNumber() * 2 - 1) * (hx - moss.size * 2.6)
			local mz = (rng:NextNumber() * 2 - 1) * (hz - moss.size * 2.6)
			local stepX = if rng:NextNumber() < 0.5 then -1 else 1
			local colour = moss.colours[rng:NextInteger(1, #moss.colours)]
			for step = 0, rng:NextInteger(1, 3) do
				table.insert(patches, {
					kind = "Moss",
					centre = Vector3.new(
						x + step * stepX * moss.size * 0.7,
						0.02,
						mz + step * moss.size * 0.6
					),
					size = Vector3.new(moss.size, 0.04, moss.size * 0.6),
					colour = colour,
				})
			end
		end
	end

	--[[ Reeds: clumps of a few upright blades in the room's corners and at
	     the foot of the side walls, never in the middle. ]]
	local reeds = kit.reeds
	if reeds then
		local spots: { Vector3 } = {}
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(spots, Vector3.new(sx * (hx - 1.2), 0, sz * (hz - 1.2)))
			end
		end
		for _ = 1, reeds.clumps do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			table.insert(
				spots,
				Vector3.new(side * (hx - 0.9), 0, (rng:NextNumber() * 2 - 1) * (hz - 6))
			)
		end
		for _, spot in spots do
			if (spot - Vector3.new(room.spawn.X, 0, room.spawn.Z)).Magnitude < 5 then
				continue
			end
			for _ = 1, rng:NextInteger(2, 4) do
				local tall = reeds.height * (0.6 + rng:NextNumber() * 0.6)
				local at = spot
					+ Vector3.new((rng:NextNumber() - 0.5) * 1.6, 0, (rng:NextNumber() - 0.5) * 1.6)
				table.insert(patches, {
					kind = "Reed",
					centre = at + Vector3.new(0, tall / 2, 0),
					size = Vector3.new(0.45, tall, 0.45),
					colour = reeds.colours[rng:NextInteger(1, #reeds.colours)],
				})
			end
		end
	end

	-- Plants along the inside of each wall.
	local function placeable(at: Vector3, radius: number): boolean
		if not clearOf(at, obstacles, radius + 0.5) then
			return false
		end
		local inGate = math.abs(at.X) < room.gateWidth / 2 + radius + 0.5
		if inGate and at.Z < -hz + kit.edgeDepth + 1 then
			return false
		end
		if inGate and kit.southGate and at.Z > hz - kit.edgeDepth - 1 then
			return false
		end
		if
			(Vector3.new(at.X, 0, at.Z) - Vector3.new(room.spawn.X, 0, room.spawn.Z)).Magnitude < 4
		then
			return false
		end
		for _, p in path do
			if (p - at).Magnitude < radius + stone.X * 0.6 then
				return false
			end
		end
		for _, other in pieces do
			if
				not other.cover
				and not other.wall
				and other.piece ~= "WallBlock"
				and other.piece ~= "CornerPillar"
			then
				if
					(other.base - at).Magnitude
					< radius + math.max(other.size.X, other.size.Z) / 2
				then
					return false
				end
			end
		end
		return true
	end
	local names = {}
	for name in kit.plants do
		table.insert(names, name)
	end
	table.sort(names)
	for _, side in { "N", "S", "W", "E" } do
		for _, name in names do
			local size = must(kit, name).size * kit.scale
			for _ = 1, kit.plants[name] do
				for _ = 1, 8 do
					local grow = 0.85 + rng:NextNumber() * 0.4
					local radius = math.max(size.X, size.Z) * grow / 2
					local inset = radius + rng:NextNumber() * math.max(0, kit.edgeDepth - radius)
					local along = rng:NextNumber() * 2 - 1
					local at = if side == "N"
						then Vector3.new(along * (hx - radius), 0, -hz + inset)
						elseif side == "S" then Vector3.new(
							along * (hx - radius),
							0,
							hz - inset
						)
						elseif side == "W" then Vector3.new(
							-hx + inset,
							0,
							along * (hz - radius)
						)
						else Vector3.new(hx - inset, 0, along * (hz - radius))
					if placeable(at, radius) then
						table.insert(pieces, {
							piece = name,
							base = at,
							yaw = rng:NextNumber() * math.pi * 2,
							size = size * grow,
							cover = false,
						})
						break
					end
				end
			end
		end
	end

	return { pieces = pieces, patches = patches }
end

return KitLayout
