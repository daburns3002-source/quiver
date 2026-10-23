--!strict
--[[
	Held weapons: the model each class carries and how its arms move.

	Presentation only. Built on the server so every player sees it
	(`Combat/HeldWeapon`), welded to a hand, never colliding, answering a
	raycast or stopping a shot. The arms are posed on each client
	(`Fx/ArcherPose`), the bow's string drawn there too (`Fx/BowString`).

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
	--[[ Hidden on the weapon; the client draws its own copy on the string
	     while an arrow is nocked (`Fx/BowString`). ]]
	nocked: boolean?,
	--[[ Hidden for the local player, who sees the live string instead. ]]
	liveString: boolean?,
}

export type Weapon = {
	--[[ The hand it is welded to. ]]
	hand: string,
	--[[ Studs per model unit. ]]
	scale: number,
	--[[ Where the grip sits in the hand's own frame, studs. ]]
	grip: Vector3,
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

	--[[ The Arcanist's staff (`assets/models/weapons/arcane_staff_roblox.glb`),
	     held upright in the right hand, about 5 studs tall, gripped a
	     little over a third of the way up (imported 2026-10-23). ]]
	ArcaneStaff = {
		hand = "RightHand",
		scale = 3.6,
		grip = Vector3.new(0, -0.25, 0),
		parts = {
			{
				name = "Staff",
				meshId = "rbxassetid://107891163169138",
				size = Vector3.new(0.2404, 1.1307, 0.1341),
				offset = Vector3.new(-0.0002, 0.2443, 0.0000),
			},
			{
				name = "Trim",
				meshId = "rbxassetid://90469048167793",
				size = Vector3.new(0.2191, 1.3088, 0.1501),
				offset = Vector3.new(-0.0002, 0.1486, 0.0031),
			},
			{
				name = "Gems",
				meshId = "rbxassetid://78968569678522",
				size = Vector3.new(0.0654, 1.1079, 0.7694),
				offset = Vector3.new(-0.0016, 0.0220, 0.3539),
				glow = true,
			},
			{
				name = "Orb",
				meshId = "rbxassetid://130121013734391",
				size = Vector3.new(0.1449, 0.1451, 0.1449),
				offset = Vector3.new(-0.0015, 0.6916, 0.0000),
				glow = true,
			},
			{
				name = "Orbits",
				meshId = "rbxassetid://123851869923567",
				size = Vector3.new(0.2915, 0.2871, 0.1095),
				offset = Vector3.new(0.0000, 0.6837, 0.0082),
			},
		},
	} :: Weapon,

	--[[ The Arcanist's right arm, in degrees, holding the staff upright
	     before it, forearm level (owner, 2026-10-23: "hold it with one hand",
	     until its animations arrive). The left arm is left to Roblox. ]]
	casterPose = {
		holdShoulder = Vector3.new(40, 10, 0),
		holdElbow = Vector3.new(50, 0, 0),
	},
}

return table.freeze(Weapons)
