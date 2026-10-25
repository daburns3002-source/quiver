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

	In a run the server's pet attacks (`Combat/PetCombat`) play here too. A
	pet that dashes (the Glade Fox) runs the server's plan
	(`Shared/Util/PetDash`): to each enemy round the cover, landing as its
	blow does, and back to its place, its Attack clip posed to the run and
	the clip's own lunge taken out so the fox is where the plan says.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ModelClip = require(ReplicatedStorage.Shared.Util.ModelClip)
local PetAttackFx = require(script.Parent.PetAttackFx)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetDash = require(ReplicatedStorage.Shared.Util.PetDash)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local PetAura = require(script.Parent.PetAura)

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
--[[ How long to wait for the server's pets to replicate, in seconds. ]]
local REPLICATION_WAIT = 20
--[[ Clip names that read as walking, best first. ]]
local MOVE_CLIPS = { "Follow", "Walk", "Trot", "Waddle", "Hop" }

--[[ A dash under way: the server's plan, the server time it started, the
     enemies it runs to, where the fox stood as it began, and which way it
     faces. ]]
type Dash = {
	plan: PetDash.Plan,
	at: number,
	targets: { Model },
	--[[ Per stop, how far the enemy has moved since it was planned (the
	     fox lands beside it where it is now). ]]
	moved: { Vector3 },
	from: Vector3,
	facing: Vector3,
}

type Pet = {
	model: Model,
	lift: number,
	idle: string?,
	move: string?,
	last: Vector3,
	--[[ The length of its Attack clip (`docs/PETS-FOREST.md`, Attacks), when
	     it has one, and the clock time an Attack under way ends. ]]
	attack: number?,
	actingUntil: number,
	--[[ Its clip data and how the import placed it, for taking its Attack
	     clip's own lunge out of a dash. ]]
	data: ModelClip.Model?,
	fit: ModelClip.Fit?,
	dash: Dash?,
}

local pets: { Pet } = {}
local holder: Folder? = nil
local stepping: RBXScriptConnection? = nil

local function clipData(key: string): ModelClip.Model?
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("ModelClips")
	local module = folder and folder:FindFirstChild(key)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	return (require :: any)(module)
end

--[[ How the import placed `model` against its clip data, read off its
     parts at rest, as `Fx/ModelAnimator` reads it. ]]
local function fitOf(model: Model, data: ModelClip.Model): ModelClip.Fit?
	local pivot = model:GetPivot()
	local observed: { [string]: { position: Vector3, size: Vector3 } } = {}
	local seen: { [string]: number } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and data.parts[d.Name] then
			seen[d.Name] = (seen[d.Name] or 0) + 1
			observed[d.Name] = { position = pivot:ToObjectSpace(d.CFrame).Position, size = d.Size }
		end
	end
	for name, n in seen do
		if n > 1 then
			observed[name] = nil
		end
	end
	return ModelClip.fit(data, observed)
end

--[[ How far the Attack clip's own lunge has carried the pet from its
     pivot `time` seconds in, on the floor, in the pivot's space. ]]
local function lungeOf(pet: Pet, clip: PetDash.Clip, time: number): Vector3
	local data, fit = pet.data, pet.fit
	local attack = data and data.clips[clip.name]
	if not data or not fit or not attack then
		return Vector3.zero
	end
	local now = ModelClip.pose(data, attack, time)[clip.root]
	local rest = ModelClip.pose(data, nil, 0)[clip.root]
	if not now or not rest then
		return Vector3.zero
	end
	local moved = fit.turn:VectorToWorldSpace(now.t - rest.t) * fit.scale
	return Vector3.new(moved.X, 0, moved.Z)
end

--[[ The pet's idle and moving clips, and its Attack clip's length. ]]
local function clipNames(key: string): (string?, string?, number?)
	local data = clipData(key)
	if not data then
		return nil, nil, nil
	end
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
	return idle, move, if data.clips.Attack then data.clips.Attack.length else nil
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

--[[ Clones the server's pets into the Workspace: all of them, or only
     the one named `only`. ]]
local function spawnAll(source: Instance, only: string?)
	local folder = Instance.new("Folder")
	folder.Name = "PetPreviewLocal"
	folder.Parent = Workspace
	holder = folder
	for _, template in source:GetChildren() do
		if not template:IsA("Model") or (only and template.Name ~= only) then
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
		local dataKey = if type(key) == "string" then key else model.Name
		local idle, move, attack = clipNames(dataKey)
		local data = clipData(dataKey)
		if idle then
			model:SetAttribute("ModelClip", idle)
		end
		model.Parent = folder
		CollectionService:AddTag(model, "ModelClips")
		-- a Mythic or Legendary pet glows, sparkles and trails (`Config/PetAuras`)
		PetAura.wear(model, template.Name)
		table.insert(pets, {
			model = model,
			lift = lift,
			idle = idle,
			move = move,
			last = model:GetPivot().Position,
			attack = attack,
			actingUntil = 0,
			data = data,
			-- read before the animator moves anything
			fit = if data then fitOf(model, data) else nil,
			dash = nil,
		})
	end
end

--[[ Where a dashing pet is drawn, or nil once its dash is over: the plan's
     place, carried along with the enemies it runs to as they move, and
     ending at `home`, the place it follows its owner at. ]]
local function dashPose(pet: Pet, dash: Dash, home: Vector3): CFrame?
	local spec = PetCombat.pets[pet.model.Name]
	local settings = spec and spec.dash
	local t = Workspace:GetServerTimeNow() - dash.at
	local plan = dash.plan
	if not settings or t >= plan.length then
		return nil
	end
	local stops = plan.stops
	for i, target in dash.targets do
		local aim = stops[i] and stops[i].aim
		if aim and target.Parent then
			local p = target:GetPivot().Position
			dash.moved[i] = Vector3.new(p.X - aim.X, 0, p.Z - aim.Z)
		end
	end
	local last = stops[#stops]
	local planned = if last and #last.route > 0 then last.route[#last.route] else plan.start
	local function offset(stop: number): Vector3
		if stop <= 0 then
			return dash.from - plan.start
		elseif stop >= #stops then
			return Vector3.new(home.X - planned.X, 0, home.Z - planned.Z)
		end
		return dash.moved[stop] or Vector3.zero
	end
	local place, heading, stop, u = PetDash.at(plan, t)
	place += offset(stop - 1):Lerp(offset(stop), u)
	local struck = stops[stop - 1]
	local target = if struck and struck.aim then dash.targets[stop - 1] else nil
	if u <= 0 and target and target.Parent then
		-- slashing: facing the enemy it struck
		local toward = target:GetPivot().Position - place
		toward = Vector3.new(toward.X, 0, toward.Z)
		if toward.Magnitude > 1e-3 then
			heading = toward.Unit
		end
	end
	if heading then
		dash.facing = heading
	end
	local clip = settings.clip
	local time = PetDash.clipTime(plan, t, clip)
	-- the clip held on the plan's frame
	pet.model:SetAttribute("ModelClip", clip.name)
	pet.model:SetAttribute("ModelClipAt", Workspace:GetServerTimeNow() - time)
	local floor = Vector3.new(place.X, home.Y, place.Z)
	return CFrame.lookAt(floor, floor + dash.facing) * CFrame.new(-lungeOf(pet, clip, time))
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
		local dash = pet.dash
		if dash then
			local posed = dashPose(pet, dash, goal)
			if posed then
				pet.model:PivotTo(posed)
				pet.last = posed.Position
				continue
			end
			pet.dash = nil
			pet.model:SetAttribute("ModelClipAt", nil)
			pet.actingUntil = 0
		end
		local next = now:Lerp(goal, alpha)
		local moved = Vector3.new(next.X - pet.last.X, 0, next.Z - pet.last.Z)
		local speed = moved.Magnitude / math.max(dt, 1e-3)
		local facing = if moved.Magnitude > 1e-3
			then moved.Unit
			else base.LookVector * Vector3.new(1, 0, 1)
		if facing.Magnitude < 1e-3 then
			facing = Vector3.new(0, 0, -1)
		end
		-- Config/PetModels is already in Roblox's frame: the pet's front is its
		-- pivot's look vector
		pet.model:PivotTo(CFrame.lookAt(next, next + facing.Unit))
		pet.last = next
		local clip = if speed > WALKING then pet.move else pet.idle
		-- an Attack plays through, walking or not
		if os.clock() < pet.actingUntil then
			clip = nil
		end
		if clip and pet.model:GetAttribute("ModelClip") ~= clip then
			pet.model:SetAttribute("ModelClip", clip)
		end
	end
end

local function putAway()
	if stepping then
		stepping:Disconnect()
		stepping = nil
	end
	if holder then
		holder:Destroy()
		holder = nil
	end
	table.clear(pets)
end

--[[ The server's pets, asking it to build them (once) and waiting until
     every part has arrived; nil if they never come. ]]
local function source(): Instance?
	Remotes.event(Remotes.DebugPetPreview):FireServer()
	local folder = ReplicatedStorage:WaitForChild("PetPreview", 30)
	if not folder then
		return nil
	end
	local deadline = os.clock() + REPLICATION_WAIT
	while not arrived(folder) and os.clock() < deadline do
		task.wait(0.1)
	end
	return folder
end

--[[ Turns the preview of every pet on or off. Returns whether it is now on. ]]
function PetPreview.toggle(): boolean
	if holder then
		putAway()
		return false
	end
	local folder = source()
	if not folder then
		return false
	end
	spawnAll(folder)
	stepping = RunService.RenderStepped:Connect(step)
	return #pets > 0
end

--[[ One pet at heel (a `Config/PetModels` key, as the sandbox menu picks
     it), in place of any already out, or none for nil. Returns whether a
     pet is now out. ]]
function PetPreview.show(key: string?): boolean
	putAway()
	if not key then
		return false
	end
	local folder = source()
	if not folder then
		return false
	end
	spawnAll(folder, key)
	stepping = RunService.RenderStepped:Connect(step)
	return #pets > 0
end

--[[ The pet named `key` runs the server's dash (`Combat/PetCombat`): to
     each of `targets` and back, its slash and sound as each blow lands. ]]
local function runDash(key: string, plan: PetDash.Plan, at: number, targets: { Model })
	for _, pet in pets do
		if pet.model.Name ~= key then
			continue
		end
		local p = pet.model:GetPivot().Position
		pet.dash = {
			plan = plan,
			at = at,
			targets = targets,
			moved = {},
			from = Vector3.new(p.X, 0, p.Z),
			facing = pet.model:GetPivot().LookVector,
		}
		pet.actingUntil = math.huge
		local late = Workspace:GetServerTimeNow() - at
		for i, arrive in PetDash.hits(plan) do
			task.delay(math.max(0, arrive - late), function()
				local running = pet.dash
				if running and running.plan == plan then
					PetAttackFx.strike(pet.model, key, targets[i])
				end
			end)
		end
	end
end

--[[ Every pet out plays its Attack clip once (the sandbox's ATTACK
     button), with its projectiles and effects (`Fx/PetAttackFx`), then goes
     back to idling or following. Returns how many did. ]]
function PetPreview.attack(): number
	local count = 0
	for _, pet in pets do
		local length = pet.attack
		if length then
			-- set afresh, so a second press restarts it
			pet.model:SetAttribute("ModelClip", nil)
			pet.model:SetAttribute("ModelClip", "Attack")
			pet.actingUntil = os.clock() + length
			-- and what it throws (`Config/PetAttacks`)
			PetAttackFx.play(pet.model, pet.model.Name)
			count += 1
		end
	end
	return count
end

--[[ The pet keys the preview can show: `Config/PetModels`, sorted. ]]
function PetPreview.keys(): { string }
	local out: { string } = {}
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("PetModels")
	if folder then
		for _, module in folder:GetChildren() do
			if module:IsA("ModuleScript") then
				table.insert(out, module.Name)
			end
		end
	end
	table.sort(out)
	return out
end

--[[ The server's pet attacked (`Combat/PetCombat`): this player's pet
     plays its Attack and pieces, as the sandbox's button does, or runs the
     dash the server planned. ]]
Remotes.event(Remotes.PetAttack).OnClientEvent
	:Connect(function(owner: Player, key: string, dash: any)
		if owner ~= Players.LocalPlayer then
			return
		end
		if type(dash) == "table" and type(dash.plan) == "table" then
			runDash(key, dash.plan, dash.at, dash.targets or {})
		else
			PetPreview.attack()
		end
	end)

return PetPreview
