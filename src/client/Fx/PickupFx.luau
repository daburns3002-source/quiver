--!strict
--[[
	XP crystals and hearts on the floor (docs/ART-archero2.md §4).

	Crystals are small cyan faceted gems that pop out of a kill, lie bobbing
	where they land, and fly into their owner when walked over or, for any
	left, when the fight clears.
	Hearts are fat red hearts tilted to face the camera, waiting until someone
	walks over them.

	Presentation only. The server decides what drops, where, and who took it;
	this draws what it is told. A pickup the client never heard about is
	simply not drawn, and nothing here can take one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)

local PickupFx = {}

type Visual = {
	model: Model,
	kind: string,
	--[[ Where it rests, and where it was thrown from. ]]
	rest: Vector3,
	from: Vector3,
	bornAt: number,
	--[[ Set when taken: who it flies to, from where, and since when. ]]
	collector: Player?,
	takenFrom: Vector3?,
	takenAt: number?,
	phase: number,
}

--[[ Seconds a drop takes to arc from the body to where it lands. ]]
local POP_TIME = 0.35
local POP_HEIGHT = 2.2
local BOB_HEIGHT = 0.18
local BOB_SPEED = 3
local CRYSTAL_SPIN = math.rad(90)
--[[ Hearts are built a unit across and drawn this much larger. ]]
local HEART_SCALE = 1.25
--[[ Hearts lean back to face the camera, which looks down at this pitch. ]]
local HEART_TILT = math.rad(Balance.Camera.pitch)

local folder: Folder? = nil
local connection: RBXScriptConnection? = nil
local visuals: { [number]: Visual } = {}

local function part(parent: Instance, shape: Enum.PartType, size: Vector3, colour: Color3): Part
	local created = Instance.new("Part")
	created.Shape = shape
	created.Size = size
	created.Color = colour
	created.Material = Enum.Material.SmoothPlastic
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	created:SetAttribute("BaseSize", size)
	created.Parent = parent
	return created
end

--[[ Parts carry their offset from the pickup's centre as an attribute, so
     placing a pickup is one pass of CFrames. ]]
local function offset(target: BasePart, cframe: CFrame)
	target:SetAttribute("Offset", cframe)
end

local function buildCrystal(): Model
	local model = Instance.new("Model")
	model.Name = "Crystal"
	local colour = Balance.Pickups.crystalColor

	--[[ A cube stood on its corner reads as a cut gem from above. ]]
	local gem = part(model, Enum.PartType.Block, Vector3.new(0.55, 0.55, 0.55), colour)
	gem.Material = Enum.Material.Glass
	gem.Reflectance = 0.2
	offset(gem, CFrame.Angles(math.rad(45), 0, math.rad(35)))

	local glow = part(model, Enum.PartType.Block, Vector3.new(0.75, 0.75, 0.75), colour)
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.7
	offset(glow, CFrame.Angles(math.rad(45), 0, math.rad(35)))

	model.Parent = folder
	return model
end

local function buildHeart(): Model
	local model = Instance.new("Model")
	model.Name = "Heart"
	local colour = Balance.Pickups.heartColor

	--[[ Two lobes over a diamond, in the heart's own plane (X across, Y up),
	     with a white shine on the left lobe. ]]
	local left = part(model, Enum.PartType.Ball, Vector3.one, colour)
	offset(left, CFrame.new(-0.29, 0.14, 0))
	local right = part(model, Enum.PartType.Ball, Vector3.one, colour)
	offset(right, CFrame.new(0.29, 0.14, 0))
	local point = part(model, Enum.PartType.Block, Vector3.new(0.9, 0.9, 0.66), colour)
	offset(point, CFrame.new(0, -0.17, 0) * CFrame.Angles(0, 0, math.rad(45)))

	local shine = part(model, Enum.PartType.Ball, Vector3.one * 0.2, Color3.new(1, 1, 1))
	shine.Material = Enum.Material.Neon
	offset(shine, CFrame.new(-0.42, 0.34, 0.38))

	--[[ A soft disc behind it, in its plane: a cylinder turned to face out. ]]
	local glow = part(model, Enum.PartType.Cylinder, Vector3.new(0.1, 1.7, 1.7), colour)
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.86
	offset(glow, CFrame.new(0, 0, -0.45) * CFrame.Angles(0, math.rad(90), 0))

	model:SetAttribute("Scale", HEART_SCALE)
	model.Parent = folder
	return model
end

--[[ Sizes and offsets both scale, so a pickup shrinks as a whole. ]]
local function place(visual: Visual, centre: Vector3, turn: CFrame, shrink: number)
	local built = visual.model:GetAttribute("Scale")
	local scale = shrink * (if type(built) == "number" then built else 1)

	for _, child in visual.model:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end

		local relative = child:GetAttribute("Offset")
		local size = child:GetAttribute("BaseSize")
		if typeof(relative) == "CFrame" then
			local scaled = relative - relative.Position + relative.Position * scale
			child.CFrame = CFrame.new(centre) * turn * scaled
		end
		if typeof(size) == "Vector3" then
			child.Size = size * scale
		end
	end
end

local function collectorPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function step()
	local now = os.clock()
	local flight = Balance.Pickups.collectFlight

	for id, visual in visuals do
		local centre: Vector3
		local scale = 1

		local takenAt = visual.takenAt
		if takenAt then
			local alpha = math.clamp((now - takenAt) / flight, 0, 1)
			local target = (visual.collector and collectorPosition(visual.collector))
				or visual.takenFrom
				or visual.rest
			local start = visual.takenFrom or visual.rest
			--[[ Eased in, so it lifts off slowly and snaps into the player. ]]
			local eased = alpha * alpha
			centre = start:Lerp(target, eased) + Vector3.new(0, math.sin(alpha * math.pi) * 1.5, 0)
			scale = 1 - 0.6 * eased

			if alpha >= 1 then
				visual.model:Destroy()
				visuals[id] = nil
				continue
			end
		else
			local age = now - visual.bornAt
			if age < POP_TIME then
				local alpha = age / POP_TIME
				centre = visual.from:Lerp(visual.rest, alpha)
					+ Vector3.new(0, math.sin(alpha * math.pi) * POP_HEIGHT, 0)
			else
				centre = visual.rest
					+ Vector3.new(0, BOB_HEIGHT * (1 + math.sin(now * BOB_SPEED + visual.phase)), 0)
			end
		end

		local turn = if visual.kind == "Heart"
			then CFrame.Angles(0, math.sin(now * 1.6 + visual.phase) * math.rad(10), 0) * CFrame.Angles(
				-HEART_TILT,
				0,
				0
			)
			else CFrame.Angles(0, now * CRYSTAL_SPIN + visual.phase, 0)

		place(visual, centre, turn, scale)
	end
end

function PickupFx.onDropped(id: number, kind: string, rest: Vector3, from: Vector3)
	if visuals[id] then
		return
	end

	local model = if kind == "Heart" then buildHeart() else buildCrystal()
	visuals[id] = {
		model = model,
		kind = kind,
		rest = rest,
		from = Vector3.new(from.X, rest.Y, from.Z),
		bornAt = os.clock(),
		collector = nil,
		takenFrom = nil,
		takenAt = nil,
		phase = (id * 1.7) % (2 * math.pi),
	}
end

function PickupFx.onTaken(ids: { number }, collector: Player)
	local now = os.clock()

	for _, id in ids do
		local visual = visuals[id]
		if visual and not visual.takenAt then
			--[[ From wherever it is drawn now, mid-bob or mid-pop. ]]
			local primary = visual.model:FindFirstChildWhichIsA("BasePart")
			visual.takenFrom = if primary then primary.Position else visual.rest
			visual.takenAt = now
			visual.collector = collector
		end
	end
end

function PickupFx.onCleared()
	for _, visual in visuals do
		visual.model:Destroy()
	end
	table.clear(visuals)
end

function PickupFx.start(parent: Instance)
	local existing = parent:FindFirstChild("Pickups")
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = "Pickups"
	created.Parent = parent
	folder = created
	table.clear(visuals)

	if connection then
		connection:Disconnect()
	end
	connection = RunService.RenderStepped:Connect(step)
end

--[[ Used by the local player's own count, for probes. ]]
function PickupFx.count(): number
	local total = 0
	for _ in visuals do
		total += 1
	end
	return total
end

return PickupFx
