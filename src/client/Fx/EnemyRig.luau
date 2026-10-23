--!strict
--[[
	Animates a rigged enemy's skinned body on this client (the Ember Wolf:
	the owner's design_handoff_ember_wolf, 2026-10-23): it runs as it
	moves and dashes as it lunges, from its own clips (`Config/EnemyRigs`,
	played by `Shared/Util/RigClip`).

	Presentation only. The server moves the hitbox exactly as before; this
	reads it. The Run's pace follows how fast the hitbox goes, and fades
	out when it stops. The Dash starts with the server's wind-up flag
	(`WindingUp`) and fits itself to the lunge: the crouch over the
	wind-up, the leap over the bolt (`LungeWindup`, `LungeTravel`), then
	the skid.

	The body is claimed from `Fx/HitSquash` and squashed here, bones and
	all: a skinned mesh scaled without its bones crushes its head into its
	body. Parts that ride a bone (`EnemyDesigns.BoneTag`, the glowing eyes
	on the head) are placed on it every frame so they bob with it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local EnemyRigs = require(ReplicatedStorage.Shared.Config.EnemyRigs)
local HitSquash = require(script.Parent.HitSquash)
local RigClip = require(ReplicatedStorage.Shared.Util.RigClip)

local EnemyRig = {}

--[[ Studs a second under which a body is standing, not running. ]]
local STILL_SPEED = 0.5
--[[ How fast the Run fades in and out, per second. ]]
local BLEND_RATE = 6
--[[ An `Eyes` tell's pulse: the eyes swell by this share, this many
     times a second. ]]
local EYE_PULSE = 0.6
local EYE_FLASHES = 4
--[[ A bone at rest: what the Run fades out to. ]]
local REST = CFrame.new()

type Rider = { part: BasePart, bone: Bone, offset: CFrame, size: Vector3 }

type Body = {
	rig: EnemyRigs.Rig,
	hitbox: BasePart,
	part: BasePart,
	size: Vector3,
	--[[ From the floor under the hitbox's centre, in its frame. ]]
	offset: CFrame,
	bones: { [string]: Bone },
	rests: { [Bone]: CFrame },
	riders: { Rider },
	last: Vector3,
	runTime: number,
	runWeight: number,
	dashAt: number?,
	launchAt: number?,
	windup: number,
	travel: number,
}

local bodies: { [Model]: Body } = {}

local function floorOf(hitbox: BasePart): CFrame
	return hitbox.CFrame * CFrame.new(0, -hitbox.Size.Y / 2, 0)
end

local function unweld(part: BasePart)
	for _, child in part:GetChildren() do
		if child:IsA("WeldConstraint") then
			child.Enabled = false
		end
	end
	part.Anchored = true
end

local function setup(model: Model)
	if bodies[model] then
		return
	end
	local rig = EnemyRigs[model.Name]
	local hitbox = model.PrimaryPart
	if not rig or not hitbox then
		return
	end
	local part = model:FindFirstChild(rig.part)
	if not part or not part:IsA("BasePart") then
		return
	end

	local bones: { [string]: Bone } = {}
	local rests: { [Bone]: CFrame } = {}
	for _, d in part:GetDescendants() do
		if d:IsA("Bone") then
			bones[d.Name] = d
			rests[d] = d.CFrame
		end
	end
	if next(bones) == nil then
		return
	end

	local floor = floorOf(hitbox)
	local body: Body = {
		rig = rig,
		hitbox = hitbox,
		part = part,
		size = part.Size,
		offset = floor:ToObjectSpace(part.CFrame),
		bones = bones,
		rests = rests,
		riders = {},
		last = hitbox.Position,
		runTime = math.random() * 0.5,
		runWeight = 0,
		dashAt = nil,
		launchAt = nil,
		windup = 0,
		travel = 0,
	}
	for _, child in model:GetChildren() do
		local boneName = child:GetAttribute(EnemyDesigns.BoneTag)
		if child:IsA("BasePart") and type(boneName) == "string" and bones[boneName] then
			local bone = bones[boneName]
			unweld(child)
			table.insert(body.riders, {
				part = child,
				bone = bone,
				offset = bone.TransformedWorldCFrame:ToObjectSpace(child.CFrame),
				size = child.Size,
			})
		end
	end
	unweld(part)
	HitSquash.claim(model)
	bodies[model] = body
end

local function step(dt: number)
	local now = os.clock()
	for model, body in bodies do
		local hitbox = body.hitbox
		if not model.Parent or not hitbox.Parent or not body.part.Parent then
			bodies[model] = nil
			continue
		end
		local rig = body.rig
		local at = hitbox.Position
		local moved = Vector3.new(at.X - body.last.X, 0, at.Z - body.last.Z)
		body.last = at
		local speed = moved.Magnitude / math.max(dt, 1e-4)

		--[[ The lunge: the wind-up flag starts the dash, its clearing
		     launches it. ]]
		local winding = model:GetAttribute("WindingUp") == true
		if winding and not body.dashAt then
			body.dashAt = now
			body.launchAt = nil
			body.windup = (model:GetAttribute("LungeWindup") :: number?) or 0.5
			body.travel = (model:GetAttribute("LungeTravel") :: number?) or 0.3
		elseif body.dashAt and not winding and not body.launchAt then
			body.launchAt = now
		end

		local poses: { [string]: CFrame }
		local dash = rig.clips.Dash
		local dashAt = body.dashAt
		if dash and dashAt then
			local launchAt = body.launchAt
			local time = RigClip.dashTime(
				dash,
				body.windup,
				body.travel,
				now - dashAt,
				if launchAt then now - launchAt else nil
			)
			poses = RigClip.sample(dash, time, rig.scale)
			body.runWeight = 0
			if time >= dash.length then
				body.dashAt = nil
				body.launchAt = nil
			end
		else
			local run = rig.clips.Run
			local moving = speed > STILL_SPEED
			local target = if moving then 1 else 0
			body.runWeight += math.clamp(target - body.runWeight, -BLEND_RATE * dt, BLEND_RATE * dt)
			body.runTime += dt * speed / (rig.strideSpeed * rig.scale)
			poses = RigClip.sample(run, body.runTime, rig.scale)
			if body.runWeight < 1 then
				for name, pose in poses do
					poses[name] = REST:Lerp(pose, body.runWeight)
				end
			end
		end

		--[[ A hit's squash, about the feet, bones and all. ]]
		local tall = HitSquash.tall(model)
		local thin = 1 / math.sqrt(tall)
		local ratio = Vector3.new(thin, tall, thin)
		local o = body.offset
		body.part.Size = body.size * ratio
		body.part.CFrame = floorOf(hitbox) * (CFrame.new(o.Position * ratio) * o.Rotation)
		for name, bone in body.bones do
			local rest = body.rests[bone]
			bone.CFrame = rest.Rotation + rest.Position * ratio
			bone.Transform = poses[name] or CFrame.identity
		end

		--[[ An `Eyes` tell: the eyes, already red from the server, pulse
		     while it winds up (owner, 2026-10-23: "the eyes just flash red
		     before he charges"). ]]
		local flashing = winding and model:GetAttribute("LungeTell") == "Eyes"
		local pulse = if flashing
			then 1 + EYE_PULSE * math.abs(
				math.sin((now - (body.dashAt or now)) * math.pi * EYE_FLASHES)
			)
			else 1
		for _, rider in body.riders do
			rider.part.CFrame = rider.bone.TransformedWorldCFrame * rider.offset
			if rider.part:GetAttribute(EnemyDesigns.EyeTag) then
				rider.part.Size = rider.size * pulse
			end
		end
	end
end

--[[ Watches every enemy that arrives. The "Enemies" folder is rebuilt
     each room, so it is followed by name. ]]
function EnemyRig.start(parent: Instance)
	local function watchFolder(folder: Instance)
		if folder.Name ~= "Enemies" or not folder:IsA("Folder") then
			return
		end
		local function arrive(child: Instance)
			if child:IsA("Model") then
				setup(child)
			end
		end
		for _, child in folder:GetChildren() do
			arrive(child)
		end
		folder.ChildAdded:Connect(arrive)
	end

	for _, child in parent:GetChildren() do
		watchFolder(child)
	end
	parent.ChildAdded:Connect(watchFolder)
	RunService.RenderStepped:Connect(step)
end

return EnemyRig
