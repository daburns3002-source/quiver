--!strict
--[[
	The bow's live string and nocked arrow, for the local player (the owner's
	Leaf Bow kit, 2026-10-23).

	The bow's own string mesh is straight and welded, so this client hides it
	and draws the string as two thin cylinders from the bow's tie points to
	the nock: the right hand while an arrow is drawn, the string's centre
	otherwise. The nocked arrow is a local copy of the bow's hidden Arrow
	part, laid from the nock towards its rest on the riser.

	Points come from `Config/Weapons` (`bowString`), in model units from the
	`WeaponOrigin` attachment `Combat/HeldWeapon` puts at the grip.

	Presentation only, and local: other players see the bow's plain string.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local BowString = {}

local STRING_COLOUR = Color3.fromRGB(236, 226, 199)
local STRING_THICKNESS = 0.05
--[[ Where the string sits below the drawing hand's centre, studs. ]]
local HAND_NOCK = CFrame.new(0, -0.1, 0)

local upper: BasePart? = nil
local lower: BasePart? = nil
local arrow: BasePart? = nil
local arrowSource: BasePart? = nil

local function stringPart(name: string): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = STRING_COLOUR
	part.Parent = Workspace.CurrentCamera
	return part
end

--[[ A cylinder's length runs along its X axis. ]]
local function span(part: BasePart, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	part.Size = Vector3.new(length, STRING_THICKNESS, STRING_THICKNESS)
	part.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
end

local function hide()
	for _, part in { upper, lower, arrow } do
		if part then
			part.Transparency = 1
		end
	end
end

--[[ Draws the string and arrow for this frame. `drawn` is whether the right
     hand is on the string with an arrow nocked. ]]
function BowString.step(character: Model, drawn: boolean)
	local weapon = character:FindFirstChild("HeldWeapon")
	local origin = weapon and weapon:FindFirstChild("WeaponOrigin", true) :: Attachment?
	-- the bow this character holds (the player's `Weapon`), its own string
	local player = Players:GetPlayerFromCharacter(character)
	local held = player and player:GetAttribute("Weapon")
	local bow = (
		type(held) == "string" and (Weapons :: any)[held] or Weapons.TwigBow
	) :: Weapons.Weapon
	local points = bow.bowString
	if not (origin and points) then
		hide()
		return
	end
	local frame = origin.WorldCFrame
	local scale = (origin:GetAttribute("Scale") :: number?) or bow.scale
	local function at(point: Vector3): Vector3
		return frame:PointToWorldSpace(point * scale)
	end

	local hand = character:FindFirstChild("RightHand") :: BasePart?
	local nock = if drawn and hand then (hand.CFrame * HAND_NOCK).Position else at(points.nock)

	upper = upper or stringPart("BowStringUpper")
	lower = lower or stringPart("BowStringLower")
	local top, bottom = upper :: BasePart, lower :: BasePart
	top.Transparency = 0
	bottom.Transparency = 0
	span(top, at(points.top), nock)
	span(bottom, at(points.bottom), nock)

	local source: BasePart? = nil
	for _, part in (weapon :: Instance):GetChildren() do
		if part:IsA("BasePart") then
			if part:GetAttribute("LiveString") then
				part.LocalTransparencyModifier = 1
			elseif part:GetAttribute("Nocked") then
				source = part
			end
		end
	end

	if source and source ~= arrowSource then
		if arrow then
			arrow:Destroy()
		end
		local copy = source:Clone()
		copy:ClearAllChildren()
		copy.Anchored = true
		copy.Parent = Workspace.CurrentCamera
		arrow = copy
		arrowSource = source
	end
	local shaft = arrow
	if not (shaft and source) then
		return
	end
	shaft.Transparency = if drawn then 0 else 1
	if drawn then
		--[[ The arrow mesh points along its own +Z, tip foremost. ]]
		local direction = (at(points.rest) - nock).Unit
		local centre = nock + direction * shaft.Size.Z / 2
		shaft.CFrame = CFrame.lookAt(centre, centre - direction)
	end
end

function BowString.hide()
	hide()
end

return BowString
