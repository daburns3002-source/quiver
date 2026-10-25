--!strict
--[[
	A rare pet's aura (`Config/PetAuras`): the Mythic Glimmerhorn glows and
	sheds rainbow sparkles and a rainbow trail, the Legendary Slime Prince
	the same in gold. Presentation only, on this client, on the pets
	`Fx/PetPreview` brings out.

	The glow is a Highlight over the whole model; the sparkles are square
	(the blocky style) and rise from a box around the body; the trail runs
	between two points across the body, so it streams out behind it as it
	walks. A rainbow look turns its hues every frame. The box is kept beside
	the model, not in it, and moved with it each frame: `Fx/ModelAnimator`
	matches a pet's parts by name, and a stranger among them would stop it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetAuras = require(ReplicatedStorage.Shared.Config.PetAuras)

local PetAura = {}

type Worn = {
	model: Model,
	box: Part,
	offset: CFrame,
	look: PetAuras.Look,
	glow: Highlight,
	light: PointLight,
	sparkles: ParticleEmitter,
	trail: Trail,
}

local worn: { Worn } = {}
local stepping: RBXScriptConnection? = nil

-- The look's colours spread evenly over 0..1.
local function sequence(colours: { Color3 }): ColorSequence
	if #colours == 1 then
		return ColorSequence.new(colours[1])
	end
	local keys = {}
	for i, colour in colours do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colours - 1), colour))
	end
	return ColorSequence.new(keys)
end

-- The rainbow at hue `h`, five steps of it, for a sparkle's or trail's life.
local function rainbowAt(h: number): ColorSequence
	local colours = {}
	for i = 0, 4 do
		table.insert(colours, Color3.fromHSV((h + i * 0.2) % 1, 0.75, 1))
	end
	return sequence(colours)
end

local function step()
	local now = os.clock()
	for i = #worn, 1, -1 do
		local w = worn[i]
		if not w.model.Parent then
			w.box:Destroy()
			table.remove(worn, i)
			continue
		end
		w.box.CFrame = w.model:GetPivot() * w.offset
		local speed = w.look.rainbow
		if speed then
			local h = (now * speed) % 1
			local colour = Color3.fromHSV(h, 0.6, 1)
			w.glow.FillColor = colour
			w.glow.OutlineColor = Color3.fromHSV(h, 0.35, 1)
			w.light.Color = colour
			local cycle = rainbowAt(h)
			w.sparkles.Color = cycle
			w.trail.Color = cycle
		end
	end
	if #worn == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

--[[ Puts the aura of the pet `key` (a `Config/PetModels` key) on `model`,
     if its rarity has one. The aura goes with the model. ]]
function PetAura.wear(model: Model, key: string)
	local rarity = PetAuras.pets[key]
	local look = if rarity then PetAuras.looks[rarity] else nil
	if not look then
		return
	end
	local box, size = model:GetBoundingBox()

	local glow = Instance.new("Highlight")
	glow.Name = "AuraGlow"
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.FillColor = look.glow
	glow.OutlineColor = look.glow
	glow.FillTransparency = look.fill
	glow.OutlineTransparency = look.outline
	glow.Adornee = model
	glow.Parent = model

	-- An unseen box the pet's size, beside the model: the sparkles rise
	-- from it, the light and the trail ride on it.
	local spark = Instance.new("Part")
	spark.Name = "AuraBox"
	spark.Size = size * Vector3.new(1.2, 1, 1.2)
	spark.Transparency = 1
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.CanTouch = false
	spark.CastShadow = false
	spark.CFrame = box
	spark.Parent = model.Parent

	local light = Instance.new("PointLight")
	light.Color = look.glow
	light.Range = look.lightRange
	light.Brightness = look.lightBrightness
	light.Shadows = false
	light.Parent = spark

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "AuraSparkles"
	sparkles.Texture = PetAuras.square
	sparkles.Color = sequence(look.colours)
	sparkles.LightEmission = 1
	sparkles.LightInfluence = 0
	sparkles.Rate = look.sparkleRate
	sparkles.Lifetime = NumberRange.new(look.sparkleLife * 0.7, look.sparkleLife)
	sparkles.Speed = NumberRange.new(0.6, 1.4)
	sparkles.SpreadAngle = Vector2.new(25, 25)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Shape = Enum.ParticleEmitterShape.Box
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparkles.Rotation = NumberRange.new(0, 90)
	sparkles.RotSpeed = NumberRange.new(-90, 90)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, look.sparkleSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkles.Parent = spark

	-- across the body, low and high, so the ribbon streams out behind it
	local low = Instance.new("Attachment")
	low.Name = "AuraTrailLow"
	low.Position = Vector3.new(0, -size.Y * 0.3, 0)
	low.Parent = spark
	local high = Instance.new("Attachment")
	high.Name = "AuraTrailHigh"
	high.Position = Vector3.new(0, size.Y * 0.15, 0)
	high.Parent = spark
	local trail = Instance.new("Trail")
	trail.Name = "AuraTrail"
	trail.Attachment0 = low
	trail.Attachment1 = high
	trail.Color = sequence(look.colours)
	trail.Lifetime = look.trail
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = spark

	table.insert(worn, {
		model = model,
		box = spark,
		offset = model:GetPivot():ToObjectSpace(box),
		look = look,
		glow = glow,
		light = light,
		sparkles = sparkles,
		trail = trail,
	})
	if not stepping then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

return PetAura
