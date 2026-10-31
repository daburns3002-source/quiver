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
	--[[ The single bow this is a pair of (the Dual Bows Mythic): drafting the
	     card puts the pair of whatever bow is in hand there
	     (`Shared/Combat/HeldWeaponChoice`). ]]
	dualOf: string?,
}

local Weapons = {
	--[[ The blocky Common skins (docs/PETS-FOREST.md, Claude Design,
	     2026-10-23): `assets/models/weapons/blocky/*_roblox.glb`, from
	     `optimise_weapon.py`, imported by the owner. Offsets are from each
	     model's grip, measured from the import. Each plays its own kit
	     (`Config/WeaponAnimations`), never the weapon it stands in for. ]]
	TwigBow = {
		hand = "LeftHand",
		scale = 3.6,
		grip = Vector3.new(0, -0.15, 0),
		clips = {
			hold = "Hold",
			ready = "Draw",
			aim = "Aim",
			fire = { "Fire" },
			legs = { idle = "Idle", walk = "Walk", walkSpeed = 5.197825 },
		},
		fireSound = "arrow_fire",
		--[[ The string's ends and the nock as imported; the arrow rests on
		     the grip block in front of it. ]]
		bowString = {
			top = Vector3.new(-0.004, 0.385, -0.195),
			bottom = Vector3.new(-0.004, -0.385, -0.195),
			nock = Vector3.new(0.04, 0.06, -0.195),
			rest = Vector3.new(0.04, 0.06, 0.06),
		},
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://93880671560670",
				size = Vector3.new(0.0850, 0.8850, 0.3237),
				offset = Vector3.new(0, 0, -0.0606),
			},
			{
				name = "Leaves",
				meshId = "rbxassetid://118987931969181",
				size = Vector3.new(0.0602, 1.1794, 0.1583),
				offset = Vector3.new(0.0069, -0.0025, -0.1811),
			},
			{
				name = "String",
				meshId = "rbxassetid://97358352060456",
				size = Vector3.new(0.0120, 0.7700, 0.0104),
				offset = Vector3.new(-0.004, 0, -0.195),
				liveString = true,
			},
		},
	} :: Weapon,

	--[[ Gripped mid-shaft like the arcane staff; the stone held in its
	     branches is a stone, not an orb, so nothing swells as it charges. ]]
	BranchStaff = {
		hand = "RightHand",
		scale = 3.3,
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
				name = "Staff",
				meshId = "rbxassetid://87963343628479",
				size = Vector3.new(0.4023, 1.3607, 0.1201),
				offset = Vector3.new(-0.0077, 0.1003, 0),
			},
			{
				name = "Leaves",
				meshId = "rbxassetid://99768490004960",
				size = Vector3.new(0.4457, 1.0763, 0.1027),
				offset = Vector3.new(0.0239, 0.2859, 0),
			},
			{
				name = "Gems",
				meshId = "rbxassetid://71784006936035",
				size = Vector3.new(0.0600, 0.0900, 0.1189),
				offset = Vector3.new(0, -0.42, 0),
				glow = true,
				colour = Color3.fromRGB(107, 191, 73),
			},
			{
				name = "Stone",
				meshId = "rbxassetid://88728390994494",
				size = Vector3.new(0.2459, 0.1850, 0.2459),
				offset = Vector3.new(-0.01, 0.525, 0),
			},
		},
	} :: Weapon,

	--[[ Held like the greatsword: the right hand on the upper grip, the
	     blade along the hand's −Z with the edge down. ]]
	TimberBlade = {
		hand = "RightHand",
		scale = 3.8,
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
			base = Vector3.new(0, 0.25, 0),
			tip = Vector3.new(0, 0.92, 0),
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
				meshId = "rbxassetid://117873556639509",
				size = Vector3.new(0.2000, 0.7700, 0.0830),
				offset = Vector3.new(0, 0.555, 0),
			},
			{
				name = "Guard",
				meshId = "rbxassetid://74236461143698",
				size = Vector3.new(0.4800, 0.1862, 0.1400),
				offset = Vector3.new(0, 0.1231, 0),
			},
			{
				name = "Grip",
				meshId = "rbxassetid://137489111811923",
				size = Vector3.new(0.2020, 0.3550, 0.1350),
				offset = Vector3.new(0, -0.1425, 0),
			},
			{
				name = "Gems",
				meshId = "rbxassetid://135328357197599",
				size = Vector3.new(0.0693, 0.4626, 0.1500),
				offset = Vector3.new(0, -0.0443, 0),
				glow = true,
				colour = Color3.fromRGB(231, 0, 21),
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
		scale = 3.6156,
		parts = {
			{
				name = "String",
				meshId = "rbxassetid://138109999243771",
				size = Vector3.new(0.012, 0.846, 0.012),
				offset = Vector3.new(0, 0.0456, -0.1195),
				turned = true,
			},
			{
				name = "Bow",
				meshId = "rbxassetid://93365548631697",
				size = Vector3.new(0.165, 1.1749, 0.3739),
				offset = Vector3.new(0, 0, 0),
				turned = true,
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
		scale = 3.6,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://100645457000997",
				size = Vector3.new(0.1952, 1.18, 0.3688),
				offset = Vector3.new(0, 0, -0.005),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(249, 227, 109),
			},
			{
				name = "String",
				meshId = "rbxassetid://129479383120226",
				size = Vector3.new(0.046, 0.754, 0.046),
				offset = Vector3.new(0, 0, -0.1482),
				turned = true,
			},
			{
				name = "Bow",
				meshId = "rbxassetid://112256096217624",
				size = Vector3.new(0.2008, 1.0139, 0.3525),
				offset = Vector3.new(0, 0, 0.0132),
				turned = true,
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
		scale = 3.6,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://107047995472192",
				size = Vector3.new(0.132, 1.18, 0.3855),
				offset = Vector3.new(0.0076, 0, 0),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(215, 230, 83),
			},
			{
				name = "String",
				meshId = "rbxassetid://101583414276977",
				size = Vector3.new(0.0078, 0.722, 0.009),
				offset = Vector3.new(0.0076, 0, -0.1548),
				turned = true,
			},
			{
				name = "Leaves",
				meshId = "rbxassetid://87836714106409",
				size = Vector3.new(0.172, 1.0092, 0.2824),
				offset = Vector3.new(0.0076, -0.0093, 0.0111),
				turned = true,
			},
			{
				name = "Bow",
				meshId = "rbxassetid://90462181562008",
				size = Vector3.new(0.1563, 1.0199, 0.3575),
				offset = Vector3.new(-0.0155, 0.0464, 0.0065),
				turned = true,
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
		scale = 3.6,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://92244687159462",
				size = Vector3.new(0.112, 1.1358, 0.333),
				offset = Vector3.new(0, 0, -0.0303),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(254, 212, 61),
			},
			{
				name = "String",
				meshId = "rbxassetid://118883778404973",
				size = Vector3.new(0.0075, 0.7815, 0.0087),
				offset = Vector3.new(0, 0, -0.1507),
				turned = true,
			},
			{
				name = "Bow",
				meshId = "rbxassetid://92588153985762",
				size = Vector3.new(0.1138, 1.18, 0.4168),
				offset = Vector3.new(0, 0, 0),
				turned = true,
			},
		} :: { WeaponPart },
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
		scale = 3.6003,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://138752915379851",
				size = Vector3.new(0.1238, 1.18, 0.3535),
				offset = Vector3.new(0.0018, 0, -0.0213),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(255, 255, 255),
			},
			{
				name = "String",
				meshId = "rbxassetid://92575416616043",
				size = Vector3.new(0.008, 0.84, 0.008),
				offset = Vector3.new(0, 0, -0.1039),
				turned = true,
			},
			{
				name = "Leaves",
				meshId = "rbxassetid://103693018640595",
				size = Vector3.new(0.1441, 1.0299, 0.4244),
				offset = Vector3.new(0, 0, 0),
				turned = true,
			},
			{
				name = "Bow",
				meshId = "rbxassetid://103912722129804",
				size = Vector3.new(0.0995, 0.9067, 0.301),
				offset = Vector3.new(0, 0, 0.0147),
				turned = true,
			},
		} :: { WeaponPart },
		rainbow = true,
		shotGlow = Color3.fromRGB(255, 255, 255),
		bolt = {
			meshId = "rbxassetid://113478574540605",
			size = Vector3.new(0.2298, 0.2298, 1.86),
		},
	},
	ToadstoolStaff = {
		-- `staff_1uncommon_toadstool_staff`, held as the BranchStaff is, playing its kit until it has its own
		kit = "BranchStaff",
		skinOf = "BranchStaff",
		scale = 3.1717,
		parts = {
			{
				name = "Leaves",
				meshId = "rbxassetid://129989536388759",
				size = Vector3.new(0.3539, 0.9798, 0.241),
				offset = Vector3.new(0.0179, -0.0208, 0.0343),
				turned = true,
			},
			{
				name = "Staff",
				meshId = "rbxassetid://126695740347657",
				size = Vector3.new(0.536, 1.415, 0.5442),
				offset = Vector3.new(0, 0.099, 0),
				turned = true,
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
		scale = 3.1005,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://106095730971050",
				size = Vector3.new(0.3605, 0.685, 0.2755),
				offset = Vector3.new(0.0418, 0.35, 0),
				turned = true,
			},
			{
				name = "Leaves",
				meshId = "rbxassetid://104607074694033",
				size = Vector3.new(0.644, 1.3426, 0.1978),
				offset = Vector3.new(0, 0.1537, -0.0189),
				turned = true,
			},
			{
				name = "Staff",
				meshId = "rbxassetid://121562689740574",
				size = Vector3.new(0.5835, 1.4015, 0.13),
				offset = Vector3.new(-0.0112, 0.0783, -0.0188),
				turned = true,
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
		scale = 3.2018,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://76098158499494",
				size = Vector3.new(0.2438, 1.1083, 0.2),
				offset = Vector3.new(-0.004, 0.0514, 0.0117),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(230, 173, 207),
			},
			{
				name = "Leaves",
				meshId = "rbxassetid://104814185219000",
				size = Vector3.new(0.4173, 1.3106, 0.2596),
				offset = Vector3.new(-0.004, 0.0991, -0.0264),
				turned = true,
			},
			{
				name = "Staff",
				meshId = "rbxassetid://96482308261364",
				size = Vector3.new(0.4525, 1.4017, 0.3124),
				offset = Vector3.new(0, 0.0981, 0),
				turned = true,
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
		scale = 3.2057,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://134682568298856",
				size = Vector3.new(0.1364, 0.1364, 0.1887),
				offset = Vector3.new(0, 0.533, 0.0234),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(230, 254, 205),
			},
			{
				name = "Leaves",
				meshId = "rbxassetid://107629102917312",
				size = Vector3.new(0.033, 0.0226, 0.018),
				offset = Vector3.new(0.05, -0.252, 0.0133),
				turned = true,
			},
			{
				name = "Staff",
				meshId = "rbxassetid://125389184367792",
				size = Vector3.new(0.5155, 1.4, 0.23),
				offset = Vector3.new(0, 0.098, -0.0027),
				turned = true,
			},
		} :: { WeaponPart },
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
		scale = 2.2238,
		parts = {
			{
				name = "Glow",
				meshId = "rbxassetid://122983161920504",
				size = Vector3.new(0.8073, 1.9482, 0.4527),
				offset = Vector3.new(0, 0.1763, 0.052),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(33, 244, 254),
			},
			{
				name = "Leaves",
				meshId = "rbxassetid://71365593178255",
				size = Vector3.new(0.6692, 1.5544, 0.492),
				offset = Vector3.new(-0.0147, 0.2099, -0.0324),
				turned = true,
			},
			{
				name = "Staff",
				meshId = "rbxassetid://79553391688912",
				size = Vector3.new(0.6212, 1.9188, 0.4212),
				offset = Vector3.new(0.0005, 0.0916, -0.0288),
				turned = true,
			},
		} :: { WeaponPart },
		rainbow = true,
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
		scale = 3.8,
		parts = {
			{
				name = "Blade",
				meshId = "rbxassetid://87369709718225",
				size = Vector3.new(0.51, 1.26, 0.144),
				offset = Vector3.new(0, 0.31, 0),
				turned = true,
			},
		} :: { WeaponPart },
	},
	ThornBlade = {
		-- `blade_2rare_thorn_blade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 3.6273,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://120853681923542",
				size = Vector3.new(0.062, 0.4522, 0.16),
				offset = Vector3.new(0, -0.0624, 0),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(191, 21, 46),
			},
			{
				name = "Blade",
				meshId = "rbxassetid://130252304830966",
				size = Vector3.new(0.6362, 1.32, 0.1503),
				offset = Vector3.new(0, 0.3247, 0),
				turned = true,
			},
		} :: { WeaponPart },
	},
	BroodsplitBlade = {
		-- `blade_3epic_broodsplit_blade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 3.8,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://96954538193459",
				size = Vector3.new(0.486, 1.1955, 0.1034),
				offset = Vector3.new(0, 0.3278, 0),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(123, 239, 73),
			},
			{
				name = "Blade",
				meshId = "rbxassetid://116958050912805",
				size = Vector3.new(0.47, 1.26, 0.15),
				offset = Vector3.new(0, 0.31, 0),
				turned = true,
			},
		} :: { WeaponPart },
	},
	EmberfangBlade = {
		-- `blade_4legendary_emberfang_blade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 3.8,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://81579522020297",
				size = Vector3.new(0.172, 0.3955, 0.144),
				offset = Vector3.new(0, -0.0878, 0),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(253, 127, 53),
			},
			{
				name = "Blade",
				meshId = "rbxassetid://107148867269470",
				size = Vector3.new(0.48, 1.26, 0.15),
				offset = Vector3.new(0, 0.31, 0),
				turned = true,
			},
		} :: { WeaponPart },
		trailGlow = Color3.fromRGB(253, 127, 53),
	},
	GladeheartBlade = {
		-- `blade_5mythic_gladeheart_blade`, held as the TimberBlade is, playing its kit until it has its own
		kit = "TimberBlade",
		skinOf = "TimberBlade",
		scale = 3.3718,
		parts = {
			{
				name = "Gems",
				meshId = "rbxassetid://133742532415891",
				size = Vector3.new(0.3386, 1.139, 0.18),
				offset = Vector3.new(0, 0.2389, 0),
				turned = true,
				glow = true,
				colour = Color3.fromRGB(222, 190, 243),
			},
			{
				name = "Blade",
				meshId = "rbxassetid://118710855901777",
				size = Vector3.new(0.6797, 1.42, 0.1677),
				offset = Vector3.new(0, 0.3493, -0.0042),
				turned = true,
			},
		} :: { WeaponPart },
		rainbow = true,
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
				offset = Vector3.new(0, 0.07, 0),
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
				offset = Vector3.new(0, 0.2459, 0),
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
				offset = Vector3.new(0, 0, 0),
				turned = true,
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
				offset = Vector3.new(0, 0.2459, 0),
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
				offset = Vector3.new(0, 0, 0),
				turned = true,
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
				offset = Vector3.new(0, 0.07, 0),
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
				offset = Vector3.new(0, 0.2459, 0),
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
				offset = Vector3.new(0, 0, 0),
				turned = true,
				textureId = "rbxassetid://87111981155450",
			},
		} :: { WeaponPart },
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
				offset = Vector3.new(0, 0.2459, 0),
				turned = true,
				textureId = "rbxassetid://78360244322797",
			},
		} :: { WeaponPart },
		trailGlow = Color3.fromRGB(255, 255, 255),
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
