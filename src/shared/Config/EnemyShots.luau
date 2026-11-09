--!strict
--[[
	Each enemy's shot, as it is drawn (owner, 2026-11-08: "i want each enemy
	projectile to have its own unique animation"): keyed by the `look` its
	`Balance.EnemyShot` names, read by `Fx/ProjectileRenderer`.

	Presentation only. What a shot hits is `Combat/ProjectileFlight`'s box,
	so `scale` changes the picture and never the danger, and `wobble`, `bob`
	and `helix` stay small enough that the drawn shot is still on its line.

	`scale` is against `Balance.Projectile.enemyOrbDiameter`. `spin` is
	radians a second about the shot's own axes, Z along its flight.
]]

export type Arm = { scale: Vector3, angles: Vector3 }
export type Sway = { amount: number, rate: number }
export type Sparkle = {
	colour: Color3,
	size: number,
	speed: number,
	lifetime: number,
	--[[ Multiplies the device tier's rate. ]]
	rate: number,
	--[[ Studs a second squared, up; below 0 it falls. ]]
	rise: number,
}
export type Impact = {
	colour: Color3,
	--[[ Studs across the ring grows to, 0 for none, and how many follow. ]]
	ring: number,
	rings: number,
	chips: number,
	chip: Vector3,
	neon: boolean,
	--[[ Studs the chips drift up by as they fly; below 0 they drop. ]]
	rise: number,
}
export type Look = {
	shape: "Block" | "Ball" | "Wedge",
	scale: Vector3,
	colour: Color3,
	material: string,
	spin: Vector3,
	outline: Color3?,
	--[[ Thin parts carried with it, turned about its middle. ]]
	arms: { Arm }?,
	armColour: Color3?,
	wobble: Sway?,
	bob: Sway?,
	helix: Sway?,
	sparkle: Sparkle?,
	--[[ Seconds of tail and how wide, in studs. Nil has no tail. ]]
	trail: number?,
	trailWidth: number?,
	trailColour: Color3?,
	impact: Impact,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local looks: { [string]: Look } = {
	--[[ The Spitter's seed: a leaf-green cube, outlined, tumbling end over
	     end, which is how every enemy shot looked before this. ]]
	Seed = {
		shape = "Block",
		scale = Vector3.one,
		colour = rgb(150, 255, 70),
		material = "Neon",
		spin = Vector3.new(1.6, 1.1, 0),
		outline = rgb(20, 52, 16),
		sparkle = {
			colour = rgb(215, 255, 170),
			size = 0.28,
			speed = 1,
			lifetime = 0.35,
			rate = 1,
			rise = 0,
		},
		trail = 0.6,
		impact = {
			colour = rgb(150, 255, 70),
			ring = 2.4,
			rings = 1,
			chips = 4,
			chip = Vector3.one * 0.22,
			neon = true,
			rise = 0,
		},
	},
	--[[ The Lancer's lance: a long red needle, dead straight, drilling. ]]
	Needle = {
		shape = "Block",
		scale = Vector3.new(0.22, 0.22, 2.4),
		colour = rgb(255, 58, 48),
		material = "Neon",
		spin = Vector3.new(0, 0, 9),
		trail = 0.3,
		trailWidth = 0.5,
		impact = {
			colour = rgb(255, 58, 48),
			ring = 1.6,
			rings = 1,
			chips = 6,
			chip = Vector3.new(0.08, 0.08, 0.7),
			neon = true,
			rise = 0,
		},
	},
	--[[ The Lurker's clod: a lump of earth, not lit at all, turning over
	     fast and shedding dirt as it goes. ]]
	Clod = {
		shape = "Block",
		scale = Vector3.new(1.05, 0.85, 1),
		colour = rgb(118, 84, 54),
		material = "Slate",
		spin = Vector3.new(7, 5, 2),
		outline = rgb(40, 26, 16),
		sparkle = {
			colour = rgb(150, 112, 74),
			size = 0.3,
			speed = 0.6,
			lifetime = 0.45,
			rate = 1.4,
			rise = -30,
		},
		impact = {
			colour = rgb(118, 84, 54),
			ring = 0,
			rings = 1,
			chips = 7,
			chip = Vector3.one * 0.32,
			neon = false,
			rise = -0.8,
		},
	},
	--[[ The Burr Thistle's burr: a pink ball stuck through with three
	     spines, a spinning jack. ]]
	Burr = {
		shape = "Ball",
		scale = Vector3.one * 0.7,
		colour = rgb(240, 70, 150),
		material = "Neon",
		spin = Vector3.new(4, 6, 8),
		arms = {
			{ scale = Vector3.new(0.16, 0.16, 1.7), angles = Vector3.zero },
			{ scale = Vector3.new(0.16, 0.16, 1.7), angles = Vector3.new(90, 0, 0) },
			{ scale = Vector3.new(0.16, 0.16, 1.7), angles = Vector3.new(0, 90, 0) },
		},
		armColour = rgb(120, 22, 76),
		sparkle = {
			colour = rgb(255, 170, 215),
			size = 0.18,
			speed = 1.2,
			lifetime = 0.2,
			rate = 0.7,
			rise = 0,
		},
		trail = 0.25,
		impact = {
			colour = rgb(240, 70, 150),
			ring = 1.8,
			rings = 1,
			chips = 8,
			chip = Vector3.new(0.08, 0.08, 0.6),
			neon = true,
			rise = 0,
		},
	},
	--[[ The Bramble Lurker's thorn: a flat violet dart, weaving, twirling
	     about its own length and dropping petals. ]]
	Thorn = {
		shape = "Wedge",
		scale = Vector3.new(0.7, 0.35, 1.9),
		colour = rgb(150, 50, 180),
		material = "Neon",
		spin = Vector3.new(0, 0, 3),
		wobble = { amount = 0.25, rate = 9 },
		sparkle = {
			colour = rgb(214, 150, 240),
			size = 0.24,
			speed = 0.5,
			lifetime = 0.5,
			rate = 0.8,
			rise = -10,
		},
		trail = 0.45,
		impact = {
			colour = rgb(150, 50, 180),
			ring = 0,
			rings = 1,
			chips = 5,
			chip = Vector3.new(0.3, 0.06, 0.18),
			neon = true,
			rise = 0.3,
		},
	},
	--[[ The Hollow Fisherman's float: a red bobber with a white band,
	     bobbing, paying out a thin line behind it, and landing in ripples. ]]
	Bobber = {
		shape = "Ball",
		scale = Vector3.one * 0.75,
		colour = rgb(226, 54, 48),
		material = "SmoothPlastic",
		spin = Vector3.zero,
		arms = {
			{ scale = Vector3.new(0.8, 0.14, 0.8), angles = Vector3.zero },
		},
		armColour = rgb(245, 245, 240),
		bob = { amount = 0.15, rate = 14 },
		trail = 1.3,
		trailWidth = 0.08,
		trailColour = rgb(235, 240, 250),
		impact = {
			colour = rgb(170, 225, 245),
			ring = 2.6,
			rings = 2,
			chips = 2,
			chip = Vector3.one * 0.14,
			neon = true,
			rise = 0.6,
		},
	},
	--[[ The Glowcap's spore: a soft teal ball corkscrewing on the air,
	     with motes rising off it. ]]
	Spore = {
		shape = "Ball",
		scale = Vector3.one * 1.05,
		colour = rgb(90, 240, 210),
		material = "Neon",
		spin = Vector3.zero,
		helix = { amount = 0.22, rate = 5 },
		sparkle = {
			colour = rgb(190, 255, 240),
			size = 0.22,
			speed = 0.4,
			lifetime = 0.6,
			rate = 1.1,
			rise = 8,
		},
		trail = 0.5,
		impact = {
			colour = rgb(90, 240, 210),
			ring = 3.2,
			rings = 1,
			chips = 6,
			chip = Vector3.one * 0.18,
			neon = true,
			rise = 1.2,
		},
	},
}

local EnemyShots = {
	default = "Seed",
	looks = looks,
}

return table.freeze(EnemyShots)
