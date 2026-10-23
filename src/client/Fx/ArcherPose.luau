--!strict
--[[
	The archer's arms: the bow held out in front, the string hand drawing to
	the cheek and snapping forward on every shot (owner, 2026-10-23: "an
	animation for shooting"; `Config/Weapons.archerPose`).

	Posed in code on the R15 arm joints rather than with an uploaded
	animation, so it follows the real fire rhythm exactly: a release on each
	shot this client fires (`LocalFiring.onFired`), then the draw back over
	`draw` seconds, ready for the next. Written to the arm joints'
	`Transform` in RunService.Stepped, after Roblox's own animations have
	run, so walking still moves the legs while the arms keep the bow.

	Presentation only, on this client; the nocked arrow is shown while drawn.
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

--[[ How drawn the string is: 0 with the hand at the string, 1 at the cheek,
     a little over 1 on the follow-through just after a release. And whether
     an arrow is on the string. ]]
local function drawn(now: number): (number, boolean)
	local config = Weapons.archerPose
	local since = now - releasedAt
	if since < config.release then
		return 1 + 0.25 * math.sin(math.pi * since / config.release), false
	end
	local t = math.clamp((since - config.release) / config.draw, 0, 1)
	if t < config.reach then
		local u = t / config.reach
		return 1 - u * u * (3 - 2 * u), false
	end
	local u = (t - config.reach) / (1 - config.reach)
	return 1 - (1 - u) ^ 3, true
end

local function step()
	local character = player.Character
	if not character then
		return
	end
	local config = Weapons.archerPose
	local now = os.clock()
	local d, nocked = drawn(now)
	local kick = math.max(0, 1 - (now - releasedAt) / (config.release * 3))

	local bowShoulder = joint(character, "LeftUpperArm", "LeftShoulder")
	local bowElbow = joint(character, "LeftLowerArm", "LeftElbow")
	local stringShoulder = joint(character, "RightUpperArm", "RightShoulder")
	local stringElbow = joint(character, "RightLowerArm", "RightElbow")
	if not (bowShoulder and bowElbow and stringShoulder and stringElbow) then
		return
	end

	pose(bowShoulder, angles(config.bowShoulder - Vector3.new(config.recoil * kick, 0, 0)))
	pose(bowElbow, angles(config.bowElbow))
	pose(stringShoulder, angles(lerp(config.stringShoulderRest, config.stringShoulderDrawn, d)))
	pose(stringElbow, angles(lerp(config.stringElbowRest, config.stringElbowDrawn, d)))

	local weapon = character:FindFirstChild("HeldWeapon")
	if weapon then
		for _, part in weapon:GetChildren() do
			if part:IsA("BasePart") and part:GetAttribute("Nocked") then
				part.LocalTransparencyModifier = 0
				part.Transparency = if nocked then 0 else 1
			end
		end
	end
end

--[[ A shot left the bow. ]]
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
