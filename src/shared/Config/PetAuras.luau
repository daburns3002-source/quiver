--!strict
--[[
	What a rare pet wears around it (owner, 2026-10-24: "I NEED THE
	GLIMMERHORN TO GLOW AND HAVE RAINBOW COLORED EFFECTS AROUND IT AND A
	TRAIL, IT NEEDS TO LOOK MYTHIC. SAME THING WITH SLIME PRINCE BUT GOLDEN
	CAUSE ITS LEGENDARY"), drawn by `Fx/PetAura`: a glow over its body,
	square sparkles rising around it, and a trail behind it as it walks.

	`pets` gives each pet its rarity (docs/PETS-FOREST.md); a pet not listed
	wears nothing. `looks` is each rarity's aura. A `rainbow` look cycles
	through the hues; any other is the `colours` it gives.
]]

export type Look = {
	--[[ Cycles the glow, sparkles and trail through the rainbow, this many
	     times a second; nil for a fixed look. ]]
	rainbow: number?,
	--[[ The colours of a fixed look: the glow, and the sparkles and trail
	     from first to last. ]]
	glow: Color3,
	colours: { Color3 },
	--[[ How see-through the glow over the body is (0 solid, 1 none), and
	     its outline. ]]
	fill: number,
	outline: number,
	--[[ The light it casts on the floor around it. ]]
	lightRange: number,
	lightBrightness: number,
	--[[ Sparkles a second, how long each lives, and how large it starts. ]]
	sparkleRate: number,
	sparkleLife: number,
	sparkleSize: number,
	--[[ Seconds the trail lingers behind it. ]]
	trail: number,
}

local PetAuras = {
	--[[ The square every sparkle is (a white 64 x 64, tinted). ]]
	square = "rbxassetid://96921977657831",
	pets = {
		Glimmerhorn = "Mythic",
		SlimePrince = "Legendary",
		EmberWilfPet = "Legendary",
		-- Thornwood (docs/PETS-THORNWOOD.md)
		Thornwake = "Mythic",
		ThornPrincess = "Legendary",
		-- owner, 2026-10-26: "Keep the Bramble Wilf's aura purple."
		BrambleWilf = "LegendaryPurple",
		-- Drowned Village (docs/PETS-DROWNED.md): the Tide Wilf carries the
		-- family's gold aura and sparkles, the Abyss Jelly the Mythic rainbow
		TideWilf = "Legendary",
		AbyssJelly = "Mythic",
	} :: { [string]: string },
	looks = {
		Mythic = {
			rainbow = 0.35,
			glow = Color3.fromRGB(255, 255, 255),
			colours = {
				Color3.fromRGB(255, 80, 80),
				Color3.fromRGB(255, 200, 60),
				Color3.fromRGB(90, 255, 120),
				Color3.fromRGB(70, 200, 255),
				Color3.fromRGB(200, 110, 255),
			},
			fill = 0.72,
			outline = 0.1,
			lightRange = 10,
			lightBrightness = 2.5,
			sparkleRate = 18,
			sparkleLife = 1.1,
			sparkleSize = 0.32,
			trail = 0.6,
		},
		Legendary = {
			rainbow = nil,
			glow = Color3.fromRGB(255, 205, 60),
			colours = {
				Color3.fromRGB(255, 245, 170),
				Color3.fromRGB(255, 205, 60),
				Color3.fromRGB(230, 150, 20),
			},
			fill = 0.75,
			outline = 0.15,
			lightRange = 9,
			lightBrightness = 2,
			sparkleRate = 12,
			sparkleLife = 1,
			sparkleSize = 0.3,
			trail = 0.5,
		},
		--[[ The Legendary aura in the Bramble Wilf's purple. ]]
		LegendaryPurple = {
			rainbow = nil,
			glow = Color3.fromRGB(190, 110, 255),
			colours = {
				Color3.fromRGB(235, 200, 255),
				Color3.fromRGB(190, 110, 255),
				Color3.fromRGB(120, 50, 200),
			},
			fill = 0.75,
			outline = 0.15,
			lightRange = 9,
			lightBrightness = 2,
			sparkleRate = 12,
			sparkleLife = 1,
			sparkleSize = 0.3,
			trail = 0.5,
		},
	} :: { [string]: Look },
}

return table.freeze(PetAuras)
