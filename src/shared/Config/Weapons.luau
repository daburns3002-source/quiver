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
	--[[ A layer under all of these for the joints a clip leaves out: `idle`
	     standing, `walk` moving, played faster or slower to match the
	     character's speed against `walkSpeed`, the studs a second it was
	     made for. The bow's Hold moves only the upper body, and these give
	     it the owner's stance and stride (`LeafBow_R15_Kit`). ]]
	legs: { idle: string, walk: string, walkSpeed: number }?,
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
	--[[ The Ranger's bow (`assets/models/weapons/leaf_bow_roblox.glb`,
	     imported 2026-10-23), held in the left hand where the owner's
	     kit holds it (`assets/models/weapons/leaf_bow_r15/`). About 4 studs tall. ]]
	LeafBow = {
		hand = "LeftHand",
		scale = 3.8,
		grip = Vector3.new(0, -0.15, 0),
		--[[ The owner's LeafBow R15 kit (2026-10-23,
		     `assets/models/weapons/leaf_bow_r15/LeafBow_R15_Kit.rbxmx`):
		     Hold for the upper body over the Idle or Walk legs, Draw, Aim
		     and Fire for the whole body. ]]
		clips = {
			hold = "Hold",
			ready = "Draw",
			aim = "Aim",
			fire = { "Fire" },
			legs = { idle = "Idle", walk = "Walk", walkSpeed = 5.351651 },
		},
		fireSound = "arrow_fire",
		--[[ From the kit's README, turned into this model's frame (the
		     arrow points +Z here, −Z in the kit). ]]
		bowString = {
			top = Vector3.new(0, 0.407, -0.1685),
			bottom = Vector3.new(0, -0.4001, -0.1701),
			nock = Vector3.new(0.045, 0.108, -0.1691),
			rest = Vector3.new(0.045, 0.108, 0.05),
		},
		parts = {
			{
				name = "Bow",
				meshId = "rbxassetid://110001034499189",
				size = Vector3.new(0.0838, 0.9297, 0.2581),
				offset = Vector3.new(0.0000, -0.0002, -0.0525),
			},
			{
				name = "Leaves",
				meshId = "rbxassetid://117994438971049",
				size = Vector3.new(0.0402, 1.1105, 0.1118),
				offset = Vector3.new(-0.0001, -0.0017, -0.1802),
			},
			{
				name = "Trim",
				meshId = "rbxassetid://93466767514316",
				size = Vector3.new(0.0961, 0.9120, 0.2363),
				offset = Vector3.new(-0.0001, 0.0009, -0.0662),
			},
			{
				name = "String",
				meshId = "rbxassetid://72336765556882",
				size = Vector3.new(0.0506, 0.8077, 0.0072),
				offset = Vector3.new(0.0225, 0.0000, -0.1697),
				liveString = true,
			},
			{
				name = "Gem",
				meshId = "rbxassetid://79842521517254",
				size = Vector3.new(0.1110, 0.0437, 0.0460),
				offset = Vector3.new(0.0000, 0.1565, -0.0029),
				glow = true,
			},
			{
				name = "Arrow",
				meshId = "rbxassetid://101205850995018",
				size = Vector3.new(0.0754, 0.0653, 0.8640),
				offset = Vector3.new(0.0450, 0.1148, 0.2605),
				nocked = true,
			},
		},
	} :: Weapon,

	--[[ The Arcanist's staff (`assets/models/weapons/arcane_staff_roblox.glb`,
	     imported 2026-10-23), held upright in the right hand where the
	     owner's kit holds it (`assets/models/weapons/arcane_staff_r15/`):
	     gripped mid-shaft, about 4.7 studs tall. ]]
	ArcaneStaff = {
		hand = "RightHand",
		scale = 3.4,
		grip = Vector3.new(0, -0.1, 0),
		clips = { hold = "Hold", ready = "Charge", aim = "Channel", fire = { "Cast" } },
		fireSound = "staff_cast",
		--[[ The kit's, turned into this model's frame. ]]
		orbitAxis = Vector3.new(0, -0.3146, -0.9492),
		--[[ The kit's bolt (`assets/models/weapons/arcane_bolt_roblox.glb`,
		     imported 2026-10-23): a faceted blue ball. ]]
		bolt = {
			meshId = "rbxassetid://126459524560740",
			size = Vector3.new(0.098, 0.1, 0.099),
		},
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://107891163169138",
				size = Vector3.new(0.2404, 1.1307, 0.1341),
				offset = Vector3.new(-0.0002, 0.1962, 0.0000),
			},
			{
				name = "Trim",
				meshId = "rbxassetid://90469048167793",
				size = Vector3.new(0.2191, 1.3088, 0.1501),
				offset = Vector3.new(-0.0002, 0.1005, 0.0031),
			},
			{
				name = "Gems",
				meshId = "rbxassetid://78968569678522",
				size = Vector3.new(0.0654, 1.1079, 0.7694),
				offset = Vector3.new(-0.0016, -0.0261, 0.3539),
				glow = true,
			},
			{
				name = "Orb",
				meshId = "rbxassetid://130121013734391",
				size = Vector3.new(0.1449, 0.1451, 0.1449),
				offset = Vector3.new(-0.0015, 0.6435, 0.0000),
				glow = true,
				orb = true,
			},
			{
				name = "Orbits",
				meshId = "rbxassetid://123851869923567",
				size = Vector3.new(0.2915, 0.2871, 0.1095),
				offset = Vector3.new(0.0000, 0.6356, 0.0082),
				orbit = true,
			},
		},
	} :: Weapon,

	--[[ The Warden's ruby greatsword (`assets/models/weapons/
	     ruby_greatsword_roblox.glb`, the owner's kit in
	     `ruby_greatsword_r15/`, imported 2026-10-23): two-handed, the right
	     hand on the upper grip and the left placed by the animations on the
	     lower, about 5 studs from pommel to tip. Offsets are from the upper
	     grip, model Y 0.062; the kit's weld turns the blade along the hand's
	     −Z with the edge down. Its colours are baked textures, so each part
	     names its colour map. Its Walk drags the blade; its three slashes
	     are a combo, the third an overhead slam. ]]
	RubyGreatsword = {
		hand = "RightHand",
		scale = 4.0,
		grip = Vector3.new(0, -0.1, 0),
		inHand = CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
		clips = {
			hold = "Hold",
			move = "Walk",
			moveSpeed = 6,
			fire = { "Slash_A", "Slash_B", "Slash_C" },
		},
		fireSound = "sword_swing",
		--[[ A sound for each blow, made to the shape of the owner's
		     reference clip (2026-10-23, `assets/audio/synth.py` round 9). ]]
		comboSounds = { "sword_swing", "sword_swing_2", "sword_slam" },
		swingTrail = {
			base = Vector3.new(0, 0.44 - 0.062, 0),
			tip = Vector3.new(0, 1.0216 - 0.062, 0),
			colour = { Color3.fromRGB(255, 120, 100), Color3.fromRGB(216, 35, 47) },
		},
		--[[ After the kit's drag sparks (orange, rate 45) and its notes on
		     an impact burst and a shake on the slam. `reach` is how far in
		     front the burst lands, studs; `shake` is studs of camera
		     shake over `shakeTime` seconds. ]]
		blade = {
			sparkColour = Color3.fromRGB(255, 170, 70),
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
				meshId = "rbxassetid://81177474115791",
				size = Vector3.new(0.2024, 0.7754, 0.0410),
				offset = Vector3.new(0.0000, 0.5719, 0.0000),
				textureId = "rbxassetid://109422005464586",
			},
			{
				name = "Fuller",
				meshId = "rbxassetid://94721709561581",
				size = Vector3.new(0.0438, 0.6715, 0.0533),
				offset = Vector3.new(0.0000, 0.5199, 0.0000),
				textureId = "rbxassetid://94166397640483",
			},
			{
				name = "Gold_Trim",
				meshId = "rbxassetid://93771149745639",
				size = Vector3.new(0.3593, 1.1834, 0.0793),
				offset = Vector3.new(0.0000, 0.2876, 0.0000),
				textureId = "rbxassetid://106699129882172",
			},
			{
				name = "Guard",
				meshId = "rbxassetid://110968987767753",
				size = Vector3.new(0.2530, 0.1801, 0.0656),
				offset = Vector3.new(0.0000, 0.1333, 0.0000),
				textureId = "rbxassetid://128210431219594",
			},
			{
				name = "Horns",
				meshId = "rbxassetid://85156262532772",
				size = Vector3.new(0.4762, 0.1960, 0.0656),
				offset = Vector3.new(0.0000, 0.1530, 0.0000),
				textureId = "rbxassetid://106246437883710",
			},
			{
				name = "Grip",
				meshId = "rbxassetid://82245855764564",
				size = Vector3.new(0.0539, 0.1833, 0.0539),
				offset = Vector3.new(0.0000, -0.0661, 0.0000),
				textureId = "rbxassetid://123206334207297",
			},
			{
				name = "Pommel",
				meshId = "rbxassetid://105635285530014",
				size = Vector3.new(0.1253, 0.3282, 0.0602),
				offset = Vector3.new(0.0000, -0.1331, 0.0000),
				textureId = "rbxassetid://85691278304365",
			},
			{
				name = "Gems",
				meshId = "rbxassetid://111607416746563",
				size = Vector3.new(0.0684, 0.4158, 0.0903),
				offset = Vector3.new(0.0000, -0.0593, 0.0000),
				glow = true,
				colour = Color3.fromRGB(216, 35, 47),
			},
		},
	} :: Weapon,
}

--[[ The Dual Bows Mythic (`Config/Abilities.DualBows.weapon`): the leaf bow
     in each hand, held up as the owner's posed rig holds them
     (`assets/models/weapons/leaf_bow_dual_r15/`, 2026-10-23). The same
     meshes at the same grip in either hand. It holds that pose while it
     fires, so it has no draw and no live string. ]]
local leafBow = Weapons.LeafBow;
(Weapons :: any).LeafBowDual = {
	hand = leafBow.hand,
	scale = leafBow.scale,
	grip = leafBow.grip,
	clips = { hold = "Hold", fire = { "Fire" } },
	fireSound = leafBow.fireSound,
	offhand = { hand = "RightHand", grip = leafBow.grip },
	parts = leafBow.parts,
} :: Weapon

return table.freeze(Weapons)
