--!strict
--[[
	The lobby (`Config/Lobby`): built once at boot beside the arena, where
	players arrive after BEGIN ADVENTURE,
	and where stepping into an active portal starts that area's run.

	- `build` lays the clearing out: lawn tiles, dirt paths, the stations,
	  the portal terrace and its arches, a ring of trees and cliffs with
	  waterfalls, a scatter of bushes, rocks and glowing mushrooms, and
	  invisible walls round the edge and round each station. A piece whose
	  mesh is not imported yet is left out.
	- `place` puts a character at the campfire.
	- `portalFor` says which active portal a player is standing in, if any.

	Seeded, so the lobby is the same every time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)

local Lobby = {}

local ORIGIN = LobbyConfig.origin
local templates: { [string]: MeshPart } = {}
local folder: Folder? = nil

--[[ The forest round the edge casts no shadow: the lobby's low sun laid
     its trees' and cliffs' shadows across the whole lawn in stripes,
     which the sheet does not have. ]]
local SHADOWLESS = { LobbyTree = true, CliffBlock = true, Waterfall = true }
--[[ Glow that is drawn lit but not Neon: the waterfall's water and the
     hatchery's moss and fountain burned white as Neon, where the sheet has
     them blue and pale green. ]]
local SOFT_GLOW = { Waterfall = true, EggHatchery = true }

--[[ The lawn's top, a little above the place's Baseplate (whose top is
     y = 0 and reaches under the lobby's north half): level with it, the
     two flickered across the lawn in grey stripes. ]]
local LAWN = 0.1

local function world(at: Vector2, y: number?): Vector3
	return ORIGIN + Vector3.new(at.X, y or 0, at.Y)
end

--[[ Which row arch `index` stands in: 1 the front, 2 the back. ]]
function Lobby.rowOf(index: number): number
	return math.ceil(index / LobbyConfig.perRow)
end

--[[ The centre of row `row`'s terrace, and how high it stands. ]]
local function rowCentre(row: number): (Vector2, number)
	return LobbyConfig.terrace - Vector2.new(0, (row - 1) * LobbyConfig.rowDepth),
		(row - 1) * LobbyConfig.rowRise
end

--[[ Where arch `index` stands: front row west to east, then the back. ]]
function Lobby.archAt(index: number): Vector2
	local perRow = LobbyConfig.perRow
	local column = (index - 1) % perRow + 1
	local offset = (column - (perRow + 1) / 2) * LobbyConfig.archSpacing
	return rowCentre(Lobby.rowOf(index)) + Vector2.new(offset, 0)
end

local function block(
	name: string,
	size: Vector3,
	centre: Vector3,
	colour: Color3?,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = centre
	part.CastShadow = false
	if colour then
		part.Color = colour
		part.Material = Enum.Material.Fabric
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	else
		-- an invisible wall
		part.Transparency = 1
		part.CanCollide = true
		part.CanQuery = false
		part.CanTouch = false
	end
	part.Parent = parent
	return part
end

--[[ A kit piece at `at`, turned `yaw`, grown `grow` times; returns its
     footprint in studs, or nil when its mesh is not there. ]]
local function piece(
	name: string,
	at: Vector2,
	yaw: number,
	grow: number,
	parent: Instance,
	tint: Color3?,
	lift: number?
): Vector3?
	local spec = LobbyConfig.pieces[name]
	if not spec then
		return nil
	end
	local template = templates[spec.meshId]
	if not template then
		return nil
	end
	local size = spec.size * LobbyConfig.scale * grow
	local part = template:Clone()
	part.Name = name
	part.Size = size
	-- the importer turns each mesh half round; turned back
	part.CFrame = CFrame.new(world(at, (lift or 0) + size.Y / 2))
		* CFrame.Angles(0, yaw + math.pi, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = tint or spec.tint or Color3.new(1, 1, 1)
	part.Material = Enum.Material.SmoothPlastic
	part.CastShadow = not SHADOWLESS[name]
	if name == "PortalSwirl" then
		-- all glow, in its portal's colour
		part.Material = Enum.Material.Neon
		part.CastShadow = false
	end
	part.Parent = parent
	local glow = spec.glow
	if glow then
		local light = templates[glow.meshId]
		if light then
			local g = light:Clone()
			g.Name = name .. "Glow"
			g.Size = glow.size * LobbyConfig.scale * grow
			local centre = CFrame.Angles(0, yaw, 0)
				:VectorToWorldSpace(glow.centre * LobbyConfig.scale * grow)
			g.CFrame = CFrame.new(world(at, lift) + centre) * CFrame.Angles(0, yaw + math.pi, 0)
			g.Anchored = true
			g.CanCollide = false
			g.CanQuery = false
			g.CanTouch = false
			g.Material = if SOFT_GLOW[name] then Enum.Material.SmoothPlastic else Enum.Material.Neon
			g.Color = tint or Color3.new(1, 1, 1)
			g.CastShadow = false
			g.Parent = parent
		end
	end
	return size
end

local function near(a: Vector2, list: { Vector2 }, reach: number): boolean
	for _, b in list do
		if (a - b).Magnitude < reach then
			return true
		end
	end
	return false
end

function Lobby.build(parent: Instance)
	local ids = {}
	for _, spec in LobbyConfig.pieces do
		table.insert(ids, spec.meshId)
		if spec.glow then
			table.insert(ids, spec.glow.meshId)
		end
	end
	templates = MeshTemplates.load(ids)

	local existing = parent:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Lobby"
	local rng = Random.new(20261025)
	local half = LobbyConfig.size / 2

	-- the lawn
	local tile = LobbyConfig.tile
	local across = math.ceil((LobbyConfig.size.X + 24) / tile)
	local deep = math.ceil((LobbyConfig.size.Y + 24) / tile)
	for i = 0, across - 1 do
		for j = 0, deep - 1 do
			local at = Vector2.new(-half.X - 12 + (i + 0.5) * tile, -half.Y - 12 + (j + 0.5) * tile)
			block(
				"Tile",
				Vector3.new(tile, 1, tile),
				world(at, LAWN - 0.5),
				LobbyConfig.lawn[rng:NextInteger(1, #LobbyConfig.lawn)],
				root
			)
		end
	end
	-- a floor to stand on, level with the lawn the whole way across
	local floor = block(
		"Floor",
		Vector3.new(LobbyConfig.size.X + 40, 1, LobbyConfig.size.Y + 40),
		world(Vector2.zero, LAWN - 0.55),
		nil,
		root
	)
	floor.CanQuery = true

	-- the dirt paths, in blocks
	local trail: { Vector2 } = {}
	for _, path in LobbyConfig.paths do
		for k = 1, #path - 1 do
			local a, b = path[k], path[k + 1]
			local steps = math.max(1, math.floor((b - a).Magnitude / 2))
			for s = 0, steps do
				local at = a:Lerp(b, s / steps)
				table.insert(trail, at)
				local side = 4 + rng:NextNumber() * 1.5
				block(
					"Dirt",
					Vector3.new(side, 0.06, side),
					world(
						at + Vector2.new(rng:NextNumber() - 0.5, rng:NextNumber() - 0.5),
						LAWN + 0.03
					),
					LobbyConfig.dirt[rng:NextInteger(1, #LobbyConfig.dirt)],
					root
				)
			end
		end
	end

	-- the stations, each with a wall round its footprint
	local taken: { Vector2 } = { LobbyConfig.spawn }
	for _, station in LobbyConfig.stations do
		local size = piece(station.piece, station.at, station.yaw or 0, 1, root)
		table.insert(taken, station.at)
		if size and station.piece ~= "SpawnCampfire" then
			block(
				"StationWall",
				Vector3.new(size.X * 0.9, 8, size.Z * 0.8),
				world(station.at, 4),
				nil,
				root
			)
		end
	end

	-- the portal terraces, each row's arches, and steps up to the back row
	local unit = LobbyConfig.scale
	local rows = Lobby.rowOf(#LobbyConfig.portals)
	local platform = LobbyConfig.archLift * unit
	local ahead = Vector2.new(0, LobbyConfig.terraceAhead * unit)
	for row = 1, rows do
		local centre, rise = rowCentre(row)
		local size = piece("PortalTerrace", centre + ahead, 0, 1, root, nil, rise)
		if size then
			-- its platform, to stand on
			local stand = block(
				"TerraceFloor",
				Vector3.new(size.X, rise + platform, size.Z),
				world(centre + ahead, (rise + platform) / 2),
				nil,
				root
			)
			stand.CanQuery = true
		end
		if rise > 0 then
			-- steps up from the front row, behind its middle arches
			for _, side in { -1, 1 } do
				local at = centre
					+ ahead
					+ Vector2.new(side * LobbyConfig.archSpacing / 2, LobbyConfig.rowDepth / 2)
				piece("PortalSteps", at, 0, 1, root, nil, platform)
			end
		end
	end
	for index, portal in LobbyConfig.portals do
		local at = Lobby.archAt(index)
		local _, rise = rowCentre(Lobby.rowOf(index))
		local lift = rise + platform
		table.insert(taken, at)
		piece("PortalArch", at, 0, 1, root, nil, lift)
		if portal.stage then
			piece("PortalSwirl", at, 0, 1, root, portal.tint, lift + LobbyConfig.swirlLift * unit)
			if portal.sign then
				local sign = at + Vector2.new(0, LobbyConfig.signAhead * unit)
				piece(portal.sign, sign, 0, 1, root, nil, lift + LobbyConfig.signLift * unit)
			end
		else
			local lock = at + Vector2.new(0, LobbyConfig.lockAhead * unit)
			piece("PortalLock", lock, 0, 1, root, nil, lift)
		end
	end
	-- nobody walks behind the back row
	local back = rowCentre(rows)
	block(
		"TerraceWall",
		Vector3.new(LobbyConfig.size.X, 10, 4),
		world(back + Vector2.new(0, -4), 5),
		nil,
		root
	)

	-- the forest ring, with its waterfalls
	for _, at in LobbyConfig.waterfalls do
		piece("Waterfall", at, if at.X < 0 then math.pi / 2 else -math.pi / 2, 1, root)
	end
	local spacing = LobbyConfig.ringSpacing
	local function ring(at: Vector2)
		if near(at, LobbyConfig.waterfalls, spacing) then
			return
		end
		local kind = if rng:NextNumber() < 0.65 then "LobbyTree" else "CliffBlock"
		piece(kind, at, rng:NextNumber() * math.pi * 2, 0.85 + rng:NextNumber() * 0.4, root)
	end
	for x = -half.X, half.X, spacing do
		ring(Vector2.new(x, -half.Y - 6))
		ring(Vector2.new(x, half.Y + 6))
	end
	for z = -half.Y, half.Y, spacing do
		ring(Vector2.new(-half.X - 6, z))
		ring(Vector2.new(half.X + 6, z))
	end

	-- the lawn's scatter, clear of the stations, portals and paths
	for name: string, count: number in LobbyConfig.scatter :: { [string]: number } do
		local placed = 0
		for _ = 1, count * 20 do
			if placed >= count then
				break
			end
			local at = Vector2.new(
				(rng:NextNumber() * 2 - 1) * (half.X - 4),
				(rng:NextNumber() * 2 - 1) * (half.Y - 4)
			)
			if near(at, taken, 15) or near(at, trail, 4.5) or at.Y < LobbyConfig.terrace.Y + 6 then
				continue
			end
			piece(name, at, rng:NextNumber() * math.pi * 2, 0.8 + rng:NextNumber() * 0.5, root)
			placed += 1
		end
	end

	-- the walls round the clearing
	local wall = 4
	block(
		"WallNorth",
		Vector3.new(LobbyConfig.size.X + 2 * wall, 12, wall),
		world(Vector2.new(0, -half.Y - wall / 2), 6),
		nil,
		root
	)
	block(
		"WallSouth",
		Vector3.new(LobbyConfig.size.X + 2 * wall, 12, wall),
		world(Vector2.new(0, half.Y + wall / 2), 6),
		nil,
		root
	)
	block(
		"WallWest",
		Vector3.new(wall, 12, LobbyConfig.size.Y),
		world(Vector2.new(-half.X - wall / 2, 0), 6),
		nil,
		root
	)
	block(
		"WallEast",
		Vector3.new(wall, 12, LobbyConfig.size.Y),
		world(Vector2.new(half.X + wall / 2, 0), 6),
		nil,
		root
	)

	root.Parent = parent
	folder = root
end

--[[ Puts a character at the campfire, facing the portals. ]]
function Lobby.place(character: Model)
	local at = world(LobbyConfig.spawn, 3)
	character:PivotTo(CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
end

--[[ The stage of the active portal `position` stands in, or nil. ]]
function Lobby.portalFor(position: Vector3): number?
	for index, portal in LobbyConfig.portals do
		if portal.stage then
			local mouth = world(Lobby.archAt(index) + Vector2.new(0, 2))
			local flat = Vector3.new(position.X - mouth.X, 0, position.Z - mouth.Z)
			if flat.Magnitude <= LobbyConfig.portalReach then
				return portal.stage
			end
		end
	end
	return nil
end

--[[ Whether `position` is in the lobby rather than the arena. ]]
function Lobby.contains(position: Vector3): boolean
	local relative = position - ORIGIN
	return math.abs(relative.X) < LobbyConfig.size.X and math.abs(relative.Z) < LobbyConfig.size.Y
end

function Lobby.folder(): Folder?
	return folder
end

return Lobby
