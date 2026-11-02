--!strict
--[[
	The Angel standing in an Angel room (`RoomConfig.encounter`), built from
	`Config/AngelDesign`'s blocks.

	Built into the arena folder, so the next room tears it down with
	everything else and there is nothing to clean up by hand.

	Every block is welded to one invisible anchored root, and only the root
	moves: the bob is a single tween on one CFrame rather than a Heartbeat
	over twenty parts. The pool of light on the ground is parented outside
	that root, so it stays on the floor while the figure rises over it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AngelDesign = require(ReplicatedStorage.Shared.Config.AngelDesign)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.forTag("AngelProp")

local AngelProp = {}

local function piece(spec: AngelDesign.Part): BasePart
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = spec.size
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = spec.color
	if spec.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Material = if spec.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	return part
end

--[[ Builds the Angel over `at` (a point on the floor), facing `look` on the
     flat. Returns the model, parented to `parent`. ]]
function AngelProp.build(parent: Instance, at: Vector3, look: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Angel"

	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local base = CFrame.lookAt(at, at + flat.Unit)

	--[[ The root the body hangs from, at the floor point. Invisible, and the
	     only anchored part, so the tween below moves the whole figure. ]]
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = base
	root.Parent = model
	model.PrimaryPart = root

	for _, spec in AngelDesign.parts do
		local part = piece(spec)
		part.CFrame = base * CFrame.new(spec.offset)
		if spec.grounded then
			--[[ A Cylinder's own axis lies along X, so a flat disc on the
			     floor is turned onto its face. ]]
			if spec.shape == "Cylinder" then
				part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(90))
			end
			part.Anchored = true
			part.Parent = model
			continue
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		part.Parent = model
		weld.Parent = part
	end

	local light = Instance.new("PointLight")
	light.Color = AngelDesign.light
	light.Range = AngelDesign.lightRange
	light.Brightness = AngelDesign.lightBrightness
	light.Shadows = false
	light.Parent = root

	model.Parent = parent

	--[[ The bob: up from where the parts put it, then back, forever. Started
	     after parenting so nothing animates while the room is still being
	     assembled. ]]
	local up = base * CFrame.new(0, AngelDesign.bob, 0)
	local info = TweenInfo.new(
		AngelDesign.bobSeconds,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	)
	TweenService:Create(root, info, { CFrame = up }):Play()

	log.info("built the Angel at %s", tostring(at))
	return model
end

return AngelProp
