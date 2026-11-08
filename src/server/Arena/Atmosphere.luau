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
Atmosphere.GlowName = "Bloom"

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

--[[ What the room asks for and what the lobby does. The lobby's golden hour
     wins while players are there: a room is built ahead of the door, which
     must not change the light they stand in, and the room's comes back the
     moment they leave. ]]
local roomLight: { [string]: any }? = nil
local lobbyLight: { [string]: any }? = nil

local function show(overrides: { [string]: any }?)
	local config: any = Balance.Lighting
	if overrides then
		config = table.clone(config)
		for key, value in overrides do
			config[key] = value
		end
	end

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

	--[[ The lobby's extra effects, under the names the owner made them with
	     in Studio so these take those over; off everywhere else. ]]
	local glow: BloomEffect = ensure("BloomEffect", Atmosphere.GlowName)
	glow.Enabled = config.glow ~= nil
	if config.glow then
		glow.Intensity = config.glow.intensity
		glow.Size = config.glow.size
		glow.Threshold = config.glow.threshold
	end

	local colour: ColorCorrectionEffect = ensure("ColorCorrectionEffect", "ColorCorrection")
	colour.Enabled = config.colour ~= nil
	if config.colour then
		colour.Saturation = config.colour.saturation
		colour.Contrast = config.colour.contrast
		colour.Brightness = config.colour.brightness
		colour.TintColor = config.colour.tint
	end

	local rays: SunRaysEffect = ensure("SunRaysEffect", "SunRays")
	rays.Enabled = config.sunRays ~= nil
	if config.sunRays then
		rays.Intensity = config.sunRays.intensity
		rays.Spread = config.sunRays.spread
	end
end

--[[ `overrides` is an area's own (`ArenaModels.lighting`): those fields in
     place of `Balance.Lighting`'s, the rest as ever. Applied again with
     none to put the game's own light back. ]]
function Atmosphere.apply(overrides: { [string]: any }?)
	roomLight = overrides
	show(lobbyLight or roomLight)
end

--[[ The lobby's light while players are in it (`Config/Lobby.light`), or nil
     to go back to the room's. ]]
function Atmosphere.lobby(light: { [string]: any }?)
	lobbyLight = light
	show(lobbyLight or roomLight)
end

return Atmosphere
