--!strict
--[[
	The class's arms: its weapon's animations from the owner's kits
	(`Config/WeaponAnimations`, 2026-10-23), played here in code rather than
	as uploaded animations, so they need no publishing and follow the real
	fire rhythm. Each weapon names its clips (`Config/Weapons.clips`):

	- `hold` while moving or with nothing to shoot. Arms only, so the legs
	  still walk.
	- `ready` on stopping with a target (the bow's Draw, the staff's
	  Charge), then `aim` loops (Aim, Channel).
	- `fire` on every volley this client fires (`LocalFiring.onFired`), then
	  `ready` again. The pair is sped up to fit inside the shot cooldown, so
	  a faster archer draws faster rather than skipping the draw.

	The weapon is engaged — an arrow on the string, a cast charging — from
	`ready`'s first marker (the bow's Nock; the staff's Charge has none, so
	from its start) until `fire`'s (Release, Cast). `Fx/BowString` and
	`Fx/StaffOrb` draw from that.

	Every change of clip blends from the last pose over `FADE` seconds.
	Joints a clip leaves out stay with Roblox's own animation. Written to the
	joints' `Transform` in RunService.Stepped, after the Animator has run.

	Presentation only, on this client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BowString = require(script.Parent.BowString)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local PlayerStats = require(script.Parent.Parent.PlayerStats)
local StaffOrb = require(script.Parent.StaffOrb)
local WeaponAnimations = require(ReplicatedStorage.Shared.Config.WeaponAnimations)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local WeaponPose = {}

--[[ Seconds a change of clip blends over. ]]
local FADE = 0.08
--[[ The share of the shot cooldown that `fire` and the next `ready` may
     take, so the weapon is ready again before the next shot. ]]
local CYCLE_SHARE = 0.9

--[[ The part each R15 joint lives in. ]]
local JOINT_PARTS: { [string]: string } = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
}

local player = Players.LocalPlayer
local connection: RBXScriptConnection? = nil
local hasTarget: () -> boolean = function()
	return false
end

local weaponName = ""
--[[ The role (`hold`, `ready`, `aim`, `fire`) playing, and since when. ]]
local role = "hold"
local roleStarted = 0
local roleSpeed = 1
local engaged = false
local lastStep = os.clock()

--[[ The last pose written to each joint, and the pose a blend starts from. ]]
local written: { [string]: CFrame } = {}
local fadeFrom: { [string]: CFrame } = {}
local fadeStarted = -math.huge

--[[ A joint is a classic Motor6D or, on avatars with Roblox's physics-based
     joints, an AnimationConstraint. Both carry `Transform`. ]]
local function joint(character: Model, part: string, name: string): (Motor6D | AnimationConstraint)?
	local holder = character:FindFirstChild(part)
	local found = holder and holder:FindFirstChild(name)
	if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
		return found :: any
	end
	return nil
end

local function ease(u: number): number
	return if u < 0.5 then 4 * u * u * u else 1 - (-2 * u + 2) ^ 3 / 2
end

--[[ The clip's pose `t` seconds in. ]]
local function sample(clip: WeaponAnimations.Clip, t: number): { [string]: CFrame }
	local keys = clip.keys
	t = if clip.loop then t % clip.length else math.clamp(t, 0, clip.length)
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			local u = ease((t - a.t) / (b.t - a.t))
			local pose = {}
			for name, rotation in a.joints do
				pose[name] = rotation:Lerp(b.joints[name], u)
			end
			return pose
		end
	end
	return keys[#keys].joints
end

--[[ The clip's earliest marker, or its start if it has none. ]]
local function firstMarker(clip: WeaponAnimations.Clip): number
	local earliest = math.huge
	for _, t in clip.markers do
		earliest = math.min(earliest, t)
	end
	return if earliest == math.huge then 0 else earliest
end

local function currentWeapon(): (string, Weapons.Weapon)
	local class = Classes[player:GetAttribute("Class") :: string? or "Ranger"] or Classes.Ranger
	return class.weapon, (Weapons :: any)[class.weapon] :: Weapons.Weapon
end

local function play(nextRole: string, speed: number, now: number)
	role = nextRole
	roleStarted = now
	roleSpeed = speed
	fadeFrom = table.clone(written)
	fadeStarted = now
end

--[[ How much faster than written `fire` and `ready` play, to fit the
     cooldown. ]]
local function cycleSpeed(): number
	local name, weapon = currentWeapon()
	local clips = WeaponAnimations[name]
	local cooldown = PlayerStats.get().attackCooldown
	local natural = clips[weapon.clips.fire].length + clips[weapon.clips.ready].length
	return math.max(1, natural / (cooldown * CYCLE_SHARE))
end

local function stepPose(character: Model, now: number, dt: number)
	local name, weapon = currentWeapon()
	local clips = WeaponAnimations[name]
	if name ~= weaponName then
		weaponName = name
		play("hold", 1, now)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local moving = humanoid ~= nil
		and humanoid.MoveDirection.Magnitude > Balance.Player.stationaryThreshold
	local aiming = not moving and hasTarget()

	if not aiming then
		if role ~= "hold" then
			play("hold", 1, now)
		end
	elseif role == "hold" then
		play("ready", cycleSpeed(), now)
	end

	local clip = clips[(weapon.clips :: any)[role]]
	local t = (now - roleStarted) * roleSpeed
	if not clip.loop and t >= clip.length then
		play(if role == "fire" then "ready" else "aim", roleSpeed, now)
		clip = clips[(weapon.clips :: any)[role]]
		t = 0
	end

	if role == "ready" and t >= firstMarker(clip) then
		engaged = true
	elseif role == "hold" or (role == "fire" and t >= firstMarker(clip)) then
		engaged = false
	end

	local target = sample(clip, t)
	local blend = math.clamp((now - fadeStarted) / FADE, 0, 1)
	for jointName, part in JOINT_PARTS do
		local j = joint(character, part, jointName)
		if not j then
			continue
		end
		local from: CFrame? = fadeFrom[jointName]
		local goal: CFrame? = target[jointName]
		if goal == nil and (from == nil or blend >= 1) then
			--[[ Left to Roblox's own animation. ]]
			written[jointName] = nil
			continue
		end
		local pose = goal or (j :: any).Transform
		if from and blend < 1 then
			pose = from:Lerp(pose, blend)
		end
		(j :: any).Transform = pose
		written[jointName] = pose
	end

	if weapon.bowString then
		BowString.step(character, engaged)
	else
		BowString.hide()
	end
	if weapon.orbitAxis then
		StaffOrb.step(character, engaged, weapon.orbitAxis, dt)
	else
		StaffOrb.hide()
	end
end

local function step()
	local now = os.clock()
	local dt = now - lastStep
	lastStep = now
	local character = player.Character
	if character then
		stepPose(character, now, dt)
	end
end

--[[ A volley left the weapon. ]]
function WeaponPose.release()
	play("fire", cycleSpeed(), os.clock())
	StaffOrb.spend()
end

--[[ `aimHasTarget` says whether there is anything to shoot, so the weapon
     is readied only when a shot can follow. ]]
function WeaponPose.start(aimHasTarget: () -> boolean)
	hasTarget = aimHasTarget
	if connection then
		connection:Disconnect()
	end
	connection = RunService.Stepped:Connect(step)
end

return WeaponPose
