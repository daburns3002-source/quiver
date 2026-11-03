--!strict
--[[
	The Angel's body, built from blocks (owner, 2026-11-02: "add an angel
	room ... it should be in the blocky design language", then "ok i like it
	build the model" of the reference sheet, then "Redo as a GLB" and "keep
	redoing it until it looks 1 to 1 with the reference pic").

	Its sheet is `assets/concepts/blocky/encounters/angel/angel_views.png`,
	drawn by Codex and approved by the owner. Every measurement here is read
	off that sheet's FRONT, LEFT SIDE and WINGS panels as a proportion of the
	head's width -- the one thing measurable in all of them -- and then set
	against a head 2.25 studs wide.

	What the sheet actually shows, which two earlier passes got wrong:

	  * **The wings grow outward.** Each is three slabs that get bigger and
	    higher the further out they go, the outermost as tall as the head and
	    reaching its top. They were built shrinking outward, which read as
	    stairs going down.
	  * **The lower robe is narrower than the torso**, not flared wider: the
	    gold band is the widest thing on the body and the hem tucks under it.
	  * The halo floats a clear half-head above the head and is half again
	    its width.
	  * The eyes and the brooch stand proud of the faces they sit on, or they
	    disappear into them.

	`tests/Angel.spec` holds all of that, and
	`assets/concepts/blocky/encounters/angel/views.py` draws the result flat
	to hold against the sheet without Studio, whose `screen_capture` returns
	an empty frame.

	Offsets are from the point on the floor the Angel hovers over, so y is
	height above the ground and the figure floats because its lowest block
	does. Forward is **-Z**, as everywhere else in the game.
]]

export type Shape = "Block" | "Cylinder"

export type Part = {
	name: string,
	size: Vector3,
	--[[ From the floor point it hovers over. +Y is up, -Z is the way it
	     faces. ]]
	offset: Vector3,
	color: Color3,
	--[[ Degrees about the local axes, for the wing slabs: the sheet's
	     wings are swept feathers, not a staircase of upright cubes (owner,
	     2026-11-02: "the wings are off"). Everything else leaves it out. ]]
	rotation: Vector3?,
	shape: Shape?,
	--[[ The halo. The owner's imported Angel has no halo of its own (its
	     sheet is `angel_no_halo_four_views.png`), so these blocks are built
	     whether the mesh is drawn or not. ]]
	halo: boolean?,
	--[[ Drawn Neon: the pool of light on the ground. ]]
	glow: boolean?,
	--[[ Left out of the hover bob, so the light stays on the ground while
	     the figure rises and falls over it. ]]
	grounded: boolean?,
}

--[[ The sheet's three colours and nothing else: cream robe, gold trim, and
     the dark line of a closed eye. ]]
local CREAM = Color3.fromRGB(248, 243, 222)
local GOLD = Color3.fromRGB(244, 181, 63)
local EYE = Color3.fromRGB(78, 58, 38)

local function block(
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	rotation: Vector3?
): Part
	return { name = name, size = size, offset = offset, color = color, rotation = rotation }
end

local function halo(name: string, size: Vector3, offset: Vector3): Part
	return { name = name, size = size, offset = offset, color = GOLD, halo = true }
end

--[[ One wing: three feathers fanning up and out from the shoulder, each
     longer than the last and tilted further over, as the sheet's WINGS
     panel draws them. They were a staircase of upright cubes for three
     passes and the owner called it: "the wings are off".

     `side` is -1 for the left wing and 1 for the right. The tilt is about
     Z, which lifts the outer end of a slab in the frontal plane, so it is
     mirrored with the side. ]]
local FEATHERS: { { length: number, depth: number, out: number, up: number, tilt: number } } = {
	{ length = 1.25, depth = 0.85, out = 1.45, up = 3.95, tilt = 10 },
	{ length = 1.45, depth = 0.9, out = 2, up = 4.6, tilt = 20 },
	{ length = 1.6, depth = 0.95, out = 2.45, up = 5.3, tilt = 32 },
}

local function wing(side: number): { Part }
	local tag = if side < 0 then "Left" else "Right"
	local out: { Part } = {}
	for index, feather in FEATHERS do
		table.insert(
			out,
			block(
				`Wing{tag}{index}`,
				Vector3.new(feather.length, feather.depth, 0.4),
				Vector3.new(side * feather.out, feather.up, 0.45),
				CREAM,
				Vector3.new(0, 0, side * -feather.tilt)
			)
		)
	end
	return out
end

local parts: { Part } = {
	--[[ The robe, bottom up: a hem tucked under the band, the band itself
	     the widest thing on the body, then the torso. No legs, no feet. ]]
	block("Hem", Vector3.new(2, 0.6, 1.45), Vector3.new(0, 1.8, 0), CREAM),
	block("Waist", Vector3.new(2.16, 0.32, 1.58), Vector3.new(0, 2.26, 0), GOLD),
	block("Torso", Vector3.new(2.05, 1.75, 1.45), Vector3.new(0, 3.295, 0), CREAM),
	--[[ Standing proud of the chest, or it vanishes into it. ]]
	block("Brooch", Vector3.new(0.62, 0.62, 0.14), Vector3.new(0, 3.45, -0.76), GOLD),

	--[[ Arms held calmly down at the sides, clear of the torso and in front
	     of the wings. ]]
	block("ArmLeft", Vector3.new(0.52, 1.3, 0.52), Vector3.new(-1.31, 3.15, -0.3), CREAM),
	block("ArmRight", Vector3.new(0.52, 1.3, 0.52), Vector3.new(1.31, 3.15, -0.3), CREAM),

	--[[ A big head, a little wider than the torso. ]]
	block("Head", Vector3.new(2.25, 1.9, 1.9), Vector3.new(0, 5.12, 0), CREAM),
	--[[ Two closed eyes, proud of the face. No mouth, no nose, no hair. ]]
	block("EyeLeft", Vector3.new(0.55, 0.2, 0.14), Vector3.new(-0.52, 5, -0.98), EYE),
	block("EyeRight", Vector3.new(0.55, 0.2, 0.14), Vector3.new(0.52, 5, -0.98), EYE),

	--[[ The halo: four bars making a flat ring, level, floating a clear
	     gap above the head and half again its width.

	     It sat at 6.54, which left no gap at all over the owner's imported
	     head and read as a gold plate resting on it (seen in Studio,
	     2026-11-02). Raised to float 0.78 above the head, about four tenths
	     of a head, as the sheet draws it. ]]
	halo("HaloFront", Vector3.new(3, 0.3, 0.3), Vector3.new(0, 7, -0.95)),
	halo("HaloBack", Vector3.new(3, 0.3, 0.3), Vector3.new(0, 7, 0.95)),
	halo("HaloLeft", Vector3.new(0.3, 0.3, 2.2), Vector3.new(-1.35, 7, 0)),
	halo("HaloRight", Vector3.new(0.3, 0.3, 2.2), Vector3.new(1.35, 7, 0)),
}

for _, side in { -1, 1 } do
	for _, piece in wing(side) do
		table.insert(parts, piece)
	end
end

--[[ The warm pool of light under it, which the sheet draws in every view
     where the ground shows. Not part of the body: it stays on the floor
     while the figure bobs over it.

     A Cylinder's axis runs along its X, and `Run/AngelProp` turns that axis
     upright, so X is the disc's thickness and Y and Z are its width.
     Written the other way round it stood on edge as a 3.4-thick wheel. ]]
table.insert(parts, {
	name = "Glow",
	size = Vector3.new(0.06, 3.6, 3.6),
	offset = Vector3.new(0, 0.03, 0),
	color = GOLD,
	shape = "Cylinder" :: Shape,
	glow = true,
	grounded = true,
})

local AngelDesign = {
	parts = parts,

	cream = CREAM,
	gold = GOLD,
	eye = EYE,

	--[[ How far the lowest block of the body floats above the floor. Read
	     off the sheet, where the Angel hovers about a fifth of its own
	     height up. ]]
	hover = 1.5,

	--[[ The slow bob that sells the hover: this far up and down from where
	     the parts above put it, over this many seconds a full rise or fall.
	     Small on purpose -- an Angel that bounces reads as a toy. ]]
	bob = 0.35,
	bobSeconds = 2.2,

	--[[ The warm light it gives off, and how far it reaches. ]]
	light = Color3.fromRGB(255, 232, 170),
	lightRange = 18,
	lightBrightness = 2,

	--[[ Its height all told, halo included, for anything that needs to frame
	     it. `tests/Angel.spec` checks the parts agree. ]]
	height = 7.15,

	--[[
		The Angel the owner imported (2026-11-02: "i just imported the angel
		room model"), which is what the room draws when the id is filled in.

		It is ONE textured MeshPart, not the three colour pieces the GLB in
		`assets/models/encounters/angel/` was exported as: the owner modelled
		it from the no-halo reference sheet instead
		(`assets/concepts/blocky/encounters/angel/angel_no_halo_four_views.png`),
		so the cream, the gold and the eyes all come from its texture and
		**it carries no halo**. The halo is the four gold blocks above, built
		whether the mesh is drawn or not.

		`size` is the import measured in Studio at the scale that puts the
		figure where the sheet does: the bottom of its robe on
		`AngelDesign.hover` and the top of its head at 6.07, right under the
		halo. The import is deeper than the blocks are (3.74 against 1.9)
		because its wings sweep back rather than out, so the mesh is NOT the
		box the blocks fill and is not checked against them.

		Empty ids mean no import, and `Run/AngelProp` builds the blocks, which
		is the same figure in the same place.
	]]
	mesh = {
		id = "rbxassetid://137599223664094",
		textureId = "rbxassetid://115778260190544",
		size = Vector3.new(5.398, 4.57, 3.737),
		offset = Vector3.new(0, 3.785, 0),
	},
}

return table.freeze(AngelDesign)
