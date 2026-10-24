--!strict
--[[
	The Arcanist's upgrades with an effect (docs/effects/arcanist-orbs.md,
	arcanist-spells.md). Homing Orbs, Bigger Orbs and Mana Flow had effects
	too; the owner cut them as clutter (2026-10-24).

	- Twin Cast: the twin orbs and their link as the cast leaves.
	- Arcane Echo: the pale ghost that follows the cast.
	- Spell Pierce: lance, puncture and shards at each body passed through.
	- Chain Lightning: a zig-zag bolt of cubes to the next enemy, and the
	  spiked node where it lands. The bolt has to reach a real enemy, so it
	  is built here, not imported.
	- Meteor: the faceted rock and its arcane trail, in place of the
	  glowing ball.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Aim = require(ReplicatedStorage.Shared.Combat.Aim)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local SoundFx = require(script.Parent.Parent.SoundFx)
local UpgradeFx = require(script.Parent.UpgradeFx)

local K = Balance.UpgradeFx

local ArcanistFx = {}

local function arcanist(): boolean
	return UpgradeFx.class() == "Arcanist"
end

local function atStaff(aim: Vector3): CFrame?
	local root = UpgradeFx.root()
	if not root then
		return nil
	end
	local heading = UpgradeFx.flat(aim)
	local at = Aim.shotOrigin(root.Position) + heading * K.bowAhead
	return CFrame.lookAt(at, at + heading)
end

--[[ Chain Lightning's bolt: segments of cubes, pooled, kinked off the line. ]]
local boltParts: { BasePart } = {}
local boltFolder: Folder? = nil
local function boltPart(): BasePart
	local part = table.remove(boltParts)
	if part then
		return part
	end
	local made = Instance.new("Part")
	made.Name = "ChainBolt"
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.Neon
	return made
end

local function bolt(from: Vector3, to: Vector3)
	local folder = boltFolder
	if not folder then
		return
	end
	local count = K.boltSegments
	local pieces: { { core: BasePart, rim: BasePart } } = {}
	for _ = 1, count do
		local core = boltPart()
		core.Color = K.boltCore
		core.Parent = folder
		local rim = boltPart()
		rim.Color = K.boltRim
		rim.Material = Enum.Material.SmoothPlastic
		rim.Transparency = 0.15
		rim.Parent = folder
		table.insert(pieces, { core = core, rim = rim })
	end
	local function kink()
		local span = to - from
		local side = UpgradeFx.flat(span):Cross(Vector3.yAxis)
		local points = { from }
		for i = 1, count - 1 do
			local along = from + span * (i / count)
			local push = (math.random() * 2 - 1) * K.boltKink
			table.insert(
				points,
				along + side * push + Vector3.new(0, (math.random() - 0.5) * K.boltKink * 0.5, 0)
			)
		end
		table.insert(points, to)
		for i, piece in pieces do
			local a, b = points[i], points[i + 1]
			local length = (b - a).Magnitude
			-- fattest where it leaves and arrives, thinnest across the middle
			local u = (i - 0.5) / count
			local width = K.boltWidth * (0.6 + 0.4 * math.abs(u - 0.5) * 2)
			local frame = CFrame.lookAt((a + b) / 2, b)
			piece.core.CFrame = frame
			piece.core.Size = Vector3.new(width * 0.35, width * 0.35, length)
			piece.rim.CFrame = frame
			piece.rim.Size = Vector3.new(width, width, length)
		end
	end
	kink()
	local started = os.clock()
	local lastKink = started
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now - started >= K.boltLife then
			connection:Disconnect()
			for _, piece in pieces do
				piece.core.Parent = nil
				piece.rim.Parent = nil
				table.insert(boltParts, piece.core)
				table.insert(boltParts, piece.rim)
			end
			return
		end
		if now - lastKink >= K.boltCrackle then
			lastKink = now
			kink()
		end
	end)
end

local function nearestEnemy(from: Vector3, heading: Vector3): Vector3?
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end
	local best, pick = math.huge, nil
	for _, enemy in enemies:GetChildren() do
		if enemy:IsA("Model") then
			local offset = enemy:GetPivot().Position - from
			local d = offset.Magnitude
			-- ahead of the bolt and within the ricochet's reach
			if
				d > 1
				and d <= Balance.Projectile.ricochetRange
				and offset.Unit:Dot(heading) > 0.5
				and d < best
			then
				best, pick = d, enemy:GetPivot().Position
			end
		end
	end
	return pick
end

local function onLaunched(part: BasePart, pool: string, aim: Vector3, chained: boolean)
	if pool ~= "PlayerOrb" or not chained or UpgradeFx.level("ChainLightning") <= 0 then
		return
	end
	do
		local from = part.Position
		local heading = UpgradeFx.flat(aim)
		local to = nearestEnemy(from, heading)
			or (from + heading * Balance.Projectile.ricochetRange * 0.6)
		bolt(from, to)
		SoundFx.play("fx_chain_lightning")
		for _, at in { from, to } do
			UpgradeFx.play("FxChainLightning", {
				at = CFrame.new(at + Vector3.new(0, K.nodeLift, 0)),
				life = K.boltLife + 0.1,
				motion = UpgradeFx.pop(1, 0.1),
			})
		end
	end
end

local function onFired(aim: Vector3)
	if not arcanist() then
		return
	end
	local at = atStaff(aim)
	if not at then
		return
	end
	if UpgradeFx.level("TwinCast") > 0 then
		UpgradeFx.play("FxTwinCast", { at = at, clip = "TwinCast_Spawn", life = K.twinLife })
	end
	if UpgradeFx.level("ArcaneEcho") > 0 then
		UpgradeFx.play("FxArcaneEcho", { at = at, clip = "ArcaneEcho_Repeat", life = K.echoLife })
	end
end

local function onContact(position: Vector3, heading: Vector3, pool: string, pierceLeft: number)
	if pool ~= "PlayerOrb" or pierceLeft <= 0 or UpgradeFx.level("SpellPierce") <= 0 then
		return
	end
	UpgradeFx.play("FxSpellPierce", {
		at = CFrame.lookAt(position, position + UpgradeFx.flat(heading)),
		life = K.pierceLife,
		motion = UpgradeFx.pop(1, 0.12),
	})
end

--[[ How the meteor model is held so it falls straight down: the model was
     drawn with its rock off its pivot and its trail streaming off at a
     slant, so both are measured from it (the rock is the part named Rock,
     the trail every other part) and the model is turned until the trail
     points straight up, with the rock where the falling ball is. ]]
local meteorHoldCache: CFrame? = nil
local function meteorHold(): CFrame
	local cached = meteorHoldCache
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild("UpgradeEffects")
	local model = folder and folder:FindFirstChild("FxMeteor")
	if not model then
		return CFrame.identity
	end
	local rockAt, trail, count = nil :: Vector3?, Vector3.zero, 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			-- the template is built at the origin, so positions are the pivot's
			if string.find(part.Name, "_Rock_", 1, true) then
				rockAt = part.Position
			else
				trail += part.Position
				count += 1
			end
		end
	end
	if not rockAt or count == 0 then
		return CFrame.identity
	end
	local streams = (trail / count - rockAt).Unit
	-- the turn that takes the trail's direction onto straight up
	local axis = streams:Cross(Vector3.yAxis)
	local turn = if axis.Magnitude > 1e-4
		then CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(streams.Y, -1, 1)))
		else CFrame.identity
	local hold = turn * CFrame.new(-rockAt)
	meteorHoldCache = hold
	return hold
end

local function onMeteor(rock: BasePart)
	-- the ball and its halo give way to the faceted rock
	rock.Transparency = 1
	for _, d in rock:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	--[[ Straight down, and steady: no tumble (owner, 2026-10-24: "the
	     meteor should fall straight down instead of spinning in the air").
	     The rock rides the ball's place with its trail straight up above. ]]
	SoundFx.play("fx_meteor")
	local hold = meteorHold()
	UpgradeFx.play("FxMeteor", {
		at = rock.CFrame,
		life = K.meteorLife,
		follow = function(): CFrame?
			if not rock.Parent then
				return nil
			end
			return CFrame.new(rock.Position) * hold
		end,
	})
end

function ArcanistFx.start(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "ChainBolts"
	folder.Parent = parent
	boltFolder = folder
	FxEvents.launched:connect(onLaunched)
	FxEvents.fired:connect(onFired)
	FxEvents.contact:connect(onContact)
	FxEvents.meteor:connect(onMeteor)
end

return ArcanistFx
