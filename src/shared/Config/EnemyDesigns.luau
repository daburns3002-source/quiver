--!strict
--[[
	Rough-draft bodies for the five archetypes.

	Pure data. Parts are described relative to the centre of the archetype's
	hitbox, in that hitbox's own local space, and `EnemyModel` assembles them.
	Nothing here knows how a part gets built.

	These are grey-box drafts, not final art — Phase 5 replaces them with
	meshes from `assets/`. The job they have to do before then is narrower
	than looking good: a player glancing at a busy room has to be able to tell
	which archetype is about to do what to them, from the silhouette alone, on
	a phone, from directly overhead. So each design is built around the one
	thing that archetype does:

	  Charger  horns, forward lean, low to the ground      — it is coming at you
	  Spitter  a sac and three nozzles                     — three shots, a fan
	  Lancer   tall and thin behind one long barrel        — one shot, a line
	  Bulwark  a slab of shield wider than its own body    — it is terrain
	  Lurker   snout, dorsal fin, reared up over a low body — it was underground

	**Everything must fit inside the hitbox.** The player aims at what they can
	see, and an archetype drawn wider than the box the server sweeps produces
	exactly the complaint that cost two playtests: shots that visibly connect
	and do nothing. `tests/EnemyDesigns.spec.luau` enforces the fit in both
	directions — nothing may stick out, and the body may not rattle around
	inside a box far bigger than itself either.

	Forward is **-Z**, because that is where `CFrame.lookAt` points its
	LookVector, and `EnemyManager` faces an enemy with exactly that call.
]]

--[[ Which primitive a part is drawn with. `Wedge` builds a WedgePart; the
     rest are PartTypes. ]]
export type DesignShape = "Block" | "Ball" | "Cylinder" | "Wedge"

export type DesignPart = {
	name: string,
	size: Vector3,
	--[[ From the centre of the hitbox, in its local space. Forward is -Z. ]]
	offset: Vector3,
	shape: DesignShape,
	--[[ Multiplier on the archetype's configured colour, so an archetype's
	     identity stays a single number in Balance rather than being restated
	     in five places here. Above 1 brightens. ]]
	shade: number,
	--[[ Degrees about the local axes. Only used where a primitive's own axis
	     points the wrong way — cylinders lie along X, wedges slope towards
	     +Z — so most parts leave it out. ]]
	rotation: Vector3?,
	material: Enum.Material?,
	--[[ Whether the telegraph flash, the hit flash and the burrow fade reach
	     this part. False for things that should stay legible as trim while
	     the body changes colour underneath them. ]]
	tint: boolean?,
}

export type Design = { DesignPart }

--[[ Set on every part `EnemyModel` builds, so the client can find a body to
     flash without knowing anything about these tables. ]]
local SKIN_TAG = "EnemySkin"

--[[ Set on the subset that responds to tinting, for the same reason. ]]
local TINT_TAG = "EnemyTint"

--[[
	Melee rush. Low, leaning, and all of its detail at the front — read from
	above it should look like something already mid-charge.
]]
local charger: Design = {
	{
		name = "Body",
		shape = "Block",
		size = Vector3.new(2.4, 2.2, 2.6),
		offset = Vector3.new(0, -0.5, 0),
		shade = 1,
	},
	{
		name = "Head",
		shape = "Ball",
		size = Vector3.new(1.8, 1.8, 1.8),
		offset = Vector3.new(0, 1.3, -0.5),
		shade = 0.88,
	},
	{
		name = "HornLeft",
		shape = "Wedge",
		size = Vector3.new(0.35, 0.8, 1.0),
		offset = Vector3.new(-0.6, 1.8, -0.9),
		rotation = Vector3.new(0, 180, 0),
		shade = 1.45,
		tint = false,
	},
	{
		name = "HornRight",
		shape = "Wedge",
		size = Vector3.new(0.35, 0.8, 1.0),
		offset = Vector3.new(0.6, 1.8, -0.9),
		rotation = Vector3.new(0, 180, 0),
		shade = 1.45,
		tint = false,
	},
	{
		name = "LegLeft",
		shape = "Block",
		size = Vector3.new(0.6, 1.4, 0.7),
		offset = Vector3.new(-0.75, -1.8, 0.1),
		shade = 0.65,
	},
	{
		name = "LegRight",
		shape = "Block",
		size = Vector3.new(0.6, 1.4, 0.7),
		offset = Vector3.new(0.75, -1.8, 0.1),
		shade = 0.65,
	},
}

--[[
	Spread ranged. A sac that visibly holds something, and three nozzles —
	one per projectile in its fan, so the count is readable before it fires.
]]
local spitter: Design = {
	{
		name = "Sac",
		shape = "Ball",
		size = Vector3.new(2.8, 2.8, 2.8),
		offset = Vector3.new(0, -0.4, 0),
		shade = 1,
	},
	{
		name = "Hump",
		shape = "Ball",
		size = Vector3.new(1.6, 1.6, 1.6),
		offset = Vector3.new(0, 1.3, 0.5),
		shade = 0.8,
	},
	{
		name = "NozzleCentre",
		shape = "Cylinder",
		size = Vector3.new(1.1, 0.5, 0.5),
		offset = Vector3.new(0, 0.2, -0.95),
		rotation = Vector3.new(0, 90, 0),
		shade = 1.4,
		material = Enum.Material.Neon,
		tint = false,
	},
	{
		name = "NozzleLeft",
		shape = "Cylinder",
		size = Vector3.new(1.0, 0.45, 0.45),
		offset = Vector3.new(-0.85, -0.4, -0.85),
		rotation = Vector3.new(0, 90, 0),
		shade = 1.4,
		material = Enum.Material.Neon,
		tint = false,
	},
	{
		name = "NozzleRight",
		shape = "Cylinder",
		size = Vector3.new(1.0, 0.45, 0.45),
		offset = Vector3.new(0.85, -0.4, -0.85),
		rotation = Vector3.new(0, 90, 0),
		shade = 1.4,
		material = Enum.Material.Neon,
		tint = false,
	},
	{
		name = "FootLeft",
		shape = "Block",
		size = Vector3.new(0.6, 0.8, 0.8),
		offset = Vector3.new(-0.8, -2.1, 0.2),
		shade = 0.7,
	},
	{
		name = "FootRight",
		shape = "Block",
		size = Vector3.new(0.6, 0.8, 0.8),
		offset = Vector3.new(0.8, -2.1, 0.2),
		shade = 0.7,
	},
}

--[[
	Line ranged. Tall and narrow so it reads as a different class of thing at
	a glance, with one long barrel that says which way the line will go during
	the nine-tenths of a second the player has to step off it.
]]
local lancer: Design = {
	{
		name = "Base",
		shape = "Block",
		size = Vector3.new(2.2, 0.6, 2.0),
		offset = Vector3.new(0, -2.2, 0),
		shade = 0.7,
	},
	{
		name = "Stalk",
		shape = "Block",
		size = Vector3.new(1.1, 2.6, 1.1),
		offset = Vector3.new(0, -0.6, 0),
		shade = 0.85,
	},
	{
		name = "Head",
		shape = "Block",
		size = Vector3.new(1.8, 1.1, 1.6),
		offset = Vector3.new(0, 1.3, 0),
		shade = 1,
	},
	{
		name = "Lance",
		shape = "Block",
		size = Vector3.new(0.35, 0.35, 2.6),
		offset = Vector3.new(0, 1.3, -0.2),
		shade = 1.5,
		material = Enum.Material.Neon,
		tint = false,
	},
	{
		name = "Vane",
		shape = "Wedge",
		size = Vector3.new(0.25, 0.9, 0.8),
		offset = Vector3.new(0, 2.0, 0.4),
		shade = 1.1,
	},
}

--[[
	Tank. The shield is wider than the body behind it and sits proud of it,
	because the thing it needs to communicate is not "tough" but "you are not
	getting through here" — the teardown's note is to treat it as terrain.
]]
local bulwark: Design = {
	{
		name = "Shield",
		shape = "Block",
		size = Vector3.new(5.4, 5.6, 0.9),
		offset = Vector3.new(0, 0, -2.0),
		shade = 1.1,
	},
	{
		name = "Body",
		shape = "Block",
		size = Vector3.new(4.0, 4.6, 3.0),
		offset = Vector3.new(0, 0, 0.3),
		shade = 0.85,
	},
	{
		name = "Head",
		shape = "Block",
		size = Vector3.new(1.8, 1.2, 1.8),
		offset = Vector3.new(0, 3.2, 0.4),
		shade = 1,
	},
	{
		name = "ShoulderLeft",
		shape = "Block",
		size = Vector3.new(1.1, 1.5, 1.5),
		offset = Vector3.new(-2.3, 2.2, 0.3),
		shade = 0.95,
	},
	{
		name = "ShoulderRight",
		shape = "Block",
		size = Vector3.new(1.1, 1.5, 1.5),
		offset = Vector3.new(2.3, 2.2, 0.3),
		shade = 0.95,
	},
	{
		name = "FootLeft",
		shape = "Block",
		size = Vector3.new(1.4, 1.2, 1.8),
		offset = Vector3.new(-1.3, -3.4, 0.3),
		shade = 0.6,
	},
	{
		name = "FootRight",
		shape = "Block",
		size = Vector3.new(1.4, 1.2, 1.8),
		offset = Vector3.new(1.3, -3.4, 0.3),
		shade = 0.6,
	},
}

--[[
	Hidden. A low, heavy body with a digging snout, reared up at the front —
	it only ever exists above ground in the moment it is attacking, so the
	draft is the surfaced pose rather than the travelling one. The dorsal fin
	is the part that stays recognisable once the rest fades out on a dive.
]]
local lurker: Design = {
	{
		name = "Body",
		shape = "Block",
		size = Vector3.new(2.0, 1.6, 2.6),
		offset = Vector3.new(0, -1.6, 0.2),
		shade = 1,
	},
	{
		name = "Neck",
		shape = "Block",
		size = Vector3.new(1.4, 1.8, 1.2),
		offset = Vector3.new(0, -0.2, -0.5),
		shade = 0.9,
	},
	{
		name = "Head",
		shape = "Block",
		size = Vector3.new(1.5, 1.2, 1.6),
		offset = Vector3.new(0, 1.5, -0.6),
		shade = 0.95,
	},
	{
		name = "Snout",
		shape = "Wedge",
		size = Vector3.new(1.1, 1.0, 1.2),
		offset = Vector3.new(0, 1.4, -0.85),
		rotation = Vector3.new(0, 180, 0),
		shade = 1.45,
		tint = false,
	},
	{
		name = "Fin",
		shape = "Wedge",
		size = Vector3.new(0.3, 1.5, 1.6),
		offset = Vector3.new(0, 0.3, 0.6),
		shade = 1.3,
		tint = false,
	},
	{
		name = "ClawLeft",
		shape = "Wedge",
		size = Vector3.new(0.25, 0.7, 1.0),
		offset = Vector3.new(-0.95, -2.1, -0.6),
		rotation = Vector3.new(0, 180, 0),
		shade = 1.2,
	},
	{
		name = "ClawRight",
		shape = "Wedge",
		size = Vector3.new(0.25, 0.7, 1.0),
		offset = Vector3.new(0.95, -2.1, -0.6),
		rotation = Vector3.new(0, 180, 0),
		shade = 1.2,
	},
}

--[[ Keyed by `EnemyConfig.displayName`, which is what the model is named and
     the only identifier an archetype actually carries. ]]
local EnemyDesigns = {
	SkinTag = SKIN_TAG,
	TintTag = TINT_TAG,

	Charger = charger,
	Spitter = spitter,
	Lancer = lancer,
	Bulwark = bulwark,
	Lurker = lurker,
}

return table.freeze(EnemyDesigns)
