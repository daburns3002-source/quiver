--!strict
--[[
	The light the whole game is seen in.

	Archero 2 is lit bright and even, with nothing important ever in shadow,
	and a soft bloom that makes eyes, orbs and shots glow
	(docs/ART-archero2.md §2). This sets that once at boot, from
	`Balance.Lighting`, so a change of mood is a readable diff rather than a
	property edited in Studio and lost on the next sync.

	The bloom and colour grade are created here, on the server, so every
	client gets them; each client then switches the bloom off on its own if
	its device tier says to. Presentation only.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local Atmosphere = {}

--[[ Names the client looks these up by, to tier-gate the bloom. ]]
Atmosphere.BloomName = "ArenaBloom"
Atmosphere.GradeName = "ArenaGrade"

local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end

	if existing then
		existing:Destroy()
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

function Atmosphere.apply()
	local config = Balance.Lighting

	Lighting.Ambient = config.ambient
	Lighting.OutdoorAmbient = config.outdoorAmbient
	Lighting.Brightness = config.brightness
	Lighting.ClockTime = config.clockTime
	Lighting.GeographicLatitude = config.geographicLatitude
	Lighting.ColorShift_Top = config.sunTint
	Lighting.ShadowSoftness = config.shadowSoftness
	Lighting.EnvironmentDiffuseScale = config.environmentDiffuse
	Lighting.EnvironmentSpecularScale = config.environmentSpecular

	local bloom: BloomEffect = ensure("BloomEffect", Atmosphere.BloomName)
	bloom.Intensity = config.bloomIntensity
	bloom.Size = config.bloomSize
	bloom.Threshold = config.bloomThreshold

	local haze: Atmosphere = ensure("Atmosphere", "Atmosphere")
	haze.Density = config.hazeDensity
	haze.Color = config.hazeColor
	haze.Decay = config.hazeDecay
	haze.Glare = config.hazeGlare
	haze.Haze = config.haze

	local grade: ColorCorrectionEffect = ensure("ColorCorrectionEffect", Atmosphere.GradeName)
	grade.Saturation = config.saturation
	grade.Contrast = config.contrast
	grade.Brightness = config.gradeBrightness
	grade.TintColor = config.gradeTint
end

return Atmosphere
