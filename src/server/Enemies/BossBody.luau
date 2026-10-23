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
	as the body rises. A thrown arm gets a stretched jelly tube from its
	shoulder to the fist.
]]

local BossMoves = require(script.Parent.BossMoves)

local BossBody = {}

type Rest = {
	part: BasePart,
	size: Vector3,
	--[[ From the feet, in the body's own frame. ]]
	offset: CFrame,
}

--[[ Studs across the thrown arm's jelly tube, before it stretches. ]]
local ARM_THICKNESS = 2.8

export type Body = {
	rests: { Rest },
	arms: { [string]: Rest },
	shadow: Rest?,
	tube: BasePart,
	height: number,
}

--[[ The jelly the thrown arm stretches into. ]]
local JELLY = Color3.fromRGB(127, 203, 36)

function BossBody.new(model: Model, hitbox: BasePart, parts: { BasePart }): Body
	local height = hitbox.Size.Y
	local feet = hitbox.CFrame * CFrame.new(0, -height / 2, 0)
	local body: Body = {
		rests = {},
		arms = {},
		shadow = nil,
		tube = nil :: any,
		height = height,
	}

	for _, part in parts do
		if part == hitbox then
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

	local tube = Instance.new("Part")
	body.tube = tube
	tube.Name = "ArmTube"
	tube.Shape = Enum.PartType.Cylinder
	tube.Anchored = true
	tube.CanCollide = false
	tube.CanQuery = false
	tube.CanTouch = false
	tube.CastShadow = false
	tube.Material = Enum.Material.Glass
	tube.Color = JELLY
	tube.Transparency = 1
	tube.Size = Vector3.new(0.1, 0.1, 0.1)
	tube.Parent = model

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

function BossBody.pose(body: Body, pose: BossMoves.Pose)
	local ground = CFrame.new(pose.feet) * CFrame.Angles(0, pose.yaw, 0)
	local base = ground * CFrame.new(0, pose.lift, -pose.lean) * CFrame.Angles(-pose.pitch, 0, 0)

	for _, rest in body.rests do
		local r = rest.offset
		local moved = Vector3.new(r.X * pose.spread, r.Y * pose.squash, r.Z * pose.spread)
		rest.part.CFrame = base * (CFrame.new(moved) * r.Rotation)
		rest.part.Size = scaled(rest, pose.squash, pose.spread)
	end

	--[[ Both arms up for a bounce; the throwing arm pulled back (+Z is
	     behind him) before a lash. ]]
	for name, arm in body.arms do
		local raise = Vector3.new(0, pose.armsLift, 0)
		if name == pose.arm and pose.armPull > 0 then
			raise += Vector3.new(0, 0.5 * pose.armPull, 1.8 * pose.armPull)
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
	local tube = body.tube
	local held = pose.held
	if not arm or (pose.armReach <= 0.02 and not held) then
		tube.Transparency = 1
		return
	end

	--[[ The fist flies from the shoulder to the lane's end and down onto
	     the floor there, or stays on whoever it holds. ]]
	local shoulder = arm.part.Position
	local fist = if held
		then Vector3.new(held.X, pose.fistLift, held.Z)
		else shoulder:Lerp(
			pose.feet + pose.direction * pose.length + Vector3.new(0, pose.fistLift, 0),
			math.clamp(pose.armReach, 0, 1)
		)
	arm.part.Size = arm.size * pose.fistScale
	arm.part.CFrame = CFrame.lookAt(fist, fist + pose.direction)

	local span = fist - shoulder
	if span.Magnitude < 0.6 then
		tube.Transparency = 1
		return
	end
	--[[ As thick as the design's (owner, 2026-10-23: "his arms ... are super
	     thin"): its tube is 0.55 to 0.85 across in the model's units, about
	     2.8 studs at this size, thinning the further it stretches as jelly
	     would, by the design's own rule (its 4 units are 8 studs here). ]]
	local thick = ARM_THICKNESS / math.sqrt(math.max(1, span.Magnitude / 8))
	tube.Size = Vector3.new(span.Magnitude, thick, thick)
	tube.CFrame = CFrame.lookAt((shoulder + fist) / 2, fist) * CFrame.Angles(0, math.pi / 2, 0)
	tube.Transparency = 0.15
end

return BossBody
