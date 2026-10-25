--!strict
--[[
	Life in the forest past the walls (the owner's
	design_handoff_forest_ambience, 2026-10-23): leaves fluttering down and
	settling on the canopy, fireflies and butterflies over the treetops, a
	faint mist hanging in them, a flock of birds crossing now and then, and
	slanting shafts of light that breathe. The design shows them on the
	forest floor; the camera looks straight down onto the canopy, which hides
	the floor, so here they live on top of the trees.

	Only on this client, and never inside the room: everything lives in
	strips of floor past the walls, worked out from the room's own size
	(`Balance.Arena`), so nothing in the scenery needs tagging. It runs
	while the room's arena asks for it (the `Ambience` attribute
	`Arena.build` stamps from `ArenaModels.ambience`), and draws the
	device tier's share (`DeviceTiers.ambienceShare`). Numbers:
	`Balance.Ambience`, an entry per area (the glade's Forest, Thornwood's
	crows and pollen), named by that attribute.

	The handoff also sways each tree in the gusts. The glades' trees are
	one merged mesh, so that waits until they are split into trees.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AmbienceVolumes = require(ReplicatedStorage.Shared.Util.AmbienceVolumes)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)

local ForestAmbience = {}

--[[ Twice the design's leaf and butterfly: they are seen from the top-down
     camera's height, where the design's sizes were specks. ]]
local LEAF_SIZE = Vector3.new(0.7, 0.04, 0.45)

type Volume = AmbienceVolumes.Volume

type Leaf = {
	part: Part,
	live: boolean,
	position: Vector3,
	fall: number,
	phase: number,
	spin: Vector3,
	turn: CFrame,
	landed: boolean,
	rest: number,
	--[[ The height of the canopy it settles on. ]]
	settle: number,
}

type Bird = { left: Part, right: Part, offset: Vector3, phase: number }
type Flock = { birds: { Bird }, from: Vector3, to: Vector3, t: number, duration: number }
type Butterfly = { left: Part, right: Part, phase: number, home: Volume?, centre: Vector3 }
type Shaft = { part: Part, rest: number, phase: number }

--[[ The trees' crowns, read from the arena as it arrives: each a disc on
     the map and the height of its top. Everything that lives on the canopy
     sits on these rather than at a fixed height, so nothing passes through
     a tree (owner, 2026-10-24: "there is a bit of clipping in the trees on
     the outer arena when walking"). ]]
type Crown = { x: number, z: number, radius: number, top: number }
local CROWN_PREFIX = "CanopyMesh"
--[[ A crown's footprint as a share of its narrower side: its corners are
     leaves, not a canopy to settle on. ]]
local CROWN_REACH = 0.45
local crowns: { Crown } = {}
local crownsTop = 0
local crownsChanged = false
local arenaConnection: RBXScriptConnection? = nil

local folder: Folder? = nil
local volumes: { Volume } = {}
local leaves: { Leaf } = {}
local butterflies: { Butterfly } = {}
local shafts: { Shaft } = {}
local flock: Flock? = nil
local nextFlock = 5
local clock = 0
local leafDebt = 0

--[[ The `Balance.Ambience` entry the room's arena asks for: the glade's
     Forest, or Thornwood's crows and pollen. ]]
local entry = "Forest"

local function config()
	return (Balance.Ambience :: any)[entry] or Balance.Ambience.Forest
end

local function share(count: number): number
	return math.floor(count * Device.tier().ambienceShare + 0.5)
end

local function between(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

--[[ The gust band sweeping across: 0 calm, 1 at its height. ]]
local function gust(at: Vector3): number
	return math.max(0, math.sin(at.X * 0.08 + at.Z * 0.05 - clock * config().gustSpeed)) ^ 4
end

local function effectPart(parent: Instance, size: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function addCrown(part: Instance)
	if not part:IsA("BasePart") or string.sub(part.Name, 1, #CROWN_PREFIX) ~= CROWN_PREFIX then
		return
	end
	local top = part.Position.Y + part.Size.Y / 2
	table.insert(crowns, {
		x = part.Position.X,
		z = part.Position.Z,
		radius = math.min(part.Size.X, part.Size.Z) * CROWN_REACH,
		top = top,
	})
	crownsTop = math.max(crownsTop, top)
	crownsChanged = true
end

--[[ The top of the crown over (x, z), or nil where no crown covers it. ]]
local function crownAt(x: number, z: number): number?
	local best: number? = nil
	for _, crown in crowns do
		local dx, dz = x - crown.x, z - crown.z
		if dx * dx + dz * dz <= crown.radius * crown.radius and (not best or crown.top > best) then
			best = crown.top
		end
	end
	return best
end

--[[ How high the canopy life floats: clear of the tallest crown, or the
     configured height where the arena has no crowns. ]]
local function hoverHeight(): number
	local c = config()
	return if #crowns > 0 then crownsTop + c.clearance else c.hover
end

local function buildVolumes(): { Volume }
	return AmbienceVolumes.strips(Balance.Arena, config())
end

local function pointIn(volume: Volume, height: number): Vector3
	return volume.centre
		+ Vector3.new(
			(math.random() - 0.5) * volume.size.X,
			height,
			(math.random() - 0.5) * volume.size.Z
		)
end

--[[ A random volume, weighted by its floor area. ]]
local function pickVolume(): Volume
	local total = 0
	for _, v in volumes do
		total += v.size.X * v.size.Z
	end
	local pick = math.random() * total
	for _, v in volumes do
		pick -= v.size.X * v.size.Z
		if pick <= 0 then
			return v
		end
	end
	return volumes[#volumes]
end

--[[ Fireflies and mist hang in each volume as emitters, sized to it. ]]
local function addEmitters(parent: Instance, volume: Volume)
	local c = config()
	local tier = Device.tier().ambienceShare
	local area = volume.size.X * volume.size.Z
	local box = effectPart(parent, Vector3.new(volume.size.X, 3, volume.size.Z), Color3.new())
	box.Name = "AmbienceVolume"
	box.Transparency = 1
	-- the box's floor clear of every crown, so nothing hangs inside a tree
	box.Position = volume.centre + Vector3.new(0, hoverHeight() + 1.5 - c.clearance / 2, 0)

	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Name = "Fireflies"
	fireflies.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fireflies.Shape = Enum.ParticleEmitterShape.Box
	fireflies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	fireflies.Color = ColorSequence.new(c.fireflyColor)
	fireflies.LightEmission = 1
	fireflies.LightInfluence = 0
	fireflies.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	fireflies.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(0.85, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fireflies.Lifetime = NumberRange.new(4, 7)
	fireflies.Rate = math.clamp(area / 60 * c.fireflyDensity, 1, 8) * tier
	fireflies.Speed = NumberRange.new(0.2, 0.6)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.Acceleration = Vector3.new(0, 0.05, 0)
	fireflies.RotSpeed = NumberRange.new(-20, 20)
	fireflies.Parent = box

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	mist.Color = ColorSequence.new(c.mistColor)
	mist.LightInfluence = 0.6
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 8),
		NumberSequenceKeypoint.new(1, 14),
	})
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Lifetime = NumberRange.new(12, 18)
	mist.Rate = math.clamp(area / 400 * c.mistDensity, 0.1, 1) * tier
	mist.Speed = NumberRange.new(0.3, 0.7)
	mist.SpreadAngle = Vector2.new(180, 0)
	mist.EmissionDirection = Enum.NormalId.Front
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-3, 3)
	mist.Parent = box
end

--[[ Each shaft slants up from the sun's side with its foot on a crown's
     top, so it falls on the treetops rather than through them; with no
     crowns, on the forest floor. ]]
local function placeShafts()
	for _, shaft in shafts do
		local at: Vector3
		if #crowns > 0 then
			local crown = crowns[math.random(1, #crowns)]
			local angle = math.random() * math.pi * 2
			local r = math.random() * crown.radius * 0.6
			at =
				Vector3.new(crown.x + math.cos(angle) * r, crown.top, crown.z + math.sin(angle) * r)
		else
			at = pointIn(pickVolume(), 0)
		end
		shaft.part.CFrame = CFrame.new(at)
			* CFrame.Angles(0, math.random() * math.pi * 2, math.rad(70))
			* CFrame.new(13, 0, 0)
	end
	crownsChanged = false
end

local function build()
	local c = config()
	local made = Instance.new("Folder")
	made.Name = "ForestAmbience"
	folder = made
	volumes = buildVolumes()
	for _, volume in volumes do
		addEmitters(made, volume)
	end

	leaves = {}
	for i = 1, share(c.leafPool) do
		local part = effectPart(made, LEAF_SIZE, c.leafColors[(i % #c.leafColors) + 1])
		part.Name = "Leaf"
		part.Transparency = 1
		table.insert(leaves, {
			part = part,
			live = false,
			position = Vector3.zero,
			fall = 0,
			phase = 0,
			spin = Vector3.zero,
			turn = CFrame.identity,
			landed = false,
			rest = 0,
			settle = 0,
		})
	end

	butterflies = {}
	for i = 1, share(c.butterflies) do
		local colour = c.butterflyColors[(i % #c.butterflyColors) + 1]
		table.insert(butterflies, {
			left = effectPart(made, Vector3.new(0.55, 0.04, 0.45), colour),
			right = effectPart(made, Vector3.new(0.55, 0.04, 0.45), colour),
			phase = math.random() * math.pi * 2,
			home = nil,
			centre = Vector3.zero,
		})
	end

	shafts = {}
	for _ = 1, share(c.lightShafts) do
		local shaft = effectPart(made, Vector3.new(3, 26, 3), c.shaftColor)
		shaft.Name = "LightShaft"
		shaft.Shape = Enum.PartType.Cylinder
		shaft.Material = Enum.Material.Neon
		shaft.Transparency = c.shaftTransparency
		table.insert(
			shafts,
			{ part = shaft, rest = c.shaftTransparency, phase = math.random() * 6.28 }
		)
	end
	placeShafts()

	flock = nil
	nextFlock = 5
	made.Parent = Workspace
end

local function teardown()
	if folder then
		folder:Destroy()
		folder = nil
	end
	flock = nil
end

local function spawnLeaf()
	local c = config()
	for _, leaf in leaves do
		if not leaf.live then
			leaf.position = pointIn(pickVolume(), between(c.leafFrom))
			leaf.settle = if #crowns > 0 then 0 else between(c.canopy)
			leaf.fall = between(c.leafFall)
			leaf.phase = math.random() * 6.28
			leaf.spin =
				Vector3.new(math.random() * 6 - 3, math.random() * 6 - 3, math.random() * 6 - 3)
			leaf.turn = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			leaf.landed = false
			leaf.rest = 0
			leaf.live = true
			leaf.part.Transparency = 0
			return
		end
	end
end

local function makeFlock(parent: Instance): Flock
	local c = config()
	local angle = math.random() * math.pi * 2
	local across = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 110
	local height = Vector3.new(0, c.birdHeight + math.random() * 4, 0)
	local from = height + across
	local to = height - across + Vector3.new(math.random(-30, 30), 0, math.random(-30, 30))
	local birds: { Bird } = {}
	for i = 1, share(c.birds) do
		local side = if i % 2 == 0 then 1 else -1
		local rank = math.ceil(i / 2)
		table.insert(birds, {
			left = effectPart(parent, Vector3.new(1.4, 0.05, 0.5), c.birdColor),
			right = effectPart(parent, Vector3.new(1.4, 0.05, 0.5), c.birdColor),
			offset = Vector3.new(side * rank * 3, math.random() - 0.5, rank * 3),
			phase = math.random() * 6.28,
		})
	end
	return {
		birds = birds,
		from = from,
		to = to,
		t = 0,
		duration = (to - from).Magnitude / c.birdSpeed,
	}
end

local function step(dt: number)
	local parent = folder
	if not parent then
		return
	end
	local c = config()
	clock += dt
	--[[ Crowns still arriving: the shafts and the hanging life follow them,
	     no more than a few times a second. ]]
	if crownsChanged and math.floor(clock * 4) ~= math.floor((clock - dt) * 4) then
		placeShafts()
		for _, box in parent:GetChildren() do
			if box.Name == "AmbienceVolume" and box:IsA("BasePart") then
				box.Position = Vector3.new(
					box.Position.X,
					hoverHeight() + 1.5 - c.clearance / 2,
					box.Position.Z
				)
			end
		end
	end

	for _, shaft in shafts do
		shaft.part.Transparency =
			math.clamp(shaft.rest + 0.05 * math.sin(clock * 0.4 + shaft.phase), 0, 1)
	end

	-- Leaves: flutter down, drift with the gusts, land flat, then fade.
	leafDebt += dt * c.leavesPerSecond * Device.tier().ambienceShare
	while leafDebt >= 1 do
		leafDebt -= 1
		spawnLeaf()
	end
	for _, leaf in leaves do
		if not leaf.live then
			continue
		end
		if not leaf.landed then
			local push = gust(leaf.position)
			leaf.position += Vector3.new(
				(math.sin(clock * 1.6 + leaf.phase) * 0.9 + 2.2 * push) * dt,
				-leaf.fall * dt * (0.8 + 0.4 * math.sin(clock * 3 + leaf.phase)),
				math.cos(clock * 1.3 + leaf.phase) * 0.7 * dt
			)
			leaf.turn *= CFrame.Angles(leaf.spin.X * dt, leaf.spin.Y * dt, leaf.spin.Z * dt)
			--[[ Settles on the crown below it, or on the forest floor in a
			     gap between trees; at a fixed height where there are no
			     crowns. ]]
			if #crowns > 0 then
				leaf.settle = (crownAt(leaf.position.X, leaf.position.Z) or 0) + 0.05
			end
			if leaf.position.Y <= leaf.settle then
				leaf.landed = true
				leaf.part.CFrame = CFrame.new(leaf.position.X, leaf.settle, leaf.position.Z)
					* CFrame.Angles(0, math.random() * 6, 0)
			else
				leaf.part.CFrame = CFrame.new(leaf.position) * leaf.turn
			end
		else
			leaf.rest += dt
			leaf.part.Transparency = math.clamp((leaf.rest - c.leafRest) / c.leafFade, 0, 1)
			if leaf.rest > c.leafRest + c.leafFade then
				leaf.live = false
				leaf.part.Transparency = 1
			end
		end
	end

	-- Birds: a flock now and then, flapping with short glides.
	nextFlock -= dt
	local current = flock
	if not current and nextFlock <= 0 and share(c.birds) > 0 then
		current = makeFlock(parent)
		flock = current
	end
	if current then
		current.t += dt
		local along = math.min(1, current.t / current.duration)
		local heading = CFrame.lookAt(current.from:Lerp(current.to, along), current.to)
		for _, bird in current.birds do
			local glide = if math.sin(clock * 0.7 + bird.phase) > 0.3 then 0.15 else 1
			local flap = 0.6 * math.sin(clock * 9 + bird.phase) * glide
			local body = heading * CFrame.new(bird.offset)
			bird.left.CFrame = body * CFrame.Angles(0, 0, flap) * CFrame.new(-0.7, 0, 0)
			bird.right.CFrame = body * CFrame.Angles(0, 0, -flap) * CFrame.new(0.7, 0, 0)
		end
		if along >= 1 then
			for _, bird in current.birds do
				bird.left:Destroy()
				bird.right:Destroy()
			end
			flock = nil
			nextFlock = between(c.birdGap)
		end
	end

	-- Butterflies: each wanders a small loop just over the treetops.
	for _, fly in butterflies do
		if not fly.home then
			local home = pickVolume()
			fly.home = home
			fly.centre = pointIn(home, 0)
		end
		local wander = clock * 0.5 + fly.phase
		local at = fly.centre
			+ Vector3.new(
				math.cos(wander) * 3,
				hoverHeight()
					+ 0.5 * math.sin(clock * 1.3 + fly.phase)
					+ 0.15 * math.sin(clock * 7 + fly.phase),
				math.sin(wander * 1.3) * 3
			)
		local ahead = fly.centre
			+ Vector3.new(math.cos(wander + 0.1) * 3, 0, math.sin((wander + 0.1) * 1.3) * 3)
		local body = CFrame.lookAt(at, Vector3.new(ahead.X, at.Y, ahead.Z))
		local flap = 1.1 * math.sin(clock * 16 + fly.phase)
		fly.left.CFrame = body * CFrame.Angles(0, 0, flap) * CFrame.new(-0.28, 0, 0)
		fly.right.CFrame = body * CFrame.Angles(0, 0, -flap) * CFrame.new(0.28, 0, 0)
	end
end

--[[ Follows the room's arena: on while it asks for the forest, off
     otherwise, rebuilt with each room. ]]
function ForestAmbience.start()
	local current: Instance? = nil
	local function follow(arena: Instance?)
		current = arena
		teardown()
		table.clear(crowns)
		crownsTop = 0
		if arenaConnection then
			arenaConnection:Disconnect()
			arenaConnection = nil
		end
		if arena then
			for _, d in arena:GetDescendants() do
				addCrown(d)
			end
			-- a big arena reaches a client over several frames
			arenaConnection = arena.DescendantAdded:Connect(addCrown)
		end
		local name = arena and arena:GetAttribute("Ambience")
		if type(name) == "string" and (Balance.Ambience :: any)[name] ~= nil then
			entry = name
			if Device.tier().ambienceShare > 0 then
				build()
			end
		end
	end
	local function watch(child: Instance)
		if child.Name == "Arena" and child:IsA("Folder") then
			follow(child)
			child:GetAttributeChangedSignal("Ambience"):Connect(function()
				if current == child then
					follow(child)
				end
			end)
			--[[ Only the room still showing: an old arena going after the
			     new one arrived must not take the new forest with it. ]]
			child.Destroying:Connect(function()
				if current == child then
					follow(nil)
				end
			end)
		end
	end
	for _, child in Workspace:GetChildren() do
		watch(child)
	end
	Workspace.ChildAdded:Connect(watch)
	RunService.RenderStepped:Connect(step)
end

return ForestAmbience
