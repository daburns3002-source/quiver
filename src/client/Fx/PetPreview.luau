--!strict
--[[
	Studio only (the P key, `DevKeys`): the pets the owner imported follow
	this player around, playing their own clips: Idle while the player
	stands, their Follow (or walk, trot, waddle, hop) while the player moves.
	A look at the pets in the game before Phase 6 builds the real pet system
	(eggs, equipping, saving: docs/ROADMAP.md). Nothing here is a system:
	the pets live on this client only and do nothing in a run.

	The server builds the models once (`Server/Dev/PetPreview`, from
	`Config/PetModels`); this clones them into the Workspace, scales them to
	pet size, tags them for `Fx/ModelAnimator`, and walks them after the
	player in rows behind it.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local PetPreview = {}

--[[ How tall a pet stands, in studs. ]]
local PET_HEIGHT = 2.4
--[[ Pets per row behind the player, the gap between them, and how far
     behind the player the first row walks. ]]
local PER_ROW = 4
local SPACING = 2.8
local BEHIND = 4
--[[ How quickly a pet closes on its place (per second), and the speed
     over which it counts as walking. ]]
local FOLLOW_RATE = 6
local WALKING = 1.5
--[[ The importer turns a model to face +Z; Roblox looks down -Z. ]]
local FACING = CFrame.Angles(0, math.pi, 0)
--[[ How long to wait for the server's pets to replicate, in seconds. ]]
local REPLICATION_WAIT = 20
--[[ Clip names that read as walking, best first. ]]
local MOVE_CLIPS = { "Follow", "Walk", "Trot", "Waddle", "Hop" }

type Pet = { model: Model, lift: number, idle: string?, move: string?, last: Vector3 }

local pets: { Pet } = {}
local holder: Folder? = nil
local stepping: RBXScriptConnection? = nil

local function clipNames(key: string): (string?, string?)
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("ModelClips")
	local module = folder and folder:FindFirstChild(key)
	if not module or not module:IsA("ModuleScript") then
		return nil, nil
	end
	local data = (require :: any)(module)
	local names = {}
	for name in data.clips do
		table.insert(names, name)
	end
	table.sort(names)
	local idle = if data.clips.Idle then "Idle" else names[1]
	local move = idle
	for _, name in MOVE_CLIPS do
		if data.clips[name] then
			move = name
			break
		end
	end
	return idle, move
end

local function ground(at: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position.Y else at.Y - 3
end

--[[ Whether every pet the server built, and every part of each, has
     replicated: the folder arrives before its contents do. ]]
local function arrived(source: Instance): boolean
	local models = source:GetChildren()
	if #models ~= source:GetAttribute("Pets") then
		return false
	end
	for _, model in models do
		if #model:GetChildren() ~= model:GetAttribute("Parts") then
			return false
		end
	end
	return true
end

local function spawnAll(source: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "PetPreviewLocal"
	folder.Parent = Workspace
	holder = folder
	for _, template in source:GetChildren() do
		if not template:IsA("Model") then
			continue
		end
		local model = template:Clone()
		local _, size = model:GetBoundingBox()
		if size.Y > 0 then
			model:ScaleTo(model:GetScale() * PET_HEIGHT / size.Y)
		end
		local box, scaled = model:GetBoundingBox()
		local lift = model:GetPivot().Position.Y - (box.Position.Y - scaled.Y / 2)
		local key = model:GetAttribute("ModelClips")
		local idle, move = clipNames(if type(key) == "string" then key else model.Name)
		if idle then
			model:SetAttribute("ModelClip", idle)
		end
		model.Parent = folder
		CollectionService:AddTag(model, "ModelClips")
		table.insert(pets, {
			model = model,
			lift = lift,
			idle = idle,
			move = move,
			last = model:GetPivot().Position,
		})
	end
end

local function step(dt: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not holder then
		return
	end
	local ignore: { Instance } = { holder, character :: Instance }
	local base = root.CFrame
	local alpha = 1 - math.exp(-FOLLOW_RATE * dt)
	for i, pet in pets do
		local row = (i - 1) // PER_ROW
		local column = (i - 1) % PER_ROW - (PER_ROW - 1) / 2
		local place = base * Vector3.new(column * SPACING, 0, BEHIND + row * SPACING)
		local now = pet.model:GetPivot().Position
		local goal = Vector3.new(place.X, ground(place, ignore) + pet.lift, place.Z)
		local next = now:Lerp(goal, alpha)
		local moved = Vector3.new(next.X - pet.last.X, 0, next.Z - pet.last.Z)
		local speed = moved.Magnitude / math.max(dt, 1e-3)
		local facing = if moved.Magnitude > 1e-3
			then moved.Unit
			else base.LookVector * Vector3.new(1, 0, 1)
		if facing.Magnitude < 1e-3 then
			facing = Vector3.new(0, 0, -1)
		end
		pet.model:PivotTo(CFrame.lookAt(next, next + facing.Unit) * FACING)
		pet.last = next
		local clip = if speed > WALKING then pet.move else pet.idle
		if clip and pet.model:GetAttribute("ModelClip") ~= clip then
			pet.model:SetAttribute("ModelClip", clip)
		end
	end
end

--[[ Turns the preview on (asking the server to build the pets, once) or
     off. Returns whether it is now on. ]]
function PetPreview.toggle(): boolean
	if holder then
		if stepping then
			stepping:Disconnect()
			stepping = nil
		end
		holder:Destroy()
		holder = nil
		table.clear(pets)
		return false
	end
	Remotes.event(Remotes.DebugPetPreview):FireServer()
	local source = ReplicatedStorage:WaitForChild("PetPreview", 30)
	if not source then
		return false
	end
	local deadline = os.clock() + REPLICATION_WAIT
	while not arrived(source) and os.clock() < deadline do
		task.wait(0.1)
	end
	spawnAll(source)
	stepping = RunService.RenderStepped:Connect(step)
	return #pets > 0
end

return PetPreview
