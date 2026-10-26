--!strict
--[[
	Puts the class's weapon in its character's hand (`Config/Weapons`).

	Built on the server, so every player in a co-op run sees it. Each part is
	a clone of a mesh template welded to the hand: massless, never colliding,
	answering a raycast, or touching, so it cannot change how the body moves
	or catch an enemy shot. The arms are posed on the client (`Fx/WeaponPose`),
	which also draws a bow's live string and nocked arrow (`Fx/BowString`).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local HeldWeapon = {}

local templates: { [string]: MeshPart } = {}

--[[ The light a glow part gives off, so an Epic, Legendary or Mythic
     reads as glowing from the game's camera and not only as a Neon
     surface (owner, 2026-10-24). ]]
local GLOW_LIGHT = { brightness = 2, range = 6 }

function HeldWeapon.preload()
	local ids: { string } = {}
	-- every weapon and skin, so switching class never waits on a fetch
	-- (TwigBowDual's parts are the Twig Bow's own, so its ids repeat)
	for _, weapon in Weapons :: any do
		for _, part in (weapon :: Weapons.Weapon).parts do
			if not table.find(ids, part.meshId) then
				table.insert(ids, part.meshId)
			end
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

--[[ Empty hands (the lobby, owner 2026-10-25: "the roblox character in the
     main lobby should not have any weapon equipped"). ]]
function HeldWeapon.unequip(character: Model)
	local existing = character:FindFirstChild("HeldWeapon")
	if existing then
		existing:Destroy()
	end
end

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

	--[[ Builds the weapon's parts in one hand. The off hand's copy (a second
	     bow) is the same model, but only the main hand's carries the
	     nocked arrow, the live string and the origin the client draws them
	     from. ]]
	local function build(holder: BasePart, grip: Vector3, turn: CFrame, main: boolean)
		local frame = holder.CFrame * CFrame.new(grip) * turn
		for _, spec in weapon.parts do
			local template = templates[spec.meshId]
			if not template or (spec.nocked and not main) then
				continue
			end
			local part = template:Clone()
			part.Name = spec.name
			part.Size = spec.size * weapon.scale
			part.CFrame = frame
				* CFrame.new(spec.offset * weapon.scale)
				* (if spec.turned then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
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
			if spec.glow then
				local light = Instance.new("PointLight")
				light.Color = part.Color
				light.Brightness = GLOW_LIGHT.brightness
				light.Range = GLOW_LIGHT.range
				light.Shadows = false
				light.Parent = part
				if weapon.rainbow then
					-- cycled on the client (`Fx/WeaponGlow`)
					CollectionService:AddTag(part, "WeaponRainbow")
				end
			end
			if spec.nocked then
				part.Transparency = 1
				part:SetAttribute("Nocked", true)
			end
			if spec.liveString and main then
				part:SetAttribute("LiveString", true)
			end
			if spec.orb then
				part:SetAttribute("Orb", true)
			end
			if spec.orbit then
				part:SetAttribute("Orbit", true)
			end

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = holder
			weld.Part1 = part
			weld.Parent = part
			part.Parent = model

			--[[ The model's origin, the grip, so the client can place the
			     live string and the nocked arrow in the bow's own units. ]]
			if main and not model:FindFirstChild("WeaponOrigin", true) then
				local origin = Instance.new("Attachment")
				origin.Name = "WeaponOrigin"
				origin.CFrame = part.CFrame:ToObjectSpace(frame)
				origin:SetAttribute("Scale", weapon.scale)
				origin.Parent = part
			end
		end
	end

	build(hand, weapon.grip, weapon.inHand or IN_HAND, true)
	local offhand = weapon.offhand
	if offhand then
		local other = character:FindFirstChild(offhand.hand) :: BasePart?
		if other then
			build(other, offhand.grip, offhand.inHand or IN_HAND, false)
		end
	end

	model.Parent = character
end

return HeldWeapon
