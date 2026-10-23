--!strict
--[[
	A blade's effects for the local player (`Config/Weapons.blade`, after
	the owner's Ruby Greatsword kit, 2026-10-23):

	- sparks off the blade's tip while the walk drags it along the ground;
	- a burst of sparks in front of the wielder as each blow lands (the
	  slash's `Hit` marker, from `Fx/WeaponPose`), and a bigger one with a
	  camera shake on the combo's last blow, the slam.

	The blow's damage is the server's (`Combat/MeleeSystem`); this only
	shows it. Spark counts follow the device tier: none on the lowest.
]]

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Parent.Device)
local TopDownCamera = require(script.Parent.Parent.Camera.TopDownCamera)

local BladeFx = {}

type Blade = {
	sparkColour: Color3,
	dragRate: number,
	burst: number,
	heavyBurst: number,
	reach: number,
	shake: number,
	shakeTime: number,
}

local dragEmitter: ParticleEmitter? = nil
local builtFor: Attachment? = nil

local function sparks(colour: Color3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(colour)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.2, 0.45)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -35, 0)
	emitter.Rate = 0
	return emitter
end

--[[ Whether this device draws sparks at all. ]]
local function drawsSparks(): boolean
	return Device.tier().orbSparkleRate > 0
end

--[[ Sparks off the tip while `dragging`, for a weapon with a blade. ]]
function BladeFx.step(character: Model, weapon: any, dragging: boolean)
	local blade: Blade? = weapon.blade
	local trail = weapon.swingTrail
	local held = character:FindFirstChild("HeldWeapon")
	local origin = held and held:FindFirstChild("WeaponOrigin", true) :: Attachment?
	if not (blade and trail and origin and drawsSparks()) then
		if dragEmitter then
			dragEmitter.Enabled = false
		end
		return
	end

	if origin ~= builtFor or not (dragEmitter and dragEmitter.Parent) then
		if dragEmitter then
			dragEmitter:Destroy()
		end
		local at = origin :: Attachment
		local scale = (at:GetAttribute("Scale") :: number?) or 1
		local tip = Instance.new("Attachment")
		tip.Name = "DragTip"
		tip.CFrame = at.CFrame * CFrame.new(trail.tip * scale)
		tip.Parent = at.Parent
		local emitter = sparks(blade.sparkColour)
		emitter.Rate = blade.dragRate
		emitter.Enabled = false
		emitter.Parent = tip
		dragEmitter = emitter
		builtFor = at
	end
	(dragEmitter :: ParticleEmitter).Enabled = dragging
end

--[[ A blow landed: a burst of sparks in front of the wielder, and for the
     combo's `heavy` last blow, more of them and a camera shake. ]]
function BladeFx.impact(character: Model, weapon: any, heavy: boolean)
	local blade: Blade? = weapon.blade
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (blade and root) then
		return
	end

	if heavy then
		TopDownCamera.shake(blade.shake, blade.shakeTime)
	end
	if not drawsSparks() then
		return
	end

	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local at = root.Position + flat.Unit * blade.reach

	local holder = Instance.new("Part")
	holder.Name = "BladeImpact"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(at)
	local emitter = sparks(blade.sparkColour)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = holder
	holder.Parent = Workspace.CurrentCamera
	emitter:Emit(if heavy then blade.heavyBurst else blade.burst)
	Debris:AddItem(holder, 1)
end

return BladeFx
