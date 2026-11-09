--!strict
--[[
	How each weapon's attack looks (owner, 2026-11-08: "make sure the
	projectiles for the bow and wands are all unique and make sure the
	legendary and mythic projectiles glow respectively. also make sure the
	swords have distinct cleaves from one another").

	Presentation only. What a shot or a swing hits is the combat code's box,
	so nothing here changes the fight: a cleave is still drawn over exactly
	the ground it hits (`Fx/SwingTrail`).

	`shots`, one per bow and staff, played by `Fx/ProjectileRenderer`, are the
	enemy shots' `Look` (`Config/EnemyShots`). `shape` "Bolt" keeps the
	weapon's own mesh (or the plain arrow); the others replace it. `scale` is
	against the plain shot; `trail` multiplies the length of its tail. A
	Legendary or Mythic also has its `Config/Weapons.shotGlow`: drawn in this
	`colour`, it carries a light and sparkles.

	`cleaves`, one per blade, played by `Fx/SwingTrail`: the streak's two
	colours, its `tail` in seconds, `taper` (how wide its end stays, 0 to 1)
	and the `motes` it throws off as it sweeps. A mote's `form` is a `Star`
	of two crossed bars, a long `Shard`, a square `Chip`, a round `Ball` or a
	flat `Leaf`; `rise` is the studs it climbs (below 0 it falls). A
	Legendary's or Mythic's cleave glows (`Config/Weapons.trailGlow`).

	`tests/WeaponFx.spec` asks that no two share a look.
]]

local EnemyShots = require(script.Parent.EnemyShots)

export type Look = EnemyShots.Look
export type Motes = {
	form: "Star" | "Shard" | "Chip" | "Ball" | "Leaf",
	colour: Color3,
	--[[ Motes a second while the swing sweeps. ]]
	rate: number,
	size: number,
	rise: number,
	life: number,
}
export type Cleave = {
	colour: { Color3 },
	tail: number,
	taper: number,
	motes: Motes?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function sparkle(colour: Color3, size: number, rise: number): EnemyShots.Sparkle
	return { colour = colour, size = size, speed = 1, lifetime = 0.45, rate = 1.5, rise = rise }
end

type Spec = {
	colour: Color3,
	shape: ("Bolt" | "Block" | "Ball" | "Wedge")?,
	scale: Vector3?,
	spin: Vector3?,
	arms: { EnemyShots.Arm }?,
	armColour: Color3?,
	wobble: EnemyShots.Sway?,
	bob: EnemyShots.Sway?,
	helix: EnemyShots.Sway?,
	sparkle: EnemyShots.Sparkle?,
	trail: number?,
	trailColour: Color3?,
}

local function shot(spec: Spec): Look
	return {
		shape = spec.shape or "Bolt",
		scale = spec.scale or Vector3.one,
		colour = spec.colour,
		material = "Neon",
		spin = spec.spin or Vector3.zero,
		arms = spec.arms,
		armColour = spec.armColour,
		wobble = spec.wobble,
		bob = spec.bob,
		helix = spec.helix,
		sparkle = spec.sparkle,
		trail = spec.trail or 1,
		trailColour = spec.trailColour,
		impact = {
			colour = spec.colour,
			ring = 2.4,
			rings = 1,
			chips = 5,
			chip = Vector3.one * 0.18,
			neon = true,
			rise = 0.5,
		},
	}
end

--[[ Two thin fins crossed along a shot, or one flat ring of three. ]]
local FINS = {
	{ scale = Vector3.new(0.06, 0.55, 0.4), angles = Vector3.zero },
	{ scale = Vector3.new(0.55, 0.06, 0.4), angles = Vector3.zero },
}
local BLADES = {
	{ scale = Vector3.new(0.08, 1.1, 0.08), angles = Vector3.new(0, 0, 0) },
	{ scale = Vector3.new(0.08, 1.1, 0.08), angles = Vector3.new(0, 0, 60) },
	{ scale = Vector3.new(0.08, 1.1, 0.08), angles = Vector3.new(0, 0, 120) },
}

local shots: { [string]: Look } = {
	-- Bows
	TwigBow = shot({ colour = rgb(255, 244, 196) }),
	AcornBow = shot({ colour = rgb(226, 170, 96), spin = Vector3.new(0, 0, 9) }),
	PeatwoodBow = shot({
		colour = rgb(196, 136, 78),
		shape = "Wedge",
		scale = Vector3.new(1.8, 0.8, 1),
	}),
	FireflyBow = shot({
		colour = rgb(250, 238, 120),
		bob = { amount = 0.35, rate = 16 },
		sparkle = sparkle(rgb(255, 240, 130), 0.2, 0),
	}),
	SlatefinBow = shot({
		colour = rgb(146, 196, 222),
		shape = "Block",
		scale = Vector3.new(1.2, 1.2, 0.8),
		arms = FINS,
		spin = Vector3.new(0, 0, 5),
	}),
	SporestringBow = shot({
		colour = rgb(238, 156, 196),
		wobble = { amount = 0.25, rate = 9 },
		sparkle = sparkle(rgb(245, 190, 215), 0.3, 3),
	}),
	MossSlimeBow = shot({
		colour = rgb(150, 236, 92),
		wobble = { amount = 0.4, rate = 22 },
		sparkle = sparkle(rgb(120, 220, 80), 0.25, -8),
	}),
	EelcrestBow = shot({
		colour = rgb(64, 224, 186),
		shape = "Wedge",
		wobble = { amount = 0.7, rate = 26 },
		trail = 1.6,
	}),
	GlowcapLongbow = shot({
		colour = rgb(176, 255, 214),
		shape = "Block",
		scale = Vector3.new(0.8, 0.8, 1.8),
		trail = 2.2,
	}),
	EmberFangBow = shot({
		colour = rgb(255, 146, 44),
		spin = Vector3.new(0, 0, 14),
		sparkle = sparkle(rgb(255, 120, 30), 0.3, 9),
		trail = 1.6,
	}),
	GulpstringBow = shot({
		colour = rgb(233, 190, 50),
		shape = "Block",
		helix = { amount = 0.4, rate = 18 },
		sparkle = sparkle(rgb(200, 220, 70), 0.3, -4),
	}),
	TollstringBow = shot({
		colour = rgb(255, 214, 128),
		shape = "Block",
		scale = Vector3.new(4, 4, 0.5),
		spin = Vector3.new(0, 16, 0),
		trail = 0.6,
	}),
	GladeSpiritBow = shot({
		colour = rgb(216, 255, 226),
		helix = { amount = 0.5, rate = 14 },
		sparkle = sparkle(rgb(255, 255, 255), 0.35, 1),
		trail = 1.8,
	}),
	EventideBow = shot({
		colour = rgb(255, 136, 196),
		arms = FINS,
		wobble = { amount = 0.3, rate = 12 },
		sparkle = sparkle(rgb(255, 180, 220), 0.3, 1),
		trail = 2,
	}),
	LumenveilBow = shot({
		colour = rgb(63, 230, 242),
		scale = Vector3.new(1.3, 1.3, 1.5),
		bob = { amount = 0.3, rate = 7 },
		sparkle = sparkle(rgb(150, 245, 255), 0.35, 2),
		trail = 2.6,
	}),
	-- Staves
	BranchStaff = shot({ colour = rgb(90, 200, 255) }),
	ToadstoolStaff = shot({
		colour = rgb(236, 92, 84),
		sparkle = sparkle(rgb(250, 210, 200), 0.3, 3),
	}),
	ReedStaff = shot({
		colour = rgb(156, 214, 132),
		shape = "Ball",
		scale = Vector3.one * 0.7,
		trail = 1.8,
	}),
	LichenStaff = shot({
		colour = rgb(198, 224, 120),
		shape = "Block",
		scale = Vector3.one * 0.7,
		spin = Vector3.new(7, 5, 9),
	}),
	LanternStaff = shot({ colour = rgb(255, 192, 84), bob = { amount = 0.25, rate = 20 } }),
	BuoyStaff = shot({
		colour = rgb(255, 142, 96),
		shape = "Ball",
		bob = { amount = 0.6, rate = 8 },
	}),
	PuffballStaff = shot({
		colour = rgb(214, 186, 240),
		shape = "Ball",
		scale = Vector3.one * 1.45,
		sparkle = sparkle(rgb(225, 205, 245), 0.45, 4),
		trail = 0.6,
	}),
	HootmossStaff = shot({
		colour = rgb(174, 204, 112),
		arms = FINS,
		spin = Vector3.new(0, 0, 6),
	}),
	VentstoneStaff = shot({
		colour = rgb(226, 230, 240),
		shape = "Wedge",
		sparkle = sparkle(rgb(190, 195, 205), 0.4, 6),
		trail = 2.2,
	}),
	WellpearlStaff = shot({
		colour = rgb(244, 240, 255),
		shape = "Ball",
		helix = { amount = 0.35, rate = 12 },
		sparkle = sparkle(rgb(255, 255, 255), 0.18, 0),
	}),
	SlimeCrownStaff = shot({
		colour = rgb(230, 254, 205),
		wobble = { amount = 0.45, rate = 18 },
		sparkle = sparkle(rgb(190, 250, 150), 0.3, -6),
	}),
	TollkeeperStaff = shot({
		colour = rgb(255, 218, 112),
		shape = "Block",
		arms = BLADES,
		spin = Vector3.new(0, 0, 12),
		sparkle = sparkle(rgb(255, 230, 150), 0.3, 1),
	}),
	GrandmothersStaff = shot({
		colour = rgb(77, 232, 200),
		shape = "Ball",
		arms = BLADES,
		spin = Vector3.new(4, 0, 8),
		bob = { amount = 0.3, rate = 10 },
		sparkle = sparkle(rgb(150, 245, 220), 0.3, -2),
	}),
	WorldrootStaff = shot({
		colour = rgb(33, 244, 254),
		helix = { amount = 0.55, rate = 15 },
		sparkle = sparkle(rgb(180, 255, 255), 0.35, 2),
		trail = 2,
	}),
	MaelstromStaff = shot({
		colour = rgb(120, 150, 255),
		shape = "Ball",
		scale = Vector3.one * 1.25,
		arms = FINS,
		spin = Vector3.new(0, 0, 18),
		helix = { amount = 0.8, rate = 24 },
		sparkle = sparkle(rgb(190, 205, 255), 0.35, 0),
	}),
	MyceliadStaff = shot({
		colour = rgb(212, 202, 255),
		shape = "Wedge",
		scale = Vector3.one * 1.3,
		arms = BLADES,
		wobble = { amount = 0.35, rate = 14 },
		sparkle = sparkle(rgb(120, 235, 245), 0.35, 3),
		trail = 2,
	}),
}

local cleaves: { [string]: Cleave } = {
	TimberBlade = { colour = { rgb(255, 80, 60), rgb(150, 25, 20) }, tail = 0.16, taper = 0.25 },
	MossstoneBlade = {
		colour = { rgb(124, 186, 92), rgb(58, 104, 48) },
		tail = 0.2,
		taper = 0.4,
		motes = {
			form = "Chip",
			colour = rgb(116, 150, 92),
			rate = 22,
			size = 0.45,
			rise = -0.7,
			life = 0.4,
		},
	},
	TidewoodBlade = {
		colour = { rgb(92, 190, 190), rgb(40, 96, 110) },
		tail = 0.24,
		taper = 0.15,
		motes = {
			form = "Ball",
			colour = rgb(150, 225, 235),
			rate = 26,
			size = 0.35,
			rise = -1.1,
			life = 0.4,
		},
	},
	BogironBlade = {
		colour = { rgb(146, 148, 132), rgb(66, 70, 62) },
		tail = 0.1,
		taper = 0.85,
		motes = {
			form = "Shard",
			colour = rgb(255, 170, 70),
			rate = 30,
			size = 0.7,
			rise = 0.3,
			life = 0.22,
		},
	},
	ThornBlade = {
		colour = { rgb(70, 150, 62), rgb(28, 70, 34) },
		tail = 0.2,
		taper = 0.05,
		motes = {
			form = "Shard",
			colour = rgb(160, 210, 90),
			rate = 28,
			size = 0.95,
			rise = 0,
			life = 0.4,
		},
	},
	TidehookBlade = {
		colour = { rgb(60, 130, 230), rgb(24, 56, 130) },
		tail = 0.28,
		taper = 0.5,
		motes = {
			form = "Leaf",
			colour = rgb(200, 235, 255),
			rate = 24,
			size = 0.7,
			rise = 0.8,
			life = 0.35,
		},
	},
	ShellbackCleaver = {
		colour = { rgb(120, 170, 160), rgb(54, 84, 88) },
		tail = 0.18,
		taper = 0.7,
		motes = {
			form = "Leaf",
			colour = rgb(170, 186, 170),
			rate = 18,
			size = 1,
			rise = -0.9,
			life = 0.5,
		},
	},
	BroodsplitBlade = {
		colour = { rgb(132, 92, 170), rgb(46, 28, 66) },
		tail = 0.26,
		taper = 0.1,
		motes = {
			form = "Shard",
			colour = rgb(235, 230, 245),
			rate = 34,
			size = 1.3,
			rise = 0.2,
			life = 0.3,
		},
	},
	CaplightBlade = {
		colour = { rgb(226, 236, 110), rgb(120, 140, 40) },
		tail = 0.22,
		taper = 0.3,
		motes = {
			form = "Ball",
			colour = rgb(240, 250, 160),
			rate = 28,
			size = 0.32,
			rise = 1.4,
			life = 0.55,
		},
	},
	CausewayBlade = {
		colour = { rgb(214, 194, 150), rgb(120, 100, 70) },
		tail = 0.3,
		taper = 0.6,
		motes = {
			form = "Chip",
			colour = rgb(196, 180, 150),
			rate = 20,
			size = 0.65,
			rise = -1.2,
			life = 0.45,
		},
	},
	EmberfangBlade = {
		colour = { rgb(255, 130, 50), rgb(255, 214, 90) },
		tail = 0.24,
		taper = 0.2,
		motes = {
			form = "Ball",
			colour = rgb(255, 150, 40),
			rate = 40,
			size = 0.28,
			rise = 2.4,
			life = 0.5,
		},
	},
	GulpfangBlade = {
		colour = { rgb(154, 214, 60), rgb(220, 240, 110) },
		tail = 0.3,
		taper = 0.45,
		motes = {
			form = "Ball",
			colour = rgb(170, 230, 70),
			rate = 30,
			size = 0.5,
			rise = -1.6,
			life = 0.5,
		},
	},
	TollguardBlade = {
		colour = { rgb(255, 208, 92), rgb(255, 240, 180) },
		tail = 0.2,
		taper = 0.9,
		motes = {
			form = "Leaf",
			colour = rgb(255, 214, 96),
			rate = 30,
			size = 0.6,
			rise = 1.6,
			life = 0.5,
		},
	},
	GladeheartBlade = {
		colour = { rgb(222, 190, 243), rgb(255, 255, 255) },
		tail = 0.26,
		taper = 0.3,
		motes = {
			form = "Star",
			colour = rgb(255, 255, 255),
			rate = 45,
			size = 0.75,
			rise = 0.6,
			life = 0.45,
		},
	},
	StormglassBlade = {
		colour = { rgb(200, 225, 255), rgb(255, 255, 255) },
		tail = 0.13,
		taper = 0.95,
		motes = {
			form = "Shard",
			colour = rgb(235, 245, 255),
			rate = 45,
			size = 1.5,
			rise = 1,
			life = 0.2,
		},
	},
	DeepglowBlade = {
		colour = { rgb(63, 230, 242), rgb(190, 250, 255) },
		tail = 0.34,
		taper = 0.35,
		motes = {
			form = "Ball",
			colour = rgb(150, 245, 255),
			rate = 36,
			size = 0.42,
			rise = 1.9,
			life = 0.7,
		},
	},
}

return table.freeze({
	shots = table.freeze(shots),
	cleaves = table.freeze(cleaves),
})
