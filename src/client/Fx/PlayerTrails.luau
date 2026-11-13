--!strict
--[[
	Every player's trail (`Config/Trails`), drawn on this client from the
	Player's `Trail` attribute (`TrailRules.ATTRIBUTE`, set by the server):
	a ribbon flat along the ground behind them and the trail's own square
	particles, as Codex's sheets show (`assets/concepts/blocky/ui/trails/`).
	A glowing one (every Legendary and the Mythic, rule 12) lights itself and
	carries a light.

	Built here rather than on the server so each device draws its own share
	of particles (`DeviceTiers.trailShare`) and no part is replicated. The
	particles run at full rate while the player moves and at `Trails.idle`
	of it while they stand, so a trail streams out as it should and does
	not heap up at a player's feet.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Device = require(script.Parent.Parent.Device)
local PetAuras = require(ReplicatedStorage.Shared.Config.PetAuras)
local TrailRules = require(ReplicatedStorage.Shared.Util.TrailRules)
local Trails = require(ReplicatedStorage.Shared.Config.Trails)

local PlayerTrails = {}

--[[ Studs a second across the ground above which a player is moving. ]]
local MOVING = 1.5
--[[ How far above the ground the ribbon lies, and behind the root its
     particles start, in studs. ]]
local LIFT = 0.15
local BEHIND = 0.6

type Worn = {
	root: BasePart,
	folder: Folder,
	emitters: { { emitter: ParticleEmitter, rate: number } },
	moving: boolean?,
}

local worn: { [Player]: Worn } = {}
local stepping: RBXScriptConnection? = nil

local function colours(list: { Color3 }): ColorSequence
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local points = {}
	for i, colour in list do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#list - 1), colour))
	end
	return ColorSequence.new(points)
end

--[[ How far below the root the feet are: R15 stands on its hip height,
     R6 on its two-stud legs. ]]
local function groundBelow(root: BasePart, humanoid: Humanoid): number
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	return root.Size.Y / 2 + legs
end

local function clear(player: Player)
	local w = worn[player]
	if w then
		w.folder:Destroy()
		worn[player] = nil
	end
end

local function step()
	for player, w in worn do
		if not w.root.Parent then
			clear(player)
			continue
		end
		local v = w.root.AssemblyLinearVelocity
		local moving = Vector3.new(v.X, 0, v.Z).Magnitude > MOVING
		if moving ~= w.moving then
			w.moving = moving
			for _, each in w.emitters do
				each.emitter.Rate = if moving then each.rate else each.rate * Trails.idle
			end
		end
	end
	if next(worn) == nil and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

--[[ Puts `key`'s trail on `character`, or nothing for nil or an unknown key. ]]
local function wear(player: Player, character: Model, key: unknown)
	clear(player)
	local trail = TrailRules.get(key)
	if not trail then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	-- the attribute or the character may have moved on while waiting
	if
		not root
		or not humanoid
		or player.Character ~= character
		or player:GetAttribute(TrailRules.ATTRIBUTE) ~= key
	then
		return
	end
	-- two asks can wait side by side (a new character and its attribute):
	-- whichever finishes last is the one worn, never both
	clear(player)
	local share = Device.tier().trailShare
	local down = groundBelow(root, humanoid) - LIFT

	local folder = Instance.new("Folder")
	folder.Name = "PlayerTrail"

	-- the ribbon: two points either side of the feet, so it lies flat
	local left = Instance.new("Attachment")
	left.Name = "TrailLeft"
	left.Position = Vector3.new(-trail.width / 2, -down, 0)
	left.Parent = root
	local right = Instance.new("Attachment")
	right.Name = "TrailRight"
	right.Position = Vector3.new(trail.width / 2, -down, 0)
	right.Parent = root
	local ribbon = Instance.new("Trail")
	ribbon.Name = "TrailRibbon"
	ribbon.Attachment0 = left
	ribbon.Attachment1 = right
	ribbon.Color = colours(trail.ribbon)
	ribbon.Lifetime = trail.life
	ribbon.MinLength = 0.05
	ribbon.FaceCamera = false
	ribbon.LightEmission = if trail.glow then 1 else 0.25
	ribbon.LightInfluence = if trail.glow then 0 else 0.6
	ribbon.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if trail.glow then 0.05 else 0.2),
		NumberSequenceKeypoint.new(0.6, if trail.glow then 0.35 else 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	ribbon.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	ribbon.Parent = folder

	if trail.glow and trail.light then
		local light = Instance.new("PointLight")
		light.Name = "TrailLight"
		light.Color = trail.light
		light.Range = 9
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = left
	end

	-- the particles, from just behind the feet
	local source = Instance.new("Attachment")
	source.Name = "TrailParticles"
	source.Position = Vector3.new(0, -down + 0.4, BEHIND)
	source.Parent = root
	local emitters = {}
	for _, look in trail.emitters do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = if look.texture == "Star" then Trails.star else PetAuras.square
		emitter.Color = colours(look.colours)
		emitter.LightEmission = look.glow
		emitter.LightInfluence = 1 - look.glow
		emitter.Lifetime = NumberRange.new(look.life * 0.7, look.life)
		emitter.Speed = NumberRange.new(look.speed * 0.5, look.speed)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, look.lift, 0)
		emitter.Drag = 0.6
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-look.spin, look.spin)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, look.size),
			NumberSequenceKeypoint.new(1, look.size * 0.2),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		local rate = look.rate * share
		emitter.Rate = rate * Trails.idle
		emitter.Parent = source
		table.insert(emitters, { emitter = emitter, rate = rate })
	end

	-- the attachments ride on the root; the folder holds the ribbon, and
	-- clearing it takes them too
	for _, part in { left, right, source } do
		folder.Destroying:Connect(function()
			part:Destroy()
		end)
	end
	folder.Parent = root
	worn[player] = { root = root, folder = folder, emitters = emitters }
	if not stepping then
		stepping = RunService.Heartbeat:Connect(step)
	end
end

local function watch(player: Player)
	local function refresh()
		local character = player.Character
		if character then
			task.spawn(wear, player, character, player:GetAttribute(TrailRules.ATTRIBUTE))
		else
			clear(player)
		end
	end
	player:GetAttributeChangedSignal(TrailRules.ATTRIBUTE):Connect(refresh)
	player.CharacterAdded:Connect(refresh)
	player.CharacterRemoving:Connect(function()
		clear(player)
	end)
	refresh()
end

function PlayerTrails.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
end

return PlayerTrails
