--!strict
--[[
	King Bloblin's effects, all cubes and square tiles (the owner's design
	pages: Royal Bounce's `royal-bounce-fx.js`, King Bloblin Fight's lash),
	numbers in `Balance.Telegraph.king`.

	Two kinds, both presentation only:

	- **Warnings and impacts**, drawn from the server's telegraphs
	  (`TelegraphRenderer` hands them here): the slam's tile circle and its
	  landing (flash, shockwave, debris, dust); the lash's tile lane, the
	  fist's splat, the goo, the grab and the chest bump.
	- **The body's own beats**, read off the clip the server says he is
	  playing (`ModelClip`): eyes that flare in a wind-up and dim when
	  winded, gems that flash, the lashing arm's glow, the gold cubes that
	  pop off his crown, and the cube stars that circle him while winded.

	Decorative cubes are scaled by the tier's `bossFxShare`; the warnings
	are drawn in full on every device, since they are the counterplay.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)

local BossFx = {}

local K = Balance.Telegraph.king

type Updater = (now: number) -> boolean

--[[ Effects that move each frame: each returns false when it is done. ]]
local updaters: { Updater } = {}
local stepping: RBXScriptConnection? = nil

local function animate(update: Updater)
	table.insert(updaters, update)
	if stepping then
		return
	end
	stepping = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #updaters, 1, -1 do
			local ok, alive = pcall(updaters[i], now)
			if not ok or not alive then
				table.remove(updaters, i)
			end
		end
		if #updaters == 0 and stepping then
			stepping:Disconnect()
			stepping = nil
		end
	end)
end

local function cube(parent: Instance, size: Vector3, colour: Color3, neon: boolean?): BasePart
	local part = Instance.new("Part")
	part.Name = "BossFx"
	part.Shape = Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = colour
	part.Size = size
	part.Parent = parent
	return part
end

--[[ How many of `count` decorative cubes this device draws (at least one). ]]
local function share(count: number): number
	return math.max(1, math.floor(count * Device.tier().bossFxShare + 0.5))
end

local function between(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function flatAt(origin: Vector3, height: number): Vector3
	return Vector3.new(origin.X, height, origin.Z)
end

local function spin(): CFrame
	return CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
end

--[[
	The cells of a disc of `radius` studs on a grid of `tile`, and which of
	them are its edge (a cell with a neighbour outside). Pure, exposed for
	the spec: the warning must cover the whole circle the slam hits.
]]
function BossFx.discCells(radius: number, tile: number): { { x: number, z: number, edge: boolean } }
	local n = math.ceil(radius / tile)
	local function inside(i: number, j: number): boolean
		local x, z = i * tile, j * tile
		return x * x + z * z <= radius * radius
	end
	local cells = {}
	for i = -n, n do
		for j = -n, n do
			if inside(i, j) then
				local edge = not (
					inside(i + 1, j)
					and inside(i - 1, j)
					and inside(i, j + 1)
					and inside(i, j - 1)
				)
				table.insert(cells, { x = i * tile, z = j * tile, edge = edge })
			end
		end
	end
	return cells
end

--[[ The slam's warning: a stepped circle of tiles at full size from the
     first frame, fading in, its edge pulsing faster as the fall nears,
     and a white-gold flash on it as he lands. ]]
function BossFx.slamWarning(parent: Instance, origin: Vector3, duration: number, radius: number)
	local colour = Balance.Telegraph.bossColor
	local tile = K.tile
	local holder = Instance.new("Folder")
	holder.Name = "SlamWarning"
	holder.Parent = parent
	local fill: { BasePart } = {}
	local edge: { BasePart } = {}
	for _, cell in BossFx.discCells(radius, tile) do
		local part = cube(holder, Vector3.new(tile * 0.92, 0.12, tile * 0.92), colour, true)
		part.Position = Vector3.new(origin.X + cell.x, 0.14, origin.Z + cell.z)
		part.Transparency = 1
		table.insert(if cell.edge then edge else fill, part)
	end
	local started = os.clock()
	local phase = 0
	local last = started
	animate(function(now)
		if not holder.Parent then
			return false
		end
		local share01 = (now - started) / duration
		if share01 >= 1 then
			-- landed: flash and fade
			local f = (now - started - duration) / K.flashTime
			if f >= 1 then
				holder:Destroy()
				return false
			end
			for _, part in fill do
				part.Color = K.flashColor
				part.Transparency = 0.2 + 0.8 * f
			end
			for _, part in edge do
				part.Color = K.flashColor
				part.Transparency = 0.8 * f
			end
			return true
		end
		local fade = math.min(1, share01 / K.tileFadeIn)
		local fall = math.max(0, (share01 - K.tileFadeIn) / (1 - K.tileFadeIn))
		phase += (now - last) * (K.pulseFrom + (K.pulseTo - K.pulseFrom) * fall) * 2 * math.pi
		last = now
		local beat = 0.5 + 0.5 * math.sin(phase)
		--[[ The fill brightens toward the slam; the edge pulses. ]]
		local fillAlpha = 0.85 - 0.35 * fade - 0.15 * share01
		for _, part in fill do
			part.Transparency = fillAlpha
		end
		local edgeAlpha = (0.9 - 0.65 * fade) - 0.25 * beat * fall
		for _, part in edge do
			part.Transparency = math.max(0, edgeAlpha)
		end
		return true
	end)
end

--[[ He landed: a ring of cubes rushing out from the circle's edge to
     `shockRadius`, debris popping up off the far edge, dust thrown out. ]]
function BossFx.slamImpact(
	parent: Instance,
	origin: Vector3,
	duration: number,
	shockRadius: number,
	radius: number
)
	local ground = flatAt(origin, 0)
	-- shockwave
	local count = share(K.shockCubes)
	local ring: { BasePart } = {}
	for _ = 1, count do
		table.insert(ring, cube(parent, Vector3.one * K.shockFrom, K.shockLime, true))
	end
	local started = os.clock()
	local time = duration
	animate(function(now)
		local t = (now - started) / time
		if t >= 1 then
			for _, part in ring do
				part:Destroy()
			end
			return false
		end
		local e = ease(t)
		local r = radius + (shockRadius - radius) * e
		local size = K.shockFrom + (K.shockTo - K.shockFrom) * e
		for i, part in ring do
			local a = (i - 1) / count * 2 * math.pi
			part.Size = Vector3.one * size
			part.CFrame = CFrame.new(
				ground + Vector3.new(math.cos(a) * r, size / 2, math.sin(a) * r)
			) * CFrame.Angles(0, -a, 0)
			part.Color = K.shockLime:Lerp(K.shockGold, e)
			part.Transparency = 0.6 * t
		end
		return true
	end)

	-- debris: off the far half of the edge (away from the camera, -Z)
	local debrisColours = { K.moss, K.moss, K.moss, K.tan, K.tan, K.gold, K.gold }
	for i = 1, share(K.debrisCubes) do
		local a = math.pi + (i - 0.5) / share(K.debrisCubes) * math.pi
		local from = ground + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius + 0.5)
		local out = Vector3.new(math.cos(a), 0, math.sin(a)) * (1 + math.random())
		local size = between(K.debrisSize)
		local part = cube(parent, Vector3.one * size, debrisColours[(i - 1) % #debrisColours + 1])
		local tumble = spin()
		local born = os.clock()
		animate(function(now)
			local t = (now - born) / K.debrisTime
			if t >= 1 then
				part:Destroy()
				return false
			end
			local lift = K.debrisRise * 4 * t * (1 - t)
			part.CFrame = CFrame.new(from + out * t + Vector3.new(0, size / 2 + lift, 0))
				* tumble
				* CFrame.Angles(t * 4, t * 3, 0)
			part.Transparency = math.max(0, (t - 0.7) / 0.3)
			return true
		end)
	end

	-- dust: tan and moss bits thrown out across the floor
	for i = 1, share(K.dustCubes) do
		local a = math.random() * 2 * math.pi
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local reach = between(K.dustReach)
		local size = between(K.dustSize)
		local part = cube(parent, Vector3.one * size, if i % 2 == 0 then K.tan else K.moss)
		local from = ground + dir * (radius * 0.6)
		local born = os.clock()
		local tumble = spin()
		animate(function(now)
			local t = (now - born) / K.dustTime
			if t >= 1 then
				part:Destroy()
				return false
			end
			local go = 1 - (1 - t) ^ 2
			local lift = 1.5 * 4 * t * (1 - t)
			part.CFrame = CFrame.new(
				from + dir * (reach - radius * 0.6) * go + Vector3.new(0, size / 2 + lift, 0)
			) * tumble
			part.Transparency = math.max(0, (t - 0.6) / 0.4)
			return true
		end)
	end
end

--[[
	A lash's lane, as tiles: 3.5 across in four columns, its first and last
	rows stepped in to the middle two. Pure, exposed for the spec: every
	tile lies inside the lane the server hits.
]]
function BossFx.laneCells(
	length: number,
	width: number,
	tile: number
): { { along: number, across: number } }
	local columns = math.max(1, math.floor(width / tile + 1e-6))
	local rows = math.max(1, math.ceil(length / tile - 1e-6))
	local cells = {}
	for row = 1, rows do
		local along = (row - 0.5) * length / rows
		for column = 1, columns do
			local stepped = (row == 1 or row == rows) and columns > 2
			if stepped and (column == 1 or column == columns) then
				continue
			end
			table.insert(cells, { along = along, across = (column - (columns + 1) / 2) * tile })
		end
	end
	return cells
end

type Lane = {
	holder: Folder,
	tiles: { BasePart },
	rows: { number },
	rowCount: number,
	started: number,
	expires: number,
	locked: boolean,
	lockedAt: number,
}

local lane: Lane? = nil

local function placeLane(
	current: Lane,
	origin: Vector3,
	direction: Vector3,
	length: number,
	width: number
)
	local cells = BossFx.laneCells(length, width, K.laneTile)
	local side = Vector3.new(-direction.Z, 0, direction.X)
	local rows = math.max(1, math.ceil(length / K.laneTile - 1e-6))
	current.rowCount = rows
	for i, cell in cells do
		local part = current.tiles[i]
		if not part then
			part = cube(
				current.holder,
				Vector3.new(K.laneTile * 0.9, 0.12, K.laneTile * 0.9),
				K.laneColor,
				true
			)
			current.tiles[i] = part
		end
		local at = flatAt(origin, 0.14) + direction * cell.along + side * cell.across
		part.CFrame = CFrame.lookAt(at, at + direction)
		current.rows[i] = math.floor(cell.along / length * rows) + 1
	end
	for i = #cells + 1, #current.tiles do
		current.tiles[i]:Destroy()
		current.tiles[i] = nil
		current.rows[i] = nil
	end
end

--[[ The lane, tracking (`locked` false, redrawn as it follows) or locked:
     one set of tiles, kept while the server keeps sending it. ]]
function BossFx.lane(
	parent: Instance,
	origin: Vector3,
	direction: Vector3,
	duration: number,
	length: number,
	width: number,
	locked: boolean
)
	local now = os.clock()
	local current = lane
	if not current or not current.holder.Parent or now > current.expires + 0.05 then
		if current then
			current.holder:Destroy()
		end
		local holder = Instance.new("Folder")
		holder.Name = "LashLane"
		holder.Parent = parent
		local made: Lane = {
			holder = holder,
			tiles = {},
			rows = {},
			rowCount = 1,
			started = now,
			expires = now + duration,
			locked = false,
			lockedAt = 0,
		}
		current = made
		lane = made
		animate(function(t)
			if not holder.Parent then
				return false
			end
			if t > made.expires then
				holder:Destroy()
				if lane == made then
					lane = nil
				end
				return false
			end
			local filled = math.min(1, (t - made.started) / K.laneFill) * made.rowCount
			for i, part in made.tiles do
				if made.locked then
					local since = t - made.lockedAt
					if since < K.laneLockFlash then
						part.Color = Color3.new(1, 1, 1)
					else
						local beat = 0.5 + 0.5 * math.sin(t * K.lanePulseRate * 2 * math.pi)
						part.Color = K.laneColor:Lerp(K.lanePulse, beat)
					end
					part.Transparency = 0.1
				else
					part.Color = K.laneColor
					part.Transparency = if made.rows[i] <= filled then 0.45 else 1
				end
			end
			return true
		end)
	end
	assert(current, "a lane")
	current.expires = math.max(current.expires, now + duration)
	if locked and not current.locked then
		current.locked = true
		current.lockedAt = now
		current.expires = now + duration
	end
	placeLane(current, origin, direction, length, width)
end

--[[ The cells of the fist's splat: a stepped cross `across` studs wide. ]]
function BossFx.splatCells(across: number, tile: number): { Vector2 }
	local n = math.floor(across / tile / 2)
	local cells = {}
	for i = -n, n do
		for j = -n, n do
			-- a plus with a fat middle: the cross's arms and the 3 x 3 centre
			if i == 0 or j == 0 or (math.abs(i) <= 1 and math.abs(j) <= 1) then
				table.insert(cells, Vector2.new(i * tile, j * tile))
			end
		end
	end
	return cells
end

--[[ The fist slapped the floor at `origin`: the stepped slime cross and a
     ring of cubes thrown out over the hold. ]]
function BossFx.splat(
	parent: Instance,
	origin: Vector3,
	direction: Vector3,
	duration: number,
	across: number
)
	local ground = flatAt(origin, 0)
	local facing = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.zAxis
	local side = Vector3.new(-facing.Z, 0, facing.X)
	local tiles: { BasePart } = {}
	for index, cell in BossFx.splatCells(across, K.splatTile) do
		local colour = if index % 2 == 0 then K.slime else K.slimeLight
		local part = cube(parent, Vector3.new(K.splatTile, 0.3, K.splatTile), colour)
		local at = ground + side * cell.X + facing * cell.Y + Vector3.new(0, 0.18, 0)
		part.CFrame = CFrame.lookAt(at, at + facing)
		table.insert(tiles, part)
	end
	local ring: { BasePart } = {}
	local count = share(K.splatRing)
	for _ = 1, count do
		table.insert(ring, cube(parent, Vector3.one * K.splatRingSize, K.slimeLight))
	end
	local born = os.clock()
	animate(function(now)
		local t = (now - born) / duration
		if t >= 1.4 then
			for _, part in tiles do
				part:Destroy()
			end
			for _, part in ring do
				part:Destroy()
			end
			return false
		end
		local out = ease(math.min(1, t)) * K.splatRingReach
		for i, part in ring do
			local a = (i - 1) / count * 2 * math.pi
			part.CFrame = CFrame.new(
				ground
					+ Vector3.new(
						math.cos(a) * (1 + out),
						K.splatRingSize / 2,
						math.sin(a) * (1 + out)
					)
			) * CFrame.Angles(0, a, 0)
			part.Transparency = math.max(0, t - 0.6) / 0.6
		end
		for _, part in tiles do
			part.Transparency = math.max(0, t - 1) / 0.4
		end
		return true
	end)
end

--[[ Goo thrown off the fist: slime cubes flung out, bouncing once on the
     floor, gone by the end of the retract. ]]
function BossFx.goo(
	parent: Instance,
	origin: Vector3,
	direction: Vector3,
	duration: number,
	count: number
)
	local along = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.zero
	for i = 1, share(count) do
		local size = between(K.gooSize)
		local part = cube(parent, Vector3.one * size, if i % 2 == 0 then K.slime else K.slimeLight)
		local a = math.random() * 2 * math.pi
		local dir = (Vector3.new(math.cos(a), 0, math.sin(a)) + along * 0.4).Unit
		local reach = K.gooReach * (0.4 + 0.6 * math.random())
		local born = os.clock()
		local start = origin
		local tumble = spin()
		animate(function(now)
			local t = (now - born) / duration
			if t >= 1 then
				part:Destroy()
				return false
			end
			-- a throw down to the floor over the first 60%, then one small bounce
			local height: number
			if t < 0.6 then
				local u = t / 0.6
				height = start.Y * (1 - u) + 2.2 * 4 * u * (1 - u)
			else
				local u = (t - 0.6) / 0.4
				height = 0.8 * 4 * u * (1 - u)
			end
			local flat = flatAt(start, 0) + dir * reach * (1 - (1 - t) ^ 2)
			part.CFrame = CFrame.new(flat + Vector3.new(0, size / 2 + height, 0)) * tumble
			part.Transparency = math.max(0, (t - 0.75) / 0.25)
			return true
		end)
	end
end

--[[ The grab: a square flash where the fist closed on someone. ]]
function BossFx.grab(
	parent: Instance,
	origin: Vector3,
	direction: Vector3,
	duration: number,
	size: number
)
	local facing = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.zAxis
	local at = flatAt(origin, 0.2)
	local square =
		cube(parent, Vector3.new(size * 0.5, 0.15, size * 0.5), Color3.new(1, 1, 1), true)
	square.CFrame = CFrame.lookAt(at, at + facing)
	local born = os.clock()
	animate(function(now)
		local t = (now - born) / duration
		if t >= 1 then
			square:Destroy()
			return false
		end
		local grow = 0.5 + 0.5 * ease(t)
		square.Size = Vector3.new(size * grow, 0.15, size * grow)
		square.Color = Color3.new(1, 1, 1):Lerp(K.slimeLight, t)
		square.Transparency = t
		return true
	end)
end

--[[ The chest bump: a square of cubes rushing out from his belly. ]]
function BossFx.bump(parent: Instance, origin: Vector3, direction: Vector3, duration: number)
	local facing = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.zAxis
	local side = Vector3.new(-facing.Z, 0, facing.X)
	local count = share(K.bumpCubes)
	local cubes: { BasePart } = {}
	for _ = 1, count do
		table.insert(cubes, cube(parent, Vector3.one * 0.8, K.slimeLight, true))
	end
	local ground = flatAt(origin, 0)
	local born = os.clock()
	animate(function(now)
		local t = (now - born) / duration
		if t >= 1 then
			for _, part in cubes do
				part:Destroy()
			end
			return false
		end
		local e = ease(t)
		local half = (K.bumpFrom + (K.bumpTo - K.bumpFrom) * e) / 2
		local size = 0.8 - 0.5 * e
		for i, part in cubes do
			-- round the square's perimeter, `i` of `count`
			local u = (i - 1) / count * 4
			local edge = math.floor(u)
			local f = (u - edge) * 2 - 1
			local x, z
			if edge == 0 then
				x, z = f, -1
			elseif edge == 1 then
				x, z = 1, f
			elseif edge == 2 then
				x, z = -f, 1
			else
				x, z = -1, -f
			end
			part.Size = Vector3.one * size
			local at = ground
				+ side * (x * half)
				+ facing * (z * half)
				+ Vector3.new(0, size / 2 + 0.1, 0)
			part.CFrame = CFrame.lookAt(at, at + facing)
			part.Transparency = 0.7 * t
		end
		return true
	end)
end

--[[ Body beats, read off the clip the server says he plays. ]]

type Glowing = {
	model: Model,
	eyes: { BasePart },
	gems: { BasePart },
	arms: { [string]: { BasePart } },
	crown: BasePart?,
	base: { [BasePart]: Color3 },
	baseMaterial: { [BasePart]: Enum.Material },
	clip: string,
	clipStarted: number,
	popped: boolean,
	stars: { BasePart },
	lit: { [BasePart]: boolean },
}

local glowing: { [Model]: Glowing } = {}
local fxParent: Instance? = nil

local function restore(g: Glowing)
	for part, colour in g.base do
		part.Color = colour
		part.Material = g.baseMaterial[part]
	end
end

local function clearStars(g: Glowing)
	for _, star in g.stars do
		star:Destroy()
	end
	table.clear(g.stars)
end

local function popCrown(g: Glowing)
	local crown = g.crown
	local parent = fxParent
	if not crown or not parent then
		return
	end
	local count = share(K.crownCubes)
	for i = 1, count do
		local a = (i - 1) / count * 2 * math.pi
		local part = cube(parent, Vector3.one * K.crownCubeSize, K.gold, true)
		local born = os.clock()
		local life = K.crownTo - K.crownFrom
		local tumble = spin()
		animate(function(now)
			local t = (now - born) / life
			if t >= 1 or not crown.Parent then
				part:Destroy()
				return false
			end
			local out = Vector3.new(math.cos(a), 0, math.sin(a)) * (0.6 + 1.6 * t)
			local up = 1 + 2.4 * 4 * t * (1 - t)
			part.CFrame = CFrame.new(crown.Position + out + Vector3.new(0, up, 0)) * tumble
			part.Transparency = math.max(0, (t - 0.6) / 0.4)
			return true
		end)
	end
end

local function stepGlow(g: Glowing, now: number)
	local clip = g.clip
	local t = now - g.clipStarted
	local beat = 0.5 + 0.5 * math.sin(now * K.glowRate * 2 * math.pi)
	local windup = clip == "Bounce_Windup"
	local wind = string.sub(clip, 1, 9) == "Lash_Wind"
	local winded = clip == "Winded"

	for _, eye in g.eyes do
		local base = g.base[eye]
		if windup or wind then
			eye.Color = base:Lerp(K.eyeGlow, 0.5 + 0.5 * beat)
			eye.Material = Enum.Material.Neon
		elseif winded then
			eye.Color = base:Lerp(Color3.new(0, 0, 0), 1 - K.eyeDim)
			eye.Material = Enum.Material.SmoothPlastic
		else
			eye.Color = base
			eye.Material = g.baseMaterial[eye]
		end
	end
	--[[ Gems and arms are only written while they glow and once as they
	     stop, so a hit flash on them (`HitFeedback`) is left to play. ]]
	for _, gem in g.gems do
		if windup then
			gem.Color = g.base[gem]:Lerp(Color3.new(1, 1, 1), 0.6 * beat)
			gem.Material = Enum.Material.Neon
			g.lit[gem] = true
		elseif g.lit[gem] then
			gem.Color = g.base[gem]
			gem.Material = g.baseMaterial[gem]
			g.lit[gem] = nil
		end
	end
	local lashing = if clip == "Lash_Wind_R"
		then "ArmR"
		elseif clip == "Lash_Wind_L" then "ArmL"
		else nil
	for name, parts in g.arms do
		for _, part in parts do
			local base = g.base[part]
			if name == lashing then
				local coil = math.min(1, t / 0.8)
				part.Color = base:Lerp(K.armGlow, coil * (0.4 + 0.6 * beat))
				g.lit[part] = true
			elseif g.lit[part] then
				part.Color = base
				g.lit[part] = nil
			end
		end
	end

	if windup and not g.popped and t >= K.crownFrom then
		g.popped = true
		popCrown(g)
	end

	local crown = g.crown
	if winded and crown and fxParent then
		if #g.stars == 0 then
			for i = 1, share(K.stars) do
				table.insert(
					g.stars,
					cube(
						fxParent,
						Vector3.one * K.starSize,
						if i % 2 == 0 then K.starWhite else K.gold,
						true
					)
				)
			end
		end
		local count = #g.stars
		for i, star in g.stars do
			local a = t * K.starTurnsPerSecond * 2 * math.pi + (i - 1) / count * 2 * math.pi
			star.CFrame = CFrame.new(
				crown.Position
					+ Vector3.new(
						math.cos(a) * K.starRadius,
						K.starLift,
						math.sin(a) * K.starRadius
					)
			) * CFrame.Angles(0, a * 2, math.pi / 4)
		end
	elseif #g.stars > 0 then
		clearStars(g)
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") or glowing[model] or not model:GetAttribute("Boss") then
		return
	end
	local g: Glowing = {
		model = model,
		eyes = {},
		gems = {},
		arms = { ArmR = {}, ArmL = {} },
		crown = nil,
		base = {},
		baseMaterial = {},
		clip = "",
		clipStarted = os.clock(),
		popped = false,
		stars = {},
		lit = {},
	}
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local tracked = false
		if d:GetAttribute("Eye") then
			table.insert(g.eyes, d)
			tracked = true
		elseif d:GetAttribute("Surface") == "Emerald" then
			table.insert(g.gems, d)
			tracked = true
		elseif g.arms[d.Name] then
			table.insert(g.arms[d.Name], d)
			tracked = true
		end
		if d.Name == "Crown" and (not g.crown or d:GetAttribute("Surface") == "Gold") then
			g.crown = d
		end
		if tracked then
			g.base[d] = d.Color
			g.baseMaterial[d] = d.Material
		end
	end
	if #g.eyes == 0 and #g.gems == 0 then
		return
	end
	glowing[model] = g
	local function onClip()
		local name = model:GetAttribute("ModelClip")
		g.clip = if type(name) == "string" then name else ""
		g.clipStarted = os.clock()
		g.popped = false
	end
	model:GetAttributeChangedSignal("ModelClip"):Connect(onClip)
	onClip()
	animate(function(now)
		if not model.Parent then
			clearStars(g)
			glowing[model] = nil
			return false
		end
		stepGlow(g, now)
		return true
	end)
	model.Destroying:Connect(function()
		clearStars(g)
		restore(g)
	end)
end

--[[ Watches for bosses that play clips; `parent` holds the cubes. ]]
function BossFx.start(parent: Instance)
	fxParent = parent
	for _, model in CollectionService:GetTagged("ModelClips") do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("ModelClips"):Connect(function(model)
		-- the Boss attribute and the parts may arrive just after the tag
		task.delay(0.5, watch, model)
	end)
end

return BossFx
