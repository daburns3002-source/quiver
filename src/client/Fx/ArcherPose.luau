--!strict
--[[
	The class's arms.

	The archer's come from the owner's Leaf Bow kit (`Config/BowAnimations`,
	2026-10-23), played here in code rather than as uploaded animations so
	they need no publishing and follow the real fire rhythm:

	- Hold, the bow held low, while moving or with nothing to shoot. Arms
	  only, so the legs still walk.
	- Draw on stopping with a target: the archer turns side-on, raises the
	  bow and draws to the chin, then Aim holds full draw.
	- Fire on every volley this client fires (`LocalFiring.onFired`), then
	  Draw again. The pair is sped up to fit inside the shot cooldown, so a
	  faster archer draws faster rather than skipping the draw.

	Every change of clip blends from the last pose over `FADE` seconds.
	Joints a clip leaves out stay with Roblox's own animation. Written to the
	joints' `Transform` in RunService.Stepped, after the Animator has run.

	The Arcanist holds its staff before it in the right hand
	(`Config/Weapons.casterPose`) until its own animations arrive.

	Presentation only, on this client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BowAnimations = require(ReplicatedStorage.Shared.Config.BowAnimations)
local BowString = require(script.Parent.BowString)
local PlayerStats = require(script.Parent.Parent.PlayerStats)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local ArcherPose = {}

--[[ Seconds a change of clip blends over. ]]
local FADE = 0.08
--[[ The share of the shot cooldown that Fire and the next Draw may take,
     so the bow is back at full draw before the next shot. ]]
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

local clipName = "Hold"
local clipStarted = 0
local clipSpeed = 1
--[[ Whether an arrow is on the string: from Draw's Nock marker to Fire's
     Release marker. ]]
local nocked = false

--[[ The last pose written to each joint, and the pose a blend starts from. ]]
local written: { [string]: CFrame } = {}
local fadeFrom: { [string]: CFrame } = {}
local fadeStarted = -math.huge

--[[ Degrees, applied pitch (X) first, then roll (Z), then yaw (Y). ]]
local function angles(v: Vector3): CFrame
	return CFrame.Angles(0, math.rad(v.Y), 0)
		* CFrame.Angles(0, 0, math.rad(v.Z))
		* CFrame.Angles(math.rad(v.X), 0, 0)
end

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
local function sample(clip: BowAnimations.Clip, t: number): { [string]: CFrame }
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

local function play(name: string, speed: number, now: number)
	clipName = name
	clipStarted = now
	clipSpeed = speed
	fadeFrom = table.clone(written)
	fadeStarted = now
end

--[[ How much faster than written Fire and Draw play, to fit the cooldown. ]]
local function cycleSpeed(): number
	local cooldown = PlayerStats.get().attackCooldown
	local natural = BowAnimations.Fire.length + BowAnimations.Draw.length
	return math.max(1, natural / (cooldown * CYCLE_SHARE))
end

local function stepArcher(character: Model, now: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local moving = humanoid ~= nil
		and humanoid.MoveDirection.Magnitude > Balance.Player.stationaryThreshold
	local aiming = not moving and hasTarget()

	if not aiming then
		if clipName ~= "Hold" then
			play("Hold", 1, now)
		end
	elseif clipName == "Hold" then
		play("Draw", cycleSpeed(), now)
	end

	local clip = BowAnimations[clipName]
	local t = (now - clipStarted) * clipSpeed
	if not clip.loop and t >= clip.length then
		play(if clipName == "Fire" then "Draw" else "Aim", clipSpeed, now)
		clip = BowAnimations[clipName]
		t = 0
	end

	if clipName == "Hold" then
		nocked = false
	elseif clipName == "Draw" and t >= (clip.markers.Nock or 0) then
		nocked = true
	elseif clipName == "Fire" and t >= (clip.markers.Release or 0) then
		nocked = false
	end

	local target = sample(clip, t)
	local blend = math.clamp((now - fadeStarted) / FADE, 0, 1)
	for name, part in JOINT_PARTS do
		local j = joint(character, part, name)
		if not j then
			continue
		end
		local from: CFrame? = fadeFrom[name]
		local goal: CFrame? = target[name]
		if goal == nil and (from == nil or blend >= 1) then
			--[[ Left to Roblox's own animation. ]]
			written[name] = nil
			continue
		end
		local pose = goal or (j :: any).Transform
		if from and blend < 1 then
			pose = from:Lerp(pose, blend)
		end
		(j :: any).Transform = pose
		written[name] = pose
	end

	BowString.step(character, nocked)
end

--[[ The Arcanist: the staff held upright before it in the right hand. ]]
local function stepCaster(character: Model)
	local config = Weapons.casterPose
	local shoulder = joint(character, "RightUpperArm", "RightShoulder")
	local elbow = joint(character, "RightLowerArm", "RightElbow")
	if shoulder and elbow then
		(shoulder :: any).Transform = angles(config.holdShoulder);
		(elbow :: any).Transform = angles(config.holdElbow)
	end
	BowString.hide()
end

local function step()
	local character = player.Character
	if not character then
		return
	end
	if player:GetAttribute("Class") == "Arcanist" then
		stepCaster(character)
		return
	end
	stepArcher(character, os.clock())
end

--[[ A volley left the bow. ]]
function ArcherPose.release()
	if player:GetAttribute("Class") == "Arcanist" then
		return
	end
	play("Fire", cycleSpeed(), os.clock())
end

--[[ `aimHasTarget` says whether there is anything to shoot, so the archer
     draws only when a shot can follow. ]]
function ArcherPose.start(aimHasTarget: () -> boolean)
	hasTarget = aimHasTarget
	if connection then
		connection:Disconnect()
	end
	connection = RunService.Stepped:Connect(step)
end

return ArcherPose
