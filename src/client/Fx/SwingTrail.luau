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

	A Legendary or Mythic blade's streak glows in its own colour
	(`Config/Weapons.trailGlow`), a Mythic's turning round the rainbow at
	its weapon's pace (`Fx/WeaponGlow`; owner, 2026-10-25).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local PlayerStats = require(script.Parent.Parent.PlayerStats)
local SwingBox = require(ReplicatedStorage.Shared.Combat.SwingBox)
local SwingSweep = require(ReplicatedStorage.Shared.Combat.SwingSweep)

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

--[[ The streak's colour and glow for the weapon in hand: its own glow colour
     when it has one (a Mythic's turned round the rainbow), else the base
     ribbon's colours, blended normally. ]]
local function tint(weapon: any)
	local trail = ribbon
	if not trail then
		return
	end
	local glow: Color3? = weapon.trailGlow
	if glow then
		local colour = if weapon.rainbow
			then Color3.fromHSV((os.clock() * RAINBOW_SPEED) % 1, RAINBOW_SATURATION, 1)
			else glow
		trail.Color = ColorSequence.new(colour, colour:Lerp(Color3.new(1, 1, 1), 0.35))
		trail.LightEmission = 1
	else
		local colours = weapon.swingTrail.colour
		trail.Color = ColorSequence.new(colours[1], colours[#colours])
		trail.LightEmission = 0
	end
end

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
	tint(weapon)

	local current = active
	if current and not current.finished then
		place(current, progress)
		return
	end

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
		shape = SwingBox.shape(box, blow, blows, stats.widthScale, stats.reachBonus),
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
