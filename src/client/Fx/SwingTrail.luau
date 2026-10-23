--!strict
--[[
	A blade's swing trail, for the local player (the owner's Ruby Greatsword
	kit, 2026-10-23): a red ribbon between two points up the blade
	(`Config/Weapons.swingTrail`), shown between a slash's `TrailOn` and
	`TrailOff` markers (`Fx/WeaponPose`).

	Built on this client against the `WeaponOrigin` attachment
	`Combat/HeldWeapon` puts at the grip, and rebuilt whenever the weapon
	is. Presentation only, and local: other players see the sword swing
	without its trail.
]]

local SwingTrail = {}

local LIFETIME = 0.16

local trail: Trail? = nil
local builtFor: Attachment? = nil

local function build(
	origin: Attachment,
	config: { base: Vector3, tip: Vector3, colour: { Color3 } }
)
	if trail then
		trail:Destroy()
	end
	local holder = origin.Parent :: BasePart
	local scale = (origin:GetAttribute("Scale") :: number?) or 1

	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.CFrame = origin.CFrame * CFrame.new(config.base * scale)
	base.Parent = holder
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.CFrame = origin.CFrame * CFrame.new(config.tip * scale)
	tip.Parent = holder

	local ribbon = Instance.new("Trail")
	ribbon.Name = "SwingTrail"
	ribbon.Attachment0 = base
	ribbon.Attachment1 = tip
	ribbon.Lifetime = LIFETIME
	ribbon.LightEmission = 0.8
	ribbon.LightInfluence = 0
	ribbon.Color = ColorSequence.new(config.colour[1], config.colour[#config.colour])
	ribbon.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	ribbon.Enabled = false
	ribbon.Parent = holder

	trail = ribbon
	builtFor = origin
end

--[[ Shows the trail while `on`, for a weapon that has one. ]]
function SwingTrail.step(character: Model, weapon: any, on: boolean)
	local config = weapon.swingTrail
	local held = character:FindFirstChild("HeldWeapon")
	local origin = held and held:FindFirstChild("WeaponOrigin", true) :: Attachment?
	if not (config and origin) then
		if trail then
			trail.Enabled = false
		end
		return
	end
	if origin ~= builtFor or not (trail and trail.Parent) then
		build(origin :: Attachment, config)
	end
	(trail :: Trail).Enabled = on
end

return SwingTrail
