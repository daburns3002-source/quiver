--!strict
--[[
	Held weapons: the model each class carries and the animations its arms
	play.

	Presentation only. Built on the server so every player sees it
	(`Combat/HeldWeapon`), welded to a hand, never colliding, answering a
	raycast or stopping a shot. The arms are posed on each client
	(`Fx/WeaponPose`, from `Config/WeaponAnimations`), the bow's string, the
	staff's orb and the sword's swing trail drawn there too (`Fx/BowString`,
	`Fx/StaffOrb`, `Fx/SwingTrail`).

	Models follow the enemy pipeline: GLB from Claude Design →
	`assets/models/weapons/optimise_weapon.py` → imported in Studio → mesh ids
	and sizes here. `size` and `offset` are in the model's own units, offsets
	from the grip (where the hand closes), axes as Studio imports them: the
	long axis up (Y), the arrow pointing +Z.
]]

export type WeaponPart = {
	name: string,
	meshId: string,
	size: Vector3,
	offset: Vector3,
	--[[ Drawn Neon, for a gem. ]]
	glow: boolean?,
	--[[ A colour map, for a model whose colours are baked into textures
	     rather than its vertices (the greatsword kit's). ]]
	textureId: string?,
	--[[ The part's colour, when not white (which lets the model's own
	     colours show). Neon shows this colour and nothing else. ]]
	colour: Color3?,
	--[[ Hidden on the weapon; the client draws its own copy on the string
	     while an arrow is nocked (`Fx/BowString`). ]]
	nocked: boolean?,
	--[[ Hidden for the local player, who sees the live string instead. ]]
	liveString: boolean?,
	--[[ A staff's orb, and the ring of small orbs round it: hidden for the
	     local player, who sees copies that swell, glow and spin as a cast
	     charges (`Fx/StaffOrb`). ]]
	orb: boolean?,
	orbit: boolean?,
	--[[ Turned half round about its own Y: a skin modelled facing the other
	     way from its base weapon (`assets/models/weapons/skins_to_luau.py`). ]]
	turned: boolean?,
	--[[ A further turn about its own Y, radians, on top of `turned`. Tripo
	     models do not share one convention: three of the Drowned Village bows
	     are modelled with the limbs curving in XY where the Twig Bow's curve
	     is in YZ, so they face sideways in the hand without this. ]]
	yaw: number?,
}

--[[ Which of the weapon's `Config/WeaponAnimations` clips plays when:
     `hold` with nothing to shoot (and while moving, unless the weapon has
     a `move` clip of its own), `ready` on stopping with a target (drawing,
     charging) and `aim` looping after it, and `fire` on each shot, after
     which `ready` plays again. A weapon without `ready` holds until its
     first shot. `fire` is a combo: each shot plays the next, round and
     round, keeping its place however long the wielder moves between
     shots (`Shared/Combat/WeaponTiming`). ]]
export type Clips = {
	hold: string,
	move: string?,
	--[[ Studs a second the `move` clip was made for; it plays faster or
	     slower to match how fast the character goes. ]]
	moveSpeed: number?,
	ready: string?,
	aim: string?,
	fire: { string },
	--[[ The role after a shot while still aiming: `ready` (the default)
	     draws again, as the single bow nocks each arrow; `aim` holds up
	     and fires again, as the dual bows raise once and take turns. ]]
	afterFire: ("ready" | "aim")?,
	--[[ A layer under all of these for the joints a clip leaves out: `idle`
	     standing, `walk` moving, played faster or slower to match the
	     character's speed against `walkSpeed`, the studs a second it was
	     made for. The bow's Hold moves only the upper body, and these give
	     it the owner's stance and stride (`LeafBow_R15_Kit`). ]]
	legs: { idle: string, walk: string, walkSpeed: number }?,
	--[[ One-off clips a card plays on its own, by name (`WeaponPose.playSpecial`):
	     the greatsword's Earthbreaker leap and slam. ]]
	special: { [string]: string }?,
}

export type Weapon = {
	--[[ The hand it is welded to. ]]
	hand: string,
	--[[ Studs per model unit. ]]
	scale: number,
	--[[ Where the grip sits in the hand's own frame, studs. ]]
	grip: Vector3,
	--[[ How the model is turned in the hand, when not the bow's and the
	     staff's (upright, pointing where the fingers do). ]]
	inHand: CFrame?,
	--[[ A second copy of the model in another hand (a bow in each), at its
	     own grip; turned like the first unless it says otherwise. ]]
	offhand: { hand: string, grip: Vector3, inHand: CFrame? }?,
	--[[ A swing trail, between two heights up the blade in model units
	     (`Fx/SwingTrail`), shown between a slash's `TrailOn` and
	     `TrailOff` markers. ]]
	swingTrail: { base: Vector3, tip: Vector3, colour: { Color3 } }?,
	--[[ A blade's effects (`Fx/BladeFx`): sparks off its tip while the
	     `move` clip drags it, a burst of sparks in front of the wielder as
	     each blow lands, more for the combo's last blow, which also shakes
	     the camera. ]]
	blade: {
		sparkColour: Color3,
		dragRate: number,
		burst: number,
		heavyBurst: number,
		reach: number,
		shake: number,
		shakeTime: number,
	}?,
	clips: Clips,
	--[[ The `Config/Sounds` entry each shot plays. ]]
	fireSound: string,
	--[[ A sound for each blow of a combo (`clips.fire`), when they differ:
	     played instead of `fireSound`. ]]
	comboSounds: { string }?,
	--[[ A staff's orbit ring axis, in the model's units through the orb. ]]
	orbitAxis: Vector3?,
	--[[ What the class's shots are drawn as, when not the plain arrow or
	     orb (`Fx/ProjectileRenderer`): a mesh, drawn Neon in the class's
	     colour as the kit does, and its own size in studs as imported. ]]
	bolt: {
		meshId: string,
		size: Vector3,
	}?,
	--[[ A bow's string, in model units from the grip: where it is tied top
	     and bottom, its centre at rest (the nock), and where the arrow rests
	     on the riser. ]]
	bowString: {
		top: Vector3,
		bottom: Vector3,
		nock: Vector3,
		rest: Vector3,
	}?,
	parts: { WeaponPart },
	--[[ The `Config/WeaponAnimations` entry it plays, when not its own: a
	     skin plays its base weapon's until it has its own kit. ]]
	kit: string?,
	--[[ A Mythic: its glow parts cycle through the rainbow (`Fx/WeaponGlow`). ]]
	rainbow: boolean?,
	--[[ A Legendary's or Mythic's shots glow in this colour, with a light and
	     sparkles (`Fx/ProjectileRenderer`), a Mythic's turning round the
	     rainbow like its weapon (owner, 2026-10-25: "the projectiles for the
	     legendary and mythics have their own glowing effect"). ]]
	shotGlow: Color3?,
	--[[ A Legendary's or Mythic's swing: its streak (`Fx/SwingTrail`) glows in
	     this colour, a Mythic's turning round the rainbow (owner, 2026-10-25:
	     "the cleave area that is currently red should also glow and change
	     color accordingly"). ]]
	trailGlow: Color3?,
	--[[ A Legendary's or Mythic's glow when it is one textured mesh with no
	     gem part to draw Neon (the Tripo weapons: Neon would wipe the
	     texture): a light and drifting motes of this colour round the whole
	     weapon (`Combat/HeldWeapon`), stronger on a Mythic. ]]
	aura: Color3?,
	--[[ The single bow this is a pair of (the Dual Bows Mythic): drafting the
	     card puts the pair of whatever bow is in hand there
	     (`Shared/Combat/HeldWeaponChoice`). ]]
	dualOf: string?,
}

local Weapons = {
	--[[ The classes' Common weapons, Tripo models since 2026-11-13 (owner:
	     all eighteen Mossy Glade weapons at 4,000 triangles and an 8K
	     texture, `assets/models/weapons/blocky/forest/tripo8k/`): one
	     textured mesh each, sized to the Claude Design models' length and
	     held on their own grips, measured from the meshes (a bow by its
	     riser, a staff 43% up, a blade at its handle's middle). The bow's
	     string is baked into its mesh, so it has no live string. Each plays
	     its own kit (`Config/WeaponAnimations`), never the weapon it stands
	     in for. ]]
	TwigBow = {
		hand = "LeftHand",
		scale = 4.3351,
		grip = Vector3.new(0, -0.15, 0),
		clips = {
			hold = "Hold",
			ready = "Draw",
			aim = "Aim",
			fire = { "Fire" },
			legs = { idle = "Idle", walk = "Walk", walkSpeed = 5.197825 },
		},
		fireSound = "arrow_fire",
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://115355663156928",
				size = Vector3.new(0.3051, 0.9799, 0.1562),
				--[[ The riser in the hand and the string behind it: the
				     riser is on the mesh's -X side (measured, 2026-11-13). ]]
				offset = Vector3.new(0, 0, -0.0833),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://75072128835727",
			},
		},
	} :: Weapon,

	--[[ Gripped mid-shaft like the arcane staff; the stone held in its
	     branches is a stone, not an orb, so nothing swells as it charges. ]]
	BranchStaff = {
		hand = "RightHand",
		scale = 4.581,
		grip = Vector3.new(0, -0.1, 0),
		clips = {
			hold = "Hold",
			ready = "Charge",
			aim = "Channel",
			fire = { "Cast" },
			special = { meteor = "Meteor" },
		},
		fireSound = "staff_cast",
		--[[ The arcane staff's bolt until the kit's blocky stone bolt is
		     imported. ]]
		bolt = {
			meshId = "rbxassetid://126459524560740",
			size = Vector3.new(0.098, 0.1, 0.099),
		},
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://90264882058244",
				size = Vector3.new(0.3193, 0.9797, 0.1633),
				offset = Vector3.new(0, 0.0686, 0),
				turned = true,
				textureId = "rbxassetid://137035804059208",
			},
		},
	} :: Weapon,

	--[[ Held like the greatsword: the right hand on the upper grip, the
	     blade along the hand's −Z with the edge down. ]]
	TimberBlade = {
		hand = "RightHand",
		scale = 4.8927,
		grip = Vector3.new(0, -0.1, 0),
		inHand = CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
		clips = {
			hold = "Hold",
			move = "Walk",
			--[[ Its kit's heavy trudge, made for 4.4 studs a second. ]]
			moveSpeed = 4.4,
			fire = { "Slash_A", "Slash_B", "Slash_C" },
			special = { earthbreaker = "Earthbreaker" },
		},
		fireSound = "sword_swing",
		comboSounds = { "sword_swing", "sword_swing_2", "sword_slam" },
		swingTrail = {
			base = Vector3.new(0, 0.194, 0),
			tip = Vector3.new(0, 0.715, 0),
			colour = { Color3.fromRGB(255, 214, 150), Color3.fromRGB(176, 112, 60) },
		},
		blade = {
			sparkColour = Color3.fromRGB(214, 160, 96),
			dragRate = 45,
			burst = 12,
			heavyBurst = 30,
			reach = 4,
			shake = 0.35,
			shakeTime = 0.25,
		},
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://87029386252426",
				size = Vector3.new(0.3963, 0.9786, 0.1826),
				-- the handle's middle, 24% up (measured, 2026-11-13)
				offset = Vector3.new(0, 0.2569, 0),
				turned = true,
				textureId = "rbxassetid://78290948770256",
			},
		},
	} :: Weapon,

	--[[ The Assassin's (owner, 2026-11-15): the Claude Design Splinter
	     Dagger of `docs/PETS-FOREST.md`'s sheet, one model held in each hand
	     (`offhand`), its own colours on its vertices. Gripped at the middle
	     of the wrapped handle, 37% up from the pommel (measured from the
	     GLB, `assets/models/weapons/blocky/forest/splinter_daggers_roblox.glb`),
	     blade out of the thumb side of the fist, as the bow and staff sit.
	     Its kit is written as numbers, not keyed in Claude Design
	     (`assets/models/weapons/splinter_daggers_r15/make_kit.py`): a
	     stance, a run with both blades trailing, a slash from each hand, a
	     double stab, and the dash's sweep. ]]
	SplinterDaggers = {
		hand = "RightHand",
		scale = 3.5,
		grip = Vector3.new(0, -0.1, 0),
		offhand = { hand = "LeftHand", grip = Vector3.new(0, -0.1, 0) },
		clips = {
			hold = "Hold",
			move = "Run",
			--[[ Made for the character's own pace (`Balance.Player.moveSpeed`). ]]
			moveSpeed = 13.5,
			fire = { "Slash_R", "Slash_L", "Stab" },
			special = { dash = "Dash" },
		},
		fireSound = "dagger_slash",
		comboSounds = { "dagger_slash", "dagger_slash_2", "dagger_stab" },
		swingTrail = {
			base = Vector3.new(0, -0.05, 0),
			tip = Vector3.new(0, 0.47, 0),
			colour = { Color3.fromRGB(236, 226, 255), Color3.fromRGB(146, 62, 224) },
		},
		--[[ Light sparks and the faintest shake, on the stab alone: the
		     daggers are quick, not heavy. ]]
		blade = {
			sparkColour = Color3.fromRGB(226, 196, 255),
			dragRate = 0,
			burst = 5,
			heavyBurst = 12,
			reach = 3,
			shake = 0.12,
			shakeTime = 0.12,
		},
		--[[ The Tripo remake of 2026-11-16 (one dagger, 4,000 triangles, an
		     8K texture; `assets/models/weapons/blocky/daggers`), at the
		     October dagger's length, gripped 18% up it, on its wrap. ]]
		parts = {
			{
				name = "Dagger",
				meshId = "rbxassetid://109981035122608",
				textureId = "rbxassetid://123337694391679",
				size = Vector3.new(0.1507, 0.5444, 0.1427),
				offset = Vector3.new(0.0001, 0.1742, -0.0006),
			},
		},
	} :: Weapon,
}

--[[ The area 1 weapon skins (docs/PETS-FOREST.md; the owner's imports,
     2026-10-24), generated by `assets/models/weapons/skins_to_luau.py` from
     what Studio holds: each its own meshes, size and glow, and everything
     else (hand, grip, how it is turned, animations, sounds, trails) its
     class's base weapon's, until it has its own kit. ]]
local skins: { [string]: any } = {
	-- SKINS BEGIN (assets/models/weapons/skins_to_luau.py; regenerate, never hand-edit)
	AcornBow = {
		-- `bow_1uncommon_acorn_bow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3343,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://98160891208078",
				size = Vector3.new(0.2851, 0.9801, 0.151),
				offset = Vector3.new(0, 0, -0.0369),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://124227247158148",
			},
		} :: { WeaponPart },
		bolt = {
			meshId = "rbxassetid://97056789014452",
			size = Vector3.new(0.3178, 0.302, 1.86),
		},
	},
	FireflyBow = {
		-- `bow_2rare_firefly_bow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3184,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://132174073872730",
				size = Vector3.new(0.2665, 0.9837, 0.1443),
				offset = Vector3.new(0.0003, 0, -0.0649),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://101595245702316",
			},
		} :: { WeaponPart },
		bolt = {
			meshId = "rbxassetid://134432387879424",
			size = Vector3.new(0.122, 0.122, 0.592),
		},
	},
	MossSlimeBow = {
		-- `bow_3epic_moss_slime_bow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.336,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://87020699323064",
				size = Vector3.new(0.1995, 0.9797, 0.4143),
				offset = Vector3.new(0.0253, 0, -0.11),
				turned = true,
				yaw = math.pi,
				textureId = "rbxassetid://77787222592510",
			},
		} :: { WeaponPart },
		bolt = {
			meshId = "rbxassetid://135158575063587",
			size = Vector3.new(0.201, 0.1741, 1.86),
		},
	},
	EmberFangBow = {
		-- `bow_4legendary_ember_fang_bow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3343,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://98290765032317",
				size = Vector3.new(0.3796, 0.9801, 0.2516),
				offset = Vector3.new(-0.0307, 0, -0.0704),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://72588131155252",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(254, 212, 61),
		shotGlow = Color3.fromRGB(254, 212, 61),
		bolt = {
			meshId = "rbxassetid://133739624251092",
			size = Vector3.new(0.3703, 0.3232, 1.56),
		},
	},
	GladeSpiritBow = {
		-- `bow_5mythic_glade_spirit_bow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3316,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://112167704420440",
				size = Vector3.new(0.4068, 0.9807, 0.1446),
				offset = Vector3.new(-0.0007, 0, -0.1069),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://123623386979421",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(150, 255, 170),
		shotGlow = Color3.fromRGB(150, 255, 170),
		bolt = {
			meshId = "rbxassetid://113478574540605",
			size = Vector3.new(0.2298, 0.2298, 1.86),
		},
	},
	ToadstoolStaff = {
		-- `staff_1uncommon_toadstool_staff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5745,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://115022213751896",
				size = Vector3.new(0.3378, 0.9811, 0.3678),
				offset = Vector3.new(0.0059, 0.0687, -0.001),
				turned = true,
				textureId = "rbxassetid://123924429087867",
			},
		} :: { WeaponPart },
		bolt = {
			meshId = "rbxassetid://134354238133479",
			size = Vector3.new(0.4199, 0.4433, 0.4798),
		},
	},
	LanternStaff = {
		-- `staff_2rare_lantern_staff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5749,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://126250025996209",
				size = Vector3.new(0.3909, 0.981, 0.2949),
				offset = Vector3.new(-0.0029, 0.0687, 0.001),
				turned = true,
				textureId = "rbxassetid://139189512630775",
			},
		} :: { WeaponPart },
		bolt = {
			meshId = "rbxassetid://76638889501110",
			size = Vector3.new(0.2, 0.2, 0.6017),
		},
	},
	HootmossStaff = {
		-- `staff_3epic_hootmoss_staff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5712,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://92890876823206",
				size = Vector3.new(0.3121, 0.9818, 0.2373),
				offset = Vector3.new(-0.001, 0.0687, -0.002),
				turned = true,
				textureId = "rbxassetid://138885584824788",
			},
		} :: { WeaponPart },
		bolt = {
			meshId = "rbxassetid://135826076139253",
			size = Vector3.new(0.14, 0.07, 0.34),
		},
	},
	SlimeCrownStaff = {
		-- `staff_4legendary_slime_crown_staff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5749,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://96486923984022",
				size = Vector3.new(0.3401, 0.981, 0.2009),
				offset = Vector3.new(0, 0.0687, 0.001),
				turned = true,
				textureId = "rbxassetid://128600877219470",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(230, 254, 205),
		shotGlow = Color3.fromRGB(230, 254, 205),
		bolt = {
			meshId = "rbxassetid://74685108676882",
			size = Vector3.new(0.0875, 0.1056, 0.4146),
		},
	},
	WorldrootStaff = {
		-- `staff_5mythic_worldroot_staff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5745,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://83012284503636",
				size = Vector3.new(0.4786, 0.9811, 0.1749),
				offset = Vector3.new(-0.0049, 0.0687, 0.002),
				turned = true,
				textureId = "rbxassetid://116526913627410",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(33, 244, 254),
		shotGlow = Color3.fromRGB(33, 244, 254),
		bolt = {
			meshId = "rbxassetid://116604779817561",
			size = Vector3.new(0.2712, 0.2851, 1.0434),
		},
	},
	MossstoneBlade = {
		-- `blade_1uncommon_mossstone_blade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8947,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://91331600009717",
				size = Vector3.new(0.3543, 0.9782, 0.1475),
				offset = Vector3.new(-0.0001, 0.2628, 0),
				turned = true,
				textureId = "rbxassetid://80126801478340",
			},
		} :: { WeaponPart },
	},
	ThornBlade = {
		-- `blade_2rare_thorn_blade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8927,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://98353512616592",
				size = Vector3.new(0.3786, 0.9786, 0.137),
				offset = Vector3.new(-0.0008, 0.2447, -0.0002),
				turned = true,
				textureId = "rbxassetid://119530046707037",
			},
		} :: { WeaponPart },
	},
	BroodsplitBlade = {
		-- `blade_3epic_broodsplit_blade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8822,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://89920476970367",
				size = Vector3.new(0.3677, 0.9807, 0.1729),
				offset = Vector3.new(0.0001, 0.2391, -0.0003),
				turned = true,
				textureId = "rbxassetid://82024155193646",
			},
		} :: { WeaponPart },
	},
	EmberfangBlade = {
		-- `blade_4legendary_emberfang_blade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8782,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://95840917045164",
				size = Vector3.new(0.3582, 0.9815, 0.2064),
				offset = Vector3.new(0.0003, 0.3129, 0.0002),
				turned = true,
				textureId = "rbxassetid://97093702935925",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(253, 127, 53),
		trailGlow = Color3.fromRGB(253, 127, 53),
	},
	GladeheartBlade = {
		-- `blade_5mythic_gladeheart_blade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8912,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://83136726794621",
				size = Vector3.new(0.3764, 0.9789, 0.1502),
				offset = Vector3.new(-0.0005, 0.257, -0.0006),
				turned = true,
				textureId = "rbxassetid://100030809181174",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(222, 190, 243),
		trailGlow = Color3.fromRGB(222, 190, 243),
	},
	ReedStaff = {
		-- `reed staff arena 3`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.4902,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://132803148374860",
				size = Vector3.new(0.2837, 0.9995, 0.2847),
				offset = Vector3.new(0.001, 0.07, 0.004),
				turned = true,
				textureId = "rbxassetid://116611356053754",
			},
		} :: { WeaponPart },
	},
	TidewoodBlade = {
		-- `tidewood blade arena 3`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.7904,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://101080327527177",
				size = Vector3.new(0.4097, 0.9995, 0.1284),
				offset = Vector3.new(0, 0.3123, 0),
				turned = true,
				textureId = "rbxassetid://82801723110398",
			},
		} :: { WeaponPart },
	},
	SlatefinBow = {
		-- `slatefin bow arena 3`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.2501,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://72959352581083",
				size = Vector3.new(0.104, 0.9995, 0.4927),
				offset = Vector3.new(-0.002, 0, -0.0917),
				turned = true,
				yaw = math.pi,
				textureId = "rbxassetid://95094493478746",
			},
		} :: { WeaponPart },
	},
	TidehookBlade = {
		-- `tidehook blade arena 3`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.7904,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://109253908479186",
				size = Vector3.new(0.4624, 0.9995, 0.1528),
				offset = Vector3.new(0, 0.3248, 0),
				turned = true,
				textureId = "rbxassetid://110272759853929",
			},
		} :: { WeaponPart },
	},
	EelcrestBow = {
		-- `eelcrest bow arena 3`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.2501,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://79795647768703",
				size = Vector3.new(0.3394, 0.9995, 0.1313),
				offset = Vector3.new(0.0014, 0, -0.0355),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://138309091162872",
			},
		} :: { WeaponPart },
	},
	WellpearlStaff = {
		-- `wellpearl staff arena 3`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.4902,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://130258670765972",
				size = Vector3.new(0.2358, 0.9995, 0.2114),
				offset = Vector3.new(-0.001, 0.07, 0.001),
				turned = true,
				textureId = "rbxassetid://78141638311419",
			},
		} :: { WeaponPart },
	},
	CausewayBlade = {
		-- `causeway blade arena 3`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.7904,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://102479967632985",
				size = Vector3.new(0.3911, 0.9995, 0.1528),
				offset = Vector3.new(0.0006, 0.3373, 0),
				turned = true,
				textureId = "rbxassetid://77605466340843",
			},
		} :: { WeaponPart },
	},
	TollstringBow = {
		-- `tollstring bow arena 3`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.2501,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://70803920000312",
				size = Vector3.new(0.4771, 0.9995, 0.1694),
				offset = Vector3.new(0.0126, 0, -0.1074),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://87111981155450",
			},
		} :: { WeaponPart },
		shotGlow = Color3.fromRGB(255, 255, 255),
	},
	TollkeeperStaff = {
		-- `tollkeeper staff arena 3`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.4902,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://126230765318311",
				size = Vector3.new(0.2739, 0.9995, 0.1216),
				offset = Vector3.new(0, 0.07, 0),
				turned = true,
				textureId = "rbxassetid://131973326076494",
			},
		} :: { WeaponPart },
		shotGlow = Color3.fromRGB(255, 255, 255),
	},
	TollguardBlade = {
		-- `sunken bell sword arena 3`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.7904,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://79270724349699",
				size = Vector3.new(0.3394, 0.9995, 0.1724),
				offset = Vector3.new(0.0003, 0.2874, 0),
				turned = true,
				textureId = "rbxassetid://78360244322797",
			},
		} :: { WeaponPart },
		trailGlow = Color3.fromRGB(255, 255, 255),
	},
	BuoyStaff = {
		-- `buoy staff arena 3`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.4902,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://78767941640588",
				size = Vector3.new(0.313, 0.9995, 0.3901),
				offset = Vector3.new(-0.001, 0.07, 0),
				turned = true,
				textureId = "rbxassetid://111040352974574",
			},
		} :: { WeaponPart },
	},
	EventideBow = {
		-- `eventide bow arena 3`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.2501,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://101108217438474",
				size = Vector3.new(0.396, 0.9995, 0.1606),
				offset = Vector3.new(-0.006, 0, -0.057),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://134441330446964",
			},
		} :: { WeaponPart },
		rainbow = true,
		shotGlow = Color3.fromRGB(255, 255, 255),
	},
	MaelstromStaff = {
		-- `maelstrom staff arena 3`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.4902,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://72086969439896",
				size = Vector3.new(0.4136, 0.9995, 0.1235),
				offset = Vector3.new(0.012, 0.07, -0.005),
				turned = true,
				textureId = "rbxassetid://80653594323518",
			},
		} :: { WeaponPart },
		rainbow = true,
		shotGlow = Color3.fromRGB(255, 255, 255),
	},
	StormglassBlade = {
		-- `stormglass blade arena 3`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.7904,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://95695726908721",
				size = Vector3.new(0.5093, 0.9995, 0.1226),
				offset = Vector3.new(0, 0.3188, 0),
				turned = true,
				textureId = "rbxassetid://91354810095787",
			},
		} :: { WeaponPart },
		rainbow = true,
		trailGlow = Color3.fromRGB(255, 255, 255),
	},
	PeatwoodBow = {
		-- `PeatwoodBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3347,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://134793521712254",
				size = Vector3.new(0.309, 0.98, 0.123),
				offset = Vector3.new(0, 0, -0.057),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://122181203004125",
			},
		} :: { WeaponPart },
	},
	SporestringBow = {
		-- `SporestringBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3303,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://96366000244536",
				size = Vector3.new(0.355, 0.978, 0.3),
				offset = Vector3.new(-0.001, 0, -0.0875),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://138494610719022",
			},
		} :: { WeaponPart },
	},
	GlowcapLongbow = {
		-- `GlowcapLongbow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3436,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://85684342392121",
				size = Vector3.new(0.352, 0.979, 0.16),
				offset = Vector3.new(-0.001, 0, -0.0733),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://140691179436768",
			},
		} :: { WeaponPart },
	},
	GulpstringBow = {
		-- `GulpstringBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3259,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://80628391762625",
				size = Vector3.new(0.396, 0.98, 0.12),
				offset = Vector3.new(-0.0076, 0, -0.0776),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://137735639693578",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(233, 185, 46),
		shotGlow = Color3.fromRGB(233, 185, 46),
	},
	LumenveilBow = {
		-- `LumenveilBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3525,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://108849383826297",
				size = Vector3.new(0.499, 0.986, 0.173),
				offset = Vector3.new(-0.0007, 0, -0.0166),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://110956143308073",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(63, 230, 242),
		shotGlow = Color3.fromRGB(63, 230, 242),
	},
	LichenStaff = {
		-- `LichenStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5843,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://128370773687924",
				size = Vector3.new(0.322, 0.978, 0.24),
				offset = Vector3.new(-0.0108, 0.0685, -0.0108),
				turned = true,
				textureId = "rbxassetid://97626502629734",
			},
		} :: { WeaponPart },
	},
	PuffballStaff = {
		-- `PuffballStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5288,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://108312008882565",
				size = Vector3.new(0.319, 0.987, 0.326),
				offset = Vector3.new(-0.0079, 0.0694, 0.001),
				turned = true,
				textureId = "rbxassetid://88895094742911",
			},
		} :: { WeaponPart },
	},
	VentstoneStaff = {
		-- `VentstoneStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5425,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://114311529112134",
				size = Vector3.new(0.263, 0.982, 0.194),
				offset = Vector3.new(0, 0.0692, -0.004),
				turned = true,
				textureId = "rbxassetid://110542643129302",
			},
		} :: { WeaponPart },
	},
	GrandmothersStaff = {
		-- `GrandmothersStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5703,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://90956375054285",
				size = Vector3.new(0.284, 0.984, 0.269),
				offset = Vector3.new(-0.0226, 0.0687, -0.0354),
				turned = true,
				textureId = "rbxassetid://80572155464574",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(77, 232, 200),
		shotGlow = Color3.fromRGB(77, 232, 200),
	},
	MyceliadStaff = {
		-- `MyceliadStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5703,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://114017100747129",
				size = Vector3.new(0.479, 0.975, 0.354),
				offset = Vector3.new(-0.0098, 0.0687, -0.001),
				turned = true,
				textureId = "rbxassetid://112810987557095",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(63, 230, 242),
		shotGlow = Color3.fromRGB(63, 230, 242),
	},
	BogironBlade = {
		-- `BogironBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8857,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://106626851576904",
				size = Vector3.new(0.365, 0.98, 0.215),
				offset = Vector3.new(-0.0008, 0.3001, -0.0008),
				turned = true,
				textureId = "rbxassetid://85082672046783",
			},
		} :: { WeaponPart },
	},
	ShellbackCleaver = {
		-- `ShellbackCleaver`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8857,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://102547166808602",
				size = Vector3.new(0.354, 0.979, 0.249),
				offset = Vector3.new(0.0295, 0.2756, -0.0004),
				turned = true,
				textureId = "rbxassetid://76281554635101",
			},
		} :: { WeaponPart },
	},
	CaplightBlade = {
		-- `CaplightBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8857,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://78732110431221",
				size = Vector3.new(0.447, 0.98, 0.441),
				offset = Vector3.new(-0.0001, 0.3001, -0.0001),
				turned = true,
				textureId = "rbxassetid://105810499031996",
			},
		} :: { WeaponPart },
	},
	GulpfangBlade = {
		-- `GulpfangBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8807,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://70750010208640",
				size = Vector3.new(0.355, 0.982, 0.164),
				offset = Vector3.new(-0.002, 0.2759, 0.0007),
				turned = true,
				textureId = "rbxassetid://97419873120402",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(154, 205, 60),
		trailGlow = Color3.fromRGB(154, 205, 60),
	},
	DeepglowBlade = {
		-- `DeepglowBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8758,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://132847635057810",
				size = Vector3.new(0.475, 0.981, 0.155),
				offset = Vector3.new(0.0001, 0.2578, 0.0009),
				turned = true,
				textureId = "rbxassetid://93900761687877",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(63, 230, 242),
		trailGlow = Color3.fromRGB(63, 230, 242),
	},
	GoldenBow = {
		-- `GoldenBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3391,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://116283939534173",
				size = Vector3.new(0.387, 0.979, 0.168),
				offset = Vector3.new(-0.0004, 0, -0.0789),
				turned = true,
				yaw = math.pi / 2,
				textureId = "rbxassetid://125471324775660",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 205, 56),
		shotGlow = Color3.fromRGB(255, 205, 56),
	},
	GoldenStaff = {
		-- `GoldenStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5843,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://109558549444590",
				size = Vector3.new(0.267, 0.979, 0.214),
				offset = Vector3.new(0, 0.0685, 0),
				turned = true,
				textureId = "rbxassetid://108480906774057",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 214, 84),
		shotGlow = Color3.fromRGB(255, 214, 84),
	},
	GoldenBlade = {
		-- `GoldenBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8857,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://134626899771970",
				size = Vector3.new(0.367, 0.98, 0.148),
				offset = Vector3.new(0, 0.3185, 0),
				turned = true,
				textureId = "rbxassetid://75986189772116",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 198, 44),
		trailGlow = Color3.fromRGB(255, 198, 44),
	},
	BrambleShivs = {
		-- `BrambleShivs`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9429,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://112072754755619",
				size = Vector3.new(0.3071, 0.9807, 0.2278),
				offset = Vector3.new(0, 0.3138, 0),
				turned = true,
				textureId = "rbxassetid://135404268248545",
			},
		} :: { WeaponPart },
	},
	FireflyFangs = {
		-- `FireflyFangs`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9449,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://125647619952354",
				size = Vector3.new(0.2414, 0.9797, 0.1993),
				offset = Vector3.new(-0.0028, 0.3135, 0),
				turned = true,
				textureId = "rbxassetid://137655955437413",
			},
		} :: { WeaponPart },
	},
	GladeFoxClaws = {
		-- `GladeFoxClaws`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.938,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://117405917457037",
				size = Vector3.new(0.2993, 0.9832, 0.2731),
				offset = Vector3.new(-0.0129, 0.3048, 0.0005),
				turned = true,
				textureId = "rbxassetid://79019869679128",
			},
		} :: { WeaponPart },
	},
	EmberWilfFangs = {
		-- `EmberWilfFangs`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9382,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://92784496611629",
				size = Vector3.new(0.2823, 0.9831, 0.3052),
				offset = Vector3.new(-0.0021, 0.2851, 0.0004),
				turned = true,
				textureId = "rbxassetid://109622119484117",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 140, 40),
		trailGlow = Color3.fromRGB(255, 140, 40),
	},
	GlimmerhornDaggers = {
		-- `GlimmerhornDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9397,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://96513730674225",
				size = Vector3.new(0.5442, 0.9823, 0.2134),
				offset = Vector3.new(0.0003, 0.3536, 0.0008),
				turned = true,
				textureId = "rbxassetid://135921372690096",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(235, 170, 255),
		trailGlow = Color3.fromRGB(235, 170, 255),
	},
	HedgePrickers = {
		-- `HedgePrickers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9495,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://121273305347098",
				size = Vector3.new(0.3088, 0.9774, 0.2126),
				offset = Vector3.new(-0.0002, 0.3323, 0.0001),
				turned = true,
				textureId = "rbxassetid://118644019151961",
			},
		} :: { WeaponPart },
	},
	TuskKnives = {
		-- `TuskKnives`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9477,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://136473741539690",
				size = Vector3.new(0.3128, 0.9783, 0.175),
				offset = Vector3.new(-0.0009, 0.2935, 0.0084),
				turned = true,
				textureId = "rbxassetid://112310444935977",
			},
		} :: { WeaponPart },
	},
	BurrfangDaggers = {
		-- `BurrfangDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9421,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://109246360782906",
				size = Vector3.new(0.3173, 0.9811, 0.2153),
				offset = Vector3.new(0.0011, 0.2355, 0.0002),
				turned = true,
				textureId = "rbxassetid://96564476510507",
			},
		} :: { WeaponPart },
	},
	SilkfangDaggers = {
		-- `SilkfangDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9479,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://117721840855836",
				size = Vector3.new(0.3508, 0.9782, 0.2156),
				offset = Vector3.new(0.0003, 0.2739, 0.0002),
				turned = true,
				textureId = "rbxassetid://99600975463545",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(230, 60, 200),
		trailGlow = Color3.fromRGB(230, 60, 200),
	},
	LurkerClaws = {
		-- `LurkerClaws`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9378,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://76588552074579",
				size = Vector3.new(0.4077, 0.9833, 0.1795),
				offset = Vector3.new(-0.0002, 0.2852, -0.0004),
				turned = true,
				textureId = "rbxassetid://138528147342659",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 70, 210),
		trailGlow = Color3.fromRGB(255, 70, 210),
	},
	DriftwoodDirks = {
		-- `DriftwoodDirks`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9423,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://108529956253947",
				size = Vector3.new(0.3639, 0.981, 0.1681),
				offset = Vector3.new(0.0015, 0.2649, 0.0013),
				turned = true,
				textureId = "rbxassetid://120432794917352",
			},
		} :: { WeaponPart },
	},
	BarnacleKnives = {
		-- `BarnacleKnives`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9465,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://140173091377064",
				size = Vector3.new(0.3198, 0.9789, 0.22),
				offset = Vector3.new(-0.0006, 0.2643, -0.0008),
				turned = true,
				textureId = "rbxassetid://120141022136704",
			},
		} :: { WeaponPart },
	},
	EeltoothDaggers = {
		-- `EeltoothDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9451,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://88277814709938",
				size = Vector3.new(0.36, 0.9796, 0.1511),
				offset = Vector3.new(-0.0002, 0.3331, -0.0006),
				turned = true,
				textureId = "rbxassetid://134472793818377",
			},
		} :: { WeaponPart },
	},
	TollbellDaggers = {
		-- `TollbellDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9461,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://90065675724031",
				size = Vector3.new(0.3316, 0.9791, 0.2352),
				offset = Vector3.new(0.0006, 0.2448, 0.0026),
				turned = true,
				textureId = "rbxassetid://80272304011974",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(70, 220, 200),
		trailGlow = Color3.fromRGB(70, 220, 200),
	},
	RiptideFangs = {
		-- `RiptideFangs`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9401,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://72842948577032",
				size = Vector3.new(0.3829, 0.9821, 0.1961),
				offset = Vector3.new(-0.0023, 0.2652, 0.0006),
				turned = true,
				textureId = "rbxassetid://119440703225958",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(90, 240, 225),
		trailGlow = Color3.fromRGB(90, 240, 225),
	},
	MossShivs = {
		-- `MossShivs`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9437,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://137107027765402",
				size = Vector3.new(0.2998, 0.9803, 0.2154),
				offset = Vector3.new(0.0001, 0.3137, 0.0006),
				turned = true,
				textureId = "rbxassetid://104305608141564",
			},
		} :: { WeaponPart },
	},
	SporeFangs = {
		-- `SporeFangs`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9433,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://112465728947288",
				size = Vector3.new(0.3186, 0.9805, 0.2274),
				offset = Vector3.new(0.0058, 0.3236, -0.0009),
				turned = true,
				textureId = "rbxassetid://96548517342191",
			},
		} :: { WeaponPart },
	},
	GlowcapKris = {
		-- `GlowcapKris`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9457,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://74062370504959",
				size = Vector3.new(0.303, 0.9793, 0.1823),
				offset = Vector3.new(0.0018, 0.3134, -0.0007),
				turned = true,
				textureId = "rbxassetid://72682821735921",
			},
		} :: { WeaponPart },
	},
	ToadtongueDaggers = {
		-- `ToadtongueDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9445,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://86671544277404",
				size = Vector3.new(0.335, 0.9799, 0.2064),
				offset = Vector3.new(-0.0015, 0.2744, 0),
				turned = true,
				textureId = "rbxassetid://85495479463592",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(245, 120, 160),
		trailGlow = Color3.fromRGB(245, 120, 160),
	},
	PrismStingers = {
		-- `PrismStingers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9317,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://132291881011733",
				size = Vector3.new(0.3698, 0.9864, 0.2304),
				offset = Vector3.new(-0.0023, 0.2269, 0.0179),
				turned = true,
				textureId = "rbxassetid://70588723273817",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(63, 230, 242),
		trailGlow = Color3.fromRGB(63, 230, 242),
	},
	GoldenDaggers = {
		-- `GoldenDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9451,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://138098743412792",
				size = Vector3.new(0.4029, 0.9796, 0.1951),
				offset = Vector3.new(0.002, 0.2645, 0.0005),
				turned = true,
				textureId = "rbxassetid://126966074841057",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 205, 56),
		trailGlow = Color3.fromRGB(255, 205, 56),
	},
	LivewireBow = {
		-- `LivewireBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3449,
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://86158872034339",
				size = Vector3.new(0.4318, 0.9777, 0.2269),
				offset = Vector3.new(0.0014, 0, -0.0972),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://82793880626680",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(70, 232, 255),
		shotGlow = Color3.fromRGB(70, 232, 255),
	},
	MainframeStaff = {
		-- `MainframeStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5815,
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://83056830126785",
				size = Vector3.new(0.3022, 0.9796, 0.1781),
				offset = Vector3.new(-0.0007, 0.0686, -0.0018),
				turned = true,
				textureId = "rbxassetid://133089754290097",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 62, 196),
		shotGlow = Color3.fromRGB(255, 62, 196),
	},
	OverclockBlade = {
		-- `OverclockBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8842,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://128389524938791",
				size = Vector3.new(0.5, 0.9803, 0.1616),
				offset = Vector3.new(0.0004, 0.2843, 0.0004),
				turned = true,
				textureId = "rbxassetid://81200535668982",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(70, 232, 255),
		trailGlow = Color3.fromRGB(70, 232, 255),
	},
	GlitchDaggers = {
		-- `GlitchDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9469,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://80951157053007",
				size = Vector3.new(0.3714, 0.9787, 0.1751),
				offset = Vector3.new(0.0011, 0.2936, 0),
				turned = true,
				textureId = "rbxassetid://125935879673176",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 62, 196),
		trailGlow = Color3.fromRGB(255, 62, 196),
	},
	WishbrightBow = {
		-- `WishbrightBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3356,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://135592328813188",
				size = Vector3.new(0.5098, 0.9798, 0.2758),
				offset = Vector3.new(0.0002, 0, -0.1392),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://91614727945119",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 214, 92),
		shotGlow = Color3.fromRGB(255, 214, 92),
	},
	DreamdropStaff = {
		-- `DreamdropStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5773,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://126746338301669",
				size = Vector3.new(0.3956, 0.9805, 0.1936),
				offset = Vector3.new(-0.0012, 0.0686, -0.0016),
				turned = true,
				textureId = "rbxassetid://113073061248661",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 140, 200),
		shotGlow = Color3.fromRGB(255, 140, 200),
	},
	WishcutterBlade = {
		-- `WishcutterBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8778,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://77646162067586",
				size = Vector3.new(0.4563, 0.9816, 0.1478),
				offset = Vector3.new(-0.0009, 0.2945, 0.0005),
				turned = true,
				textureId = "rbxassetid://83650970339437",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 214, 92),
		trailGlow = Color3.fromRGB(255, 214, 92),
	},
	TwinkleDaggers = {
		-- `TwinkleDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9415,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://133381353315585",
				size = Vector3.new(0.463, 0.9814, 0.2238),
				offset = Vector3.new(-0.0001, 0.2846, 0.0001),
				turned = true,
				textureId = "rbxassetid://116194704763654",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 140, 200),
		trailGlow = Color3.fromRGB(255, 140, 200),
	},
	SaddlehornBow = {
		-- `SaddlehornBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3396,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://93712261068900",
				size = Vector3.new(0.5317, 0.9789, 0.1665),
				offset = Vector3.new(-0.0054, 0, -0.1111),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://101987197506919",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(64, 224, 208),
		shotGlow = Color3.fromRGB(64, 224, 208),
	},
	WagonwheelStaff = {
		-- `WagonwheelStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5829,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://120857626319400",
				size = Vector3.new(0.3876, 0.9793, 0.1374),
				offset = Vector3.new(-0.0001, 0.0686, -0.0007),
				turned = true,
				textureId = "rbxassetid://137006257922329",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(64, 224, 208),
		shotGlow = Color3.fromRGB(64, 224, 208),
	},
	TrailbossBlade = {
		-- `TrailbossBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8872,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://80154596704715",
				size = Vector3.new(0.3825, 0.9797, 0.1315),
				offset = Vector3.new(-0.0013, 0.3429, 0),
				turned = true,
				textureId = "rbxassetid://137119121556911",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(240, 190, 80),
		trailGlow = Color3.fromRGB(240, 190, 80),
	},
	SpurDaggers = {
		-- `SpurDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9431,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://140311721087454",
				size = Vector3.new(0.3321, 0.9806, 0.2418),
				offset = Vector3.new(-0.002, 0.2942, 0.0009),
				turned = true,
				textureId = "rbxassetid://129615841966613",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(240, 190, 80),
		trailGlow = Color3.fromRGB(240, 190, 80),
	},
	NoodleBow = {
		-- `NoodleBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3334,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://87062589115071",
				size = Vector3.new(0.4973, 0.9803, 0.219),
				offset = Vector3.new(-0.0126, 0, -0.1104),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://115404089914100",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(80, 220, 255),
		shotGlow = Color3.fromRGB(80, 220, 255),
	},
	SplashringStaff = {
		-- `SplashringStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5833,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://104899557257644",
				size = Vector3.new(0.3876, 0.9792, 0.1751),
				offset = Vector3.new(0.0012, 0.1958, -0.0005),
				turned = true,
				textureId = "rbxassetid://126649089229975",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(80, 220, 255),
		shotGlow = Color3.fromRGB(80, 220, 255),
	},
	BreakerBlade = {
		-- `BreakerBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8773,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://74329406799333",
				size = Vector3.new(0.4168, 0.9817, 0.2386),
				offset = Vector3.new(0.0007, 0.2847, 0.005),
				turned = true,
				textureId = "rbxassetid://85506869167256",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(80, 220, 255),
		trailGlow = Color3.fromRGB(80, 220, 255),
	},
	SquirtDaggers = {
		-- `SquirtDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9407,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://127929929640360",
				size = Vector3.new(0.3907, 0.9818, 0.1768),
				offset = Vector3.new(0, 0.2749, -0.0004),
				turned = true,
				textureId = "rbxassetid://70441792722031",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(80, 220, 255),
		trailGlow = Color3.fromRGB(80, 220, 255),
	},
	HighscoreBow = {
		-- `HighscoreBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3422,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://70497883513598",
				size = Vector3.new(0.4011, 0.9783, 0.2702),
				offset = Vector3.new(-0.0009, 0, -0.0978),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://90791410773927",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 70, 70),
		shotGlow = Color3.fromRGB(255, 70, 70),
	},
	JoystickStaff = {
		-- `JoystickStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5843,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://114774082160561",
				size = Vector3.new(0.2625, 0.979, 0.2285),
				offset = Vector3.new(-0.0004, 0.0685, -0.0004),
				turned = true,
				textureId = "rbxassetid://103519652395887",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(70, 130, 255),
		shotGlow = Color3.fromRGB(70, 130, 255),
	},
	PixelBlade = {
		-- `PixelBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8763,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://81036173680464",
				size = Vector3.new(0.3695, 0.9819, 0.1222),
				offset = Vector3.new(-0.0005, 0.2455, 0.0006),
				turned = true,
				textureId = "rbxassetid://138716240575470",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(70, 130, 255),
		trailGlow = Color3.fromRGB(70, 130, 255),
	},
	TokenDaggers = {
		-- `TokenDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9451,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://109593487073132",
				size = Vector3.new(0.3631, 0.9796, 0.2385),
				offset = Vector3.new(-0.0006, 0.2253, 0.0004),
				turned = true,
				textureId = "rbxassetid://105499947744136",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 70, 70),
		trailGlow = Color3.fromRGB(255, 70, 70),
	},
	OrbitBow = {
		-- `OrbitBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3431,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://94734081999341",
				size = Vector3.new(0.434, 0.9781, 0.2836),
				offset = Vector3.new(-0.0004, 0, -0.094),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://102202300078466",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(180, 110, 255),
		shotGlow = Color3.fromRGB(180, 110, 255),
	},
	StarwellStaff = {
		-- `StarwellStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5847,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://121785432247384",
				size = Vector3.new(0.4724, 0.9789, 0.3388),
				offset = Vector3.new(0.0007, 0.0685, -0.0012),
				turned = true,
				textureId = "rbxassetid://83876518973798",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 140, 230),
		shotGlow = Color3.fromRGB(255, 140, 230),
	},
	NebulaBlade = {
		-- `NebulaBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8962,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://102228735402808",
				size = Vector3.new(0.3761, 0.9779, 0.3302),
				offset = Vector3.new(0.0001, 0.2738, -0.0004),
				turned = true,
				textureId = "rbxassetid://93712729804632",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(180, 110, 255),
		trailGlow = Color3.fromRGB(180, 110, 255),
	},
	CometDaggers = {
		-- `CometDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9485,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://131831047658815",
				size = Vector3.new(0.3542, 0.9779, 0.3375),
				offset = Vector3.new(0.0001, 0.2738, -0.0047),
				turned = true,
				textureId = "rbxassetid://90966274072915",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 140, 230),
		trailGlow = Color3.fromRGB(255, 140, 230),
	},
	BlossomBow = {
		-- `BlossomBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3369,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://98079111026738",
				size = Vector3.new(0.4471, 0.9795, 0.2216),
				offset = Vector3.new(-0.0009, 0, -0.1141),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://105431348845860",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 150, 190),
		shotGlow = Color3.fromRGB(255, 150, 190),
	},
	PaperglowStaff = {
		-- `PaperglowStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.5749,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://123203878806120",
				size = Vector3.new(0.469, 0.981, 0.2741),
				offset = Vector3.new(-0.1147, 0.2649, 0.0006),
				turned = true,
				textureId = "rbxassetid://83121551068534",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 190, 90),
		shotGlow = Color3.fromRGB(255, 190, 90),
	},
	PetalfallBlade = {
		-- `PetalfallBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8753,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://78703893865338",
				size = Vector3.new(0.3361, 0.9821, 0.1321),
				offset = Vector3.new(0, 0.2652, 0.0006),
				turned = true,
				textureId = "rbxassetid://139263431899652",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 150, 190),
		trailGlow = Color3.fromRGB(255, 150, 190),
	},
	BellchimeDaggers = {
		-- `BellchimeDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9439,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://92988602774925",
				size = Vector3.new(0.4413, 0.9802, 0.1777),
				offset = Vector3.new(0.0006, 0.245, 0),
				turned = true,
				textureId = "rbxassetid://89087637842542",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 190, 90),
		trailGlow = Color3.fromRGB(255, 190, 90),
	},
	CinderstringBow = {
		-- `CinderstringBow`, held as the TwigBow is, playing its kit until it has its own
		kit = "TwigBow",
		skinOf = "TwigBow",
		scale = 4.3356,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://93048340998656",
				size = Vector3.new(0.4797, 0.9798, 0.2292),
				offset = Vector3.new(0, 0, -0.1117),
				turned = true,
				yaw = -math.pi / 2,
				textureId = "rbxassetid://90939717773223",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 120, 30),
		shotGlow = Color3.fromRGB(255, 120, 30),
	},
	ForgeheartStaff = {
		-- `ForgeheartStaff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 4.589,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://109248491458154",
				size = Vector3.new(0.3451, 0.978, 0.2911),
				offset = Vector3.new(0.0008, 0.0685, 0.0019),
				turned = true,
				textureId = "rbxassetid://101093659277750",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 120, 30),
		shotGlow = Color3.fromRGB(255, 120, 30),
	},
	MoltenBlade = {
		-- `MoltenBlade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 4.8827,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://96189184685974",
				size = Vector3.new(0.4137, 0.9806, 0.2146),
				offset = Vector3.new(0.0007, 0.255, -0.0002),
				turned = true,
				textureId = "rbxassetid://90975304299716",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 120, 30),
		trailGlow = Color3.fromRGB(255, 120, 30),
	},
	EmbershardDaggers = {
		-- `EmbershardDaggers`, held as the SplinterDaggers is, playing its kit until it has its own
		kit = "SplinterDaggers",
		skinOf = "SplinterDaggers",
		scale = 1.9473,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://134222445690465",
				size = Vector3.new(0.4547, 0.9785, 0.2438),
				offset = Vector3.new(0.0001, 0.274, 0.0025),
				turned = true,
				textureId = "rbxassetid://133070494226928",
			},
		} :: { WeaponPart },
		aura = Color3.fromRGB(255, 200, 60),
		trailGlow = Color3.fromRGB(255, 200, 60),
	},
	-- SKINS END
}
for key, skin in skins do
	local base = (Weapons :: any)[skin.skinOf] :: Weapon
	(Weapons :: any)[key] = {
		hand = base.hand,
		scale = skin.scale,
		grip = base.grip,
		inHand = base.inHand,
		--[[ A dagger skin is held in both hands, as the Splinter Daggers are. ]]
		offhand = base.offhand,
		clips = base.clips,
		fireSound = base.fireSound,
		comboSounds = base.comboSounds,
		swingTrail = base.swingTrail,
		blade = base.blade,
		bolt = skin.bolt or base.bolt,
		kit = skin.kit,
		rainbow = skin.rainbow,
		shotGlow = skin.shotGlow,
		trailGlow = skin.trailGlow,
		aura = skin.aura,
		parts = skin.parts,
	} :: Weapon
end

--[[ The Dual Bows Mythic (`Config/Abilities.DualBows.weapon`): the Ranger's
     Twig Bow in each hand, the same meshes at the same grip in either hand,
     played from the owner's Dual Bows kit (`assets/models/weapons/
     leaf_bow_dual_r15/LeafBow_Dual_R15_Kit.rbxmx`, 2026-10-23, made for the
     leaf bow, which is gone: owner, 2026-10-24): both bows low while moving,
     raised square, then held up at chest height, the right and left firing
     in turn. The strings draw themselves in the kit, so neither has a live
     string here. ]]
local twigBow = Weapons.TwigBow;
(Weapons :: any).TwigBowDual = {
	hand = twigBow.hand,
	scale = twigBow.scale,
	grip = twigBow.grip,
	clips = {
		hold = "Hold",
		ready = "Raise",
		aim = "Aim",
		fire = { "Fire_R", "Fire_L" },
		afterFire = "aim",
		legs = twigBow.clips.legs,
	},
	fireSound = twigBow.fireSound,
	offhand = { hand = "RightHand", grip = twigBow.grip },
	parts = twigBow.parts,
	dualOf = "TwigBow",
} :: Weapon

--[[ Each bow skin's own pair, so drafting Dual Bows keeps the skin in hand
     (owner, 2026-10-25: "it needs to keep the skin of the bow they have on
     currently"): the skin's meshes, size, glow, rainbow and arrow, held and
     animated as the Twig Bows are. No skin has a second-hand model, and the
     bows are symmetric front to back, so the off hand holds a copy of the
     same model at the same grip and turn, as the Twig Bows' does. ]]
local twigBowDual = (Weapons :: any).TwigBowDual :: Weapon
for key, skin in skins do
	if skin.skinOf ~= "TwigBow" then
		continue
	end
	(Weapons :: any)[`{key}Dual`] = {
		hand = twigBowDual.hand,
		scale = skin.scale,
		grip = twigBowDual.grip,
		clips = twigBowDual.clips,
		fireSound = twigBowDual.fireSound,
		offhand = twigBowDual.offhand,
		bolt = skin.bolt or twigBow.bolt,
		kit = "TwigBowDual",
		rainbow = skin.rainbow,
		shotGlow = skin.shotGlow,
		parts = skin.parts,
		dualOf = key,
	} :: Weapon
end

return table.freeze(Weapons)
