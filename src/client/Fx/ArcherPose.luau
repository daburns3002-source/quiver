--!strict
--[[
	The class's arms. The archer's: held still in the owner's pose, bow in
	the left hand (`Config/Weapons.archerHold`, from the owner's posed rig,
	2026-10-23: "scrap the bow animations and use this instead").

	Written to the arm joints' `Transform` in RunService.Stepped, after
	Roblox's own animations have run, so walking still moves the legs while
	the arms keep the bow.

	The Arcanist's: the staff held before it in the right hand, thrust out on
	every cast (`Config/Weapons.casterPose`), timed by `LocalFiring.onFired`.

	Presentation only, on this client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local ArcherPose = {}

local player = Players.LocalPlayer
local connection: RBXScriptConnection? = nil
local releasedAt = -math.huge
--[[ Degrees, applied pitch (X) first, then roll (Z), then yaw (Y): raise
     the arm, turn it about its own length so the elbow's hinge points the
     right way, then swing it round the body. ]]
local function angles(v: Vector3): CFrame
	return CFrame.Angles(0, math.rad(v.Y), 0)
		* CFrame.Angles(0, 0, math.rad(v.Z))
		* CFrame.Angles(math.rad(v.X), 0, 0)
end

local function lerp(a: Vector3, b: Vector3, t: number): Vector3
	return a + (b - a) * t
end

--[[ A joint is a classic Motor6D or, on avatars with Roblox's physics-based
     joints, an AnimationConstraint. Both carry `Transform`, which the
     animation system writes every frame before RunService.Stepped; writing
     it in Stepped, after that, replaces the arm animation with the pose. ]]
local function joint(character: Model, part: string, name: string): (Motor6D | AnimationConstraint)?
	local holder = character:FindFirstChild(part)
	local found = holder and holder:FindFirstChild(name)
	if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
		return found :: any
	end
	return nil
end

local function pose(j: Motor6D | AnimationConstraint, rotation: CFrame)
	(j :: any).Transform = rotation
end

--[[ The Arcanist: the right arm holds the staff before it and thrusts it out
     on each cast, then eases back. The left arm is left to the animation. ]]
local function stepCaster(character: Model, now: number)
	local config = Weapons.casterPose
	local shoulder = joint(character, "RightUpperArm", "RightShoulder")
	local elbow = joint(character, "RightLowerArm", "RightElbow")
	if not (shoulder and elbow) then
		return
	end
	local since = now - releasedAt
	local out = if since < config.thrust
		then since / config.thrust
		else 1 - math.clamp((since - config.thrust) / config.recover, 0, 1)
	out = out * out * (3 - 2 * out)
	pose(shoulder, angles(lerp(config.holdShoulder, config.castShoulder, out)))
	pose(elbow, angles(lerp(config.holdElbow, config.castElbow, out)))
end

local function step()
	local character = player.Character
	if not character then
		return
	end
	if player:GetAttribute("Class") == "Arcanist" then
		stepCaster(character, os.clock())
		return
	end
	for _, hold in Weapons.archerHold do
		local j = joint(character, hold.part, hold.joint)
		if j then
			pose(j, hold.rotation)
		end
	end
end

--[[ A cast left the staff. ]]
function ArcherPose.release()
	releasedAt = os.clock()
end

function ArcherPose.start()
	if connection then
		connection:Disconnect()
	end
	connection = RunService.Stepped:Connect(step)
end

return ArcherPose
