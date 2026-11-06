--!strict
--[[
	The beats of the shops' reveals and the gear screen's equip (owner,
	2026-10-26: "a crate opening, egg hatching, and gear equipping animation
	... these are the big selling point so these should be heavy on
	dopamine"), in seconds. `Util/RevealTimeline` turns them into one
	reveal's clock and `UI/Reveal` draws it.

	Redone 2026-11-06 (owner: "i need new animations for the egg hatch and
	chest opening ... right now they look terrible"), in the style of the big
	Roblox pet games: the egg drops in and bounces, wobbles harder and harder
	as cracks spread and light leaks out, bursts into shell pieces with a
	flash and confetti, and the pet pops out with a bounce; then its colour
	bursts and its rarity banner slams down. A chest shakes, its padlocks
	pop, the lid bursts open with light beams and coins, and the weapon rises
	out and lands with a pop. Legendary and Mythic build longer, darken the
	screen, shake the camera harder and glow (owner's rule: every Legendary
	and Mythic glows; Mythics need not be rainbow).

	The sounds (`Config/Sounds` crate_open, egg_hatch, reveal_rare,
	mythic_reveal, reveal_glitter, new_item; `assets/audio/shop_synth.py`)
	are cut to `soundBurst`: each starts that long before its burst, so the
	burst lands on the sound's whatever the build-up's length.
]]

export type Tier = {
	--[[ Extra seconds of wobble before the burst. ]]
	build: number,
	--[[ The burst's shake, 1 a Common's. ]]
	shake: number,
	--[[ How dark the screen goes before the burst (0 none, 1 black). ]]
	dark: number,
	--[[ Extra seconds the prize holds before the screen closes. ]]
	hold: number,
	--[[ It glows, sparkles and gets the second ring and confetti rain. ]]
	glow: boolean,
	--[[ "...SOMETHING SPECIAL..." while it builds, and its odds shown. ]]
	special: boolean,
	--[[ How strongly the egg or chest itself glows, in its area's colour
	     (`glows`), from the landing to the burst (owner, 2026-11-06: "make
	     sure there is a glow in the egg and chest in the animations"). ]]
	aura: number,
}

local Reveal = {
	--[[ The egg hatch. Every egg of a triple hatch runs in step, each one
	     bursting `stagger` after the one before. ]]
	egg = {
		--[[ It falls in and lands at `drop`, bounces, and sits by `settle`. ]]
		drop = 0.32,
		settle = 0.7,
		--[[ The burst for a Common: the wobble runs from `settle` to here. ]]
		burst = 2.3,
		--[[ The cracks, in seconds before the burst (the hatch sound's two
		     crack ticks are the last two). ]]
		cracks = { 1.15, 0.8, 0.4 },
		stagger = 0.12,
		--[[ The pet pops out over `pop` and lands; the banner slams at `banner`
		     after the burst. ]]
		pop = 0.5,
		banner = 0.55,
		--[[ How long a prize holds before the screen closes by itself, and
		     the fade out. ]]
		hold = 1.7,
		fade = 0.35,
		--[[ The hatch sound's length (round 25 A with D's chord), and where its
		     burst falls in it. ]]
		jingle = 3.73,
		soundBurst = 1.3,
	},
	--[[ The chest opens to the egg's beats, the padlocks popping on the
	     second crack; its own sound has its two padlock clicks before the
	     burst. ]]
	crate = {
		soundBurst = 1.1,
		jingle = 3.75,
		--[[ Coins thrown out of the open chest. ]]
		coins = 14,
	},
	--[[ Each rarity's build-up and payoff. ]]
	tiers = {
		Common = {
			build = 0,
			shake = 1,
			dark = 0,
			hold = 0,
			glow = false,
			special = false,
			aura = 0.34,
		},
		Uncommon = {
			build = 0,
			shake = 1.1,
			dark = 0,
			hold = 0,
			glow = false,
			special = false,
			aura = 0.4,
		},
		Rare = {
			build = 0.15,
			shake = 1.25,
			dark = 0.1,
			hold = 0.2,
			glow = false,
			special = false,
			aura = 0.48,
		},
		Epic = {
			build = 0.35,
			shake = 1.5,
			dark = 0.2,
			hold = 0.4,
			glow = false,
			special = false,
			aura = 0.58,
		},
		Legendary = {
			build = 0.9,
			shake = 2.2,
			dark = 0.45,
			hold = 1,
			glow = true,
			special = false,
			aura = 0.82,
		},
		Mythic = {
			build = 1.8,
			shake = 3,
			dark = 0.75,
			hold = 1.6,
			glow = true,
			special = true,
			aura = 1,
		},
	} :: { [string]: Tier },
	--[[ How many bits fly: shell pieces per egg, confetti per reveal. ]]
	shards = 10,
	confetti = 44,
	--[[ The shell's colours per area (`Config/Economy` keys), for its pieces
	     and for the egg drawn when there is no picture or model yet. ]]
	shells = {
		MossyGlade = { Color3.fromRGB(122, 190, 84), Color3.fromRGB(232, 240, 196) },
		Thornwood = { Color3.fromRGB(150, 74, 112), Color3.fromRGB(104, 168, 80) },
		DrownedVillage = { Color3.fromRGB(70, 150, 196), Color3.fromRGB(224, 242, 250) },
		BogheartCaverns = { Color3.fromRGB(92, 112, 62), Color3.fromRGB(184, 96, 206) },
		WindsweptCliffs = { Color3.fromRGB(206, 204, 170), Color3.fromRGB(120, 172, 226) },
		FrostpeakPass = { Color3.fromRGB(176, 220, 250), Color3.fromRGB(255, 255, 255) },
	} :: { [string]: { Color3 } },
	--[[ The light inside each area's egg and chest: its glow while it
	     wobbles and the light out of its cracks and lid. ]]
	glows = {
		MossyGlade = Color3.fromRGB(150, 255, 120),
		Thornwood = Color3.fromRGB(255, 120, 200),
		DrownedVillage = Color3.fromRGB(110, 220, 255),
		BogheartCaverns = Color3.fromRGB(200, 120, 255),
		WindsweptCliffs = Color3.fromRGB(170, 225, 255),
		FrostpeakPass = Color3.fromRGB(190, 245, 255),
	} :: { [string]: Color3 },
	--[[ A chest's wood and its bands, for its splinters and the chest drawn
	     when there is none. ]]
	wood = { Color3.fromRGB(150, 96, 50), Color3.fromRGB(255, 205, 40) },
	equip = {
		--[[ The item flies from its tile to the slot, the slot pops. ]]
		fly = 0.25,
		pop = 0.25,
		--[[ The pet slot's pet hops; the weapon slot flashes. ]]
		settle = 0.5,
	},
	--[[ Rarities that, after the jingle, get `reveal_rare` (a Mythic gets
	     `mythic_reveal` in its place). ]]
	rare = { Epic = true, Legendary = true, Mythic = true },
}

return table.freeze(Reveal)
