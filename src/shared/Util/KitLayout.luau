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
export type Placement = { piece: string, base: Vector3, yaw: number, size: Vector3, cover: boolean }

--[[ A flat patch of floor: a lawn tile, water or its bank. ]]
export type Patch = {
	kind: "Tile" | "Water" | "Bank" | "Dirt",
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
	local function run(from: number, to: number, fixed: number, alongX: boolean)
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
				yaw = if alongX then 0 else math.pi / 2,
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
	-- West and east.
	run(-z + inner, z - inner, -x, false)
	run(-z + inner, z - inner, x, false)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(out, {
				piece = "CornerPillar",
				base = Vector3.new(sx * x, 0, sz * z),
				yaw = 0,
				size = pillar,
				cover = false,
			})
		end
	end
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
	if h < FLAT then
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
	local long, short = math.max(w, d), math.min(w, d)
	if long >= short * LONG then
		table.insert(pieces, {
			piece = "FallenLog",
			base = at,
			yaw = if d > w then math.pi / 2 else 0,
			size = Vector3.new(long, h, short),
			cover = true,
		})
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
				local grow = 0.85 + rng:NextNumber() * 0.4
				table.insert(patches, {
					kind = "Dirt",
					centre = at + Vector3.new(0, 0.02, 0),
					size = Vector3.new(stone.X * grow, stone.Y, stone.Z * (2 - grow)),
					colour = dirt[rng:NextInteger(1, #dirt)],
				})
			end
		end
		z -= kit.pathSpacing
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
			if not other.cover and other.piece ~= "WallBlock" and other.piece ~= "CornerPillar" then
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
