--!strict
--[[
	The Angel's body, built from blocks (owner, 2026-11-02: "add an angel
	room ... it should be in the blocky design language", then "ok i like it
	build the model" of the reference sheet).

	Its sheet is `assets/concepts/blocky/encounters/angel/angel_views.png`,
	drawn by Codex from `angel_views.prompt.txt` and approved by the owner.
	Every measurement below is read off that sheet, and `tests/Angel.spec`
	holds the shape to it: the halo floats clear above the head, the wings
	step outward and up in threes, the hem is wider than the torso, and the
	whole figure hovers clear of the ground.

	The wings sit outboard of the arms, not beside them. Drawn from the
	first pass's numbers the two overlapped across X and the front view read
	as one wide shelf rather than as arms in front of wings, which
	`views.py` caught before any of it shipped.

	**It is parts rather than a mesh.** CLAUDE.md rule 10 sends 3D models
	through Claude Design in the owner's Chrome, and no Chrome was connected
	when this was built (`list_connected_browsers` returned nothing, and the
	owner was away from their computer). For a figure the sheet draws as
	sixteen axis-aligned blocks that is no loss: blocks placed from the
	sheet's own proportions match it more exactly than a mesh traced from it
	would, and nothing has to be imported or uploaded. A GLB can replace this
	later without touching the room: `Run/AngelProp` is the only thing that
	reads it.

	Pure data, like `Config/EnemyDesigns`. Offsets are from the point on the
	floor the Angel stands over, so y is height above the ground and the
	figure hovers because its lowest block does. Forward is **-Z**, as
	everywhere else in the game, so the face looks down -Z.
]]

export type Shape = "Block" | "Cylinder"

export type Part = {
	name: string,
	size: Vector3,
	--[[ From the floor point it hovers over. +Y is up, -Z is the way it
	     faces. ]]
	offset: Vector3,
	color: Color3,
	shape: Shape?,
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

local function block(name: string, size: Vector3, offset: Vector3, color: Color3): Part
	return { name = name, size = size, offset = offset, color = color }
end

--[[ One wing: three flat blocks stepping outward and up, smaller as they
     go, set back behind the arms as the WINGS panel shows. `side` is -1 for
     the left wing and 1 for the right. ]]
local function wing(side: number): { Part }
	local tag = if side < 0 then "Left" else "Right"
	return {
		block(
			`Wing{tag}1`,
			Vector3.new(0.95, 1.5, 0.36),
			Vector3.new(side * 1.9, 4.35, 0.5),
			CREAM
		),
		block(`Wing{tag}2`, Vector3.new(0.8, 1.2, 0.36), Vector3.new(side * 2.6, 4.95, 0.5), CREAM),
		block(
			`Wing{tag}3`,
			Vector3.new(0.65, 0.9, 0.36),
			Vector3.new(side * 3.15, 5.5, 0.5),
			CREAM
		),
	}
end

local parts: { Part } = {
	--[[ The robe: a hem wider than the torso above it, so the figure reads
	     as robed rather than as a stack of boxes. No legs and no feet. ]]
	block("Hem", Vector3.new(2.6, 0.9, 1.7), Vector3.new(0, 2.05, 0), CREAM),
	block("Torso", Vector3.new(2.2, 2.4, 1.4), Vector3.new(0, 3.7, 0), CREAM),
	block("Waist", Vector3.new(2.32, 0.36, 1.52), Vector3.new(0, 2.6, 0), GOLD),
	block("Brooch", Vector3.new(0.55, 0.55, 0.1), Vector3.new(0, 3.9, -0.72), GOLD),

	block("Head", Vector3.new(1.9, 1.6, 1.6), Vector3.new(0, 5.7, 0), CREAM),
	--[[ Two closed eyes, flat on the face. No mouth, no nose, no hair. ]]
	block("EyeLeft", Vector3.new(0.46, 0.16, 0.08), Vector3.new(-0.42, 5.75, -0.82), EYE),
	block("EyeRight", Vector3.new(0.46, 0.16, 0.08), Vector3.new(0.42, 5.75, -0.82), EYE),

	--[[ Arms held calmly down at the sides, in front of the wings. ]]
	block("ArmLeft", Vector3.new(0.6, 1.7, 0.6), Vector3.new(-1.25, 3.5, -0.25), CREAM),
	block("ArmRight", Vector3.new(0.6, 1.7, 0.6), Vector3.new(1.25, 3.5, -0.25), CREAM),

	--[[ The halo: four bars making a flat rectangle, level, floating clear
	     above the head rather than resting on it. ]]
	block("HaloFront", Vector3.new(2.2, 0.22, 0.22), Vector3.new(0, 6.95, -0.74), GOLD),
	block("HaloBack", Vector3.new(2.2, 0.22, 0.22), Vector3.new(0, 6.95, 0.74), GOLD),
	block("HaloLeft", Vector3.new(0.22, 0.22, 1.7), Vector3.new(-0.99, 6.95, 0), GOLD),
	block("HaloRight", Vector3.new(0.22, 0.22, 1.7), Vector3.new(0.99, 6.95, 0), GOLD),
}

for _, side in { -1, 1 } do
	for _, piece in wing(side) do
		table.insert(parts, piece)
	end
end

--[[ The warm pool of light under it, which the sheet draws in every view
     where the ground shows. Not part of the body: it stays on the floor
     while the figure bobs over it. ]]
table.insert(parts, {
	name = "Glow",
	--[[ A Cylinder's axis runs along its X, and `Run/AngelProp` turns that
	     axis upright, so X is the disc's thickness and Y and Z are its
	     width. Written the other way round it stood on edge as a 3.4-thick
	     wheel: caught in Studio, where the model came out 8.73 tall instead
	     of 7.06. ]]
	size = Vector3.new(0.06, 3.4, 3.4),
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
	     off the sheet, where the Angel hovers about a third of its own
	     height up. ]]
	hover = 1.6,

	--[[ The slow bob that sells the hover: this far up and down from where
	     the parts above put it, over this many seconds a full rise or fall.
	     Small on purpose — an Angel that bounces reads as a toy. ]]
	bob = 0.35,
	bobSeconds = 2.2,

	--[[ The warm light it gives off, and how far it reaches. ]]
	light = Color3.fromRGB(255, 232, 170),
	lightRange = 18,
	lightBrightness = 2,

	--[[ Its height all told, halo included, for anything that needs to frame
	     it. `tests/Angel.spec` checks the parts agree. ]]
	height = 7.06,
}

return table.freeze(AngelDesign)
