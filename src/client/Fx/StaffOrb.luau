--!strict
--[[
	The staff's orb as a cast charges, for the local player (the owner's
	Arcane Staff kit, 2026-10-23).

	The orb and its ring of small orbs are welded to the staff, so this
	client hides them and draws its own copies in their place each frame.
	While charging, the charge rises to full over `CHARGE_TIME`; the orb
	swells and pulses, a light on it brightens and reaches further, and the
	ring spins faster and draws in. A cast spends the orb: it drops to
	`SPENT` of its size and grows back at `REGROW` a second. Numbers are
	the kit's.

	Presentation only, and local: other players see the staff as welded.
]]

local Workspace = game:GetService("Workspace")

local StaffOrb = {}

local CHARGE_TIME = 0.7
local SPENT = 0.45
local REGROW = 1.6
local LIGHT_COLOUR = Color3.fromRGB(80, 170, 255)

local charge = 0
local grow = 1
local spin = 0
local orbCopy: BasePart? = nil
local orbitCopy: BasePart? = nil
local orbSource: BasePart? = nil
local orbitSource: BasePart? = nil
local light: PointLight? = nil

local function copyOf(source: BasePart): BasePart
	local copy = source:Clone()
	copy:ClearAllChildren()
	copy.Anchored = true
	copy.Parent = Workspace.CurrentCamera
	return copy
end

function StaffOrb.hide()
	for _, part in { orbCopy, orbitCopy } do
		if part then
			part.Transparency = 1
		end
	end
end

--[[ A cast left the staff. ]]
function StaffOrb.spend()
	charge = 0
	grow = SPENT
end

--[[ Draws the orb for this frame. `charging` is whether a cast is being
     readied; `orbitAxis` the ring's axis in the staff's model frame. ]]
function StaffOrb.step(character: Model, charging: boolean, orbitAxis: Vector3, dt: number)
	local weapon = character:FindFirstChild("HeldWeapon")
	local orb: BasePart?, orbit: BasePart? = nil, nil
	if weapon then
		for _, part in weapon:GetChildren() do
			if part:IsA("BasePart") then
				if part:GetAttribute("Orb") then
					orb = part
				elseif part:GetAttribute("Orbit") then
					orbit = part
				end
			end
		end
	end
	if not (orb and orbit) then
		StaffOrb.hide()
		return
	end

	if orb ~= orbSource then
		if orbCopy then
			orbCopy:Destroy()
		end
		orbCopy = copyOf(orb)
		orbSource = orb
		local glow = Instance.new("PointLight")
		glow.Color = LIGHT_COLOUR
		glow.Shadows = false
		glow.Parent = orbCopy
		light = glow
	end
	if orbit ~= orbitSource then
		if orbitCopy then
			orbitCopy:Destroy()
		end
		orbitCopy = copyOf(orbit)
		orbitSource = orbit
	end
	orb.LocalTransparencyModifier = 1
	orbit.LocalTransparencyModifier = 1

	charge = if charging then math.min(1, charge + dt / CHARGE_TIME) else 0
	grow = math.min(1, grow + REGROW * dt)
	local c = 1 - (1 - charge) ^ 2
	spin += (0.9 + 7 * c) * dt

	local now = os.clock()
	local copy = orbCopy :: BasePart
	copy.Transparency = 0
	copy.Size = orb.Size * grow * (1 + 0.12 * c) * (1 + 0.08 * c * math.sin(30 * now))
	copy.CFrame = orb.CFrame
	local glow = light :: PointLight
	glow.Brightness = 1 + 4 * c
	glow.Range = 8 + 6 * c

	--[[ The ring turns about its axis through the orb's centre, drawing in
	     as the charge builds. ]]
	local ring = orbitCopy :: BasePart
	local axis = orb.CFrame:VectorToWorldSpace(orbitAxis.Unit)
	local around = orb.CFrame.Position
	local turned = CFrame.fromAxisAngle(axis, spin)
	local offset = orbit.Position - around
	ring.Transparency = 0
	ring.Size = orbit.Size * (1 - 0.22 * c)
	ring.CFrame = CFrame.new(around + turned * offset * (1 - 0.22 * c))
		* turned
		* orbit.CFrame.Rotation
end

return StaffOrb
