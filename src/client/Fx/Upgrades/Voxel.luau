--!strict
--[[
	The blocky pieces the class upgrades' effects are made of (`RangerBuildFx`,
	`ArcanistBuildFx`, `WardenBuildFx`): cubes, flung, ringed and flashed, in
	the game's chunky voxel look. Each runs on one RenderStepped connection
	and cleans itself up; counts are budgeted by the device tier
	(`DeviceTiers.mythicFxShare`), as `Fx/MythicFx`'s are.

	Presentation only.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Parent.Parent.Device)

local Voxel = {}

local GRAVITY = 40

local holder: Folder? = nil

--[[ The folder every piece lives in, made once. ]]
function Voxel.folder(): Folder
	local existing = holder
	if existing and existing.Parent then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "ClassUpgradeFx"
	folder.Parent = Workspace
	holder = folder
	return folder
end

--[[ `count` scaled by the device's share, never below one. ]]
function Voxel.share(count: number): number
	return math.max(1, math.floor(count * Device.tier().mythicFxShare + 0.5))
end

--[[ The rainbow at time `t`, as a Mythic's glow cycles (rule 12). ]]
function Voxel.rainbow(t: number, offset: number?): Color3
	return Color3.fromHSV((t * 0.5 + (offset or 0)) % 1, 0.75, 1)
end

--[[ One cube: anchored, never touched or hit, `neon` to glow. ]]
function Voxel.cube(size: Vector3 | number, colour: Color3, neon: boolean?, parent: Instance?): Part
	local part = Instance.new("Part")
	part.Name = "Voxel"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = if typeof(size) == "number" then Vector3.one * size else size
	part.Color = colour
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Parent = parent or Voxel.folder()
	return part
end

--[[ A light on `part`. ]]
function Voxel.light(part: BasePart, colour: Color3, range: number, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = range
	light.Brightness = brightness or 2
	light.Shadows = false
	light.Parent = part
	return light
end

--[[ Runs `pose(t, dt)` every frame for `life` seconds (t from 0 to 1), then
     `done`. `pose` returning false ends it early. ]]
function Voxel.run(life: number, pose: (t: number, dt: number) -> boolean?, done: (() -> ())?)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		local t = (os.clock() - started) / life
		local keep = if t < 1 then pose(math.min(t, 1), dt) else false
		if t >= 1 or keep == false then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
end

--[[ Cubes flung out of `at`, falling and spinning, fading at the end. ]]
function Voxel.burst(
	at: Vector3,
	count: number,
	colours: { Color3 },
	speed: number,
	life: number,
	size: number?,
	up: number?
)
	local n = Voxel.share(count)
	local pieces: { { part: Part, velocity: Vector3, spin: Vector3 } } = {}
	for index = 1, n do
		local s = (size or 0.6) * (0.6 + math.random() * 0.8)
		local part = Voxel.cube(s, colours[(index - 1) % #colours + 1], true)
		part.CFrame = CFrame.new(at)
		local angle = math.random() * math.pi * 2
		local out = speed * (0.5 + math.random() * 0.7)
		table.insert(pieces, {
			part = part,
			velocity = Vector3.new(
				math.cos(angle) * out,
				(up or speed) * (0.4 + math.random() * 0.8),
				math.sin(angle) * out
			),
			spin = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8),
		})
	end
	local elapsed = 0
	Voxel.run(life, function(t, dt)
		elapsed += dt
		for _, piece in pieces do
			piece.velocity -= Vector3.new(0, GRAVITY * dt, 0)
			local position = piece.part.Position + piece.velocity * dt
			if position.Y < 0.2 then
				position = Vector3.new(position.X, 0.2, position.Z)
				piece.velocity = Vector3.new(piece.velocity.X * 0.5, 0, piece.velocity.Z * 0.5)
			end
			piece.part.CFrame = CFrame.new(position)
				* CFrame.Angles(
					piece.spin.X * elapsed,
					piece.spin.Y * elapsed,
					piece.spin.Z * elapsed
				)
			piece.part.Transparency = math.clamp((t - 0.6) / 0.4, 0, 1)
		end
		return nil
	end, function()
		for _, piece in pieces do
			piece.part:Destroy()
		end
	end)
end

--[[ A ring of cubes on the floor spreading from `at` out to `radius`. ]]
function Voxel.ring(at: Vector3, radius: number, colours: { Color3 }, life: number, height: number?)
	local n = Voxel.share(math.clamp(math.floor(radius * 4), 12, 36))
	local parts: { Part } = {}
	for index = 1, n do
		table.insert(parts, Voxel.cube(0.7, colours[(index - 1) % #colours + 1], true))
	end
	Voxel.run(life, function(t)
		local ease = 1 - (1 - t) ^ 3
		local r = radius * ease
		for index, part in parts do
			local angle = (index / n) * math.pi * 2
			part.CFrame = CFrame.new(
				at.X + math.cos(angle) * r,
				(height or 0.4) + math.sin(t * math.pi) * 0.4,
				at.Z + math.sin(angle) * r
			) * CFrame.Angles(0, -angle, 0)
			part.Size = Vector3.one * (0.9 - 0.5 * t)
			part.Transparency = t ^ 2
		end
		return nil
	end, function()
		for _, part in parts do
			part:Destroy()
		end
	end)
end

--[[ A glowing cube that grows from nothing to `size` and fades: a flash. ]]
function Voxel.flash(at: Vector3, size: number, colour: Color3, life: number)
	local part = Voxel.cube(0.1, colour, true)
	part.Shape = Enum.PartType.Ball
	local light = Voxel.light(part, colour, size * 2, 4)
	Voxel.run(life, function(t)
		local ease = 1 - (1 - t) ^ 2
		part.Size = Vector3.one * math.max(0.1, size * ease)
		part.CFrame = CFrame.new(at)
		part.Transparency = 0.15 + 0.85 * t
		light.Brightness = 4 * (1 - t)
		return nil
	end, function()
		part:Destroy()
	end)
end

--[[ A chunky voxel arrow (shaft, red head, white fletching) pointing down
     its -Z, `scale` times arrow size, glowing `glow` when given. ]]
function Voxel.arrow(scale: number, glow: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "VoxelArrow"
	local shaft =
		Voxel.cube(Vector3.new(0.3, 0.3, 2.6) * scale, Color3.fromRGB(150, 92, 46), false, model)
	shaft.CFrame = CFrame.new()
	local head =
		Voxel.cube(Vector3.new(0.7, 0.7, 0.7) * scale, Color3.fromRGB(230, 60, 50), false, model)
	head.CFrame = CFrame.new(0, 0, -1.5 * scale) * CFrame.Angles(0, math.rad(45), 0)
	local fletch =
		Voxel.cube(Vector3.new(0.9, 0.12, 0.7) * scale, Color3.new(1, 1, 1), false, model)
	fletch.CFrame = CFrame.new(0, 0, 1.2 * scale)
	local fletch2 =
		Voxel.cube(Vector3.new(0.12, 0.9, 0.7) * scale, Color3.new(1, 1, 1), false, model)
	fletch2.CFrame = CFrame.new(0, 0, 1.2 * scale)
	if glow then
		local halo = Voxel.cube(Vector3.new(0.6, 0.6, 3.2) * scale, glow, true, model)
		halo.CFrame = CFrame.new()
		halo.Transparency = 0.7
	end
	model.PrimaryPart = shaft
	model.Parent = Voxel.folder()
	return model
end

return Voxel
