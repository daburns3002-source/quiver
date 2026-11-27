--!strict
--[[
	Grandmother Gulp's own moves, drawn (`Enemies/BossMoves`; owner,
	2026-11-07): the glob of Spore Spit lobbed from her mouth, the cone of
	Big Gulp and its inhale, the slime trail of Belly Slide, and the poison
	of The Bog Rises creeping in from the walls. Blocky, on the boss
	warnings' grid (`Balance.Telegraph.king.tile`), like `BossFx`.

	Presentation only: what hurts is decided on the server, over the same
	shapes (a cone, a strip, the floor inset from its walls).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)

local GulpFx = {}

local TILE = Balance.Telegraph.king.tile
local WARN = Balance.Telegraph.bossColor
local SPORE = Color3.fromRGB(196, 120, 210)
local SLIME = Color3.fromRGB(120, 190, 70)
local POISON = Color3.fromRGB(110, 200, 90)
local AIR = Color3.fromRGB(230, 240, 255)

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

local function cube(parent: Instance, size: Vector3, colour: Color3, neon: boolean?): Part
	local part = Instance.new("Part")
	part.Name = "GulpFx"
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

local function holder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

--[[
	The grid cells inside a cone from `origin` along `direction`, `reach`
	long and `halfAngle` radians either side. Pure, exposed for the spec:
	the warning must cover what the server drags.
]]
function GulpFx.coneCells(
	direction: Vector3,
	reach: number,
	halfAngle: number,
	tile: number
): { Vector3 }
	local cells: { Vector3 } = {}
	local facing = Vector3.new(direction.X, 0, direction.Z)
	facing = if facing.Magnitude > 1e-3 then facing.Unit else Vector3.zAxis
	local side = Vector3.new(-facing.Z, 0, facing.X)
	local cosine = math.cos(halfAngle)
	local span = math.ceil(reach / tile)
	for i = 1, span do
		local along = (i - 0.5) * tile
		local width = along * math.tan(halfAngle)
		local across = math.max(0, math.floor(width / tile))
		for j = -across, across do
			local point = facing * along + side * (j * tile)
			if point.Magnitude <= reach and point.Unit:Dot(facing) >= cosine - 1e-3 then
				table.insert(cells, point)
			end
		end
	end
	return cells
end

--[[ Spore Spit's glob: a lumpy pink ball lobbed from `from` along `throw`
     (the whole flight), landing `duration` later. ]]
function GulpFx.glob(
	parent: Instance,
	from: Vector3,
	throw: Vector3,
	duration: number,
	size: number
)
	local ball = cube(parent, Vector3.one * size, SPORE, false)
	ball.Shape = Enum.PartType.Ball
	local height = 6 + throw.Magnitude * 0.25
	local started = os.clock()
	animate(function(now)
		if not ball.Parent then
			return false
		end
		local t = (now - started) / duration
		if t >= 1 then
			ball:Destroy()
			return false
		end
		local point = from + throw * t + Vector3.new(0, height * 4 * t * (1 - t), 0)
		ball.CFrame = CFrame.new(point) * CFrame.Angles(t * 7, t * 5, 0)
		return true
	end)
end

--[[ Big Gulp's cone: red cells on the floor that fade in and pulse until
     the inhale ends. ]]
function GulpFx.cone(
	parent: Instance,
	origin: Vector3,
	direction: Vector3,
	duration: number,
	reach: number,
	halfAngle: number
)
	local folder = holder(parent, "GulpCone")
	local cells: { Part } = {}
	for _, offset in GulpFx.coneCells(direction, reach, halfAngle, TILE) do
		local part = cube(folder, Vector3.new(TILE * 0.9, 0.12, TILE * 0.9), WARN, true)
		part.Position = Vector3.new(origin.X + offset.X, 0.14, origin.Z + offset.Z)
		part.Transparency = 1
		table.insert(cells, part)
	end
	local started = os.clock()
	animate(function(now)
		if not folder.Parent then
			return false
		end
		local t = (now - started) / duration
		if t >= 1 then
			folder:Destroy()
			return false
		end
		local beat = 0.5 + 0.5 * math.sin((now - started) * 10)
		local alpha = 0.85 - 0.4 * math.min(1, t * 4) - 0.15 * beat
		for _, part in cells do
			part.Transparency = alpha
		end
		return true
	end)
end

--[[ The inhale: white streaks of air rushing in along the cone to her
     mouth. ]]
function GulpFx.inhale(
	parent: Instance,
	mouth: Vector3,
	direction: Vector3,
	duration: number,
	reach: number,
	halfAngle: number
)
	local folder = holder(parent, "GulpInhale")
	local facing = Vector3.new(direction.X, 0, direction.Z)
	facing = if facing.Magnitude > 1e-3 then facing.Unit else Vector3.zAxis
	local count = math.max(4, math.floor(14 * Device.tier().bossFxShare + 0.5))
	type Streak = { part: Part, angle: number, offset: number }
	local streaks: { Streak } = {}
	for i = 1, count do
		local part = cube(folder, Vector3.new(0.25, 0.25, 2.2), AIR, true)
		part.Transparency = 0.4
		table.insert(streaks, {
			part = part,
			angle = (math.random() * 2 - 1) * halfAngle,
			offset = i / count,
		})
	end
	local started = os.clock()
	animate(function(now)
		if not folder.Parent then
			return false
		end
		local elapsed = now - started
		if elapsed >= duration then
			folder:Destroy()
			return false
		end
		for _, streak in streaks do
			local u = (streak.offset - elapsed * 1.6) % 1
			local way = CFrame.Angles(0, streak.angle, 0):VectorToWorldSpace(facing)
			local at = mouth + way * (reach * u) + Vector3.new(0, 1.5 + u * 2, 0)
			streak.part.CFrame = CFrame.lookAt(at, mouth + Vector3.new(0, 2, 0))
			streak.part.Transparency = 0.3 + 0.6 * (1 - u)
		end
		return true
	end)
end

--[[ Belly Slide's trail: slime cells laid behind her as she slides at
     `speed`, then fading at the end of `duration`. ]]
function GulpFx.trail(
	parent: Instance,
	from: Vector3,
	direction: Vector3,
	duration: number,
	length: number,
	width: number,
	speed: number
)
	local folder = holder(parent, "GulpTrail")
	local facing = Vector3.new(direction.X, 0, direction.Z)
	facing = if facing.Magnitude > 1e-3 then facing.Unit else Vector3.zAxis
	local side = Vector3.new(-facing.Z, 0, facing.X)
	type Cell = { part: Part, along: number }
	local cells: { Cell } = {}
	local across = math.max(0, math.floor((width / 2) / TILE - 0.5))
	for i = 0, math.floor(length / TILE) do
		local along = i * TILE
		for j = -across, across do
			local part = cube(folder, Vector3.new(TILE * 0.95, 0.1, TILE * 0.95), SLIME, false)
			part.CFrame = CFrame.lookAt(
				Vector3.new(from.X, 0.12, from.Z) + facing * along + side * (j * TILE),
				Vector3.new(from.X, 0.12, from.Z) + facing * (along + 1) + side * (j * TILE)
			)
			part.Transparency = 1
			table.insert(cells, { part = part, along = along })
		end
	end
	local started = os.clock()
	animate(function(now)
		if not folder.Parent then
			return false
		end
		local elapsed = now - started
		if elapsed >= duration then
			folder:Destroy()
			return false
		end
		local laid = elapsed * speed
		local fade = math.clamp((duration - elapsed) / 0.6, 0, 1)
		for _, cell in cells do
			cell.part.Transparency = if cell.along <= laid then 1 - 0.65 * fade else 1
		end
		return true
	end)
end

local flooding: Folder? = nil

--[[ The Bog Rises: poison rows creeping in from all four walls of a floor
     `half` across, to `inset` studs in, over `rise` seconds, and staying
     until `GulpFx.drain`. ]]
function GulpFx.flood(parent: Instance, half: Vector2, inset: Vector2, rise: number)
	GulpFx.drain()
	local folder = holder(parent, "BogFlood")
	flooding = folder
	local height = 0.35
	local function slab(): Part
		local part = cube(folder, Vector3.new(1, height, 1), POISON, true)
		part.Transparency = 0.45
		return part
	end
	local west, east, north, south = slab(), slab(), slab(), slab()
	local started = os.clock()
	animate(function(now)
		if not folder.Parent then
			return false
		end
		local risen = math.clamp((now - started) / rise, 0, 1)
		local wave = 0.05 * math.sin(now * 3)
		local x = math.max(0.05, inset.X * risen)
		local z = math.max(0.05, inset.Y * risen)
		local y = 0.1 + height / 2 + wave
		west.Size = Vector3.new(x, height, half.Y * 2)
		west.Position = Vector3.new(-half.X + x / 2, y, 0)
		east.Size = west.Size
		east.Position = Vector3.new(half.X - x / 2, y, 0)
		north.Size = Vector3.new(half.X * 2 - x * 2, height, z)
		north.Position = Vector3.new(0, y, -half.Y + z / 2)
		south.Size = north.Size
		south.Position = Vector3.new(0, y, half.Y - z / 2)
		return true
	end)
end

--[[ The flood drains: she has died. ]]
function GulpFx.drain()
	local folder = flooding
	flooding = nil
	if folder then
		folder:Destroy()
	end
end

return GulpFx
