--!strict
--[[
	The Old Tollcrab's moves (`Server/Enemies/TollcrabMoves`), drawn in
	cubes like every boss's (`BossFx`) from the server's telegraphs:

	- `TollTell`: the toll's warning for its wind-up: a red ring of cubes
	  where the ring will die (`reach`), and its gap lit pale blue on the
	  floor from him out to that ring: the place to stand.
	- `TollRing`: the bronze ring rolling out to `reach` over `duration`,
	  `band` thick, with its gap open, exactly where the server hits.
	- `EchoTell`: a red ring of cubes under the player with a bronze fill
	  swelling to its edge as the strike comes.
	- `EchoStrike`: the echo landing: a burst of cubes out from the mark.

	The warnings are drawn in full on every device: they are the counterplay.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local TollFx = {}

local BRONZE = Color3.fromRGB(235, 172, 78)
local GAP = Color3.fromRGB(120, 225, 255)
local FLOOR = 0.16
local TILE = 2
local FADE = 0.25

local function toll(): Balance.BossToll
	local config = (Balance.Enemies :: any).OldTollcrab :: Balance.EnemyConfig
	return (config.boss :: Balance.EnemyBoss).toll :: Balance.BossToll
end

type Updater = (now: number) -> boolean
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

local function cube(parent: Instance, size: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = "TollFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = colour
	part.Size = size
	part.Parent = parent
	return part
end

local function folderIn(parent: Instance, name: string): Folder
	local holder = Instance.new("Folder")
	holder.Name = name
	holder.Parent = parent
	return holder
end

--[[ The angle, about the vertical, of a flat direction. ]]
local function angleOf(direction: Vector3): number
	return math.atan2(direction.Z, direction.X)
end

--[[ Whether `angle` is inside the gap centred on `gapAngle`, `half` wide
     each side. ]]
local function inGap(angle: number, gapAngle: number, half: number): boolean
	local delta = math.abs(((angle - gapAngle + math.pi) % (2 * math.pi)) - math.pi)
	return delta < half
end

--[[ Cubes laid round a circle of `radius`, the gap left out, each `size`
     along it; returns them with their angles. ]]
local function ringCubes(
	holder: Instance,
	count: number,
	gapAngle: number,
	half: number,
	colour: Color3
): { { part: Part, angle: number } }
	local cubes = {}
	local span = 2 * math.pi - 2 * half
	for i = 0, count - 1 do
		local angle = gapAngle + half + span * (i + 0.5) / count
		local part = cube(holder, Vector3.one, colour)
		part.Transparency = 1
		table.insert(cubes, { part = part, angle = angle })
	end
	return cubes
end

local function placeRing(
	cubes: { { part: Part, angle: number } },
	origin: Vector3,
	radius: number,
	along: number,
	thick: number,
	height: number,
	transparency: number
)
	for _, c in cubes do
		local x, z = math.cos(c.angle), math.sin(c.angle)
		local at = Vector3.new(origin.X + x * radius, height / 2 + FLOOR, origin.Z + z * radius)
		c.part.Size = Vector3.new(thick, height, along)
		c.part.CFrame = CFrame.lookAt(at, at + Vector3.new(-z, 0, x))
		c.part.Transparency = transparency
	end
end

function TollFx.tell(
	parent: Instance,
	origin: Vector3,
	gap: Vector3,
	duration: number,
	reach: number,
	gapDegrees: number
)
	local holder = folderIn(parent, "TollTell")
	local gapAngle = angleOf(gap)
	local half = math.rad(gapDegrees / 2)
	local count = math.max(8, math.floor((2 * math.pi - 2 * half) * reach / TILE))
	local edge = ringCubes(holder, count, gapAngle, half, Balance.Telegraph.bossColor)
	local along = (2 * math.pi - 2 * half) * reach / count * 0.8
	--[[ The gap's tiles, from beside him out to the ring. ]]
	local lit: { Part } = {}
	local n = math.ceil(reach / TILE)
	for i = -n, n do
		for j = -n, n do
			local x, z = i * TILE, j * TILE
			local distance = math.sqrt(x * x + z * z)
			if distance >= 3 and distance <= reach and inGap(math.atan2(z, x), gapAngle, half) then
				local part = cube(holder, Vector3.new(TILE * 0.9, 0.12, TILE * 0.9), GAP)
				part.Position = Vector3.new(origin.X + x, FLOOR, origin.Z + z)
				part.Transparency = 1
				table.insert(lit, part)
			end
		end
	end
	local started = os.clock()
	animate(function(now)
		if not holder.Parent then
			return false
		end
		local age = now - started
		if age >= duration then
			holder:Destroy()
			return false
		end
		local fade = math.min(1, age / FADE)
		local beat = 0.5 + 0.5 * math.sin(age * (6 + 10 * age / duration))
		placeRing(edge, origin, reach, along, 0.9, 0.5, 1 - fade * (0.55 + 0.35 * beat))
		for _, part in lit do
			part.Transparency = 1 - fade * (0.35 + 0.25 * beat)
		end
		return true
	end)
end

function TollFx.ring(
	parent: Instance,
	origin: Vector3,
	gap: Vector3,
	duration: number,
	reach: number,
	gapDegrees: number
)
	local holder = folderIn(parent, "TollRing")
	local band = toll().band
	local gapAngle = angleOf(gap)
	local half = math.rad(gapDegrees / 2)
	local count = math.max(8, math.floor((2 * math.pi - 2 * half) * reach / TILE))
	local cubes = ringCubes(holder, count, gapAngle, half, BRONZE)
	local started = os.clock()
	animate(function(now)
		if not holder.Parent then
			return false
		end
		local t = (now - started) / duration
		if t >= 1 then
			holder:Destroy()
			return false
		end
		local radius = math.max(0.5, reach * t)
		local along = (2 * math.pi - 2 * half) * radius / count * 1.05
		local fadeOut = if t > 0.85 then (t - 0.85) / 0.15 else 0
		placeRing(cubes, origin, radius, along, band, 1.4, 0.1 + 0.9 * fadeOut)
		return true
	end)
end

function TollFx.echoTell(parent: Instance, origin: Vector3, duration: number, radius: number)
	local holder = folderIn(parent, "EchoTell")
	local count = math.max(10, math.floor(2 * math.pi * radius / 1.2))
	local edge = ringCubes(holder, count, 0, 0, Balance.Telegraph.bossColor)
	local along = 2 * math.pi * radius / count * 0.75
	local fill = cube(holder, Vector3.new(0.1, 0.1, 0.1), BRONZE)
	fill.Shape = Enum.PartType.Cylinder
	fill.Transparency = 1
	local started = os.clock()
	animate(function(now)
		if not holder.Parent then
			return false
		end
		local t = (now - started) / duration
		if t >= 1 then
			holder:Destroy()
			return false
		end
		local fade = math.min(1, (now - started) / 0.15)
		placeRing(edge, origin, radius, along, 0.7, 0.5, 1 - fade * 0.85)
		local across = 2 * radius * t
		fill.Size = Vector3.new(0.1, across, across)
		fill.CFrame = CFrame.new(origin.X, FLOOR, origin.Z) * CFrame.Angles(0, 0, math.pi / 2)
		fill.Transparency = 0.65 - 0.3 * t
		return true
	end)
end

function TollFx.echoStrike(parent: Instance, origin: Vector3, duration: number, radius: number)
	local holder = folderIn(parent, "EchoStrike")
	local count = math.max(10, math.floor(2 * math.pi * radius / 1.5))
	local burst = ringCubes(holder, count, 0, 0, BRONZE)
	local started = os.clock()
	animate(function(now)
		if not holder.Parent then
			return false
		end
		local t = (now - started) / duration
		if t >= 1 then
			holder:Destroy()
			return false
		end
		local r = radius * (0.6 + 0.7 * t)
		placeRing(burst, origin, r, 1.1, 1.1, 1.6 * (1 - t) + 0.3, t)
		return true
	end)
end

return TollFx
