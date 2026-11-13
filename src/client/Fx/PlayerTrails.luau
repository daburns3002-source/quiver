--!strict
--[[
	Every player's trail (`Config/Trails`), drawn on this client from the
	Player's `Trail` attribute (`TrailRules.ATTRIBUTE`, set by the server):
	a ribbon flat along the ground behind them with a brighter core inside
	it, and the trail's own square particles, as Codex's sheets show
	(`assets/concepts/blocky/ui/trails/`). A glowing one (every Legendary
	and the Mythic, rule 12) lights itself and carries a light that breathes.

	What makes it more than a stripe (owner, 2026-11-13: "Make it very
	cool"; the numbers are `Trails.core`, `burst`, `pulse`, `shimmerRate`):
	a dash or putting the trail on throws a burst of its particles out all
	round; glowing particles twinkle; a shimmering ribbon (Starfall) slides
	its colours along itself.

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
local WHITE = Color3.new(1, 1, 1)

type Worn = {
	trail: Trails.Trail,
	root: BasePart,
	folder: Folder,
	ribbon: Trail,
	core: Trail,
	light: PointLight?,
	emitters: { { emitter: ParticleEmitter, rate: number } },
	bursts: { ParticleEmitter },
	moving: boolean?,
	lastBurst: number,
	born: number,
}

local worn: { [Player]: Worn } = {}
local stepping: RBXScriptConnection? = nil

local function colours(list: { Color3 }, toward: number?): ColorSequence
	local white = toward or 0
	if #list == 1 then
		return ColorSequence.new(list[1]:Lerp(WHITE, white))
	end
	local points = {}
	for i, colour in list do
		table.insert(
			points,
			ColorSequenceKeypoint.new((i - 1) / (#list - 1), colour:Lerp(WHITE, white))
		)
	end
	return ColorSequence.new(points)
end

--[[ The ribbon's colours slid `phase` (0..1) of a step along it, wrapping
     round, for a shimmering trail. ]]
local function slid(list: { Color3 }, phase: number, toward: number): ColorSequence
	local n = #list
	if n < 2 then
		return colours(list, toward)
	end
	local points = {}
	for i = 0, 4 do
		local at = i / 4
		local x = (at * (n - 1) + phase * n) % n
		local a = list[math.floor(x) % n + 1]
		local b = list[(math.floor(x) + 1) % n + 1]
		table.insert(points, ColorSequenceKeypoint.new(at, a:Lerp(b, x % 1):Lerp(WHITE, toward)))
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

local function burst(w: Worn)
	w.lastBurst = os.clock()
	local each = math.max(1, math.round(Trails.burst.count / #w.bursts))
	for _, emitter in w.bursts do
		emitter:Emit(each)
	end
end

local function step()
	local now = os.clock()
	for player, w in worn do
		if not w.root.Parent then
			clear(player)
			continue
		end
		local v = w.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local moving = speed > MOVING
		if moving ~= w.moving then
			w.moving = moving
			for _, each in w.emitters do
				each.emitter.Rate = if moving then each.rate else each.rate * Trails.idle
			end
		end
		if speed > Trails.burst.speed and now - w.lastBurst > Trails.burst.gap then
			burst(w)
		end
		local light = w.light
		if light then
			light.Brightness = 1.4
				* (
					1
					+ Trails.pulse.depth
						* math.sin((now - w.born) * Trails.pulse.rate * math.pi * 2)
				)
		end
		if w.trail.shimmer then
			local phase = ((now - w.born) * Trails.shimmerRate) % 1
			w.ribbon.Color = slid(w.trail.ribbon, phase, 0)
			w.core.Color = slid(w.trail.ribbon, phase, Trails.core.whiteGlow)
		end
	end
	if next(worn) == nil and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function ribbonBetween(
	root: BasePart,
	folder: Folder,
	name: string,
	from: Vector3,
	to: Vector3
): (Trail, Attachment, Attachment)
	local left = Instance.new("Attachment")
	left.Name = name .. "A"
	left.Position = from
	left.Parent = root
	local right = Instance.new("Attachment")
	right.Name = name .. "B"
	right.Position = to
	right.Parent = root
	local ribbon = Instance.new("Trail")
	ribbon.Name = name
	ribbon.Attachment0 = left
	ribbon.Attachment1 = right
	ribbon.MinLength = 0.05
	ribbon.FaceCamera = false
	ribbon.Parent = folder
	-- the attachments ride on the root; clearing the folder takes them too
	folder.Destroying:Connect(function()
		left:Destroy()
		right:Destroy()
	end)
	return ribbon, left, right
end

local function emitterFor(look: Trails.Emitter): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = if look.texture == "Star" then Trails.star else PetAuras.square
	emitter.Color = colours(look.colours)
	-- some of a glowing particle's light is added, not all: added in full,
	-- colours wash out to white on bright ground, as the ribbon's did
	emitter.LightEmission = look.glow * 0.4
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
	-- a glowing particle twinkles on its way out; the rest just fade
	emitter.Transparency = if look.glow >= 0.9
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.55),
			NumberSequenceKeypoint.new(0.32, 0),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(0.62, 0.05),
			NumberSequenceKeypoint.new(1, 1),
		})
		else NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
	return emitter
end

--[[ Puts `key`'s trail on `character`, or nothing for nil or an unknown
     key; `fresh` (just put on, not a new character) throws a burst. ]]
local function wear(player: Player, character: Model, key: unknown, fresh: boolean)
	local trail = TrailRules.get(key)
	if not trail then
		clear(player)
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

	--[[ The ribbon: two points either side of the feet, so it lies flat.
	     Its colours are laid over the ground, never added to it: added,
	     a blue ribbon on the lobby's cream stone came out white (seen in
	     Play, 2026-11-13). A glowing one is lit by nothing but itself. ]]
	local ribbon, left = ribbonBetween(
		root,
		folder,
		"TrailRibbon",
		Vector3.new(-trail.width / 2, -down, 0),
		Vector3.new(trail.width / 2, -down, 0)
	)
	ribbon.Color = colours(trail.ribbon)
	ribbon.Lifetime = trail.life
	ribbon.LightEmission = 0
	ribbon.LightInfluence = if trail.glow then 0 else 0.5
	ribbon.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if trail.glow then 0.05 else 0.15),
		NumberSequenceKeypoint.new(0.6, if trail.glow then 0.35 else 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	ribbon.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})

	-- its core: a brighter fin standing up along its middle
	local white = if trail.glow then Trails.core.whiteGlow else Trails.core.white
	local core = ribbonBetween(
		root,
		folder,
		"TrailCore",
		Vector3.new(0, -down + 0.03, 0),
		Vector3.new(0, -down + Trails.core.height, 0)
	)
	core.Color = colours(trail.ribbon, white)
	core.Lifetime = trail.life * Trails.core.life
	core.LightEmission = if trail.glow then 0.5 else 0.15
	core.LightInfluence = if trail.glow then 0 else 0.4
	core.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if trail.glow then 0 else 0.1),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	core.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})

	local light: PointLight? = nil
	if trail.glow and trail.light then
		local made = Instance.new("PointLight")
		made.Name = "TrailLight"
		made.Color = trail.light
		made.Range = 10
		made.Brightness = 1.4
		made.Shadows = false
		made.Parent = left
		light = made
	end

	-- the particles, from just behind the feet; and each one's burst,
	-- which throws the same particles out all round, faster
	local source = Instance.new("Attachment")
	source.Name = "TrailParticles"
	source.Position = Vector3.new(0, -down + 0.4, BEHIND)
	source.Parent = root
	folder.Destroying:Connect(function()
		source:Destroy()
	end)
	local emitters = {}
	local bursts = {}
	for _, look in trail.emitters do
		local emitter = emitterFor(look)
		local rate = look.rate * share
		emitter.Rate = rate * Trails.idle
		emitter.Parent = source
		table.insert(emitters, { emitter = emitter, rate = rate })
		local thrown = emitterFor(look)
		thrown.Name = "TrailBurst"
		thrown.Enabled = false
		thrown.SpreadAngle = Vector2.new(180, 180)
		thrown.Speed = NumberRange.new(math.max(look.speed, 2) * 2, math.max(look.speed, 2) * 4)
		thrown.Parent = source
		table.insert(bursts, thrown)
	end

	folder.Parent = root
	local w: Worn = {
		trail = trail,
		root = root,
		folder = folder,
		ribbon = ribbon,
		core = core,
		light = light,
		emitters = emitters,
		bursts = bursts,
		lastBurst = 0,
		born = os.clock(),
	}
	worn[player] = w
	if fresh then
		burst(w)
	end
	if not stepping then
		stepping = RunService.Heartbeat:Connect(step)
	end
end

local function watch(player: Player)
	local function refresh(fresh: boolean)
		local character = player.Character
		if character then
			task.spawn(wear, player, character, player:GetAttribute(TrailRules.ATTRIBUTE), fresh)
		else
			clear(player)
		end
	end
	player:GetAttributeChangedSignal(TrailRules.ATTRIBUTE):Connect(function()
		refresh(true)
	end)
	player.CharacterAdded:Connect(function()
		refresh(false)
	end)
	player.CharacterRemoving:Connect(function()
		clear(player)
	end)
	refresh(false)
end

function PlayerTrails.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
end

return PlayerTrails
