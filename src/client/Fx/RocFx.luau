--!strict
--[[
	The Tempest Roc's warnings and blows (`Enemies/RocMoves`), drawn in
	cubes like every boss's: the Wing Gust's cone and the white streaks it
	blows along it, the Talon Swipe's arc and its claw marks, and a
	lightning bolt falling onto its ring. Told by `Fx/TelegraphRenderer`.
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local GulpFx = require(script.Parent.GulpFx)

local RocFx = {}

local TILE = 1.5
RocFx.WIND = Color3.fromRGB(196, 234, 255)
RocFx.WARN = Color3.fromRGB(255, 86, 64)
RocFx.BOLT = Color3.fromRGB(255, 236, 96)

local function cube(parent: Instance, size: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = colour
	part.Material = Enum.Material.Neon
	part.Parent = parent
	return part
end

local function facing(direction: Vector3): Vector3
	local flat = Vector3.new(direction.X, 0, direction.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
end

local function turned(direction: Vector3, radians: number): Vector3
	local c, s = math.cos(radians), math.sin(radians)
	return Vector3.new(direction.X * c - direction.Z * s, 0, direction.X * s + direction.Z * c)
end

--[[ A cone of floor tiles `reach` long and `angle` degrees across that
     brightens over the warning, then goes. ]]
function RocFx.cone(
	parent: Instance,
	origin: Vector3,
	direction: Vector3,
	duration: number,
	reach: number,
	angle: number,
	colour: Color3
)
	local folder = Instance.new("Folder")
	folder.Name = "RocCone"
	folder.Parent = parent
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, offset in GulpFx.coneCells(facing(direction), reach, math.rad(angle / 2), TILE) do
		local part = cube(folder, Vector3.new(TILE * 0.9, 0.12, TILE * 0.9), colour)
		part.Position = Vector3.new(origin.X + offset.X, 0.14, origin.Z + offset.Z)
		part.Transparency = 0.85
		TweenService:Create(part, info, { Transparency = 0.35 }):Play()
	end
	Debris:AddItem(folder, duration)
end

--[[ The gust itself: white streaks blown out along the cone for its whole
     `duration`. ]]
function RocFx.gust(
	parent: Instance,
	origin: Vector3,
	direction: Vector3,
	duration: number,
	reach: number,
	angle: number
)
	local ahead = facing(direction)
	local streaks = 18
	for i = 1, streaks do
		local along = turned(ahead, math.rad((math.random() - 0.5) * angle))
		local start = origin
			+ along * (2 + math.random() * 3)
			+ Vector3.new(0, 0.8 + math.random() * 2.4, 0)
		local finish = start + along * reach
		local streak = cube(parent, Vector3.new(0.16, 0.16, 2.4), RocFx.WIND)
		streak.CFrame = CFrame.lookAt(start, finish)
		streak.Transparency = 0.2
		local delay = (i - 1) / streaks * math.max(duration - 0.45, 0)
		TweenService:Create(
			streak,
			TweenInfo.new(0.45, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, delay),
			{ CFrame = CFrame.lookAt(finish, finish + along), Transparency = 1 }
		):Play()
		Debris:AddItem(streak, delay + 0.5)
	end
end

--[[ The swipe landing: three claw marks raked across its arc. ]]
function RocFx.swipe(
	parent: Instance,
	origin: Vector3,
	direction: Vector3,
	reach: number,
	angle: number
)
	local ahead = facing(direction)
	for i = -1, 1 do
		local along = turned(ahead, math.rad(i * angle / 4))
		local centre = origin + along * (reach * 0.6) + Vector3.new(0, 0.25, 0)
		local side = Vector3.new(-along.Z, 0, along.X)
		local mark = cube(parent, Vector3.new(0.35, 0.2, reach * 0.7), RocFx.BOLT)
		mark.CFrame = CFrame.lookAt(centre, centre + side)
		TweenService:Create(mark, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		Debris:AddItem(mark, 0.35)
	end
end

--[[ A lightning bolt onto `at`: a jagged column of neon cubes from high
     overhead to the floor, flashing out. ]]
function RocFx.bolt(parent: Instance, at: Vector3, radius: number)
	local folder = Instance.new("Folder")
	folder.Name = "RocBolt"
	folder.Parent = parent
	local top = 34
	local segments = 6
	local previous = Vector3.new(at.X, top, at.Z)
	for i = 1, segments do
		local y = top * (1 - i / segments)
		local jitter = if i == segments
			then Vector3.zero
			else Vector3.new((math.random() - 0.5) * 2.4, 0, (math.random() - 0.5) * 2.4)
		local point = Vector3.new(at.X, y, at.Z) + jitter
		local length = (point - previous).Magnitude
		local piece = cube(folder, Vector3.new(0.6, 0.6, length), RocFx.BOLT)
		piece.CFrame = CFrame.lookAt((previous + point) / 2, point)
		previous = point
	end
	local flash = cube(folder, Vector3.new(radius * 2, 0.2, radius * 2), RocFx.BOLT)
	flash.Position = Vector3.new(at.X, 0.2, at.Z)
	for _, child in folder:GetChildren() do
		TweenService:Create(child :: Part, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	end
	Debris:AddItem(folder, 0.4)
end

return RocFx
