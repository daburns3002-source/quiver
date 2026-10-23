--!strict
--[[
	Finds a way around the room's cover for an enemy that cannot walk straight
	at its target (owner, 2026-10-23: "make sure the ai for the enemies finds
	a way around an obstacle, they are getting stuck").

	Sliding along whatever face an enemy bumped into was the only steering,
	and it failed wherever cover had a corner to fall into: a boulder beside a
	boulder, a pillar beside a wall, the long edge of the pond. Measured over
	Level 1's five room shapes, 28 of 165 Moss Slimes reached a player hiding
	behind cover.

	A walkable grid is laid over the floor, one cell a stud, for each body
	size, against the room's own collision (`Arena.isClear`), and rebuilt
	whenever a room is built. A* finds the cells between two points, eight
	ways with no corner-cutting past a blocked cell, and the route is pulled
	tight to the fewest straight legs a body of that size can walk.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Parent.Arena.Arena)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.forTag("Pathing")

local Pathing = {}

--[[ Studs per grid cell: fine enough to find a gap a body fits through,
     coarse enough that a room is a couple of thousand cells. ]]
local CELL = 1

--[[ A cap on the cells A* may open per search, so a target walled off
     entirely costs a bounded amount and returns nothing. ]]
local MAX_EXPANDED = 4000

type Grid = {
	version: number,
	columns: number,
	rows: number,
	originX: number,
	originZ: number,
	walkable: { boolean },
}

--[[ One grid per body size (radius to a tenth of a stud), per room. ]]
local grids: { [number]: Grid } = {}

local function key(radius: number): number
	return math.floor(radius * 10 + 0.5)
end

local function grid(radius: number): Grid
	local version = Arena.layoutVersion()
	local k = key(radius)
	local existing = grids[k]
	if existing and existing.version == version then
		return existing
	end

	local half = Arena.halfSize()
	local columns = math.max(1, math.floor(half.X * 2 / CELL))
	local rows = math.max(1, math.floor(half.Y * 2 / CELL))
	local originX = -half.X + (half.X * 2 - columns * CELL) / 2 + CELL / 2
	local originZ = -half.Y + (half.Y * 2 - rows * CELL) / 2 + CELL / 2
	local walkable: { boolean } = table.create(columns * rows, false)

	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			local at = Vector3.new(originX + column * CELL, 0, originZ + row * CELL)
			walkable[row * columns + column + 1] = Arena.isClear(at, radius)
		end
	end

	local built: Grid = {
		version = version,
		columns = columns,
		rows = rows,
		originX = originX,
		originZ = originZ,
		walkable = walkable,
	}
	grids[k] = built
	return built
end

local function cellOf(g: Grid, position: Vector3): (number, number)
	local column = math.clamp(math.floor((position.X - g.originX) / CELL + 0.5), 0, g.columns - 1)
	local row = math.clamp(math.floor((position.Z - g.originZ) / CELL + 0.5), 0, g.rows - 1)
	return column, row
end

local function open(g: Grid, column: number, row: number): boolean
	if column < 0 or row < 0 or column >= g.columns or row >= g.rows then
		return false
	end
	return g.walkable[row * g.columns + column + 1]
end

local function centre(g: Grid, column: number, row: number): Vector3
	return Vector3.new(g.originX + column * CELL, 0, g.originZ + row * CELL)
end

--[[ The nearest walkable cell to one that is not: a body pressed against
     cover, or a target standing in a gap too narrow for this body, still
     gets a route that ends as close as it can. ]]
local function nearestOpen(g: Grid, column: number, row: number): (number?, number?)
	if open(g, column, row) then
		return column, row
	end
	for ring = 1, 6 do
		local best: number? = nil
		local bestColumn, bestRow = nil, nil
		for dc = -ring, ring do
			for dr = -ring, ring do
				if
					math.max(math.abs(dc), math.abs(dr)) == ring and open(g, column + dc, row + dr)
				then
					local d = dc * dc + dr * dr
					if not best or d < best then
						best, bestColumn, bestRow = d, column + dc, row + dr
					end
				end
			end
		end
		if bestColumn then
			return bestColumn, bestRow
		end
	end
	return nil, nil
end

local NEIGHBOURS = {
	{ 1, 0, 1 },
	{ -1, 0, 1 },
	{ 0, 1, 1 },
	{ 0, -1, 1 },
	{ 1, 1, math.sqrt(2) },
	{ 1, -1, math.sqrt(2) },
	{ -1, 1, math.sqrt(2) },
	{ -1, -1, math.sqrt(2) },
}

--[[ A binary heap of cell indices ordered by `score`. ]]
local function push(heap: { number }, score: { [number]: number }, item: number)
	table.insert(heap, item)
	local i = #heap
	while i > 1 do
		local parent = i // 2
		if score[heap[parent]] <= score[heap[i]] then
			break
		end
		heap[parent], heap[i] = heap[i], heap[parent]
		i = parent
	end
end

local function pop(heap: { number }, score: { [number]: number }): number
	local top = heap[1]
	local last = table.remove(heap) :: number
	if #heap > 0 then
		heap[1] = last
		local i = 1
		while true do
			local left, right = i * 2, i * 2 + 1
			local smallest = i
			if left <= #heap and score[heap[left]] < score[heap[smallest]] then
				smallest = left
			end
			if right <= #heap and score[heap[right]] < score[heap[smallest]] then
				smallest = right
			end
			if smallest == i then
				break
			end
			heap[smallest], heap[i] = heap[i], heap[smallest]
			i = smallest
		end
	end
	return top
end

--[[
	The straight legs a body of `radius` can walk from `from` to `to`, as
	waypoints after `from` (the last is `to`, or the nearest reachable point
	to it). Nil if no route exists. Y is zero; callers keep their own height.
]]
function Pathing.find(from: Vector3, to: Vector3, radius: number): { Vector3 }?
	local g = grid(radius)
	local sc, sr = cellOf(g, from)
	local gc, gr = cellOf(g, to)
	local startColumn, startRow = nearestOpen(g, sc, sr)
	local goalColumn, goalRow = nearestOpen(g, gc, gr)
	if not startColumn or not startRow or not goalColumn or not goalRow then
		return nil
	end

	local columns = g.columns
	local function index(column: number, row: number): number
		return row * columns + column + 1
	end
	local start, goal = index(startColumn, startRow), index(goalColumn, goalRow)

	local cost: { [number]: number } = { [start] = 0 }
	local score: { [number]: number } = {}
	local cameFrom: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local heap: { number } = {}

	local function heuristic(column: number, row: number): number
		local dx, dy = math.abs(column - goalColumn), math.abs(row - goalRow)
		return math.max(dx, dy) + (math.sqrt(2) - 1) * math.min(dx, dy)
	end

	score[start] = heuristic(startColumn, startRow)
	push(heap, score, start)
	local expanded = 0

	while #heap > 0 do
		local current = pop(heap, score)
		if current == goal then
			break
		end
		if closed[current] then
			continue
		end
		closed[current] = true
		expanded += 1
		if expanded > MAX_EXPANDED then
			log.warn("search gave up after %d cells", expanded)
			return nil
		end

		local column = (current - 1) % columns
		local row = (current - 1) // columns
		for _, n in NEIGHBOURS do
			local nc, nr = column + n[1], row + n[2]
			-- No cutting a corner past a blocked cell.
			if
				open(g, nc, nr)
				and (
					n[1] == 0
					or n[2] == 0
					or (open(g, column + n[1], row) and open(g, column, row + n[2]))
				)
			then
				local neighbour = index(nc, nr)
				local through = cost[current] + n[3]
				if not closed[neighbour] and through < (cost[neighbour] or math.huge) then
					cost[neighbour] = through
					cameFrom[neighbour] = current
					score[neighbour] = through + heuristic(nc, nr)
					push(heap, score, neighbour)
				end
			end
		end
	end

	if start ~= goal and not cameFrom[goal] then
		return nil
	end

	-- Walk back from the goal, then pull the route tight.
	local cells: { Vector3 } = {}
	local at = goal
	while at do
		local column = (at - 1) % columns
		local row = (at - 1) // columns
		table.insert(cells, 1, centre(g, column, row))
		at = cameFrom[at]
	end
	if goal == index(gc, gr) then
		cells[#cells] = Vector3.new(to.X, 0, to.Z)
	end

	local route: { Vector3 } = {}
	local anchor = Vector3.new(from.X, 0, from.Z)
	local i = 1
	while i <= #cells do
		-- The furthest cell still in a straight, clear line from the anchor.
		local reach = i
		for j = #cells, i, -1 do
			if Arena.isSegmentClear(anchor, cells[j], radius) then
				reach = j
				break
			end
		end
		table.insert(route, cells[reach])
		anchor = cells[reach]
		i = reach + 1
	end
	return route
end

return Pathing
