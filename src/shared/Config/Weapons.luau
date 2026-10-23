--!strict
--[[
	Held weapons: the model each class carries and how its arms move.

	Presentation only. Built on the server so every player sees it
	(`Combat/HeldWeapon`), welded to a hand, never colliding, answering a
	raycast or stopping a shot. The arms are posed on each client
	(`Fx/ArcherPose`).

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
}

export type Weapon = {
	--[[ The hand it is welded to. ]]
	hand: string,
	--[[ Studs per model unit. ]]
	scale: number,
	--[[ Where the grip sits in the hand's own frame, studs. ]]
	grip: Vector3,
	parts: { WeaponPart },
}

local Weapons = {
	--[[ The Ranger's bow (`assets/models/weapons/leaf_bow_roblox.glb`,
	     imported 2026-10-23), held in the left hand where the owner's
	     posed rig holds it. About 4 studs tall. ]]
	LeafBow = {
		hand = "LeftHand",
		scale = 3.8,
		grip = Vector3.new(0, -0.15, 0),
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
			},
			{
				name = "Gem",
				meshId = "rbxassetid://79842521517254",
				size = Vector3.new(0.1110, 0.0437, 0.0460),
				offset = Vector3.new(0.0000, 0.1565, -0.0029),
				glow = true,
			},
		},
	} :: Weapon,

	--[[ The Arcanist's staff (`assets/models/weapons/arcane_staff_roblox.glb`),
	     held upright in the right hand, about 5 studs tall. Parts are filled
	     in from the Studio import; until then the Arcanist holds nothing. ]]
	ArcaneStaff = {
		hand = "RightHand",
		scale = 3.6,
		grip = Vector3.new(0, -0.25, 0),
		parts = {},
	} :: Weapon,

	--[[
		The Arcanist's casting arm (right), in degrees. It
		holds the staff upright before it, forearm level; each cast thrusts
		the arm out straight for `thrust` seconds and eases back over
		`recover`. The left arm is left to Roblox's own animation.
	]]
	casterPose = {
		holdShoulder = Vector3.new(40, 10, 0),
		holdElbow = Vector3.new(50, 0, 0),
		castShoulder = Vector3.new(85, 0, 0),
		castElbow = Vector3.new(5, 0, 0),
		thrust = 0.07,
		recover = 0.35,
	},

	--[[
		The archer's arms: held still in the owner's pose
		(`assets/models/weapons/leaf_bow_r15.glb`, 2026-10-23: "scrap the bow
		animations and use this instead"), bow in the left hand. Each entry
		is a joint's rotation (its `Transform`) on the R15 rig, read straight
		from that file; joints not listed are left to Roblox's animation.
	]]
	archerHold = {
		{
			part = "LeftUpperArm",
			joint = "LeftShoulder",
			rotation = CFrame.fromMatrix(
				Vector3.zero,
				Vector3.new(0.6360, 0.3006, -0.7108),
				Vector3.new(0.0315, 0.9102, 0.4131),
				Vector3.new(0.7711, -0.2851, 0.5694)
			),
		},
		{ part = "LeftLowerArm", joint = "LeftElbow", rotation = CFrame.identity },
		{
			part = "LeftHand",
			joint = "LeftWrist",
			rotation = CFrame.fromMatrix(
				Vector3.zero,
				Vector3.new(0.6056, 0.1593, 0.7796),
				Vector3.new(-0.7030, 0.5662, 0.4304),
				Vector3.new(-0.3729, -0.8087, 0.4549)
			),
		},
		{
			part = "RightUpperArm",
			joint = "RightShoulder",
			rotation = CFrame.fromMatrix(
				Vector3.zero,
				Vector3.new(-0.7679, -0.5269, 0.3643),
				Vector3.new(-0.1311, 0.6859, 0.7157),
				Vector3.new(-0.6270, 0.5019, -0.5958)
			),
		},
		{
			part = "RightLowerArm",
			joint = "RightElbow",
			rotation = CFrame.fromMatrix(
				Vector3.zero,
				Vector3.new(1, 0, 0),
				Vector3.new(0, 0.5154, 0.8570),
				Vector3.new(0, -0.8570, 0.5154)
			),
		},
		{ part = "RightHand", joint = "RightWrist", rotation = CFrame.identity },
	},
}

return table.freeze(Weapons)
