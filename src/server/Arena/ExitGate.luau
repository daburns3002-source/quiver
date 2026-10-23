--!strict
--[[
	The exit: a stone gatehouse in the gap of the north wall, after Archero 2's
	(owner, 2026-10-22, from footage). While enemies remain its doorway is a
	dark purple haze; when the room is cleared it blazes white-gold, throws
	light and sparkles into the room, and an arrow on the floor points the way. A plaque over the doorway carries the next room's number.

	Presentation only. Whether a player has reached the exit is still
	`Arena.isAtDoor`, against `Balance.Run.doorOffset`, which sits in front
	of this doorway. Nothing here collides, answers a raycast or stops an
	arrow.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local ExitGate = {}

export type Gate = {
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

	local gate: Gate = {
		fill = fill,
		light = light,
		sparkles = sparkles,
		glow = glow,
		arrow = { shaft, heads[1], heads[2] },
		label = label,
	}
	ExitGate.setOpen(gate, false)
	return gate
end

--[[ Closed: dark haze, no light, no arrow. Open: the doorway blazes. ]]
function ExitGate.setOpen(gate: Gate, open: boolean)
	local config = Balance.Run.gate
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
