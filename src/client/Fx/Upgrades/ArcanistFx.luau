--!strict
--[[
	The Arcanist's upgrades with an effect (docs/effects/arcanist-orbs.md,
	arcanist-spells.md). Homing Orbs, Bigger Orbs and Mana Flow had effects
	too; the owner cut them as clutter (2026-10-24).

	- Twin Cast: the twin orbs and their link as the cast leaves.
	- Arcane Echo: the pale ghost that follows the cast.
	- Spell Pierce: lance, puncture and shards at each body passed through.
	- Chain Lightning: a jagged, forked bolt that snaps from the enemy struck
	  to the next, one hop after another (`LightningFx`, built in code: the
	  bolt has to reach between two real enemies).
	- Meteor: the faceted rock and its arcane trail, in place of the
	  glowing ball.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Aim = require(ReplicatedStorage.Shared.Combat.Aim)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local FxEvents = require(script.Parent.FxEvents)
local LightningFx = require(script.Parent.LightningFx)
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

--[[ Chain Lightning: one arc of it, as the server sends each hop (`origin`
     and `direction` are the arc's own, `from` and `to` the enemy it leaves
     and the one it was sent at, `speed` how fast it gets there). Drawn body
     to body, over their heads, for every player's arcs. ]]
local function onArc(origin: Vector3, direction: Vector3, from: Model?, to: Model?, speed: number)
	local height = origin.Y + K.bolt.lift
	local function over(at: Vector3): Vector3
		return Vector3.new(at.X, height, at.Z)
	end
	local a = over(if from and from.Parent then from:GetPivot().Position else origin)
	--[[ An enemy this client no longer has (it died on the way) still gets
	     its bolt, along the arc's aim. ]]
	local b = over(
		if to and to.Parent
			then to:GetPivot().Position
			else origin + UpgradeFx.flat(direction) * Balance.Projectile.ricochetRange * 0.6
	)
	LightningFx.strike(a, b, (b - a).Magnitude / math.max(speed, 1), from, to)
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
	LightningFx.start(parent)
	FxEvents.arc:connect(onArc)
	FxEvents.fired:connect(onFired)
	FxEvents.contact:connect(onContact)
	FxEvents.meteor:connect(onMeteor)
end

return ArcanistFx
