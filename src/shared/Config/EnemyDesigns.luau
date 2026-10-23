--!strict
--[[
	Bodies for the five archetypes, in Archero 2's style.

	Pure data. Parts are described relative to the centre of the archetype's
	hitbox, in that hitbox's own local space, and `EnemyModel` assembles them.
	Nothing here knows how a part gets built.

	The style, from docs/ART-archero2.md: small round "vinyl toy" creatures,
	each one silhouette, one strong colour and **glowing eyes**, so a player
	glancing at a busy room on a phone can tell them apart from directly
	overhead. Each design still says what its archetype does:

	  Charger  ladybug beetle, low dome, head first   - it is coming at you
	  Spitter  one-eyed slime, glossy teardrop        - it lobs blobs
	  Lancer   hooded mage with a staff, tall, thin   - one aimed shot
	  Bulwark  rock-shell brute behind a round shield - it is terrain
	  Lurker   spiked urchin, glowing spikes all round - it comes up under you

	Phase 5 replaces these with meshes from `assets/`; until then they are
	built from primitives, plus `Ellipsoid` for the squashed rounded shapes a
	Ball part cannot make (a Ball is always a perfect sphere).

	**Everything must fit inside the hitbox.** The player aims at what they can
	see, and an archetype drawn wider than the box the server sweeps produces
	exactly the complaint that cost two playtests: shots that visibly connect
	and do nothing. `tests/EnemyDesigns.spec.luau` enforces the fit in both
	directions: nothing may stick out, and the body may not rattle around
	inside a box far bigger than itself either.

	Forward is **-Z**, because that is where `CFrame.lookAt` points its
	LookVector, and `EnemyManager` faces an enemy with exactly that call. The
	floor is at y = -half the hitbox's height.
]]

--[[ Which primitive a part is drawn with. `Wedge` builds a WedgePart; the
     rest are PartTypes. ]]
export type DesignShape = "Block" | "Ball" | "Cylinder" | "Wedge" | "Ellipsoid" | "Mesh"

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
	--[[ A fixed colour instead of a shade of the archetype's: eyes, spots,
	     spikes. The marks that make a creature stay the same colour whatever
	     the body is. ]]
	color: Color3?,
	--[[ How see-through the part is at rest, for a jelly body. Hiding and
	     showing the enemy returns to this rather than to solid. ]]
	transparency: number?, --[[ For `shape = "Mesh"`: the uploaded mesh. Built by `EnemyModel` from
	     a template made once with AssetService:CreateMeshPartAsync. ]]
	meshId: string?,
}

export type Design = { DesignPart }

--[[ Set on every part `EnemyModel` builds, so the client can find a body to
     flash without knowing anything about these tables. ]]
local SKIN_TAG = "EnemySkin"

--[[ Set on the subset that responds to tinting, for the same reason. ]]
local TINT_TAG = "EnemyTint"

local BLACK = Color3.fromRGB(28, 24, 36)
local WHITE = Color3.fromRGB(250, 250, 255)
local EYE_YELLOW = Color3.fromRGB(255, 226, 64)
local EYE_ORANGE = Color3.fromRGB(255, 150, 40)
local EYE_PINK = Color3.fromRGB(255, 96, 196)
local SPIKE_CYAN = Color3.fromRGB(90, 236, 255)
local WOOD = Color3.fromRGB(120, 84, 56)

--[[ A glowing marking that keeps its colour through every flash. ]]
local function glow(name: string, size: number, offset: Vector3, colour: Color3): DesignPart
	return {
		name = name,
		shape = "Ball",
		size = Vector3.one * size,
		offset = offset,
		shade = 1,
		color = colour,
		material = Enum.Material.Neon,
		tint = false,
	}
end

--[[ A fixed-colour marking: spots, legs, a pupil. ]]
local function mark(
	name: string,
	shape: DesignShape,
	size: Vector3,
	offset: Vector3,
	colour: Color3,
	rotation: Vector3?
): DesignPart
	return {
		name = name,
		shape = shape,
		size = size,
		offset = offset,
		rotation = rotation,
		shade = 1,
		color = colour,
		tint = false,
	}
end

--[[ An enemy's blob shadow, matched to Archero 2's (owner, 2026-10-22, from
     footage): one flat dark blob as wide as the body, a touch towards the
     camera, darkening the floor to about 60% (measured 81 against 134). ]]
local SHADOW_SPREAD = 1
local SHADOW_TOWARDS_CAMERA = 0.12
local SHADOW_COLOR = Color3.fromRGB(0, 0, 0)
--[[ 0.3 measures 59% on the lawn in Studio; 0.6 only reached 83%. ]]
local SHADOW_TRANSPARENCY = 0.3
--[[ Studs above the floor the blob is drawn at: over the ground and what
     lies on it — path stones, moss, the pond, low grass, which rise a few
     tenths of a stud and used to hide it — and still under the body, whose
     round base is widest well above this (owner, 2026-10-23: shadows over
     everything but the enemies and players). ]]
local SHADOW_LIFT = 0.4

--[[
	A soft dark disc on the floor under the body, which is how Archero 2
	grounds every character: a blob shadow rather than a cast one, so it
	reads the same on every device tier. Sits just above the floor of a
	hitbox `height` tall (`SHADOW_LIFT`), and never flashes.
]]
local function shadow(width: number, depth: number, height: number): DesignPart
	return {
		name = "Shadow",
		shape = "Ellipsoid",
		size = Vector3.new(width * SHADOW_SPREAD, 0.08, depth * SHADOW_SPREAD),
		offset = Vector3.new(0, -height / 2 + SHADOW_LIFT, depth * SHADOW_TOWARDS_CAMERA),
		shade = 1,
		--[[ Matte: black plastic caught the sun and read as a flat grey disc
		     on the lawn. ]]
		color = SHADOW_COLOR,
		material = Enum.Material.Fabric,
		transparency = SHADOW_TRANSPARENCY,
		tint = false,
	}
end

--[[
	Melee rush: the Moss Slime, Act 1's grunt (docs/ENEMIES-AND-ARENAS.md) —
	the first enemy built from a real model rather than primitives: a jelly
	dome under a shaggy moss cap, little mushrooms, two amber eye sockets.

	From `assets/models/enemies/moss_slime_roblox.glb` (made in Claude Design,
	slimmed by `optimise_moss_slime.py`, imported 2026-10-22). The model faces
	+Z after import, so every part is turned 180° and its offset mirrored.
	Scaled ×1.89, the most that keeps it inside the 3-stud-wide hitbox, and
	the hitbox is cut to fit it: 3 × 2.2 × 3 (`Balance`).

	Body and Decor carry the model's own vertex colours, so they are white
	(colour × white = the painted colour). The eyes glow the act's colour.
]]
local MOSS_SLIME_TURN = Vector3.new(0, 180, 0)
local charger: Design = {
	shadow(2.9, 2.9, 2.2),
	{
		name = "Body",
		shape = "Mesh",
		meshId = "rbxassetid://78283705651192",
		size = Vector3.new(2.460, 1.881, 2.236),
		offset = Vector3.new(-0.077, -0.160, -0.024),
		rotation = MOSS_SLIME_TURN,
		shade = 1,
		color = WHITE,
	},
	{
		name = "Decor",
		shape = "Mesh",
		meshId = "rbxassetid://122593286662953",
		size = Vector3.new(2.986, 1.896, 2.244),
		offset = Vector3.new(0, 0.087, 0.020),
		rotation = MOSS_SLIME_TURN,
		shade = 1,
		color = WHITE,
		tint = false,
	},
	{
		name = "Eyes",
		shape = "Mesh",
		meshId = "rbxassetid://137939916650483",
		size = Vector3.new(1.467, 0.644, 0.335),
		offset = Vector3.new(-0.119, -0.272, -0.950),
		rotation = MOSS_SLIME_TURN,
		shade = 1,
		-- Act 1's eye colour (amber), glowing.
		color = Color3.fromRGB(255, 176, 32),
		material = Enum.Material.Neon,
		tint = false,
	},
}

--[[
	Spread ranged: the Sprout Spitter, Act 1's seed-spitter (the "Sprout
	Slime" of docs/ENEMIES-AND-ARENAS.md) — a lime jelly with a two-leaf
	sprout, a mossy cap, little mushrooms, amber eye sockets and a round
	spout of a mouth it lobs its fan of seeds from.

	From `assets/models/enemies/sprout_spitter_roblox.glb` (Claude Design,
	slimmed by `optimise_enemy.py`, imported 2026-10-22). Turned 180° like
	the Moss Slime, scaled ×2.45 into a hitbox cut to fit it, 3 × 3.6 × 3.
]]
local SPROUT_TURN = Vector3.new(0, 180, 0)
local spitter: Design = {
	shadow(2.9, 2.9, 3.6),
	{
		name = "Body",
		shape = "Mesh",
		meshId = "rbxassetid://125655555170241",
		size = Vector3.new(2.747, 2.475, 2.603),
		offset = Vector3.new(-0.060, -0.563, 0.192),
		rotation = SPROUT_TURN,
		shade = 1,
		color = WHITE,
	},
	{
		name = "Decor",
		shape = "Mesh",
		meshId = "rbxassetid://86695498504200",
		size = Vector3.new(2.803, 3.188, 2.851),
		offset = Vector3.new(0.032, 0.108, -0.068),
		rotation = SPROUT_TURN,
		shade = 1,
		color = WHITE,
		tint = false,
	},
	{
		name = "Eyes",
		shape = "Mesh",
		meshId = "rbxassetid://110667629055549",
		size = Vector3.new(1.688, 0.700, 0.487),
		offset = Vector3.new(-0.039, -0.720, -0.880),
		rotation = SPROUT_TURN,
		shade = 1,
		-- Act 1's eye colour (amber), glowing.
		color = Color3.fromRGB(255, 176, 32),
		material = Enum.Material.Neon,
		tint = false,
	},
}

--[[
	Line ranged: a hooded mage. Tall and narrow so it reads as a different
	class of thing at a glance, a dark face with one glowing eye under the
	hood, and a staff whose orb glows the colour of its single shot.
]]
local _lancer: Design = {
	shadow(2.6, 2.6, 5),
	{
		name = "Robe",
		shape = "Ellipsoid",
		size = Vector3.new(2.6, 2.6, 2.6),
		offset = Vector3.new(0, -1.2, 0.05),
		shade = 0.85,
	},
	{
		name = "Chest",
		shape = "Ball",
		size = Vector3.one * 1.9,
		offset = Vector3.new(0, 0.15, 0.05),
		shade = 0.95,
	},
	{
		name = "Hood",
		shape = "Ball",
		size = Vector3.one * 2.2,
		offset = Vector3.new(0, 1.25, 0.15),
		shade = 1,
	},
	{
		name = "HoodTip",
		shape = "Ball",
		size = Vector3.one * 0.9,
		offset = Vector3.new(0, 2.05, 0.55),
		shade = 1,
	},
	mark("Face", "Ball", Vector3.one * 1.4, Vector3.new(0, 1.15, -0.5), BLACK),
	glow("Eye", 0.6, Vector3.new(0, 1.2, -1.12), EYE_PINK),
	mark("Staff", "Block", Vector3.new(0.22, 3.6, 0.22), Vector3.new(1.15, -0.4, -0.7), WOOD),
	glow("StaffOrb", 0.6, Vector3.new(1.15, 1.6, -0.7), EYE_PINK),
}

--[[
	Tank: a rock-shell brute. A great round stone body hunched behind a
	rounded shield, a small head and glowing eyes above it. The thing it needs
	to say is not "tough" but "you are not getting through here".
]]
local bulwark: Design = {
	shadow(5.8, 5.8, 8),
	{
		name = "Shell",
		shape = "Ellipsoid",
		size = Vector3.new(5.6, 5.4, 5.2),
		offset = Vector3.new(0, -1.25, 0.35),
		shade = 0.85,
	},
	{
		name = "Shield",
		shape = "Ellipsoid",
		size = Vector3.new(5.2, 4.8, 1.2),
		offset = Vector3.new(0, -1.0, -2.3),
		shade = 1.15,
	},
	glow("ShieldBoss", 1.2, Vector3.new(0, -0.8, -2.35), EYE_ORANGE),
	{
		name = "Head",
		shape = "Ball",
		size = Vector3.one * 2.6,
		offset = Vector3.new(0, 2.15, -0.9),
		shade = 1,
	},
	{
		name = "Brow",
		shape = "Block",
		size = Vector3.new(2.1, 0.4, 0.6),
		offset = Vector3.new(0, 2.8, -1.9),
		shade = 0.6,
		tint = false,
	},
	glow("EyeLeft", 0.6, Vector3.new(-0.55, 2.3, -2.05), EYE_ORANGE),
	glow("EyeRight", 0.6, Vector3.new(0.55, 2.3, -2.05), EYE_ORANGE),
}

--[[
	Hidden: a spiked urchin. A round body with glowing spikes on every side
	and yellow eyes. It was underground, and it comes up spiny.
]]
local function spike(name: string, offset: Vector3, rotation: Vector3): DesignPart
	return {
		name = name,
		shape = "Cylinder",
		size = Vector3.new(1.0, 0.36, 0.36),
		offset = offset,
		rotation = rotation,
		shade = 1,
		color = SPIKE_CYAN,
		material = Enum.Material.Neon,
		tint = false,
	}
end

local lurker: Design = {
	shadow(2.6, 2.6, 5),
	{
		name = "Body",
		shape = "Ball",
		size = Vector3.one * 2.6,
		offset = Vector3.new(0, -1.05, 0),
		shade = 1,
	},
	spike("SpikeTop", Vector3.new(0, 0.55, 0), Vector3.new(0, 0, 90)),
	spike("SpikeLeft", Vector3.new(-1.0, -1.05, 0), Vector3.new(0, 0, 0)),
	spike("SpikeRight", Vector3.new(1.0, -1.05, 0), Vector3.new(0, 0, 0)),
	spike("SpikeBack", Vector3.new(0, -1.05, 1.0), Vector3.new(0, 90, 0)),
	spike("SpikeUpLeft", Vector3.new(-0.75, -0.05, 0), Vector3.new(0, 0, 45)),
	spike("SpikeUpRight", Vector3.new(0.75, -0.05, 0), Vector3.new(0, 0, -45)),
	spike("SpikeUpBack", Vector3.new(0, -0.05, 0.75), Vector3.new(0, 90, 45)),
	glow("EyeLeft", 0.55, Vector3.new(-0.42, -0.85, -1.15), EYE_YELLOW),
	glow("EyeRight", 0.55, Vector3.new(0.42, -0.85, -1.15), EYE_YELLOW),
	{
		name = "FootLeft",
		shape = "Ball",
		size = Vector3.one * 0.7,
		offset = Vector3.new(-0.6, -2.15, -0.2),
		shade = 0.7,
	},
	{
		name = "FootRight",
		shape = "Ball",
		size = Vector3.one * 0.7,
		offset = Vector3.new(0.6, -2.15, -0.2),
		shade = 0.7,
	},
}

--[[
	Elite melee: the Brood Slime — a big Moss Slime, four babies riding in
	its moss, a little mouth. Splits into Moss Slimes when it dies.

	From `assets/models/enemies/brood_slime_roblox.glb` (Claude Design,
	slimmed by `optimise_enemy.py`, imported 2026-10-22). Turned 180° like
	the Moss Slime, scaled ×2.05 into its 4.1 × 3.4 × 4.1 hitbox.
]]
local BROOD_TURN = Vector3.new(0, 180, 0)
local broodSlime: Design = {
	shadow(4, 4, 3.4),
	{
		name = "Body",
		shape = "Mesh",
		meshId = "rbxassetid://106787142698337",
		size = Vector3.new(4.000, 2.970, 4.017),
		offset = Vector3.new(0, -0.215, 0),
		rotation = BROOD_TURN,
		shade = 1,
		color = WHITE,
	},
	{
		name = "Decor",
		shape = "Mesh",
		meshId = "rbxassetid://117695519355503",
		size = Vector3.new(3.142, 3.150, 3.145),
		offset = Vector3.new(0.060, 0.025, 0.011),
		rotation = BROOD_TURN,
		shade = 1,
		color = WHITE,
		tint = false,
	},
	{
		name = "Eyes",
		shape = "Mesh",
		meshId = "rbxassetid://137720523915862",
		size = Vector3.new(1.161, 0.677, 0.225),
		offset = Vector3.new(0.052, -0.034, -1.418),
		rotation = BROOD_TURN,
		shade = 1,
		-- Act 1's eye colour (amber), glowing.
		color = Color3.fromRGB(255, 176, 32),
		material = Enum.Material.Neon,
		tint = false,
	},
}

--[[
	The Slime King, Mossy Glade's boss (the owner's
	design_handoff_slime_king, 2026-10-23): a crowned jelly in a mantle, two
	arms the Slime Lash throws.

	From `assets/models/bosses/king_bloblin/slime_king_roblox.glb`, slimmed
	by `optimise_enemy.py slime_king` to Body, Eyes, Decor (crown, mantle,
	collar, brooch, gems, feet, brows) and the two arms, imported by the
	owner (model 83216994830889). The importer turns it to face +Z, so every
	part is turned 180° and its offset mirrored; ×2, so he stands 9.8 studs
	tall. Sizes and offsets are the imported parts' own.

	Every part carries the model's own vertex colours, so all are white,
	the eyes included, in their cut sockets. The parts
	are posed by the server while he moves (`BossBody`), so the arms must be
	named `Arm_L` and `Arm_R`, as the lash looks them up.
]]
local KING_TURN = Vector3.new(0, 180, 0)
local slimeKing: Design = {
	shadow(7.6, 6, 9.8),
	{
		name = "Body",
		shape = "Mesh",
		meshId = "rbxassetid://134712175436166",
		size = Vector3.new(6.503, 7.641, 5.206),
		offset = Vector3.new(0.024, -0.492, -1.017),
		rotation = KING_TURN,
		shade = 1,
		color = WHITE,
	},
	{
		name = "Decor",
		shape = "Mesh",
		meshId = "rbxassetid://129228909981460",
		size = Vector3.new(9.578, 9.784, 7.197),
		offset = Vector3.new(0, -0.008, 0.022),
		rotation = KING_TURN,
		shade = 1,
		color = WHITE,
		tint = false,
	},
	{
		name = "Eyes",
		shape = "Mesh",
		meshId = "rbxassetid://109019496517574",
		size = Vector3.new(2.647, 1.171, 0.512),
		offset = Vector3.new(0.025, 2.114, -2.464),
		rotation = KING_TURN,
		shade = 1,
		--[[ As painted: dark eyes with amber glints. Unlike the grunts'
		     glowing act-coloured eyes, a flat glow would turn these into two
		     orange blobs (owner, 2026-10-23: the king should look like his
		     model). ]]
		color = WHITE,
		tint = false,
	},
	{
		name = "Arm_L",
		shape = "Mesh",
		meshId = "rbxassetid://102422066700070",
		size = Vector3.new(2.043, 2.225, 2.038),
		offset = Vector3.new(3.707, -0.824, -1.292),
		rotation = KING_TURN,
		shade = 1,
		color = WHITE,
	},
	{
		name = "Arm_R",
		shape = "Mesh",
		meshId = "rbxassetid://137805889967490",
		size = Vector3.new(2.043, 2.228, 2.038),
		offset = Vector3.new(-3.656, -0.826, -1.292),
		rotation = KING_TURN,
		shade = 1,
		color = WHITE,
	},
}

--[[
	The Ember Wolf (owner, 2026-10-23), after the owner's dog: a round
	ginger pup with a cream chest, muzzle and paws.

	From `assets/models/enemies/ember_wolf_roblox.glb` (one mesh, slimmed by
	`optimise_enemy.py ember_wolf`), imported by the owner (model
	117724324166248). Turned 180° like the slimes, ×2.6 into its
	2.2 × 3 × 3.3 hitbox (`Balance`). The mesh carries its own colours, so it
	is white.

	The eyes are painted into that one mesh, so they cannot glow on their
	own: two Neon discs in the slimes' amber sit over them (owner: "make
	sure the wolf's eyes glow like the slimes eyes bright orange"), placed
	where the mesh paints them, measured from its vertex colours.
]]
local WOLF_TURN = Vector3.new(0, 180, 0)
local WOLF_EYES = Color3.fromRGB(255, 176, 32)
local wolf: Design = {
	shadow(2.2, 3.3, 3),
	{
		name = "Body",
		shape = "Mesh",
		meshId = "rbxassetid://126878330603727",
		size = Vector3.new(2.19, 2.992, 3.216),
		offset = Vector3.new(0, -0.004, 0),
		rotation = WOLF_TURN,
		shade = 1,
		color = WHITE,
	},
	{
		name = "EyeLeft",
		shape = "Ellipsoid",
		size = Vector3.new(0.36, 0.3, 0.12),
		offset = Vector3.new(-0.39, 0.37, -1.28),
		shade = 1,
		color = WOLF_EYES,
		material = Enum.Material.Neon,
		tint = false,
	},
	{
		name = "EyeRight",
		shape = "Ellipsoid",
		size = Vector3.new(0.36, 0.3, 0.12),
		offset = Vector3.new(0.39, 0.37, -1.28),
		shade = 1,
		color = WOLF_EYES,
		material = Enum.Material.Neon,
		tint = false,
	},
}

--[[
	The Baby Slime (the owner's updated slimes, 2026-10-23): a small green
	jelly dome with a tuft of moss. A stand-in of primitives in its model's
	proportions (×2, in its 2.5 × 1.5 hitbox) until the owner imports
	`assets/models/enemies/baby_slime_roblox.glb`.
]]
local BABY_GREEN = Color3.fromRGB(127, 203, 36)
local babySlime: Design = {
	shadow(2.5, 2.5, 1.5),
	{
		name = "Body",
		shape = "Ellipsoid",
		size = Vector3.new(2.5, 1.2, 2.4),
		offset = Vector3.new(0, -0.15, 0),
		shade = 1,
		color = BABY_GREEN,
	},
	mark(
		"Moss",
		"Ellipsoid",
		Vector3.new(1.4, 0.35, 1.6),
		Vector3.new(0, 0.38, 0.1),
		Color3.fromRGB(70, 120, 40)
	),
	glow("EyeLeft", 0.32, Vector3.new(-0.3, 0.02, -0.95), Color3.fromRGB(255, 176, 32)),
	glow("EyeRight", 0.32, Vector3.new(0.3, 0.02, -0.95), Color3.fromRGB(255, 176, 32)),
}

--[[ Keyed by `EnemyConfig.displayName`, which is what the model is named and
     the only identifier an archetype actually carries. ]]
local EnemyDesigns = {
	SkinTag = SKIN_TAG,
	TintTag = TINT_TAG,

	Charger = charger,
	Spitter = spitter,
	-- The Lancer is benched while the Ember Wolf stands in for it (`Balance`).
	Bulwark = bulwark,
	Lurker = lurker,
	BroodSlime = broodSlime,
	BabySlime = babySlime,
	SlimeKing = slimeKing,
	Wolf = wolf,
}

return table.freeze(EnemyDesigns)
