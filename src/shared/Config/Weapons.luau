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
	--[[ Shown only while an arrow is drawn: the nocked arrow. ]]
	nocked: boolean?,
}

export type Weapon = {
	--[[ The hand it is welded to. ]]
	hand: string,
	--[[ Studs per model unit. ]]
	scale: number,
	parts: { WeaponPart },
}

local Weapons = {
	--[[ The Ranger's bow (`assets/models/weapons/leaf_bow_roblox.glb`,
	     imported 2026-10-23), held in the left hand. About 3.5 studs tall. ]]
	LeafBow = {
		hand = "LeftHand",
		scale = 3.2,
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
			{
				name = "Arrow",
				meshId = "rbxassetid://101205850995018",
				size = Vector3.new(0.0754, 0.0653, 0.8640),
				offset = Vector3.new(0.0450, 0.1148, 0.2605),
				nocked = true,
			},
		},
	} :: Weapon,

	--[[
		The archer's arms, in degrees on the R15 shoulder and elbow joints.

		The bow arm is held out in front the whole time, bow upright. The
		string hand sits at full draw by the chin: the upper arm raised
		forward and out to the right, turned so the elbow folds sideways, the
		forearm folded back across to the face. The R15 elbow bends at most
		120°, which is why the arm is turned rather than simply bent. On each shot (owner, 2026-10-23: "an
		animation for shooting") it flicks back past the cheek for `release`
		seconds, reaches forward to the string, and draws again over `draw`
		seconds; the nocked arrow shows once the draw begins.
	]]
	archerPose = {
		bowShoulder = Vector3.new(90, 0, -10),
		bowElbow = Vector3.new(0, 0, 0),
		stringShoulderRest = Vector3.new(90, 35, 0),
		stringShoulderDrawn = Vector3.new(90, -35, 90),
		stringElbowRest = Vector3.new(10, 0, 0),
		stringElbowDrawn = Vector3.new(120, 0, 0),
		release = 0.08,
		draw = 0.32,
		--[[ The share of `draw` spent reaching forward to the string. ]]
		reach = 0.35,
		--[[ How far the bow arm kicks back on a release, degrees. ]]
		recoil = 6,
	},
}

return table.freeze(Weapons)
