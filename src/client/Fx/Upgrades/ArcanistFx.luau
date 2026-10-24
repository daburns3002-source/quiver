--!strict
--[[
	The Arcanist's upgrades (docs/effects/arcanist-orbs.md,
	arcanist-spells.md). The three that touch the orb sit on three different
	axes so they stack: Twin Cast across the lane, Homing Orbs along it,
	Arcane Echo behind it in time.

	- Homing Orbs: a bending tail on each orb, and one crosshair on the
	  target (once per target, never per orb).
	- Bigger Orbs: the blast shell, a clip per level, where an orb bursts.
	- Mana Flow: droplets orbiting the staff, faster per level.
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
local LocalFiring = require(script.Parent.Parent.Parent.Combat.LocalFiring)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local UpgradeFx = require(script.Parent.UpgradeFx)

local K = Balance.UpgradeFx

local ArcanistFx = {}

local function arcanist(): boolean
	return UpgradeFx.class() == "Arcanist"
end

local function hide(model: Model?, word: string)
	if not model then
		return
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and string.find(part.Name, word, 1, true) then
			part.Transparency = 1
		end
	end
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
	if pool ~= "PlayerOrb" then
		return
	end
	if chained then
		if UpgradeFx.level("ChainLightning") <= 0 then
			return
		end
		local from = part.Position
		local heading = UpgradeFx.flat(aim)
		local to = nearestEnemy(from, heading)
			or (from + heading * Balance.Projectile.ricochetRange * 0.6)
		bolt(from, to)
		for _, at in { from, to } do
			UpgradeFx.play("FxChainLightning", {
				at = CFrame.new(at + Vector3.new(0, K.nodeLift, 0)),
				life = K.boltLife + 0.1,
				motion = UpgradeFx.pop(1, 0.1),
			})
		end
		return
	end
	if UpgradeFx.level("TrackingEye") > 0 then
		local tail = UpgradeFx.play("FxTrackingEye", {
			at = part.CFrame,
			clip = "TrackingEye_Flight",
			life = K.trailLife,
			follow = function(): CFrame?
				return if part.Parent then part.CFrame else nil
			end,
		})
		-- the crosshair is drawn once per target, not per orb
		hide(tail, "Crosshair")
	end
end

-- Homing Orbs' crosshair, on the target being aimed at
local crosshair: Model? = nil
local crosshairTarget: Model? = nil
local function crosshairStep()
	local target = if arcanist() and UpgradeFx.level("TrackingEye") > 0
		then LocalFiring.currentTarget()
		else nil
	if target ~= crosshairTarget and crosshair then
		UpgradeFx.stop(crosshair)
		crosshair = nil
	end
	crosshairTarget = target
	if target and not crosshair then
		crosshair = UpgradeFx.play("FxTrackingEye", {
			at = target:GetPivot(),
			clip = "TrackingEye_Flight",
			life = math.huge,
			follow = function(): CFrame?
				if not target.Parent then
					return nil
				end
				return CFrame.new(target:GetPivot().Position + Vector3.new(0, K.crosshairLift, 0))
			end,
		})
		hide(crosshair, "Tail")
		hide(crosshair, "Spark")
	end
end

-- Mana Flow's droplets, round the staff
local mana: Model? = nil
local function manaStep()
	local level = if arcanist() then UpgradeFx.level("ManaFlow") else 0
	if level <= 0 then
		if mana then
			UpgradeFx.stop(mana)
			mana = nil
		end
		return
	end
	if not mana then
		mana = UpgradeFx.play("FxManaFlow", {
			at = CFrame.new(),
			clip = `ManaFlow_Cast_L{math.min(level, 3)}`,
			life = math.huge,
			follow = function(): CFrame?
				local root = UpgradeFx.root()
				local character = root and root.Parent
				local hand = character and character:FindFirstChild("RightHand")
				if hand and hand:IsA("BasePart") then
					return CFrame.new(hand.Position + Vector3.new(0, K.staffHead, 0))
				end
				return if root then root.CFrame * CFrame.new(0.8, K.staffHead, 0) else nil
			end,
		})
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
	if mana then
		local level = math.min(UpgradeFx.level("ManaFlow"), 3)
		UpgradeFx.clip(mana, `ManaFlow_Cast_L{level}`)
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

local function onExplosion(centre: Vector3, _radius: number)
	local level = if arcanist() then UpgradeFx.level("BiggerOrbs") else 0
	if level <= 0 then
		return
	end
	UpgradeFx.play("FxBiggerOrbs", {
		at = CFrame.new(UpgradeFx.floor(centre, 0)),
		clip = `BiggerOrbs_Impact_L{math.min(level, 3)}`,
		span = K.shellSpan,
		life = K.shellSpan + 0.05,
	})
end

local function onMeteor(rock: BasePart)
	-- the ball and its halo give way to the faceted rock
	rock.Transparency = 1
	for _, d in rock:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	local last = rock.Position
	local spin = 0
	UpgradeFx.play("FxMeteor", {
		at = rock.CFrame,
		life = K.meteorLife,
		follow = function(): CFrame?
			if not rock.Parent then
				return nil
			end
			local now = rock.Position
			local fall = now - last
			last = now
			spin += K.meteorTumble
			local heading = if fall.Magnitude > 1e-3
				then fall.Unit
				else Vector3.new(-0.4, -1, 0.6).Unit
			-- the trail streams back up the way it came
			return CFrame.lookAt(now, now + heading) * CFrame.Angles(0, 0, spin)
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
	Remotes.event(Remotes.Explosion).OnClientEvent:Connect(onExplosion)
	RunService.Heartbeat:Connect(function()
		crosshairStep()
		manaStep()
	end)
end

return ArcanistFx
