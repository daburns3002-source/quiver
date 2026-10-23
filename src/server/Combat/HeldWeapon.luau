--!strict
--[[
	Puts the class's weapon in its character's hand (`Config/Weapons`).

	Built on the server, so every player in a co-op run sees it. Each part is
	a clone of a mesh template welded to the hand: massless, never colliding,
	answering a raycast, or touching, so it cannot change how the body moves
	or catch an enemy shot. The arms are posed on the client (`Fx/WeaponPose`),
	which also draws a bow's live string and nocked arrow (`Fx/BowString`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local HeldWeapon = {}

local templates: { [string]: MeshPart } = {}

function HeldWeapon.preload()
	local ids: { string } = {}
	for _, name in { "LeafBow", "ArcaneStaff", "RubyGreatsword" } do
		local weapon = (Weapons :: any)[name] :: Weapons.Weapon
		for _, part in weapon.parts do
			table.insert(ids, part.meshId)
		end
	end
	templates = MeshTemplates.load(ids)
end

--[[ The bow's axes in the hand's: held upright with the arrow pointing
     where the hand's fingers point (-Y) once the arm is raised forward.
     Model X → hand -X, model Y (up the bow) → hand -Z, model Z (arrow) →
     hand -Y. ]]
local IN_HAND = CFrame.fromMatrix(
	Vector3.zero,
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 0, -1),
	Vector3.new(0, -1, 0)
)

--[[ Puts `weaponName` (a `Config/Weapons` entry) in the character's hand,
     replacing whatever it held. ]]
function HeldWeapon.equip(character: Model, weaponName: string)
	local weapon = (Weapons :: any)[weaponName] :: Weapons.Weapon?
	if not weapon then
		return
	end
	local hand = character:WaitForChild(weapon.hand, 10) :: BasePart?
	if not hand then
		return
	end

	local existing = character:FindFirstChild("HeldWeapon")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "HeldWeapon"

	local frame = hand.CFrame * CFrame.new(weapon.grip) * (weapon.inHand or IN_HAND)
	for _, spec in weapon.parts do
		local template = templates[spec.meshId]
		if not template then
			continue
		end
		local part = template:Clone()
		part.Name = spec.name
		part.Size = spec.size * weapon.scale
		part.CFrame = frame * CFrame.new(spec.offset * weapon.scale)
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		--[[ White, so the model's own vertex colours or texture show,
		     unless the part names a colour of its own. ]]
		part.Color = spec.colour or Color3.new(1, 1, 1)
		if spec.textureId then
			part.TextureID = spec.textureId
		end
		part.Material = if spec.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if spec.nocked then
			part.Transparency = 1
			part:SetAttribute("Nocked", true)
		end
		if spec.liveString then
			part:SetAttribute("LiveString", true)
		end
		if spec.orb then
			part:SetAttribute("Orb", true)
		end
		if spec.orbit then
			part:SetAttribute("Orbit", true)
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model

		--[[ The model's origin, the grip, so the client can place the live
		     string and the nocked arrow in the bow's own units. ]]
		if not model:FindFirstChild("WeaponOrigin", true) then
			local origin = Instance.new("Attachment")
			origin.Name = "WeaponOrigin"
			origin.CFrame = part.CFrame:ToObjectSpace(frame)
			origin:SetAttribute("Scale", weapon.scale)
			origin.Parent = part
		end
	end

	model.Parent = character
end

return HeldWeapon
