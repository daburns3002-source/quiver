--!strict
--[[
	Every player's trail (`Config/Trails`), drawn on this client from the
	Player's `Trail` attribute (`TrailRules.ATTRIBUTE`, set by the server),
	as the trail's Claude Design build draws it (owner, 2026-11-13: "start
	making the trails in design that were agreed upon earlier"; each
	trail's build is named in `Config/Trails`, its numbers ported here):

	- The ribbon: voxel tiles laid on a grid in the ground as the player
	  runs, `Trails.tile` studs a tile, so a curve comes out stepped like
	  the builds' top views. A tile takes its column across the ribbon
	  (edge, band, lump...), ages a row every `1 / Trails.pace` seconds and
	  fades, dissolves or shrinks away as the build's rows do, the outer
	  columns first, so the ribbon narrows towards its end.
	- The pieces: the build's leaves, fireflies, feathers, crowns and
	  stars, each a few blocks, thrown along the ribbon and moved by its
	  numbers: out to the side, up to a peak and down to settle, sway,
	  tumble and spin, grow and shrink (in steps where the build steps),
	  blink or flash. A `follow` piece rides along behind the player as
	  the builds' swarms do; the rest stay where they were thrown.
	- A glowing trail (every Legendary and the Mythic, rule 12) carries a
	  light that breathes, and its glowing blocks are Neon.

	A dash or putting the trail on throws a burst of its pieces. Built here
	rather than on the server so each device draws its own share
	(`DeviceTiers.trailShare`) and nothing is replicated. Tiles and blocks
	are made once, a pool each, and reused oldest first; a frame moves
	every block in one `BulkMoveTo`. A player far from the camera lays
	nothing new.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Parent.Device)
local TrailRules = require(ReplicatedStorage.Shared.Util.TrailRules)
local Trails = require(ReplicatedStorage.Shared.Config.Trails)

local PlayerTrails = {}

local TILE = Trails.tile
local PACE = Trails.pace
--[[ Studs a second across the ground above which a player is moving. ]]
local MOVING = 1.5
--[[ How far above the ground the ribbon lies, in studs. ]]
local LIFT = 0.03
--[[ Tiles and blocks at full share; a device makes its `trailShare`. ]]
local TILES = 900
local BLOCKS = 900
--[[ Studs from the camera past which a player lays no new trail. ]]
local RANGE = 160
--[[ Where an unused part waits, out of sight under the world. ]]
local HIDDEN = CFrame.new(0, -500, 0)
local TAU = math.pi * 2
local BLACK = Color3.new(0, 0, 0)

type Worn = {
	trail: Trails.Trail,
	root: BasePart,
	humanoid: Humanoid,
	down: number,
	light: PointLight?,
	--[[ The grid squares this player's ribbon covers, to the tile there. ]]
	squares: { [number]: Tile },
	--[[ The last point the ribbon was laid to, and the way it ran. ]]
	last: Vector3?,
	heading: Vector3,
	--[[ The points the ribbon was laid through, half a tile apart, newest
	     last, for throwing pieces some rows back along it. ]]
	path: { Vector3 },
	--[[ Tiles run so far, for the threads' weave. ]]
	run: number,
	--[[ Each piece's share of one still to throw. ]]
	owed: { number },
	lastBurst: number,
	born: number,
}

type Tile = {
	part: BasePart,
	owner: Worn?,
	key: number,
	born: number,
	column: Trails.Column?,
	ribbon: Trails.Ribbon?,
	--[[ The row it goes at (dissolving or shrinking), and the row its
	     column shows from. ]]
	ends: number,
	from: number,
	size: Vector3,
	base: CFrame,
	colour: Color3,
	alpha: number,
	scale: number,
	fresh: boolean,
}

type Bit = {
	parts: { BasePart },
	look: Trails.Piece?,
	owner: Worn?,
	born: number,
	life: number,
	--[[ Where it was thrown from (a `follow` piece: nil, it rides with
	     the player). ]]
	base: CFrame?,
	sign: number,
	side: number,
	out: number,
	back: number,
	height: number,
	peak: number,
	peakAt: number,
	settle: number,
	settleAt: number,
	settleFrom: number,
	sway: number,
	turns: number,
	axis: Vector3,
	yaw: number,
	yawTurns: number,
	spin: number,
	tilt: number,
	creep: number,
	size: number,
	tint: Color3,
	period: number,
	phase: number,
	scale: number,
}

local worn: { [Player]: Worn } = {}
local tiles: { Tile } = {}
local bits: { Bit } = {}
local blocks: { BasePart } = {}
--[[ Which piece holds each block, so taking it back leaves no double. ]]
local holder: { [BasePart]: Bit } = {}
local nextTile = 1
local nextBit = 1
local nextBlock = 1
local folder: Folder? = nil
local stepping: RBXScriptConnection? = nil
local rng = Random.new()

--[[ Reused every frame for the one bulk move. ]]
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function between(range: { number }?, default: number): number
	if not range then
		return default
	end
	return lerp(range[1], range[2] or range[1], rng:NextNumber())
end

local function smooth(a: number, b: number, x: number): number
	if b <= a then
		return if x >= b then 1 else 0
	end
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function easeOut(t: number): number
	local c = math.clamp(t, 0, 1)
	return 1 - (1 - c) * (1 - c)
end

--[[ `t` (0..1) in `steps` even steps, as the builds grow voxels. ]]
local function stepped(t: number, steps: number?): number
	if not steps or t <= 0 or t >= 1 then
		return math.clamp(t, 0, 1)
	end
	return math.ceil(t * steps) / steps
end

--[[ A number from 0 to 1 that is always the same for the same seed. ]]
local function hash(n: number): number
	local x = math.sin(n * 127.1 + 311.7) * 43758.5453
	return x - math.floor(x)
end

local function shade(colour: Color3, by: number): Color3
	return Color3.new(
		math.min(1, colour.R * by),
		math.min(1, colour.G * by),
		math.min(1, colour.B * by)
	)
end

local function newPart(name: string): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = Vector3.one * 0.1
	part.CFrame = HIDDEN
	return part
end

local function newBit(): Bit
	return {
		parts = {},
		look = nil,
		owner = nil,
		born = 0,
		life = 1,
		base = nil,
		sign = 1,
		side = 0,
		out = 0,
		back = 0,
		height = 0,
		peak = 0,
		peakAt = 0,
		settle = 0,
		settleAt = 1,
		settleFrom = 0,
		sway = 0,
		turns = 0,
		axis = Vector3.yAxis,
		yaw = 0,
		yawTurns = 0,
		spin = 0,
		tilt = 0,
		creep = 0,
		size = 1,
		tint = BLACK,
		period = 0,
		phase = 0,
		scale = -1,
	}
end

--[[ The pools, made the first time a trail is worn. ]]
local function pools()
	if folder then
		return
	end
	local made = Instance.new("Folder")
	made.Name = "PlayerTrails"
	local share = Device.tier().trailShare
	for i = 1, math.max(80, math.round(TILES * share)) do
		local part = newPart("TrailTile")
		part.Parent = made
		tiles[i] = {
			part = part,
			owner = nil,
			key = 0,
			born = 0,
			column = nil,
			ribbon = nil,
			ends = 0,
			from = 0,
			size = Vector3.one,
			base = HIDDEN,
			colour = BLACK,
			alpha = 0,
			scale = 0,
			fresh = false,
		}
	end
	local count = math.max(60, math.round(BLOCKS * share))
	for i = 1, count do
		local part = newPart("TrailBlock")
		part.Parent = made
		blocks[i] = part
	end
	for i = 1, math.round(count / 2) do
		bits[i] = newBit()
	end
	made.Parent = Workspace
	folder = made
end

local function letTileGo(tile: Tile)
	local owner = tile.owner
	if owner and owner.squares[tile.key] == tile then
		owner.squares[tile.key] = nil
	end
	tile.owner = nil
	tile.column = nil
	tile.ribbon = nil
	tile.part.CFrame = HIDDEN
end

local function letBitGo(bit: Bit)
	bit.look = nil
	bit.owner = nil
	for _, part in bit.parts do
		part.CFrame = HIDDEN
		holder[part] = nil
	end
	table.clear(bit.parts)
end

--[[ A tile's opacity and size at `rows` old. ]]
local function tileLook(tile: Tile, rows: number): (number, number)
	local ribbon = tile.ribbon :: Trails.Ribbon
	local column = tile.column :: Trails.Column
	local fade = ribbon.fade
	local left = if ribbon.curve
		then (1 - math.clamp((rows - fade[1]) / (fade[2] - fade[1]), 0, 1)) ^ ribbon.curve
		else 1 - smooth(fade[1], fade[2], rows)
	local gone = column.gone
	if gone then
		left *= 1 - smooth(gone[1], gone[2], rows)
	end
	local alpha = (column.alpha or 1) * ribbon.alpha * left
	-- growing in, from the row its column shows from
	local scale = 1
	if rows < tile.from then
		return 0, 0
	end
	if ribbon.grow then
		scale = stepped((rows - tile.from) / ribbon.grow, ribbon.steps)
	end
	-- dissolving: gone at its own row, or shrinking away over `shrink` rows
	if rows >= tile.ends then
		if not ribbon.shrink then
			return 0, 0
		end
		scale = math.min(scale, 1 - stepped((rows - tile.ends) / ribbon.shrink, ribbon.steps))
	end
	return alpha, scale
end

local function lay(w: Worn, at: Vector3, heading: Vector3, now: number)
	local ribbon = w.trail.ribbon
	local columns = ribbon.columns
	local across = #columns
	if across == 0 then
		return
	end
	local half = across / 2
	local right = heading:Cross(Vector3.yAxis)
	local reach = half + 1
	local x0 = math.floor((at.X - reach * TILE) / TILE)
	local x1 = math.floor((at.X + reach * TILE) / TILE)
	local z0 = math.floor((at.Z - reach * TILE) / TILE)
	local z1 = math.floor((at.Z + reach * TILE) / TILE)
	for ix = x0, x1 do
		for iz = z0, z1 do
			local centre = Vector3.new((ix + 0.5) * TILE, at.Y, (iz + 0.5) * TILE)
			local offset = centre - at
			local lateral = offset:Dot(right) / TILE
			local along = offset:Dot(heading) / TILE
			if math.abs(lateral) >= half or math.abs(along) > 0.5 then
				continue
			end
			local key = ix * 131072 + iz
			local had = w.squares[key]
			-- laid a moment ago by the point before: leave it be
			if had and (now - had.born) * PACE < 3 then
				continue
			end
			local column = columns[math.clamp(math.floor(lateral + half) + 1, 1, across)]
			local seed = ix * 7.31 + iz * 3.17
			-- a column that is only there now and then, chosen two by two
			if
				column.chance
				and hash(math.floor(ix / 2) * 5.1 + math.floor(iz / 2) * 9.7) >= column.chance
			then
				if had then
					letTileGo(had)
				end
				continue
			end
			local tile: Tile
			if had then
				tile = had
			else
				tile = tiles[nextTile]
				nextTile = nextTile % #tiles + 1
				if tile.owner then
					letTileGo(tile)
				end
			end
			local colour = column.colour
			if column.streak and hash(seed + 41) < (column.streaks or 0) then
				colour = column.streak
			end
			local jitter = lerp(ribbon.jitter[1], ribbon.jitter[2], hash(seed))
			local part = tile.part
			part.Material = if column.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local high = column.height
			if column.tall and hash(seed + 23) < (column.tallShare or 0) then
				high = column.tall
			end
			local tall = high * TILE
			tile.size = Vector3.new(TILE, tall, TILE)
			tile.base = CFrame.new(centre.X, at.Y + LIFT, centre.Z)
			tile.colour = shade(colour, jitter)
			tile.fresh = column.fresh ~= nil
			part.Color = if column.fresh then shade(column.fresh, jitter) else tile.colour
			local dissolve = column.dissolve
			tile.ends = if dissolve
				then lerp(dissolve[1], dissolve[2], hash(seed + 7))
				else math.huge
			tile.from = column.from or 0
			tile.owner = w
			tile.key = key
			tile.born = now
			tile.column = column
			tile.ribbon = ribbon
			tile.alpha = -1
			tile.scale = -1
			part.Transparency = 1
			part.Size = tile.size
			part.CFrame = tile.base * CFrame.new(0, tall / 2, 0)
			w.squares[key] = tile
		end
	end
end

--[[ A thread's next stretch, a tile long, at its own height and its
     weave's place across the ribbon (snapped to eighths, as the build). ]]
local function layThreads(w: Worn, at: Vector3, heading: Vector3, now: number)
	local ribbon = w.trail.ribbon
	local threads = ribbon.threads
	if not threads then
		return
	end
	local right = heading:Cross(Vector3.yAxis)
	for _, thread in threads do
		local across = thread.amp * math.sin(TAU * w.run / thread.wave + thread.phase)
		across = math.round(math.clamp(across, -thread.limit, thread.limit) * 8) / 8
		local tile = tiles[nextTile]
		nextTile = nextTile % #tiles + 1
		if tile.owner then
			letTileGo(tile)
		end
		local part = tile.part
		part.Material = if thread.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Color = thread.colour
		tile.size = Vector3.new(thread.width * TILE, thread.height * TILE, TILE * 1.02)
		tile.base = CFrame.lookAlong(
			at + right * across * TILE + Vector3.new(0, thread.lift * TILE + LIFT, 0),
			heading
		)
		tile.colour = thread.colour
		tile.fresh = false
		tile.ends = math.huge
		tile.from = 0
		tile.owner = w
		tile.key = 0
		tile.born = now
		tile.column = thread :: any
		tile.ribbon = ribbon
		tile.alpha = -1
		tile.scale = -1
		part.Transparency = 1
		part.Size = tile.size
		part.CFrame = tile.base * CFrame.new(0, tile.size.Y / 2, 0)
	end
end

local function takeBlocks(count: number): { BasePart }
	local taken = {}
	for _ = 1, count do
		local part = blocks[nextBlock]
		nextBlock = nextBlock % #blocks + 1
		-- the oldest block, still in a piece that was nearly done: it goes
		local had = holder[part]
		if had then
			local at = table.find(had.parts, part)
			if at then
				table.remove(had.parts, at)
			end
		end
		table.insert(taken, part)
	end
	return taken
end

--[[ A point `rows` back along the player's ribbon, and the way it ran. ]]
local function behind(w: Worn, rows: number, feet: Vector3): (Vector3, Vector3)
	local path = w.path
	local index = #path - math.floor(rows * 2)
	if index >= 1 and #path >= 2 then
		local at = path[index]
		local towards = path[math.min(#path, index + 1)] - at
		if index == #path then
			towards = at - path[index - 1]
		end
		return at, if towards.Magnitude > 1e-3 then towards.Unit else w.heading
	end
	return feet - w.heading * rows * TILE, w.heading
end

local function throw(w: Worn, look: Trails.Piece, feet: Vector3, now: number, burst: boolean?)
	local bit: Bit = bits[nextBit]
	nextBit = nextBit % #bits + 1
	if bit.look then
		letBitGo(bit)
	end
	local back = if burst then between({ 0, 2 }, 0) else between(look.back, 0)
	if look.follow then
		bit.base = nil
		bit.back = back
	else
		local at, heading = behind(w, back, feet)
		bit.base = CFrame.lookAlong(Vector3.new(at.X, feet.Y, at.Z), heading)
		bit.back = 0
	end
	bit.parts = takeBlocks(#look.blocks)
	for _, part in bit.parts do
		holder[part] = bit
	end
	bit.look = look
	bit.owner = w
	bit.born = now
	bit.life = between(look.life, 1)
	bit.sign = if look.sides == 1 then 1 elseif rng:NextNumber() < 0.5 then -1 else 1
	bit.side = between(look.side, 0)
	bit.out = between(look.out, 0) * (if burst then 2 else 1)
	bit.height = between(look.height, 0)
	bit.peak = between(look.peak, bit.height)
	bit.peakAt = between(look.peakAt, 0)
	bit.settle = between(look.settle, bit.peak)
	bit.settleAt = between(look.settleAt, 1)
	bit.settleFrom = look.settleFrom or bit.peakAt
	bit.sway = between(look.sway, 0)
	bit.turns = math.round(between(look.turns, 0))
	bit.axis = Vector3.new(
		rng:NextNumber() - 0.5,
		0.6 * (rng:NextNumber() - 0.5),
		rng:NextNumber() - 0.5
	).Unit
	bit.yaw = rng:NextNumber() * TAU
	bit.yawTurns = math.round(between(look.yawTurns, 0))
		* (if rng:NextNumber() < 0.5 then -1 else 1)
	local spin = look.spin or 0
	bit.spin = math.rad(between({ -spin, spin }, 0))
	bit.tilt = between(look.tilt, 0)
	bit.creep = between(look.creep, 0)
	bit.size = between(look.size, 1)
	bit.tint = shade(look.colours[rng:NextInteger(1, #look.colours)], between(look.jitter, 1))
	local blink = look.blink
	bit.period = if blink then blink[rng:NextInteger(1, #blink)] else 0
	bit.phase = rng:NextNumber()
	bit.scale = -1
	for i, part in bit.parts do
		local block = look.blocks[i]
		part.Material = if block.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Color = block.colour or shade(bit.tint, block.shade or 1)
		part.Transparency = 1
	end
end

--[[ How lit a blinking piece is, `t` seconds in: on for `duty` of each
     period with soft edges, as the builds blink. ]]
local function blinkAt(bit: Bit, t: number, duty: number): number
	if bit.period <= 0 then
		return 1
	end
	local ph = (t / bit.period + bit.phase) % 1
	return smooth(0, 0.07, ph) * (1 - smooth(duty - 0.07, duty, ph))
end

local function moveBit(bit: Bit, now: number, count: number): number
	local look = bit.look :: Trails.Piece
	local w = bit.owner :: Worn
	local t = now - bit.born
	local u = t / bit.life
	if u >= 1 or #bit.parts == 0 then
		letBitGo(bit)
		return count
	end
	local outAt = look.outAt or { 0, 1 }
	local settling = smooth(bit.settleFrom, bit.settleAt, u)
	local lateral = bit.sign
			* (bit.side + bit.out * easeOut((u - outAt[1]) / (outAt[2] - outAt[1])))
		+ bit.sway
			* (1 - 0.55 * settling)
			* math.sin(TAU * (u * (look.swayTurns or 1) + bit.phase))
	local back = bit.back + (look.slide or 0) * (1 - math.exp(-t / 0.55)) + bit.creep * t
	local y = lerp(lerp(bit.height, bit.peak, smooth(0, bit.peakAt, u)), bit.settle, settling)
	if look.bob then
		y += look.bob * math.sin(TAU * (t / (look.bobPeriod or 1) + bit.phase))
	end
	local turnEnd = look.turnEnd or 1
	local angle = bit.turns * TAU * easeOut(u / turnEnd)
	local wobble = bit.tilt * (1 - 0.55 * settling)
	local turn = CFrame.Angles(0, bit.yaw + bit.yawTurns * TAU * u + bit.spin * t, 0)
		* CFrame.Angles(
			wobble * 0.6 * math.sin(TAU * (u * 2 + bit.phase)),
			0,
			wobble * math.cos(TAU * (u + bit.phase))
		)
		* CFrame.fromAxisAngle(bit.axis, angle)
	local base = bit.base
	if not base then
		local feet = w.root.Position - Vector3.new(0, w.down, 0)
		base = CFrame.lookAlong(feet, w.heading)
	end
	assert(base, "a base")
	local frame = base * CFrame.new(lateral * TILE, y * TILE, back * TILE) * turn

	local lit = blinkAt(bit, t, look.duty or 0.62)
	local grown = stepped(smooth(0, look.grow or 0.001, u), look.steps)
		* (1 - stepped(smooth(1 - (look.shrink or 0.001), 1, u), look.steps))
	grown *= 1 + (look.pulse or 0) * (if bit.period > 0 then lit else 0)
	local scale = math.round(bit.size * grown * 40) / 40
	local fade = 1 - smooth(look.fadeFrom or 1, 1, u)
	local resize = scale ~= bit.scale
	bit.scale = scale
	for i, part in bit.parts do
		local block = look.blocks[i]
		count += 1
		moveParts[count] = part
		local placed = frame * CFrame.new((block.at or Vector3.zero) * scale * TILE)
		if block.turn then
			placed *= CFrame.Angles(0, math.rad(block.turn), 0)
		end
		moveFrames[count] = placed
		if resize then
			part.Size = block.size * math.max(scale, 0.02) * TILE
		end
		local alpha = if scale <= 0
			then 0
			else (block.alpha or 1) * fade * (if block.shell then lit else 1)
		part.Transparency = 1 - math.round(alpha * 40) / 40
		if block.dim then
			part.Color = block.dim:Lerp(block.colour or bit.tint, lit)
		end
	end
	return count
end

local function step(dt: number)
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local share = Device.tier().trailShare
	for player, w in worn do
		if not w.root.Parent then
			worn[player] = nil
			continue
		end
		local trail = w.trail
		local feet = w.root.Position - Vector3.new(0, w.down, 0)
		local v = w.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local near = (feet - eye).Magnitude < RANGE
		local grounded = w.humanoid.FloorMaterial ~= Enum.Material.Air

		-- the ribbon: tiles laid every half tile run
		local last = w.last
		if not last or not near or not grounded then
			w.last = feet
		else
			local run = Vector3.new(feet.X - last.X, 0, feet.Z - last.Z)
			local gap = TILE * 0.5
			if run.Magnitude > TILE * 12 then
				w.last = feet -- a teleport: start again from here
			elseif run.Magnitude >= gap then
				local heading = run.Unit
				w.heading = heading
				local steps = math.floor(run.Magnitude / gap)
				for i = 1, steps do
					local at = Vector3.new(last.X, feet.Y, last.Z) + heading * gap * i
					lay(w, at, heading, now)
					table.insert(w.path, at)
					w.run += 0.5
					if w.run % 1 == 0 then
						layThreads(w, at, heading, now)
					end
				end
				while #w.path > 160 do
					table.remove(w.path, 1)
				end
				w.last = Vector3.new(last.X, feet.Y, last.Z) + heading * gap * steps
			end
		end

		-- the pieces: their rate while running, a little standing still
		if near then
			local moving = speed > MOVING
			for i, look in trail.pieces do
				local rate = look.rate * share * (if moving then 1 else Trails.idle)
				w.owed[i] += rate * dt
				while w.owed[i] >= 1 do
					w.owed[i] -= 1
					throw(w, look, feet, now)
				end
			end
			if speed > Trails.burst.speed and now - w.lastBurst > Trails.burst.gap then
				w.lastBurst = now
				for _, look in trail.pieces do
					for _ = 1, math.max(1, math.round(Trails.burst.count * share / #trail.pieces)) do
						throw(w, look, feet, now, true)
					end
				end
			end
		end

		local light = w.light
		if light then
			light.Brightness = (trail.lightBrightness or 1.4)
				* (1 + Trails.pulse.depth * math.sin((now - w.born) * Trails.pulse.rate * TAU))
		end
	end

	-- every tile ages; a change is set only when it shows
	local any = false
	for _, tile in tiles do
		local ribbon = tile.ribbon
		if not ribbon then
			continue
		end
		any = true
		local rows = (now - tile.born) * PACE
		if rows >= ribbon.fade[2] or rows >= tile.ends + (ribbon.shrink or 0) then
			letTileGo(tile)
			continue
		end
		local alpha, scale = tileLook(tile, rows)
		alpha = math.round(alpha * 40) / 40
		if alpha ~= tile.alpha then
			tile.alpha = alpha
			tile.part.Transparency = if scale <= 0 then 1 else 1 - alpha
		end
		if scale ~= tile.scale then
			tile.scale = scale
			if scale > 0 then
				local size = tile.size * scale
				tile.part.Size = size
				tile.part.CFrame = tile.base * CFrame.new(0, size.Y / 2, 0)
			end
			tile.part.Transparency = if scale <= 0 then 1 else 1 - tile.alpha
		end
		local column = tile.column :: Trails.Column
		if tile.fresh and column.freshRows and rows >= column.freshRows then
			tile.fresh = false
			tile.part.Color = tile.colour
		end
	end

	local count = 0
	for _, bit in bits do
		if bit.look then
			any = true
			count = moveBit(bit, now, count)
		end
	end
	for i = #moveParts, count + 1, -1 do
		moveParts[i] = nil
		moveFrames[i] = nil
	end
	if count > 0 then
		Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	if next(worn) == nil and not any and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function clear(player: Player)
	local w = worn[player]
	if not w then
		return
	end
	worn[player] = nil
	if w.light then
		w.light:Destroy()
	end
	-- what it laid fades out as it would have; nothing new is laid
end

--[[ How far below the root the feet are: R15 stands on its hip height,
     R6 on its two-stud legs. ]]
local function groundBelow(root: BasePart, humanoid: Humanoid): number
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	return root.Size.Y / 2 + legs
end

--[[ Puts `key`'s trail on `character`, or nothing for nil or an unknown
     key; `fresh` (just put on, not a new character) throws a burst. ]]
local function wear(player: Player, character: Model, key: unknown, fresh: boolean)
	local trail = TrailRules.get(key)
	if not trail then
		clear(player)
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	-- the attribute or the character may have moved on while waiting
	if
		not root
		or not humanoid
		or player.Character ~= character
		or player:GetAttribute(TrailRules.ATTRIBUTE) ~= key
	then
		return
	end
	-- two asks can wait side by side (a new character and its attribute):
	-- whichever finishes last is the one worn, never both
	clear(player)
	pools()

	local light: PointLight? = nil
	if trail.glow and trail.light then
		local made = Instance.new("PointLight")
		made.Name = "TrailLight"
		made.Color = trail.light
		made.Range = trail.lightRange or 12
		made.Brightness = trail.lightBrightness or 1.4
		made.Shadows = false
		made.Parent = root
		light = made
	end

	local look = root.CFrame.LookVector
	local heading = Vector3.new(look.X, 0, look.Z)
	local owed = {}
	for i in trail.pieces do
		owed[i] = 0
	end
	local now = os.clock()
	local w: Worn = {
		trail = trail,
		root = root,
		humanoid = humanoid,
		down = groundBelow(root, humanoid),
		light = light,
		squares = {},
		last = nil,
		heading = if heading.Magnitude > 1e-3 then heading.Unit else Vector3.zAxis,
		path = {},
		run = 0,
		owed = owed,
		lastBurst = now,
		born = now,
	}
	worn[player] = w
	if fresh then
		local feet = root.Position - Vector3.new(0, w.down, 0)
		for _, piece in trail.pieces do
			for _ = 1, math.max(1, math.round(Trails.burst.count / #trail.pieces)) do
				throw(w, piece, feet, now, true)
			end
		end
	end
	if not stepping then
		stepping = RunService.Heartbeat:Connect(step)
	end
end

local function watch(player: Player)
	local function refresh(fresh: boolean)
		local character = player.Character
		if character then
			task.spawn(wear, player, character, player:GetAttribute(TrailRules.ATTRIBUTE), fresh)
		else
			clear(player)
		end
	end
	player:GetAttributeChangedSignal(TrailRules.ATTRIBUTE):Connect(function()
		refresh(true)
	end)
	player.CharacterAdded:Connect(function()
		refresh(false)
	end)
	player.CharacterRemoving:Connect(function()
		clear(player)
	end)
	refresh(false)
end

function PlayerTrails.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
end

return PlayerTrails
