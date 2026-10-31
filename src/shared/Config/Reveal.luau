--!strict
--[[
	The beats of the shops' reveals and the gear screen's equip (owner,
	2026-10-26: "a crate opening, egg hatching, and gear equipping animation
	... these are the big selling point so these should be heavy on
	dopamine"), in seconds from the start. The sounds (`Config/Sounds`
	crate_open, egg_hatch, reveal_rare, equip_*, new_item;
	`assets/audio/shop_synth.py`) are cut to these same beats, so change
	both together.
]]

local Reveal = {
	--[[ A crate opens to the eggs' beats (`egg`, owner, 2026-10-27: "the
	     weapon chests are also changed exactly how you are changing the
	     pets"); its own sound still has its two padlock clicks before the
	     burst. ]]
	crate = {
		--[[ Where the opening sound's burst falls (round 24 A), and its
		     length; the rare reveal plays after it (owner, 2026-10-26: "the
		     rare reveal should play after the original full jingle"). ]]
		soundBurst = 1.1,
		jingle = 3.75,
	},
	--[[ The egg hatch, beat for beat as Tap Simulator Reborn's (owner,
	     2026-10-27: "replicated exactly 1 to 1"; docs/EGG-HATCH-REFERENCE.md).
	     Every egg of a triple hatch runs in step; the crates open to it too. ]]
	egg = {
		--[[ The eggs drop in from above; the white ring sweeps out. ]]
		drop = 0.3,
		--[[ The eggs flash pure white, then fade back. ]]
		whiten = { 0.6, 0.9 },
		--[[ They shake, cracks spreading, until the burst. ]]
		cracks = { 1.6, 2.0 },
		--[[ Full-screen white flash; the pets stand where the eggs were. ]]
		burst = 2.4,
		land = 2.6,
		--[[ The pets shrink away and the screen closes by itself (an Epic or
		     better holds on until its reveal sound has played). ]]
		leave = 3.9,
		done = 4.3,
		--[[ The hatch sound's length (round 25 A with D's chord), and where its
		     burst falls in it: it starts `burst - soundBurst` in. ]]
		jingle = 3.73,
		soundBurst = 1.3,
	},
	--[[ A Mythic's cinematic before its pet shows (Tap Simulator Reborn's
	     top-rarity hatch, same timings). ]]
	mythic = {
		--[[ Dark screen, the pet's silhouette, "YOU HATCHED SOMETHING SPECIAL...". ]]
		question = 0.9,
		--[[ The "?" whitens in sparkles; the flash; the hall glide. ]]
		whiten = 5.1,
		flash = 5.9,
		--[[ The lone golden egg, glowing brighter and bigger. ]]
		egg = 12.7,
		--[[ The pet on its pedestal: "MYTHIC DISCOVERED", name, odds. ]]
		discovered = 16.2,
		--[[ A tap may close it from here. ]]
		done = 17.4,
	},
	equip = {
		--[[ The item flies from its tile to the slot, the slot pops. ]]
		fly = 0.25,
		pop = 0.25,
		--[[ The pet slot's pet hops; the weapon slot flashes. ]]
		settle = 0.5,
	},
	--[[ Rarities that get the bigger burst and, after the jingle, `reveal_rare`. ]]
	rare = { Epic = true, Legendary = true, Mythic = true },
}

return table.freeze(Reveal)
