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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)

type EnemyConfig = Balance.EnemyConfig
type DesignPart = EnemyDesigns.DesignPart

local EnemyModel = {}

--[[ What `EnemyManager` needs back to drive the body: everything drawn, and
     the subset that responds to a colour change. ]]
export type Skin = {
	all: { BasePart },
	tintable: { BasePart },
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

local function buildPart(spec: DesignPart, config: EnemyConfig): BasePart
	local part: BasePart

	if spec.shape == "Wedge" then
		part = Instance.new("WedgePart")
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
	part.Color = shaded(config.color, spec.shade)
	part.Material = spec.material or Enum.Material.SmoothPlastic

	--[[ Decoration, and nothing more. A skin part that answered queries would
	     silently widen the hitbox the whole combat system is built around. ]]
	part.CanQuery = false
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Anchored = false

	part:SetAttribute(EnemyDesigns.SkinTag, true)

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

	local design = (EnemyDesigns :: any)[config.displayName] :: { DesignPart }?
	local skin: Skin = { all = {}, tintable = {} }

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
	end

	return model, hitbox, skin
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
	local design = (EnemyDesigns :: any)[config.displayName] :: { DesignPart }?

	if not design then
		for _, part in skin.all do
			part.Color = config.color
		end
		return
	end

	for index, spec in design do
		local part = skin.all[index]
		if part then
			part.Color = shaded(config.color, spec.shade)
		end
	end
end

--[[ Hides or shows the whole body for a dive. The hitbox is already invisible
     and keeps its own `CanQuery` handling in EnemyManager, where the rest of
     the submerged state lives. ]]
function EnemyModel.setHidden(skin: Skin, hidden: boolean)
	for _, part in skin.all do
		part.Transparency = if hidden then 1 else 0
	end
end

return EnemyModel
