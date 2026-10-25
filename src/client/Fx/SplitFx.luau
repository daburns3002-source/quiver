--!strict
--[[
	A splitting enemy's death, after Zac's Cell Division in League of
	Legends: the body bursts into a puddle, and each piece is flung out of
	it as a blob of jelly — stretched along its flight, squashed flat where
	it lands, wobbling back to round — until the enemy it becomes appears.

	Presentation only. The server has already decided how many pieces, where
	each lands and when it becomes an enemy (`Balance.Split`); a piece is
	drawn from the `Split` telegraph that announces it, and is untargetable
	until it lands.

	A piece that plays its own clips (its body names one in `SplitClip`,
	from `EnemySplit.pieceClip`: the Bramble Sow's Boarlets) is thrown as
	itself instead: a copy of the body it becomes, playing that clip along
	the same arc, with no jelly at all.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local SplitFx = {}

--[[ The Moss Slime's jelly, a shade lighter so the blob reads in flight. ]]
local JELLY = Color3.fromRGB(128, 204, 62)
local JELLY_DARK = Color3.fromRGB(78, 150, 40)

--[[ Height a piece leaves from: the burst is at the dying body's middle. ]]
local LAUNCH_HEIGHT = 1.4

--[[ Seconds the blob takes to fade once its enemy should be standing in it,
     covering the replication of the enemy becoming visible. ]]
local HANDOVER = 0.15

--[[ A flying piece's shadow, the same as the enemies' (`EnemyDesigns`):
     matte black at 0.3, just off the floor. ]]
local SHADOW_COLOR = Color3.new(0, 0, 0)
local SHADOW_TRANSPARENCY = 0.3
local SHADOW_HEIGHT = 0.1

--[[ Frames a piece waits for its body's `SplitClip` to arrive (set just
     after the telegraph that announces it) before it is drawn as jelly. ]]
local CLIP_WAIT_FRAMES = 6

--[[ A body's parts keep their design's transparency here while it is
     hidden (`EnemyModel`). ]]
local RESTING_TRANSPARENCY = "RestingTransparency"

--[[ When each origin last burst, so the pieces of one death draw one puddle
     between them rather than one each. ]]
local lastBurst: { [Vector3]: number } = {}

local function part(name: string, colour: Color3, parent: Instance): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	created.Material = Enum.Material.SmoothPlastic
	created.Color = colour
	created.Parent = parent
	return created
end

--[[ A round blob that can be squashed and stretched: a block drawn as a
     sphere, since a Ball part is always perfectly round. ]]
local function blob(name: string, colour: Color3, parent: Instance): Part
	local created = part(name, colour, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = created
	return created
end

--[[ A flat disc of jelly on the floor, grown to `diameter` then thinned out. ]]
local function splat(at: Vector3, diameter: number, grow: number, last: number, parent: Instance)
	local disc = part("SplitSplat", JELLY_DARK, parent)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.2
	disc.Size = Vector3.new(0.12, diameter * 0.3, diameter * 0.3)
	disc.CFrame = CFrame.new(at.X, 0.07, at.Z) * CFrame.Angles(0, 0, math.rad(90))

	TweenService
		:Create(disc, TweenInfo.new(grow, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.12, diameter, diameter),
		})
		:Play()
	task.delay(grow, function()
		TweenService
			:Create(disc, TweenInfo.new(last, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = Vector3.new(0.12, diameter * 0.6, diameter * 0.6),
				Transparency = 1,
			})
			:Play()
	end)
	Debris:AddItem(disc, grow + last + 0.05)
end

--[[ The burst where the body fell: a puddle and a spray of droplets. Once
     per death, however many pieces it throws. ]]
local function burst(origin: Vector3, parent: Instance)
	local now = os.clock()
	for at, time in lastBurst do
		if now - time > 1 then
			lastBurst[at] = nil
		end
	end
	for at in lastBurst do
		if (at - origin).Magnitude < 0.5 then
			return
		end
	end
	lastBurst[origin] = now

	local split = Balance.Split
	splat(origin, 5, 0.14, split.flight + split.settle, parent)

	for index = 1, 7 do
		local angle = index / 7 * math.pi * 2 + math.random() * 0.6
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local drop = blob("SplitDrop", JELLY, parent)
		local size = 0.35 + math.random() * 0.3
		drop.Size = Vector3.one * size
		drop.Position = Vector3.new(origin.X, LAUNCH_HEIGHT, origin.Z)
		TweenService
			:Create(drop, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = Vector3.new(origin.X, 0.2, origin.Z)
					+ out * (1.8 + math.random() * 1.4)
					+ Vector3.new(0, 0.6 + math.random(), 0),
				Size = Vector3.one * size * 0.4,
				Transparency = 1,
			})
			:Play()
		Debris:AddItem(drop, 0.4)
	end
end

--[[ The body a piece becomes, if it is thrown as itself: the arriving
     enemy standing at `to` whose `SplitClip` names its clip. ]]
local function pieceBody(to: Vector3): (Model?, string?)
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil, nil
	end
	for _, child in enemies:GetChildren() do
		local clip = child:GetAttribute("SplitClip")
		local root = if child:IsA("Model") then child.PrimaryPart else nil
		if
			type(clip) == "string"
			and root
			and Vector2.new(root.Position.X - to.X, root.Position.Z - to.Z).Magnitude < 0.5
		then
			return child :: Model, clip
		end
	end
	return nil, nil
end

--[[ A flying piece's shadow on the floor under `position`: small and faint
     while it is high (`lift` 1), the enemies' own full shadow on the floor. ]]
local function placeShadow(shadow: Part, position: Vector3, lift: number, diameter: number)
	local spread = diameter * (1 - 0.45 * lift)
	shadow.Size = Vector3.new(spread, 0.08, spread)
	shadow.CFrame = CFrame.new(position.X, SHADOW_HEIGHT, position.Z)
	shadow.Transparency = SHADOW_TRANSPARENCY + (1 - SHADOW_TRANSPARENCY) * 0.6 * lift
end

--[[
	A piece thrown as itself: a copy of `body` (the enemy it becomes, still
	hidden where it will stand) playing `clip` over the whole throw, flying
	the arc facing the way it is thrown and turning to face as the body
	does while it settles. Gone once the body has taken over.
]]
local function throwBody(
	body: Model,
	clip: string,
	from: Vector3,
	duration: number,
	began: number,
	diameter: number,
	parent: Instance
)
	local split = Balance.Split
	local flight = math.min(split.flight, duration)

	local copy = body:Clone()
	copy.Name = "SplitPiece"
	for _, name in { "Targetable", "Health", "MaxHealth", "SplitClip" } do
		copy:SetAttribute(name, nil)
	end
	for _, piece in copy:GetDescendants() do
		if piece:IsA("BasePart") then
			local resting = piece:GetAttribute(RESTING_TRANSPARENCY)
			--[[ This throw draws its own shadow, which follows it in the air. ]]
			piece.Transparency = if piece.Name == "Shadow" or piece.Name == "Hitbox"
				then 1
				elseif type(resting) == "number" then resting
				else 0
		end
	end
	copy:SetAttribute("ModelClipSpan", duration)
	copy:SetAttribute("ModelClipAt", Workspace:GetServerTimeNow() - (os.clock() - began))
	copy:SetAttribute("ModelClip", clip)

	local rest = body:GetPivot()
	local start = Vector3.new(from.X, rest.Position.Y, from.Z)
	local throw = Vector3.new(rest.Position.X - from.X, 0, rest.Position.Z - from.Z)
	local facing = if throw.Magnitude > 1e-3
		then CFrame.lookAt(Vector3.zero, throw.Unit)
		else rest.Rotation
	copy:PivotTo(CFrame.new(start) * facing)
	copy.Parent = parent

	local shadow = blob("SplitShadow", SHADOW_COLOR, parent)
	shadow.Material = Enum.Material.Fabric

	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - began
		if body.Parent then
			rest = body:GetPivot()
		end

		if elapsed < flight then
			local u = elapsed / flight
			local arc = split.arcHeight * 4 * u * (1 - u)
			local position = start:Lerp(rest.Position, u) + Vector3.new(0, arc, 0)
			copy:PivotTo(CFrame.new(position) * facing)
			placeShadow(shadow, position, math.clamp(arc / split.arcHeight, 0, 1), diameter)
		else
			local settled = math.clamp((elapsed - flight) / math.max(duration - flight, 1e-3), 0, 1)
			copy:PivotTo(CFrame.new(rest.Position) * facing:Lerp(rest.Rotation, settled))
			placeShadow(shadow, rest.Position, 0, diameter)
			if elapsed >= duration then
				-- The enemy brings its own shadow; this one hands over to it.
				local fade = math.min((elapsed - duration) / HANDOVER, 1)
				shadow.Transparency = SHADOW_TRANSPARENCY + (1 - SHADOW_TRANSPARENCY) * fade
			end
		end

		if elapsed >= duration + HANDOVER then
			if connection then
				connection:Disconnect()
			end
			copy:Destroy()
			shadow:Destroy()
		end
	end)
end

--[[
	One piece: flung from `from` (where the body fell) to `to` (where its
	enemy will stand), landing at `Balance.Split.flight` and becoming the
	enemy at `duration`. `radius` is that enemy's body radius.
]]
function SplitFx.piece(
	from: Vector3,
	to: Vector3,
	duration: number,
	radius: number,
	parent: Instance
)
	local began = os.clock()
	task.spawn(function()
		local body, clip = pieceBody(to)
		for _ = 1, CLIP_WAIT_FRAMES do
			if body then
				break
			end
			RunService.RenderStepped:Wait()
			body, clip = pieceBody(to)
		end
		local diameter = math.max(radius, 0.5) * 2 * 0.8
		if body and clip then
			throwBody(body, clip, from, duration, began, diameter, parent)
		else
			SplitFx.jelly(from, to, duration, radius, parent, began)
		end
	end)
end

--[[ A piece drawn as a blob of jelly (a slime's), thrown from `began`. ]]
function SplitFx.jelly(
	from: Vector3,
	to: Vector3,
	duration: number,
	radius: number,
	parent: Instance,
	began: number
)
	burst(from, parent)

	local split = Balance.Split
	local flight = math.min(split.flight, duration)
	local diameter = math.max(radius, 0.5) * 2 * 0.8

	local start = Vector3.new(from.X, LAUNCH_HEIGHT, from.Z)
	local finish = Vector3.new(to.X, diameter / 2, to.Z)
	local body = blob("SplitPiece", JELLY, parent)
	body.Transparency = 0.08
	body.Size = Vector3.one * diameter * 0.5

	--[[ Its shadow on the floor from the moment it leaves the body, so a
	     piece in the air can be tracked to where it will land (owner,
	     2026-10-22: the split is "hard to see"). Small and faint while the
	     piece is high, the enemies' own full shadow once it lands. ]]
	local shadow = blob("SplitShadow", SHADOW_COLOR, parent)
	shadow.Material = Enum.Material.Fabric

	local landed = false
	local connection: RBXScriptConnection? = nil

	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - began

		if elapsed < flight then
			-- In the air: a parabola, stretched along the way it is going.
			local u = elapsed / flight
			local arc = Vector3.new(0, split.arcHeight * 4 * u * (1 - u), 0)
			local position = start:Lerp(finish, u) + arc
			local velocity = (finish - start) / flight
				+ Vector3.new(0, split.arcHeight * 4 * (1 - 2 * u) / flight, 0)
			-- Grows from the burst to full size over the first part of the throw.
			local grown = diameter * (0.5 + 0.5 * math.min(u / 0.35, 1))
			local stretch = 1 + math.min(velocity.Magnitude / 40, 0.45)
			local width = grown / math.sqrt(stretch)
			body.Size = Vector3.new(width, width, grown * stretch)
			body.CFrame = CFrame.lookAt(position, position + velocity)

			placeShadow(shadow, position, math.clamp(arc.Y / split.arcHeight, 0, 1), diameter)
			return
		end

		if not landed then
			landed = true
			splat(to, diameter * 1.4, 0.08, 0.35, parent)
		end

		-- Landed: squashed flat, wobbling back to round.
		local settled = elapsed - flight
		local squash = 1 - 0.5 * math.exp(-settled * 9) * math.cos(settled * 30)
		local height = diameter * squash
		local width = diameter / math.sqrt(squash)
		body.Size = Vector3.new(width, height, width)
		body.CFrame = CFrame.new(finish.X, height / 2, finish.Z)
		shadow.Size = Vector3.new(width, 0.08, width)
		shadow.CFrame = CFrame.new(finish.X, SHADOW_HEIGHT, finish.Z)
		shadow.Transparency = SHADOW_TRANSPARENCY

		if elapsed >= duration then
			local fade = math.min((elapsed - duration) / HANDOVER, 1)
			body.Transparency = 0.08 + 0.92 * fade
			-- The enemy brings its own shadow; this one hands over to it.
			shadow.Transparency = SHADOW_TRANSPARENCY + (1 - SHADOW_TRANSPARENCY) * fade
		end

		if elapsed >= duration + HANDOVER then
			if connection then
				connection:Disconnect()
			end
			body:Destroy()
			shadow:Destroy()
		end
	end)
end

return SplitFx
