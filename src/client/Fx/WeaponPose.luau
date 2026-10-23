--!strict
--[[
	The class's arms: its weapon's animations from the owner's kits
	(`Config/WeaponAnimations`, 2026-10-23), played here in code rather than
	as uploaded animations, so they need no publishing and follow the real
	fire rhythm. Each weapon names its clips (`Config/Weapons.clips`):

	- `hold` with nothing to shoot, and while moving unless the weapon has
	  a `move` clip (the greatsword's blade-dragging Walk, kept in step with
	  the character's speed). Hold is arms only, so the legs still walk.
	- `ready` on stopping with a target (the bow's Draw, the staff's
	  Charge), then `aim` loops (Aim, Channel). The greatsword has neither
	  and holds until it swings.
	- `fire` on every attack this client predicts (`LocalFiring.onFired`),
	  the next clip of the weapon's combo each time (the greatsword's three
	  slashes), then `ready` again (or straight back to `aim` for a weapon
	  whose `afterFire` says so: the dual bows raise once and take turns). They are sped up to fit inside the
	  attack cooldown (`Shared/Combat/WeaponTiming`, which the server uses
	  to land a swing on its `Hit` marker), so a faster attacker draws
	  faster rather than skipping the draw. An attack plays out even if its
	  target dies; only moving cuts it short.

	The weapon is engaged — an arrow on the string, a cast charging — from
	`ready`'s first marker (the bow's Nock; the staff's Charge has none, so
	from its start) until `fire`'s (Release, Cast). `Fx/BowString` and
	`Fx/StaffOrb` draw from that; `Fx/SwingTrail` shows a blade's trail
	between a slash's TrailOn and TrailOff, and `Fx/BladeFx` its sparks as
	the walk drags it and as each blow lands.

	A weapon may have a `legs` layer (the bow's, from the owner's LeafBow R15
	kit): its Idle standing, its Walk moving at the character's pace, for
	the joints the playing clip leaves out — the bow's Hold moves only the
	upper body. Every change of clip blends from the last pose over `FADE`
	seconds. Joints no clip drives stay with Roblox's own animation. Written to the
	joints' `Transform` in RunService.Stepped, after the Animator has run.

	Presentation only, on this client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BladeFx = require(script.Parent.BladeFx)
local BowString = require(script.Parent.BowString)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local PlayerStats = require(script.Parent.Parent.PlayerStats)
local StaffOrb = require(script.Parent.StaffOrb)
local SwingTrail = require(script.Parent.SwingTrail)
local WeaponAnimations = require(ReplicatedStorage.Shared.Config.WeaponAnimations)
local WeaponTiming = require(ReplicatedStorage.Shared.Combat.WeaponTiming)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local WeaponPose = {}

--[[ Seconds a change of clip blends over. ]]
local FADE = 0.08

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
--[[ The role (`hold`, `move`, `ready`, `aim`, `fire`) playing, how far
     into its clip, and how fast it plays. Time is advanced each frame at
     the role's speed rather than read off a start time, so a walk can
     change speed with the character without jumping in its cycle. ]]
local role = "hold"
local phase = 0
local roleSpeed = 1
--[[ The combo: which `fire` clip played last (0 for none). It keeps its
     place between attacks, and starts over with a new character, as the
     server's does (`Combat/MeleeSystem`). ]]
local comboIndex = 0
local comboCharacter: Model? = nil
--[[ The place before the attack playing now, and whether its blow has
     landed: moving before it lands gives the place back. ]]
local comboPrevious = 0
local blowLanded = false
local engaged = false
local lastStep = os.clock()
--[[ The legs layer: which clip, and how far into it. ]]
local legsClip: string? = nil
local legsPhase = 0

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

--[[ The weapon in hand, as the server recorded it (`RunSession`): the
     class's own, or one a drafted card put there (the Dual Bows Mythic). ]]
local function currentWeapon(): (string, Weapons.Weapon)
	local class = Classes[player:GetAttribute("Class") :: string? or "Ranger"] or Classes.Ranger
	local recorded = player:GetAttribute("Weapon")
	local name = if type(recorded) == "string" and (Weapons :: any)[recorded]
		then recorded
		else class.weapon
	return name, (Weapons :: any)[name] :: Weapons.Weapon
end

--[[ The clip a role plays on this weapon, or nil when it has none. ]]
--[[ The one-off clip playing in the `special` role. ]]
local specialClip: string? = nil

local function clipFor(weapon: Weapons.Weapon, which: string): string?
	if which == "fire" then
		return weapon.clips.fire[math.max(comboIndex, 1)]
	end
	if which == "special" then
		return specialClip
	end
	return (weapon.clips :: any)[which]
end

local function play(nextRole: string, speed: number, now: number)
	role = nextRole
	phase = 0
	roleSpeed = speed
	fadeFrom = table.clone(written)
	fadeStarted = now
end

local function cycleSpeed(): number
	local name = currentWeapon()
	return WeaponTiming.cycleSpeed(name, math.max(comboIndex, 1), PlayerStats.get().attackCooldown)
end

local function stepPose(character: Model, now: number, dt: number)
	local name, weapon = currentWeapon()
	local clips = WeaponAnimations[name]
	if name ~= weaponName then
		weaponName = name
		comboIndex = 0
		play("hold", 1, now)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local moving = humanoid ~= nil
		and humanoid.MoveDirection.Magnitude > Balance.Player.stationaryThreshold
	local aiming = not moving and hasTarget()

	--[[ A swing or a release plays out even if its target died mid-way;
	     only moving cuts it short. A special clip (`playSpecial`) plays out
	     whatever happens. ]]
	if role ~= "special" then
		if moving then
			local want = if weapon.clips.move then "move" else "hold"
			if role == "fire" and not blowLanded then
				comboIndex = comboPrevious
			end
			if role ~= want then
				play(want, 1, now)
			end
		elseif role ~= "fire" and not aiming then
			if role ~= "hold" then
				play("hold", 1, now)
			end
		elseif role == "hold" or role == "move" then
			if weapon.clips.ready then
				play("ready", cycleSpeed(), now)
			elseif role == "move" then
				play("hold", 1, now)
			end
		end
	end

	if role == "move" and humanoid then
		--[[ The walk keeps pace with the feet, within limits. ]]
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
		local planar = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		roleSpeed = math.clamp(planar / (weapon.clips.moveSpeed or planar), 0.6, 2.2)
	end

	local before = phase
	phase += dt * roleSpeed
	local clip = clips[clipFor(weapon, role) :: string]

	--[[ The blow lands as the slash passes its Hit marker: the server's
	     damage lands then too (`Shared/Combat/WeaponTiming`). ]]
	local hit = clip.markers.Hit
	if role == "fire" and hit and before < hit and phase >= hit then
		blowLanded = true
		BladeFx.impact(character, weapon, comboIndex == #weapon.clips.fire)
	end

	if not clip.loop and phase >= clip.length then
		local nextRole
		if role == "fire" then
			nextRole = if aiming and weapon.clips.ready
				then (weapon.clips.afterFire or "ready")
				else "hold"
		elseif role == "special" then
			nextRole = "hold"
		else
			nextRole = "aim"
		end
		play(nextRole, if nextRole == "hold" then 1 else roleSpeed, now)
		clip = clips[clipFor(weapon, role) :: string]
	end
	local t = phase

	if role == "ready" and t >= firstMarker(clip) then
		engaged = true
	elseif role == "hold" or role == "move" or (role == "fire" and t >= firstMarker(clip)) then
		engaged = false
	end

	local target = sample(clip, t)

	--[[ The legs layer, under the clip: standing or walking, the walk kept
	     in step with the feet, as the owner's kit plays it. ]]
	local legs = weapon.clips.legs
	local under: { [string]: CFrame }? = nil
	if legs then
		local want = if moving then legs.walk else legs.idle
		if want ~= legsClip then
			legsClip = want
			legsPhase = 0
			fadeFrom = table.clone(written)
			fadeStarted = now
		end
		local pace = 1
		if moving then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
			local planar = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			pace = math.clamp(planar / legs.walkSpeed, 0.5, 2.5)
		end
		legsPhase += dt * pace
		under = sample(clips[want], legsPhase)
	else
		legsClip = nil
	end
	local blend = math.clamp((now - fadeStarted) / FADE, 0, 1)
	for jointName, part in JOINT_PARTS do
		local j = joint(character, part, jointName)
		if not j then
			continue
		end
		local from: CFrame? = fadeFrom[jointName]
		local goal: CFrame? = target[jointName] or (if under then under[jointName] else nil)
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
	local trailOn = clip.markers.TrailOn
	local trailOff = clip.markers.TrailOff
	BladeFx.step(character, weapon, role == "move")
	--[[ How far through the slash's trail window, for the red drawn on the
	     swing's box. ]]
	local trailProgress: number? = nil
	local trailSeconds = 0
	if role == "fire" and trailOn and trailOff and trailOff > trailOn then
		if t >= trailOn and t < trailOff then
			trailProgress = (t - trailOn) / (trailOff - trailOn)
		end
		trailSeconds = (trailOff - trailOn) / math.max(roleSpeed, 1e-3)
	end
	SwingTrail.step(
		character,
		weapon,
		trailProgress,
		math.max(comboIndex, 1),
		#weapon.clips.fire,
		trailSeconds
	)
end

local function step()
	local now = os.clock()
	local dt = now - lastStep
	lastStep = now
	local character = player.Character
	if character ~= comboCharacter then
		comboCharacter = character
		comboIndex = 0
	end
	if character then
		stepPose(character, now, dt)
	end
end

--[[ An attack left the weapon: the next clip of its combo plays. ]]
function WeaponPose.release()
	local now = os.clock()
	local name, weapon = currentWeapon()
	comboPrevious = comboIndex
	comboIndex = WeaponTiming.nextInCombo(name, comboIndex)
	blowLanded = WeaponAnimations[name][weapon.clips.fire[comboIndex]].markers.Hit == nil
	play("fire", cycleSpeed(), now)
	StaffOrb.spend()
end

--[[ Which blow of the weapon's combo played last (0 for none), for
     anything that follows the combo, such as each blow's sound. ]]
--[[ Plays a weapon's one-off clip (`Config/Weapons.clips.special`) once,
     through to its end, then back to Hold: the Earthbreaker Mythic's leap
     and slam as a dash ends, the Meteor Mythic's cast as one is called. Nothing for a weapon without it. ]]
function WeaponPose.playSpecial(key: string)
	local _, weapon = currentWeapon()
	local special = weapon.clips.special
	local name = special and special[key]
	if not name then
		return
	end
	specialClip = name
	play("special", 1, os.clock())
end

function WeaponPose.comboIndex(): number
	return comboIndex
end

--[[ `aimHasTarget` says whether there is anything to shoot, so the weapon
     is readied only when a shot can follow. ]]
function WeaponPose.start(aimHasTarget: () -> boolean)
	hasTarget = aimHasTarget
	if connection then
		connection:Disconnect()
	end
	connection = RunService.Stepped:Connect(step)
	--[[ The server counts each meteor this player calls down
	     (`Combat/FiringSystem`); the staff casts it. ]]
	Players.LocalPlayer:GetAttributeChangedSignal("Meteors"):Connect(function()
		WeaponPose.playSpecial("meteor")
	end)
end

return WeaponPose
