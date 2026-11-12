--!strict
--[[
	What each class wears: Outfit C, the blocky armour set (owner, 2026-11-12,
	picking from three drawn options: "for the class choosing make it C"). A
	full chunky voxel set per class, worn over the player's own avatar so
	only the face shows, on the class select cards, the Gear portrait and in
	a run. `Util/ClassOutfit` dresses a character from this.

	A set is a list of pieces. A piece is welded to one R15 body part and is
	one closed solid of its own: nothing is cut out of a body, so a bent knee
	or a raised arm shows the avatar underneath, never the inside of a shell.
	(The class bodies taken out on 2026-11-07 were whole bodies cut into R15
	parts, and every cut was a hole: docs/FIXES.md.)

	Everything is measured on the standard blocky R15 body (`standard`, read
	off Roblox's default rig), in the body part's own space: X to the
	character's right, Y up, the front at -Z, the part's centre at zero. A
	body part that is larger has its piece stretched to it, never shrunk
	(`ClassOutfit.ratio`, `stretch`), and in a run the avatar is set to the
	standard proportions first (`scales`).

	`blocks` is the piece built from plain coloured boxes: the plan the
	Claude Design model was made to. `meshId`, `size` and `at` are that
	model's mesh (`MESHES` below), and the blocks are only the fallback for
	a mesh that fails to load.

	Rules the data keeps (`tests/ClassOutfits.spec`): every class has a set
	that covers the head, both halves of the torso, and every arm and leg
	segment and foot (hands stay bare: the weapon sits in them); every piece
	names a real body part; left and right pieces mirror each other; the face
	stays open; nothing reaches under the floor; and no two faces share a
	plane, which would flicker.
]]

export type Block = {
	size: Vector3,
	at: Vector3,
	colour: Color3,
	--[[ Neon: a crystal. ]]
	glow: boolean?,
}

export type Piece = {
	name: string,
	--[[ The R15 body part it is welded to. ]]
	part: string,
	blocks: { Block },
	--[[ The imported model, when there is one: its mesh, its size on the
	     standard body and its centre from the body part's centre. `turned`
	     for an import that came in facing backwards. ]]
	meshId: string?,
	size: Vector3?,
	at: Vector3?,
	turned: boolean?,
	--[[ The model's glowing blocks (a crystal), worn over its mesh as Neon:
	     a mesh is one material and cannot glow in part. ]]
	glows: { Block }?,
}

export type Outfit = { pieces: { Piece } }

export type Body = { size: Vector3, at: Vector3 }

local rgb = Color3.fromRGB

--[[ A box from its two corners. ]]
local function box(
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	colour: Color3,
	glow: boolean?
): Block
	return {
		size = Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		at = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		colour = colour,
		glow = glow,
	}
end

--[[ The same blocks on the other side of the body. ]]
local function flipped(blocks: { Block }): { Block }
	local out: { Block } = {}
	for _, block in blocks do
		table.insert(out, {
			size = block.size,
			at = Vector3.new(-block.at.X, block.at.Y, block.at.Z),
			colour = block.colour,
			glow = block.glow,
		})
	end
	return out
end

--[[ `blocks` and their mirror image, for a piece that has both sides. ]]
local function both(blocks: { Block }): { Block }
	local out = table.clone(blocks)
	for _, block in flipped(blocks) do
		table.insert(out, block)
	end
	return out
end

local function join(...: { Block }): { Block }
	local out: { Block } = {}
	for _, list in { ... } do
		for _, block in list do
			table.insert(out, block)
		end
	end
	return out
end

--[[ A right-hand piece and its left-hand twin. ]]
local function pair(name: string, part: string, right: { Block }): (Piece, Piece)
	return { name = `Right{name}`, part = `Right{part}`, blocks = right }, {
		name = `Left{name}`,
		part = `Left{part}`,
		blocks = flipped(right),
	}
end

--[[ Ranger: leaf hood with ears, a wooden guard on one shoulder, a leaf
     cloak and big boots. ]]
local function ranger(): Outfit
	local green, dark, light = rgb(47, 145, 80), rgb(28, 99, 54), rgb(127, 214, 114)
	local leather, hide, wood = rgb(138, 90, 43), rgb(91, 58, 28), rgb(176, 122, 66)
	local gold, hem = rgb(231, 185, 62), rgb(19, 74, 38)
	local sleeveR, sleeveL = pair("Sleeve", "UpperArm", {
		box(-0.52, 0.60, -0.36, 0.56, -0.58, 0.58, green),
	})
	local bracerR, bracerL = pair("Bracer", "LowerArm", {
		box(-0.56, 0.66, -0.48, 0.20, -0.64, 0.64, leather),
		box(-0.56, 0.66, 0.20, 0.30, -0.64, 0.64, wood),
	})
	local thighR, thighL = pair("Trouser", "UpperLeg", {
		box(-0.50, 0.60, -0.38, 0.42, -0.57, 0.57, leather),
	})
	local bootR, bootL = pair("Boot", "LowerLeg", {
		box(-0.50, 0.68, -0.45, 0.20, -0.66, 0.66, hide),
		box(-0.50, 0.72, 0.20, 0.40, -0.70, 0.70, leather),
	})
	local footR, footL = pair("Sole", "Foot", {
		box(-0.505, 0.64, -0.15, 0.20, -0.90, 0.62, hide),
	})
	return {
		pieces = {
			{
				name = "Hood",
				part = "Head",
				blocks = join(
					{
						-- the cap, overhanging all round, and its stepped crown
						box(-0.78, 0.78, 0.52, 0.80, -0.80, 0.78, green),
						box(-0.56, 0.56, 0.80, 1.00, -0.50, 0.66, green),
						box(-0.34, 0.34, 1.00, 1.14, -0.24, 0.52, light),
						-- the back, down over the neck
						box(-0.72, 0.72, -0.78, 0.52, 0.50, 0.72, green),
					},
					both({
						-- the sides, framing the face
						box(0.56, 0.76, -0.74, 0.52, -0.64, 0.50, green),
						-- a leaf ear, stepping out and up
						box(0.78, 1.06, 0.50, 0.92, -0.10, 0.26, light),
						box(1.00, 1.24, 0.84, 1.20, -0.04, 0.20, light),
					})
				),
			},
			{
				name = "Tunic",
				part = "UpperTorso",
				blocks = {
					box(-1.07, 1.07, -0.87, 0.91, -0.62, 0.62, green),
					-- the pale V at the neck
					box(-0.40, 0.40, 0.48, 0.74, -0.68, -0.62, light),
					box(-0.20, 0.20, 0.22, 0.48, -0.68, -0.62, light),
					-- the wooden guard on the right shoulder
					box(1.00, 2.14, 0.70, 1.16, -0.66, 0.66, leather),
					box(1.16, 1.94, 1.16, 1.34, -0.48, 0.48, wood),
					-- and a leaf pad on the left
					box(-2.14, -1.00, 0.70, 1.16, -0.66, 0.66, green),
					box(-1.94, -1.16, 1.16, 1.34, -0.48, 0.48, light),
				},
			},
			{
				name = "Cloak",
				part = "UpperTorso",
				blocks = {
					-- three leaves, each wider and further out than the last
					box(-1.00, 1.00, 0.00, 0.78, 0.60, 0.82, dark),
					box(-1.20, 1.20, -0.75, 0.00, 0.68, 0.90, dark),
					box(-1.40, 1.40, -1.50, -0.75, 0.76, 0.98, dark),
					box(-1.40, 1.40, -1.62, -1.50, 0.76, 0.98, hem),
				},
			},
			{
				name = "Belt",
				part = "LowerTorso",
				blocks = {
					box(-1.18, 1.18, -0.08, 0.20, -0.68, 0.68, leather),
					box(-0.20, 0.20, -0.14, 0.26, -0.76, -0.68, gold),
					-- the tunic's skirt under it
					box(-1.14, 1.14, -0.50, -0.08, -0.62, 0.62, dark),
				},
			},
			sleeveR,
			sleeveL,
			bracerR,
			bracerL,
			thighR,
			thighL,
			bootR,
			bootL,
			footR,
			footL,
		},
	}
end

--[[ Arcanist: a giant stepped star hat, crystal shoulders and a wide robe
     that steps out to its gold hem. ]]
local function arcanist(): Outfit
	local blue, deep, navy = rgb(63, 127, 234), rgb(37, 72, 166), rgb(26, 52, 120)
	local gold, gem = rgb(243, 200, 71), rgb(255, 230, 128)
	local crystal, glint = rgb(64, 200, 255), rgb(190, 240, 255)
	local sleeveR, sleeveL = pair("Sleeve", "UpperArm", {
		box(-0.52, 0.60, -0.36, 0.56, -0.58, 0.58, blue),
	})
	local cuffR, cuffL = pair("Cuff", "LowerArm", {
		-- a bell sleeve and its gold cuff
		box(-0.56, 0.68, -0.26, 0.26, -0.66, 0.66, blue),
		box(-0.60, 0.74, -0.48, -0.26, -0.75, 0.75, gold),
	})
	local skirtR, skirtL = pair("Skirt", "UpperLeg", {
		box(-0.50, 0.86, -0.38, 0.42, -0.78, 0.78, blue),
	})
	local hemR, hemL = pair("Hem", "LowerLeg", {
		box(-0.50, 1.00, -0.30, 0.40, -0.90, 0.90, blue),
		box(-0.50, 1.06, -0.45, -0.30, -0.96, 0.96, gold),
	})
	local shoeR, shoeL = pair("Shoe", "Foot", {
		box(-0.505, 0.62, -0.15, 0.20, -0.80, 0.60, navy),
	})
	return {
		pieces = {
			{
				name = "StarHat",
				part = "Head",
				blocks = join(
					{
						-- a cowl behind and beside the face
						box(-0.70, 0.70, -0.76, 0.50, 0.50, 0.70, deep),
						-- the wide brim
						box(-1.20, 1.20, 0.50, 0.68, -1.20, 1.20, deep),
						-- the gold band, and the cone stepping up and drooping back
						box(-0.80, 0.80, 0.68, 0.88, -0.80, 0.80, gold),
						box(-0.74, 0.74, 0.88, 1.20, -0.74, 0.74, blue),
						box(-0.56, 0.52, 1.20, 1.52, -0.48, 0.60, blue),
						box(-0.42, 0.26, 1.52, 1.82, -0.26, 0.48, blue),
						box(-0.38, 0.02, 1.82, 2.08, -0.02, 0.42, blue),
						-- the star on its front
						box(-0.18, 0.18, 0.74, 1.10, -0.86, -0.76, gem),
					},
					both({
						box(0.56, 0.74, -0.72, 0.50, -0.59, 0.50, deep),
					})
				),
			},
			{
				name = "Robe",
				part = "UpperTorso",
				blocks = join(
					{
						box(-1.07, 1.07, -0.87, 0.91, -0.62, 0.62, blue),
						-- the gold stripe down the front and the gem on it
						box(-0.24, 0.24, -0.87, 0.80, -0.68, -0.62, gold),
						box(-0.32, 0.32, 0.22, 0.66, -0.74, -0.66, gem),
					},
					both({
						-- a shoulder, and the crystal growing out of it
						box(1.00, 2.12, 0.70, 1.18, -0.64, 0.64, deep),
						box(1.28, 1.80, 1.18, 1.70, -0.26, 0.26, crystal, true),
						box(1.40, 1.68, 1.70, 1.90, -0.14, 0.14, glint),
					})
				),
			},
			{
				name = "Sash",
				part = "LowerTorso",
				blocks = {
					box(-1.16, 1.16, -0.26, 0.22, -0.65, 0.65, blue),
					box(-1.20, 1.20, -0.06, 0.12, -0.72, 0.72, gold),
				},
			},
			sleeveR,
			sleeveL,
			cuffR,
			cuffL,
			skirtR,
			skirtL,
			hemR,
			hemL,
			shoeR,
			shoeL,
		},
	}
end

--[[ Warden: a horned helm with a red plume, huge shoulder plates, a
     breastplate under a red tabard and a red cape. ]]
local function warden(): Outfit
	local steel, iron, shine = rgb(186, 194, 208), rgb(128, 138, 156), rgb(214, 220, 232)
	local red, wine = rgb(224, 69, 58), rgb(163, 42, 34)
	local gold, pale = rgb(232, 186, 63), rgb(255, 229, 150)
	local armR, armL = pair("Rerebrace", "UpperArm", {
		box(-0.52, 0.60, -0.36, 0.56, -0.58, 0.58, iron),
	})
	local vambraceR, vambraceL = pair("Vambrace", "LowerArm", {
		box(-0.56, 0.66, -0.48, 0.24, -0.61, 0.61, steel),
		-- the elbow guard
		box(-0.60, 0.72, 0.04, 0.30, -0.70, 0.70, shine),
	})
	local cuisseR, cuisseL = pair("Cuisse", "UpperLeg", {
		box(-0.50, 0.60, -0.38, 0.42, -0.58, 0.58, steel),
	})
	local greaveR, greaveL = pair("Greave", "LowerLeg", {
		box(-0.50, 0.66, -0.45, 0.40, -0.64, 0.64, iron),
		-- the knee plate
		box(-0.30, 0.50, 0.14, 0.56, -0.74, -0.60, steel),
	})
	local sabatonR, sabatonL = pair("Sabaton", "Foot", {
		box(-0.505, 0.64, -0.15, 0.20, -0.92, 0.62, iron),
		box(-0.36, 0.52, -0.15, 0.10, -1.02, -0.92, steel),
	})
	return {
		pieces = {
			{
				name = "Helm",
				part = "Head",
				blocks = join(
					{
						-- the dome and its top plate
						box(-0.77, 0.77, 0.52, 0.86, -0.78, 0.76, steel),
						box(-0.56, 0.56, 0.86, 1.00, -0.56, 0.56, shine),
						-- the back, down over the neck
						box(-0.72, 0.72, -0.78, 0.52, 0.50, 0.72, steel),
						-- the brow, above the eyes
						box(-0.56, 0.56, 0.36, 0.52, -0.74, -0.58, iron),
						-- the plume, a crest from front to back with a tail
						box(-0.17, 0.17, 1.00, 1.42, -0.36, 0.60, red),
						box(-0.17, 0.17, 0.86, 1.00, 0.56, 0.84, red),
					},
					both({
						-- a cheek guard
						box(0.56, 0.77, -0.70, 0.52, -0.62, 0.50, steel),
						-- a horn, stepping out and up
						box(0.77, 1.12, 0.46, 0.80, -0.18, 0.18, gold),
						box(1.00, 1.28, 0.80, 1.20, -0.13, 0.13, gold),
						box(1.14, 1.34, 1.20, 1.44, -0.09, 0.09, pale),
					})
				),
			},
			{
				name = "Breastplate",
				part = "UpperTorso",
				blocks = join(
					{
						box(-1.10, 1.10, -0.87, 0.93, -0.64, 0.64, steel),
						-- the red tabard and its gold crest
						box(-0.46, 0.46, -0.87, 0.60, -0.70, -0.64, red),
						box(-0.20, 0.20, 0.02, 0.42, -0.76, -0.68, gold),
					},
					both({
						-- a huge shoulder plate, its stepped top and its stud
						box(1.00, 2.30, 0.66, 1.28, -0.76, 0.76, steel),
						box(1.16, 2.10, 1.28, 1.50, -0.56, 0.56, shine),
						box(1.45, 1.85, 0.80, 1.14, -0.84, -0.76, gold),
					})
				),
			},
			{
				name = "Cape",
				part = "UpperTorso",
				blocks = {
					box(-1.00, 1.00, -0.10, 0.80, 0.62, 0.84, red),
					box(-1.30, 1.30, -1.55, -0.10, 0.72, 0.94, red),
					box(-1.30, 1.30, -1.68, -1.55, 0.72, 0.94, wine),
				},
			},
			{
				name = "Belt",
				part = "LowerTorso",
				blocks = {
					box(-1.20, 1.20, -0.06, 0.22, -0.73, 0.73, gold),
					-- the fauld, and the tabard's tail over it
					box(-1.14, 1.14, -0.52, -0.06, -0.63, 0.63, iron),
					box(-0.46, 0.46, -0.60, -0.06, -0.69, -0.63, red),
				},
			},
			armR,
			armL,
			vambraceR,
			vambraceL,
			cuisseR,
			cuisseL,
			greaveR,
			greaveL,
			sabatonR,
			sabatonL,
		},
	}
end

type Mesh = {
	id: string,
	size: Vector3,
	at: Vector3,
	glow: { { size: Vector3, at: Vector3, colour: Color3 } }?,
}

--[[ How far a glowing block stands proud of the mesh's own copy of it, a
     side: enough to cover it without the two flickering in one plane. ]]
local PROUD = 0.02

--[[ The Claude Design models (locked and imported by the owner on
     2026-11-12; docs/PIPELINES.md 12): each piece's mesh, its size on the
     standard body and its centre from its body part's centre. Written by
     `tools/class_armour/meshes_to_luau.py` from the Studio import's ids and
     `assets/models/armour/<class>_pieces.json`; change those, not this. ]]
local MESHES: { [string]: { [string]: Mesh } } = {
	-- <meshes>
	Ranger = {
		Hood = {
			id = "rbxassetid://74157358416773",
			size = Vector3.new(2.6077, 2.0193, 1.4595),
			at = Vector3.new(0, 0.1724, 0.1351),
		},
		Tunic = {
			id = "rbxassetid://133549744518395",
			size = Vector3.new(4.3213, 2.1736, 1.4525),
			at = Vector3.new(0.01, 0.1527, -0.0067),
		},
		Cloak = {
			id = "rbxassetid://133455827840652",
			size = Vector3.new(2.7874, 2.6951, 0.5813),
			at = Vector3.new(0, -0.4166, 0.874),
		},
		Belt = {
			id = "rbxassetid://136768914250201",
			size = Vector3.new(2.3494, 0.8616, 1.3654),
			at = Vector3.new(0, -0.2308, 0),
		},
		RightSleeve = {
			id = "rbxassetid://136247475588694",
			size = Vector3.new(1.1707, 0.928, 1.4392),
			at = Vector3.new(0.0853, 0.096, 0),
		},
		LeftSleeve = {
			id = "rbxassetid://109763299296358",
			size = Vector3.new(1.1507, 0.928, 1.3981),
			at = Vector3.new(-0.0753, 0.096, 0),
		},
		RightBracer = {
			id = "rbxassetid://96563350295950",
			size = Vector3.new(1.2012, 0.7792, 1.3981),
			at = Vector3.new(0.1001, -0.1746, 0),
		},
		LeftBracer = {
			id = "rbxassetid://77947960262650",
			size = Vector3.new(1.2012, 0.7792, 1.3981),
			at = Vector3.new(-0.1001, -0.1746, 0),
		},
		RightTrouser = {
			id = "rbxassetid://107042237521091",
			size = Vector3.new(1.1118, 0.7941, 1.2012),
			at = Vector3.new(0.0559, 0.0133, 0),
		},
		LeftTrouser = {
			id = "rbxassetid://131316447316162",
			size = Vector3.new(1.1118, 0.7941, 1.2012),
			at = Vector3.new(-0.0559, 0.0133, 0),
		},
		RightBoot = {
			id = "rbxassetid://81115978906707",
			size = Vector3.new(1.2192, 0.8551, 1.4014),
			at = Vector3.new(0.1096, -0.0415, -0.02),
		},
		LeftBoot = {
			id = "rbxassetid://131826107438460",
			size = Vector3.new(1.2192, 0.8551, 1.4014),
			at = Vector3.new(-0.1096, -0.0415, -0.02),
		},
		RightSole = {
			id = "rbxassetid://92091582812345",
			size = Vector3.new(1.1977, 0.3258, 1.6316),
			at = Vector3.new(0.0989, 0.0069, -0.1552),
		},
		LeftSole = {
			id = "rbxassetid://95412752377249",
			size = Vector3.new(1.1977, 0.3258, 1.6316),
			at = Vector3.new(-0.0989, 0.0069, -0.1552),
		},
	},
	Arcanist = {
		StarHat = {
			id = "rbxassetid://100321072961120",
			size = Vector3.new(2.5112, 2.9058, 2.3704),
			at = Vector3.new(0, 0.852, 0.0242),
		},
		Robe = {
			id = "rbxassetid://138872124137806",
			size = Vector3.new(4.2012, 2.6351, 1.31),
			at = Vector3.new(0, 0.5375, -0.0177),
			glow = {
				{
					size = Vector3.new(0.4605, 0.6106, 0.4112),
					at = Vector3.new(-1.53, 1.2595, 0),
					colour = Color3.fromRGB(64, 200, 255),
				},
				{
					size = Vector3.new(0.4605, 0.6106, 0.4112),
					at = Vector3.new(1.53, 1.2595, 0),
					colour = Color3.fromRGB(64, 200, 255),
				},
			},
		},
		Sash = {
			id = "rbxassetid://94452063432621",
			size = Vector3.new(2.1602, 0.4205, 1.2199),
			at = Vector3.new(0, 0.0098, -0.0075),
		},
		RightSleeve = {
			id = "rbxassetid://82281960210689",
			size = Vector3.new(1.1006, 0.938, 1.2747),
			at = Vector3.new(0.0503, 0.091, 0),
		},
		LeftSleeve = {
			id = "rbxassetid://133071294747612",
			size = Vector3.new(1.1006, 0.938, 1.2747),
			at = Vector3.new(-0.0503, 0.091, 0),
		},
		RightCuff = {
			id = "rbxassetid://73932206064191",
			size = Vector3.new(1.2212, 0.7347, 1.4803),
			at = Vector3.new(0.0701, -0.1564, 0),
		},
		LeftCuff = {
			id = "rbxassetid://81345525461225",
			size = Vector3.new(1.2212, 0.7347, 1.4803),
			at = Vector3.new(-0.0701, -0.1564, 0),
		},
		RightSkirt = {
			id = "rbxassetid://130854875718236",
			size = Vector3.new(1.488, 0.8246, 1.5415),
			at = Vector3.new(0.244, 0.0103, 0),
		},
		LeftSkirt = {
			id = "rbxassetid://81937878309114",
			size = Vector3.new(1.488, 0.8246, 1.5415),
			at = Vector3.new(-0.244, 0.0103, 0),
		},
		RightHem = {
			id = "rbxassetid://124789866180466",
			size = Vector3.new(1.7087, 0.8059, 1.8418),
			at = Vector3.new(0.3543, -0.0291, 0),
		},
		LeftHem = {
			id = "rbxassetid://103500491772423",
			size = Vector3.new(1.7087, 0.8059, 1.8418),
			at = Vector3.new(-0.3543, -0.0291, 0),
		},
		RightShoe = {
			id = "rbxassetid://130430741011118",
			size = Vector3.new(1.0213, 0.3543, 1.1812),
			at = Vector3.new(0.0107, 0.0211, -0.05),
		},
		LeftShoe = {
			id = "rbxassetid://103307754883606",
			size = Vector3.new(1.0213, 0.3543, 1.1812),
			at = Vector3.new(-0.0107, 0.0211, -0.05),
		},
	},
	Warden = {
		Helm = {
			id = "rbxassetid://105465383914819",
			size = Vector3.new(2.8329, 1.8409, 1.514),
			at = Vector3.new(0, 0.3245, 0.0245),
		},
		Breastplate = {
			id = "rbxassetid://77698836468022",
			size = Vector3.new(4.6215, 2.1917, 1.4223),
			at = Vector3.new(0, 0.3034, -0.102),
		},
		Cape = {
			id = "rbxassetid://78766958373005",
			size = Vector3.new(2.6032, 2.5763, 0.402),
			at = Vector3.new(0, -0.589, 0.8163),
		},
		Belt = {
			id = "rbxassetid://133299759249612",
			size = Vector3.new(2.2017, 0.8202, 1.5754),
			at = Vector3.new(0, -0.2088, -0.0765),
		},
		RightRerebrace = {
			id = "rbxassetid://79556042972133",
			size = Vector3.new(1.1589, 0.8343, 1.1432),
			at = Vector3.new(0.0794, 0.1429, -0.0001),
		},
		LeftRerebrace = {
			id = "rbxassetid://90716828952437",
			size = Vector3.new(1.1589, 0.8343, 1.1432),
			at = Vector3.new(-0.0794, 0.1429, -0.0001),
		},
		RightVambrace = {
			id = "rbxassetid://78873303959352",
			size = Vector3.new(1.1638, 0.6989, 1.3519),
			at = Vector3.new(0.0763, -0.0368, 0),
		},
		LeftVambrace = {
			id = "rbxassetid://119243469824166",
			size = Vector3.new(1.1638, 0.6989, 1.3519),
			at = Vector3.new(-0.0763, -0.0368, 0),
		},
		RightCuisse = {
			id = "rbxassetid://112282686321918",
			size = Vector3.new(1.0193, 0.5023, 1.2655),
			at = Vector3.new(0.0513, -0.1288, -0.0254),
		},
		LeftCuisse = {
			id = "rbxassetid://100742796733641",
			size = Vector3.new(1.0193, 0.5023, 1.2655),
			at = Vector3.new(-0.0513, -0.1288, -0.0254),
		},
		RightGreave = {
			id = "rbxassetid://122801147018587",
			size = Vector3.new(1.0705, 0.9657, 1.4181),
			at = Vector3.new(0.0769, 0.0771, -0.0509),
		},
		LeftGreave = {
			id = "rbxassetid://90796227412920",
			size = Vector3.new(1.0705, 0.9657, 1.4181),
			at = Vector3.new(-0.0769, 0.0771, -0.0509),
		},
		RightSabaton = {
			id = "rbxassetid://128784565642756",
			size = Vector3.new(1.0193, 0.3932, 1.4181),
			at = Vector3.new(0.0513, 0.0406, -0.1017),
		},
		LeftSabaton = {
			id = "rbxassetid://87737533770634",
			size = Vector3.new(1.0193, 0.3932, 1.4181),
			at = Vector3.new(-0.0513, 0.0406, -0.1017),
		},
	},
	-- </meshes>
}

--[[ A set with its imported models on. The importer turns a model half
     round, so every mesh is worn turned back. A mesh is one material, so a
     piece's crystals are also worn over it as Neon blocks (`glows`), the
     model's own, a hair larger (owner, 2026-11-12: "Make them glow"). ]]
local function meshed(class: string, outfit: Outfit): Outfit
	local meshes = MESHES[class]
	for _, piece in outfit.pieces do
		local mesh = meshes and meshes[piece.name]
		if mesh then
			piece.meshId = mesh.id
			piece.size = mesh.size
			piece.at = mesh.at
			piece.turned = true
			if mesh.glow then
				local glows: { Block } = {}
				for _, lit in mesh.glow do
					table.insert(glows, {
						size = lit.size + Vector3.one * PROUD * 2,
						at = lit.at,
						colour = lit.colour,
						glow = true,
					})
				end
				piece.glows = glows
			end
		end
	end
	return outfit
end

local ClassOutfits = {
	--[[ The standard blocky R15 body the sets are sized for: each part's
	     size and its centre from the HumanoidRootPart, read off
	     `Players:CreateHumanoidModelFromDescription` with an empty
	     description (2026-11-12). ]]
	standard = {
		Head = { size = Vector3.new(1.159, 1.182, 1.161), at = Vector3.new(0, 1.586, 0) },
		UpperTorso = { size = Vector3.new(1.943, 1.698, 1.004), at = Vector3.new(0, 0.2, 0) },
		LowerTorso = { size = Vector3.new(1.991, 0.401, 1.004), at = Vector3.new(0, -0.8, 0) },
		RightUpperArm = {
			size = Vector3.new(1.001, 1.242, 1.002),
			at = Vector3.new(1.5, 0.369, 0),
		},
		LeftUpperArm = {
			size = Vector3.new(1.001, 1.242, 1.002),
			at = Vector3.new(-1.5, 0.369, 0),
		},
		RightLowerArm = {
			size = Vector3.new(1.001, 1.118, 1.002),
			at = Vector3.new(1.5, -0.224, 0),
		},
		LeftLowerArm = {
			size = Vector3.new(1.001, 1.118, 1.002),
			at = Vector3.new(-1.5, -0.224, 0),
		},
		RightHand = { size = Vector3.new(0.984, 0.316, 1.028), at = Vector3.new(1.5, -0.85, 0) },
		LeftHand = { size = Vector3.new(0.984, 0.316, 1.028), at = Vector3.new(-1.5, -0.85, 0) },
		RightUpperLeg = {
			size = Vector3.new(0.993, 1.363, 0.973),
			at = Vector3.new(0.5, -1.421, 0),
		},
		LeftUpperLeg = {
			size = Vector3.new(0.993, 1.363, 0.973),
			at = Vector3.new(-0.5, -1.421, 0),
		},
		RightLowerLeg = {
			size = Vector3.new(0.993, 1.301, 0.973),
			at = Vector3.new(0.5, -2.201, 0),
		},
		LeftLowerLeg = {
			size = Vector3.new(0.993, 1.301, 0.973),
			at = Vector3.new(-0.5, -2.201, 0),
		},
		RightFoot = { size = Vector3.new(1.009, 0.312, 1.001), at = Vector3.new(0.5, -2.85, 0) },
		LeftFoot = { size = Vector3.new(1.009, 0.312, 1.001), at = Vector3.new(-0.5, -2.85, 0) },
	} :: { [string]: Body },
	--[[ The floor under the standard body, from the HumanoidRootPart. ]]
	floor = -3.006,
	--[[ The body parts a set has to cover. Hands stay bare. ]]
	covered = {
		"Head",
		"UpperTorso",
		"LowerTorso",
		"RightUpperArm",
		"LeftUpperArm",
		"RightLowerArm",
		"LeftLowerArm",
		"RightUpperLeg",
		"LeftUpperLeg",
		"RightLowerLeg",
		"LeftLowerLeg",
		"RightFoot",
		"LeftFoot",
	},
	--[[ The window the face shows through, in the Head's space: nothing may
	     stand in front of it. ]]
	face = { halfWidth = 0.45, bottom = -0.45, top = 0.3 },
	--[[ The avatar's own scale values while a set is worn in a run (the
	     Humanoid's NumberValues of these names): the standard proportions,
	     so a tall, wide or slender avatar fits the set. Put back when the
	     set comes off. ]]
	scales = {
		BodyHeightScale = 1,
		BodyWidthScale = 1,
		BodyDepthScale = 1,
		HeadScale = 1,
		BodyTypeScale = 0,
		BodyProportionScale = 0,
	} :: { [string]: number },
	--[[ How far a piece is stretched to a body part that is still not the
	     standard size. Never smaller than it was made: a slim avatar's arm
	     sits inside a sleeve of the full size, so the set stays as chunky
	     as its sheet. Up to three times larger, which a tall shoe-shaped
	     foot needs for its sole to reach the floor. ]]
	stretch = { min = 1, max = 3 },
	sets = {
		Ranger = meshed("Ranger", ranger()),
		Arcanist = meshed("Arcanist", arcanist()),
		Warden = meshed("Warden", warden()),
	} :: { [string]: Outfit },
}

return table.freeze(ClassOutfits)
