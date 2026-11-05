--!strict
--[[
	The lobby's air (`Config/Lobby.motes`, `mist`): gold motes drifting over the
	courtyard and mist at the foot of each waterfall, as the layout sheet's LIFE
	panel draws them. Only on this client, only while in the lobby, and the
	device tier's share of it (`DeviceTiers.ambienceShare`): it is background,
	the first thing a phone can spare.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Parent.Device)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)

local LobbyMotes = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local GOLD = Color3.fromRGB(255, 214, 120)

local function emitterPart(name: string, size: Vector3, at: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Position = at
	p.Parent = parent
	return p
end

function LobbyMotes.start()
	local share = Device.tier().ambienceShare
	if share <= 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "LobbyMotes"
	local origin = LobbyConfig.origin
	local emitters: { ParticleEmitter } = {}

	local motes = LobbyConfig.motes
	local air = emitterPart(
		"Motes",
		Vector3.new(170, motes.high, 150),
		origin + Vector3.new(0, motes.high / 2 + 1, 16),
		folder
	)
	local gold = Instance.new("ParticleEmitter")
	gold.Texture = SPARKLE
	gold.Color = ColorSequence.new(GOLD)
	gold.LightEmission = 1
	gold.LightInfluence = 0
	gold.Rate = motes.rate * share
	gold.Lifetime = motes.lifetime
	gold.Speed = NumberRange.new(0.3, 1.2)
	gold.SpreadAngle = Vector2.new(180, 180)
	gold.Acceleration = Vector3.new(0.12, 0.05, 0.08)
	gold.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, motes.size),
		NumberSequenceKeypoint.new(0.8, motes.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	gold.Parent = air
	table.insert(emitters, gold)

	local mist = LobbyConfig.mist
	for _, at in LobbyConfig.waterfalls do
		local foot = emitterPart(
			"Mist",
			Vector3.new(10, 1, 6),
			origin + Vector3.new(at.X, 0, at.Y):Lerp(Vector3.new(0, 0, 0), 0.05),
			folder
		)
		local cloud = Instance.new("ParticleEmitter")
		cloud.Texture = SMOKE
		cloud.Color = ColorSequence.new(Color3.fromRGB(255, 244, 236))
		cloud.Rate = mist.rate * share
		cloud.Lifetime = mist.lifetime
		cloud.Speed = NumberRange.new(1, 2.5)
		cloud.SpreadAngle = Vector2.new(40, 40)
		cloud.EmissionDirection = Enum.NormalId.Top
		cloud.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		})
		cloud.Size = NumberSequence.new(mist.size * 0.6, mist.size)
		cloud.Parent = foot
		table.insert(emitters, cloud)
	end
	folder.Parent = Workspace

	local function refresh()
		local inLobby = Workspace:GetAttribute("InLobby") == true
		for _, emitter in emitters do
			emitter.Enabled = inLobby
		end
	end
	refresh()
	Workspace:GetAttributeChangedSignal("InLobby"):Connect(refresh)
end

return LobbyMotes
