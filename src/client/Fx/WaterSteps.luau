--!strict
--[[
	Footsteps in shallow water (owner, 2026-11-05: "the footsteps in the
	shallow water need to be emphasized"): in a room whose floor is flood
	water (`ArenaModels.shallowWater`, stamped on the arena as the
	`ShallowWater` attribute by `Arena.build`), every stride of every
	player's character splashes. Each step throws a few blocky droplets up
	and out, flashes a white foam disc under the foot and sends two ripple
	rings out across the water, and the local player's own steps play
	one of `water_step_1..3` (silent until their sprite is uploaded).

	Drawn only here, on the client: nothing collides, answers a raycast or
	is seen by the server. Droplets are pooled and moved by one
	RenderStepped; rings are handle adornments on Terrain, tweened.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundFx = require(script.Parent.SoundFx)

local WaterSteps = {}

--[[ Studs walked between two steps. ]]
local STRIDE = 2.6
--[[ Slower than this (studs a second) is standing, not walking. ]]
local MOVING = 2
--[[ The water's top: the arena floor. ]]
local WATER_Y = 0.05

local FOAM = Color3.fromRGB(236, 255, 252)
local SPRAY =
	{ Color3.fromRGB(200, 250, 248), Color3.fromRGB(130, 228, 230), Color3.fromRGB(255, 255, 255) }

--[[ Each step's droplets: how many, how fast up and out, how long. ]]
local DROPS = 6
local DROP_UP = { 9, 14 }
local DROP_OUT = { 3, 6 }
local DROP_LIFE = 0.45
local GRAVITY = 44

--[[ The rings: from this radius to that over this long, two a step, the
     second a little behind and wider. ]]
local RING_FROM, RING_TO, RING_TIME = 0.5, 3.2, 0.7
local RING_WIDTH = 0.28

type Drop = { part: Part, velocity: Vector3, age: number }

local live: { Drop } = {}
local spare: { Part } = {}
local folder: Folder? = nil
local on = false
--[[ Each character's distance walked since its last step. ]]
local walked: { [Model]: number } = {}
local lastAt: { [Model]: Vector3 } = {}
local random = Random.new()

local function holder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "WaterSteps"
	made.Parent = Workspace
	folder = made
	return made
end

local function dropPart(): Part
	local part = table.remove(spare)
	if part then
		return part
	end
	local made = Instance.new("Part")
	made.Name = "Drop"
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.SmoothPlastic
	return made
end

local function ring(at: Vector3, delay: number, reach: number)
	local adorn = Instance.new("CylinderHandleAdornment")
	adorn.Adornee = Workspace.Terrain
	adorn.CFrame = CFrame.new(at) * CFrame.Angles(math.pi / 2, 0, 0)
	adorn.Height = 0.06
	adorn.Radius = RING_FROM + RING_WIDTH
	adorn.InnerRadius = RING_FROM
	adorn.Color3 = FOAM
	adorn.Transparency = 0.15
	adorn.ZIndex = 1
	adorn.Parent = holder()
	local info =
		TweenInfo.new(RING_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay)
	local tween = TweenService:Create(adorn, info, {
		Radius = reach + RING_WIDTH,
		InnerRadius = reach,
		Transparency = 1,
	})
	tween.Completed:Once(function()
		adorn:Destroy()
	end)
	tween:Play()
end

local function foam(at: Vector3)
	local adorn = Instance.new("CylinderHandleAdornment")
	adorn.Adornee = Workspace.Terrain
	adorn.CFrame = CFrame.new(at) * CFrame.Angles(math.pi / 2, 0, 0)
	adorn.Height = 0.05
	adorn.Radius = 0.9
	adorn.Color3 = FOAM
	adorn.Transparency = 0.1
	adorn.Parent = holder()
	local tween = TweenService:Create(adorn, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Radius = 1.6,
		Transparency = 1,
	})
	tween.Completed:Once(function()
		adorn:Destroy()
	end)
	tween:Play()
end

--[[ One step's splash, at the foot's place on the water. ]]
local function splash(at: Vector3, heading: Vector3)
	foam(at)
	ring(at, 0, RING_TO)
	ring(at, 0.12, RING_TO * 1.35)
	for _ = 1, DROPS do
		local angle = random:NextNumber() * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			* random:NextNumber(DROP_OUT[1], DROP_OUT[2])
		local part = dropPart()
		local s = random:NextNumber(0.22, 0.4)
		part.Size = Vector3.new(s, s, s)
		part.Color = SPRAY[random:NextInteger(1, #SPRAY)]
		part.Transparency = 0.05
		part.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0))
		part.Parent = holder()
		table.insert(live, {
			part = part,
			-- kicked a little the way the foot is going
			velocity = out
				+ heading * 2
				+ Vector3.new(0, random:NextNumber(DROP_UP[1], DROP_UP[2]), 0),
			age = 0,
		})
	end
end

local function stepDrops(dt: number)
	for i = #live, 1, -1 do
		local drop = live[i]
		drop.age += dt
		drop.velocity -= Vector3.new(0, GRAVITY * dt, 0)
		local at = drop.part.Position + drop.velocity * dt
		if drop.age >= DROP_LIFE or at.Y < WATER_Y then
			drop.part.Parent = nil
			table.insert(spare, drop.part)
			table.remove(live, i)
		else
			drop.part.CFrame = CFrame.new(at)
			drop.part.Transparency = math.clamp(drop.age / DROP_LIFE, 0, 1) ^ 2
		end
	end
end

local function stepFeet(dt: number)
	local me = Players.LocalPlayer
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and root and humanoid) or humanoid.Health <= 0 then
			continue
		end
		local flat = Vector3.new(root.Position.X, WATER_Y, root.Position.Z)
		local last = lastAt[character]
		lastAt[character] = flat
		if not last then
			continue
		end
		local moved = (flat - last).Magnitude
		--[[ A teleport or a new room is not a step. ]]
		if moved > 6 or dt <= 0 or moved / dt < MOVING then
			continue
		end
		if humanoid.FloorMaterial == Enum.Material.Air then
			continue
		end
		walked[character] = (walked[character] or 0) + moved
		if walked[character] >= STRIDE then
			walked[character] = 0
			local heading = (flat - last).Unit
			-- alternate feet, a little either side of the line walked
			local side = Vector3.new(-heading.Z, 0, heading.X)
				* (if random:NextNumber() < 0.5 then 0.45 else -0.45)
			splash(flat + side, heading)
			if player == me then
				SoundFx.play(`water_step_{random:NextInteger(1, 3)}`)
			end
		end
	end
end

local function step(dt: number)
	if on then
		stepFeet(dt)
	end
	if #live > 0 then
		stepDrops(dt)
	end
end

--[[ Follows the room's arena: on while its floor is shallow water. ]]
function WaterSteps.start()
	local current: Instance? = nil
	local function follow(arena: Instance?)
		current = arena
		on = arena ~= nil and arena:GetAttribute("ShallowWater") == true
		table.clear(walked)
		table.clear(lastAt)
	end
	local function watch(child: Instance)
		if child.Name == "Arena" and child:IsA("Folder") then
			follow(child)
			child:GetAttributeChangedSignal("ShallowWater"):Connect(function()
				if current == child then
					follow(child)
				end
			end)
			child.Destroying:Connect(function()
				if current == child then
					follow(nil)
				end
			end)
		end
	end
	for _, child in Workspace:GetChildren() do
		watch(child)
	end
	Workspace.ChildAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			walked[character] = nil
			lastAt[character] = nil
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return WaterSteps
