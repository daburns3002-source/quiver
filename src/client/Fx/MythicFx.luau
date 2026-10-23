--!strict
--[[
	The Mythics' area attacks, dressed as the owner's mythic-fx.js draws
	them (design_handoff_ruby_greatsword_r15, design_handoff_arcane_staff_r15,
	2026-10-23), over the warnings `Fx/TelegraphRenderer` already draws:

	- the falling meteor glows, with a hot halo, and sheds embers;
	- where it lands, a fireball bursts out to the strike's radius, debris
	  is thrown out of the crater, and a scorch is left a while;
	- each eruption of Earthbreaker's cracked ground pushes rock spikes up
	  over glowing lava, which sink again.

	Presentation only. The server has already decided every hit
	(`Combat/AreaStrikes`). Debris, embers and spikes are budgeted by the
	device tier (`DeviceTiers.mythicFxShare`). Numbers: `Balance.MythicFx`.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Device = require(script.Parent.Parent.Device)

local MythicFx = {}

local GRAVITY = 30
--[[ Height debris settles at, on the floor. ]]
local REST_HEIGHT = 0.2

local function share(count: number): number
	return math.max(1, math.floor(count * Device.tier().mythicFxShare + 0.5))
end

local function effectPart(parent: Instance, name: string, shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

--[[ A flat disc on the floor, `across` studs wide. ]]
local function floorDisc(
	parent: Instance,
	name: string,
	at: Vector3,
	across: number,
	height: number
): Part
	local disc = effectPart(parent, name, Enum.PartType.Cylinder)
	disc.Size = Vector3.new(0.05, across, across)
	disc.CFrame = CFrame.new(at.X, height, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
	return disc
end

--[[ Dresses the falling `rock`: a halo round it and embers behind it. ]]
function MythicFx.meteorRock(rock: BasePart)
	local config = Balance.MythicFx
	local halo = effectPart(rock, "Halo", Enum.PartType.Ball)
	halo.Size = rock.Size * config.meteorHalo
	halo.Material = Enum.Material.Neon
	halo.Color = config.fireColor
	halo.Transparency = 0.6
	halo.Anchored = false
	halo.Massless = true
	halo.CFrame = rock.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rock
	weld.Part1 = halo
	weld.Parent = halo

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Rate = share(config.meteorEmbers)
	embers.Lifetime = NumberRange.new(0.3, 0.45)
	embers.Speed = NumberRange.new(0.5, 2)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.LightEmission = 1
	embers.Color = ColorSequence.new(config.lavaColor, config.fireColor)
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 1.6),
	})
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	embers.Parent = rock
end

--[[ Where a meteor lands, `radius` studs round `origin`: a fireball, the
     scorch it leaves, and debris thrown out. ]]
function MythicFx.meteorImpact(parent: Instance, origin: Vector3, radius: number)
	local config = Balance.MythicFx
	local ground = Vector3.new(origin.X, 0, origin.Z)

	local fireball = effectPart(parent, "Fireball", Enum.PartType.Ball)
	fireball.Material = Enum.Material.Neon
	fireball.Color = config.fireColor
	fireball.Transparency = 0.1
	fireball.Size = Vector3.one * 2
	fireball.Position = ground + Vector3.new(0, 1, 0)
	TweenService:Create(fireball, TweenInfo.new(config.fireballTime, Enum.EasingStyle.Quad), {
		Size = Vector3.one * radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(fireball, config.fireballTime)

	local scorch = floorDisc(parent, "Scorch", ground, radius * 2 * config.scorchShare, 0.06)
	scorch.Material = Enum.Material.Fabric
	scorch.Color = config.scorchColor
	scorch.Transparency = 0.4
	TweenService:Create(
		scorch,
		TweenInfo.new(
			config.scorchFade,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.In,
			0,
			false,
			config.scorchHold
		),
		{ Transparency = 1 }
	):Play()
	Debris:AddItem(scorch, config.scorchHold + config.scorchFade)

	--[[ Debris: thrown up and out, falling back and skidding to a stop on
	     the floor. ]]
	local rocks: { { part: Part, velocity: Vector3 } } = {}
	for _ = 1, share(config.debris) do
		local rock = effectPart(parent, "Debris", Enum.PartType.Block)
		rock.Material = Enum.Material.Slate
		rock.Color = config.rockColor
		rock.Size = Vector3.one * (0.4 + math.random() * 0.4)
		rock.CFrame = CFrame.new(ground + Vector3.new(0, 0.4, 0))
			* CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		local angle = math.random() * math.pi * 2
		local out = 4 + math.random() * 5
		table.insert(rocks, {
			part = rock,
			velocity = Vector3.new(
				math.cos(angle) * out,
				6 + math.random() * 6,
				math.sin(angle) * out
			),
		})
		Debris:AddItem(rock, config.debrisLife)
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		if os.clock() - started > config.debrisLife then
			connection:Disconnect()
			return
		end
		for _, rock in rocks do
			rock.velocity -= Vector3.new(0, GRAVITY * dt, 0)
			local at = rock.part.Position + rock.velocity * dt
			if at.Y < REST_HEIGHT then
				at = Vector3.new(at.X, REST_HEIGHT, at.Z)
				rock.velocity *= 0.3
			end
			rock.part.CFrame = CFrame.new(at)
				* rock.part.CFrame.Rotation
				* CFrame.Angles(dt * 5, 0, 0)
		end
	end)
end

--[[ One eruption of cracked ground `radius` studs round `origin`: rock
     spikes punched up over lava, sinking again. ]]
function MythicFx.erupt(parent: Instance, origin: Vector3, radius: number)
	local config = Balance.MythicFx
	local low, high = config.spikeHeight[1], config.spikeHeight[2]
	for _ = 1, share(config.spikes) do
		local angle = math.random() * math.pi * 2
		local distance = math.sqrt(math.random()) * radius * 0.85
		local at = Vector3.new(origin.X, 0, origin.Z)
			+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		local height = low + math.random() * (high - low)
		local width = 0.7 + math.random() * 0.5

		local glow = floorDisc(parent, "Lava", at, 1.4, 0.08)
		glow.Material = Enum.Material.Neon
		glow.Color = config.lavaColor
		TweenService:Create(glow, TweenInfo.new(config.spikeLife * 0.8), {
			Size = Vector3.new(0.05, 3.4, 3.4),
			Transparency = 1,
		}):Play()
		Debris:AddItem(glow, config.spikeLife)

		--[[ A four-sided spike: a corner wedge, its point up, turned at
		     random and leaning a little. ]]
		local spike = Instance.new("CornerWedgePart")
		spike.Name = "Spike"
		spike.Anchored = true
		spike.CanCollide = false
		spike.CanQuery = false
		spike.CanTouch = false
		spike.CastShadow = false
		spike.Material = Enum.Material.Slate
		spike.Color = config.rockColor
		spike.Size = Vector3.new(width, height, width)
		local turn = CFrame.Angles(
			(math.random() - 0.5) * 0.6,
			math.random() * math.pi * 2,
			(math.random() - 0.5) * 0.6
		)
		local sunk = CFrame.new(at - Vector3.new(0, height / 2, 0)) * turn
		local risen = CFrame.new(at + Vector3.new(0, height * 0.45, 0)) * turn
		spike.CFrame = sunk
		spike.Parent = parent
		local life = config.spikeLife
		--[[ Punched up, held, then sunk. Chained, not both played at once:
		     playing a tween cancels any other on the same property, even
		     one still waiting out its delay. ]]
		local rise = TweenService:Create(spike, TweenInfo.new(life * 0.2, Enum.EasingStyle.Back), {
			CFrame = risen,
		})
		local sink = TweenService:Create(
			spike,
			TweenInfo.new(
				life * 0.4,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In,
				0,
				false,
				life * 0.4
			),
			{ CFrame = sunk }
		)
		rise.Completed:Connect(function()
			sink:Play()
		end)
		rise:Play()
		Debris:AddItem(spike, life * 1.1)
	end
end

return MythicFx
