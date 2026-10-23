--!strict
--[[
	Puts the class's weapon in its character's hand (`Config/Weapons`).

	Built on the server, so every player in a co-op run sees it. Each part is
	a clone of a mesh template welded to the hand: massless, never colliding,
	answering a raycast, or touching, so it cannot change how the body moves
	or catch an enemy shot. The nocked arrow starts hidden; the client shows
	it while drawing (`Fx/ArcherPose`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local HeldWeapon = {}

local templates: { [string]: MeshPart } = {}

function HeldWeapon.preload()
	local ids: { string } = {}
	for _, part in Weapons.LeafBow.parts do
		table.insert(ids, part.meshId)
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

--[[ Where the grip sits in the hand: a little below its centre, in the
     palm. ]]
local GRIP = CFrame.new(0, -0.25, 0)

function HeldWeapon.equip(character: Model)
	local weapon = Weapons.LeafBow
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

	local frame = hand.CFrame * GRIP * IN_HAND
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
		--[[ White, so the model's own vertex colours show. ]]
		part.Color = Color3.new(1, 1, 1)
		part.Material = if spec.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if spec.nocked then
			part.Transparency = 1
			part:SetAttribute("Nocked", true)
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	model.Parent = character
end

return HeldWeapon
