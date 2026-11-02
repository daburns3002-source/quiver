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
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)

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

--[[ The three mesh ids, if the owner has imported the GLB. All three or
     none: a half-imported Angel would draw a head with no eyes, so the
     blocks are kept until the set is complete (`tests/Angel.spec`). ]]
local function meshIds(): { string }?
	local ids = {}
	for _, part in { AngelDesign.mesh.cream, AngelDesign.mesh.gold, AngelDesign.mesh.eye } do
		if part.id == "" then
			return nil
		end
		table.insert(ids, part.id)
	end
	return ids
end

--[[ The Angel as three MeshParts, one a colour, in place of the blocks.
     Returns false if a mesh did not load, so the caller falls back rather
     than leaving a room with an invisible encounter in it. ]]
local function buildMesh(model: Model, root: BasePart, base: CFrame, ids: { string }): boolean
	local templates = MeshTemplates.load(ids)
	local pieces = {
		{ spec = AngelDesign.mesh.cream, color = AngelDesign.cream },
		{ spec = AngelDesign.mesh.gold, color = AngelDesign.gold },
		{ spec = AngelDesign.mesh.eye, color = AngelDesign.eye },
	}
	for _, entry in pieces do
		local template = templates[entry.spec.id]
		if not template then
			return false
		end
		local part = template:Clone()
		part.Name = entry.spec.id
		part.Size = entry.spec.size
		part.CFrame = base * CFrame.new(entry.spec.offset)
		part.Color = entry.color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		part.Parent = model
		weld.Parent = part
	end
	return true
end

--[[ Builds the Angel over `at` (a point on the floor), facing `look` on the
     flat. Returns the model, parented to `parent`.

     From the GLB's meshes where the owner has imported them, and from
     `Config/AngelDesign`'s blocks otherwise. The two are the same figure:
     the GLB is exported from those very blocks. ]]
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

	local ids = meshIds()
	local drawn = ids ~= nil and buildMesh(model, root, base, ids)

	for _, spec in AngelDesign.parts do
		--[[ With the meshes drawn, only the pool of light is still a part:
		     it is Neon and flat on the floor, not geometry the GLB carries. ]]
		if drawn and not spec.grounded then
			continue
		end
		local part = piece(spec)
		local turn = spec.rotation
		part.CFrame = base * CFrame.new(spec.offset)
		if turn then
			part.CFrame = part.CFrame
				* CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))
		end
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

	log.info("built the Angel at %s (%s)", tostring(at), if drawn then "mesh" else "blocks")
	return model
end

return AngelProp
