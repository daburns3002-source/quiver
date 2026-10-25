--!strict
--[[
	XP crystals and hearts on the floor (docs/ART-archero2.md §4).

	Crystals are small cyan faceted gems that pop out of a kill, lie bobbing
	where they land, and fly into their owner when walked over or, for any
	left, when the fight clears.
	Hearts are blocky pixel hearts in the game's voxel style (owner,
	2026-10-24): they pop out of the body, bounce once in a random direction,
	and stand upright on the floor spinning on the spot until someone walks
	over them.

	Presentation only. The server decides what drops, where, and who took it;
	this draws what it is told. A pickup the client never heard about is
	simply not drawn, and nothing here can take one.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local SoundFx = require(script.Parent.SoundFx)

local PickupFx = {}

type Visual = {
	model: Model,
	kind: string,
	--[[ Hearts: where the first arc lands, before the hop to `rest`. ]]
	bounce: Vector3?,
	--[[ Where it rests, and where it was thrown from. ]]
	rest: Vector3,
	from: Vector3,
	bornAt: number,
	--[[ Set when taken: who it flies to, from where, and since when. ]]
	collector: Player?,
	takenFrom: Vector3?,
	takenAt: number?,
	phase: number,
	--[[ Its parts with their offsets from its centre and their sizes at
	     scale 1 (the build's `Scale` folded in), read once when built;
	     `drawnScale` is the scale their sizes were last written at, so a
	     bobbing pickup only moves. ]]
	parts: { BasePart },
	offsets: { CFrame },
	sizes: { Vector3 },
	drawnScale: number,
}

--[[ Seconds a drop takes to arc from the body to where it lands. ]]
local POP_TIME = 0.35
local POP_HEIGHT = 2.2
local BOB_HEIGHT = 0.18
local BOB_SPEED = 3
local CRYSTAL_SPIN = math.rad(90)
--[[ Hearts are built a unit across and drawn this much larger. ]]
local HEART_SCALE = 2.2
--[[ A landed heart's turn about the vertical, radians a second. ]]
local HEART_SPIN = math.rad(150)
--[[ A heart's bounce after it first lands: the hop's length, height and
     time. The hop ends where the server put the heart, so it lands first a
     hop away from there, in a direction of its own. ]]
local HEART_HOP = 1.6
local HEART_HOP_HEIGHT = 0.9
local HEART_HOP_TIME = 0.25
--[[ A heart stands on the floor: its middle this far above where the server
     rests pickups (0.6), so its point touches the ground. ]]
local HEART_LIFT = 0.35
--[[ The pixel heart, top row first: each row's runs of pixels, as
     { first column, last column } in a 7 by 6 grid. Built as one bar per
     run, so a heart is seven parts, not twenty-seven cubes. ]]
local HEART_ROWS = {
	{ { 2, 3 }, { 5, 6 } },
	{ { 1, 7 } },
	{ { 1, 7 } },
	{ { 2, 6 } },
	{ { 3, 5 } },
	{ { 4, 4 } },
}
local HEART_PIXEL = 1 / 7
--[[ Pixels deep: a heart one pixel deep all but vanished edge-on as it
     spun, under a camera looking steeply down; four, "a little thicker"
     than three (owner, 2026-10-24). ]]
local HEART_DEPTH = 4

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
	local px = HEART_PIXEL
	local rows = #HEART_ROWS

	--[[ Each run of pixels one block, a pixel deep, centred on the grid's
	     middle in the heart's own plane (X across, Y up). ]]
	for row, runs in HEART_ROWS do
		local y = ((rows + 1) / 2 - row) * px
		for _, run in runs do
			local first, last = run[1], run[2]
			local bar = part(
				model,
				Enum.PartType.Block,
				Vector3.new((last - first + 1) * px, px, px * HEART_DEPTH),
				colour
			)
			offset(bar, CFrame.new(((first + last) / 2 - 4) * px, y, 0))
		end
	end

	--[[ The pixel shine, top left, on both faces so it shows as it turns. ]]
	for _, side in { 1, -1 } do
		local shine =
			part(model, Enum.PartType.Block, Vector3.new(px, px, px * 0.2), Color3.new(1, 1, 1))
		offset(
			shine,
			CFrame.new(-2 * px, ((rows + 1) / 2 - 2) * px, side * px * (HEART_DEPTH / 2 + 0.05))
		)
	end

	model:SetAttribute("Scale", HEART_SCALE)
	model.Parent = folder
	return model
end

--[[ Every pickup's moves this frame, handed to the engine in one
     `BulkMoveTo`; reused, so a frame allocates no lists. ]]
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}
local moveCount = 0

--[[ Reads a built pickup's parts once: their offsets and sizes, at the
     build's own `Scale`. ]]
local function partsOf(model: Model): ({ BasePart }, { CFrame }, { Vector3 })
	local built = model:GetAttribute("Scale")
	local scale = if type(built) == "number" then built else 1
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local sizes: { Vector3 } = {}
	for _, child in model:GetChildren() do
		local relative = child:GetAttribute("Offset")
		local size = child:GetAttribute("BaseSize")
		if child:IsA("BasePart") and typeof(relative) == "CFrame" and typeof(size) == "Vector3" then
			table.insert(parts, child)
			table.insert(offsets, relative - relative.Position + relative.Position * scale)
			table.insert(sizes, size * scale)
		end
	end
	return parts, offsets, sizes
end

--[[ Sizes and offsets both scale, so a pickup shrinks as a whole. ]]
local function place(visual: Visual, centre: Vector3, turn: CFrame, scale: number)
	local frame = CFrame.new(centre) * turn
	local resize = scale ~= visual.drawnScale
	visual.drawnScale = scale
	for i, child in visual.parts do
		local relative = visual.offsets[i]
		moveCount += 1
		moveParts[moveCount] = child
		moveFrames[moveCount] = if scale == 1
			then frame * relative
			else frame * (relative - relative.Position + relative.Position * scale)
		if resize then
			child.Size = visual.sizes[i] * scale
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
			local bounce = visual.bounce
			if age < POP_TIME then
				local alpha = age / POP_TIME
				centre = visual.from:Lerp(bounce or visual.rest, alpha)
					+ Vector3.new(0, math.sin(alpha * math.pi) * POP_HEIGHT, 0)
			elseif bounce and age < POP_TIME + HEART_HOP_TIME then
				local alpha = (age - POP_TIME) / HEART_HOP_TIME
				centre = bounce:Lerp(visual.rest, alpha)
					+ Vector3.new(0, math.sin(alpha * math.pi) * HEART_HOP_HEIGHT, 0)
			else
				centre = visual.rest
					+ Vector3.new(0, BOB_HEIGHT * (1 + math.sin(now * BOB_SPEED + visual.phase)), 0)
			end
		end

		local turn
		if visual.kind == "Heart" then
			local landedFor = now - visual.bornAt - POP_TIME - HEART_HOP_TIME
			if landedFor < 0 or visual.takenAt then
				-- in flight: upright
				turn = CFrame.new()
			else
				-- landed: upright on the floor, spinning on the spot
				turn = CFrame.Angles(0, landedFor * HEART_SPIN, 0)
			end
			centre += Vector3.new(0, HEART_LIFT, 0)
		else
			turn = CFrame.Angles(0, now * CRYSTAL_SPIN + visual.phase, 0)
		end

		place(visual, centre, turn, scale)
	end

	if moveCount > 0 then
		for i = #moveParts, moveCount + 1, -1 do
			moveParts[i] = nil
			moveFrames[i] = nil
		end
		Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		moveCount = 0
	end
end

function PickupFx.onDropped(id: number, kind: string, rest: Vector3, from: Vector3)
	if visuals[id] then
		return
	end

	local model = if kind == "Heart" then buildHeart() else buildCrystal()
	local parts, offsets, sizes = partsOf(model)
	local bounce: Vector3? = nil
	if kind == "Heart" then
		local angle = Random.new(id):NextNumber() * 2 * math.pi
		bounce = rest - Vector3.new(math.cos(angle), 0, math.sin(angle)) * HEART_HOP
	end
	visuals[id] = {
		model = model,
		kind = kind,
		bounce = bounce,
		rest = rest,
		from = Vector3.new(from.X, rest.Y, from.Z),
		bornAt = os.clock(),
		collector = nil,
		takenFrom = nil,
		takenAt = nil,
		phase = (id * 1.7) % (2 * math.pi),
		parts = parts,
		offsets = offsets,
		sizes = sizes,
		-- sizes are written on the first frame
		drawnScale = -1,
	}
end

function PickupFx.onTaken(ids: { number }, collector: Player)
	local now = os.clock()
	local mine = collector == Players.LocalPlayer

	for _, id in ids do
		local visual = visuals[id]
		if visual and not visual.takenAt then
			if mine then
				SoundFx.play(if visual.kind == "Heart" then "heart_pickup" else "xp_pickup")
			end
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
