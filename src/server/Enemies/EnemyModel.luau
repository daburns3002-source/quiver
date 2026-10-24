--!strict
--[[
	Assembles an archetype's body from its design data.

	The split matters: `Config/EnemyDesigns` says what an archetype looks like
	and this says how a look becomes parts. A silhouette change should be a
	readable diff in a data table, never an edit here.

	**The hitbox is still the only thing that answers a raycast.** It is
	invisible and every skin part has `CanQuery` off, so the shape the server
	sweeps is exactly the shape it was before any of this existed — which is
	the point. Hit detection was expensive to get right and none of it is
	allowed to depend on what an enemy happens to look like.

	Skin parts are welded to the hitbox rather than anchored and moved. The
	hitbox is anchored, so the assembly is kinematic and costs no simulation,
	and `EnemyManager` goes on moving an enemy by writing one CFrame.

	An archetype built from an imported model (`EnemyDesigns.Imported`:
	King Bloblin) adds that model's parts to its design (`designFor`),
	scaled to fill the hitbox and stood on its floor, each named after its
	GLB node so `Fx/ModelAnimator` can play the model's clips on it. They
	are welded like any skin, so a client that does not animate them still
	draws him where the server has him; one that does unwelds them locally.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local EnemyRigs = require(ReplicatedStorage.Shared.Config.EnemyRigs)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)

type EnemyConfig = Balance.EnemyConfig
type DesignPart = EnemyDesigns.DesignPart

--[[ A part of an imported model (`Config/ImportedModels/<Model>`). ]]
type ImportedPart = {
	name: string,
	meshId: string,
	textureId: string,
	color: { number },
	material: string,
	transparency: number,
	size: { number },
	cframe: { number },
	surface: string?,
}

--[[ A part as built: a design's, or one from an import. ]]
export type BuiltPart = DesignPart

local EnemyModel = {}

--[[ What `EnemyManager` needs back to drive the body: everything drawn, and
     the subset that responds to a colour change. ]]
export type Skin = {
	all: { BasePart },
	tintable: { BasePart },
	--[[ The parts an `Eyes` tell recolours. ]]
	eyes: { BasePart },
}

--[[
	Where a design part sits, in the hitbox's local space.

	Shared with the bounds test rather than duplicated there, so a design that
	passes the test is positioned by the same arithmetic that builds it.
]]
function EnemyModel.localCFrame(part: DesignPart): CFrame
	local placed = CFrame.new(part.offset)
	local rotation = part.rotation

	if not rotation then
		return placed
	end

	return placed * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
end

--[[ An archetype's own colour, lightened or darkened. Keeping identity in one
     number in Balance is why designs carry a multiplier instead of a Color3. ]]
local function shaded(base: Color3, shade: number): Color3
	return Color3.new(
		math.clamp(base.R * shade, 0, 1),
		math.clamp(base.G * shade, 0, 1),
		math.clamp(base.B * shade, 0, 1)
	)
end

--[[ The colour a part rests at: its fixed colour if the design gives one,
     otherwise its shade of the archetype's. ]]
local function restingColour(spec: DesignPart, config: EnemyConfig): Color3
	local colour = spec.color or shaded(config.color, spec.shade)
	if spec.material == Enum.Material.Neon then
		return colour
	end
	return shaded(colour, EnemyDesigns.BodyShade)
end

--[[ Attribute holding a part's resting transparency, so hiding and showing
     an enemy can put a jelly body back to see-through rather than solid. ]]
local RESTING_TRANSPARENCY = "RestingTransparency"

--[[ One template per uploaded mesh, made once and cloned for every enemy:
     CreateMeshPartAsync yields and fetches, which a spawn must not wait on. ]]
local meshTemplates: { [string]: MeshPart } = {}

--[[ Roblox's smallest part size. ]]
local SMALLEST = 0.001
--[[ A part this much smaller than the biggest is tucked away, not body. ]]
local TUCKED_SHARE = 0.01
--[[ Studs under which a built part is tucked away (`EnemyModel.tucked`). ]]
local TUCKED_STUDS = 0.05

--[[ Whether a design part is tucked away at rest, too small to see: a
     lash link waiting for its clip to scale it up. Not body, for bounds. ]]
function EnemyModel.tucked(part: DesignPart): boolean
	local size = part.restSize or part.size
	return math.max(size.X, size.Y, size.Z) < TUCKED_STUDS
end

local function importedParts(model: string): { ImportedPart }?
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("ImportedModels")
	local module = folder and folder:FindFirstChild(model)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	return (require :: any)(module) :: { ImportedPart }
end

local function rowCFrame(c: { number }): CFrame
	return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
end

--[[
	An imported model's parts as design parts: scaled by the most that keeps
	every part inside `box` (the hitbox's size), centred on it across, and
	stood on its floor. Pure, so the bounds spec measures what is built.
]]
function EnemyModel.importedDesign(
	imported: EnemyDesigns.ImportedDesign,
	box: Vector3
): { BuiltPart }
	local rows = importedParts(imported.model)
	if not rows then
		return {}
	end
	--[[ Parts tucked away at rest (a lash chain at a thousandth of its
	     size, laid out down the lane it will fly along) are not body: they
	     are left out of the bounds, or he would shrink to fit them. ]]
	local largest = 0
	for _, row in rows do
		largest = math.max(largest, row.size[1], row.size[2], row.size[3])
	end
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, row in rows do
		if math.max(row.size[1], row.size[2], row.size[3]) < largest * TUCKED_SHARE then
			continue
		end
		local cf = rowCFrame(row.cframe)
		local half = Vector3.new(row.size[1], row.size[2], row.size[3]) / 2
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = cf * (half * Vector3.new(x, y, z))
					low = low:Min(corner)
					high = high:Max(corner)
				end
			end
		end
	end
	local span = high - low
	local scale = math.min(box.X / span.X, box.Y / span.Y, box.Z / span.Z)
	local centre = (low + high) / 2
	--[[ Model space to hitbox space: centred across, its floor on the box's. ]]
	local origin = Vector3.new(centre.X, low.Y, centre.Z)
	local floor = Vector3.new(0, -box.Y / 2, 0)

	local out: { BuiltPart } = {}
	for _, row in rows do
		local cf = rowCFrame(row.cframe)
		local size = Vector3.new(row.size[1], row.size[2], row.size[3]) * scale
		local rx, ry, rz = cf:ToEulerAnglesXYZ()
		local eye = string.match(row.name, imported.eyes) ~= nil
		--[[ A part the GLB rests tucked away (a lash link at a thousandth of
		     its size) imports its mesh at that size, and Roblox keeps too
		     little of it: scaled back up, King Bloblin's links drew as pale
		     specks, an arm with no substance. In the blocky style each is a
		     cube anyway, so it is built as one. ]]
		local tucked = math.max(row.size[1], row.size[2], row.size[3]) < largest * TUCKED_SHARE
		local part: BuiltPart = {
			name = row.name,
			shape = (if tucked then "Block" else "Mesh") :: EnemyDesigns.DesignShape,
			meshId = if tucked then nil else row.meshId,
			textureId = if row.textureId ~= "" then row.textureId else nil,
			size = size:Max(Vector3.one * SMALLEST),
			restSize = if math.min(size.X, size.Y, size.Z) < SMALLEST then size else nil,
			offset = floor + (cf.Position - origin) * scale,
			rotation = Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz)),
			shade = 1,
			color = if eye
				then imported.eyeColor
				else Color3.new(row.color[1], row.color[2], row.color[3]),
			material = if eye
				then Enum.Material.Neon
				else (Enum.Material :: any)[row.material] or Enum.Material.SmoothPlastic,
			transparency = row.transparency,
			tint = not eye,
			eye = eye or nil,
			surface = row.surface,
		}
		table.insert(out, part)
	end
	return out
end

local designs: { [string]: { BuiltPart } } = {}

--[[ Every part an archetype is built from, in order: its design's, then
     its imported model's (`EnemyDesigns.Imported`). nil for an archetype
     with no design. ]]
function EnemyModel.designFor(config: EnemyConfig): { BuiltPart }?
	local cached = designs[config.displayName]
	if cached then
		return cached
	end
	local design = (EnemyDesigns :: any)[config.displayName] :: { DesignPart }?
	if not design then
		return nil
	end
	local out: { BuiltPart } = table.clone(design) :: any
	local imported = (EnemyDesigns.Imported :: any)[config.displayName] :: EnemyDesigns.ImportedDesign?
	if imported then
		for _, part in EnemyModel.importedDesign(imported, config.hitboxSize) do
			table.insert(out, part)
		end
	end
	designs[config.displayName] = out
	return out
end

--[[ Makes the mesh templates every design asks for. Called once at server
     start, before anything spawns; a mesh that fails to load leaves its
     part to fall back to a plain ellipsoid rather than breaking a spawn. ]]
function EnemyModel.preload()
	local ids: { string } = {}
	for _, design in EnemyDesigns :: any do
		if type(design) ~= "table" then
			continue
		end
		for _, spec in design do
			local id = type(spec) == "table" and spec.meshId
			if type(id) == "string" then
				table.insert(ids, id)
			end
		end
	end
	for _, imported in EnemyDesigns.Imported :: any do
		local rows: { ImportedPart } = importedParts(imported.model) or {}
		for _, row in rows do
			table.insert(ids, row.meshId)
		end
	end
	meshTemplates = MeshTemplates.load(ids)
end

--[[ A skinned mesh's bones, from its rig (`Config/EnemyRigs`), shrunk to
     the size the body is drawn at: a skinned mesh binds its vertices to
     bones by name, so these are what bend it. ]]
local function addBones(part: BasePart, rigName: string)
	local rig = EnemyRigs[rigName]
	if not rig then
		return
	end
	local made: { [string]: Bone } = {}
	for _, spec in rig.bones do
		local c = spec.cframe
		local bone = Instance.new("Bone")
		bone.Name = spec.name
		bone.CFrame = CFrame.new(
			c[1] * rig.scale,
			c[2] * rig.scale,
			c[3] * rig.scale,
			c[4],
			c[5],
			c[6],
			c[7],
			c[8],
			c[9],
			c[10],
			c[11],
			c[12]
		)
		bone.Parent = made[spec.parent] or part
		made[spec.name] = bone
	end
end

local function buildPart(spec: BuiltPart, config: EnemyConfig): BasePart
	local part: BasePart

	local template = if spec.shape == "Mesh" and spec.meshId
		then meshTemplates[spec.meshId]
		else nil
	if template then
		part = template:Clone()
		if spec.textureId then
			(part :: MeshPart).TextureID = spec.textureId
		end
		if spec.rig then
			addBones(part, spec.rig)
		end
	elseif spec.shape == "Wedge" then
		part = Instance.new("WedgePart")
	elseif spec.shape == "Ellipsoid" or spec.shape == "Mesh" then
		--[[ A Ball part is always a perfect sphere; a sphere mesh stretches
		     to whatever size the part is given, which is what a domed shell
		     or a squat slime needs. ]]
		local block = Instance.new("Part")
		block.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = block
		part = block
	else
		local block = Instance.new("Part")
		block.Shape = if spec.shape == "Ball"
			then Enum.PartType.Ball
			elseif spec.shape == "Cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block
		part = block
	end

	part.Name = spec.name
	part.Size = spec.size
	part.Color = restingColour(spec, config)
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	part:SetAttribute(RESTING_TRANSPARENCY, spec.transparency or 0)

	--[[ Decoration, and nothing more. A skin part that answered queries would
	     silently widen the hitbox the whole combat system is built around. ]]
	part.CanQuery = false
	part.CanCollide = false
	part.CanTouch = false
	--[[ No cast shadow: an enemy is grounded by its blob shadow alone, as in
	     Archero 2's footage (`EnemyDesigns`). ]]
	part.CastShadow = false
	part.Anchored = false

	part:SetAttribute(EnemyDesigns.SkinTag, true)
	--[[ An imported part's true size where Roblox clamps it, which its
	     clips scale (`Fx/ModelAnimator`), and its GLB material, which a
	     flash looks for (a boss's gems, `Fx/BossGlow`). ]]
	if spec.restSize then
		part:SetAttribute("RestSize", spec.restSize)
	end
	if spec.surface then
		part:SetAttribute("Surface", spec.surface)
		-- where it rests on the hitbox, which a client animating it reads
		-- rather than where a lagging weld has it (`Fx/ModelAnimator`)
		part:SetAttribute("RestCFrame", EnemyModel.localCFrame(spec))
	end
	--[[ Rides a bone of the rigged body (`Fx/EnemyRig`). ]]
	if spec.bone then
		part:SetAttribute(EnemyDesigns.BoneTag, spec.bone)
	end

	--[[ Trim opts out, so a telegraph reads as the body lighting up behind
	     fixed markings rather than the whole thing turning one flat colour. ]]
	if spec.tint ~= false then
		part:SetAttribute(EnemyDesigns.TintTag, true)
	end

	return part
end

--[[
	Builds the model, the hitbox and the skin.

	Returns the hitbox separately because it remains what everything else
	holds on to: `EnemyManager` moves it, the projectile filters find it, and
	`positions` is keyed off the model it roots.
]]
function EnemyModel.build(config: EnemyConfig, position: Vector3): (Model, BasePart, Skin)
	local model = Instance.new("Model")
	model.Name = config.displayName

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = config.hitboxSize
	hitbox.Position = position
	hitbox.Anchored = true
	--[[
		Collision is resolved analytically in Arena.resolve, so the hitbox is
		only ever a raycast target. Leaving CanCollide on would let enemies shove
		the player's character around, which move-or-shoot cannot survive.
	]]
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CastShadow = false
	hitbox.Color = config.color
	hitbox.Material = Enum.Material.SmoothPlastic
	--[[ Invisible: the skin is the enemy now. The box stays exactly the size
	     it was, because that is the shape the server sweeps. ]]
	hitbox.Transparency = 1
	hitbox.Parent = model

	model.PrimaryPart = hitbox

	local design = EnemyModel.designFor(config)
	local skin: Skin = { all = {}, tintable = {}, eyes = {} }

	--[[ An archetype with no design is a draft that has not been done yet, not
	     an error. It falls back to a visible hitbox, which is what every
	     archetype looked like before this existed. ]]
	if not design then
		hitbox.Transparency = 0
		table.insert(skin.all, hitbox)
		table.insert(skin.tintable, hitbox)
		return model, hitbox, skin
	end

	for _, spec in design do
		local part = buildPart(spec, config)
		part.CFrame = hitbox.CFrame * EnemyModel.localCFrame(spec)
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hitbox
		weld.Part1 = part
		weld.Parent = part

		table.insert(skin.all, part)
		if part:GetAttribute(EnemyDesigns.TintTag) then
			table.insert(skin.tintable, part)
		end
		if spec.eye then
			part:SetAttribute(EnemyDesigns.EyeTag, true)
			table.insert(skin.eyes, part)
		end
	end

	return model, hitbox, skin
end

--[[ Turns only the eyes one colour, for an `Eyes` tell; `restore` puts
     them back with the rest. ]]
function EnemyModel.tintEyes(skin: Skin, colour: Color3)
	for _, part in skin.eyes do
		part.Color = colour
	end
end

--[[ Floods the body with one colour, for a telegraph. Trim parts opt out, so
     markings stay legible while the mass behind them changes. ]]
function EnemyModel.tint(skin: Skin, colour: Color3)
	for _, part in skin.tintable do
		part.Color = colour
	end
end

--[[
	Puts every part back to the colour its design asked for.

	The counterpart to `tint`, and the reason a telegraph can be a flat colour
	without damage: restoring from the design rather than from a remembered
	value means a body cannot drift towards flat archetype colour however many
	times it flashes.
]]
function EnemyModel.restore(skin: Skin, config: EnemyConfig)
	local design = EnemyModel.designFor(config)

	if not design then
		for _, part in skin.all do
			part.Color = config.color
		end
		return
	end

	for index, spec in design do
		local part = skin.all[index]
		if part then
			part.Color = restingColour(spec, config)
		end
	end
end

--[[ Hides or shows the whole body for a dive. The hitbox is already invisible
     and keeps its own `CanQuery` handling in EnemyManager, where the rest of
     the submerged state lives. ]]
function EnemyModel.setHidden(skin: Skin, hidden: boolean)
	for _, part in skin.all do
		local resting = part:GetAttribute(RESTING_TRANSPARENCY)
		part.Transparency = if hidden then 1 else (if type(resting) == "number" then resting else 0)
	end
end

return EnemyModel
