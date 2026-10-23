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
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
	burst(from, parent)

	local split = Balance.Split
	local flight = math.min(split.flight, duration)
	local diameter = math.max(radius, 0.5) * 2 * 0.8

	local start = Vector3.new(from.X, LAUNCH_HEIGHT, from.Z)
	local finish = Vector3.new(to.X, diameter / 2, to.Z)
	local body = blob("SplitPiece", JELLY, parent)
	body.Transparency = 0.08
	body.Size = Vector3.one * diameter * 0.5

	local began = os.clock()
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

		if elapsed >= duration then
			body.Transparency = 0.08 + 0.92 * math.min((elapsed - duration) / HANDOVER, 1)
		end

		if elapsed >= duration + HANDOVER then
			if connection then
				connection:Disconnect()
			end
			body:Destroy()
		end
	end)
end

return SplitFx
