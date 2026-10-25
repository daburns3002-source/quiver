--!strict
--[[
	The Broodmother's Web Walker (owner, 2026-10-25; concept sheet
	`assets/concepts/blocky/broodmother_web_walker_concept.png`), drawn
	from the server's three telegraphs:

	- `WheelTell`: the warning, from the first frame at full size: the
	  floor under the web in red tiles, and the spokes' arms on across the
	  floor to the walls, standing still where they will start; the web
	  itself (`FxBroodWebWheel`, the owner's Claude Design piece) unfolds
	  over her back;
	- `WheelSpin`: the arms and the web turn clockwise round her, one turn
	  every `period`, the angle worked out exactly as the server's
	  (`Shared/Util/WebWheel`), so the arm drawn is the arm that hits;
	- `WheelBreak`: the tiles go and the web snaps apart (`Web_Break`).

	The tiles are drawn in full on every device: they are the counterplay.
	Until the web piece is imported only the tiles show, which is the whole
	of the warning anyway.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossFx = require(script.Parent.BossFx)
local UpgradeFx = require(script.Parent.Upgrades.UpgradeFx)
local WebWheel = require(ReplicatedStorage.Shared.Util.WebWheel)

local BroodWheelFx = {}

--[[ Floor tiles: the web's are two studs square; an arm's are two studs
     along it and as wide as it is. ]]
local TILE = 2
local TILE_HEIGHT = 0.12
--[[ The piece's one ring (an octagon, as in the web reference's splat)
     crosses its spokes at 0.55 of their length (one unit): drawn so that
     ring sits on the web's edge, and the spokes past it are the arms. ]]
local PIECE_RING = 0.55
local FADE_IN = 0.35
local FADE_OUT = 0.3

local function spin(): Balance.BossSpin
	local config = (Balance.Enemies :: any).Broodmother :: Balance.EnemyConfig
	return (config.boss :: Balance.EnemyBoss).spin :: Balance.BossSpin
end

type Wheel = {
	holder: Folder,
	web: { BasePart },
	arms: { { part: BasePart, spoke: number, along: number } },
	piece: Model?,
	centre: Vector3,
	start: number,
	spec: WebWheel.Spec,
	shownAt: number,
	spinAt: number?,
	stoppedAt: number?,
	breakAt: number?,
	life: number,
}

local current: Wheel? = nil
local stepping: RBXScriptConnection? = nil

--[[ Half the room, from its floor (centred on the origin), so arms stop at
     the walls. ]]
local function roomHalf(): Vector2
	local arena = Workspace:FindFirstChild("Arena")
	local floor = arena and arena:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		return Vector2.new(floor.Size.X / 2, floor.Size.Z / 2)
	end
	return Vector2.new(math.huge, math.huge)
end

local function tile(parent: Instance, size: Vector3, colour: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = "WebWheel"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = colour
	part.Size = size
	part.Transparency = 1
	part.Parent = parent
	return part
end

--[[ The angle spoke one is at now: still before the spin, turning during
     it, held where it stopped once broken. ]]
local function angleNow(w: Wheel, now: number): number
	local spinAt = w.spinAt
	if not spinAt then
		return w.start
	end
	local upTo = w.stoppedAt or now
	return WebWheel.angle(w.start, w.spec.period, upTo - spinAt)
end

local function placeArms(w: Wheel, angle: number)
	local half = roomHalf()
	for _, arm in w.arms do
		local along = WebWheel.spoke(angle, arm.spoke, w.spec.spokes)
		local at = w.centre + along * arm.along
		local inside = math.abs(at.X) <= half.X and math.abs(at.Z) <= half.Y
		arm.part.CFrame = CFrame.lookAt(
			Vector3.new(at.X, TILE_HEIGHT / 2 + 0.05, at.Z),
			Vector3.new(at.X + along.X, TILE_HEIGHT / 2 + 0.05, at.Z + along.Z)
		)
		arm.part:SetAttribute("Inside", inside)
	end
end

local function finish(w: Wheel)
	w.holder:Destroy()
	UpgradeFx.stop(w.piece)
	if current == w then
		current = nil
	end
end

local function step()
	local w = current
	if not w then
		if stepping then
			stepping:Disconnect()
			stepping = nil
		end
		return
	end
	local now = os.clock()
	if now > w.life or not w.holder.Parent then
		finish(w)
		return
	end

	local colour = Balance.Telegraph.bossColor
	local webAlpha, armAlpha
	local breakAt = w.breakAt
	if breakAt then
		local f = math.min(1, (now - breakAt) / FADE_OUT)
		webAlpha, armAlpha = 0.5 + 0.5 * f, 0.25 + 0.75 * f
	elseif w.spinAt then
		webAlpha, armAlpha = 0.5, 0.1
	else
		--[[ The warning: fading in, then pulsing. ]]
		local fade = math.min(1, (now - w.shownAt) / FADE_IN)
		local beat = 0.5 + 0.5 * math.sin((now - w.shownAt) * 6 * math.pi)
		webAlpha = 1 - fade * (0.35 + 0.15 * beat)
		armAlpha = 1 - fade * (0.6 + 0.2 * beat)
	end
	for _, part in w.web do
		part.Color = colour
		part.Transparency = webAlpha
	end
	placeArms(w, angleNow(w, now))
	for _, arm in w.arms do
		arm.part.Color = colour
		arm.part.Transparency = if arm.part:GetAttribute("Inside") then armAlpha else 1
	end
end

--[[ The web's warning: tiles under the web and along each arm, and the
     piece unfolding over her. `radius` and `reach` are the web's and the
     arms' (the server's `spin`). ]]
function BroodWheelFx.tell(
	parent: Instance,
	origin: Vector3,
	direction: Vector3,
	duration: number,
	radius: number,
	reach: number
)
	local old = current
	if old then
		finish(old)
	end
	local s = spin()
	local holder = Instance.new("Folder")
	holder.Name = "WebWalker"
	holder.Parent = parent
	local centre = Vector3.new(origin.X, 0, origin.Z)
	local half = roomHalf()

	local web: { BasePart } = {}
	for _, cell in BossFx.discCells(radius, TILE) do
		local x, z = centre.X + cell.x, centre.Z + cell.z
		if math.abs(x) > half.X or math.abs(z) > half.Y then
			continue
		end
		local part = tile(
			holder,
			Vector3.new(TILE * 0.92, TILE_HEIGHT, TILE * 0.92),
			Balance.Telegraph.bossColor
		)
		part.Position = Vector3.new(x, TILE_HEIGHT / 2 + 0.04, z)
		table.insert(web, part)
	end

	local arms = {}
	for k = 1, s.spokes do
		local along = radius + TILE / 2
		while along < reach do
			local part = tile(
				holder,
				Vector3.new(s.width, TILE_HEIGHT, TILE * 0.92),
				Balance.Telegraph.bossColor
			)
			table.insert(arms, { part = part, spoke = k, along = along })
			along += TILE
		end
	end

	local now = os.clock()
	local made: Wheel = {
		holder = holder,
		web = web,
		arms = arms,
		piece = nil,
		centre = centre,
		start = WebWheel.angleOf(direction),
		spec = {
			spokes = s.spokes,
			radius = radius,
			reach = reach,
			width = s.width,
			period = s.period,
		},
		shownAt = now,
		spinAt = nil,
		stoppedAt = nil,
		breakAt = nil,
		life = now + duration + s.spin + s.broken + 1,
	}
	current = made

	if UpgradeFx.ready("FxBroodWebWheel") then
		local lift = Vector3.new(0, s.height, 0)
		made.piece = UpgradeFx.play("FxBroodWebWheel", {
			at = CFrame.new(centre + lift),
			life = math.huge,
			scale = radius / PIECE_RING,
			clip = "Web_Unfold",
			span = duration,
			motion = function(model: Model)
				--[[ The piece's spoke one lies along its +Z: turned so it
				     lies along the server's spoke one. ]]
				local turn = math.pi / 2 - angleNow(made, os.clock())
				model:PivotTo(CFrame.new(centre + lift) * CFrame.Angles(0, turn, 0))
			end,
		})
	end

	placeArms(made, made.start)
	if not stepping then
		stepping = RunService.Heartbeat:Connect(step)
	end
end

--[[ The web starts to turn. ]]
function BroodWheelFx.spin(direction: Vector3, duration: number)
	local w = current
	if not w then
		return
	end
	local now = os.clock()
	w.start = WebWheel.angleOf(direction)
	w.spinAt = now
	w.life = now + duration + spin().broken + 1
end

--[[ The web snaps: the tiles go, the piece breaks apart where it stopped. ]]
function BroodWheelFx.snap(direction: Vector3, duration: number)
	local w = current
	if not w then
		return
	end
	local now = os.clock()
	w.stoppedAt = now
	w.breakAt = now
	if w.spinAt then
		--[[ Held exactly where the server says it stopped. ]]
		w.start = WebWheel.angleOf(direction)
		w.spinAt = now
	end
	UpgradeFx.clip(w.piece, "Web_Break")
	w.life = now + math.max(duration, FADE_OUT)
end

return BroodWheelFx
