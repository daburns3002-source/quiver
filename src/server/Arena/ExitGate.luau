--!strict
--[[
	The exit: a stone gatehouse in the gap of the north wall, after Archero 2's
	(owner, 2026-10-22, from footage). While enemies remain it is shut by two
	wooden doors over a dark purple haze; when the room is cleared the doors
	swing open towards the room (owner, 2026-10-23: "a semblance of an actual
	door opening"), the doorway behind blazes white-gold, throws light and
	sparkles into the room, and an arrow on the floor points the way. A
	plaque over the doorway carries the next room's number.

	Presentation only. Whether a player has reached the exit is still
	`Arena.isAtDoor`, against `Balance.Run.doorOffset`, which sits in front
	of this doorway. Nothing here collides, answers a raycast or stops an
	arrow.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local ExitGate = {}

--[[ One door leaf: everything on it is welded to an invisible hinge part
     on the pillar's edge, which is all that turns, so the leaf sweeps an
     arc about its hinge rather than sliding. ]]
type Leaf = {
	hinge: Part,
	shut: CFrame,
	--[[ -1 for the left leaf, 1 for the right: which way it turns open. ]]
	side: number,
}

export type Gate = {
	leaves: { Leaf },
	fill: Part,
	light: PointLight,
	sparkles: ParticleEmitter,
	glow: Part,
	arrow: { BasePart },
	label: TextLabel,
}

local function piece(
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[ One leaf of the double door, shut, hinged on the inner edge of the
     pillar on `side` (-1 left, 1 right): vertical planks, two iron bands
     and a ring handle near the middle, facing the room. ]]
local function buildLeaf(
	folder: Instance,
	side: number,
	width: number,
	height: number,
	front: number
): Leaf
	local config = Balance.Run.gate
	local leafWidth = width / 2
	local thickness = 0.3
	local z = front + 0.05
	--[[ The leaf runs from its hinge towards the middle: +X for the left
	     leaf, -X for the right. ]]
	local inward = -side
	local hingeAt = CFrame.new(side * width / 2, height / 2, z)

	local hinge = piece("DoorHinge", Vector3.new(0.2, 0.2, 0.2), hingeAt, config.doorColor, folder)
	hinge.Transparency = 1

	local function attach(
		name: string,
		size: Vector3,
		offset: Vector3,
		colour: Color3,
		material: Enum.Material?,
		turn: CFrame?
	): Part
		local part = piece(
			name,
			size,
			hingeAt * CFrame.new(offset) * (turn or CFrame.identity),
			colour,
			folder
		)
		part.Anchored = false
		part.Massless = true
		if material then
			part.Material = material
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hinge
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	--[[ A hair short of the middle and the floor, so the two leaves and
	     the ground never share a face. ]]
	local span = leafWidth - 0.05
	attach(
		"Door",
		Vector3.new(span, height - 0.1, thickness),
		Vector3.new(inward * span / 2, 0.05, 0),
		config.doorColor,
		Enum.Material.Wood
	)
	-- Plank seams, standing a little proud of the face.
	for i = 1, 2 do
		attach(
			"DoorSeam",
			Vector3.new(0.08, height - 0.3, 0.06),
			Vector3.new(inward * span * i / 3, 0.05, thickness / 2 + 0.02),
			config.doorPlankColor
		)
	end
	-- Two iron bands across the leaf.
	for _, y in { height * 0.28, -height * 0.28 } do
		attach(
			"DoorBand",
			Vector3.new(span, 0.32, 0.08),
			Vector3.new(inward * span / 2, y, thickness / 2 + 0.04),
			config.doorBandColor,
			Enum.Material.Metal
		)
	end
	-- A ring handle near the meeting edge.
	--[[ A cylinder's axis is its X, so it is turned to stand out of the
	     door like a ring seen face-on. ]]
	local ring = attach(
		"DoorRing",
		Vector3.new(0.12, 0.7, 0.7),
		Vector3.new(inward * (span - 0.45), -0.2, thickness / 2 + 0.12),
		config.doorRingColor,
		Enum.Material.Metal,
		CFrame.Angles(0, math.rad(90), 0)
	)
	ring.Shape = Enum.PartType.Cylinder

	return { hinge = hinge, shut = hingeAt, side = side }
end

--[[ Builds the gate under `root`, closed. Its front sits on the inner face
     of the north wall, a hair into the room so the two never share a
     plane. ]]
function ExitGate.build(root: Instance): Gate
	local config = Balance.Run.gate
	local folder = Instance.new("Folder")
	folder.Name = "ExitGate"
	folder.Parent = root

	local front = -Balance.Arena.size.Z / 2 + 0.2
	local depth = config.depth
	local z = front - depth / 2
	local width, height = config.width, config.height
	local pillar = config.pillarWidth
	local outer = width + pillar * 2

	for _, side in { -1, 1 } do
		local x = side * (width / 2 + pillar / 2)
		piece(
			"Pillar",
			Vector3.new(pillar, height + 1, depth),
			CFrame.new(x, (height + 1) / 2, z),
			config.stoneColor,
			folder
		)
		-- A moss cap on each pillar, a little wider than the stone.
		piece(
			"PillarMoss",
			Vector3.new(pillar + 0.3, 0.45, depth + 0.3),
			CFrame.new(x, height + 1.2, z),
			config.mossColor,
			folder
		)
	end

	local lintelY = height + 1.9
	piece(
		"Lintel",
		Vector3.new(outer + 0.6, 1.6, depth + 0.4),
		CFrame.new(0, lintelY, z),
		config.stoneColor,
		folder
	)

	-- A pitched roof: two wedges meeting over the lintel, in moss.
	local roofHeight = 2.2
	for _, side in { -1, 1 } do
		local wedge = piece(
			"Roof",
			Vector3.new(depth + 1, roofHeight, outer / 2 + 0.6),
			CFrame.new(side * (outer / 4 + 0.3), lintelY + 0.8 + roofHeight / 2, z)
				* CFrame.Angles(0, side * math.pi / 2, 0),
			config.roofColor,
			folder
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = wedge
	end

	-- The plaque with the next room's number, facing into the room.
	local plaque = piece(
		"Plaque",
		Vector3.new(3.2, 1.7, 0.3),
		CFrame.new(0, lintelY, front + 0.25),
		config.plaqueColor,
		folder
	)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(240, 130)
	surface.LightInfluence = 0
	surface.Parent = plaque
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = config.plaqueTextColor
	label.Text = ""
	label.Parent = surface

	-- The doorway itself: the haze when closed, the light when open.
	local fill = piece(
		"Doorway",
		Vector3.new(width, height, 0.4),
		CFrame.new(0, height / 2, front - 0.3),
		config.closedColor,
		folder
	)
	fill.CastShadow = false

	local light = Instance.new("PointLight")
	light.Color = config.openColor
	light.Range = config.lightRange
	light.Brightness = config.lightBrightness
	light.Shadows = false
	light.Parent = fill

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(config.openColor)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Rate = config.sparkleRate
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(35, 35)
	sparkles.EmissionDirection = Enum.NormalId.Back
	sparkles.Parent = fill

	-- Light spilling onto the floor in front of the doorway.
	local glow = piece(
		"Spill",
		Vector3.new(width + 1, 0.06, config.spillLength),
		CFrame.new(0, 0.05, front + config.spillLength / 2),
		config.openColor,
		folder
	)
	glow.Material = Enum.Material.Neon
	glow.CastShadow = false

	-- An arrow on the floor pointing into the doorway.
	--[[ Clear of the doorway's glare, and above the lawn and its grass
	     tufts: at floor height the model's ground hid it. ]]
	local arrowZ = Balance.Run.doorOffset.Y + 6.5
	local arrowY = 0.9
	local shaft = piece(
		"ArrowShaft",
		Vector3.new(1.1, 0.08, 2.4),
		CFrame.new(0, arrowY, arrowZ + 1.2),
		Color3.new(1, 1, 1),
		folder
	)
	-- The head: a chevron of two bars meeting at the point, towards the gate.
	local heads = {}
	for _, side in { -1, 1 } do
		table.insert(
			heads,
			piece(
				"ArrowHead",
				Vector3.new(1.1, 0.08, 2.6),
				CFrame.new(side * 0.8, arrowY, arrowZ - 0.55)
					* CFrame.Angles(0, side * math.rad(45), 0),
				Color3.new(1, 1, 1),
				folder
			)
		)
	end

	local leaves = {}
	for _, side in { -1, 1 } do
		table.insert(leaves, buildLeaf(folder, side, width, height, front))
	end

	local gate: Gate = {
		leaves = leaves,
		fill = fill,
		light = light,
		sparkles = sparkles,
		glow = glow,
		arrow = { shaft, heads[1], heads[2] },
		label = label,
	}
	ExitGate.setOpen(gate, false, true)
	return gate
end

--[[ Closed: the doors shut over a dark haze, no light, no arrow. Open: the
     doors swing wide and the doorway blazes. `instant` skips the swing, for
     a gate being built shut. ]]
function ExitGate.setOpen(gate: Gate, open: boolean, instant: boolean?)
	local config = Balance.Run.gate
	for _, leaf in gate.leaves do
		local target = if open
			then leaf.shut * CFrame.Angles(0, leaf.side * math.rad(config.doorOpenAngle), 0)
			else leaf.shut
		if instant then
			leaf.hinge.CFrame = target
		else
			TweenService:Create(
				leaf.hinge,
				TweenInfo.new(config.doorOpenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ CFrame = target }
			):Play()
		end
	end
	gate.fill.Color = if open then config.openColor else config.closedColor
	gate.fill.Material = if open then Enum.Material.Neon else Enum.Material.SmoothPlastic
	gate.fill.Transparency = if open then 0 else 0.15
	gate.light.Enabled = open
	gate.sparkles.Enabled = open
	gate.glow.Transparency = if open then 0.55 else 1
	for _, part in gate.arrow do
		part.Transparency = if open then 0.05 else 1
		part.Material = Enum.Material.Neon
	end
end

--[[ The plaque's text: the number of the room the gate leads to. ]]
function ExitGate.setLabel(gate: Gate, text: string)
	gate.label.Text = text
end

return ExitGate
