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
	--[[ For a mesh: the image painted over it, for a mesh that carries a
	     texture instead of vertex colours. ]]
	textureId: string?,
	--[[ For a skinned mesh: its `Config/EnemyRigs` entry, whose bones are
	     built into it and which `Fx/EnemyRig` animates. ]]
	rig: string?,
	--[[ A bone of the rigged body this part rides on, so it follows the
	     animation: eyes on the head. ]]
	bone: string?,
	--[[ An eye: what an `Eyes` tell turns red (`EnemyModel.tintEyes`). ]]
	eye: boolean?,
	--[[ For a part of an imported model (`Imported`): its true size where
	     Roblox would clamp it to 0.001 (a lash link tucked away until a clip
	     scales it up), and its GLB material's name, which a flash looks for
	     (a boss's gems). ]]
	restSize: Vector3?,
	surface: string?,
}

export type Design = { DesignPart }

--[[
	An archetype whose body is a model the owner imported whole (a Claude
	Design rig that plays its own clips), on top of its `Design` (a shadow).
	`model` names its `Config/ImportedModels` entry (from
	tools/imports_to_luau.py) and `clips` its `Config/ModelClips` one. It is
	scaled to fill the hitbox and stood on its floor. Parts whose names
	match `eyes` (a Lua pattern) are its eyes: Neon in `eyeColor`. `stretch`
	names the joint a lash's length stretches (`ModelClipStretch`) and the
	joints under it that keep their own size.
]]
export type ImportedDesign = {
	model: string,
	clips: string,
	eyes: string,
	eyeColor: Color3,
	stretch: { joint: string, keep: { string } }?,
}

--[[ Set on every part `EnemyModel` builds, so the client can find a body to
     flash without knowing anything about these tables. ]]
local SKIN_TAG = "EnemySkin"

--[[ Set on the subset that responds to tinting, for the same reason. ]]
local TINT_TAG = "EnemyTint"

local BLACK = Color3.fromRGB(28, 24, 36)
local WHITE = Color3.fromRGB(250, 250, 255)
--[[ Every blocky import faces +Z as Studio brings it in. ]]
local BLOCKY_TURN = Vector3.new(0, 180, 0)
--[[ Act 1's eye colour, the glow every Mossy Glade enemy's eyes share. ]]
local EYE_AMBER = Color3.fromRGB(255, 176, 32)
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
--[[ Since 2026-10-23: the blocky Moss Slime (Claude Design, 2026-10-23). From
     `assets/models/enemies/blocky/` through `optimise_blocky_enemy.py`, imported
     by the owner: Body with the model's colours on its vertices, glowing
     Eyes in the act's amber. Turned 180° like every import, scaled to fill
     its hitbox. ]]
local charger: Design = {
	shadow(3, 2.6, 2.7),
	{
		name = "Body",
		shape = "Mesh",
		meshId = "rbxassetid://125178064043003",
		size = Vector3.new(2.898, 2.687, 2.509),
		offset = Vector3.new(0, -0.007, 0),
		rotation = BLOCKY_TURN,
		shade = 1,
		color = WHITE,
	},
	{
		name = "Eyes",
		shape = "Mesh",
		meshId = "rbxassetid://125381875352776",
		size = Vector3.new(1.209, 0.297, 0.006),
		offset = Vector3.new(-0.038, -0.642, -1.066),
		rotation = BLOCKY_TURN,
		shade = 1,
		-- Act 1's eye colour (amber), glowing.
		color = EYE_AMBER,
		material = Enum.Material.Neon,
		tint = false,
	},
}

--[[
	Spread ranged: the Splitter Spitter, Act 1's seed-spitter (the Sprout Spitter and
	Sprout Slime until the owner renamed it, 2026-10-26) — a lime jelly with a two-leaf
	sprout, a mossy cap, little mushrooms, amber eye sockets and a round
	spout of a mouth it lobs its fan of seeds from.

	From `assets/models/enemies/sprout_spitter_roblox.glb` (Claude Design,
	slimmed by `optimise_enemy.py`, imported 2026-10-22). Turned 180° like
	the Moss Slime, scaled ×2.45 into a hitbox cut to fit it, 3 × 3.6 × 3.
]]
--[[ Since 2026-10-23: the blocky Splitter Spitter, a seed-nozzle face (Claude Design, 2026-10-23). From
     `assets/models/enemies/blocky/` through `optimise_blocky_enemy.py`, imported
     by the owner: Body with the model's colours on its vertices, glowing
     Eyes in the act's amber. Turned 180° like every import, scaled to fill
     its hitbox. ]]
local spitter: Design = {
	shadow(3, 3, 3.2),
	{
		name = "Body",
		shape = "Mesh",
		meshId = "rbxassetid://76698920241435",
		size = Vector3.new(2.968, 3.184, 2.971),
		offset = Vector3.new(0, -0.007, 0),
		rotation = BLOCKY_TURN,
		shade = 1,
		color = WHITE,
	},
	{
		name = "Eyes",
		shape = "Mesh",
		meshId = "rbxassetid://123343390761433",
		size = Vector3.new(1.428, 0.487, 0.014),
		offset = Vector3.new(0, -0.265, -1.280),
		rotation = BLOCKY_TURN,
		shade = 1,
		-- Act 1's eye colour (amber), glowing.
		color = EYE_AMBER,
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
--[[ Since 2026-10-23: the blocky Mother Slime, babies riding on it (Claude Design, 2026-10-23). From
     `assets/models/enemies/blocky/` through `optimise_blocky_enemy.py`, imported
     by the owner: Body with the model's colours on its vertices, glowing
     Eyes in the act's amber. Turned 180° like every import, scaled to fill
     its hitbox. ]]
local broodSlime: Design = {
	shadow(4.0, 3.5, 4.6),
	{
		name = "Body",
		shape = "Mesh",
		meshId = "rbxassetid://78769820606735",
		size = Vector3.new(3.953, 4.515, 3.469),
		offset = Vector3.new(0, -0.041, 0.007),
		rotation = BLOCKY_TURN,
		shade = 1,
		color = WHITE,
	},
	{
		name = "Eyes",
		shape = "Mesh",
		meshId = "rbxassetid://97009288373667",
		size = Vector3.new(2.603, 1.789, 3.401),
		offset = Vector3.new(0.024, -1.291, -0.041),
		rotation = BLOCKY_TURN,
		shade = 1,
		-- Act 1's eye colour (amber), glowing.
		color = EYE_AMBER,
		material = Enum.Material.Neon,
		tint = false,
	},
}

--[[
	The Slime King, King Bloblin (the owner's King Bloblin Fight, Claude
	Design, 2026-10-24): one blocky rig with all 22 of his clips, from
	`assets/models/bosses/king_bloblin_blocky/KingBloblin_Fight.glb`,
	imported whole by the owner. His body is that import (`Imported`,
	below), built by `EnemyModel` from `Config/ImportedModels/KingBloblin`
	and scaled to fill his 9.6 × 9.6 × 8 hitbox; only his shadow is drawn
	from here. His clips play on the beats of his moves (`Balance` boss
	`clips`, `Fx/ModelAnimator`), his lash chain stretched to the lane.
]]
local slimeKing: Design = {
	shadow(9.6, 8.0, 9.6),
}

--[[ Thornwood's enemies (Level 2), every one an imported model that plays
     its own clips (`Imported` below): their designs are only shadows. ]]
local brambleBoar: Design = { shadow(3, 3.8, 2.7) }
local burrThistle: Design = { shadow(3.2, 2.4, 3.8) }
local brambleSow: Design = { shadow(3.9, 5.4, 4.1) }
local boarlet: Design = { shadow(2.15, 3, 2.25) }
local brambleLurker: Design = { shadow(4.5, 4.5, 3.3) }
local broodmother: Design = { shadow(10.3, 6.2, 6.2) }
local thornling: Design = { shadow(2.4, 1.85, 1.8) }

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
	BoneTag = "RidesBone",
	EyeTag = "Eye",

	Charger = charger,
	Spitter = spitter,
	-- The Lancer is benched while the Ember Wilf stands in for it (`Balance`).
	Bulwark = bulwark,
	Lurker = lurker,
	BroodSlime = broodSlime,
	BabySlime = babySlime,
	SlimeKing = slimeKing,
	BrambleBoar = brambleBoar,
	BurrThistle = burrThistle,
	BrambleSow = brambleSow,
	Boarlet = boarlet,
	BrambleLurker = brambleLurker,
	Broodmother = broodmother,
	Thornling = thornling,

	--[[ Archetypes built from an imported model, by display name. ]]
	Imported = {
		SlimeKing = {
			model = "KingBloblin",
			clips = "KingBloblin",
			-- Eye_L, Eye_R and every Eye_Baby*_L / _R: Act 1's amber, glowing
			eyes = "^Eye_",
			eyeColor = EYE_AMBER,
			stretch = {
				joint = "LashRoot",
				-- every link keeps its size: the lane spaces them, never flattens them
				keep = {
					"LashLink_1_Joint",
					"LashLink_2_Joint",
					"LashLink_3_Joint",
					"LashLink_4_Joint",
					"LashLink_5_Joint",
					"LashLink_6_Joint",
					"LashLink_7_Joint",
					"LashLink_8_Joint",
					"LashLink_9_Joint",
					"LashLink_10_Joint",
					"LashLink_11_Joint",
					"LashLink_12_Joint",
					"LashFist_Joint",
				},
			},
		} :: ImportedDesign,
		--[[ Thornwood (Level 2): each its own model and clips, with Act 1's
		     amber, glowing eyes (Eye_L, Eye_R and the Broodmother's
		     Eye_Small_*; not the glints, pupils, sockets or rims). ]]
		BrambleBoar = {
			model = "BrambleBoar",
			clips = "BrambleBoar",
			eyes = "^Eye_[LR]$",
			eyeColor = EYE_AMBER,
		},
		BurrThistle = {
			model = "BurrThistle",
			clips = "BurrThistle",
			eyes = "^Eye_[LR]$",
			eyeColor = EYE_AMBER,
		},
		BrambleSow = {
			model = "BrambleSow",
			clips = "BrambleSow",
			eyes = "^Eye_[LR]$",
			eyeColor = EYE_AMBER,
		},
		--[[ The Sow's own model, drawn to the Boarlet's smaller box. ]]
		Boarlet = {
			model = "BrambleSow",
			clips = "BrambleSow",
			eyes = "^Eye_[LR]$",
			eyeColor = EYE_AMBER,
		},
		BrambleLurker = {
			model = "BrambleLurker",
			clips = "BrambleLurker",
			eyes = "^Eye_[LR]$",
			eyeColor = EYE_AMBER,
		},
		Thornling = {
			model = "Thornling",
			clips = "Thornling",
			eyes = "^Eye_[LR]$",
			eyeColor = EYE_AMBER,
		},
		Broodmother = {
			model = "Broodmother",
			clips = "Broodmother",
			eyes = "^Eye_[LRS][^G]*$",
			eyeColor = EYE_AMBER,
		},
	},
}

return table.freeze(EnemyDesigns)
