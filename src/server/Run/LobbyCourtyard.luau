--!strict
--[[
	Lobby B's ground and ruins (`Config/Lobby.courtyard`), from the layout sheet
	`assets/concepts/blocky/lobby/palace/lobby_layout_reference.png`: the cream
	marble floor with moss in its joints, the gold inlaid rings, the red carpets,
	the fountain, the arrival circle, the low broken balustrade and the
	vine-wrapped broken columns. `Run/Lobby` calls these in turn and builds the
	buildings and the portal terrace itself.

	Every piece is a plain smooth part, the words alone being in the blocky font
	(owner, 2026-10-27). Flat things are stacked by height: the `LAYER` table is
	the whole order, because two flat parts level with each other flicker.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local PalaceBuildings = require(ReplicatedStorage.Shared.Config.PalaceBuildings)

local LobbyCourtyard = {}

local ORIGIN = LobbyConfig.origin
local COLOURS = LobbyConfig.colours
local SPEC = LobbyConfig.courtyard
local OUTLINE = SPEC.outline

--[[ The floor's height, a little above nothing, and the ground past the
     balustrade, which the courtyard stands above. ]]
LobbyCourtyard.FLOOR = 0.1
LobbyCourtyard.OUTSIDE = 0.1 - SPEC.drop
local FLOOR = LobbyCourtyard.FLOOR

--[[ The tops of the flat things, studs above the floor. ]]
local LAYER = {
	base = 0.04,
	tile = 0.1,
	moss = 0.14,
	outerGold = 0.18,
	outerMarble = 0.22,
	innerGold = 0.26,
	innerMarble = 0.3,
	seam = 0.34,
	carpetGold = 0.38,
	carpetRed = 0.44,
}
--[[ What a player walks on: level with the carpets, so no foot sinks. ]]
local WALK = LAYER.carpetRed

local function world(at: Vector2, y: number?): Vector3
	return ORIGIN + Vector3.new(at.X, y or 0, at.Y)
end

--[[ A smooth part, seen but never met: no collision, no queries (the camera
     and the prompts see through it). ]]
function LobbyCourtyard.part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	parent: Instance,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Parent = parent
	return p
end
local part = LobbyCourtyard.part

--[[ An ellipsoid `size` studs across. ]]
function LobbyCourtyard.blob(
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	parent: Instance
): Part
	local p = part(name, size, cframe, colour, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
local blob = LobbyCourtyard.blob

--[[ A wall a player meets and nothing sees. ]]
function LobbyCourtyard.wall(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end
local wall = LobbyCourtyard.wall

--[[ An upright cylinder, its foot at `foot`. ]]
local function drum(
	name: string,
	foot: Vector3,
	height: number,
	across: number,
	colour: Color3,
	parent: Instance
): Part
	return part(
		name,
		Vector3.new(height, across, across),
		CFrame.new(foot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		colour,
		parent,
		Enum.PartType.Cylinder
	)
end

--[[ A flat round thing lying on the floor, its top at `layer`. ]]
local function disc(
	name: string,
	at: Vector2,
	across: number,
	layer: number,
	colour: Color3,
	parent: Instance
)
	local p = drum(name, world(at, FLOOR + layer - 0.1), 0.1, across, colour, parent)
	p.CastShadow = false
	return p
end

--[[ A flat strip lying on the floor from `a` to `b`, its top at `layer`. ]]
local function strip(
	name: string,
	a: Vector2,
	b: Vector2,
	across: number,
	layer: number,
	colour: Color3,
	parent: Instance
): Part
	local y = FLOOR + layer - 0.05
	local p = part(
		name,
		Vector3.new(across, 0.1, (b - a).Magnitude),
		CFrame.lookAt(world((a + b) / 2, y), world(b, y)),
		colour,
		parent
	)
	p.CastShadow = false
	return p
end

--[[ Whether `at` is inside the balustrade, by at least `margin` studs. The
     outline is convex and runs clockwise seen from above. ]]
function LobbyCourtyard.inside(at: Vector2, margin: number?): boolean
	local give = margin or 0
	for k, a in OUTLINE do
		local b = OUTLINE[k % #OUTLINE + 1]
		local along = (b - a).Unit
		local inward = Vector2.new(along.Y, -along.X)
		if (at - a):Dot(inward) < give then
			return false
		end
	end
	return true
end

--[[ How far the outline reaches east and west at depth `z`. ]]
local function span(z: number): (number, number)
	local low, high = math.huge, -math.huge
	for k, a in OUTLINE do
		local b = OUTLINE[k % #OUTLINE + 1]
		if (a.Y <= z and b.Y >= z) or (b.Y <= z and a.Y >= z) then
			local t = if a.Y == b.Y then 0 else (z - a.Y) / (b.Y - a.Y)
			local x = a.X + (b.X - a.X) * t
			low, high = math.min(low, x), math.max(high, x)
			if a.Y == b.Y then
				low, high = math.min(low, b.X), math.max(high, b.X)
			end
		end
	end
	return low, high
end

--[[ Whether a tile would lie out of sight, under a building. ]]
local function underBuilding(at: Vector2): boolean
	for _, station in LobbyConfig.stations do
		local spec = LobbyConfig.buildings[station.piece]
		if spec then
			local yaw = LobbyConfig.facing(station.at)
			local s, c = math.sin(yaw), math.cos(yaw)
			local d = at - station.at
			local size = spec.size * LobbyConfig.buildingScale
			if
				math.abs(d.X * c - d.Y * s) < size.X / 2 - 2
				and math.abs(d.X * s + d.Y * c) < size.Z / 2 - 2
			then
				return true
			end
		end
	end
	return false
end

--[[ The solid floor, the plain marble under the flagstones showing as their
     joints, and the flagstones themselves, one of three close shades each so
     the floor never reads as a checkerboard. Moss runs along some joints, and
     a few long veins and cracks wander over the top. ]]
function LobbyCourtyard.floor(rng: Random, parent: Instance)
	local floor = Instance.new("Model")
	floor.Name = "CourtyardFloor"

	-- what a player stands on, the outline's whole bounding box
	local west, east, north, south = math.huge, -math.huge, math.huge, -math.huge
	local levels: { number } = {}
	for _, point in OUTLINE do
		west, east = math.min(west, point.X), math.max(east, point.X)
		north, south = math.min(north, point.Y), math.max(south, point.Y)
		if not table.find(levels, point.Y) then
			table.insert(levels, point.Y)
		end
	end
	table.sort(levels)
	wall(
		"Walk",
		Vector3.new(east - west, 1, south - north),
		CFrame.new(world(Vector2.new((east + west) / 2, (north + south) / 2), FLOOR + WALK - 0.5)),
		floor
	)

	--[[ The base: a rectangle between each two depths the outline turns at,
	     then a slab along each slanted edge to fill its corner. ]]
	for k = 1, #levels - 1 do
		local low, high = levels[k], levels[k + 1]
		local w1, e1 = span(low)
		local w2, e2 = span(high)
		local w, e = math.max(w1, w2), math.min(e1, e2)
		strip(
			"Base",
			Vector2.new((w + e) / 2, low),
			Vector2.new((w + e) / 2, high),
			e - w,
			LAYER.base,
			COLOURS.joint,
			floor
		)
	end
	for k, a in OUTLINE do
		local b = OUTLINE[k % #OUTLINE + 1]
		if a.X ~= b.X and a.Y ~= b.Y then
			local along = (b - a).Unit
			local inward = Vector2.new(along.Y, -along.X)
			local reach = (b - a).Magnitude / 2
			strip(
				"Base",
				a + inward * reach / 2,
				b + inward * reach / 2,
				reach,
				LAYER.base,
				COLOURS.joint,
				floor
			)
		end
	end

	local plaza = LobbyConfig.plaza / 2
	local arrival = SPEC.arrival.across / 2
	local tile = SPEC.tile
	local gap = SPEC.joint
	local mossColours = { COLOURS.moss, COLOURS.mossDark }
	local shades = COLOURS.marble
	local depth = north
	while depth < south do
		local middleZ = depth + tile.Y / 2
		local x = west - rng:NextNumber() * tile.X
		while x < east do
			local across = tile.X * rng:NextNumber(0.7, 1.3)
			local at = Vector2.new(x + across / 2, middleZ)
			local half = Vector2.new(across / 2, tile.Y / 2)
			local whole = true
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					if not LobbyCourtyard.inside(at + half * Vector2.new(sx, sz)) then
						whole = false
					end
				end
			end
			local hidden = underBuilding(at)
				or (at - LobbyConfig.middle).Magnitude < plaza - 4
				or (at - SPEC.arrival.at).Magnitude < arrival - 4
			if whole and not hidden then
				local flag = part(
					"Flag",
					Vector3.new(across - gap, 0.1, tile.Y - gap),
					CFrame.new(world(at, FLOOR + LAYER.tile - 0.05)),
					shades[rng:NextInteger(1, #shades)],
					floor
				)
				flag.CastShadow = false
				if rng:NextNumber() < SPEC.mossShare then
					local colour = mossColours[rng:NextInteger(1, #mossColours)]
					local side = if rng:NextInteger(0, 1) == 0
						then {
							a = at + Vector2.new(half.X, -half.Y),
							b = at + Vector2.new(half.X, half.Y),
						}
						else {
							a = at + Vector2.new(-half.X, half.Y),
							b = at + Vector2.new(half.X, half.Y),
						}
					strip("Moss", side.a, side.b, gap + 0.7, LAYER.moss, colour, floor)
					disc(
						"MossTuft",
						(side.a + side.b) / 2,
						rng:NextNumber(1.2, 2.6),
						LAYER.moss,
						colour,
						floor
					)
				end
			end
			x += across
		end
		depth += tile.Y
	end

	-- long wandering lines, each a few bent lengths, kept inside the balustrade
	local function wander(name: string, count: number, width: number, colour: Color3)
		for _ = 1, count do
			local at = Vector2.new(rng:NextNumber(west, east), rng:NextNumber(north, south))
			local turn = rng:NextNumber() * math.pi * 2
			for _ = 1, rng:NextInteger(2, 4) do
				local length = rng:NextNumber(3.5, 8)
				local nextAt = at + Vector2.new(math.cos(turn), math.sin(turn)) * length
				if
					LobbyCourtyard.inside(at, 2)
					and LobbyCourtyard.inside(nextAt, 2)
					and not underBuilding(nextAt)
				then
					strip(name, at, nextAt, width, LAYER.moss, colour, floor)
				end
				at = nextAt
				turn += rng:NextNumber(-0.9, 0.9)
			end
		end
	end
	wander("MossVein", SPEC.mossVeins, 0.55, COLOURS.moss)
	wander("Crack", SPEC.cracks, 0.16, COLOURS.crack)

	floor.Parent = parent
end

--[[ A red carpet with gold edges from `a` to `b`, `across` wide. ]]
function LobbyCourtyard.carpet(
	a: Vector2,
	b: Vector2,
	across: number,
	parent: Instance,
	top: number?
)
	local lift = top or 0
	strip(
		"CarpetEdge",
		a,
		b,
		across + SPEC.carpetEdge * 2,
		LAYER.carpetGold + lift,
		COLOURS.gold,
		parent
	)
	strip("Carpet", a, b, across, LAYER.carpetRed + lift, COLOURS.carpet, parent)
end
local carpet = LobbyCourtyard.carpet

--[[ A gold ring inlaid in the floor: a gold disc and a marble one on it. Only
     the two layers of `inner` or `outer` are ever used, so rings nest. ]]
local function inlay(at: Vector2, across: number, width: number, inner: boolean, parent: Instance)
	disc(
		"GoldRing",
		at,
		across,
		if inner then LAYER.innerGold else LAYER.outerGold,
		COLOURS.gold,
		parent
	)
	disc(
		"RingFloor",
		at,
		across - width * 2,
		if inner then LAYER.innerMarble else LAYER.outerMarble,
		COLOURS.marble[2],
		parent
	)
end

--[[ The joints of a round floor, so its marble reads as laid and not poured. ]]
local function spokes(
	at: Vector2,
	from: number,
	to: number,
	count: number,
	rng: Random,
	parent: Instance
)
	local start = rng:NextNumber() * math.pi
	for k = 1, count do
		local turn = start + k / count * math.pi * 2
		local out = Vector2.new(math.cos(turn), math.sin(turn))
		strip("Seam", at + out * from, at + out * to, 0.25, LAYER.seam, COLOURS.joint, parent)
	end
end

--[[ The fountain plaza: two gold rings in the floor, then the basin in its
     ring of flowers, the water lilies on its pool, and the tiered fountain in
     the middle. Each building's carpet is laid to the inner ring. ]]
function LobbyCourtyard.plaza(rng: Random, parent: Instance)
	local middle = LobbyConfig.middle
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	local outer = LobbyConfig.plaza
	inlay(middle, outer, 1.6, false, plaza)
	spokes(middle, SPEC.plazaInner / 2, outer / 2 - 1, 16, rng, plaza)
	inlay(middle, SPEC.plazaInner, 1.3, true, plaza)

	local basin = LobbyConfig.fountain
	local foot = world(middle, FLOOR)
	local fountain = Instance.new("Model")
	fountain.Name = "Fountain"
	drum("Rim", foot, 1.8, basin, COLOURS.stone, fountain)
	drum("RimGold", foot + Vector3.new(0, 1.8, 0), 0.25, basin + 0.3, COLOURS.gold, fountain)
	local pool = drum("Pool", foot, 2.15, basin - 2.2, COLOURS.water, fountain)
	pool.CastShadow = false
	for k = 0, 3 do
		local turn = k * math.pi / 2
		local out = Vector3.new(math.sin(turn), 0, math.cos(turn)) * (basin / 2 + 0.2)
		part(
			"RimBlock",
			Vector3.new(2.6, 2.8, 2.6),
			CFrame.new(foot + out + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, turn, 0),
			COLOURS.gold,
			fountain
		)
	end
	-- the tiers
	drum("Pedestal", foot, 4, 8, COLOURS.stone, fountain)
	drum("Band", foot + Vector3.new(0, 3.4, 0), 0.5, 8.4, COLOURS.gold, fountain)
	drum("LowBowl", foot + Vector3.new(0, 4, 0), 1, 11, COLOURS.stone, fountain)
	drum("LowWater", foot + Vector3.new(0, 4, 0), 1.1, 9.6, COLOURS.water, fountain).CastShadow =
		false
	drum("Stem", foot + Vector3.new(0, 4, 0), 4.5, 2.6, COLOURS.stone, fountain)
	drum("HighBowl", foot + Vector3.new(0, 8.3, 0), 0.8, 6, COLOURS.gold, fountain)
	drum("HighWater", foot + Vector3.new(0, 8.3, 0), 0.9, 5, COLOURS.water, fountain).CastShadow =
		false
	local spout = blob(
		"Spout",
		Vector3.new(2, 4, 2),
		CFrame.new(foot + Vector3.new(0, 10.6, 0)),
		COLOURS.foam,
		fountain
	)
	spout.Transparency = 0.15
	spout.CastShadow = false
	-- the water falling from each bowl to the one below
	for k = 0, 7 do
		local turn = k * math.pi / 4
		local out = Vector3.new(math.cos(turn), 0, math.sin(turn))
		for _, sheet in { { r = 3.1, low = 5, high = 8.4 }, { r = 5.6, low = 1.9, high = 4.8 } } do
			local fall = part(
				"Fall",
				Vector3.new(0.9, sheet.high - sheet.low, 0.2),
				CFrame.lookAt(
					foot + out * sheet.r + Vector3.new(0, (sheet.high + sheet.low) / 2, 0),
					foot + Vector3.new(0, (sheet.high + sheet.low) / 2, 0)
				),
				COLOURS.foam,
				fountain
			)
			fall.Transparency = 0.25
			fall.CastShadow = false
		end
	end
	-- the lilies
	for k = 1, SPEC.lilies do
		local turn = k * 2.399
		local out = 6.2 + (k % 3) * 1.6
		local at = middle + Vector2.new(math.cos(turn), math.sin(turn)) * out
		local spot = world(at, FLOOR + 2.2)
		drum("LilyPad", spot, 0.1, rng:NextNumber(1.8, 2.8), COLOURS.moss, fountain).CastShadow =
			false
		if k % 2 == 0 then
			blob(
				"Lily",
				Vector3.new(1, 0.7, 1),
				CFrame.new(spot + Vector3.new(0, 0.3, 0)),
				COLOURS.lily,
				fountain
			).CastShadow =
				false
		end
	end
	-- the ring of leaves and flowers round the rim
	local leaves = COLOURS.leaves
	local round = SPEC.hedge
	for k = 0, round - 1 do
		local turn = (k + 0.5) / round * math.pi * 2
		local spot =
			world(middle + Vector2.new(math.cos(turn), math.sin(turn)) * (basin / 2 + 0.9), FLOOR)
		blob(
			"Leaves",
			Vector3.new(2.2, 1.5, 2),
			CFrame.new(spot + Vector3.new(0, 0.7, 0)),
			leaves[k % #leaves + 1],
			fountain
		).CastShadow =
			false
		blob(
			"Bloom",
			Vector3.new(0.7, 0.5, 0.7),
			CFrame.new(spot + Vector3.new(0, 1.5, 0)),
			if k % 3 == 0 then COLOURS.lily else COLOURS.foam,
			fountain
		).CastShadow =
			false
	end
	fountain.Parent = plaza
	plaza.Parent = parent
	local ring = wall(
		"FountainWall",
		Vector3.new(8, basin + 2.4, basin + 2.4),
		CFrame.new(world(middle, 4)) * CFrame.Angles(0, 0, math.pi / 2),
		parent
	)
	ring.Shape = Enum.PartType.Cylinder
end

--[[ The arrival circle south of the fountain, with its gold-edged walk up to
     the plaza. ]]
function LobbyCourtyard.arrival(rng: Random, parent: Instance)
	local circle = Instance.new("Model")
	circle.Name = "ArrivalCircle"
	local spec = SPEC.arrival
	inlay(spec.at, spec.across, 1.5, false, circle)
	spokes(spec.at, spec.inner / 2, spec.across / 2 - 1, 12, rng, circle)
	inlay(spec.at, spec.inner, 1.1, true, circle)
	-- the walk: two gold lines and a bar across every few studs
	local from = LobbyConfig.middle + Vector2.new(0, LobbyConfig.plaza / 2 - 0.5)
	local to = spec.at - Vector2.new(0, spec.across / 2 - 0.5)
	for _, side in { -1, 1 } do
		local x = Vector2.new(side * spec.walk / 2, 0)
		strip("WalkEdge", from + x, to + x, 0.9, LAYER.outerGold, COLOURS.gold, circle)
	end
	local length = (to - from).Magnitude
	for k = 1, math.floor(length / 5) do
		local at = from + (to - from) * (k / (math.floor(length / 5) + 1))
		strip(
			"WalkBar",
			at - Vector2.new(spec.walk / 2, 0),
			at + Vector2.new(spec.walk / 2, 0),
			0.5,
			LAYER.outerGold,
			COLOURS.gold,
			circle
		)
	end
	circle.Parent = parent
end

--[[ The sheet's red carpets. A northern building's runs from its steps to the
     plaza's inner ring. A southern one has its back to the plaza, so a carpet
     runs from the ring in under it, and a short one from its steps southward. ]]
function LobbyCourtyard.buildingCarpets(parent: Instance)
	local carpets = Instance.new("Model")
	carpets.Name = "Carpets"
	local middle = LobbyConfig.middle
	for _, station in LobbyConfig.stations do
		local design = PalaceBuildings[station.piece]
		if design then
			local yaw = LobbyConfig.facing(station.at)
			local front = Vector2.new(math.sin(yaw), math.cos(yaw))
			local door = station.at + front * (design.front * LobbyConfig.buildingScale - 1)
			local north = station.at.Y < middle.Y
			local from = if north then door else station.at
			local way = (middle - from).Unit
			carpet(from, middle - way * (SPEC.plazaInner / 2 - 0.4), SPEC.carpetWidth, carpets)
			if not north then
				carpet(door, door + front * 14, SPEC.carpetWidth, carpets)
			end
		end
	end
	carpets.Parent = parent
end

--[[ Falling steps with a carpet up their middle: the south way out, which is
     walled at its top for now (the sheet draws it; there is nothing below). ]]
function LobbyCourtyard.southStairs(parent: Instance)
	local stairs = Instance.new("Model")
	stairs.Name = "SouthStairs"
	local gap = SPEC.southGap
	local count = math.ceil(SPEC.drop / 0.8)
	local rise = SPEC.drop / count
	local z = OUTLINE[1].Y
	for _, point in OUTLINE do
		z = math.max(z, point.Y)
	end
	for k = 1, count do
		local top = FLOOR - k * rise
		local height = top - LobbyCourtyard.OUTSIDE
		local at = Vector2.new(0, z + (k - 0.5) * 1.3)
		local step = part(
			"Step",
			Vector3.new(gap * 2, math.max(height, 0.2), 1.3),
			CFrame.new(world(at, LobbyCourtyard.OUTSIDE + height / 2)),
			if k % 2 == 0 then COLOURS.stone else COLOURS.stoneShade,
			stairs
		)
		step.CastShadow = false
		local width = SPEC.walkWidth
		part(
			"StepEdge",
			Vector3.new(width + SPEC.carpetEdge * 2, 0.1, 1.3),
			CFrame.new(world(at, top + 0.05)),
			COLOURS.gold,
			stairs
		).CastShadow =
			false
		part(
			"StepCarpet",
			Vector3.new(width, 0.1, 1.3),
			CFrame.new(world(at, top + 0.1)),
			COLOURS.carpet,
			stairs
		).CastShadow =
			false
	end
	local deep = count * 1.3
	for _, side in { -1, 1 } do
		part(
			"Cheek",
			Vector3.new(2, SPEC.drop + 2.4, deep),
			CFrame.new(
				world(
					Vector2.new(side * (gap + 1), z + deep / 2),
					LobbyCourtyard.OUTSIDE + (SPEC.drop + 2.4) / 2
				)
			),
			COLOURS.stone,
			stairs
		)
	end
	stairs.Parent = parent
end

--[[ One post and its bay of balusters along a stretch of balustrade. Past a
     break the rail is gone, and past a worse one the whole bay is rubble. ]]
local function bay(a: Vector2, b: Vector2, rng: Random, parent: Instance)
	local spec = SPEC.balustrade
	local foot = FLOOR
	local tall = spec.tall
	local way = (b - a).Unit
	local face = CFrame.lookAt(world(a, foot), world(b, foot))
	local length = (b - a).Magnitude
	part(
		"Post",
		Vector3.new(1.7, tall + 0.7, 1.7),
		face * CFrame.new(0, (tall + 0.7) / 2, 0),
		COLOURS.stone,
		parent
	)
	part(
		"PostCap",
		Vector3.new(2.2, 0.4, 2.2),
		face * CFrame.new(0, tall + 0.9, 0),
		COLOURS.stoneShade,
		parent
	)
	local roll = rng:NextNumber()
	if roll < spec.rubble then
		for k = 1, 3 do
			local spot = a
				+ way * rng:NextNumber(1.5, length - 1)
				+ Vector2.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
			part(
				"Rubble",
				Vector3.new(rng:NextNumber(1, 2.4), rng:NextNumber(0.6, 1.2), rng:NextNumber(1, 2)),
				CFrame.new(world(spot, foot + 0.5))
					* CFrame.Angles(
						rng:NextNumber(-0.4, 0.4),
						rng:NextNumber() * 3,
						rng:NextNumber(-0.4, 0.4)
					),
				if k == 1 then COLOURS.stoneShade else COLOURS.stone,
				parent
			)
		end
		return
	end
	local middle = -length / 2
	part(
		"Plinth",
		Vector3.new(1.3, 0.6, length),
		face * CFrame.new(0, 0.3, middle),
		COLOURS.stoneShade,
		parent
	).CastShadow =
		false
	local broken = roll < spec.rubble + spec.broken
	local stand = if broken then math.max(1, math.floor(spec.balusters / 2)) else spec.balusters
	for k = 1, stand do
		local along = -length * k / (spec.balusters + 1)
		local baluster = part(
			"Baluster",
			Vector3.new(0.9, tall - 0.9, 0.9),
			face * CFrame.new(0, 0.6 + (tall - 0.9) / 2, along),
			COLOURS.stone,
			parent
		)
		baluster.CastShadow = false
	end
	if not broken then
		part(
			"Rail",
			Vector3.new(1.5, 0.5, length),
			face * CFrame.new(0, tall - 0.05, middle),
			COLOURS.stone,
			parent
		)
	end
end

--[[ Leaves climbing up to height `tall` round something `round` studs from
     `foot`, and hanging off the top. ]]
local function vines(
	foot: Vector3,
	tall: number,
	round: number,
	count: number,
	rng: Random,
	parent: Instance
)
	local leaves = COLOURS.leaves
	local turn = rng:NextNumber() * math.pi * 2
	for k = 1, count do
		turn += 1.15
		local y = tall * (k - 0.5) / count
		local size = rng:NextNumber(1, 1.7)
		blob(
			"Vine",
			Vector3.new(size * 1.2, size * 0.9, size),
			CFrame.new(foot + Vector3.new(math.cos(turn) * round, y, math.sin(turn) * round)),
			leaves[k % #leaves + 1],
			parent
		).CastShadow =
			false
		if k % 4 == 0 then
			blob(
				"VineBloom",
				Vector3.new(0.5, 0.5, 0.5),
				CFrame.new(
					foot
						+ Vector3.new(
							math.cos(turn) * (round + 0.7),
							y + 0.3,
							math.sin(turn) * (round + 0.7)
						)
				),
				COLOURS.lily,
				parent
			).CastShadow =
				false
		end
	end
end

--[[ A broken white column with a gold band, wrapped in vines. ]]
local function column(at: Vector2, tall: number, foot: number, rng: Random, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "RuinColumn"
	local base = world(at, foot)
	part(
		"Plinth",
		Vector3.new(6.4, 1.2, 6.4),
		CFrame.new(base + Vector3.new(0, 0.6, 0)),
		COLOURS.stoneShade,
		model
	)
	part(
		"Plinth",
		Vector3.new(5.4, 0.7, 5.4),
		CFrame.new(base + Vector3.new(0, 1.5, 0)),
		COLOURS.stone,
		model
	)
	local shaft = base + Vector3.new(0, 1.8, 0)
	drum("Shaft", shaft, tall, 4.4, COLOURS.stone, model)
	drum("GoldBand", shaft + Vector3.new(0, tall * 0.58, 0), 1, 4.8, COLOURS.gold, model)
	drum("GoldBand", shaft + Vector3.new(0, 0.6, 0), 0.5, 4.7, COLOURS.gold, model)
	-- the broken top: two tilted lumps of the shaft, never a clean cut
	local top = shaft + Vector3.new(0, tall, 0)
	part(
		"BrokenTop",
		Vector3.new(3.6, 1.6, 2.8),
		CFrame.new(top + Vector3.new(0.3, 0.3, 0.2))
			* CFrame.Angles(0.25, rng:NextNumber() * 3, 0.2),
		COLOURS.stone,
		model
	)
	part(
		"BrokenTop",
		Vector3.new(2, 1.3, 1.8),
		CFrame.new(top + Vector3.new(-0.5, 1, -0.3))
			* CFrame.Angles(-0.3, rng:NextNumber() * 3, 0.4),
		COLOURS.stoneShade,
		model
	)
	vines(shaft, tall + 1.5, 2.3, math.floor(tall * 1.1), rng, model)
	blob(
		"Tuft",
		Vector3.new(5.4, 2.4, 4.8),
		CFrame.new(top + Vector3.new(-0.3, 1.5, 0.2)),
		COLOURS.leaves[2],
		model
	).CastShadow =
		false
	model.Parent = parent
end

--[[ A ruined arch past the balustrade: two columns and what is left of the
     beam across them. ]]
local function ruinArch(at: Vector2, rng: Random, parent: Instance)
	local spec = SPEC.ruinArch
	local foot = LobbyCourtyard.OUTSIDE
	local model = Instance.new("Model")
	model.Name = "RuinArch"
	for _, side in { -1, 1 } do
		column(at + Vector2.new(side * spec.across / 2, 0), spec.tall, foot, rng, model)
	end
	local y = foot + spec.tall + 2.2
	part(
		"Beam",
		Vector3.new(spec.across * 0.75, 2.2, 3.2),
		CFrame.new(world(at - Vector2.new(spec.across * 0.1, 0), y)) * CFrame.Angles(0, 0, 0.03),
		COLOURS.stone,
		model
	)
	part(
		"BeamGold",
		Vector3.new(spec.across * 0.75, 0.4, 3.4),
		CFrame.new(world(at - Vector2.new(spec.across * 0.1, 0), y - 1.1)),
		COLOURS.gold,
		model
	)
	vines(world(at, y + 1), 1, spec.across * 0.25, 8, rng, model)
	model.Parent = parent
end

--[[ The low broken balustrade, its kerb and the wall below it down to the
     ground past it, and a wall for players along all of it. The edges listed
     `open` are the terrace's front and the south stairs' top; the stairs' top
     keeps its player wall. ]]
function LobbyCourtyard.balustrade(rng: Random, parent: Instance)
	local ruin = Instance.new("Model")
	ruin.Name = "Balustrade"
	local spec = SPEC.balustrade
	for k, a in OUTLINE do
		local b = OUTLINE[k % #OUTLINE + 1]
		local length = (b - a).Magnitude
		local middle = (a + b) / 2
		local along = (b - a).Unit
		local outward = Vector2.new(-along.Y, along.X)
		if SPEC.terraceEdge ~= k then
			wall(
				"Edge",
				Vector3.new(2, 30, length + 4),
				CFrame.lookAt(world(middle + outward, 15), world(b + outward, 15)),
				parent
			)
		end
		if table.find(SPEC.openEdges, k) then
			continue
		end
		local drop = SPEC.drop
		local y = LobbyCourtyard.OUTSIDE + drop / 2
		part(
			"Retaining",
			Vector3.new(1.6, drop, length + 1.2),
			CFrame.lookAt(world(middle + outward * 0.5, y), world(b + outward * 0.5, y)),
			COLOURS.stoneShade,
			ruin
		).CastShadow =
			false
		strip("Kerb", a - outward * 0.8, b - outward * 0.8, 3, LAYER.moss, COLOURS.stoneShade, ruin)
		local bays = math.max(1, math.round(length / spec.bay))
		for j = 1, bays do
			bay(a + (b - a) * ((j - 1) / bays), a + (b - a) * (j / bays), rng, ruin)
		end
	end
	ruin.Parent = parent
end

--[[ The columns the sheet stands along the balustrade, and the two ruined
     arches past its northern corners. ]]
function LobbyCourtyard.ruins(rng: Random, parent: Instance)
	local ruins = Instance.new("Model")
	ruins.Name = "Ruins"
	for _, spot in SPEC.columns do
		column(spot.at, spot.tall, FLOOR, rng, ruins)
	end
	for _, at in SPEC.ruinArch.at do
		ruinArch(at, rng, ruins)
	end
	ruins.Parent = parent
end

--[[ The sky over the lobby: clouds and a sun. The camera never sees the sky in
     a room, so these stay up for the whole game. ]]
function LobbyCourtyard.sky()
	local spec = LobbyConfig.sky
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = spec.sunSize
	sky.MoonAngularSize = 0
	sky.SkyboxBk = spec.skybox.SkyboxBk
	sky.SkyboxDn = spec.skybox.SkyboxDn
	sky.SkyboxFt = spec.skybox.SkyboxFt
	sky.SkyboxLf = spec.skybox.SkyboxLf
	sky.SkyboxRt = spec.skybox.SkyboxRt
	sky.SkyboxUp = spec.skybox.SkyboxUp
	sky.Parent = Lighting
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = spec.cloudCover
	clouds.Density = spec.cloudDensity
	clouds.Color = Color3.new(1, 1, 1)
	clouds.Enabled = spec.cloudsShown
	clouds.Parent = Workspace.Terrain
end

return LobbyCourtyard
