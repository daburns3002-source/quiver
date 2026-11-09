--!strict
--[[
	A blade's swing, drawn as exactly the shape it hits (owner, 2026-10-23:
	"the red on the swing should be exactly the hitbox of the sword", then
	an arc for the side-to-side blows and a circle for the slam).

	The same red ribbon as before (`Config/Weapons.swingTrail` colours), but
	its two ends no longer ride the blade, whose arc paints wherever the
	animation happens to swing. They are swept over the swing's box by
	`Shared/Combat/SwingSweep`, between a slash's `TrailOn` and `TrailOff`
	markers (`Fx/WeaponPose`), so the red ends up covering exactly the
	ground the server checks (`Combat/MeleeSystem`, `Shared/Combat/SwingBox`):
	the class's `swing` shape, grown by Cleave and Long Reach.

	Drawn low over the floor, from where the swinger stood when the slash
	began, facing the way it faced. Presentation only, and local: other
	players see the sword swing without it.

	Each blade cuts its own cleave (`Config/WeaponFx`, owner 2026-11-08): the
	streak's colours, length and taper, and the motes it scatters over the
	ground it sweeps, popping in, turning and fading, from a pool of
	`MOTE_POOL`, so a swing costs no new parts. A Legendary or Mythic blade's
	streak glows (`Config/Weapons.trailGlow`), a rainbow Mythic's streak and
	motes turning round the hue wheel at its weapon's pace (`Fx/WeaponGlow`).
	The Gladeheart's motes are the little cross-shaped stars the owner asked
	for on 2026-10-25.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Device = require(script.Parent.Parent.Device)
local PlayerStats = require(script.Parent.Parent.PlayerStats)
local SwingBox = require(ReplicatedStorage.Shared.Combat.SwingBox)
local SwingSweep = require(ReplicatedStorage.Shared.Combat.SwingSweep)
local WeaponFx = require(ReplicatedStorage.Shared.Config.WeaponFx)

local SwingTrail = {}

--[[ Studs above the floor the streak is drawn at: about where the blade
     is as it swings. ]]
local HEIGHT = 1.4
--[[ Seconds the streak lasts behind the tip: a slash's tail, not the whole
     shape held. ]]
local TAIL = 0.16

type Active = {
	origin: CFrame,
	shape: SwingBox.Shape,
	sweep: SwingSweep.Sweep,
	--[[ Whether the far edge has been held for its frame. ]]
	finished: boolean,
}

--[[ The thin side of a mote's bars and the most alive at once. ]]
local MOTE_THICK = 0.14
local MOTE_POOL = 24

--[[ One thrown-off mote: its bars (the second is a `Star`'s alone), each
     bar's full size, and how it flies. ]]
type Mote = {
	arms: { Part },
	sizes: { Vector3 },
	born: number,
	at: Vector3,
	hue: number?,
	spin: number,
	rise: number,
	life: number,
}

local motes: { Mote } = {}
local idleMotes: { Mote } = {}
local moteDebt = 0
local moteFolder: Folder? = nil
local moteConnection: RBXScriptConnection? = nil

local holder: Part? = nil
local ends: { Attachment } = {}
local ribbon: Trail? = nil
local active: Active? = nil

local function build(colours: { Color3 })
	local part = Instance.new("Part")
	part.Name = "SwingTrail"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Parent = Workspace.CurrentCamera

	local a0 = Instance.new("Attachment")
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	--[[ Blended normally: glowing, it added to the grass under it and read
	     as yellow rather than red. ]]
	trail.LightEmission = 0
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new(colours[1], colours[#colours])
	--[[ Bright at the blade and fading, narrowing towards the tail, as a
	     sword's slash streaks behind it. ]]
	trail.Lifetime = TAIL
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	trail.Enabled = false
	trail.Parent = part

	holder = part
	ends = { a0, a1 }
	ribbon = trail
end

--[[ A Mythic's streak turns round the hue wheel at its weapon's pace. ]]
local RAINBOW_SPEED = 0.25
local RAINBOW_SATURATION = 0.7

--[[ The held blade's cleave, a pair being drawn as the blade it pairs. ]]
local function cleaveOf(weapon: any): WeaponFx.Cleave?
	local held = Players.LocalPlayer:GetAttribute("Weapon")
	return (if type(held) == "string" then WeaponFx.cleaves[held] else nil)
		or WeaponFx.cleaves[weapon.dualOf or ""]
end

--[[ The streak's look for the blade in hand: its own colours and shape,
     glowing and blended bright for a Legendary or Mythic, a rainbow
     Mythic's turned round the wheel. ]]
local function tint(weapon: any, cleave: WeaponFx.Cleave?)
	local trail = ribbon
	if not trail then
		return
	end
	local colours = if cleave then cleave.colour else weapon.swingTrail.colour
	local first, last = colours[1], colours[#colours]
	if weapon.trailGlow then
		if weapon.rainbow then
			first = Color3.fromHSV((os.clock() * RAINBOW_SPEED) % 1, RAINBOW_SATURATION, 1)
			last = first:Lerp(Color3.new(1, 1, 1), 0.35)
		end
		trail.LightEmission = 1
	else
		trail.LightEmission = 0
	end
	trail.Color = ColorSequence.new(first, last)
	trail.Lifetime = if cleave then cleave.tail else TAIL
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, if cleave then cleave.taper else 0.25),
	})
end

local function newMote(): Mote
	local folder = moteFolder
	if not (folder and folder.Parent) then
		local made = Instance.new("Folder")
		made.Name = "SwingMotes"
		made.Parent = Workspace.CurrentCamera
		moteFolder = made
		folder = made
	end
	local arms: { Part } = {}
	for index = 1, 2 do
		local arm = Instance.new("Part")
		arm.Name = "Mote"
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanQuery = false
		arm.CanTouch = false
		arm.CastShadow = false
		arm.Transparency = 1
		arm.Parent = folder
		arms[index] = arm
	end
	return {
		arms = arms,
		sizes = { Vector3.one, Vector3.one },
		born = 0,
		at = Vector3.zero,
		hue = nil,
		spin = 0,
		rise = 0,
		life = 1,
	}
end

--[[ Poses every live mote, and parks the ones whose time is up. ]]
local function stepMotes()
	local now = os.clock()
	for index = #motes, 1, -1 do
		local mote = motes[index]
		local t = (now - mote.born) / mote.life
		if t >= 1 then
			for _, arm in mote.arms do
				arm.Transparency = 1
			end
			table.remove(motes, index)
			table.insert(idleMotes, mote)
			continue
		end
		-- pops in over the first fifth, shrinks away over the rest
		local scale = if t < 0.2 then t / 0.2 else 1 - (t - 0.2) / 0.8 * 0.7
		local frame = CFrame.new(mote.at + Vector3.new(0, t * mote.rise, 0))
			* CFrame.Angles(0, mote.spin + t * 2.5, 0)
		local hue = mote.hue
		for at, arm in mote.arms do
			if mote.sizes[at].Magnitude < 1e-3 then
				continue
			end
			if hue then
				arm.Color =
					Color3.fromHSV((hue + now * RAINBOW_SPEED) % 1, RAINBOW_SATURATION * 0.8, 1)
			end
			arm.Transparency = 0.1 + 0.8 * math.max(0, (t - 0.55) / 0.45)
			arm.CFrame = frame
			arm.Size = (mote.sizes[at] * scale):Max(Vector3.one * 0.05)
		end
	end
	if #motes == 0 and moteConnection then
		moteConnection:Disconnect()
		moteConnection = nil
	end
end

--[[ Shapes a pooled mote as `spec` says. ]]
local function shapeMote(mote: Mote, spec: WeaponFx.Motes, glowing: boolean)
	local size, form = spec.size, spec.form
	local first = if form == "Star" or form == "Shard"
		then Vector3.new(size, MOTE_THICK, MOTE_THICK)
		elseif form == "Leaf" then Vector3.new(size, 0.06, size * 0.6)
		else Vector3.one * size
	mote.sizes[1] = first
	mote.sizes[2] = if form == "Star"
		then Vector3.new(MOTE_THICK, MOTE_THICK, size)
		else Vector3.zero
	for _, arm in mote.arms do
		arm.Shape = if form == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
		arm.Material = if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic
		arm.Color = spec.colour
	end
	mote.rise, mote.life = spec.rise, spec.life
end

--[[ Scatters the cleave's motes over the streak between its two ends, at
     a steady rate, from the pool. ]]
local function scatterMotes(dt: number, spec: WeaponFx.Motes, weapon: any)
	local part = holder
	if not part or #ends < 2 then
		return
	end
	moteDebt += dt * spec.rate
	while moteDebt >= 1 do
		moteDebt -= 1
		local mote = table.remove(idleMotes)
		if not mote then
			if #motes >= MOTE_POOL then
				break
			end
			mote = newMote()
		end
		local m = mote :: Mote
		shapeMote(m, spec, weapon.trailGlow ~= nil)
		local along = 0.2 + math.random() * 0.8
		m.at = part.CFrame:PointToWorldSpace(ends[1].Position:Lerp(ends[2].Position, along))
		m.born = os.clock()
		m.hue = if weapon.rainbow then math.random() else nil
		m.spin = math.random() * math.pi
		table.insert(motes, m)
	end
	if not moteConnection then
		moteConnection = RunService.RenderStepped:Connect(stepMotes)
	end
end

local lastMoteStep = os.clock()

local function place(swing: Active, progress: number)
	local a, b = SwingSweep.edge(swing.shape, swing.sweep, progress)
	ends[1].Position = a
	ends[2].Position = b
end

--[[
	Called every frame by `Fx/WeaponPose`. `progress` is how far through
	the slash's `TrailOn`–`TrailOff` window it is, or nil outside it;
	`blow` is which blow of `blows`. (`_seconds`, the window's length, is
	unused since the streak has a fixed tail.)
]]
function SwingTrail.step(
	character: Model,
	weapon: any,
	progress: number?,
	blow: number,
	blows: number,
	_seconds: number
)
	local config = weapon.swingTrail
	local class = Classes[PlayerStats.get().class]
	local box = class and class.swing
	if not (config and box and progress) then
		--[[ A trail records where its ends are once a frame, so the far
		     edge is held for one frame before it stops, or the last sliver
		     of the box would go unpainted. ]]
		local ending = active
		if ending and not ending.finished then
			ending.finished = true
			place(ending, 1)
			return
		end
		if ribbon then
			ribbon.Enabled = false
		end
		active = nil
		return
	end
	if not (holder and holder.Parent) then
		build(config.colour)
	end
	local cleave = cleaveOf(weapon)
	tint(weapon, cleave)

	local current = active
	if current and not current.finished then
		place(current, progress)
		-- its motes over the ground the slash is sweeping
		local now = os.clock()
		local spec = cleave and cleave.motes
		if spec and Device.tier().orbSparkleRate > 0 then
			scatterMotes(math.min(now - lastMoteStep, 0.1), spec, weapon)
		end
		lastMoteStep = now
		return
	end
	lastMoteStep = os.clock()

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 1e-3 then
		return
	end
	local stats = PlayerStats.get()
	local at = Vector3.new(root.Position.X, HEIGHT, root.Position.Z)
	local fresh: Active = {
		origin = CFrame.lookAt(at, at + forward),
		shape = SwingBox.shape(
			box,
			blow,
			blows,
			stats.widthScale,
			stats.reachBonus,
			stats.reachScale
		),
		sweep = SwingSweep.forBlow(blow, blows),
		finished = false,
	}
	active = fresh

	local trail = ribbon :: Trail
	trail.Enabled = false
	local part = holder :: Part
	part.CFrame = fresh.origin
	--[[ The near edge holds for this frame, so the first sliver is
	     painted too; the sweep moves on from the next. ]]
	place(fresh, 0)
	trail:Clear()
	trail.Enabled = true
end

return SwingTrail
