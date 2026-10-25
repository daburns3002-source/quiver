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
} :: Weapon

return table.freeze(Weapons)
