--!strict
--[[
	Soul Chain's fireball (owner, 2026-11-11: "soul link should be like brand
	ult"): a blazing cube with a flame trail that leaps from the enemy hit to
	each linked enemy in turn, in arcs, bursts into fire on each one it lands
	on and leaves it burning for a moment before it leaps on.

	The server says who is linked, in what order and when the fireball lands
	on each (`Remotes.SoulLink`, `Shared/Combat/SoulBounce`), and lands each
	enemy's share of the hit at that moment, so the burst here and the damage
	number, white flash and knockback of `Fx/HitFeedback` arrive together.
	This draws the leaps for every player's link, card held or not.

	Built in code: two tumbling neon cubes, a trail, square embers, a warm
	light on the floor under it (which is what lets the top-down camera read
	the height of a leap), and on landing a flash, a ring on the floor and a
	burst of flames. Cheap on a phone: every fireball and burst is pooled,
	and how many fly at once and how many flames they throw is the device's
	share (`UpgradeFx.budget`, `DeviceTiers.burnParticleRate`).

	Presentation only: the flames it leaves are not Blaze's burn and do no
	damage.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Parent.Device)
local PetAuras = require(ReplicatedStorage.Shared.Config.PetAuras)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoulBounce = require(ReplicatedStorage.Shared.Combat.SoulBounce)
local SoundFx = require(script.Parent.Parent.SoundFx)
local UpgradeFx = require(script.Parent.UpgradeFx)

local K = Balance.UpgradeFx.soul

local FLAME_NAME = "SoulFlame"
--[[ Burst emitters kept in the world and used in turn. ]]
local BURST_ANCHORS = 4
--[[ Seconds a put-out flame's last particles are given to die. ]]
local FLAME_TAIL = 0.7

local FIRE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, K.flameColour),
	ColorSequenceKeypoint.new(0.4, K.fireColour),
	ColorSequenceKeypoint.new(1, K.emberColour),
})

--[[ The trail is fire from its first inch: with the white-hot heart's own
     colour at its head it burned out to a white band. ]]
local TRAIL = ColorSequence.new(K.fireColour, K.emberColour)

local SoulFireFx = {}

type Ball = {
	core: BasePart,
	shell: BasePart,
	glow: BasePart,
	trail: Trail,
	embers: ParticleEmitter,
	--[[ The enemies it visits, where each was last seen, and the seconds
	     after `started` it lands on each. ]]
	models: { Model? },
	stops: { Vector3 },
	times: { number },
	started: number,
	--[[ The leap it is on, and where that leap began. ]]
	hop: number,
	from: Vector3,
}

type Burst = { flash: BasePart, ring: BasePart, at: Vector3, scale: number, started: number }

type Flame = { emitter: ParticleEmitter, untilAt: number }

local folder: Folder? = nil
local spareBalls: { Ball } = {}
local balls: { Ball } = {}
local spareBursts: { Burst } = {}
local bursts: { Burst } = {}
local burstEmitters: { ParticleEmitter } = {}
local nextBurst = 1
--[[ The flames left on enemies, by the part they sit on. ]]
local flames: { [BasePart]: Flame } = {}

local function neon(name: string, colour: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = colour
	return part
end

local function fire(emitter: ParticleEmitter)
	emitter.Texture = PetAuras.square
	emitter.Color = FIRE
	emitter.LightEmission = K.flameGlow
	emitter.Rotation = NumberRange.new(0, 90)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.6, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function makeBall(): Ball
	local core = neon("SoulFireCore", K.coreColour)
	core.Size = Vector3.one * K.core
	local shell = neon("SoulFireShell", K.fireColour)
	shell.Size = Vector3.one * K.shell
	shell.Transparency = 0.45
	local glow = neon("SoulFireGlow", K.fireColour)

	--[[ The trail is a ribbon between two points on the heart, turned to the
	     camera, so it is as wide from straight above as from the side. One
	     drawn object for the whole flame, which is why every tier keeps it:
	     `projectileTrails` is off on a phone for a room of arrows, and there
	     are never more than a few of these. ]]
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(K.trailWidth / 2, 0, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(-K.trailWidth / 2, 0, 0)
	bottom.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.FaceCamera = true
	trail.Lifetime = K.trailLife
	trail.MinLength = 0.05
	trail.LightEmission = K.trailGlow
	trail.Color = TRAIL
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	trail.Enabled = false
	trail.Parent = core

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	fire(embers)
	embers.Enabled = false
	embers.Rate = UpgradeFx.budget(K.embers, 10)
	embers.Lifetime = NumberRange.new(0.25, 0.45)
	embers.Speed = NumberRange.new(1, 4)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Acceleration = Vector3.new(0, 7, 0)
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	embers.Parent = core

	return {
		core = core,
		shell = shell,
		glow = glow,
		trail = trail,
		embers = embers,
		models = {},
		stops = {},
		times = {},
		started = 0,
		hop = 1,
		from = Vector3.zero,
	}
end

local function park(ball: Ball)
	ball.trail.Enabled = false
	ball.embers.Enabled = false
	ball.core.Parent = nil
	ball.shell.Parent = nil
	ball.glow.Parent = nil
	table.insert(spareBalls, ball)
end

--[[ The part a flame sits on: the hitbox where there is one, as `BurnFx`. ]]
local function anchorPart(model: Model): BasePart?
	local hitbox = model:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") then
		return hitbox
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

--[[ Leaves `model` visibly burning for a moment. ]]
local function ignite(model: Model?, now: number)
	if not model or not model.Parent then
		return
	end
	local part = anchorPart(model)
	if not part then
		return
	end
	local flame = flames[part]
	if flame then
		flame.untilAt = now + K.burn
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = FLAME_NAME
	fire(emitter)
	emitter.Rate = Device.tier().burnParticleRate * K.burnRate
	emitter.Lifetime = NumberRange.new(0.3, 0.55)
	emitter.Speed = NumberRange.new(4, 7)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.15),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	emitter.Parent = part
	flames[part] = { emitter = emitter, untilAt = now + K.burn }
end

--[[ A burst `f` (0 to 1) of the way through its life: the flash swells and
     clears, and the ring spreads flat on the floor, which is the part of it
     the camera above sees whole. ]]
local function poseBurst(made: Burst, f: number)
	local eased = 1 - (1 - f) * (1 - f)
	local size = K.flash * made.scale * (0.4 + 0.6 * eased)
	made.flash.Size = Vector3.one * size
	made.flash.CFrame = CFrame.new(made.at) * CFrame.Angles(0, f * 2, 0)
	made.flash.Transparency = 0.1 + 0.9 * f
	local ring = K.ring * made.scale * (0.3 + 0.7 * eased)
	made.ring.Size = Vector3.new(ring, 0.08, ring)
	made.ring.CFrame = CFrame.new(made.at.X, 0.16, made.at.Z) * CFrame.Angles(0, math.pi / 4, 0)
	made.ring.Transparency = 0.35 + 0.65 * f
end

--[[ The light the fireball throws on the floor under it, which shrinks and
     fades as it rises: how the camera above reads the height of a leap. ]]
local function poseGlow(ball: Ball, at: Vector3)
	local high = math.clamp((at.Y - K.height) / K.leap.max, 0, 1)
	local wide = K.floorGlow * (1 - 0.45 * high)
	ball.glow.Size = Vector3.new(wide, 0.06, wide)
	ball.glow.CFrame = CFrame.new(at.X, 0.14, at.Z)
	ball.glow.Transparency = 0.5 + 0.35 * high
end

--[[ The fireball bursting into fire at `at`; `scale` under 1 for the small
     flare it is born from. ]]
local function burst(at: Vector3, scale: number, now: number)
	local parent = folder
	if not parent then
		return
	end

	local emitter = burstEmitters[nextBurst]
	nextBurst = nextBurst % #burstEmitters + 1
	local anchor = emitter.Parent
	if anchor and anchor:IsA("BasePart") then
		anchor.CFrame = CFrame.new(at)
	end
	emitter:Emit(math.max(2, math.floor(UpgradeFx.budget(K.burst, 5) * scale + 0.5)))

	local made: Burst = table.remove(spareBursts)
		or {
			flash = neon("SoulFireFlash", K.coreColour),
			ring = neon("SoulFireRing", K.fireColour),
			at = at,
			scale = scale,
			started = now,
		}
	made.at = at
	made.scale = scale
	made.started = now
	poseBurst(made, 0)
	made.flash.Parent = parent
	made.ring.Parent = parent
	table.insert(bursts, made)
end

--[[ Where the fireball is aiming on leap `hop`: the enemy itself while this
     client still has it, else where it was last seen. ]]
local function aim(ball: Ball, hop: number): Vector3
	local model = ball.models[hop]
	if model and model.Parent then
		local at = model:GetPivot().Position
		ball.stops[hop] = Vector3.new(at.X, K.height, at.Z)
	end
	return ball.stops[hop]
end

local function step()
	local now = os.clock()

	for i = #balls, 1, -1 do
		local ball = balls[i]
		local t = now - ball.started

		while ball.hop <= #ball.times and t >= ball.times[ball.hop] do
			local landed = aim(ball, ball.hop)
			burst(landed, 1, now)
			ignite(ball.models[ball.hop], now)
			ball.from = landed
			ball.hop += 1
		end

		if ball.hop > #ball.times then
			table.remove(balls, i)
			park(ball)
			continue
		end

		local began = if ball.hop > 1 then ball.times[ball.hop - 1] else 0
		local length = math.max(ball.times[ball.hop] - began, 1e-3)
		local to = aim(ball, ball.hop)
		local at = SoulBounce.at(ball.from, to, (t - began) / length)

		ball.core.CFrame = CFrame.new(at) * CFrame.Angles(t * K.spin, t * K.spin * 1.3, 0)
		ball.shell.CFrame = CFrame.new(at) * CFrame.Angles(-t * K.spin * 0.7, t * K.spin * 0.5, 1)
		ball.shell.Size = Vector3.one * K.shell * (1 + 0.12 * math.sin(t * 38))
		poseGlow(ball, at)
	end

	for i = #bursts, 1, -1 do
		local made = bursts[i]
		local f = (now - made.started) / K.burstLife
		if f >= 1 then
			made.flash.Parent = nil
			made.ring.Parent = nil
			table.remove(bursts, i)
			table.insert(spareBursts, made)
			continue
		end
		poseBurst(made, f)
	end

	for part, flame in flames do
		if now >= flame.untilAt or not part.Parent then
			flame.emitter.Enabled = false
			Debris:AddItem(flame.emitter, FLAME_TAIL)
			flames[part] = nil
		end
	end
end

--[[ `Remotes.SoulLink`: where the enemy hit stood, the linked enemies in
     the order the fireball visits them, where each stood, and the seconds
     from now it lands on each. Checked, as anything off the wire is. ]]
local function onSoulLink(centre: unknown, models: unknown, reached: unknown, times: unknown)
	local parent = folder
	if not parent or typeof(centre) ~= "Vector3" then
		return
	end
	if type(models) ~= "table" or type(reached) ~= "table" or type(times) ~= "table" then
		return
	end
	if #balls >= UpgradeFx.budget(K.cap, 1) then
		return
	end

	local stops: { Vector3 } = {}
	local lands: { number } = {}
	local visits: { Model? } = {}
	local last = 0
	for index, stop in reached :: { unknown } do
		local at = (times :: { unknown })[index]
		if typeof(stop) ~= "Vector3" or type(at) ~= "number" or at < last then
			return
		end
		last = at
		local model = (models :: { unknown })[index]
		stops[index] = Vector3.new(stop.X, K.height, stop.Z)
		lands[index] = at
		visits[index] = if typeof(model) == "Instance" and model:IsA("Model") then model else nil
	end
	if #stops == 0 then
		return
	end

	local now = os.clock()
	local ball = table.remove(spareBalls) or makeBall()
	ball.models = visits
	ball.stops = stops
	ball.times = lands
	ball.started = now
	ball.hop = 1
	ball.from = Vector3.new(centre.X, K.height, centre.Z)

	ball.core.CFrame = CFrame.new(ball.from)
	ball.shell.CFrame = ball.core.CFrame
	poseGlow(ball, ball.from)
	ball.core.Parent = parent
	ball.shell.Parent = parent
	ball.glow.Parent = parent
	--[[ Only once it sits at its start, so a reused one draws no ribbon from
	     where its last flight ended. ]]
	ball.trail:Clear()
	ball.embers:Clear()
	ball.trail.Enabled = true
	ball.embers.Enabled = true
	table.insert(balls, ball)

	SoundFx.play("fx_soul_chain")
	burst(ball.from, 0.5, now)
end

function SoulFireFx.start(parent: Instance)
	local made = Instance.new("Folder")
	made.Name = "SoulFire"
	made.Parent = parent
	folder = made

	for index = 1, BURST_ANCHORS do
		local anchor = Instance.new("Part")
		anchor.Name = "SoulFireBurst" .. index
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.6
		anchor.CFrame = CFrame.new(0, -200, 0)
		anchor.Parent = made

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Flames"
		fire(emitter)
		emitter.Enabled = false
		emitter.Lifetime = NumberRange.new(0.25, 0.5)
		emitter.Speed = NumberRange.new(7, 16)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Drag = 4
		emitter.Acceleration = Vector3.new(0, 9, 0)
		emitter.ZOffset = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2),
			NumberSequenceKeypoint.new(1, 0.15),
		})
		emitter.Parent = anchor
		table.insert(burstEmitters, emitter)
	end

	Remotes.event(Remotes.SoulLink).OnClientEvent:Connect(onSoulLink)
	RunService.RenderStepped:Connect(step)
end

return SoulFireFx
