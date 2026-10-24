--!strict
--[[
	Poses a boss's body from a `BossMoves` pose.

	Other enemies' parts are welded to their hitbox and go where it goes. A
	boss squashes, stretches, leans and throws an arm, which a weld cannot
	do, so here its parts are unwelded and anchored and placed every frame,
	as the owner's handoff does: each part keeps its offset from the feet
	and its size, scaled about the feet along its own axes. Presentation
	only — the hitbox is placed by `EnemyManager` and stays the box the
	server sweeps.

	The blob shadow stays on the floor whatever the body does, and shrinks
	as the body rises. A thrown arm is a jelly tube from its shoulder to
	the fist, as the design builds it: a chain of cylinders with balls at
	the joints, laid along an arc with a ripple running down it, thinning
	as it stretches, a lump of goo riding out to the fist.

	A body that plays its own clips (`EnemyBoss.clips`: King Bloblin's
	imported rig, animated on each client by `Fx/ModelAnimator`) is built
	`shadowOnly`: its parts stay welded to the hitbox, which carries them
	up a jump, and only the shadow is placed here, kept on the floor. No
	jelly tube: his chain is part of his rig.
]]

local BossMoves = require(script.Parent.BossMoves)

local BossBody = {}

type Rest = {
	part: BasePart,
	size: Vector3,
	--[[ From the feet, in the body's own frame. ]]
	offset: CFrame,
}

--[[ Studs across the thrown arm's jelly tube at the shoulder, before it
     stretches. ]]
local ARM_THICKNESS = 2.8

--[[ Segments in the tube, as the design's. ]]
local SEGMENTS = 12

--[[ The tube's radius at the shoulder, as a share of its `thin`: the
     design's profile is 0.88 there. ]]
local SHOULDER_SHARE = 0.88

local TUBE_TRANSPARENCY = 0.15

export type Body = {
	rests: { Rest },
	arms: { [string]: Rest },
	shadow: Rest?,
	cylinders: { BasePart },
	balls: { BasePart },
	height: number,
}

--[[ The jelly the thrown arm stretches into. ]]
local JELLY = Color3.fromRGB(127, 203, 36)

function BossBody.new(
	model: Model,
	hitbox: BasePart,
	parts: { BasePart },
	shadowOnly: boolean?
): Body
	local height = hitbox.Size.Y
	local feet = hitbox.CFrame * CFrame.new(0, -height / 2, 0)
	local body: Body = {
		rests = {},
		arms = {},
		shadow = nil,
		cylinders = {},
		balls = {},
		height = height,
	}

	for _, part in parts do
		if part == hitbox or (shadowOnly and part.Name ~= "Shadow") then
			continue
		end
		for _, child in part:GetChildren() do
			if child:IsA("WeldConstraint") then
				child:Destroy()
			end
		end
		part.Anchored = true
		local rest: Rest =
			{ part = part, size = part.Size, offset = feet:ToObjectSpace(part.CFrame) }
		if part.Name == "Shadow" then
			body.shadow = rest
		else
			table.insert(body.rests, rest)
		end
		if part.Name:match("^Arm_") then
			body.arms[part.Name] = rest
		end
	end

	if shadowOnly then
		return body
	end

	local tube = Instance.new("Folder")
	tube.Name = "ArmTube"
	tube.Parent = model
	local function jelly(shape: Enum.PartType): BasePart
		local part = Instance.new("Part")
		part.Shape = shape
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Glass
		part.Color = JELLY
		part.Transparency = 1
		part.Size = Vector3.one * 0.1
		part.Parent = tube
		return part
	end
	for _ = 1, SEGMENTS do
		table.insert(body.cylinders, jelly(Enum.PartType.Cylinder))
	end
	for _ = 0, SEGMENTS do
		table.insert(body.balls, jelly(Enum.PartType.Ball))
	end

	return body
end

--[[ A part's size scaled by the squash, along its own axes. ]]
local function scaled(rest: Rest, squash: number, spread: number): Vector3
	local r = rest.offset
	local function along(axis: Vector3): number
		return math.sqrt((axis.X * spread) ^ 2 + (axis.Y * squash) ^ 2 + (axis.Z * spread) ^ 2)
	end
	return Vector3.new(
		rest.size.X * along(r.RightVector),
		rest.size.Y * along(r.UpVector),
		rest.size.Z * along(-r.LookVector)
	)
end

local function hideTube(body: Body)
	for _, part in body.cylinders do
		part.Transparency = 1
	end
	for _, part in body.balls do
		part.Transparency = 1
	end
end

--[[ The design's `drawArm`: a quadratic curve from the shoulder to the
     fist, lifted `arc` studs at its middle, with a sideways ripple that
     is still at both ends, and a radius that is thickest at the shoulder,
     thinnest along the stretch, swelling a little into the fist and
     around the lump of goo. ]]
local function drawTube(body: Body, shoulder: Vector3, fist: Vector3, pose: BossMoves.Pose)
	local span = fist - shoulder
	local length = span.Magnitude
	if length < 0.6 then
		hideTube(body)
		return
	end
	local sideways = span:Cross(Vector3.yAxis)
	sideways = if sideways.Magnitude > 1e-3 then sideways.Unit else Vector3.xAxis
	local middle = (shoulder + fist) / 2 + Vector3.new(0, pose.tubeArc, 0)
	--[[ As thick as the owner asked (2026-10-23: "his arms ... are super
	     thin"), thinning the further it stretches as jelly would, by the
	     design's own rule (its 4 units are 8 studs here). ]]
	local thin = ARM_THICKNESS / (2 * SHOULDER_SHARE) / math.sqrt(math.max(1, length / 8))

	local points: { Vector3 } = {}
	local radii: { number } = {}
	for i = 0, SEGMENTS do
		local s = i / SEGMENTS
		local point = shoulder * (1 - s) ^ 2 + middle * (2 * s * (1 - s)) + fist * (s * s)
		point += sideways * pose.tubeWave * math.sin(2 * math.pi * (1.5 * s - pose.tubePhase)) * math.sin(
			math.pi * s
		)
		points[i + 1] = point
		radii[i + 1] = thin * (0.5 + 0.38 * (1 - s) ^ 2 + 0.22 * s ^ 3)
			+ 0.45 * thin * math.exp(-(((s - pose.tubeBulge) / 0.07) ^ 2))
	end
	for i, ball in body.balls do
		ball.Size = Vector3.one * radii[i] * 2
		ball.CFrame = CFrame.new(points[i])
		ball.Transparency = TUBE_TRANSPARENCY
	end
	for i, cylinder in body.cylinders do
		local from, to = points[i], points[i + 1]
		local across = radii[i] + radii[i + 1]
		cylinder.Size = Vector3.new(math.max(0.05, (to - from).Magnitude), across, across)
		cylinder.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0)
		cylinder.Transparency = TUBE_TRANSPARENCY
	end
end

function BossBody.pose(body: Body, pose: BossMoves.Pose)
	local ground = CFrame.new(pose.feet) * CFrame.Angles(0, pose.yaw, 0)
	local base = ground
		* CFrame.Angles(0, pose.twist, 0)
		* CFrame.new(0, pose.lift, -pose.lean)
		* CFrame.Angles(-pose.pitch, 0, 0)

	for _, rest in body.rests do
		local r = rest.offset
		local moved = Vector3.new(r.X * pose.spread, r.Y * pose.squash, r.Z * pose.spread)
		rest.part.CFrame = base * (CFrame.new(moved) * r.Rotation)
		rest.part.Size = scaled(rest, pose.squash, pose.spread)
	end

	--[[ Both arms up for a bounce; the throwing arm balled up behind the
	     shoulder before a lash (+Z is behind him), swelling as it coils. ]]
	for name, arm in body.arms do
		local raise = Vector3.new(0, pose.armsLift, 0)
		if name == pose.arm then
			raise += pose.armOffset
			arm.part.Size *= pose.armSwell
		end
		if raise.Magnitude > 0 then
			arm.part.CFrame = arm.part.CFrame + base:VectorToWorldSpace(raise)
		end
	end

	local shadow = body.shadow
	if shadow then
		local fade = math.clamp(1 - pose.lift / (body.height * 1.5), 0.35, 1)
		shadow.part.CFrame = ground * shadow.offset
		shadow.part.Size = Vector3.new(
			shadow.size.X * pose.spread * fade,
			shadow.size.Y,
			shadow.size.Z * pose.spread * fade
		)
	end

	local arm = if pose.arm then body.arms[pose.arm] else nil
	local held = pose.held
	if not arm or (pose.armReach <= 0.02 and not held) then
		hideTube(body)
		return
	end

	--[[ The fist flies from the shoulder out to the lane's end, arcing up
	     on the way, or stays on whoever it holds. ]]
	local shoulder = arm.part.Position
	local fist = if held
		then Vector3.new(held.X, pose.fistLift, held.Z)
		else shoulder:Lerp(
			pose.feet + pose.direction * pose.length + Vector3.new(0, pose.fistLift, 0),
			pose.armReach
		) + Vector3.new(0, pose.fistArc, 0)
	arm.part.Size = arm.size * pose.fistScale * pose.fistShape
	--[[ Never into the floor, however big the fist swells or flat it
	     splats: the design rests it on its own half height. ]]
	fist = Vector3.new(fist.X, math.max(fist.Y, arm.part.Size.Y / 2), fist.Z)
	arm.part.CFrame = CFrame.lookAt(fist, fist + pose.direction)
	drawTube(body, shoulder, fist, pose)
end

return BossBody
